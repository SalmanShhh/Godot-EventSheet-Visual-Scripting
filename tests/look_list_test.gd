@tool
class_name LookListTest
extends RefCounted

## The list the Variable window picks an Inspector look from: what it shows (ids, headings, the
## selected one, the one sentence per row), the fill that marks the pick, and the pictures.

const SUPPORT := preload("res://tests/support.gd")


static func run() -> bool:
	var ok: bool = true
	ok = _model() and ok
	ok = _fill() and ok
	ok = _pictures() and ok
	ok = _rows_grow() and ok
	return ok


static func _option() -> OptionButton:
	var option: OptionButton = OptionButton.new()
	EventSheetPopupUI.add_described_item(option, "Two number fields", "The Inspector shows the type's own editor.\nWrites @export", "")
	EventSheetPopupUI.add_described_item(option, "Linked fields", "The fields kept in the same ratio.\nWrites link", "link")
	EventSheetPopupUI.add_described_item(option, "Direction dial", "Drag a handle round a circle to aim.\nWrites dial", "vector_dial")
	EventSheetPopupUI.add_described_item(option, "Min-max range", "Two handles on one slider.\nWrites range", "min_max")
	option.select(2)
	return option


static func _model() -> bool:
	var option: OptionButton = _option()
	var model: Array[Dictionary] = EventSheetLookList.model(option)
	var ids: Array = []
	var groups: Array = []
	var selected: Array = []
	for entry: Dictionary in model:
		ids.append(entry["id"])
		groups.append(entry["group"])
		selected.append(entry["selected"])
	var rows: Array = [
		["the rows come in the order the choices were added", ids, ["", "link", "vector_dial", "min_max"]],
		["Godot's own looks sit under one heading and ours under another", groups, ["own", "own", "ours", "ours"]],
		["only the chosen look is marked", selected, [false, false, true, false]],
		["a row's sentence is the first line of its description", model[1]["sentence"], "The fields kept in the same ratio."],
		["a row's title is the name shown", model[2]["title"], "Direction dial"],
		["a row remembers which option item it stands for", model[3]["index"], 3],
		["an unknown id counts as Godot's own", EventSheetLookList.group_of("not_installed_anywhere"), "own"],
		["the plain look is Godot's own", EventSheetLookList.group_of(""), "own"],
		["a written look is Godot's own", EventSheetLookList.group_of("written"), "own"],
	]
	var list: EventSheetLookList = EventSheetLookList.new(option)
	list.rebuild()
	rows.append(["the list builds a row for every choice", list.look_ids(), PackedStringArray(["", "link", "vector_dial", "min_max"])])
	rows.append(["the list is about five rows tall before it scrolls", list.custom_minimum_size.y, list.row_height() * float(EventSheetLookList.VISIBLE_ROWS)])
	list.free()
	option.free()
	return SUPPORT.pins("look_list_test", rows)


## A row is as tall as its wrapped sentence: one that needs more than the least height grows to it, so
## it never runs under the next row, and a short one keeps the least height.
static func _rows_grow() -> bool:
	var option: OptionButton = _option()
	var list: EventSheetLookList = EventSheetLookList.new(option)
	var least: float = list.row_height()
	var air: float = EventSheetLookStyle.px(8.0)
	var rows: Array = [
		["a short row keeps the least height", list.fitted_height(10.0), least],
		["a row whose content is taller than the least grows to the content and its air", list.fitted_height(least + 40.0), least + 40.0 + air],
		["a three-line sentence beside a picture is not cut", list.fitted_height(least + 24.0) >= least + 24.0, true],
	]
	list.rebuild()
	var wraps: Array = []
	for label: Node in list.find_children("*", "Label", true, false):
		wraps.append((label as Label).autowrap_mode)
	rows.append(["a row's sentence wraps rather than being cut", wraps.has(TextServer.AUTOWRAP_WORD_SMART), true])
	list.free()
	option.free()
	return SUPPORT.pins("look_list_test", rows)


static func _fill() -> bool:
	var picked: StyleBoxFlat = EventSheetLookList.fill_box(Color(0.2, 0.4, 0.9))
	var widths: Array = [picked.border_width_left, picked.border_width_top, picked.border_width_right, picked.border_width_bottom]
	return SUPPORT.pins("look_list_test", [
		["the pick is a fill with no border on any side", widths, [0, 0, 0, 0]],
		["the fill is the colour asked for", picked.bg_color, Color(0.2, 0.4, 0.9)],
	])


static func _pictures() -> bool:
	var rows: Array = []
	for look_id: String in EventSheetLookMinis.drawn_ids():
		var known: bool = look_id in ["table", "table_row", "cards"] or not EventSheetInspectorLooks.by_id(look_id).is_empty()
		rows.append(["the picture of %s belongs to a look that exists" % look_id, known, true])
	var colour_keys: Array = []
	for key: String in EventSheetLookMinis.theme_colours().keys():
		colour_keys.append(key)
	colour_keys.sort()
	var wanted: Array = EventSheetLookMinis.COLOUR_KEYS.duplicate()
	wanted.sort()
	var drawn: PackedStringArray = EventSheetLookMinis.drawn_ids()
	rows.append(["Your own hint has a picture of its own", drawn.has("custom"), true])
	rows.append(["Saved but hidden has a picture of its own", drawn.has("storage"), true])
	rows.append(["the editor colour set carries every colour the painter takes", colour_keys, wanted])
	return SUPPORT.pins("look_list_test", rows)
