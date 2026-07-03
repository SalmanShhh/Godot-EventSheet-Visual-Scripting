# EventForge — the read-only .gd preview banner must always describe the ACTIVE tab's sheet. A cached
# lift report made it keep the previously-opened sheet's counts after a tab switch ("9 event(s)" car
# showing timer's "1 event(s)"); the banner now recomputes from the active sheet on every refresh.
@tool
class_name PreviewBannerTabTest
extends RefCounted

const CAR := "res://eventsheet_addons/car/car_behavior.gd"
const TIMER := "res://eventsheet_addons/timer/timer_behavior.gd"


static func run() -> bool:
	var ok: bool = true

	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(EventSheetResource.new())

	dock._load_sheet_from_path(CAR)
	var car_summary: String = EventSheetLiftReport.summary(EventSheetLiftReport.for_sheet(dock.get_current_sheet()))
	ok = _check("banner shows car's counts on open", dock._preview_label.text.contains(car_summary), true) and ok

	dock._load_sheet_from_path(TIMER)
	var timer_summary: String = EventSheetLiftReport.summary(EventSheetLiftReport.for_sheet(dock.get_current_sheet()))
	ok = _check("banner shows timer's counts on open", dock._preview_label.text.contains(timer_summary), true) and ok
	ok = _check("the two packs genuinely differ (a meaningful regression guard)", car_summary != timer_summary, true) and ok

	# THE regression: re-activating car's tab must swap the banner back to car's counts.
	var car_tab: int = -1
	for index: int in range(dock._open_tabs.size()):
		var tab_sheet: EventSheetResource = dock._open_tabs[index].get("sheet")
		if tab_sheet != null and tab_sheet.external_source_path == CAR:
			car_tab = index
	ok = _check("found car's tab", car_tab >= 0, true) and ok
	dock._activate_tab(car_tab)
	ok = _check("banner names car after the tab switch", dock._preview_label.text.contains("car_behavior.gd"), true) and ok
	ok = _check("banner shows CAR's counts after the tab switch (not timer's)", dock._preview_label.text.contains(car_summary), true) and ok

	dock.free()
	return ok


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] preview_banner_tab_test: %s" % label)
		return true
	print("[FAIL] preview_banner_tab_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
