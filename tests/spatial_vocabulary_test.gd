# Godot EventSheets - the spatial vocabulary (addons/eventforge/registration/modules/spatial_aces.gd)
# and its Follow Path pack sibling (eventsheet_addons/follow_path/).
#
# Every verb is held to two gates, because either one alone lies:
#   1. THE EMITTED CODE is pinned character for character. A template is API the moment it ships -
#      a sheet stores it - so a "harmless" tidy-up here is a silent behaviour change in someone
#      else's game.
#   2. THE BEHAVIOUR IS RUN, including the edge case the verb's own blurb promises: the falloff
#      that reads 0 past its radius, the Look At that does not crash when the target is directly
#      overhead, the scatter that does NOT bunch at the centre, the 3D projection that reads zero
#      rather than faulting when no camera exists.
#
# The suite has no scene tree (run_tests' _init runs before the main loop exists), so a template is
# run inside a generated stub host that declares exactly the members the emitted line touches -
# global_position, get_viewport(), get_tree().get_nodes_in_group(), apply_impulse(), look_at().
# That is enough to prove the maths; that the same line compiles inside its REAL declared host is
# builtin_ace_compile_test's job, and the two together cover the whole claim.
#
# The Follow Path trigger is proved the way a trigger must be: the signal is looked up in the
# script's own signal list, connected to, and the run driven frame by frame until it fires - once,
# at the end, and never for a Loop or Ping-pong run that has no end.
@tool
class_name SpatialVocabularyTest
extends RefCounted

const PACK_PATH := "res://eventsheet_addons/follow_path/path_follow_behavior.gd"

## Loaded by PATH, not by class name: a module added in this same change is not in the editor's
## class cache during a headless run, and a global-name reference would resolve to null there.
const SPATIAL := preload("res://addons/eventforge/registration/modules/spatial_aces.gd")

## Members the 2D templates reach for. `__parent` stands in for the get_parent() default the
## node-facing verbs ship with, and the impulse/group stubs record what an ACTION did.
const SCAFFOLD_2D := """
var global_position: Vector2 = Vector2.ZERO
var rotation: float = 0.0
var __parent: Node2D = null
var __members: Array = []
var __impulses: Array = []
func get_parent() -> Variant:
	return __parent
func get_tree() -> Variant:
	return self
func get_nodes_in_group(_group_name: String) -> Array:
	return __members
func apply_impulse(impulse: Vector2) -> void:
	__impulses.append(impulse)
"""

## The 3D half: a Vector3 position, and a look_at that RECORDS its arguments instead of rotating -
## which is how the safe-up fix is provable at all, since the whole point is which up vector was
## chosen.
const SCAFFOLD_3D := """
var global_position: Vector3 = Vector3.ZERO
var __looks: Array = []
func look_at(target: Vector3, up: Vector3) -> void:
	__looks.append([target, up])
"""

## How many samples every statistical claim is judged on. Large enough that an area-correct
## distribution cannot pass by luck and a wrong one cannot fail by it.
const SAMPLES := 4000


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _test_registration() and all_passed
	all_passed = _test_screen_and_world() and all_passed
	all_passed = _test_random_geometry() and all_passed
	all_passed = _test_surfaces() and all_passed
	all_passed = _test_grid() and all_passed
	all_passed = _test_falloff() and all_passed
	all_passed = _test_follow_path_verbs() and all_passed
	all_passed = _test_follow_path_trigger() and all_passed
	return all_passed


# ── registration ──────────────────────────────────────────────────────────────────────────────


## The module reaches the live registry, and the node-scoped verbs came through the builtin
## "On node" pass UNCHANGED. That pass prefixes every line of a node-scoped template with
## `{target.}`; on maths that reads THIS node's own position it would answer for the wrong node,
## so each of these templates is deliberately shaped (a leading statement keyword, or an opening
## bracket) to be skipped. If that shaping is ever lost the prefix reappears here, silently.
static func _test_registration() -> bool:
	var all_passed: bool = true
	var shipped: Dictionary = _shipped()
	all_passed = _check("the spatial module reaches the live registry",
		shipped.has("WorldPointToScreen"), true) and all_passed
	all_passed = _check("the module ships the whole family",
		_module_ids().size(), 47) and all_passed
	for ace_id: String in ["WrapInsideView3D", "FaceAlongVelocity", "LookAtSafeUp", "LookAtFlat",
			"StrengthToward", "ApplyRadialImpulse", "PushGroupAwayFrom"]:
		var descriptor: ACEDescriptor = shipped.get(ace_id, null)
		all_passed = _check("%s keeps its authored template (no {target.} prefix)" % ace_id,
			str(descriptor.codegen_template).contains("{target.}"), false) and all_passed
		all_passed = _check("%s gained no On node param" % ace_id,
			_param_labels(descriptor).has("On node"), false) and all_passed
	# The looping condition is a REAL loop row, not a bool dressed as one: the pick machinery reads
	# these two fields, and the iterator name is what the guide tells readers to type.
	var loop: ACEDescriptor = shipped.get("ForEachCellInRadius", null)
	all_passed = _check("For Each Cell In Radius registers as a looping condition",
		loop.is_looping, true) and all_passed
	all_passed = _check("its items arrive under the name the guide promises",
		loop.looping_iterator, "cell") and all_passed
	all_passed = _check("it is a CONDITION, so it lands in the left lane",
		loop.ace_type, ACEDescriptor.ACEType.CONDITION) and all_passed
	all_passed = _check("the loop and the plain list expression cannot disagree",
		str(loop.codegen_template), str((shipped.get("CellsInRadius", null) as ACEDescriptor).codegen_template)) and all_passed
	return all_passed


# ── 1. screen and world ───────────────────────────────────────────────────────────────────────


## A view scrolled to -100,-50 and zoomed 2x, which is the only honest way to test these: an
## identity transform would pass even if the canvas transform were dropped from the template. The
## stub host answers get_viewport() with ITSELF, so no real Viewport - and no rendering server - is
## involved; there is no scene tree here to put one in.
const VIEW := {
	"__view_transform": Transform2D(0.0, Vector2(2.0, 2.0), 0.0, Vector2(-100.0, -50.0)),
	"__view_rect": Rect2(0.0, 0.0, 320.0, 200.0)
}


static func _test_screen_and_world() -> bool:
	var all_passed: bool = true
	var to_screen: String = _emit("WorldPointToScreen", {"world_point": "Vector2(64, 32)"})
	all_passed = _check("World Point To Screen emits the canvas transform",
		to_screen, "(get_viewport().get_canvas_transform() * Vector2(64, 32))") and all_passed
	all_passed = _check("World Point To Screen answers with the zoom and scroll applied",
		_value(to_screen, SCAFFOLD_2D, VIEW), Vector2(28, 14)) and all_passed

	var to_world: String = _emit("ScreenPointToWorld", {"screen_point": "Vector2(10, 20)"})
	all_passed = _check("Screen Point To World emits the inverse transform",
		to_world, "(get_viewport().get_canvas_transform().affine_inverse() * Vector2(10, 20))") and all_passed
	all_passed = _check("Screen Point To World is the exact opposite, so the pair round-trips",
		_value(to_world, SCAFFOLD_2D, VIEW), Vector2(55, 35)) and all_passed

	var project: String = _emit("ProjectToScreen3D", {"world_point": "Vector3(1, 2, 3)"})
	all_passed = _check("Project To Screen (3D) emits a camera-guarded projection",
		project, "(get_viewport().get_camera_3d().unproject_position(Vector3(1, 2, 3)) if get_viewport().get_camera_3d() != null else Vector2.ZERO)") and all_passed
	all_passed = _check("Project To Screen (3D) reads zero rather than faulting with no camera",
		_value(project, SCAFFOLD_3D, VIEW), Vector2.ZERO) and all_passed

	var on_screen: String = _emit("IsPointOnScreen", {"world_point": "Vector2(64, 32)", "margin": "8.0"})
	all_passed = _check("Is Point On Screen emits a grown-rect test",
		on_screen, "get_viewport().get_visible_rect().grow(8.0).has_point(get_viewport().get_canvas_transform() * Vector2(64, 32))") and all_passed
	all_passed = _check("Is Point On Screen is true for a point in view",
		_value(on_screen, SCAFFOLD_2D, VIEW), true) and all_passed
	all_passed = _check("Is Point On Screen is false once the point leaves the view",
		_value(_emit("IsPointOnScreen", {"world_point": "Vector2(900, 32)", "margin": "0.0"}), SCAFFOLD_2D, VIEW), false) and all_passed
	all_passed = _check("a margin buys the slack it promises",
		_value(_emit("IsPointOnScreen", {"world_point": "Vector2(900, 32)", "margin": "2000.0"}), SCAFFOLD_2D, VIEW), true) and all_passed

	var behind: String = _emit("IsBehindCamera3D", {"world_point": "Vector3(1, 2, 3)"})
	all_passed = _check("Is Behind Camera (3D) emits the null-guarded check",
		behind, "(get_viewport().get_camera_3d() == null or get_viewport().get_camera_3d().is_position_behind(Vector3(1, 2, 3)))") and all_passed
	all_passed = _check("with no camera it reads true, so nothing draws into a view that is not there",
		_value(behind, SCAFFOLD_3D, VIEW), true) and all_passed

	var edge: String = _emit("ScreenEdgePositionFor", {"world_point": "Vector2(1000, 20)", "margin": "48.0"})
	all_passed = _check("Screen Edge Position For emits a clamp into the view",
		edge, "((get_viewport().get_canvas_transform() * Vector2(1000, 20)).clamp(Vector2(48.0, 48.0), get_viewport().get_visible_rect().size - Vector2(48.0, 48.0)))") and all_passed
	all_passed = _check("an off-screen target parks the marker on the edge, inside the margin",
		_value(edge, SCAFFOLD_2D, VIEW), Vector2(272, 48)) and all_passed
	all_passed = _check("a visible target is followed exactly instead of being clamped",
		_value(_emit("ScreenEdgePositionFor", {"world_point": "Vector2(100, 60)", "margin": "48.0"}), SCAFFOLD_2D, VIEW), Vector2(100, 70)) and all_passed

	var marker: String = _emit("MarkerAngleToward", {"world_point": "Vector2(1000, 100)"})
	all_passed = _check("Marker Angle Toward emits an angle from the middle of the view",
		marker, "rad_to_deg(((get_viewport().get_canvas_transform() * Vector2(1000, 100)) - get_viewport().get_visible_rect().size * 0.5).angle())") and all_passed
	all_passed = _check("a target straight right of the middle reads as 0 degrees",
		_value(_emit("MarkerAngleToward", {"world_point": "Vector2(180, 75)"}), SCAFFOLD_2D, VIEW), 0.0) and all_passed
	all_passed = _check("a target straight below the middle reads as 90 degrees",
		roundi(float(_value(_emit("MarkerAngleToward", {"world_point": "Vector2(130, 125)"}), SCAFFOLD_2D, VIEW)) * 1000.0), 90000) and all_passed

	var world_rect: String = _emit("VisibleWorldRect", {})
	all_passed = _check("Visible World Rect emits the inverted view rectangle",
		world_rect, "(get_viewport().get_canvas_transform().affine_inverse() * get_viewport().get_visible_rect())") and all_passed
	all_passed = _check("Visible World Rect answers in world units, zoom included",
		_value(world_rect, SCAFFOLD_2D, VIEW), Rect2(50, 25, 160, 100)) and all_passed

	var wrap: String = _emit("WrapInsideView3D", {"uid": "7"})
	all_passed = _check("Wrap Inside The View (3D) emits a camera-guarded wrap",
		wrap, "var __view_cam_7: Camera3D = get_viewport().get_camera_3d()\nif __view_cam_7 != null:\n\tvar __view_size_7: Vector2 = get_viewport().get_visible_rect().size\n\tvar __view_at_7: Vector2 = __view_cam_7.unproject_position(global_position)\n\tif not Rect2(Vector2.ZERO, __view_size_7).has_point(__view_at_7):\n\t\tglobal_position = __view_cam_7.project_position(Vector2(wrapf(__view_at_7.x, 0.0, __view_size_7.x), wrapf(__view_at_7.y, 0.0, __view_size_7.y)), __view_cam_7.global_position.distance_to(global_position))") and all_passed
	var wrapped: Object = _after(wrap, SCAFFOLD_3D, {"global_position": Vector3(1, 2, 3), "__view_transform": VIEW["__view_transform"], "__view_rect": VIEW["__view_rect"]})
	all_passed = _check("with no 3D camera it leaves the node exactly where it was",
		wrapped.get("global_position"), Vector3(1, 2, 3)) and all_passed

	return all_passed


# ── 2. random geometry ────────────────────────────────────────────────────────────────────────


static func _test_random_geometry() -> bool:
	var all_passed: bool = true

	var circle: String = _emit("RandomPointInCircle", {"center": "Vector2(100, 100)", "radius": "50.0"})
	all_passed = _check("Random Point In Circle emits the sqrt-weighted polar form",
		circle, "(Vector2(100, 100) + Vector2.RIGHT.rotated(randf() * TAU) * (sqrt(randf()) * 50.0))") and all_passed
	var circle_points: Array = _samples(circle)
	all_passed = _check("every point lands inside the circle",
		_all_true(circle_points, func(p: Variant) -> bool: return (p as Vector2).distance_to(Vector2(100, 100)) <= 50.0001), true) and all_passed
	# THE promise: the obvious "random angle + random radius" puts HALF the points inside the inner
	# half-radius, which holds only a quarter of the area. Area-correct scatter puts a quarter there.
	var inner: float = _fraction(circle_points, func(p: Variant) -> bool: return (p as Vector2).distance_to(Vector2(100, 100)) <= 25.0)
	all_passed = _check("scatter does not bunch at the centre (inner quarter holds under 35 percent)",
		inner < 0.35, true) and all_passed
	all_passed = _check("nor does it hollow out the middle (inner quarter holds over 15 percent)",
		inner > 0.15, true) and all_passed

	var on_circle: String = _emit("RandomPointOnCircle", {"center": "Vector2(100, 100)", "radius": "50.0"})
	all_passed = _check("Random Point On Circle emits the un-weighted rim form",
		on_circle, "(Vector2(100, 100) + Vector2.RIGHT.rotated(randf() * TAU) * 50.0)") and all_passed
	all_passed = _check("every point sits exactly on the rim, never inside it",
		_all_true(_samples(on_circle), func(p: Variant) -> bool: return absf((p as Vector2).distance_to(Vector2(100, 100)) - 50.0) < 0.001), true) and all_passed

	var ring: String = _emit("RandomPointInRing", {"center": "Vector2.ZERO", "inner_radius": "100.0", "outer_radius": "200.0"})
	all_passed = _check("Random Point In Ring emits the area-correct band form",
		ring, "(Vector2.ZERO + Vector2.RIGHT.rotated(randf() * TAU) * sqrt(lerpf(100.0 * 100.0, 200.0 * 200.0, randf())))") and all_passed
	var ring_points: Array = _samples(ring)
	all_passed = _check("nothing spawns inside the hole and nothing beyond the rim",
		_all_true(ring_points, func(p: Variant) -> bool:
			var d: float = (p as Vector2).length()
			return d >= 99.999 and d <= 200.001), true) and all_passed
	all_passed = _check("the band is evenly filled, not crowded against its inner edge",
		_fraction(ring_points, func(p: Variant) -> bool: return (p as Vector2).length() <= 150.0) < 0.45, true) and all_passed

	var rect: String = _emit("RandomPointInRectangle", {"top_left": "Vector2(10, 20)", "size": "Vector2(100, 50)"})
	all_passed = _check("Random Point In Rectangle emits a per-axis roll",
		rect, "(Vector2(10, 20) + Vector2(randf() * Vector2(100, 50).x, randf() * Vector2(100, 50).y))") and all_passed
	all_passed = _check("every point lands inside the rectangle",
		_all_true(_samples(rect), func(p: Variant) -> bool: return Rect2(10, 20, 100, 50).has_point(p as Vector2)), true) and all_passed

	var cone: String = _emit("RandomPointInCone", {"center": "Vector2.ZERO", "facing_degrees": "0.0", "spread_degrees": "30.0", "radius": "100.0"})
	all_passed = _check("Random Point In Cone emits the degrees-in, radians-out wedge",
		cone, "(Vector2.ZERO + Vector2.RIGHT.rotated(deg_to_rad(0.0) + randf_range(-deg_to_rad(30.0) * 0.5, deg_to_rad(30.0) * 0.5)) * (sqrt(randf()) * 100.0))") and all_passed
	all_passed = _check("every point is inside the wedge, half the spread either side of facing",
		_all_true(_samples(cone), func(p: Variant) -> bool:
			return absf(rad_to_deg((p as Vector2).angle())) <= 15.001 and (p as Vector2).length() <= 100.001), true) and all_passed

	var around: String = _emit("RandomPointAround", {"node": "get_parent()", "min_radius": "10.0", "max_radius": "20.0"})
	all_passed = _check("Random Point Around emits a node-relative band",
		around, "(get_parent().global_position + Vector2.RIGHT.rotated(randf() * TAU) * sqrt(lerpf(10.0 * 10.0, 20.0 * 20.0, randf())))") and all_passed
	var anchor: Node2D = Node2D.new()
	anchor.global_position = Vector2(500, 500)
	all_passed = _check("the scatter follows the node it is anchored to",
		_all_true(_samples(around, SCAFFOLD_2D, {"__parent": anchor}), func(p: Variant) -> bool:
			var d: float = (p as Vector2).distance_to(Vector2(500, 500))
			return d >= 9.999 and d <= 20.001), true) and all_passed
	anchor.free()

	var direction_2d: String = _emit("RandomDirection2D", {})
	all_passed = _check("Random Direction (2D) emits a rotated unit vector",
		direction_2d, "Vector2.RIGHT.rotated(randf() * TAU)") and all_passed
	all_passed = _check("it is always exactly one unit long, so a speed stays where you set it",
		_all_true(_samples(direction_2d), func(p: Variant) -> bool: return absf((p as Vector2).length() - 1.0) < 0.001), true) and all_passed

	var direction_3d: String = _emit("RandomDirection3D", {})
	all_passed = _check("Random Direction (3D) emits the two-rotation sphere form",
		direction_3d, "Vector3.UP.rotated(Vector3.RIGHT, acos(randf_range(-1.0, 1.0))).rotated(Vector3.UP, randf() * TAU)") and all_passed
	var directions: Array = _samples(direction_3d)
	all_passed = _check("every 3D direction is one unit long",
		_all_true(directions, func(p: Variant) -> bool: return absf((p as Vector3).length() - 1.0) < 0.001), true) and all_passed
	# Even over the whole sphere: exactly half the directions should have a positive height, which
	# the crowded three-random-numbers version also passes - so the tighter test is the middle band,
	# which holds half the surface of a sphere and only a third of a cube's.
	all_passed = _check("the spread is even over the sphere, not crowded toward the poles",
		absf(_fraction(directions, func(p: Variant) -> bool: return absf((p as Vector3).y) <= 0.5) - 0.5) < 0.05, true) and all_passed

	var sphere: String = _emit("RandomPointInSphere", {"center": "Vector3.ZERO", "radius": "5.0"})
	all_passed = _check("Random Point In Sphere emits the cube-root-weighted form",
		sphere, "(Vector3.ZERO + Vector3.UP.rotated(Vector3.RIGHT, acos(randf_range(-1.0, 1.0))).rotated(Vector3.UP, randf() * TAU) * (pow(randf(), 1.0 / 3.0) * 5.0))") and all_passed
	var sphere_points: Array = _samples(sphere)
	all_passed = _check("every point is inside the sphere",
		_all_true(sphere_points, func(p: Variant) -> bool: return (p as Vector3).length() <= 5.0001), true) and all_passed
	all_passed = _check("the middle does not fill up first (inner half holds under 20 percent)",
		_fraction(sphere_points, func(p: Variant) -> bool: return (p as Vector3).length() <= 2.5) < 0.20, true) and all_passed

	var box: String = _emit("RandomPointInBox", {"center": "Vector3.ZERO", "size": "Vector3(10, 4, 10)"})
	all_passed = _check("Random Point In Box emits a per-axis roll around the centre",
		box, "(Vector3.ZERO + Vector3(randf_range(-1.0, 1.0) * Vector3(10, 4, 10).x, randf_range(-1.0, 1.0) * Vector3(10, 4, 10).y, randf_range(-1.0, 1.0) * Vector3(10, 4, 10).z) * 0.5)") and all_passed
	all_passed = _check("size means the FULL box, measured around the centre",
		_all_true(_samples(box), func(p: Variant) -> bool:
			var v: Vector3 = p as Vector3
			return absf(v.x) <= 5.001 and absf(v.y) <= 2.001 and absf(v.z) <= 5.001), true) and all_passed

	var screen_edge: String = _emit("RandomPointOnScreenEdge", {})
	all_passed = _check("Random Point On Screen Edge emits a perimeter roll over the world rect",
		screen_edge, "((get_viewport().get_canvas_transform().affine_inverse() * get_viewport().get_visible_rect()).position + (get_viewport().get_canvas_transform().affine_inverse() * get_viewport().get_visible_rect()).size * [Vector2(randf(), 0.0), Vector2(randf(), 1.0), Vector2(0.0, randf()), Vector2(1.0, randf())][randi() % 4])") and all_passed
	all_passed = _check("every point lands on the border of what the camera can see",
		_all_true(_samples(screen_edge, SCAFFOLD_2D, VIEW), func(p: Variant) -> bool:
			var v: Vector2 = p as Vector2
			return absf(v.x - 50.0) < 0.001 or absf(v.x - 210.0) < 0.001 or absf(v.y - 25.0) < 0.001 or absf(v.y - 125.0) < 0.001), true) and all_passed

	var jitter: String = _emit("JitterValue", {"value": "100.0", "amount": "5.0"})
	all_passed = _check("Jitter emits a symmetric nudge",
		jitter, "(100.0 + 5.0 * randf_range(-1.0, 1.0))") and all_passed
	all_passed = _check("the nudge never exceeds the amount given",
		_all_true(_samples(jitter), func(v: Variant) -> bool: return float(v) >= 95.0 and float(v) <= 105.0), true) and all_passed
	all_passed = _check("and it works on a vector as readily as a number",
		_all_true(_samples(_emit("JitterValue", {"value": "Vector2(10, 10)", "amount": "Vector2(2, 2)"})), func(v: Variant) -> bool:
			return (v as Vector2).distance_to(Vector2(10, 10)) <= 2.83), true) and all_passed
	return all_passed


# ── 3. bounce, slide and aim ──────────────────────────────────────────────────────────────────


static func _test_surfaces() -> bool:
	var all_passed: bool = true

	var bounce: String = _emit("BounceOffSurface", {"velocity": "Vector2(10, -5)", "normal": "Vector2.UP", "bounciness": "0.5"})
	all_passed = _check("Bounce Off Surface emits a normalised bounce times the bounciness",
		bounce, "(Vector2(10, -5).bounce(Vector2.UP.normalized()) * 0.5)") and all_passed
	all_passed = _check("the velocity comes back reflected and scaled",
		_value(bounce), Vector2(5, 2.5)) and all_passed
	all_passed = _check("bounciness 0 is the dead stop the blurb promises",
		_value(_emit("BounceOffSurface", {"velocity": "Vector2(10, -5)", "normal": "Vector2.UP", "bounciness": "0.0"})), Vector2.ZERO) and all_passed

	var slide: String = _emit("SlideAlongSurface", {"velocity": "Vector2(10, -5)", "normal": "Vector2.UP"})
	all_passed = _check("Slide Along Surface emits a normalised slide",
		slide, "(Vector2(10, -5).slide(Vector2.UP.normalized()))") and all_passed
	all_passed = _check("only the part pushing into the surface is removed",
		_value(slide), Vector2(10, 0)) and all_passed

	var reflected: String = _emit("AngleReflected", {"degrees": "45.0", "normal": "Vector2.UP"})
	all_passed = _check("Angle Reflected emits degrees in and degrees out",
		reflected, "rad_to_deg(Vector2.RIGHT.rotated(deg_to_rad(45.0)).bounce(Vector2.UP.normalized()).angle())") and all_passed
	all_passed = _check("45 degrees into a floor comes back out at -45",
		roundi(float(_value(reflected)) * 1000.0), -45000) and all_passed

	var push_out: String = _emit("PushOutOfSurface", {"point": "Vector2(10, 10)", "normal": "Vector2.UP", "distance": "2.0"})
	all_passed = _check("Push Out Of Surface emits a step along the normal",
		push_out, "(Vector2(10, 10) + Vector2.UP.normalized() * 2.0)") and all_passed
	all_passed = _check("the point ends up clear of the surface, not on it",
		_value(push_out), Vector2(10, 8)) and all_passed

	var face: String = _emit("FaceAlongVelocity", {"velocity": "Vector2(0, 10)"})
	all_passed = _check("Face Along Velocity emits a guarded rotation assignment",
		face, "if Vector2(0, 10).length_squared() > 0.0001:\n\trotation = Vector2(0, 10).angle()") and all_passed
	all_passed = _check("a moving node turns to face its travel",
		roundi(float(_after(face, SCAFFOLD_2D, {"rotation": 0.25}).get("rotation")) * 10000.0), roundi(PI * 0.5 * 10000.0)) and all_passed
	all_passed = _check("a stopped node is left alone instead of snapping back to facing right",
		_after(_emit("FaceAlongVelocity", {"velocity": "Vector2.ZERO"}), SCAFFOLD_2D, {"rotation": 0.25}).get("rotation"), 0.25) and all_passed

	var safe_up: String = _emit("LookAtSafeUp", {"target": "Vector3(0, 10, 0)", "uid": "7"})
	all_passed = _check("Look At (safe up) emits the guarded, up-swapping form",
		safe_up, "var __look_to_7: Vector3 = Vector3(0, 10, 0) - global_position\nif __look_to_7.length_squared() > 0.000001:\n\tlook_at(Vector3(0, 10, 0), Vector3.UP if absf(__look_to_7.normalized().y) < 0.999 else Vector3.FORWARD)") and all_passed
	# THE crash fix: a target directly overhead is exactly where plain look_at throws, because the
	# look direction and the up vector are parallel. The up vector must swap, and it must swap only
	# then - an ordinary target still gets the ordinary up.
	all_passed = _check("a target directly overhead swaps the up vector instead of crashing",
		(_after(safe_up, SCAFFOLD_3D).get("__looks") as Array)[0][1], Vector3.FORWARD) and all_passed
	all_passed = _check("an ordinary target keeps the ordinary up vector",
		(_after(_emit("LookAtSafeUp", {"target": "Vector3(5, 0, 0)", "uid": "7"}), SCAFFOLD_3D).get("__looks") as Array)[0][1], Vector3.UP) and all_passed
	all_passed = _check("a target where the node already stands turns nothing at all",
		(_after(_emit("LookAtSafeUp", {"target": "Vector3.ZERO", "uid": "7"}), SCAFFOLD_3D).get("__looks") as Array).size(), 0) and all_passed

	var flat: String = _emit("LookAtFlat", {"target": "Vector3(5, 99, 0)", "uid": "7"})
	all_passed = _check("Look At (flat) emits a height-flattened target",
		flat, "var __flat_7: Vector3 = Vector3(Vector3(5, 99, 0).x, global_position.y, Vector3(5, 99, 0).z)\nif __flat_7.distance_squared_to(global_position) > 0.000001:\n\tlook_at(__flat_7, Vector3.UP)") and all_passed
	all_passed = _check("the height is discarded, so a character never tips over to stare at feet",
		(_after(flat, SCAFFOLD_3D, {"global_position": Vector3(0, 3, 0)}).get("__looks") as Array)[0][0], Vector3(5, 3, 0)) and all_passed

	var lead: String = _emit("AimAtMovingTarget", {"shooter_position": "Vector2.ZERO", "target_position": "Vector2(600, 0)", "target_velocity": "Vector2(0, 100)", "projectile_speed": "600.0"})
	all_passed = _check("Aim At Moving Target emits the guarded interception point",
		lead, "(Vector2(600, 0) + Vector2(0, 100) * (Vector2(600, 0).distance_to(Vector2.ZERO) / maxf(600.0, 0.001)) if 600.0 > Vector2(0, 100).length() else Vector2(600, 0))") and all_passed
	all_passed = _check("the aim point leads the target by exactly one second of its travel",
		_value(lead), Vector2(600, 100)) and all_passed
	all_passed = _check("a target faster than the shot falls back to where it is now",
		_value(_emit("AimAtMovingTarget", {"shooter_position": "Vector2.ZERO", "target_position": "Vector2(600, 0)", "target_velocity": "Vector2(0, 100)", "projectile_speed": "50.0"})), Vector2(600, 0)) and all_passed

	var arc: String = _emit("LaunchAngleForArc", {"distance": "300.0", "height": "0.0", "speed": "600.0", "gravity": "980.0"})
	all_passed = _check("Launch Angle For Arc emits the discriminant-guarded solution",
		arc, "(rad_to_deg(atan2(600.0 * 600.0 - sqrt(maxf(600.0 * 600.0 * 600.0 * 600.0 - 980.0 * (980.0 * 300.0 * 300.0 + 2.0 * 0.0 * 600.0 * 600.0), 0.0)), 980.0 * 300.0)) if 300.0 != 0.0 and 980.0 != 0.0 else 45.0)") and all_passed
	all_passed = _check("it picks the flatter of the two arcs",
		roundi(float(_value(arc)) * 10.0), 274) and all_passed
	all_passed = _check("nothing to solve for reads as 45 rather than as not-a-number",
		_value(_emit("LaunchAngleForArc", {"distance": "0.0", "height": "0.0", "speed": "600.0", "gravity": "980.0"})), 45.0) and all_passed

	var travel: String = _emit("TimeToReach", {"from_position": "Vector2.ZERO", "to_position": "Vector2(300, 0)", "speed": "150.0"})
	all_passed = _check("Time To Reach emits a guarded division",
		travel, "(Vector2.ZERO.distance_to(Vector2(300, 0)) / maxf(150.0, 0.001))") and all_passed
	all_passed = _check("300 pixels at 150 a second takes two seconds",
		_value(travel), 2.0) and all_passed
	all_passed = _check("a speed of zero reads as a very long time, never a division by zero",
		_value(_emit("TimeToReach", {"from_position": "Vector2.ZERO", "to_position": "Vector2(300, 0)", "speed": "0.0"})), 300000.0) and all_passed
	return all_passed


# ── 4. grid maths ─────────────────────────────────────────────────────────────────────────────


static func _test_grid() -> bool:
	var all_passed: bool = true

	var cell_of: String = _emit("CellOfPoint", {"point": "Vector2(130, -10)", "cell_size": "64.0"})
	all_passed = _check("Cell Of Point emits a guarded floor divide",
		cell_of, "Vector2i(floori(Vector2(130, -10).x / maxf(64.0, 0.001)), floori(Vector2(130, -10).y / maxf(64.0, 0.001)))") and all_passed
	all_passed = _check("a position left of and above the origin lands in a negative cell",
		_value(cell_of), Vector2i(2, -1)) and all_passed

	var center_of: String = _emit("CenterOfCell", {"cell": "Vector2i(2, 1)", "cell_size": "64.0"})
	all_passed = _check("Center Of Cell emits the half-cell offset",
		center_of, "(Vector2(Vector2i(2, 1)) * 64.0 + Vector2(64.0, 64.0) * 0.5)") and all_passed
	all_passed = _check("the answer is the middle of the cell, not its corner",
		_value(center_of), Vector2(160, 96)) and all_passed
	all_passed = _check("Cell Of Point and Center Of Cell round-trip",
		_value(_emit("CellOfPoint", {"point": "Vector2(160, 96)", "cell_size": "64.0"})), Vector2i(2, 1)) and all_passed

	var snap: String = _emit("SnapPointToGrid", {"point": "Vector2(70, 100)", "cell_size": "64.0"})
	all_passed = _check("Snap Point To Grid emits a plain snapped call",
		snap, "Vector2(70, 100).snapped(Vector2(64.0, 64.0))") and all_passed
	all_passed = _check("it rounds to the NEAREST intersection, either way",
		_value(snap), Vector2(64, 128)) and all_passed

	var snap_3d: String = _emit("SnapPointToGrid3D", {"point": "Vector3(1.4, 0.2, -0.6)", "cell_size": "1.0"})
	all_passed = _check("Snap Point To Grid (3D) emits the Vector3 form",
		snap_3d, "Vector3(1.4, 0.2, -0.6).snapped(Vector3(1.0, 1.0, 1.0))") and all_passed
	all_passed = _check("all three axes snap together",
		_value(snap_3d), Vector3(1, 0, -1)) and all_passed

	var cell_distance: String = _emit("CellDistance", {"from_cell": "Vector2i(0, 0)", "to_cell": "Vector2i(3, 4)", "metric": "3"})
	all_passed = _check("Cell Distance emits the five-geometry array indexed by the dropdown",
		cell_distance, "([Vector2(Vector2i(0, 0)).distance_to(Vector2(Vector2i(3, 4))), float(absi(Vector2i(0, 0).x - Vector2i(3, 4).x)), float(absi(Vector2i(0, 0).y - Vector2i(3, 4).y)), float(absi(Vector2i(0, 0).x - Vector2i(3, 4).x) + absi(Vector2i(0, 0).y - Vector2i(3, 4).y)), float(maxi(absi(Vector2i(0, 0).x - Vector2i(3, 4).x), absi(Vector2i(0, 0).y - Vector2i(3, 4).y)))][3])") and all_passed
	all_passed = _check("grid steps counts the Manhattan walk",
		_value(cell_distance), 7.0) and all_passed
	all_passed = _check("straight line measures the hypotenuse",
		_value(_emit("CellDistance", {"from_cell": "Vector2i(0, 0)", "to_cell": "Vector2i(3, 4)", "metric": "0"})), 5.0) and all_passed
	all_passed = _check("king moves counts the longer axis alone",
		_value(_emit("CellDistance", {"from_cell": "Vector2i(0, 0)", "to_cell": "Vector2i(3, 4)", "metric": "4"})), 4.0) and all_passed
	# Every option in the dropdown must index a live entry in that array: an option the array cannot
	# reach crashes only when the row is REACHED, and nothing at authoring time would say so.
	var metric_ok: bool = true
	for option: Dictionary in SPATIAL.CELL_METRIC_OPTIONS:
		if not (_value(_emit("CellDistance", {"from_cell": "Vector2i(0, 0)", "to_cell": "Vector2i(3, 4)", "metric": str(option["key"])})) is float):
			metric_ok = false
	all_passed = _check("every geometry option indexes a live entry", metric_ok, true) and all_passed

	var neighbours: String = _emit("NeighboursOfCell", {"cell": "Vector2i(2, 2)", "shape": "0"})
	all_passed = _check("Neighbours Of Cell emits the three shapes as one indexed array",
		neighbours, "([[Vector2i(2, 2) + Vector2i(1, 0), Vector2i(2, 2) + Vector2i(-1, 0), Vector2i(2, 2) + Vector2i(0, 1), Vector2i(2, 2) + Vector2i(0, -1)], [Vector2i(2, 2) + Vector2i(1, 0), Vector2i(2, 2) + Vector2i(-1, 0), Vector2i(2, 2) + Vector2i(0, 1), Vector2i(2, 2) + Vector2i(0, -1), Vector2i(2, 2) + Vector2i(1, 1), Vector2i(2, 2) + Vector2i(1, -1), Vector2i(2, 2) + Vector2i(-1, 1), Vector2i(2, 2) + Vector2i(-1, -1)], [Vector2i(2, 2) + Vector2i(1, 0), Vector2i(2, 2) + Vector2i(-1, 0), Vector2i(2, 2) + Vector2i(0, 1), Vector2i(2, 2) + Vector2i(0, -1), Vector2i(2, 2) + Vector2i(1, -1), Vector2i(2, 2) + Vector2i(-1, 1)]][0])") and all_passed
	all_passed = _check("four sides gives four neighbours", (_value(neighbours) as Array).size(), 4) and all_passed
	all_passed = _check("the four are the cells actually touching it",
		str(_value(neighbours)), str([Vector2i(3, 2), Vector2i(1, 2), Vector2i(2, 3), Vector2i(2, 1)])) and all_passed
	all_passed = _check("eight including diagonals gives eight",
		(_value(_emit("NeighboursOfCell", {"cell": "Vector2i(2, 2)", "shape": "1"})) as Array).size(), 8) and all_passed
	all_passed = _check("an axial hex board gives six",
		(_value(_emit("NeighboursOfCell", {"cell": "Vector2i(2, 2)", "shape": "2"})) as Array).size(), 6) and all_passed

	var line: String = _emit("CellsInLine", {"from_cell": "Vector2i(0, 0)", "to_cell": "Vector2i(4, 2)"})
	all_passed = _check("Cells In Line emits a stepped walk between the two cells",
		line, "range(maxi(absi(Vector2i(4, 2).x - Vector2i(0, 0).x), absi(Vector2i(4, 2).y - Vector2i(0, 0).y)) + 1).map(func(__step: int) -> Vector2i: return Vector2i(roundi(lerpf(Vector2i(0, 0).x, Vector2i(4, 2).x, float(__step) / maxf(float(maxi(absi(Vector2i(4, 2).x - Vector2i(0, 0).x), absi(Vector2i(4, 2).y - Vector2i(0, 0).y))), 1.0))), roundi(lerpf(Vector2i(0, 0).y, Vector2i(4, 2).y, float(__step) / maxf(float(maxi(absi(Vector2i(4, 2).x - Vector2i(0, 0).x), absi(Vector2i(4, 2).y - Vector2i(0, 0).y))), 1.0)))))") and all_passed
	var line_cells: Array = _value(line) as Array
	all_passed = _check("the walk takes one step per cell of the longer axis, both ends included",
		line_cells.size(), 5) and all_passed
	all_passed = _check("it starts at the first cell", line_cells[0], Vector2i(0, 0)) and all_passed
	all_passed = _check("and ends at the last", line_cells[4], Vector2i(4, 2)) and all_passed
	all_passed = _check("a line to itself is that one cell, not an empty walk",
		str(_value(_emit("CellsInLine", {"from_cell": "Vector2i(3, 3)", "to_cell": "Vector2i(3, 3)"}))), str([Vector2i(3, 3)])) and all_passed

	var radius_diamond: String = _emit("CellsInRadius", {"center": "Vector2i(0, 0)", "radius": "1", "shape": "0"})
	all_passed = _check("Cells In Radius emits the row-reduce with a shape filter",
		radius_diamond, "(range(-1, 1 + 1).reduce(func(__rows: Array, __dy: int) -> Array: return __rows + range(-1, 1 + 1).map(func(__dx: int) -> Vector2i: return Vector2i(0, 0) + Vector2i(__dx, __dy)), []) as Array).filter(func(__cell: Vector2i) -> bool: return 0 == 1 or absi(__cell.x - Vector2i(0, 0).x) + absi(__cell.y - Vector2i(0, 0).y) <= 1)") and all_passed
	all_passed = _check("grid steps drops the corners, so radius 1 is five cells",
		(_value(radius_diamond) as Array).size(), 5) and all_passed
	all_passed = _check("king moves keeps them, so radius 1 is nine",
		(_value(_emit("CellsInRadius", {"center": "Vector2i(0, 0)", "radius": "1", "shape": "1"})) as Array).size(), 9) and all_passed
	all_passed = _check("radius 0 is the centre cell alone",
		(_value(_emit("CellsInRadius", {"center": "Vector2i(4, 4)", "radius": "0", "shape": "1"})) as Array).size(), 1) and all_passed
	all_passed = _check("the set is centred where it was asked to be",
		(_value(_emit("CellsInRadius", {"center": "Vector2i(4, 4)", "radius": "0", "shape": "1"})) as Array)[0], Vector2i(4, 4)) and all_passed

	var block: String = _emit("CellsInRectangle", {"top_left": "Vector2i(0, 0)", "size": "Vector2i(2, 3)"})
	all_passed = _check("Cells In Rectangle emits a row-by-row reduce",
		block, "range(Vector2i(0, 0).y, Vector2i(0, 0).y + maxi(Vector2i(2, 3).y, 0)).reduce(func(__rows: Array, __y: int) -> Array: return __rows + range(Vector2i(0, 0).x, Vector2i(0, 0).x + maxi(Vector2i(2, 3).x, 0)).map(func(__x: int) -> Vector2i: return Vector2i(__x, __y)), [])") and all_passed
	all_passed = _check("a 2 by 3 block is six cells", (_value(block) as Array).size(), 6) and all_passed
	all_passed = _check("laid out row by row", (_value(block) as Array)[1], Vector2i(1, 0)) and all_passed
	all_passed = _check("a negative size walks nothing rather than looping backwards",
		(_value(_emit("CellsInRectangle", {"top_left": "Vector2i(0, 0)", "size": "Vector2i(-3, -3)"})) as Array).size(), 0) and all_passed

	var bounds: String = _emit("IsCellInBounds", {"cell": "Vector2i(19, 11)", "size": "Vector2i(20, 12)"})
	all_passed = _check("Is Cell In Bounds emits a four-way range test",
		bounds, "(Vector2i(19, 11).x >= 0 and Vector2i(19, 11).y >= 0 and Vector2i(19, 11).x < Vector2i(20, 12).x and Vector2i(19, 11).y < Vector2i(20, 12).y)") and all_passed
	all_passed = _check("a 20 by 12 board's last cell is 19,11", _value(bounds), true) and all_passed
	all_passed = _check("20,11 is off the end of it",
		_value(_emit("IsCellInBounds", {"cell": "Vector2i(20, 11)", "size": "Vector2i(20, 12)"})), false) and all_passed
	all_passed = _check("and a negative cell is off the other end",
		_value(_emit("IsCellInBounds", {"cell": "Vector2i(-1, 0)", "size": "Vector2i(20, 12)"})), false) and all_passed

	var loop: String = _emit("ForEachCellInRadius", {"center": "Vector2i(0, 0)", "radius": "2", "shape": "0"})
	all_passed = _check("For Each Cell In Radius walks the diamond it advertises",
		(_value(loop) as Array).size(), 13) and all_passed
	return all_passed


# ── 5. falloff and radial force ───────────────────────────────────────────────────────────────


static func _test_falloff() -> bool:
	var all_passed: bool = true

	var linear: String = _emit("FalloffAtDistance", {"center": "Vector2.ZERO", "point": "Vector2(100, 0)", "radius": "200.0", "shape": "0"})
	all_passed = _check("Falloff At Distance emits the three profiles as one indexed array",
		linear, "([clampf(1.0 - Vector2.ZERO.distance_to(Vector2(100, 0)) / maxf(200.0, 0.001), 0.0, 1.0), clampf(1.0 - Vector2.ZERO.distance_to(Vector2(100, 0)) / maxf(200.0, 0.001), 0.0, 1.0) * clampf(1.0 - Vector2.ZERO.distance_to(Vector2(100, 0)) / maxf(200.0, 0.001), 0.0, 1.0), smoothstep(0.0, 1.0, clampf(1.0 - Vector2.ZERO.distance_to(Vector2(100, 0)) / maxf(200.0, 0.001), 0.0, 1.0))][0])") and all_passed
	all_passed = _check("linear reads halfway at half the radius", _value(linear), 0.5) and all_passed
	all_passed = _check("inverse square falls off faster",
		_value(_emit("FalloffAtDistance", {"center": "Vector2.ZERO", "point": "Vector2(100, 0)", "radius": "200.0", "shape": "1"})), 0.25) and all_passed
	all_passed = _check("the centre always reads full strength",
		_value(_emit("FalloffAtDistance", {"center": "Vector2.ZERO", "point": "Vector2.ZERO", "radius": "200.0", "shape": "2"})), 1.0) and all_passed
	# THE promise that makes it safe to multiply straight into damage: nothing past the radius.
	all_passed = _check("anything past the radius reads exactly 0, so it is safe to multiply in",
		_value(_emit("FalloffAtDistance", {"center": "Vector2.ZERO", "point": "Vector2(9999, 0)", "radius": "200.0", "shape": "2"})), 0.0) and all_passed
	var shape_ok: bool = true
	for option: Dictionary in SPATIAL.FALLOFF_SHAPE_OPTIONS:
		if not (_value(_emit("FalloffAtDistance", {"center": "Vector2.ZERO", "point": "Vector2(50, 0)", "radius": "200.0", "shape": str(option["key"])})) is float):
			shape_ok = false
	all_passed = _check("every profile option indexes a live entry", shape_ok, true) and all_passed

	var toward: String = _emit("StrengthToward", {"node": "get_parent()", "radius": "600.0"})
	all_passed = _check("Strength Toward emits a node-relative clamp",
		toward, "(clampf(1.0 - global_position.distance_to(get_parent().global_position) / maxf(600.0, 0.001), 0.0, 1.0))") and all_passed
	var other: Node2D = Node2D.new()
	other.global_position = Vector2(300, 0)
	all_passed = _check("half a radius away reads half strength",
		_value(toward, SCAFFOLD_2D, {"__parent": other}), 0.5) and all_passed
	other.global_position = Vector2(9999, 0)
	all_passed = _check("out of range reads nothing at all",
		_value(toward, SCAFFOLD_2D, {"__parent": other}), 0.0) and all_passed
	other.free()

	var impulse: String = _emit("ApplyRadialImpulse", {"center": "Vector2.ZERO", "strength": "900.0", "radius": "240.0", "uid": "7"})
	all_passed = _check("Apply Radial Impulse emits a uid-named blast local",
		impulse, "var __blast_7: Vector2 = global_position - Vector2.ZERO\napply_impulse(__blast_7.normalized() * 900.0 * clampf(1.0 - __blast_7.length() / maxf(240.0, 0.001), 0.0, 1.0))") and all_passed
	var thrown: Object = _after(impulse, SCAFFOLD_2D, {"global_position": Vector2(120, 0)})
	all_passed = _check("a body at half the radius is thrown outward at half strength",
		(thrown.get("__impulses") as Array)[0], Vector2(450, 0)) and all_passed
	var far: Object = _after(impulse, SCAFFOLD_2D, {"global_position": Vector2(9999, 0)})
	all_passed = _check("a body outside the blast is not moved",
		(far.get("__impulses") as Array)[0], Vector2.ZERO) and all_passed

	var shove: String = _emit("PushGroupAwayFrom", {"group": "\"enemies\"", "center": "Vector2.ZERO", "radius": "240.0", "strength": "60.0", "uid": "7"})
	all_passed = _check("Push Group Away From emits a guarded group walk",
		shove, "for __blast_7: Node in get_tree().get_nodes_in_group(\"enemies\"):\n\tif __blast_7 is Node2D and (__blast_7 as Node2D).global_position.distance_to(Vector2.ZERO) <= maxf(240.0, 0.001):\n\t\t(__blast_7 as Node2D).global_position += ((__blast_7 as Node2D).global_position - Vector2.ZERO).normalized() * 60.0 * clampf(1.0 - (__blast_7 as Node2D).global_position.distance_to(Vector2.ZERO) / maxf(240.0, 0.001), 0.0, 1.0)") and all_passed
	var near_member: Node2D = Node2D.new()
	near_member.global_position = Vector2(120, 0)
	var far_member: Node2D = Node2D.new()
	far_member.global_position = Vector2(1000, 0)
	_after(shove, SCAFFOLD_2D, {"__members": [near_member, far_member]})
	all_passed = _check("a member inside the blast is shoved outward, weaker for being further",
		near_member.global_position, Vector2(150, 0)) and all_passed
	all_passed = _check("a member outside it is untouched",
		far_member.global_position, Vector2(1000, 0)) and all_passed
	near_member.free()
	far_member.free()

	var cone: String = _emit("IsWithinConeOf", {"origin": "Vector2.ZERO", "facing_degrees": "0.0", "point": "Vector2(100, 0)", "fov_degrees": "70.0", "range_px": "600.0"})
	all_passed = _check("Is Within Cone Of emits a range test and an angle test",
		cone, "(Vector2(100, 0).distance_to(Vector2.ZERO) <= maxf(600.0, 0.0) and absf(angle_difference(deg_to_rad(0.0), (Vector2(100, 0) - Vector2.ZERO).angle())) <= deg_to_rad(70.0) * 0.5)") and all_passed
	all_passed = _check("a point straight ahead is inside the wedge", _value(cone), true) and all_passed
	all_passed = _check("a point at 90 degrees is outside a 70 degree wedge",
		_value(_emit("IsWithinConeOf", {"origin": "Vector2.ZERO", "facing_degrees": "0.0", "point": "Vector2(0, 100)", "fov_degrees": "70.0", "range_px": "600.0"})), false) and all_passed
	all_passed = _check("a point dead ahead but out of reach is outside it too",
		_value(_emit("IsWithinConeOf", {"origin": "Vector2.ZERO", "facing_degrees": "0.0", "point": "Vector2(700, 0)", "fov_degrees": "70.0", "range_px": "600.0"})), false) and all_passed
	all_passed = _check("the wedge turns with its facing",
		_value(_emit("IsWithinConeOf", {"origin": "Vector2.ZERO", "facing_degrees": "90.0", "point": "Vector2(0, 100)", "fov_degrees": "70.0", "range_px": "600.0"})), true) and all_passed
	return all_passed


# ── the Follow Path pack ──────────────────────────────────────────────────────────────────────


## An L-shaped route 200 pixels long: 100 right, then 100 down. Every distance below is read off
## that, so a change to the curve shows up as a value, not as a vague drift.
static func _route() -> Path2D:
	var path: Path2D = Path2D.new()
	var curve: Curve2D = Curve2D.new()
	curve.add_point(Vector2.ZERO)
	curve.add_point(Vector2(100, 0))
	curve.add_point(Vector2(100, 100))
	path.curve = curve
	return path


## A behavior with its host bound by hand. _enter_tree does that in a real scene; there is no tree
## here, so the binding is made explicitly and the rest of the pack runs exactly as shipped.
static func _behavior(host: Node2D) -> Node:
	var script: GDScript = load(PACK_PATH)
	var behavior: Node = script.new()
	behavior.set("host", host)
	return behavior


static func _test_follow_path_verbs() -> bool:
	var all_passed: bool = true
	var host: Node2D = Node2D.new()
	var behavior: Node = _behavior(host)
	var path: Path2D = _route()

	all_passed = _check("the route is the 200 pixel L the tests are written against",
		behavior.call("path_length", path), 200.0) and all_passed
	all_passed = _check("Path Length measures along the curve, not corner to corner",
		snappedf(float(behavior.call("path_length", path)), 0.01) > Vector2.ZERO.distance_to(Vector2(100, 100)), true) and all_passed
	all_passed = _check("a missing route reads 0 rather than faulting",
		behavior.call("path_length", null), 0.0) and all_passed

	all_passed = _check("Point On Path At walks halfway to the corner",
		behavior.call("point_on_path_at", path, 0.5), Vector2(100, 0)) and all_passed
	all_passed = _check("0 is the start", behavior.call("point_on_path_at", path, 0.0), Vector2.ZERO) and all_passed
	all_passed = _check("1 is the end", behavior.call("point_on_path_at", path, 1.0), Vector2(100, 100)) and all_passed
	all_passed = _check("a fraction past the end is clamped rather than running off",
		behavior.call("point_on_path_at", path, 9.0), Vector2(100, 100)) and all_passed
	all_passed = _check("a missing route reads zero rather than faulting",
		behavior.call("point_on_path_at", null, 0.5), Vector2.ZERO) and all_passed

	all_passed = _check("Direction Along Path At reads the heading down the second leg",
		(behavior.call("direction_along_path_at", path, 0.75) as Vector2).snapped(Vector2(0.001, 0.001)), Vector2(0, 1)) and all_passed
	all_passed = _check("and the heading along the first",
		(behavior.call("direction_along_path_at", path, 0.25) as Vector2).snapped(Vector2(0.001, 0.001)), Vector2(1, 0)) and all_passed
	all_passed = _check("a missing route reads a plain right-facing direction",
		behavior.call("direction_along_path_at", null, 0.5), Vector2.RIGHT) and all_passed

	all_passed = _check("Nearest Point On Path snaps a stray position onto the lane",
		behavior.call("nearest_point_on_path", path, Vector2(130, 50)), Vector2(100, 50)) and all_passed
	all_passed = _check("a missing route hands the position straight back",
		behavior.call("nearest_point_on_path", null, Vector2(7, 7)), Vector2(7, 7)) and all_passed

	all_passed = _check("nothing is following before a Follow Path row runs",
		behavior.call("is_following_path"), false) and all_passed
	all_passed = _check("and Progress Along Path reads 0",
		behavior.call("progress_along_path"), 0.0) and all_passed
	behavior.call("follow_path", path, 100.0, "once")
	all_passed = _check("Follow Path parks the host at the start of the route",
		host.global_position, Vector2.ZERO) and all_passed
	all_passed = _check("and it is following now", behavior.call("is_following_path"), true) and all_passed
	behavior.call("_process", 0.5)
	all_passed = _check("half a second at 100 a second is 50 pixels ALONG the curve",
		host.global_position, Vector2(50, 0)) and all_passed
	all_passed = _check("Progress Along Path reads a quarter of the way",
		behavior.call("progress_along_path"), 0.25) and all_passed
	all_passed = _check("Is At Path End is false while it is still travelling",
		behavior.call("is_at_path_end"), false) and all_passed
	# Arc-length pacing: the SECOND leg costs the same 100 pixels as the first, so a second and a
	# half of travel lands 150 along, which is halfway down the vertical leg - not somewhere the
	# straight-line spelling would put it.
	behavior.call("_process", 1.0)
	all_passed = _check("the corner does not speed it up: 150 along is halfway down the second leg",
		host.global_position, Vector2(100, 50)) and all_passed

	behavior.call("stop_following_path")
	all_passed = _check("Stop Following Path halts it where it stands",
		behavior.call("is_following_path"), false) and all_passed
	behavior.call("_process", 10.0)
	all_passed = _check("and a stopped run does not move on the next frame",
		host.global_position, Vector2(100, 50)) and all_passed

	behavior.set("rotate_to_face", true)
	behavior.call("follow_path", path, 100.0, "once")
	behavior.call("_process", 0.5)
	all_passed = _check("rotate-to-face turns the host along the first leg",
		roundi(host.global_rotation * 1000.0), 0) and all_passed
	behavior.call("_process", 1.0)
	all_passed = _check("and turns it again through the corner",
		roundi(host.global_rotation * 1000.0), roundi(PI * 0.5 * 1000.0)) and all_passed

	all_passed = _check("a null route is refused rather than half-started",
		_started_with_null(), false) and all_passed

	behavior.free()
	host.free()
	path.free()
	return all_passed


## Follow Path handed nothing: the row must leave the behavior alone, not mark it following with no
## curve to walk (which would fault on the very next frame).
static func _started_with_null() -> bool:
	var host: Node2D = Node2D.new()
	var behavior: Node = _behavior(host)
	behavior.call("follow_path", null, 100.0, "once")
	var following: bool = bool(behavior.call("is_following_path"))
	behavior.free()
	host.free()
	return following


# ── the trigger ───────────────────────────────────────────────────────────────────────────────


static func _test_follow_path_trigger() -> bool:
	var all_passed: bool = true
	var script: GDScript = load(PACK_PATH)

	# 1. DECLARED. The trigger is a real Godot signal on the shipped script, carrying exactly the
	#    payload the design calls for - arrival needs no arguments to say what happened.
	var signal_names: PackedStringArray = PackedStringArray()
	var argument_count: int = -1
	for entry: Dictionary in script.get_script_signal_list():
		signal_names.append(str(entry.get("name", "")))
		if str(entry.get("name", "")) == "path_finished":
			argument_count = (entry.get("args", []) as Array).size()
	all_passed = _check("the pack declares a real signal for arrival",
		signal_names.has("path_finished"), true) and all_passed
	all_passed = _check("it carries no payload, because arrival has nothing to report",
		argument_count, 0) and all_passed
	all_passed = _check("the shipped source marks it a trigger",
		FileAccess.get_file_as_string(PACK_PATH).contains("## @ace_trigger\n## @ace_name(\"On Path Finished\")\nsignal path_finished"), true) and all_passed

	# 2. PUBLISHED as a TRIGGER row, not as a condition. This is the re-kinding the audit asked for:
	#    arrival is the signal, and Is At Path End stays beside it for the other question.
	var kinds: Dictionary = _pack_definitions()
	all_passed = _check("On Path Finished is published as a trigger",
		kinds.get("On Path Finished", -1), ACEDefinition.ACEType.TRIGGER) and all_passed
	all_passed = _check("Is At Path End stays a condition, for \"is it parked there right now\"",
		kinds.get("Is At Path End", -1), ACEDefinition.ACEType.CONDITION) and all_passed
	all_passed = _check("Follow Path is an action", kinds.get("Follow Path", -1), ACEDefinition.ACEType.ACTION) and all_passed
	all_passed = _check("Point On Path At is an expression",
		kinds.get("Point On Path At", -1), ACEDefinition.ACEType.EXPRESSION) and all_passed

	# 3. EMITTED at the right moment: once, when a Once run reaches the end, and never before.
	var host: Node2D = Node2D.new()
	var behavior: Node = _behavior(host)
	var path: Path2D = _route()
	# A trigger is only proved by CONNECTING to it and driving the thing that should make it fire.
	# The counter lives in an array so the lambda can raise it: a captured int would be a copy.
	var fired: Array = [0]
	behavior.connect("path_finished", func() -> void: fired[0] += 1)
	behavior.call("follow_path", path, 100.0, "once")
	behavior.call("_process", 1.0)
	all_passed = _check("nothing fires halfway along", int(fired[0]), 0) and all_passed
	behavior.call("_process", 1.5)
	all_passed = _check("arrival fires exactly once at the end", int(fired[0]), 1) and all_passed
	all_passed = _check("and the host is parked on the last point of the curve",
		host.global_position, Vector2(100, 100)) and all_passed
	all_passed = _check("Is At Path End now answers true, which is the OTHER question",
		behavior.call("is_at_path_end"), true) and all_passed
	all_passed = _check("Progress Along Path reads all the way",
		behavior.call("progress_along_path"), 1.0) and all_passed
	behavior.call("_process", 5.0)
	all_passed = _check("a finished run never fires again on later frames", int(fired[0]), 1) and all_passed

	# 4. A run with no end never fires it.
	behavior.call("follow_path", path, 100.0, "loop")
	for _step: int in 5:
		behavior.call("_process", 1.0)
	all_passed = _check("a Loop run keeps going", behavior.call("is_following_path"), true) and all_passed
	all_passed = _check("and never fires an arrival it has not reached", int(fired[0]), 1) and all_passed
	all_passed = _check("looping wraps back onto the route rather than running past its end",
		host.global_position, Vector2(100, 0)) and all_passed

	behavior.call("follow_path", path, 100.0, "pingpong")
	behavior.call("_process", 2.5)
	all_passed = _check("a Ping-pong run turns around at the end",
		host.global_position, Vector2(100, 50)) and all_passed
	behavior.call("_process", 1.0)
	all_passed = _check("and walks back the way it came",
		host.global_position, Vector2(50, 0)) and all_passed
	all_passed = _check("still without ever firing arrival", int(fired[0]), 1) and all_passed

	behavior.free()
	host.free()
	path.free()
	return all_passed


## Display name -> ACEDefinition.ACEType for every verb the shipped pack publishes.
static func _pack_definitions() -> Dictionary:
	var kinds: Dictionary = {}
	var script: GDScript = load(PACK_PATH)
	var instance: Node = script.new()
	for definition: ACEDefinition in EventSheetACEGenerator.new().generate_from_object(instance):
		kinds[definition.display_name] = definition.ace_type
	instance.free()
	return kinds


# ── harness ───────────────────────────────────────────────────────────────────────────────────


## ace_id -> descriptor, from the LIVE builtin registry - so what is pinned is what ships, after
## the cross-node "On node" pass has had its chance to rewrite a template.
static func _shipped() -> Dictionary:
	var shipped: Dictionary = {}
	for descriptor: ACEDescriptor in EventForgeBuiltinACEs.get_descriptors():
		shipped[descriptor.ace_id] = descriptor
	return shipped


static func _module_ids() -> PackedStringArray:
	var ids: PackedStringArray = PackedStringArray()
	for descriptor: ACEDescriptor in SPATIAL.get_descriptors():
		ids.append(descriptor.ace_id)
	return ids


## The DISPLAY labels of a descriptor's parameters. The cross-node pass appends one called
## "On node"; a verb's own argument may legitimately be called `target`, so the label is what tells
## the two apart.
static func _param_labels(descriptor: ACEDescriptor) -> PackedStringArray:
	var labels: PackedStringArray = PackedStringArray()
	for parameter: ACEParam in descriptor.params:
		labels.append(str(parameter.display_name))
	return labels


## The GDScript a row ships as: the SHIPPED template run through the compiler's own substitution,
## never a hand-written approximation of it.
static func _emit(ace_id: String, params: Dictionary) -> String:
	var descriptor: ACEDescriptor = _shipped().get(ace_id, null)
	if descriptor == null:
		return "<no such ACE: %s>" % ace_id
	return ActionCodegen._apply_template(descriptor.codegen_template, params)


## Compiles a throwaway host around emitted code and runs it, returning the live instance so a test
## can read back both what the code RETURNED (__result) and what it DID (a moved position, a
## recorded impulse). Returns null when the generated source will not parse, which every caller
## turns into a value mismatch rather than a crash.
static func _host(scaffold: String, body: String, is_expression: bool) -> Object:
	var lines: PackedStringArray = PackedStringArray(["@tool", "extends RefCounted",
		"var __result: Variant = null",
		"var __view_transform: Transform2D = Transform2D()",
		"var __view_rect: Rect2 = Rect2()",
		scaffold,
		"func get_viewport() -> Variant:", "\treturn self",
		"func get_canvas_transform() -> Transform2D:", "\treturn __view_transform",
		"func get_visible_rect() -> Rect2:", "\treturn __view_rect",
		"func get_camera_3d() -> Camera3D:", "\treturn null",
		"func run() -> void:"])
	if is_expression:
		lines.append("\t__result = (%s)" % body)
	else:
		for statement: String in body.split("\n"):
			lines.append("\t" + statement)
		lines.append("\tpass")
	var script: GDScript = GDScript.new()
	script.source_code = "\n".join(lines) + "\n"
	if script.reload() != OK:
		return null
	return script.new()


## The value an emitted EXPRESSION produces, or the string "<did not compile>" when its generated
## host will not parse - so a template typo reads as a wrong value instead of taking the suite down.
static func _value(body: String, scaffold: String = SCAFFOLD_2D, setup: Dictionary = {}) -> Variant:
	var instance: Object = _host(scaffold, body, true)
	if instance == null:
		return "<did not compile>"
	return _drive(instance, setup).get("__result")


## The host an emitted ACTION leaves behind, so the test can read the members it changed.
static func _after(body: String, scaffold: String = SCAFFOLD_2D, setup: Dictionary = {}) -> Object:
	var instance: Object = _host(scaffold, body, false)
	if instance == null:
		return RefCounted.new()
	return _drive(instance, setup)


static func _drive(instance: Object, setup: Dictionary) -> Object:
	for key: Variant in setup:
		instance.set(str(key), setup[key])
	instance.call("run")
	return instance


## Runs an expression SAMPLES times, so a claim about a random distribution is judged on numbers
## rather than on one lucky roll.
static func _samples(body: String, scaffold: String = SCAFFOLD_2D, setup: Dictionary = {}) -> Array:
	var instance: Object = _host(scaffold, body, true)
	if instance == null:
		return []
	for key: Variant in setup:
		instance.set(str(key), setup[key])
	var values: Array = []
	for _index: int in SAMPLES:
		instance.call("run")
		values.append(instance.get("__result"))
	return values


static func _all_true(values: Array, predicate: Callable) -> bool:
	if values.is_empty():
		return false
	for value: Variant in values:
		if not bool(predicate.call(value)):
			return false
	return true


static func _fraction(values: Array, predicate: Callable) -> float:
	if values.is_empty():
		return -1.0
	var hits: int = 0
	for value: Variant in values:
		if bool(predicate.call(value)):
			hits += 1
	return float(hits) / float(values.size())


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] spatial_vocabulary_test: %s" % label)
		return true
	print("[FAIL] spatial_vocabulary_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
