# Godot EventSheets - no coloured bar down the left edge of a row, a cell, a card or a panel.
#
# A coloured strip on the left edge is a look the editor does not wear anywhere: a state is told by
# the colour of the thing itself (its number, its tint, its icon) and structure by a neutral hairline.
# Two halves here:
#
#   1. A sweep of the editor's own code for the two ways such a strip gets drawn - a narrow rectangle
#      the full height of its row or cell starting at its left corner, and a left border on a
#      StyleBoxFlat. Neither may come back. (A rectangle that ends at a gutter's right edge, a drop
#      line or a bar chart is not at the left corner and is not matched.)
#   2. The one structural rule that remains, a group's bracket down the margin, is neutral: every
#      stroke is the theme's own guide colour, whatever colour the group's bar wears.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "left_edge_bars_test"
const ROOT: String = "res://addons/eventsheet"

## A script with a region round it: the region is the group whose bracket runs down the margin.
const SOURCE: String = "extends Node2D


#region Movement
func go() -> void:
	position.x += 1.0


func stop() -> void:
	position.x = 0.0
#endregion
"

## A rectangle that starts at the left corner of a row or cell, has a literal width and takes the
## whole height: Rect2(row_rect.position.x, row_rect.position.y, 3.0, row_rect.size.y).
const STRIP_BY_COORDINATES: String = "draw_rect\\(\\s*Rect2\\(\\s*[\\w.]+\\.position\\.x\\s*,\\s*[\\w.]+\\.position\\.y\\s*,\\s*[0-9.]+\\s*,\\s*[\\w.]+\\.size\\.y"

## The same strip spelled with a corner: Rect2(row_rect.position, Vector2(3.0, row_rect.size.y)).
const STRIP_BY_CORNER: String = "draw_rect\\(\\s*Rect2\\(\\s*[\\w.]+\\.position\\s*,\\s*Vector2\\(\\s*[0-9.]+\\s*,\\s*[\\w.]+\\.size\\.y"

## A left border on a box, in either spelling, whose width is not zero.
const LEFT_BORDER_ASSIGNED: String = "border_width_left\\s*=\\s*[^0\\s]"
const LEFT_BORDER_CALL: String = "set_border_width\\(\\s*SIDE_LEFT\\s*,\\s*[^0\\s]"


static func run() -> bool:
	var ok: bool = true
	ok = _sweep_pins() and ok
	ok = _bracket_pins() and ok
	return ok


static func _sweep_pins() -> bool:
	var patterns: Dictionary = {
		"a full-height strip drawn from a row's corner": STRIP_BY_COORDINATES,
		"a full-height strip drawn from a cell's corner": STRIP_BY_CORNER,
		"a left border assigned on a box": LEFT_BORDER_ASSIGNED,
		"a left border set by side on a box": LEFT_BORDER_CALL,
	}
	var found: Dictionary = {}
	for label: String in patterns:
		found[label] = PackedStringArray()
	for path: String in _gd_files(ROOT):
		var lines: PackedStringArray = FileAccess.get_file_as_string(path).split("\n")
		for index: int in lines.size():
			var line: String = lines[index]
			if line.strip_edges().begins_with("#"):
				continue
			for label: String in patterns:
				var matcher: RegEx = RegEx.create_from_string(str(patterns[label]))
				if matcher.search(line) != null:
					(found[label] as PackedStringArray).append("%s:%d" % [path.trim_prefix("res://"), index + 1])
	var rows: Array = []
	for label: String in patterns:
		rows.append([label, ", ".join(found[label] as PackedStringArray), ""])
	return SUPPORT.pins(P, rows)


## Every stroke a group's bracket is drawn with is the look's neutral guide colour.
static func _bracket_pins() -> bool:
	var sheet: EventSheetResource = SUPPORT.reopen(SOURCE)
	if sheet == null:
		return SUPPORT.check(P, "the sample script opens as a sheet", false, true)
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(sheet)
	var viewport: EventSheetViewport = editor.get_viewport_control()
	var strokes: Array = viewport.group_bracket_strokes(900.0)
	var guide: Color = viewport._get_reading_style().tree_guide_color
	var off_colour: int = 0
	for stroke: Variant in strokes:
		var drawn: Dictionary = stroke as Dictionary
		if str(drawn.get("part", "")) in ["bar", "tick", "dash"] and Color(drawn["color"]) != guide:
			off_colour += 1
	var ok: bool = SUPPORT.pins(P, [
		["the sample script has a bracket to look at", strokes.size() > 0, true],
		["no bracket stroke wears a colour of its own", off_colour, 0],
	])
	editor.free()
	return ok


static func _gd_files(folder: String) -> PackedStringArray:
	var files: PackedStringArray = PackedStringArray()
	var dir: DirAccess = DirAccess.open(folder)
	if dir == null:
		return files
	for name: String in dir.get_files():
		if name.ends_with(".gd"):
			files.append(folder.path_join(name))
	for sub: String in dir.get_directories():
		files.append_array(_gd_files(folder.path_join(sub)))
	return files
