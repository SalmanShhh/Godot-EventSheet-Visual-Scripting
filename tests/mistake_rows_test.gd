# Godot EventSheets - the mistake checks on the canvas, in the strip and in the Doctor.
#
# The detection is pinned in mistake_checks_test; this file pins where it LANDS. A row that says a
# mistake wears the quiet state (amber for a warning, red for an error) and nothing is drawn inside
# it; the words and the doors are the help strip's; the same finding is a line in the Doctor with the
# same chips. A door changes the open sheet through undo and the finding goes away.
@tool
class_name MistakeRowsTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const TEST_NAME: String = "mistake_rows"
## The script a door REWRITES when it saves the sheet: its own fixture, put back as it was after the
## run, so no other test ever reads it changed.
const LEVEL := "res://tests/fixtures/mistake_rows_level.gd"
const LEVEL_TEXT := "extends Node2D\n"
const SCRIPT_FIXTURE := "res://tests/fixtures/mistake_script.gd"

const SOURCE := "extends Node2D\n\nsignal hit(damage: int)\n\nvar lives: int = 3\nvar score: int = 0\n\n\nfunc go() -> void:\n\thit.emit()\n\n\nfunc tidy() -> void:\n\tfor node in get_tree().get_nodes_in_group(\"enemys\"):\n\t\tnode.queue_free()\n\n\nfunc grind() -> void:\n\twhile lives > 0:\n\t\tscore += 1\n"


static func run() -> bool:
	EventSheetSceneConnections.clear_cache()
	EventSheetMistakeFindings.clear_cache()
	_put_the_fixture_back()
	# Judged against the fixtures alone, so a group elsewhere in the project cannot be nearer to the typo.
	EventSheetMistakeFindings.limit_group_scan_to(PackedStringArray(["res://tests/fixtures/"]))
	var ok: bool = true
	ok = _row_state_pins() and ok
	ok = _strip_pins() and ok
	ok = _door_pins() and ok
	_put_the_fixture_back()
	ok = _doctor_pins() and ok
	EventSheetMistakeFindings.limit_group_scan_to(PackedStringArray())
	return ok


## A door saves the open sheet to its file, which here is the fixture script; this writes it back.
static func _put_the_fixture_back() -> void:
	var file: FileAccess = FileAccess.open(LEVEL, FileAccess.WRITE)
	if file != null:
		file.store_string(LEVEL_TEXT)
		file.close()
	EventForgeFileStamp.forget_all()
	EventSheetSceneConnections.clear_cache()
	EventSheetMistakeFindings.clear_cache()


static func _sheet() -> EventSheetResource:
	var sheet: EventSheetResource = SUPPORT.reopen(SOURCE, true, LEVEL)
	sheet.external_source_path = LEVEL
	return sheet


static func _dock_of(sheet: EventSheetResource) -> EventSheetDock:
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(sheet)
	return dock


## Every built row of the canvas, children and all, in row order. An event's words are built as it
## comes into view, so each is asked for them first - which is what scrolling to it does.
static func _flat(rows: Array, viewport: EventSheetViewport) -> Array[EventRowData]:
	var flat: Array[EventRowData] = []
	for row_data: EventRowData in rows:
		viewport._row_builder._ensure_event_spans(row_data)
		flat.append(row_data)
		flat.append_array(_flat(row_data.children, viewport))
	return flat


## The row stamped with a finding of one kind.
static func _stamped(dock: EventSheetDock, kind: String) -> EventRowData:
	for row_data: EventRowData in _flat(dock._viewport._root_rows, dock._viewport):
		for finding: Dictionary in row_data.attention_findings:
			if str(finding.get("kind", "")) == kind:
				return row_data
	return null


## The rows under a row other than the "+ Add event" door a function's body ends with.
static func _note_children(row_data: EventRowData) -> int:
	var count: int = 0
	for child: EventRowData in row_data.children:
		if not child.row_uid.begins_with("add_event_footer_"):
			count += 1
	return count


static func _row_state_pins() -> bool:
	var dock: EventSheetDock = _dock_of(_sheet())
	var red: EventRowData = _stamped(dock, "signal-emit-value-count")
	var amber: EventRowData = _stamped(dock, "group-nothing-is-in")
	var loop: EventRowData = _stamped(dock, "while-never-ends")
	var ok: bool = SUPPORT.pins(TEST_NAME, [
		["an error row is stamped, and red", [red != null, red.attention_severe if red != null else false], [true, true]],
		["a warning row is stamped, and amber", [amber != null, amber.attention_severe if amber != null else true], [true, false]],
		["a While that cannot end is amber", [loop != null, loop.attention_severe if loop != null else true], [true, false]],
		["the red row has no note row under it (the quiet sheet law)", _note_children(red) if red != null else -1, 0],
		["and its error mark is not borrowed: the diagnostics layer stays empty", red.error_message if red != null else "x", ""],
		["the stamp carries the sentence the strip reads", red != null and red.attention_note.contains("Error calling from signal"), true],
		["two rows are counted for the head's attention count", dock._viewport.attention_row_count() >= 3, true],
	])
	dock.free()
	return ok


static func _strip_pins() -> bool:
	var dock: EventSheetDock = _dock_of(_sheet())
	var red: EventRowData = _stamped(dock, "signal-emit-value-count")
	var amber: EventRowData = _stamped(dock, "group-nothing-is-in")
	dock._update_row_help_strip(red)
	var red_modulate: Color = dock._row_help_label.modulate
	var red_visible: bool = dock._row_help_label.visible
	dock._update_row_help_strip(amber)
	var amber_modulate: Color = dock._row_help_label.modulate
	var amber_text: String = dock._row_help_label.text
	var door: String = dock._row_help_button.text
	var door_shown: bool = dock._row_help_button.visible
	var second: String = dock._row_help_button_second.text
	var ok: bool = SUPPORT.pins(TEST_NAME, [
		["selecting the red row shows the strip", red_visible, true],
		["and the red row's words are not drawn in the amber colour", red_modulate != amber_modulate, true],
		["the amber row's sentence names the group and what Godot does", amber_text.contains("\"enemys\"") and amber_text.contains("Godot prints nothing"), true],
		["a group with a near name offers it first", [door, door_shown], ["Use \"enemies\"", true]],
		["and a node for it second", second, "Add the group to a node..."],
		["and the run-time door third", dock._row_help_button_third.text, "It is added at run time"],
	])
	dock.free()
	return ok


static func _door_pins() -> bool:
	var dock: EventSheetDock = _dock_of(_sheet())
	var amber: EventRowData = _stamped(dock, "group-nothing-is-in")
	dock._update_row_help_strip(amber)
	dock.apply_selected_row_fix()
	var after: Array = []
	for finding: Dictionary in EventSheetMistakeFindings.findings(dock._current_sheet, LEVEL):
		after.append(finding["kind"])
	var compiled: String = SUPPORT.compile_output(dock._current_sheet, "")
	var stopped_ok: bool = _stop_after_pins(dock)
	var saved: Variant = ProjectSettings.get_setting(EventSheetMistakeFindings.REMEMBER_SETTING, {})
	ProjectSettings.set_setting(EventSheetMistakeFindings.REMEMBER_SETTING, {})
	var source: Dictionary = {"kind": "group-nothing-is-in", "subject": "x", "fix": "known_at_run_time"}
	ProjectSettings.set_setting(EventSheetMistakeFindings.REMEMBER_SETTING, saved)
	dock.free()
	return SUPPORT.pins(TEST_NAME, [
		["the use-the-name door respells the group in the row, through undo", compiled.contains("get_nodes_in_group(\"enemies\")") and not compiled.contains("\"enemys\""), true],
		["and that finding is gone", after.has("group-nothing-is-in"), false],
		["the other findings are untouched by it", after.has("signal-emit-value-count") and after.has("while-never-ends"), true],
		["the guard door writes a counter, a step and the condition", stopped_ok, true],
		["a door id with no place on the strip does nothing", source.get("fix", ""), "known_at_run_time"],
	])


## "Stop after 1000 rounds" writes plain GDScript: a counter local, a step, and the condition and-ed.
static func _stop_after_pins(dock: EventSheetDock) -> bool:
	var loop: EventRowData = _stamped(dock, "while-never-ends")
	if loop == null:
		return false
	dock._update_row_help_strip(loop)
	dock.apply_selected_row_second_fix()
	var compiled: String = SUPPORT.compile_output(dock._current_sheet, "")
	var kinds: Array = []
	for finding: Dictionary in EventSheetMistakeFindings.findings(dock._current_sheet, LEVEL):
		kinds.append(finding["kind"])
	return compiled.contains("while lives > 0 and rounds < 1000:") and compiled.contains("var rounds") \
		and compiled.contains("rounds += 1") and not kinds.has("while-never-ends")


static func _doctor_pins() -> bool:
	EventSheetProjectDoctor.clear_project_scripts()
	var report: Array[Dictionary] = EventSheetMistakeChecksDoctor.report(PackedStringArray([SCRIPT_FIXTURE]))
	var checks: Array = []
	var severities: Array = []
	for finding: Dictionary in report:
		checks.append(finding["check"])
		severities.append(finding["severity"])
	var summary_first: bool = report.size() > 0 and str(report[0]["check"]) == "mistakes" and str(report[0]["severity"]) == "info"
	var while_finding: Dictionary = {}
	for finding: Dictionary in report:
		if str(finding["check"]) == "while-never-ends":
			while_finding = finding
	var offered: Array = []
	for offer: Dictionary in EventSheetQuickFixes.fixes_for(while_finding):
		offered.append(offer["label"])
	return SUPPORT.pins(TEST_NAME, [
		["the section's summary leads and is a note", summary_first, true],
		["the script's two mistakes are filed under their own check ids", checks.has("signal-emit-value-count") and checks.has("while-never-ends"), true],
		["with their own severities (error, warning)", severities.has("error") and severities.has("warning"), true],
		["a finding names the sheet's margin number for the row", int(while_finding.get("event", 0)) > 0, true],
		["the While offers its doors", offered, ["Add: Subtract 1 from lives", "Stop after 1000 rounds", "Make it an If"]],
		["a clean corpus reports nothing at all", EventSheetMistakeChecksDoctor.report(PackedStringArray(["res://tests/fixtures/mistake_level.gd"])), []],
		["the missing control is not said twice: it stays the Doctor's own finding", EventSheetMistakeChecksDoctor.SAID_ELSEWHERE.has("input-action-not-in-map"), true],
	])
