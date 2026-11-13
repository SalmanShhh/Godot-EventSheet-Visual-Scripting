@tool
class_name SilentHolesRuntimeTest
extends RefCounted

# A failure in the running game is an error at a file and a line. The sheet that wrote that file can say
# which row wrote the line - for ANY open sheet and with the Code panel closed, not only for the tab on
# screen while the panel is showing. Nothing in the emitted game is changed to make that true.

const SUPPORT := preload("res://tests/support.gd")
const NAME := "silent_holes_runtime_test"


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _locator_finds_the_tab_and_the_map() and all_passed
	all_passed = _an_error_in_another_tab_finds_its_row_and_jumps_there() and all_passed
	return all_passed


static func _sheet_with_event(event_name: String) -> Array:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnProcess"
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "Silent%s" % event_name
	action.codegen_template = "silent_%s()" % event_name
	event.actions.append(action)
	sheet.events.append(event)
	return [sheet, event]


static func _locator_finds_the_tab_and_the_map() -> bool:
	EventSheetRuntimeErrorLocator.clear()
	var made: Array = _sheet_with_event("alpha")
	var sheet: EventSheetResource = made[0]
	sheet.take_over_path("user://silent_holes_runtime_c.tres")
	var written: Dictionary = EventSheetCompiler.compile(sheet, "")
	var output_path: String = EventSheetRuntimeErrorLocator.output_path_of(sheet)
	var other: Array = _sheet_with_event("beta")
	var other_sheet: EventSheetResource = other[0]
	other_sheet.external_source_path = "res://game/other_script.gd"
	var tabs: Array = [{"sheet": other_sheet}, {"sheet": sheet}]
	var fresh: Dictionary = EventSheetRuntimeErrorLocator.source_map_for(sheet, false)
	# An edit since the save: the file the game ran is no longer what the sheet would write.
	var extra: EventRow = EventRow.new()
	extra.trigger_provider_id = "Core"
	extra.trigger_id = "OnReady"
	var extra_action: ACEAction = ACEAction.new()
	extra_action.provider_id = "Core"
	extra_action.ace_id = "SilentGamma"
	extra_action.codegen_template = "silent_gamma()"
	extra.actions.append(extra_action)
	sheet.events.insert(0, extra)
	var edited: Dictionary = EventSheetRuntimeErrorLocator.source_map_for(sheet, true)
	var passed: bool = SUPPORT.pins(NAME, [
		["the compile wrote the sheet's script", bool(written.get("success", false)), true],
		["a .tres sheet's output is the script beside it", output_path.ends_with("_generated.gd"), true],
		["the tab that wrote the named file is found by its whole path", EventSheetRuntimeErrorLocator.tab_for(tabs, output_path), 1],
		["another tab is found by its own file", EventSheetRuntimeErrorLocator.tab_for(tabs, "res://game/other_script.gd"), 0],
		["a file nobody wrote is no tab", EventSheetRuntimeErrorLocator.tab_for(tabs, "res://game/nothing.gd"), -1],
		["the map is there without a Code panel", (fresh.get("map", []) as Array).is_empty(), false],
		["and matches the file the game ran", bool(fresh.get("stale", true)), false],
		["an edit since the save makes it stale: no row is pointed at", bool(edited.get("stale", false)), true],
	])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(output_path))
	EventSheetRuntimeErrorLocator.clear()
	return passed


static func _an_error_in_another_tab_finds_its_row_and_jumps_there() -> bool:
	var first: Array = _sheet_with_event("one")
	var second: Array = _sheet_with_event("two")
	var first_sheet: EventSheetResource = first[0]
	var second_sheet: EventSheetResource = second[0]
	var second_event: EventRow = second[1]
	second_sheet.external_source_path = "res://game/second_script.gd"
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(first_sheet)
	dock._open_sheet_in_tab(second_sheet, "")
	dock._activate_tab(0)
	var line: int = EventSheetLineRowMapper.range_for_resource(
		EventSheetCompiler.echo(second_sheet).get("source_map", []), second_event).x
	var side_panel_open: bool = dock._side_panel != null and dock._side_panel.visible
	var report: Dictionary = dock.report_runtime_error(
		"Invalid call. Nonexistent function 'silent_two' in base 'Node'.", "res://game/second_script.gd", line)
	var found_row: bool = report.get("row_resource") == second_event
	var found_tab: int = int(report.get("tab_index", -9))
	var still_on_first: int = dock._active_tab_index
	dock._jump_to_runtime_error_row()
	var passed: bool = SUPPORT.pins(NAME, [
		["the Code panel was never opened", side_panel_open, false],
		["the error resolved to the row of the OTHER sheet", found_row, true],
		["and names that sheet's tab", found_tab, 1],
		["the report did not steal focus from the tab on screen", still_on_first, 0],
		["Jump to event is live", dock._runtime_error_jump_button.disabled, false],
		["Jump brings that tab forward", dock._active_tab_index, 1],
	])
	dock.free()
	return passed
