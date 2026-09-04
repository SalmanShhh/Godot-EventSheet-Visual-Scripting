# Godot EventSheets - the Camera Rail packs (the 2D rail and its 3D twin).
#
# Both packs are shot lists: a rail flies its own camera along a drawn path over seconds, holds on
# a beat, blends onto another camera and hands the view over, or cuts to one outright. Everything
# here drives the COMPILED pack directly and steps it by hand - a headless run has no main loop, so
# nothing in this file waits for a frame or a tween.
#
# Two things about the 3D twin are worth writing down, because they decide the shape of half this
# file. A Node3D REFUSES to read or write a global transform outside a scene tree (it returns
# identity and prints an error), and `look_at_from_position` sets one. A headless test has no tree.
# So the 3D value pins run against the shipped source with those two seams rewritten into the local
# frame - the arithmetic is identical either way, and every other character is the pack's own. The
# rewrite is asserted to have FIRED, because a replace that matched nothing would leave this whole
# half passing for the wrong reason. A third seam joins them for the same reason: asking the
# viewport which camera is current also needs a tree, and the case worth pinning is exactly the one
# where the answer is a camera the rail never handed the view to.
@tool
class_name CameraRailPackTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const PACK_2D := "res://eventsheet_addons/camera_rail/camera_rail_behavior.gd"
const PACK_3D := "res://eventsheet_addons/camera_rail_3d/camera_rail_3d_behavior.gd"

## The two calls of the 3D pack that ask a scene tree a question outright, and the local-frame
## arithmetic that stands in for each. Written out in full so a change to either side fails the
## rewrite pins below rather than quietly turning this half of the file into a no-op. Everything
## else the rewrite does is the blanket `global_` fold applied after these.
const TREE_CALLS := [
	["host.look_at_from_position(host.global_position, focus, Vector3.UP)",
		"host.transform = Transform3D(Basis.looking_at(focus - host.global_position, Vector3.UP), host.global_position)"],
	["_flight_path.to_global(point)", "(_flight_path.transform * point)"],
]
## The third seam, kept apart from the two above because it replaces a whole function body rather
## than one call: which camera the viewport says is current. There is no viewport here, so the
## shipped guard would answer null for ever and the case worth pinning - a camera somebody ELSE
## made current - could never arise. The stand-in reads a field the test writes; the `on_screen`
## member it reads is appended to the rewritten text below.
const ON_SCREEN_BODY := [
	"if host == null or not host.is_inside_tree():\n\t\treturn null\n\treturn host.get_viewport().get_camera_3d()",
	"if host == null:\n\t\treturn null\n\treturn on_screen",
]


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _test_the_2d_rail() and all_passed
	all_passed = _test_the_3d_rail() and all_passed
	all_passed = _test_the_shared_curves() and all_passed
	all_passed = _test_the_emitted_calls() and all_passed
	all_passed = _test_the_row_sentences() and all_passed
	return all_passed


## What a Fly Along row READS as. Three facts on the row in both twins - the route, the pace, and
## (in 3D) what stays in frame - because a fourth slot turns a sentence into a settings line. The
## 3D twin's ease is the fact that stepped out: it is a word from a dropdown with the rail's own
## shot_ease behind it, so it reads in the parameter dialog, where Scene Flow's ease reads too.
static func _test_the_row_sentences() -> bool:
	var all_passed: bool = true
	for pinned: Array in [
		[PACK_2D, "fly along [i]{path}[/i] over [b]{seconds}[/b]s, [b]{ease}[/b]"],
		[PACK_3D, "fly along [i]{path}[/i] over [b]{seconds}[/b]s, watching [i]{look_at}[/i]"],
	]:
		var sentence: String = str(pinned[1])
		all_passed = _check("the pack ships the row sentence %s" % sentence,
			FileAccess.get_file_as_string(str(pinned[0])).contains(
				"## @ace_display_template(\"%s\")" % sentence), true) and all_passed
		all_passed = _check("and it carries three slots, not four",
			sentence.count("{"), 3) and all_passed
	return all_passed


## The call a picked row emits. The ease is a DROPDOWN over four words, and a dropdown key is
## inserted verbatim - so the shipped template has to write the quotes around it, or a row picking
## "Ease in" emits `fly_along($Route, 4, ease_in)` and the game will not parse. The four templates
## are read off the shipped packs and put through the compiler's own emitter, because a pin on the
## annotation text alone would not notice the emitter changing under it.
static func _test_the_emitted_calls() -> bool:
	var all_passed: bool = true
	for pinned: Array in [
		[PACK_2D, "$CameraRailBehavior.fly_along({path}, {seconds}, \"{ease}\")",
			"$CameraRailBehavior.fly_along($Route, 4.0, \"ease_in\")"],
		[PACK_2D, "$CameraRailBehavior.blend_to({camera}, {seconds}, \"{ease}\")",
			"$CameraRailBehavior.blend_to($Other, 4.0, \"ease_in\")"],
		[PACK_3D, "$CameraRail3DBehavior.fly_along({path}, {seconds}, \"{ease}\", {look_at})",
			"$CameraRail3DBehavior.fly_along($Route, 4.0, \"ease_in\", $Player)"],
		[PACK_3D, "$CameraRail3DBehavior.blend_to({camera}, {seconds}, \"{ease}\")",
			"$CameraRail3DBehavior.blend_to($Other, 4.0, \"ease_in\")"],
	]:
		var template: String = str(pinned[1])
		var shipped: String = FileAccess.get_file_as_string(str(pinned[0]))
		all_passed = _check("the pack ships %s" % template,
			shipped.contains("## @ace_codegen_template(\"%s\")" % template), true) and all_passed
		var action: ACEAction = ACEAction.new()
		action.provider_id = "CameraRail"
		action.ace_id = "method:pinned"
		action.codegen_template = template
		action.params = {"path": "$Route", "camera": "$Other", "seconds": "4.0", "ease": "ease_in",
			"look_at": "$Player"}
		all_passed = _check("a picked ease emits a word, not an identifier",
			ActionCodegen.generate_action(action), str(pinned[2])) and all_passed
	return all_passed


## The 2D rail, against real Camera2D and Path2D nodes. A CanvasItem's global transform is readable
## and writable outside a tree, so every value here is the shipped pack's own arithmetic.
static func _test_the_2d_rail() -> bool:
	var all_passed: bool = true
	var script: GDScript = load(PACK_2D)
	all_passed = _check("the 2D pack loads and parses", script != null, true) and all_passed
	if script == null:
		return all_passed

	var rail: Node = script.new()
	var camera: Camera2D = Camera2D.new()
	rail.set("host", camera)
	var shots: Array = [0]
	var blends: Array = [0]
	rail.connect("shot_finished", func() -> void: shots[0] += 1)
	rail.connect("blend_finished", func() -> void: blends[0] += 1)

	# ── Fly Along: a straight 400 px route walked over 4 seconds, linear, stepped a second at a time.
	var path: Path2D = Path2D.new()
	var curve: Curve2D = Curve2D.new()
	curve.add_point(Vector2.ZERO)
	curve.add_point(Vector2(400.0, 0.0))
	path.curve = curve
	rail.fly_along(path, 4.0, "linear")
	all_passed = _check("the flight starts at the route's first point", camera.global_position, Vector2.ZERO) and all_passed
	all_passed = _check("a flight that has not ticked has made no progress", rail.rail_progress(), 0.0) and all_passed
	all_passed = _check("the rail is flying", rail.is_flying(), true) and all_passed
	rail._process(1.0)
	all_passed = _check("a quarter of the seconds is a quarter of the progress", rail.rail_progress(), 0.25) and all_passed
	all_passed = _check("and a quarter of the route in pixels",
		camera.global_position.distance_to(Vector2(100.0, 0.0)) < 0.001, true) and all_passed
	rail._process(1.0)
	all_passed = _check("half the seconds is half the route",
		camera.global_position.distance_to(Vector2(200.0, 0.0)) < 0.001, true) and all_passed
	all_passed = _check("no shot has finished half way through one", shots[0], 0) and all_passed
	rail._process(2.0)
	all_passed = _check("the run ends on the route's last point",
		camera.global_position.distance_to(Vector2(400.0, 0.0)) < 0.001, true) and all_passed
	all_passed = _check("a finished shot reads as full progress", rail.rail_progress(), 1.0) and all_passed
	all_passed = _check("On Shot Finished fired once", shots[0], 1) and all_passed
	all_passed = _check("the rail is no longer flying", rail.is_flying(), false) and all_passed
	rail._process(1.0)
	all_passed = _check("a tick after the end fires nothing more", shots[0], 1) and all_passed

	# ── Blend To: the rail's camera travels onto another one and hands the view over.
	var target: Camera2D = Camera2D.new()
	target.position = Vector2(100.0, 50.0)
	target.rotation = 0.5
	target.zoom = Vector2(2.0, 2.0)
	camera.position = Vector2.ZERO
	camera.rotation = 0.0
	camera.zoom = Vector2.ONE
	rail.blend_to(target, 2.0, "linear")
	all_passed = _check("a blend is not a flight", rail.is_flying(), false) and all_passed
	rail._process(1.0)
	all_passed = _check("half way through the blend the camera is half way there",
		camera.global_position.distance_to(Vector2(50.0, 25.0)) < 0.001, true) and all_passed
	all_passed = _check("and half way through the zoom",
		camera.zoom.distance_to(Vector2(1.5, 1.5)) < 0.001, true) and all_passed
	all_passed = _check("the handover has not happened yet", blends[0], 0) and all_passed
	rail._process(1.0)
	all_passed = _check("the blend lands on the target's position",
		camera.global_position.distance_to(target.global_position) < 0.001, true) and all_passed
	all_passed = _check("and on its rotation",
		absf(camera.global_rotation - target.global_rotation) < 0.001, true) and all_passed
	all_passed = _check("and on its zoom", camera.zoom.distance_to(target.zoom) < 0.001, true) and all_passed
	all_passed = _check("On Blend Finished fired once", blends[0], 1) and all_passed
	all_passed = _check("the target holds the view", rail.get("_handed_to") == target, true) and all_passed
	rail._process(1.0)
	all_passed = _check("a tick after the handover fires nothing more", blends[0], 1) and all_passed
	all_passed = _check("and a blend never fires the shot trigger", shots[0], 1) and all_passed

	# ── Cut To: the hard cut. No tree here, so make_current is skipped and the pack's own record
	# of who holds the view is the thing to read.
	var third: Camera2D = Camera2D.new()
	rail.fly_along(path, 4.0, "linear")
	rail.cut_to(third)
	all_passed = _check("a cut ends the shot it interrupted", rail.is_flying(), false) and all_passed
	all_passed = _check("the cut camera holds the view", rail.get("_handed_to") == third, true) and all_passed
	all_passed = _check("and a cut announces nothing", shots[0], 1) and all_passed
	all_passed = _check("a cut to nothing is refused, not obeyed",
		_cut_to_null_keeps(rail, third), true) and all_passed

	# ── The view a shot runs on. make_current does nothing outside a scene tree, so what is read
	# here is the pack's own record of who holds the view - which is written whether or not there is
	# a tree, precisely so this question can be asked at all. The rule: a MOVING shot takes the view
	# (a flight or a blend nobody can see is not a shot), and a Hold leaves it exactly where it is,
	# because a hold after a cut is the beat on THAT camera.
	rail.cut_to(third)
	rail.fly_along(path, 4.0, "linear")
	all_passed = _check("a flight takes the view back for the rail's own camera",
		rail.get("_handed_to") == camera, true) and all_passed
	rail.stop_rail()
	rail.cut_to(third)
	rail.hold(1.0)
	all_passed = _check("a hold leaves the view where the cut put it",
		rail.get("_handed_to") == third, true) and all_passed
	rail.stop_rail()
	# A blend started while another camera holds the view stands ON that shot first, so the travel
	# is continuous instead of a jump to wherever the rail's camera was parked.
	third.global_position = Vector2(500.0, 300.0)
	third.zoom = Vector2(3.0, 3.0)
	camera.global_position = Vector2.ZERO
	camera.zoom = Vector2.ONE
	rail.cut_to(third)
	rail.blend_to(target, 2.0, "linear")
	all_passed = _check("a blend takes the view", rail.get("_handed_to") == camera, true) and all_passed
	all_passed = _check("and starts from the shot that was on screen",
		camera.global_position.distance_to(third.global_position) < 0.001, true) and all_passed
	all_passed = _check("zoom included", camera.zoom.distance_to(third.zoom) < 0.001, true) and all_passed
	rail.stop_rail()

	# ── A camera somebody ELSE made current. The rail's record only ever says who the RAIL handed
	# the view to: the builtin Make Current row, a juice pack, or one line of anybody's script can
	# make a camera current without telling it, and a blend that stood on the stale record would
	# open with exactly the snap Blend To exists to avoid. The live answer wins, and the record is
	# the fallback for when there is no viewport to ask.
	var stub: GDScript = _rail_that_can_be_told_what_is_on_screen()
	all_passed = _check("the told-what-is-on-screen rail compiles", stub != null, true) and all_passed
	if stub != null:
		var own: Camera2D = Camera2D.new()
		var told: Node = stub.new()
		told.set("host", own)
		var parked: Camera2D = Camera2D.new()
		parked.global_position = Vector2(10.0, 10.0)
		parked.zoom = Vector2(0.5, 0.5)
		var current: Camera2D = Camera2D.new()
		current.global_position = Vector2(900.0, 700.0)
		current.zoom = Vector2(4.0, 4.0)
		var destination: Camera2D = Camera2D.new()
		destination.global_position = Vector2(1200.0, 800.0)
		told.cut_to(parked)
		told.set("on_screen", current)
		told.blend_to(destination, 2.0, "linear")
		all_passed = _check("a blend starts from the camera that is actually current",
			own.global_position.distance_to(current.global_position) < 0.001, true) and all_passed
		all_passed = _check("with that camera's zoom, not the parked record's",
			own.zoom.distance_to(current.zoom) < 0.001, true) and all_passed
		all_passed = _check("and the pose the blend travels FROM is that camera's",
			(told.get("_blend_from_transform") as Transform2D).origin.distance_to(current.global_position) < 0.001,
			true) and all_passed
		told.stop_rail()
		told.set("on_screen", null)
		told.cut_to(parked)
		told.blend_to(destination, 2.0, "linear")
		all_passed = _check("with nothing current the rail's own record is still the fallback",
			own.global_position.distance_to(parked.global_position) < 0.001, true) and all_passed
		told.stop_rail()
		own.free()
		told.free()
		parked.free()
		current.free()
		destination.free()

	# ── Hold: the beat between two moves, and the one shot with nothing to move.
	rail.hold(0.5)
	rail._process(0.25)
	all_passed = _check("a hold reports its own progress", rail.rail_progress(), 0.5) and all_passed
	all_passed = _check("a hold is not a flight", rail.is_flying(), false) and all_passed
	rail._process(0.25)
	all_passed = _check("a finished hold fires On Shot Finished", shots[0], 2) and all_passed

	# ── Stop Rail: halts where it stands and says nothing.
	rail.fly_along(path, 4.0, "linear")
	rail._process(1.0)
	rail.stop_rail()
	all_passed = _check("a stopped rail is not flying", rail.is_flying(), false) and all_passed
	all_passed = _check("stopping announces nothing", shots[0], 2) and all_passed
	rail._process(10.0)
	all_passed = _check("and a stopped rail stays where it was left",
		camera.global_position.distance_to(Vector2(100.0, 0.0)) < 0.001, true) and all_passed

	# ── The Inspector's own defaults: an empty path, 0 seconds and no ease word fall back to them.
	rail.set("route", path)
	rail.set("shot_seconds", 2.0)
	rail.set("shot_ease", "ease_in_out")
	rail.fly_along(null, 0.0, "")
	all_passed = _check("an empty path walks the Inspector's route", rail.get("_flight_path") == path, true) and all_passed
	all_passed = _check("0 seconds takes the rail's default pace", rail.get("_duration"), 2.0) and all_passed
	all_passed = _check("no ease word takes the rail's default curve", rail.get("_ease"), "ease_in_out") and all_passed
	rail.stop_rail()

	# ── A route with nothing drawn on it is refused rather than dividing by a zero length. The
	# refusal leaves the shot that was running exactly where it was: it does not park it, and it
	# does not fire anything, which is why the pack warns instead of failing silently.
	var empty_path: Path2D = Path2D.new()
	empty_path.curve = Curve2D.new()
	rail.fly_along(empty_path, 1.0, "linear")
	all_passed = _check("a route with no length starts no flight", rail.is_flying(), false) and all_passed
	all_passed = _check("and the refusal is written down where a game can see it",
		FileAccess.get_file_as_string(PACK_2D).contains("push_warning(\"Camera Rail: Fly Along was handed no route"), true) and all_passed

	# ── A blend target freed mid-blend: the landing is skipped, because there is nothing left to
	# land on, but On Blend Finished still fires so the rows after it are not stranded.
	var doomed: Camera2D = Camera2D.new()
	doomed.position = Vector2(600.0, 0.0)
	var blends_before: int = blends[0]
	rail.blend_to(doomed, 2.0, "linear")
	rail._process(1.0)
	doomed.free()
	rail._process(0.1)
	all_passed = _check("a freed target ends the blend on the spot", rail.get("_mode"), "") and all_passed
	all_passed = _check("and the blend still announces itself", blends[0], blends_before + 1) and all_passed

	camera.free()
	target.free()
	third.free()
	path.free()
	empty_path.free()
	rail.free()
	return all_passed


## The 3D twin. Same shot list, plus the two things only 3D has: a node kept in frame while the
## camera flies, and a field of view that travels with the blend.
static func _test_the_3d_rail() -> bool:
	var all_passed: bool = true
	var shipped: String = FileAccess.get_file_as_string(PACK_3D)
	all_passed = _check("the 3D pack reads off disk", shipped.is_empty(), false) and all_passed

	# The seams a scene tree would supply, rewritten into the local frame. Order matters: the two
	# calls are replaced first, while they still spell their arguments the shipped way.
	var text: String = shipped
	for swap: Array in TREE_CALLS:
		all_passed = _check("the shipped pack still spells %s the way the rewrite expects" % str(swap[0]),
			text.contains(str(swap[0])), true) and all_passed
		text = text.replace(str(swap[0]), str(swap[1]))
	all_passed = _check("the shipped pack still asks the viewport which camera is current",
		text.contains(str(ON_SCREEN_BODY[0])), true) and all_passed
	text = text.replace(str(ON_SCREEN_BODY[0]), str(ON_SCREEN_BODY[1]))
	text = text.replace("global_transform", "transform").replace("global_position", "position")
	text = text.replace("class_name CameraRail3DBehavior\n", "")
	all_passed = _check("the rewrite fired", text == shipped, false) and all_passed
	all_passed = _check("and nothing global is left to fail on a missing tree",
		text.contains("global_"), false) and all_passed
	# The field the stand-in above reads. Appended rather than woven in, because a member variable
	# is legal anywhere at the top level and none of the pack's own bytes move for it.
	text += "\n\nvar on_screen: Camera3D = null\n"

	var script: GDScript = GDScript.new()
	script.source_code = text
	var compiled: int = script.reload()
	all_passed = _check("the rewritten pack compiles", compiled, OK) and all_passed
	if compiled != OK:
		return all_passed

	var rail: Node = script.new()
	var camera: Camera3D = Camera3D.new()
	camera.fov = 60.0
	rail.set("host", camera)
	var shots: Array = [0]
	var blends: Array = [0]
	rail.connect("shot_finished", func() -> void: shots[0] += 1)
	rail.connect("blend_finished", func() -> void: blends[0] += 1)

	# ── Fly Along: a straight 10 m route walked over 4 seconds, linear, with nothing to watch.
	var path: Path3D = Path3D.new()
	var curve: Curve3D = Curve3D.new()
	curve.add_point(Vector3.ZERO)
	curve.add_point(Vector3(10.0, 0.0, 0.0))
	path.curve = curve
	rail.fly_along(path, 4.0, "linear", null)
	all_passed = _check("the flight starts at the route's first point", camera.position, Vector3.ZERO) and all_passed
	all_passed = _check("the rail is flying", rail.is_flying(), true) and all_passed
	rail._process(1.0)
	all_passed = _check("a quarter of the seconds is a quarter of the progress", rail.rail_progress(), 0.25) and all_passed
	all_passed = _check("and a quarter of the route in metres",
		camera.position.distance_to(Vector3(2.5, 0.0, 0.0)) < 0.001, true) and all_passed
	rail._process(3.0)
	all_passed = _check("the run ends on the route's last point",
		camera.position.distance_to(Vector3(10.0, 0.0, 0.0)) < 0.001, true) and all_passed
	all_passed = _check("On Shot Finished fired once", shots[0], 1) and all_passed

	# ── The node kept in frame: the camera's forward axis points at it, all the way along.
	var focus: Node3D = Node3D.new()
	focus.position = Vector3(0.0, 0.0, -10.0)
	rail.fly_along(path, 4.0, "linear", focus)
	all_passed = _check("the watched node is remembered", rail.get("_flight_look_at") == focus, true) and all_passed
	rail._process(1.0)
	var forward: Vector3 = -camera.transform.basis.z
	var toward_focus: Vector3 = (focus.position - camera.position).normalized()
	all_passed = _check("the camera faces what it is watching",
		forward.distance_to(toward_focus) < 0.001, true) and all_passed
	rail.stop_rail()

	# ── Blend To: transform AND field of view travel together, then the target takes the view.
	var target: Camera3D = Camera3D.new()
	target.position = Vector3(4.0, 2.0, 0.0)
	target.fov = 80.0
	camera.transform = Transform3D.IDENTITY
	camera.fov = 60.0
	rail.blend_to(target, 2.0, "linear")
	rail._process(1.0)
	all_passed = _check("half way through the blend the camera is half way there",
		camera.position.distance_to(Vector3(2.0, 1.0, 0.0)) < 0.001, true) and all_passed
	all_passed = _check("and half way through the lens", absf(camera.fov - 70.0) < 0.001, true) and all_passed
	all_passed = _check("the handover has not happened yet", blends[0], 0) and all_passed
	rail._process(1.0)
	all_passed = _check("the blend lands on the target's transform",
		camera.position.distance_to(target.position) < 0.001, true) and all_passed
	all_passed = _check("and on its field of view", absf(camera.fov - target.fov) < 0.001, true) and all_passed
	all_passed = _check("On Blend Finished fired once", blends[0], 1) and all_passed
	all_passed = _check("the target holds the view", rail.get("_handed_to") == target, true) and all_passed
	rail._process(1.0)
	all_passed = _check("a tick after the handover fires nothing more", blends[0], 1) and all_passed

	# ── Cut To, Hold and Stop Rail read exactly as they do in 2D.
	var third: Camera3D = Camera3D.new()
	rail.fly_along(path, 4.0, "linear", null)
	rail.cut_to(third)
	all_passed = _check("a cut ends the shot it interrupted", rail.is_flying(), false) and all_passed
	all_passed = _check("the cut camera holds the view", rail.get("_handed_to") == third, true) and all_passed
	rail.hold(0.5)
	rail._process(0.5)
	all_passed = _check("a finished hold fires On Shot Finished", shots[0], 2) and all_passed
	rail.fly_along(path, 4.0, "linear", null)
	rail.stop_rail()
	all_passed = _check("stopping announces nothing", shots[0], 2) and all_passed

	# ── The view a shot runs on, exactly as in 2D: a moving shot takes it, a hold leaves it, and a
	# blend stands on the shot that was up before it travels - the field of view with it.
	third.position = Vector3(0.0, 8.0, 12.0)
	third.fov = 40.0
	camera.transform = Transform3D.IDENTITY
	camera.fov = 60.0
	rail.cut_to(third)
	rail.hold(1.0)
	all_passed = _check("a hold leaves the view where the cut put it",
		rail.get("_handed_to") == third, true) and all_passed
	rail.stop_rail()
	rail.cut_to(third)
	rail.blend_to(target, 2.0, "linear")
	all_passed = _check("a blend takes the view", rail.get("_handed_to") == camera, true) and all_passed
	all_passed = _check("and starts from the shot that was on screen",
		camera.position.distance_to(third.position) < 0.001, true) and all_passed
	all_passed = _check("field of view included", absf(camera.fov - third.fov) < 0.001, true) and all_passed
	rail.stop_rail()

	# ── And the same rule as in 2D for a camera somebody ELSE made current: the live answer beats
	# the rail's own record of who it handed the view to, which is stale the moment another row or
	# another script makes a camera current without saying so.
	var elsewhere: Camera3D = Camera3D.new()
	elsewhere.position = Vector3(0.0, 20.0, 40.0)
	elsewhere.fov = 25.0
	camera.transform = Transform3D.IDENTITY
	camera.fov = 60.0
	rail.cut_to(third)
	rail.set("on_screen", elsewhere)
	rail.blend_to(target, 2.0, "linear")
	all_passed = _check("a blend starts from the camera that is actually current",
		camera.position.distance_to(elsewhere.position) < 0.001, true) and all_passed
	all_passed = _check("with that camera's lens, not the parked record's",
		absf(camera.fov - elsewhere.fov) < 0.001, true) and all_passed
	rail.stop_rail()
	rail.set("on_screen", null)
	rail.cut_to(third)
	rail.blend_to(target, 2.0, "linear")
	all_passed = _check("with nothing current the rail's own record is still the fallback",
		camera.position.distance_to(third.position) < 0.001, true) and all_passed
	rail.stop_rail()
	rail.cut_to(third)
	rail.fly_along(path, 4.0, "linear", null)
	all_passed = _check("a flight takes the view back for the rail's own camera",
		rail.get("_handed_to") == camera, true) and all_passed
	rail.stop_rail()

	camera.free()
	target.free()
	third.free()
	focus.free()
	elsewhere.free()
	path.free()
	rail.free()
	return all_passed


## The four shot curves, pinned on the shipped 2D pack. They are the same four words in both twins,
## and an unknown word is deliberately LINEAR rather than a frozen shot.
static func _test_the_shared_curves() -> bool:
	var all_passed: bool = true
	var rail: Node = (load(PACK_2D) as GDScript).new()
	all_passed = _check("linear is the straight fraction", rail._eased(0.5, "linear"), 0.5) and all_passed
	all_passed = _check("ease in starts slow", rail._eased(0.5, "ease_in"), 0.25) and all_passed
	all_passed = _check("ease out ends slow", rail._eased(0.5, "ease_out"), 0.75) and all_passed
	all_passed = _check("ease in and out is symmetrical at the middle",
		rail._eased(0.5, "ease_in_out"), 0.5) and all_passed
	all_passed = _check("and it is slower than linear a quarter in",
		rail._eased(0.25, "ease_in_out") < 0.25, true) and all_passed
	all_passed = _check("a word nobody knows plays the shot straight",
		rail._eased(0.5, "wobble"), 0.5) and all_passed
	all_passed = _check("a fraction past the end is clamped", rail._eased(2.0, "linear"), 1.0) and all_passed
	rail.free()
	return all_passed


## The shipped 2D rail, subclassed, with the one function that asks the viewport which camera is
## current answering a field instead. A headless test has no viewport - and the pack asks that
## question through a function of its own precisely so the answer can be stood in for here, which
## is what makes "somebody else made a camera current" a case with a value to pin at all.
static func _rail_that_can_be_told_what_is_on_screen() -> GDScript:
	var script: GDScript = GDScript.new()
	script.source_code = "extends \"%s\"\n\n\nvar on_screen: Camera2D = null\n\n\nfunc _camera_on_screen() -> Camera2D:\n\treturn on_screen\n" % PACK_2D
	return script if script.reload() == OK else null


## Cut To with no camera must change nothing - the record of who holds the view survives it.
static func _cut_to_null_keeps(rail: Node, held: Camera2D) -> bool:
	rail.cut_to(null)
	return rail.get("_handed_to") == held


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("camera_rail_pack_test", label, actual, expected)
