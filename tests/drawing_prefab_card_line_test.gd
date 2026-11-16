# Godot EventSheets - the Drawing Prefab's folded card line: a tile that draws the shape in its own
# colour, the shape's plain name, and a quiet summary in the shape's own words.
#
# Pinned as data and as pixels: the summary text per shape, the title, the tile's image (where it is
# filled, where it is empty, what the light ground's faint edge does), and that a write repaints the
# head IN PLACE - the tile in the list is the same node before and after a colour edit.
@tool
class_name DrawingPrefabCardLineTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const PREFIX := "drawing_prefab_card_line_test"
const PREFAB_STEPS := preload("res://addons/eventsheet/editor/inspector/drawing_prefab_steps_property.gd")
const TILE_PATH := "res://addons/eventsheet/editor/inspector/drawing_prefab_shape_tile.gd"


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _pin_the_summaries() and all_passed
	all_passed = _pin_the_titles() and all_passed
	all_passed = _pin_the_tile_image() and all_passed
	all_passed = _pin_the_head_repaints_in_place() and all_passed
	return all_passed


static func _step(kind: String, extra: Dictionary) -> Dictionary:
	var step: Dictionary = {"kind": kind, "x": 0.0, "y": 0.0, "p1": 0.0, "p2": 0.0, "p3": 0.0, "color": "#ffffff", "texture": ""}
	for key: Variant in extra:
		step[str(key)] = extra[key]
	return step


static func _pin_the_summaries() -> bool:
	var steps_editor: GDScript = PREFAB_STEPS.ShapeStepsEditor
	return SUPPORT.pins(PREFIX, [
		["a circle says its radius", steps_editor.call("summary_of", _step("circle", {"p1": 5.0})), "radius 5"],
		["a ring says its radius and its thickness", steps_editor.call("summary_of", _step("ring", {"p1": 46.0, "p2": 5.0})), "radius 46, 5 px thick"],
		["a rectangle says its size", steps_editor.call("summary_of", _step("rect", {"p1": 24.0, "p2": 16.0})), "24 x 16"],
		["a line says its TRUE length, from its start to its end", steps_editor.call("summary_of", _step("line", {"x": -60.0, "p1": 60.0})), "120 px long"],
		["a slanted line is measured along the slant", steps_editor.call("summary_of", _step("line", {"x": 0.0, "y": 0.0, "p1": 3.0, "p2": 4.0, "p3": 2.0})), "5 px long"],
		["a cone says how wide it opens", steps_editor.call("summary_of", _step("cone", {"p2": 60.0})), "60° wide"],
		["a stamp says its file's name", steps_editor.call("summary_of", _step("stamp", {"texture": "res://icon.svg"})), "icon.svg"],
		["a stamp with nothing picked says so", steps_editor.call("summary_of", _step("stamp", {})), "no texture"],
		["a size that is not whole keeps its decimals", steps_editor.call("summary_of", _step("circle", {"p1": 2.5})), "radius 2.5"],
		["a shape this list does not know is named as written", steps_editor.call("summary_of", _step("blob", {})), "blob"],
	])


static func _pin_the_titles() -> bool:
	var editor: PREFAB_STEPS.ShapeStepsEditor = PREFAB_STEPS.ShapeStepsEditor.new()
	editor.set_steps([_step("rect", {}), _step("circle", {}), _step("stamp", {})])
	var labels: PackedStringArray = editor.card_labels()
	editor.free()
	return SUPPORT.pins(PREFIX, [
		["a rectangle's card says Rectangle, the stored word stays rect", ",".join(labels), "Rectangle,Circle,Stamp"],
	])


static func _alpha_at(image: Image, x: int, y: int) -> float:
	return image.get_pixel(x, y).a


static func _pin_the_tile_image() -> bool:
	var tile: Script = load(TILE_PATH) as Script
	var side: int = 14
	var red: Color = Color(1.0, 0.0, 0.0)
	var pale: Color = Color(1.0, 1.0, 1.0)
	var rows: Array = []
	for kind: String in ["circle", "ring", "rect", "line", "cone", "stamp"]:
		var image: Image = tile.call("shape_image", kind, red, side, false)
		rows.append(["%s: the tile is %d px square" % [kind, side], "%dx%d" % [image.get_width(), image.get_height()], "%dx%d" % [side, side]])
		rows.append(["%s: the tile is drawn in the step's colour" % kind, _has_colour(image, red), true])
		rows.append(["%s: the tile has empty corners, so it is a shape and not a box" % kind, _alpha_at(image, 0, 0) < 0.05 or _alpha_at(image, side - 1, 0) < 0.05, true])
	var disc: Image = tile.call("shape_image", "circle", red, side, false)
	var ring: Image = tile.call("shape_image", "ring", red, side, false)
	rows.append(["a circle is filled at its centre", _alpha_at(disc, 7, 7) > 0.95, true])
	rows.append(["a ring is empty at its centre", _alpha_at(ring, 7, 7) < 0.05, true])
	# A pale shape on a light ground keeps a faint edge that follows the shape; on a dark ground it has none.
	var pale_light: Image = tile.call("shape_image", "circle", pale, side, true)
	var pale_dark: Image = tile.call("shape_image", "circle", pale, side, false)
	rows.append(["a pale disc on the light theme has an edge darker than itself", _has_dark_edge(pale_light), true])
	rows.append(["the same disc on the dark theme has none", _has_dark_edge(pale_dark), false])
	rows.append(["the faint edge follows the disc: the corner stays empty", _alpha_at(pale_light, 0, 0) < 0.05, true])
	return SUPPORT.pins(PREFIX, rows)


static func _has_colour(image: Image, wanted: Color) -> bool:
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			var pixel: Color = image.get_pixel(x, y)
			if pixel.a > 0.9 and absf(pixel.r - wanted.r) < 0.05 and absf(pixel.g - wanted.g) < 0.05 and absf(pixel.b - wanted.b) < 0.05:
				return true
	return false


static func _has_dark_edge(image: Image) -> bool:
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			var pixel: Color = image.get_pixel(x, y)
			if pixel.a > 0.1 and pixel.get_luminance() < 0.6:
				return true
	return false


## A write repaints the head where it stands: the tile node and the summary are the SAME instances, so a
## colour typed under the cursor is not a list rebuilt out from under it.
static func _pin_the_head_repaints_in_place() -> bool:
	var editor: PREFAB_STEPS.ShapeStepsEditor = PREFAB_STEPS.ShapeStepsEditor.new()
	editor.set_steps([_step("ring", {"p1": 46.0, "p2": 5.0, "color": "#ffd24d"})])
	var tile: Control = editor.call("head_tile_of", 0)
	var has_tile: bool = tile != null
	var summary_before: String = editor.call("head_summary_of", 0)
	editor.write_card_key(0, "color", "#ff0000")
	var same_tile: bool = editor.call("head_tile_of", 0) == tile
	var tile_colour: Color = tile.get("shown_color") if tile != null else Color.BLACK
	editor.write_card_key(0, "p1", 10.0)
	var summary_after: String = editor.call("head_summary_of", 0)
	editor.free()
	return SUPPORT.pins(PREFIX, [
		["the card line wears a tile", has_tile, true],
		["the summary reads the stored sizes", summary_before, "radius 46, 5 px thick"],
		["a colour write keeps the tile node", same_tile, true],
		["and the tile now shows the new colour", tile_colour.to_html(false), "ff0000"],
		["a size write rewrites the summary in place", summary_after, "radius 10, 5 px thick"],
	])
