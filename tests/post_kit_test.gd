# Godot EventSheets - the Post Kit pack: the camera's post stack, and the outline that goes through
# walls.
#
# A test cannot reach a scene tree, a rendering device or a frame, so nothing here asks what the
# camera DREW. What it asks instead is everything that decides what the camera will draw:
#
#   - the pack's rows exist under the names and the emitted spellings the sheet promises;
#   - the five effect words are the 2D post stack's own words where the two overlap, which is the
#     whole of "a row reads alike on the screen and on the camera";
#   - each effect is a real CompositorEffect resource that loads, with the exported dials its shader
#     reads, and each shader file exists and declares the one push constant they all share;
#   - the stack model, by value: what add, disable, set, fade and remove leave behind, and what the
#     two accessibility dials do to a strength on the way in;
#   - the outline row's marking, by value: the mask layer bit goes on the meshes and comes off again;
#   - and the companion files shipped beside the pack are byte-identical to the ones they came from,
#     which is what makes a second build change nothing.
@tool
class_name PostKitTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "post_kit_test"

const PACK_SCRIPT := "res://eventsheet_addons/post_kit/post_kit_behavior.gd"
const EFFECT_DIRECTORY := "res://eventsheet_addons/post_kit/effects/"
const EFFECT_SOURCE_DIRECTORY := "res://tools/pack_builders/src/post_kit_effects/"
const SCREEN_FX_SCRIPT := "res://eventsheet_addons/screen_fx/screen_fx.gd"

## The five words a row adds by name, and the file each one is.
const EFFECT_WORDS: PackedStringArray = ["vignette", "desaturate", "pixelate", "tint", "fade"]


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _the_rows_are_the_ones_the_pack_promises() and all_passed
	all_passed = _the_words_are_the_screens_words() and all_passed
	all_passed = _every_effect_is_a_resource_with_its_dials() and all_passed
	all_passed = _every_shader_is_a_file_with_the_shared_header() and all_passed
	all_passed = _the_stack_model_by_value() and all_passed
	all_passed = _the_accessibility_dials_reach_the_camera() and all_passed
	all_passed = _the_outline_row_marks_the_layer() and all_passed
	all_passed = _the_companions_are_the_bytes_they_came_from() and all_passed
	all_passed = _the_renderer_note_names_the_door() and all_passed
	return all_passed


## Every row the pack ships, by the name a picker shows and the line it emits. These are the two
## halves of a verb's public face, and both freeze the moment the pack ships.
static func _the_rows_are_the_ones_the_pack_promises() -> bool:
	var pack: String = FileAccess.get_file_as_string(PACK_SCRIPT)
	var rows: Dictionary = {
		"Add Post Effect": "$PostKitBehavior.add_post_effect(\"{effect}\", \"{called}\", {strength})",
		"Remove Post Effect": "$PostKitBehavior.remove_post_effect(\"{called}\")",
		"Enable Post Effect": "$PostKitBehavior.enable_post_effect(\"{called}\")",
		"Disable Post Effect": "$PostKitBehavior.disable_post_effect(\"{called}\")",
		"Set Post Strength": "$PostKitBehavior.set_post_strength(\"{called}\", {strength})",
		"Fade Post Strength": "$PostKitBehavior.fade_post_strength(\"{called}\", {to}, {seconds})",
		"Pulse Post Effect": "$PostKitBehavior.pulse_post_effect(\"{effect}\", {strength}, {seconds})",
		"Has Post Effect": "$PostKitBehavior.has_post_effect(\"{called}\")",
		"Post Strength": "$PostKitBehavior.post_strength(\"{called}\")",
		"Outline Group Through Walls": "$PostKitBehavior.outline_group_through_walls(\"{group}\", {colour}, {width}, {seconds})",
		"Silhouette Node Through Walls": "$PostKitBehavior.silhouette_node_through_walls({node}, {colour}, {seconds})",
		"Stop Outlining": "$PostKitBehavior.stop_outlining()",
		"Is Outlined": "$PostKitBehavior.is_outlined({node})",
		"Is Hidden From View": "$PostKitBehavior.is_hidden_from_view({node})",
	}
	var missing_names: PackedStringArray = PackedStringArray()
	var missing_templates: PackedStringArray = PackedStringArray()
	for row_name: String in rows:
		if not pack.contains("## @ace_name(\"%s\")" % row_name):
			missing_names.append(row_name)
		if not pack.contains("## @ace_codegen_template(\"%s\")" % str(rows[row_name])):
			missing_templates.append(row_name)
	return SUPPORT.pins(P, [
		["every row is named in the shipped pack", ",".join(missing_names), ""],
		["every row emits the line it promises", ",".join(missing_templates), ""],
		["the pack is a Post Kit behavior", pack.contains("## @ace_category(\"Post Kit\")"), true],
		["the pack says which renderer draws it", pack.contains("FORWARD+ ONLY"), true],
	])


## Where the two stacks overlap they use the SAME WORD, so a row reads alike whether it is on the
## screen or on the camera. Pinned as the overlap itself rather than as a count, so either list
## changing a spelling is a failure that names the word.
static func _the_words_are_the_screens_words() -> bool:
	var screen: String = FileAccess.get_file_as_string(SCREEN_FX_SCRIPT)
	var shared: PackedStringArray = PackedStringArray()
	for word: String in EFFECT_WORDS:
		if screen.contains("\"%s\"" % word):
			shared.append(word)
	shared.sort()
	return SUPPORT.pins(P, [
		["the words both stacks ship are spelled the same", ",".join(shared),
			"desaturate,pixelate,vignette"],
		["the pack ships the five words it says it does",
			",".join(_pack_constant("POST_EFFECTS")), "vignette,desaturate,pixelate,tint,fade"],
	])


## Each effect is a CompositorEffect that loads from its own file, with the dials its shader reads.
## The dials are asked for BY NAME through the property list, because a dial renamed is a shader
## reading a value nothing writes.
static func _every_effect_is_a_resource_with_its_dials() -> bool:
	var dials: Dictionary = {
		"vignette": "shade,inner_edge,strength",
		"desaturate": "strength",
		"pixelate": "block_pixels,strength",
		"tint": "tint,gain,strength",
		"fade": "to_colour,strength",
		"outline": "ink,width,fill,strength",
	}
	var rows: Array = []
	for word: String in dials:
		var made: Object = _effect(word)
		rows.append(["%s is a CompositorEffect" % word, made is CompositorEffect, true])
		if made == null:
			continue
		var found: PackedStringArray = PackedStringArray()
		for wanted: String in str(dials[word]).split(","):
			if _has_property(made, wanted):
				found.append(wanted)
		rows.append(["%s carries its own dials" % word, ",".join(found), str(dials[word])])
	rows.append(["an effect starts at the strength a row would not have to think about",
		float((_effect("vignette") as Object).get("strength")), 0.6])
	rows.append(["the outline starts as an edge rather than a fill",
		float((_effect("outline") as Object).get("fill")), 0.0])
	return SUPPORT.pins(P, rows)


## Every effect has a compute shader on disk, and every shader declares the same push constant, the
## frame at binding 0, and (for the one that reads a mask) the mask at binding 1.
static func _every_shader_is_a_file_with_the_shared_header() -> bool:
	var rows: Array = []
	var words: PackedStringArray = EFFECT_WORDS.duplicate()
	words.append("outline")
	for word: String in words:
		var path: String = "%spost_%s.glsl" % [EFFECT_DIRECTORY, word]
		var text: String = FileAccess.get_file_as_string(path)
		rows.append(["post_%s.glsl is a compute shader" % word, text.begins_with("#[compute]"), true])
		rows.append(["post_%s.glsl reads the frame at binding 0" % word,
			text.contains("layout(rgba16f, set = 0, binding = 0) uniform restrict image2D frame;"), true])
		rows.append(["post_%s.glsl shares the one push constant" % word,
			text.contains("layout(push_constant, std430) uniform Params {"), true])
	var outline: String = FileAccess.get_file_as_string("%spost_outline.glsl" % EFFECT_DIRECTORY)
	rows.append(["the outline shader reads a mask at binding 1",
		outline.contains("layout(set = 0, binding = 1) uniform sampler2D mask;"), true])
	return SUPPORT.pins(P, rows)


## The stack, exercised on a camera that is not in a tree: what each row leaves behind, and what the
## camera's own Compositor is holding afterwards.
static func _the_stack_model_by_value() -> bool:
	var camera: Camera3D = Camera3D.new()
	var kit: Node = _behavior(camera)
	kit.call("add_post_effect", "vignette", "", 0.6)
	kit.call("add_post_effect", "tint", "warm", 0.4)
	var rows: Array = [
		["adding one names it after its effect", kit.call("has_post_effect", "vignette"), true],
		["a named entry answers to its name", kit.call("has_post_effect", "warm"), true],
		["a strength comes back as it was asked for", kit.call("post_strength", "vignette"), 0.6],
		["the camera is holding both, in the order they were added",
			_effect_files(camera), "post_vignette.gd,post_tint.gd"],
		["an unknown word adds nothing",
			_says_no(kit, "add_post_effect", "sepia"), true],
	]
	kit.call("disable_post_effect", "warm")
	rows.append(["disabling leaves the entry and turns the effect off",
		[kit.call("has_post_effect", "warm"), _enabled(camera, 1)], [true, false]])
	kit.call("enable_post_effect", "warm")
	rows.append(["enabling turns it back on", _enabled(camera, 1), true])
	kit.call("set_post_strength", "warm", 0.25)
	rows.append(["a strength written reaches the effect the shader reads",
		float(camera.compositor.compositor_effects[1].get("strength")), 0.25])
	# No tree means no tween, so a fade lands on its value at once - the same answer a moment later.
	kit.call("fade_post_strength", "warm", 1.0, 0.5)
	rows.append(["a fade with no tree to run in lands on its value", kit.call("post_strength", "warm"), 1.0])
	kit.call("remove_post_effect", "vignette")
	rows.append(["removing takes it off the camera",
		[kit.call("has_post_effect", "vignette"), _effect_files(camera)], [false, "post_tint.gd"]])
	# A pulse with no tree behaves the same way: it lands, and a borrowed entry is dropped again.
	kit.call("pulse_post_effect", "fade", 0.8, 0.0)
	rows.append(["a pulse with no time left is the strength it asked for",
		kit.call("post_strength", "fade"), 0.8])
	camera.free()
	return SUPPORT.pins(P, rows)


## The two dials the whole project already shares reach the camera's stack: the effect-strength dial
## scales a row, and no flashing holds it under the ceiling. The new layer obeys them; the frozen
## verbs of the other packs are deliberately untouched, which is why this is asked here.
static func _the_accessibility_dials_reach_the_camera() -> bool:
	var had_flashing: bool = Engine.has_meta(&"no_flashing")
	var had_strength: bool = Engine.has_meta(&"effect_strength")
	var was_flashing: Variant = Engine.get_meta(&"no_flashing", false)
	var was_strength: Variant = Engine.get_meta(&"effect_strength", 1.0)
	var camera: Camera3D = Camera3D.new()
	var kit: Node = _behavior(camera)
	Engine.set_meta(&"effect_strength", 0.5)
	kit.call("add_post_effect", "vignette", "half", 1.0)
	var halved: Variant = kit.call("post_strength", "half")
	Engine.set_meta(&"effect_strength", 1.0)
	Engine.set_meta(&"no_flashing", true)
	kit.call("add_post_effect", "tint", "held", 1.0)
	var held: Variant = kit.call("post_strength", "held")
	camera.free()
	if had_flashing:
		Engine.set_meta(&"no_flashing", was_flashing)
	else:
		Engine.remove_meta(&"no_flashing")
	if had_strength:
		Engine.set_meta(&"effect_strength", was_strength)
	else:
		Engine.remove_meta(&"effect_strength")
	return SUPPORT.pins(P, [
		["the effect-strength dial scales a row on the way in", halved, 0.5],
		["no flashing holds a row under the ceiling", held, 0.3],
	])


## The outline row's own mechanism: the mask layer bit goes on every visual instance under what was
## named, and Stop Outlining takes it off exactly those again.
static func _the_outline_row_marks_the_layer() -> bool:
	var camera: Camera3D = Camera3D.new()
	var kit: Node = _behavior(camera)
	var body: Node3D = Node3D.new()
	var mesh: MeshInstance3D = MeshInstance3D.new()
	body.add_child(mesh)
	var layer: int = int(kit.get("mask_layer"))
	var before: bool = mesh.get_layer_mask_value(20)
	kit.call("_mark", body, true)
	var marked: bool = mesh.get_layer_mask_value(20)
	var still_on_its_own_layer: bool = mesh.get_layer_mask_value(1)
	kit.call("stop_outlining")
	var cleared: bool = mesh.get_layer_mask_value(20)
	body.free()
	camera.free()
	return SUPPORT.pins(P, [
		["the pack marks the last visual layer by default", layer, 20],
		["a mesh starts off the mask layer", before, false],
		["the row switches the mask layer on for the meshes under a node", marked, true],
		["and leaves the layers the project was already using alone", still_on_its_own_layer, true],
		["stopping switches it off again", cleared, false],
	])


## The companion files beside the shipped pack are the ones in the source folder, byte for byte.
## That is what makes a second build write nothing, and it is the only place it can be asked, since
## the pack drift gate reads scripts and these are shaders and effect resources.
static func _the_companions_are_the_bytes_they_came_from() -> bool:
	var differ: PackedStringArray = PackedStringArray()
	var absent: PackedStringArray = PackedStringArray()
	var source: DirAccess = DirAccess.open(EFFECT_SOURCE_DIRECTORY)
	var names: PackedStringArray = PackedStringArray() if source == null else source.get_files()
	names.sort()
	for file_name: String in names:
		if not (file_name.ends_with(".gd") or file_name.ends_with(".glsl")):
			continue
		var shipped_path: String = EFFECT_DIRECTORY + file_name
		if not FileAccess.file_exists(shipped_path):
			absent.append(file_name)
			continue
		if FileAccess.get_file_as_string(shipped_path) != FileAccess.get_file_as_string(
				EFFECT_SOURCE_DIRECTORY + file_name):
			differ.append(file_name)
	return SUPPORT.pins(P, [
		["every companion the source folder holds ships beside the pack", ",".join(absent), ""],
		["and ships byte for byte, so a second build writes nothing", ",".join(differ), ""],
	])


## The ship-it check names a post-stack row for what it is on a renderer that has no compositor, and
## carries the door with it: the 2D packs do the same looks anywhere.
static func _the_renderer_note_names_the_door() -> bool:
	var row: String = "$PostKitBehavior.pulse_post_effect(\"vignette\", 0.6, 0.35)"
	return SUPPORT.pins(P, [
		["a post-stack row is named as Forward+ only",
			EventSheetShipItDoctor.forward_plus_asked_for(row),
			"a camera post effect (the Screen FX and Blend Modes packs do the same looks on any renderer)"],
		["a file with no such row is named as nothing",
			EventSheetShipItDoctor.forward_plus_asked_for("position.x += 1.0"), ""],
	])


## One Post Kit behavior under a camera, wired the way _enter_tree wires it. A test has no tree, so
## the one thing the tree would have done is done here rather than reached for.
static func _behavior(camera: Camera3D) -> Node:
	var script: GDScript = load(PACK_SCRIPT) as GDScript
	var kit: Node = script.new() as Node
	camera.add_child(kit)
	kit.set("host", camera)
	return kit


## One effect resource, built from its own script file the way the pack builds it.
static func _effect(word: String) -> Object:
	var script: GDScript = load("%spost_%s.gd" % [EFFECT_DIRECTORY, word]) as GDScript
	if script == null:
		return null
	return script.new()


## Whether an object declares a property by that name - asked of the property list rather than with
## `in`, so an answer of null from a property that exists is not read as an absence.
static func _has_property(target: Object, property_name: String) -> bool:
	for entry: Dictionary in target.get_property_list():
		if str(entry.get("name", "")) == property_name:
			return true
	return false


## The effect scripts the camera's Compositor is holding, in order, by file name - the shape of the
## stack as the renderer would walk it.
static func _effect_files(camera: Camera3D) -> String:
	if camera.compositor == null:
		return ""
	var names: PackedStringArray = PackedStringArray()
	for made: CompositorEffect in camera.compositor.compositor_effects:
		names.append(made.get_script().resource_path.get_file())
	return ",".join(names)


## Whether the effect at that position in the camera's stack is switched on.
static func _enabled(camera: Camera3D, at: int) -> bool:
	if camera.compositor == null or at >= camera.compositor.compositor_effects.size():
		return false
	return camera.compositor.compositor_effects[at].enabled


## Whether a row refused a word it does not know: nothing was added, and the stack is the length it
## was. The warning it prints is deliberate and is not counted here.
static func _says_no(kit: Node, row: String, word: String) -> bool:
	kit.call(row, word, "unknown", 0.5)
	return not bool(kit.call("has_post_effect", "unknown"))


## One constant off the shipped pack, as the list it is. Read from the pack rather than restated, so
## a word added there without being added here is a failure rather than a silence.
static func _pack_constant(constant_name: String) -> PackedStringArray:
	var script: GDScript = load(PACK_SCRIPT) as GDScript
	if script == null:
		return PackedStringArray()
	return script.get_script_constant_map().get(constant_name, PackedStringArray())
