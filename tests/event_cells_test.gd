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
	ok = _every_action_after_a_collapsed_ternary_is_drawn() and ok
	return ok


## The shape the first repair missed: a value that LOOKS like a ternary but does not split (a
## ternary inside a format list) used to stop the scan at that action, so every action after it
## went undrawn while the event still owned a cell - which is why an event-granular walk printed
## clean over it. Both orders are pinned by the WORDS each action draws, so a scan that stops early
## or a real pair that fails to split is named by the cell it did not produce.
static func _every_action_after_a_collapsed_ternary_is_drawn() -> bool:
	var source: String = "
".join(PackedStringArray([
		"extends Node",
		"var speed := 0",
		"var fast := true",
		"var alive := true",
		"var hp := 3",
		"@onready var label: Label = $Label",
		"",
		"",
		"func _process(_delta: float) -> void:",
		"	if visible:",
		"		speed = 1 if fast else 2",
		"		label.text = \"%d\" % [hp if alive else 0]",
		"		speed += 1",
		"	if fast:",
		"		label.text = \"%d\" % [hp if alive else 0]",
		"		speed = 1 if fast else 2",
		"",
	]))
	var sheet: EventSheetResource = GDScriptImporter.new().import_external_source(
		source, true, "res://ternary_orders_fixture.gd")
	if sheet == null:
		return SUPPORT.check(P, "the ternary-orders fixture opens as a sheet", false, true)
	# The cells from the first event on: the file's own header and variable rows are the sheet's
	# anatomy, pinned elsewhere, and this pin is about what the two EVENTS draw.
	var cells: PackedStringArray = PackedStringArray()
	var in_events: bool = false
	for entry: Variant in LINES.readings_of_sheet(sheet, "fixture"):
		var words: String = " ".join((entry as LINES.Reading).plain)
		in_events = in_events or words == "Every tick (draw)"
		if in_events:
			cells.append(words)
	var dropped: PackedStringArray = PackedStringArray()
	for entry: Variant in LINES.events_without_cells(sheet, LINES.readings_of_sheet(sheet, "fixture")):
		dropped.append(str((entry as Dictionary)["reason"]))
	return SUPPORT.pins(P, [
		["no event of the fixture is dropped", dropped, PackedStringArray()],
		["every cell the two orders draw, in canvas order", cells, _expected_order_cells()],
	])


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


## What the fixture's two events draw, cell by cell: the real pair splits into its arms, the text
## write after a collapsed value is drawn, and the increment after that is drawn too - in BOTH orders.
static func _expected_order_cells() -> PackedStringArray:
	return PackedStringArray([
		"Every tick (draw)", "Is visible",
		"fast is true", "Set speed to 1", "Else", "Set speed to 2",
		"Set text to hp if alive else 0",
		"Add 1 to speed",
		"⟳", "Every tick (draw)", "fast is true",
		"Set text to hp if alive else 0",
		"fast is true", "Set speed to 1", "Else", "Set speed to 2",
	])
