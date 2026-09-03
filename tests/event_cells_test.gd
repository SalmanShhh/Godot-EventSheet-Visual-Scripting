@tool
class_name EventCellsTest
extends RefCounted

# Godot EventSheets - every event of an opened sheet has to reach the canvas.
#
# A row the row builder DROPS leaves nothing behind: no row data, no spans, no cell, and so nothing
# for a reading walk to notice. That is not hypothetical. A guard added to the ternary-branch pass
# made an untyped array return reachable for the first time; the assignment behind it failed, the
# expansion came back empty, and two whole `_process` events vanished from the canvas of two
# showcases while every gate in the tree still printed green.
#
# So this pins the thing those gates could not see: for each file below, every `EventRow` the sheet
# holds owns at least one cell on the resting canvas walk, or has one of the two harmless reasons not
# to (a pick-filter shell another reading replaces, a body a published verb draws in its own shape).
# An event with no cell and no reason is a dropped event and fails here by name.
#
# THE FILES ARE THE ONES THAT BIT, plus one that is legitimately short of a cell, so a change that
# broke the explanation rather than the reading is caught too. The population is small on purpose:
# the whole tree is what `tools/reading_dump.gd` walks, and it takes minutes.

const SUPPORT := preload("res://tests/support.gd")
const LINES := preload("res://tools/reading_lines.gd")
const P: String = "event_cells_test"

## The two showcases whose bracketed-value events were dropped, and the shell row that owns no cell
## for a reason. Each is pinned by what it must say, not merely by a count.
const HIERARCHY: String = "res://demo/showcase/hierarchy_playground/hierarchy_playground.gd"
const RAYCAST_3D: String = "res://demo/showcase/raycast_lab_3d/raycast_lab_3d.gd"
const SHOOTER: String = "res://demo/showcase/platformer_shooter/platformer_shooter.gd"


static func run() -> bool:
	var ok: bool = true
	ok = _no_event_is_dropped() and ok
	ok = _a_shell_says_why() and ok
	return ok


## The repair itself: neither file loses an event, and both hold the bracketed values that made the
## expansion fire in the first place - so a pin that passed because the sheet stopped branching at
## all would still fail.
static func _no_event_is_dropped() -> bool:
	var rows: Array = []
	var dropped: PackedStringArray = PackedStringArray()
	for path: String in [HIERARCHY, RAYCAST_3D, SHOOTER]:
		var missing: Array = _missing_of(path)
		rows.append(_event_count(path))
		for entry: Variant in missing:
			var found: Dictionary = entry as Dictionary
			if str(found["reason"]) == LINES.NO_CELL_DROPPED:
				dropped.append(path.get_file())
	return SUPPORT.pins(P, [
		["no event of the pinned sheets is dropped from the canvas", dropped, PackedStringArray()],
		["hierarchy_playground.gd still opens with events to draw", rows[0] > 0, true],
		["raycast_lab_3d.gd still opens with events to draw", rows[1] > 0, true],
		["platformer_shooter.gd still opens with events to draw", rows[2] > 0, true],
	])


## The other half: a row that owns no cell for a HARMLESS reason is named as that reason rather than
## as a fault, so the pin above cannot be made to pass by calling every missing row explained.
static func _a_shell_says_why() -> bool:
	var reasons: PackedStringArray = PackedStringArray()
	for entry: Variant in _missing_of(SHOOTER):
		reasons.append(str((entry as Dictionary)["reason"]))
	return SUPPORT.pins(P, [
		["the shooter's pick-filter shell owns no cell and says why",
			reasons, PackedStringArray([LINES.NO_CELL_PICKING])],
	])


## One file's events that own no cell, opened the way the editor opens a `.gd`.
static func _missing_of(path: String) -> Array:
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(path)
	if sheet == null:
		push_error("%s: %s does not open as a sheet" % [P, path])
		return []
	return LINES.events_without_cells(sheet, LINES.readings_of_sheet(sheet, path))


## How many events one file holds at all - the guard against a green run over an empty sheet.
static func _event_count(path: String) -> int:
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(path)
	return 0 if sheet == null else LINES.event_rows_of(sheet).size()
