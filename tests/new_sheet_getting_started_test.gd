# Godot EventSheets - a new sheet shows its getting-started words under its head row.
#
# A new sheet holds a head band and the "+ Add event" line, and nothing else. The empty-state words used
# to wait for a sheet with no rows at all, which a sheet never is, so a newcomer saw two thin lines and
# no hint of what to do next. The words now sit BELOW those two rows, and go away with the first row or
# variable the sheet gains. This pins the question that decides it (is the sheet only a head band?) and
# the place the words start, in canvas space, which is what keeps them off the rows.
@tool
class_name NewSheetGettingStartedTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const TEST_NAME := "new_sheet_getting_started_test"


static func run() -> bool:
	var sheet: EventSheetResource = EventSheetGDScriptImporter.new().import_external_source("extends Node
", true, "")
	var viewport: EventSheetViewport = EventSheetViewport.new()
	viewport.heads_unsaved_sheets = true
	viewport.set_sheet(sheet)
	var helper: EventSheetViewportEmptyStateHelper = viewport._empty_state_helper
	var rows_when_new: int = viewport.get_flat_rows().size()
	var bottom_when_new: float = helper.rows_bottom()
	var new_sheet_shows_words: bool = helper.is_sheet_only_head_band()
	var fills_the_old_state: bool = helper.is_sheet_visually_empty()

	var event: EventRow = EventRow.new()
	event.trigger_id = "on_ready"
	sheet.events.append(event)
	viewport.set_sheet(sheet)
	var words_with_an_event: bool = helper.is_sheet_only_head_band()

	var with_variable: EventSheetResource = EventSheetGDScriptImporter.new().import_external_source("extends Node
", true, "")
	var variable: LocalVariable = LocalVariable.new()
	variable.name = "hp"
	variable.type_name = "int"
	with_variable.events.append(variable)
	viewport.set_sheet(with_variable)
	var words_with_a_variable: bool = helper.is_sheet_only_head_band()
	viewport.free()
	return SUPPORT.pins(TEST_NAME, [
		["a new sheet holds only its head band and the Add event line", rows_when_new >= 1, true],
		["a new sheet shows the getting-started words", new_sheet_shows_words, true],
		["the words start below the last row, never over it", bottom_when_new > 0.0, true],
		["the old whole-canvas state does not claim a sheet that still has its head row", fills_the_old_state, false],
		["the first event takes the words away", words_with_an_event, false],
		["the first variable takes the words away", words_with_a_variable, false],
	])
