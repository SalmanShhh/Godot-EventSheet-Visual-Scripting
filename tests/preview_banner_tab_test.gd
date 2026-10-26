# EventForge - an opened .gd says what it is on its head bar, and always about the ACTIVE tab's sheet.
#
# A preview used to open under a full-width banner ("Viewing car_behavior.gd as a sheet - just start
# editing ... (9 event(s), ...)") and the status bar said the same sentence again. Both are gone: the
# banner is shown only for a file an unfinished merge blocks, the status bar names the file, and what
# the file is and its door to the script editor are the head bar and its name card - which, like the
# banner it replaced, must describe the sheet whose tab is active, not the last one opened.
@tool
class_name PreviewBannerTabTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const CAR := "res://eventsheet_addons/car/car_behavior.gd"
const TIMER := "res://eventsheet_addons/timer/timer_behavior.gd"


static func run() -> bool:
	var ok: bool = true

	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(EventSheetResource.new())

	dock._load_sheet_from_path(CAR)
	var car_card: Dictionary = _name_card(dock)
	ok = _check("no banner over an opened file", dock._preview_banner.visible, false) and ok
	ok = _check("the status bar names the file, and says nothing more", dock._status_label.text, "car_behavior.gd") and ok
	ok = _check("the head bar is car's", _head_words(dock), "◆ CarBehavior Behaviour") and ok
	ok = _check("and its name card offers the script editor", Array(car_card.get("doors", [])).has(
		["Open in the script editor", "open_script_editor"]), true) and ok

	dock._load_sheet_from_path(TIMER)
	var timer_card: Dictionary = _name_card(dock)
	ok = _check("timer's head bar names timer", _head_words(dock), "◆ TimerBehavior Behaviour") and ok
	ok = _check("the two packs genuinely differ (a meaningful regression guard)",
		str(car_card.get("notes", [])) != str(timer_card.get("notes", [])), true) and ok

	# THE regression the banner once had: re-activating car's tab must show car's words again.
	var car_tab: int = -1
	for index: int in range(dock._open_tabs.size()):
		var tab_sheet: EventSheetResource = dock._open_tabs[index].get("sheet")
		if tab_sheet != null and tab_sheet.external_source_path == CAR:
			car_tab = index
	ok = _check("found car's tab", car_tab >= 0, true) and ok
	dock._activate_tab(car_tab)
	ok = _check("the head bar is car's after the tab switch", _head_words(dock), "◆ CarBehavior Behaviour") and ok
	ok = _check("with CAR's facts on its card, not timer's", str(_name_card(dock).get("notes", [])),
		str(car_card.get("notes", []))) and ok
	ok = _check("and still no banner", dock._preview_banner.visible, false) and ok

	dock.free()
	return ok


## The active view's head bar, its words joined.
static func _head_words(dock: EventSheetDock) -> String:
	for entry: Dictionary in dock._viewport.get_flat_rows():
		var row_data: EventRowData = entry.get("row")
		if row_data == null or not row_data.row_uid.begins_with("sheet_head_bar_"):
			continue
		var words: PackedStringArray = PackedStringArray()
		for span: SemanticSpan in row_data.spans:
			if not span.text.strip_edges().is_empty():
				words.append(span.text.strip_edges())
		return " ".join(words)
	return ""


## The card behind the active view's head bar name, {} when there is none.
static func _name_card(dock: EventSheetDock) -> Dictionary:
	for entry: Dictionary in dock._viewport.get_flat_rows():
		var row_data: EventRowData = entry.get("row")
		if row_data == null:
			continue
		for span: SemanticSpan in row_data.spans:
			var card: Variant = (span.metadata as Dictionary).get("head_card") if span.metadata is Dictionary else null
			if card is Dictionary and str((card as Dictionary).get("id", "")) == "name":
				return card
	return {}


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("preview_banner_tab_test", label, actual, expected)
