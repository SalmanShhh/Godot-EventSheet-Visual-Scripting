# Godot EventSheets - where a Drawing Prefab's line ends, said once and drawn the same everywhere.
#
# A line step runs from its offset (x, y) to its End (p1, p2), and BOTH are points in the prefab's
# own space, measured from the prefab's origin. That is what Draw Prefab has drawn since the first
# day, and what the shipped target marker was made for: two lines from -60 to +60 that cross at
# the centre. The stamp node and the Inspector picture used to end a line at offset + End, which
# drew the same marker as two half arms. This file pins the one meaning in each place a line is
# turned into points: the shared span the game renderers use, the Inspector picture (the software
# rasterizer that also makes the FileSystem thumbnail), and its bounds.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const TEST_NAME := "drawing_prefab_line_end_test"

const RASTER_PATH := "res://addons/eventsheet/editor/inspector/drawing_prefab_preview.gd"
const MARKER_PATH := "res://demo/showcase/draw_lab/target_marker.tres"
const PREFAB_PATH := "res://eventsheet_addons/drawing_prefab_resource/drawing_prefab_resource.gd"
const BACKGROUND := Color(0.0, 0.0, 0.0, 1.0)


static func run() -> bool:
	var ok: bool = true
	ok = _span_pins() and ok
	ok = _picture_pins() and ok
	ok = _marker_pins() and ok
	return ok


## The shared span, asked by name so a tree without it reads as a failed pin rather than a file that
## does not compile (a test that cannot load prints no failure at all).
static func _span(step: Dictionary) -> PackedVector2Array:
	var script: GDScript = load(PREFAB_PATH) as GDScript
	for method: Dictionary in script.get_script_method_list():
		if str(method.get("name", "")) == "line_span":
			return script.call("line_span", step)
	return PackedVector2Array()


static func _line(x: float, y: float, end_x: float, end_y: float) -> Dictionary:
	return {"kind": "line", "x": x, "y": y, "p1": end_x, "p2": end_y, "p3": 4.0, "color": "#ffffff", "texture": ""}


## The span the stamp node and Draw Prefab both draw: from the offset to the End, both in prefab space.
static func _span_pins() -> bool:
	var span: PackedVector2Array = _span(_line(-60.0, 0.0, 60.0, 0.0))
	var at_origin: PackedVector2Array = _span(_line(0.0, 0.0, 24.0, 0.0))
	return SUPPORT.pins(TEST_NAME, [
		["a line starts at its offset", span[0] if span.size() == 2 else Vector2.INF, Vector2(-60.0, 0.0)],
		["and ends at its End, measured from the prefab's origin", span[1] if span.size() == 2 else Vector2.INF, Vector2(60.0, 0.0)],
		["a line at the origin reads the same either way, so no saved prefab of that shape moves",
			at_origin, PackedVector2Array([Vector2.ZERO, Vector2(24.0, 0.0)])],
	])


## The Inspector picture draws the same span. Two dots pin the frame at -60 and +60; the line between
## them is drawn on BOTH sides of the centre.
static func _picture_pins() -> bool:
	var raster: Script = load(RASTER_PATH)
	var steps: Array = [
		_line(-60.0, 0.0, 60.0, 0.0),
		{"kind": "circle", "x": -60.0, "y": 0.0, "p1": 1.0, "color": "#ff0000"},
		{"kind": "circle", "x": 60.0, "y": 0.0, "p1": 1.0, "color": "#ff0000"},
	]
	var image: Image = raster.call("rasterize", steps, Vector2i(130, 130), BACKGROUND)
	var bounds: Rect2 = raster.call("compute_bounds", [_line(-60.0, 0.0, 60.0, 0.0)])
	# The picture is centred on the bounds' centre (x 0) at pixel 65, so local -30 and +30 sit an
	# equal distance either side of it.
	var left: Color = image.get_pixel(40, 65)
	var right: Color = image.get_pixel(90, 65)
	return SUPPORT.pins(TEST_NAME, [
		["the picture draws the line left of the centre", left.g > 0.5, true],
		["and right of it, as far as its End", right.g > 0.5, true],
		["its bounds reach the End, not offset + End", bounds.end.x >= 60.0, true],
	])


## The shipped target marker: its two lines cross at the centre, as Draw Prefab draws it in the game.
static func _marker_pins() -> bool:
	var marker: Resource = ResourceLoader.load(MARKER_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
	var spans: Array = []
	for step: Variant in marker.get("steps"):
		if str((step as Dictionary).get("kind", "")) == "line":
			spans.append(_span(step as Dictionary))
	return SUPPORT.pins(TEST_NAME, [
		["the marker's lines, start and end", spans, [
			PackedVector2Array([Vector2(-60.0, 0.0), Vector2(60.0, 0.0)]),
			PackedVector2Array([Vector2(0.0, -60.0), Vector2(0.0, 60.0)])]],
	])
