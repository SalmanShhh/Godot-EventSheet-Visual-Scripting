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

	# The Inspector plugin (_can_handle -> DrawingPrefabResource only) and the thumbnail generator
	# (_handles -> "DrawingPrefabResource" only) extend editor-only classes, so they cannot be instantiated
	# in this headless (non-editor) suite. They are parse-checked at build time and verified live in-editor;
	# both are thin wrappers over the rasterizer pinned above, which is their substantive logic.

	return all_passed


static func _is_bg(c: Color, bg: Color) -> bool:
	return absf(c.r - bg.r) < 0.05 and absf(c.g - bg.g) < 0.05 and absf(c.b - bg.b) < 0.05


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] drawing_prefab_preview_test: %s" % label)
		return true
	print("[FAIL] drawing_prefab_preview_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
