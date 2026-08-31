# Godot EventSheets - the Second View pack: a second picture of the world you are already in.
#
# Three things are pinned here.
#
#   1. THE PUBLISHED CONTRACT, read off the shipped file: the four verbs and the one expression, the
#      autoload calls they emit, the scene-node fields, and the refusals the pack decided NOT to
#      publish (no split-screen row, no culling row, no drawing row - those belong to Canvas Surface
#      and to the visibility-layer vocabulary).
#   2. THE RUNTIME, driven treeless. The suite has no scene tree (run_tests.gd works inside
#      SceneTree._init, where the main loop does not exist yet), so the two names that need one -
#      `is_inside_tree()` and `get_viewport()` - are redirected at stand-ins, exactly as the Named
#      Scenes pack test redirects them. What that proves is the bookkeeping: which camera a followed
#      node's class asks for, the shared world, zoom clamping, the park-the-tick convention when a
#      followed node is destroyed, and Stop View taking its texture back off the frames first.
#   3. THE LIFT, both directions. A sheet's own `SecondView.make_a_view(...)` opens as the pack's row
#      like every other pack verb, and a HAND-BUILT SubViewport is never claimed as one - proved
#      against a fixture, because a view the pack did not make is not a view it can zoom or stop.
@tool
class_name SecondViewPackTest
extends RefCounted

const PACK: String = "res://eventsheet_addons/second_view/second_view_addon.gd"
const HANDBUILT: String = "res://tests/fixtures/second_view_handbuilt.gd"
const ROWS: String = "res://tests/fixtures/second_view_rows.gd"


static func run() -> bool:
	var all_passed: bool = true
	var script: GDScript = load(PACK)
	all_passed = _check("the second view pack loads + parses", script != null, true) and all_passed
	if script == null:
		return all_passed
	all_passed = _test_published_contract() and all_passed
	all_passed = _test_refusals() and all_passed
	all_passed = _test_views() and all_passed
	all_passed = _test_lift() and all_passed
	return all_passed


## What the pack publishes, off the shipped bytes.
static func _test_published_contract() -> bool:
	var all_passed: bool = true
	var source: String = FileAccess.get_file_as_string(PACK)
	all_passed = _check("it ships as the SecondView autoload",
		source.contains("## @ace_codegen_template(\"SecondView.make_a_view({view_name}, {followed}, {zoom})\")"), true) and all_passed
	all_passed = _check("Show View In emits its autoload call",
		source.contains("## @ace_codegen_template(\"SecondView.show_view_in({view_name}, {frame})\")"), true) and all_passed
	all_passed = _check("Set View Zoom emits its autoload call",
		source.contains("## @ace_codegen_template(\"SecondView.set_view_zoom({view_name}, {zoom})\")"), true) and all_passed
	all_passed = _check("Stop View emits its autoload call",
		source.contains("## @ace_codegen_template(\"SecondView.stop_view({view_name})\")"), true) and all_passed
	all_passed = _check("View Texture Of is published as an expression",
		source.contains("## @ace_expression\n## @ace_name(\"View Texture Of\")"), true) and all_passed
	all_passed = _check("and answers with a texture", source.contains("func view_texture_of(view_name: String = \"minimap\") -> Texture2D:"), true) and all_passed
	all_passed = _check("the followed node's field is the scene-node picker",
		source.contains("## @ace_param_hint(followed scene_node)"), true) and all_passed
	all_passed = _check("and so is the frame's", source.contains("## @ace_param_hint(frame scene_node)"), true) and all_passed
	all_passed = _check("Make A View and Show View In are the two hero verbs",
		source.count("## @ace_featured"), 2) and all_passed
	all_passed = _check("a view really shares the running 2D world",
		source.contains("view.world_2d = get_viewport().find_world_2d()"), true) and all_passed
	all_passed = _check("and the running 3D one",
		source.contains("view.world_3d = get_viewport().find_world_3d()"), true) and all_passed
	all_passed = _check("the render is always on, which is what a hand-built view forgets",
		source.contains("view.render_target_update_mode = SubViewport.UPDATE_ALWAYS"), true) and all_passed
	return all_passed


## The refusals: what this pack deliberately does not publish, because a neighbour already owns it.
static func _test_refusals() -> bool:
	var all_passed: bool = true
	var source: String = FileAccess.get_file_as_string(PACK)
	var published: PackedStringArray = PackedStringArray()
	for line: String in source.split("\n"):
		if line.begins_with("## @ace_name("):
			published.append(line.substr(14, line.length() - 16))
	all_passed = _check("the pack publishes exactly its five words", published,
		PackedStringArray(["Make A View", "Show View In", "Set View Zoom", "Stop View", "View Texture Of"])) and all_passed
	all_passed = _check("the split-screen refusal is stated in the pack rather than published as a row",
		source.contains("Two views in two frames IS split screen"), true) and all_passed
	all_passed = _check("no per-view culling row in v1 - the camera it builds is ordinary, so the visibility-layer rows already decide that",
		source.contains("cull_mask"), false) and all_passed
	all_passed = _check("no drawing row - drawing surfaces stay Canvas Surface's",
		source.contains("draw_"), false) and all_passed
	return all_passed


## The runtime, treeless: making views, the camera each followed class asks for, zoom, the frames, the
## park-the-tick convention, and Stop View.
static func _test_views() -> bool:
	var all_passed: bool = true
	var script: GDScript = _harness_script()
	all_passed = _check("the stand-in harness parses", script != null, true) and all_passed
	if script == null:
		return all_passed

	var views: Node = script.new()
	views.in_tree = true
	views.fake_viewport = _world_stand_in()

	# Nothing to follow yet, so nothing is being paid for.
	views._ready()
	all_passed = _check("a fresh autoload pays for no frame at all", views.is_processing(), false) and all_passed

	# A 2D node asks for a Camera2D in a viewport sharing the 2D world.
	var runner: Node2D = Node2D.new()
	runner.global_position = Vector2(300.0, 120.0)
	views.make_a_view("minimap", runner, 0.25)
	var minimap: SubViewport = views._views["minimap"]["viewport"]
	all_passed = _check("the view is a SubViewport named after it", minimap.name, StringName("View_minimap")) and all_passed
	all_passed = _check("parented to the autoload", minimap.get_parent(), views) and all_passed
	all_passed = _check("rendering always, not only when visible",
		minimap.render_target_update_mode, SubViewport.UPDATE_ALWAYS) and all_passed
	all_passed = _check("sharing the running 2D world rather than an empty one",
		minimap.world_2d, views.fake_viewport.shared_2d) and all_passed
	var lens: Camera2D = views._views["minimap"]["camera"]
	all_passed = _check("a 2D node gets a Camera2D", lens != null, true) and all_passed
	all_passed = _check("already on the node it follows", lens.global_position, Vector2(300.0, 120.0)) and all_passed
	all_passed = _check("at the zoom the row asked for", lens.zoom, Vector2(0.25, 0.25)) and all_passed
	all_passed = _check("and the frame is being paid for again", views.is_processing(), true) and all_passed

	# Following: the camera goes where the node goes.
	runner.global_position = Vector2(500.0, 90.0)
	views._process(0.016)
	all_passed = _check("the camera follows on the frame", lens.global_position, Vector2(500.0, 90.0)) and all_passed

	# Zoom, and its floor - a zoom of zero would divide the world by nothing.
	views.set_view_zoom("minimap", 1.5)
	all_passed = _check("Set View Zoom moves the camera's zoom", lens.zoom, Vector2(1.5, 1.5)) and all_passed
	views.set_view_zoom("minimap", 0.0)
	all_passed = _check("a zoom of zero is floored rather than obeyed", lens.zoom, Vector2(0.01, 0.01)) and all_passed
	views.set_view_zoom("nowhere", 2.0)
	all_passed = _check("zooming a view that does not exist changes nothing",
		views._views.has("nowhere"), false) and all_passed

	# A 3D node asks for a Camera3D in a viewport sharing the 3D world. Godot refuses to answer a
	# Node3D's WORLD position while it is out of the tree, and the suite has no tree, so the followed
	# node here reads at the origin - which is exactly what makes the height the zoom puts the camera
	# at the readable thing, and it is the height that is the arithmetic worth pinning. The three
	# "Condition !is_inside_tree() is true" lines the suite prints around here are that refusal being
	# said out loud, not a failure.
	var walker: Node3D = Node3D.new()
	views.make_a_view("monitor", walker, 1.0)
	var monitor: SubViewport = views._views["monitor"]["viewport"]
	all_passed = _check("a 3D node gets a viewport on the running 3D world",
		monitor.world_3d, views.fake_viewport.shared_3d) and all_passed
	var eye: Camera3D = views._views["monitor"]["camera"]
	all_passed = _check("with a Camera3D inside it", eye != null, true) and all_passed
	all_passed = _check("sitting overhead by the zoom-1 height",
		eye.position, Vector3(0.0, 20.0, 0.0)) and all_passed
	all_passed = _check("looking straight down, with world north still up the screen",
		eye.basis, Basis(Vector3.RIGHT, Vector3.FORWARD, Vector3.UP)) and all_passed
	views.set_view_zoom("monitor", 2.0)
	all_passed = _check("and twice the zoom is half the height",
		eye.position, Vector3(0.0, 10.0, 0.0)) and all_passed

	# A node that is neither 2D nor 3D has nowhere to put a camera, and is refused by name.
	var plain: Node = Node.new()
	plain.name = "Bookkeeping"
	views.make_a_view("nothing_to_see", plain, 1.0)
	all_passed = _check("a node that is neither 2D nor 3D is refused rather than half-built",
		views._views.has("nothing_to_see"), false) and all_passed
	views.make_a_view("", runner, 1.0)
	all_passed = _check("and so is a nameless view", views._views.size(), 2) and all_passed

	# Making a view under a name that already exists replaces it.
	var second_runner: Node2D = Node2D.new()
	views.make_a_view("minimap", second_runner, 0.5)
	all_passed = _check("re-making a name leaves one view, not two", views._views.size(), 2) and all_passed
	all_passed = _check("and it is the new one", views._views["minimap"]["camera"] != lens, true) and all_passed

	# Showing a view in a frame: the texture lands, the frame is remembered, and a frame that takes
	# no texture is refused by name rather than silently doing nothing.
	var frame: TextureRect = TextureRect.new()
	frame.size = Vector2(200.0, 120.0)
	views.show_view_in("minimap", frame)
	all_passed = _check("the frame is remembered so Stop View can clear it",
		(views._views["minimap"]["frames"] as Dictionary).has(frame.get_instance_id()), true) and all_passed
	all_passed = _check("and the render is sized to the frame rather than stretched from a square",
		(views._views["minimap"]["viewport"] as SubViewport).size, Vector2i(200, 120)) and all_passed
	views.show_view_in("minimap", frame)
	all_passed = _check("showing the same view in the same frame twice hooks it once",
		(views._views["minimap"]["frames"] as Dictionary).size(), 1) and all_passed
	views.show_view_in("minimap", plain)
	all_passed = _check("a frame that takes no texture is refused",
		(views._views["minimap"]["frames"] as Dictionary).size(), 1) and all_passed
	views.show_view_in("nowhere", frame)
	all_passed = _check("and so is a view nobody made", views._views.has("nowhere"), false) and all_passed

	# THE IDLE CONVENTION: a view whose followed node is gone parks, and when every view has parked
	# the autoload hands the frame back.
	all_passed = _check("both views are still being followed", views.is_processing(), true) and all_passed
	second_runner.free()
	views._process(0.016)
	all_passed = _check("the view whose node went stops being redrawn",
		(views._views["minimap"]["viewport"] as SubViewport).render_target_update_mode,
		SubViewport.UPDATE_DISABLED) and all_passed
	all_passed = _check("but a view that still has its node keeps drawing",
		monitor.render_target_update_mode, SubViewport.UPDATE_ALWAYS) and all_passed
	all_passed = _check("and the frame is still worth paying for", views.is_processing(), true) and all_passed
	walker.free()
	views._process(0.016)
	all_passed = _check("with nothing left to follow, the tick is handed back",
		views.is_processing(), false) and all_passed

	# Stop View: the frames are cleared BEFORE the viewport goes.
	frame.texture = PlaceholderTexture2D.new()
	views._views["minimap"]["frames"][frame.get_instance_id()] = Callable()
	views.stop_view("minimap")
	all_passed = _check("Stop View takes the picture back off the frame", frame.texture, null) and all_passed
	all_passed = _check("and forgets the view", views._views.has("minimap"), false) and all_passed
	views.stop_view("minimap")
	all_passed = _check("stopping a view that is not there does nothing", views._views.size(), 1) and all_passed
	views.stop_view("monitor")
	all_passed = _check("the last view goes too", views._views.is_empty(), true) and all_passed

	frame.free()
	plain.free()
	runner.free()
	views.free()
	return all_passed


## The lift, both ways.
##
## A pack's verbs are claimed by their own `@ace_codegen_template`, and nothing else - this pack adds
## no lifting machinery of its own, which is the whole point of "it lifts like every pack verb". Those
## templates all open `SecondView.`, so the two directions are one fact: a line naming the autoload can
## be claimed, and a line that does not name it never can. That is why a hand-built SubViewport is safe
## from this pack no matter what else is in scope - a view the pack never made is not a view it could
## zoom or stop, and a row claiming otherwise would promise a name the autoload has never heard of.
##
## The suite has no scene tree, so the runtime bridge that carries pack vocabulary into the reverse
## index is not there and the calls read as plain method calls here rather than as the pack's rows.
## What is driven instead is the half that does not depend on it: both files open and re-emit byte for
## byte, every call is a row, and nothing in either file is falsely claimed.
static func _test_lift() -> bool:
	var all_passed: bool = true
	for path: String in [ROWS, HANDBUILT]:
		var source: String = FileAccess.get_file_as_string(path)
		var sheet: EventSheetResource = GDScriptImporter.new().import_external(path)
		var reopened: String = str(SheetCompiler.compile(sheet, path).get("output", ""))
		all_passed = _check("%s comes back byte for byte" % path.get_file(), reopened, source) and all_passed

	var rows: EventSheetResource = GDScriptImporter.new().import_external(ROWS)
	all_passed = _check("a sheet's four Second View calls all open as rows",
		_actions_of(rows).size(), 4) and all_passed
	all_passed = _check("and every one of them is a line naming the autoload, which is what its verb's template claims",
		_lines_naming_the_autoload(ROWS), 4) and all_passed

	var handbuilt: EventSheetResource = GDScriptImporter.new().import_external(HANDBUILT)
	all_passed = _check("the hand-built viewport opens as rows too, so nothing about it is lost",
		_actions_of(handbuilt).size() > 0, true) and all_passed
	all_passed = _check("but not one of its lines names the autoload, so no template of this pack can reach it",
		_lines_naming_the_autoload(HANDBUILT), 0) and all_passed
	all_passed = _check("and no row it opened as carries a Second View spelling",
		_pack_rows(handbuilt), PackedStringArray()) and all_passed

	# Every published template really does open with the autoload name, or the sentence above is not
	# a proof of anything.
	var openers: int = 0
	for line: String in FileAccess.get_file_as_string(PACK).split("\n"):
		if line.begins_with("## @ace_codegen_template(\"SecondView."):
			openers += 1
	all_passed = _check("all five published verbs are claimed by a SecondView. template and nothing else",
		openers, 5) and all_passed
	return all_passed


## How many lines of a file name the pack's autoload - the only lines any template of this pack can
## ever claim.
static func _lines_naming_the_autoload(path: String) -> int:
	var naming: int = 0
	for line: String in FileAccess.get_file_as_string(path).split("\n"):
		if line.contains("SecondView."):
			naming += 1
	return naming


## The Second View verbs one opened sheet became, in sheet order - read off the baked template, which
## is the spelling the row will write back and the only thing that says which vocabulary claimed it.
static func _pack_rows(sheet: EventSheetResource) -> PackedStringArray:
	var claimed: PackedStringArray = PackedStringArray()
	for action: ACEAction in _actions_of(sheet):
		if not action.codegen_template.begins_with("SecondView."):
			continue
		claimed.append(action.codegen_template.substr(11).get_slice("(", 0))
	return claimed


## Every action of every event, however deeply nested.
static func _actions_of(sheet: EventSheetResource) -> Array[ACEAction]:
	var actions: Array[ACEAction] = []
	for entry: Variant in sheet.events:
		_collect_actions(entry, actions)
	return actions


static func _collect_actions(entry: Variant, actions: Array[ACEAction]) -> void:
	var event: EventRow = entry as EventRow
	if event == null:
		return
	for candidate: Variant in event.actions:
		var action: ACEAction = candidate as ACEAction
		if action != null:
			actions.append(action)
	for sub: Variant in event.sub_events:
		_collect_actions(sub, actions)


## The shipped pack source with its class_name and icon dropped (an in-memory script cannot claim a
## global class name that is already registered) and the two names that need a scene tree redirected
## at stand-ins the test supplies.
static func _harness_script() -> GDScript:
	var kept: PackedStringArray = PackedStringArray()
	for line: String in FileAccess.get_file_as_string(PACK).split("\n"):
		if line.begins_with("class_name ") or line.begins_with("@icon("):
			continue
		kept.append(line)
	var text: String = "\n".join(kept).replace("get_viewport()", "_viewport()").replace("is_inside_tree()", "_in_tree()")
	text += "\n\nvar fake_viewport: Object = null\nvar in_tree: bool = false\n\nfunc _viewport() -> Object:\n\treturn fake_viewport\n\nfunc _in_tree() -> bool:\n\treturn in_tree\n"
	var script: GDScript = GDScript.new()
	script.source_code = text
	return script if script.reload() == OK else null


## A stand-in for the running game's viewport that hands out one real World2D and one real World3D,
## so "the view shares the world it is a second picture of" is asserted against the same object.
static func _world_stand_in() -> Object:
	var script: GDScript = GDScript.new()
	script.source_code = "extends RefCounted\n\nvar shared_2d: World2D = World2D.new()\nvar shared_3d: World3D = World3D.new()\n\nfunc find_world_2d() -> World2D:\n\treturn shared_2d\n\nfunc find_world_3d() -> World3D:\n\treturn shared_3d\n"
	script.reload()
	return script.new()


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		return true
	print("[FAIL] second_view_pack_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
