# EventForge - the help strip speaks for the selection in front of the reader. A variable selected on
# one tab put its words in the strip; switching to another tab left them there, describing a row the
# reader could no longer see. Switching tabs now says what the new tab's selection says - nothing, when
# it has none - and coming back says the first tab's again.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")


static func run() -> bool:
	var first: EventSheetResource = SUPPORT.reopen("extends Node2D\n\n@export var walk_speed = 220\n")
	var second: EventSheetResource = SUPPORT.reopen("extends Node\n\n\nfunc _ready() -> void:\n\tprint(\"hi\")\n")
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(first)
	dock._open_sheet_in_tab(first, "user://help_strip_first.gd")
	var first_tab: int = dock._active_tab_index
	var walk: int = -1
	var flat: Array = dock._viewport.get_flat_rows()
	for index: int in flat.size():
		var row: EventRowData = (flat[index] as Dictionary).get("row") as EventRowData
		if row != null and row.source_resource is LocalVariable:
			walk = index
	dock._viewport._select_row(walk)
	dock._update_row_help_strip(dock._viewport.get_selected_row_data())
	var said_first: String = dock._row_help_label.text if dock._row_help_label.visible else ""
	dock._open_sheet_in_tab(second, "user://help_strip_second.gd")
	var said_second: String = dock._row_help_label.text if dock._row_help_label.visible else ""
	dock._activate_tab(first_tab)
	var said_back: String = dock._row_help_label.text if dock._row_help_label.visible else ""
	dock.free()
	return SUPPORT.pins("help_strip_follows_tab_test", [
		["a selected variable puts its words in the strip", said_first.is_empty(), false],
		["another tab with nothing selected leaves the strip empty", said_second, ""],
		["coming back says the first tab's words again", said_back, said_first],
	])
