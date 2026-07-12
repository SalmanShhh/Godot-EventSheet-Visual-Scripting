# EventForge - Drawing Canvas / Decal Painter / Bound To / Wrap packs + the collision-mask
# picker hint. Pins the four packs' public surfaces (verbs, triggers, inert defaults) and the
# physics-layer param plumbing: the dialog's hint factories, the mask field's value
# round-trip, and the name-convention that routes *_mask params to the picker.
@tool
class_name DrawingAndBoundsPacksTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true

	# ── Drawing Canvas: the verb set that makes shadows/telegraphs/LoS/ribbons one row each
	var canvas: Node = (load("res://eventsheet_addons/drawing_canvas/drawing_canvas_behavior.gd") as GDScript).new()
	for canvas_method: String in ["clear_canvas", "set_auto_clear", "set_canvas_visible", "draw_canvas_line", "draw_canvas_circle", "draw_canvas_ring", "draw_canvas_rect", "draw_canvas_cone", "draw_canvas_stamp", "draw_line_of_sight", "start_ribbon", "set_ribbon_texture", "stop_ribbon", "canvas_texture", "is_auto_clear"]:
		all_passed = _check("Drawing Canvas has %s" % canvas_method, canvas.has_method(canvas_method), true) and all_passed
	all_passed = _check("Drawing Canvas is persistent by default", canvas.get("auto_clear"), false) and all_passed
	all_passed = _check("Drawing Canvas reads world coordinates by default", canvas.get("coordinates"), "world") and all_passed
	all_passed = _check("Drawing Canvas verbs no-op safely out of tree", canvas.call("canvas_texture") == null, true) and all_passed
	canvas.free()

	# ── Decal Painter: spawn/blob/canvas-link verbs
	var painter: Node = (load("res://eventsheet_addons/decal_painter/decal_painter_behavior.gd") as GDScript).new()
	for painter_method: String in ["spawn_decal", "spawn_blob_shadow", "stop_blob_shadow", "spawn_canvas_decal", "clear_decals", "set_max_decals", "decal_count"]:
		all_passed = _check("Decal Painter has %s" % painter_method, painter.has_method(painter_method), true) and all_passed
	all_passed = _check("Decal Painter starts empty", int(painter.call("decal_count")), 0) and all_passed
	painter.free()

	# ── Bound To: clamp verbs + the per-side trigger
	var bound: Node = (load("res://eventsheet_addons/bound_to/bound_to_behavior.gd") as GDScript).new()
	for bound_method: String in ["set_bound_enabled", "set_bound_space", "set_custom_bounds", "set_bound_extents", "is_at_bound"]:
		all_passed = _check("Bound To has %s" % bound_method, bound.has_method(bound_method), true) and all_passed
	all_passed = _check("Bound To carries On Hit Bound", bound.has_signal("bound_hit"), true) and all_passed
	all_passed = _check("Bound To binds by edge by default", bound.get("bound_by_edge"), true) and all_passed
	all_passed = _check("Bound To defaults to the screen space", bound.get("bound_space"), "screen") and all_passed
	bound.free()

	# ── Wrap: per-axis wrapping + the side trigger
	var wrap: Node = (load("res://eventsheet_addons/wrap/wrap_behavior.gd") as GDScript).new()
	for wrap_method: String in ["set_wrap_enabled", "set_wrap_space", "set_custom_wrap_bounds", "set_wrap_axes", "set_wrap_extents"]:
		all_passed = _check("Wrap has %s" % wrap_method, wrap.has_method(wrap_method), true) and all_passed
	all_passed = _check("Wrap carries On Wrapped", wrap.has_signal("wrapped"), true) and all_passed
	all_passed = _check("Wrap wraps both axes by default", wrap.get("wrap_horizontal") == true and wrap.get("wrap_vertical") == true, true) and all_passed
	wrap.free()

	# ── The collision-mask picker: hint factories registered + the field round-trips ints
	var dialog: Variant = (load("res://addons/eventsheet/editor/ace_params_dialog.gd") as GDScript).new()
	dialog.call("_ensure_hint_factories")
	var factories: Dictionary = dialog.get("_hint_factories")
	all_passed = _check("physics_layer_2d hint is registered", factories.has("physics_layer_2d"), true) and all_passed
	all_passed = _check("physics_layer_3d hint is registered", factories.has("physics_layer_3d"), true) and all_passed
	var field: Control = dialog.call("_create_physics_layer_2d_field", "collision_mask", "5")
	all_passed = _check("mask field extracts the default mask", dialog.call("_extract_value", field), 5) and all_passed
	all_passed = _check("mask summary lists anonymous layers by number", dialog.call("_physics_mask_summary", 5, "2d_physics"), "1, 3") and all_passed
	all_passed = _check("empty mask reads as No layers", dialog.call("_physics_mask_summary", 0, "2d_physics"), "No layers") and all_passed
	field.free()

	# ── Rotate: the C3-parity spinner + its editor-preview contract
	var rotate_script: GDScript = load("res://eventsheet_addons/rotate/rotate_behavior.gd")
	var rotate: Node = rotate_script.new()
	for rotate_method: String in ["set_rotation_enabled", "set_rotation_speed", "set_rotation_acceleration", "set_rotation_type", "reverse_rotation", "is_rotating", "rotation_speed"]:
		all_passed = _check("Rotate has %s" % rotate_method, rotate.has_method(rotate_method), true) and all_passed
	all_passed = _check("Rotate spins by default", rotate.get("rotate_enabled"), true) and all_passed
	all_passed = _check("Rotate defaults to 2D", rotate.get("rotation_type"), "2d") and all_passed
	rotate.free()
	# The preview static: angle(t) = speed*t + accel*t^2/2, on a 2D float and a 3D axis.
	var preview_2d: Dictionary = rotate_script.editor_preview_sample({"speed": 90.0, "acceleration": 0.0}, {"rotation": 0.0}, 2.0)
	all_passed = _check("Rotate preview spins a 2D host (90 deg/s for 2s = PI)", is_equal_approx(float(preview_2d.get("rotation", 0.0)), PI), true) and all_passed
	var preview_accel: Dictionary = rotate_script.editor_preview_sample({"speed": 0.0, "acceleration": 90.0}, {"rotation": 0.0}, 2.0)
	all_passed = _check("Rotate preview applies acceleration (accel 90 for 2s = PI)", is_equal_approx(float(preview_accel.get("rotation", 0.0)), PI), true) and all_passed
	var preview_y: Dictionary = rotate_script.editor_preview_sample({"speed": 90.0, "rotation_type": "y"}, {"rotation": Vector3.ZERO}, 1.0)
	all_passed = _check("Rotate preview spins a 3D Y axis", is_equal_approx((preview_y.get("rotation", Vector3.ZERO) as Vector3).y, PI / 2.0), true) and all_passed
	var preview_off: Dictionary = rotate_script.editor_preview_sample({"rotate_enabled": false, "speed": 90.0}, {"rotation": 0.0}, 1.0)
	all_passed = _check("Rotate preview respects the toggle", preview_off.is_empty(), true) and all_passed

	# ── Wrap: the circular constraint
	var wrap_circle: Node = (load("res://eventsheet_addons/wrap/wrap_behavior.gd") as GDScript).new()
	all_passed = _check("Wrap has set_circle_wrap_bounds", wrap_circle.has_method("set_circle_wrap_bounds"), true) and all_passed
	all_passed = _check("Wrap shape defaults to rect", wrap_circle.get("wrap_shape"), "rect") and all_passed
	wrap_circle.call("set_circle_wrap_bounds", 100.0, 200.0, 250.0)
	all_passed = _check("Set Circle Wrap Bounds switches the shape", wrap_circle.get("wrap_shape"), "circle") and all_passed
	all_passed = _check("Set Circle Wrap Bounds stores the radius", is_equal_approx(float(wrap_circle.get("wrap_circle_radius")), 250.0), true) and all_passed
	all_passed = _check("circle exits report a side word", wrap_circle.call("_direction_side", Vector2(1.0, 0.2)), "right") and all_passed
	wrap_circle.free()

	# ── Drawing prefabs: the ordered-steps resource + the canvas verb that replays it
	var prefab: Resource = (load("res://eventsheet_addons/drawing_prefab_resource/drawing_prefab_resource.gd") as GDScript).new()
	all_passed = _check("DrawingPrefabResource carries an ordered steps array", prefab.get("steps") is Array, true) and all_passed
	var canvas_prefab: Node = (load("res://eventsheet_addons/drawing_canvas/drawing_canvas_behavior.gd") as GDScript).new()
	all_passed = _check("Drawing Canvas has draw_prefab", canvas_prefab.has_method("draw_prefab"), true) and all_passed
	canvas_prefab.free()
	# The showcase's bundled prefab asset loads and keeps its step order.
	var marker: Resource = load("res://demo/showcase/draw_lab/target_marker.tres")
	all_passed = _check("draw_lab target_marker.tres loads", marker != null, true) and all_passed
	if marker != null:
		var steps: Array = marker.get("steps")
		all_passed = _check("target marker has 8 ordered steps", steps.size(), 8) and all_passed
		all_passed = _check("target marker draws the outer ring FIRST", str((steps[0] as Dictionary).get("kind", "")), "ring") and all_passed

	# ── The name convention: *_mask params route to the picker with zero ceremony
	var generator: Variant = (load("res://addons/eventsheet/ace/ace_generator.gd") as GDScript).new()
	all_passed = _check("collision_mask routes to the 2D picker", generator.call("_convention_hint", "collision_mask"), "physics_layer_2d") and all_passed
	all_passed = _check("wall_mask routes to the 2D picker", generator.call("_convention_hint", "wall_mask"), "physics_layer_2d") and all_passed
	all_passed = _check("collision_mask_3d routes to the 3D picker", generator.call("_convention_hint", "collision_mask_3d"), "physics_layer_3d") and all_passed
	all_passed = _check("plain mask stays unrouted (layer NUMBERS exist)", generator.call("_convention_hint", "mask"), "") and all_passed

	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] drawing_and_bounds_packs_test: %s" % label)
		return true
	print("[FAIL] drawing_and_bounds_packs_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
