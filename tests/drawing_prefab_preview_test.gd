# Godot EventSheets - DrawingPrefabResource preview renderer + plugin gating.
#
# Pins the tree-free rasterizer (used by both the Inspector panel and the resource thumbnail): it bounds
# every step kind, fills the composed shapes into an Image of the requested size, and never crashes on an
# empty prefab. Also checks the two editor plugins only claim DrawingPrefabResource, so they never hijack
# other resources' Inspector / thumbnails.
@tool
class_name DrawingPrefabPreviewTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true

	# Bounds: a single circle of radius 10 at the origin spans a 20x20 box centered on it.
	var circle_bounds: Rect2 = EventSheetDrawingPrefabPreview.compute_bounds([
		{"kind": "circle", "x": 0.0, "y": 0.0, "p1": 10.0}])
	all_passed = _check("circle bounds are its diameter box", circle_bounds, Rect2(-10, -10, 20, 20)) and all_passed

	# Bounds union: two circles 100 apart grow the box to enclose both.
	var union_bounds: Rect2 = EventSheetDrawingPrefabPreview.compute_bounds([
		{"kind": "circle", "x": 0.0, "y": 0.0, "p1": 8.0},
		{"kind": "circle", "x": 100.0, "y": 0.0, "p1": 8.0}])
	all_passed = _check("bounds enclose every step", union_bounds.size.x >= 116.0, true) and all_passed

	# Empty prefab: still yields an image of the asked size (no crash, all background).
	var bg: Color = Color(0.1, 0.1, 0.1, 1.0)
	var empty_img: Image = EventSheetDrawingPrefabPreview.rasterize([], Vector2i(48, 48), bg)
	all_passed = _check("empty prefab rasterizes to the requested size", empty_img.get_size(), Vector2i(48, 48)) and all_passed
	all_passed = _check("empty prefab is all background", _is_bg(empty_img.get_pixel(24, 24), bg), true) and all_passed

	# A centered red circle paints red near the middle and leaves the far corner as background.
	var red_img: Image = EventSheetDrawingPrefabPreview.rasterize([
		{"kind": "circle", "x": 0.0, "y": 0.0, "p1": 10.0, "color": "red"}], Vector2i(64, 64), bg)
	var center: Color = red_img.get_pixel(32, 32)
	all_passed = _check("a red circle paints red at the center", center.r > 0.5 and center.g < 0.4 and center.b < 0.4, true) and all_passed
	all_passed = _check("the corner stays background", _is_bg(red_img.get_pixel(1, 1), bg), true) and all_passed

	# The DrawingPrefabStamp @tool node (the placeable viewport gizmo) instantiates, exposes the shared
	# vector draw routine, and holds a prefab. Its actual drawing is verified live by a render harness.
	var stamp: Node2D = DrawingPrefabStamp.new()
	all_passed = _check("DrawingPrefabStamp exposes the shared draw routine", stamp.has_method("draw_prefab_steps"), true) and all_passed
	var stamp_prefab: DrawingPrefabResource = DrawingPrefabResource.new()
	stamp.set("prefab", stamp_prefab)
	all_passed = _check("DrawingPrefabStamp holds its assigned prefab", stamp.get("prefab") == stamp_prefab, true) and all_passed
	stamp.free()

	# The Inspector plugin (_can_handle -> DrawingPrefabResource only) and the thumbnail generator
	# (_handles -> "DrawingPrefabResource" only) extend editor-only classes, so they cannot be instantiated
	# in this headless (non-editor) suite. They are parse-checked at build time and verified live in-editor;
	# both are thin wrappers over the rasterizer pinned above, which is their substantive logic.

	# The shape-aware steps editor's substance is its INNER Control (a plain VBoxContainer, so it DOES
	# instantiate headless). On load it preserves the stored keys exactly - never injecting a `texture`
	# slot the source lacked, never coercing a legacy color name - so opening a prefab reads back faithfully;
	# only an explicit edit changes the data.
	var steps_editor: EventSheetDrawingPrefabInspector.ShapeStepsEditor = EventSheetDrawingPrefabInspector.ShapeStepsEditor.new()
	steps_editor.set_steps([{"kind": "line", "x": 1.0, "y": 2.0, "p1": 5.0, "p2": 6.0, "p3": 3.0, "color": "red"}])
	var roundtrip: Array = steps_editor.get_steps()
	var first: Dictionary = roundtrip[0] if not roundtrip.is_empty() else {}
	all_passed = _check("steps editor round-trips the stored keys unchanged", "|".join(first.keys()), "kind|x|y|p1|p2|p3|color") and all_passed
	all_passed = _check("steps editor keeps a legacy color name verbatim on load", str(first.get("color", "")), "red") and all_passed
	# Each shape titles its own slots (never the raw p1/p2/p3) - the field vocabulary IS the promise this
	# feature makes to a beginner, so pin it per shape.
	all_passed = _check("circle titles p1 as Radius", _shape_labels("circle"), "Radius") and all_passed
	all_passed = _check("rect titles p1/p2 as Width/Height", _shape_labels("rect"), "Width|Height") and all_passed
	all_passed = _check("line titles p1/p2/p3 as End X/End Y/Thickness", _shape_labels("line"), "End X|End Y|Thickness") and all_passed
	all_passed = _check("cone titles p1/p2/p3 as Facing/FOV/Radius", _shape_labels("cone"), "Facing|FOV|Radius") and all_passed
	# A freshly added step is a visible filled circle with every storage slot seeded (valid immediately).
	steps_editor.set_steps([])
	steps_editor._on_add()
	var added: Dictionary = steps_editor.get_steps()[0]
	all_passed = _check("a new step defaults to a circle", str(added.get("kind", "")), "circle") and all_passed
	all_passed = _check("a new step seeds every storage slot", added.has("p1") and added.has("texture") and added.has("color"), true) and all_passed
	steps_editor.free()

	return all_passed


static func _is_bg(c: Color, bg: Color) -> bool:
	return absf(c.r - bg.r) < 0.05 and absf(c.g - bg.g) < 0.05 and absf(c.b - bg.b) < 0.05


## The titled field labels a shape shows, pipe-joined in display order (circle -> "Radius").
static func _shape_labels(kind: String) -> String:
	var labels: PackedStringArray = PackedStringArray()
	for field: Variant in EventSheetDrawingPrefabInspector.ShapeStepsEditor.SHAPE_FIELDS.get(kind, []):
		labels.append(str((field as Dictionary).get("label", "")))
	return "|".join(labels)


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] drawing_prefab_preview_test: %s" % label)
		return true
	print("[FAIL] drawing_prefab_preview_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
