# Godot EventSheets - one event wears its number once.
#
# A function's head and the step it leads with are one event, as are an event and the Local rows it reads as,
# so the margin says the number once, on the first of them; the later rows keep the number for the status
# line and Go to event, and draw none. Before this a function holding locals showed its number beside its
# head and again beside its actions.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "margin_number_once_test"
const SHEETS: Array[String] = [
	"res://demo/showcase/input_rebind/input_rebind.gd",
	"res://demo/showcase/options_and_quick_save/options_and_quick_save.gd",
	"res://demo/showcase/traversal_course/traversal_course.gd",
]


static func run() -> bool:
	var ok: bool = true
	for path: String in SHEETS:
		var sheet: EventSheetResource = SUPPORT.reopen(FileAccess.get_file_as_string(path), true, path)
		sheet.external_source_path = path
		var view := EventSheetViewport.new()
		view.set_ace_registry(EventSheetACERegistry.new())
		view.size = Vector2(1200.0, 900.0)
		view.set_sheet(sheet)
		var worn: Dictionary = {}
		var repeats: Array[int] = []
		var named: Dictionary = {}
		for entry: Dictionary in view.get_flat_rows():
			var row_data: EventRowData = entry.get("row")
			if row_data == null:
				continue
			if row_data.event_number > 0:
				named[row_data.event_number] = true
			var shown: int = _margin_number(row_data)
			if shown <= 0:
				continue
			if worn.has(shown):
				repeats.append(shown)
			worn[shown] = true
		ok = SUPPORT.check(P, "%s: no number is drawn twice" % path.get_file(), repeats, [] as Array[int]) and ok
		ok = SUPPORT.check(P, "%s: every event still has its number on some row" % path.get_file(),
			worn.size(), named.size()) and ok
		view.free()
	# The function with locals: its head wears 14 and nothing under it does.
	var rebind: String = SHEETS[0]
	var sheet_rebind: EventSheetResource = SUPPORT.reopen(FileAccess.get_file_as_string(rebind), true, rebind)
	sheet_rebind.external_source_path = rebind
	var rebind_view := EventSheetViewport.new()
	rebind_view.set_ace_registry(EventSheetACERegistry.new())
	rebind_view.size = Vector2(1200.0, 900.0)
	rebind_view.set_sheet(sheet_rebind)
	var drawn_for_14: Array[String] = []
	var named_14: int = 0
	for entry: Dictionary in rebind_view.get_flat_rows():
		var row_data: EventRowData = entry.get("row")
		if row_data == null:
			continue
		if row_data.event_number == 14:
			named_14 += 1
		if _margin_number(row_data) == 14:
			drawn_for_14.append(row_data.row_uid)
	ok = SUPPORT.check(P, "define_control: more than one row belongs to event 14", named_14 > 1, true) and ok
	ok = SUPPORT.check(P, "define_control: only the head draws 14", drawn_for_14, ["define_fn_define_control"] as Array[String]) and ok
	# Go to event and the margin still agree: the number finds the same event.
	var target: EventRow = EventSheetViewport.event_by_number(sheet_rebind.events, 14, sheet_rebind.functions)
	ok = SUPPORT.check(P, "Go to event 14 still finds the function's step", target != null, true) and ok
	rebind_view.free()
	return ok


## What the margin draws beside a row. A row that cannot say (an older build of the editor) draws its event number.
static func _margin_number(row_data: EventRowData) -> int:
	return row_data.margin_number() if row_data.has_method("margin_number") else row_data.event_number
