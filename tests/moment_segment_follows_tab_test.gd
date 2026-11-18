# Godot EventSheets - the toolbar's Moment segment speaks for the selection in front of the reader.
# A Juice Player row selected on one tab left "Juice" and its Play, Stop, Skip, Restore and Open buttons
# on the strip when another tab came to the front with nothing selected, so the buttons described a row
# the reader could no longer see (and a picture taken after other pictures carried them). Switching tabs
# now says what the new tab's selection says - nothing, when it has none.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")


static func run() -> bool:
	var first: EventSheetResource = SUPPORT.reopen("extends Node2D\n\n\nfunc _ready() -> void:\n\tprint(\"hi\")\n")
	var second: EventSheetResource = SUPPORT.reopen("extends Node\n\n\nfunc _ready() -> void:\n\tprint(\"there\")\n")
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(first)
	dock._open_sheet_in_tab(first, "user://moment_segment_first.gd")
	var segment: EventSheetMomentSegment = dock._moment_segment
	var beat_row: ACEAction = ACEAction.new()
	beat_row.provider_id = "FeedbackPlayer"
	beat_row.ace_id = "play"
	segment.follow(beat_row, "")
	var while_selected: Dictionary = segment._subject.duplicate()
	dock._open_sheet_in_tab(second, "user://moment_segment_second.gd")
	var after_switch: Dictionary = segment._subject.duplicate()
	dock.free()
	return SUPPORT.pins("moment_segment_follows_tab_test", [
		["a Juice Player row selected puts the segment on the strip", while_selected.get("kind", ""), "player"],
		["another tab with nothing selected leaves the strip without it", after_switch, {}],
	])
