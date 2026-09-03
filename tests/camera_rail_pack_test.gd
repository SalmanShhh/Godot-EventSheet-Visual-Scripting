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
# half passing for the wrong reason.
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


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _test_the_2d_rail() and all_passed
	all_passed = _test_the_3d_rail() and all_passed
	all_passed = _test_the_shared_curves() and all_passed
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

	# ── A route with nothing drawn on it is refused rather than dividing by a zero length.
	var empty_path: Path2D = Path2D.new()
	empty_path.curve = Curve2D.new()
	rail.fly_along(empty_path, 1.0, "linear")
	all_passed = _check("a route with no length starts no flight", rail.is_flying(), false) and all_passed

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
	text = text.replace("global_transform", "transform").replace("global_position", "position")
	text = text.replace("class_name CameraRail3DBehavior\n", "")
	all_passed = _check("the rewrite fired", text == shipped, false) and all_passed
	all_passed = _check("and nothing global is left to fail on a missing tree",
		text.contains("global_"), false) and all_passed

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
	rail.cut_to(third)
	rail.fly_along(path, 4.0, "linear", null)
	all_passed = _check("a flight takes the view back for the rail's own camera",
		rail.get("_handed_to") == camera, true) and all_passed
	rail.stop_rail()

	camera.free()
	target.free()
	third.free()
	focus.free()
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


## Cut To with no camera must change nothing - the record of who holds the view survives it.
static func _cut_to_null_keeps(rail: Node, held: Camera2D) -> bool:
	rail.cut_to(null)
	return rail.get("_handed_to") == held


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("camera_rail_pack_test", label, actual, expected)
