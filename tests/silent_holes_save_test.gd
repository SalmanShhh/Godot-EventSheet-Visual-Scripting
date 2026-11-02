@tool
class_name SilentHolesSaveTest
extends RefCounted

# What a save knew and dropped: the engine's verdict on the whole script it wrote (with the engine's own
# words, placed on the row that wrote the failing line), the parse check a .gd sheet only ever had on
# open, and the warnings the compiler has always returned beside its output.

const SUPPORT := preload("res://tests/support.gd")
const NAME := "silent_holes_save_test"
## What one engine check of a six-line script may cost on a slow runner; it runs alone, in the tail.
const ENGINE_CHECK_BUDGET_MS := 5000

## A stand-in for the dock with exactly what the save checks reach for.
const DOCK_STUB := "extends Control\nvar _current_sheet = null\nvar status := ''\nvar status_is_error := false\nfunc _active_view():\n\treturn null\nfunc _set_status(text, is_error = false):\n\tstatus = text\n\tstatus_is_error = is_error\n"


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _compiler_attributes_warnings_to_rows() and all_passed
	all_passed = _warnings_are_recorded_and_found() and all_passed
	all_passed = _doctor_lists_them() and all_passed
	all_passed = _engine_words_land_on_the_row() and all_passed
	all_passed = _engine_check_reads_a_real_file() and all_passed
	return all_passed


static func _ghost_sheet() -> Array:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	var event_row: EventRow = EventRow.new()
	event_row.trigger_provider_id = "Core"
	event_row.trigger_id = "OnProcess"
	var ghost: ACECondition = ACECondition.new()
	ghost.provider_id = "GhostAddon"
	ghost.ace_id = "SomeGoneCondition"
	event_row.conditions.append(ghost)
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "X"
	action.codegen_template = "fire_missile()"
	event_row.actions.append(action)
	sheet.events.append(event_row)
	return [sheet, event_row]


static func _compiler_attributes_warnings_to_rows() -> bool:
	var made: Array = _ghost_sheet()
	var sheet: EventSheetResource = made[0]
	var event_row: EventRow = made[1]
	var result: Dictionary = SheetCompiler.echo(sheet)
	var rows: Array = result.get("warning_rows", [])
	var first: Dictionary = rows[0] if not rows.is_empty() else {}
	var warnings: Array = result.get("warnings", [])
	# A second compile is the same: the attribution is bookkeeping and leaves the output alone.
	var again: Dictionary = SheetCompiler.echo(sheet)
	return SUPPORT.pins(NAME, [
		["the warning is still in the list the compiler always returned", str(warnings).contains("could not be resolved"), true],
		["and one row carries it", rows.size(), 1],
		["the row is the event the compiler was writing", str(first.get("uid", "")), str(event_row.get_instance_id())],
		["with the same sentence", warnings.has(str(first.get("message", "-"))), true],
		["the emitted bytes are untouched by recording it", str(again.get("output", "")), str(result.get("output", "x"))],
	])


static func _warnings_are_recorded_and_found() -> bool:
	EventSheetCompileFindings.clear()
	var made: Array = _ghost_sheet()
	var sheet: EventSheetResource = made[0]
	var event_row: EventRow = made[1]
	sheet.external_source_path = "res://tests/silent_holes_ghost_sheet.gd"
	var result: Dictionary = SheetCompiler.echo(sheet)
	var first_record: bool = EventSheetCompileFindings.record(sheet, result)
	var same_record: bool = EventSheetCompileFindings.record(sheet, result)
	var found: Array[Dictionary] = EventSheetCompileFindings.findings(sheet)
	var at_event: Array[Dictionary] = ViewportRowBuilder.findings_at_event(found, event_row)
	var summary: String = EventSheetCompileFindings.summary(EventSheetCompileFindings.warnings_for(sheet))
	var passed: bool = SUPPORT.pins(NAME, [
		["the first record is a change", first_record, true],
		["recording the same warnings again is not", same_record, false],
		["a finding hangs on the event", at_event.size(), 1],
		["it is the quiet amber kind", str(at_event[0].get("severity", "")), "warning"] if not at_event.is_empty() else ["it is a finding", false, true],
		["its words are the compiler's", str(at_event[0].get("message", "")).contains("could not be resolved"), true] if not at_event.is_empty() else ["has words", false, true],
		["no door is offered", str(at_event[0].get("fix", "x")), ""] if not at_event.is_empty() else ["no door", false, true],
		["the status line says how many and the first", summary.begins_with("1 compiler warning(s)"), true],
	])
	# A fixed sheet stops being reported.
	var clean: Dictionary = {"warnings": [], "warning_rows": []}
	var cleared: bool = EventSheetCompileFindings.record(sheet, clean)
	passed = SUPPORT.pins(NAME, [
		["a clean write is a change from a warned one", cleared, true],
		["and leaves nothing on record", EventSheetCompileFindings.recorded_paths().size(), 0],
		["nor any finding", EventSheetCompileFindings.findings(sheet).size(), 0],
		["nor words for the status line", EventSheetCompileFindings.summary([]), ""],
	]) and passed
	EventSheetCompileFindings.clear()
	return passed


static func _doctor_lists_them() -> bool:
	EventSheetCompileFindings.clear()
	var made: Array = _ghost_sheet()
	var sheet: EventSheetResource = made[0]
	sheet.external_source_path = "res://tests/silent_holes_ghost_sheet.gd"
	EventSheetCompileFindings.record(sheet, SheetCompiler.echo(sheet))
	var findings: Array[Dictionary] = []
	EventSheetCompilerWarningsDoctor.check(PackedStringArray(), findings)
	var passed: bool = SUPPORT.pins(NAME, [
		["a summary line and the warning", findings.size(), 2],
		["the summary comes first", str(findings[0].get("severity", "")), "info"],
		["the warning is filed under the section", str(findings[1].get("check", "")), "compiler_warnings"],
		["with the file in front of the words", str(findings[1].get("message", "")).begins_with("silent_holes_ghost_sheet.gd "), true],
		["and the file it is about", str(findings[1].get("path", "")), "res://tests/silent_holes_ghost_sheet.gd"],
	]) if findings.size() == 2 else SUPPORT.check(NAME, "the Doctor lists the recorded warning", findings.size(), 2)
	EventSheetCompileFindings.clear()
	var empty: Array[Dictionary] = []
	EventSheetCompilerWarningsDoctor.check(PackedStringArray(), empty)
	return SUPPORT.check(NAME, "nothing on record, nothing in the inbox", empty.size(), 0) and passed


static func _dock_stub() -> Control:
	var stub_script: GDScript = GDScript.new()
	stub_script.source_code = DOCK_STUB
	stub_script.reload()
	return stub_script.new() as Control


static func _engine_words_land_on_the_row() -> bool:
	EventSheetSaveChecks.clear_layers()
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.external_source_path = "res://tests/silent_holes_engine_sheet.gd"
	var dock: Control = _dock_stub()
	dock._current_sheet = sheet
	var checks: EventSheetSaveChecks = EventSheetSaveChecks.new()
	checks.init(dock)
	var request: Dictionary = {
		"path": sheet.external_source_path, "sheet_key": EventSheetCompileFindings.key_of(sheet),
		"source_map": [{"uid": "4242", "start": 3, "end": 5, "kind": "event"}], "backed": true,
	}
	var errors: Array = [{"line": 4, "message": "Identifier \"flub\" not declared in the current scope."}]
	checks.apply_engine_result(request, errors)
	var merged: Array = EventSheetSaveChecks.merged_diagnostics(sheet)
	var passed: bool = SUPPORT.pins(NAME, [
		["the failing line's row is marked", str((merged[0] as Dictionary).get("uid", "")), "4242"] if not merged.is_empty() else ["a mark", false, true],
		["with the engine's own sentence", str((merged[0] as Dictionary).get("message", "")).contains("\"flub\" not declared"), true] if not merged.is_empty() else ["words", false, true],
		["the status line says it, as an error", bool(dock.status_is_error), true],
		["in the engine's words", str(dock.status).contains("Identifier \"flub\" not declared"), true],
		["with the line and the file", str(dock.status).contains("line 4 of silent_holes_engine_sheet.gd"), true],
		["a .gd sheet's stored parse errors (the head bar) are replaced", EventSheetParseErrors.error_count(sheet), 1],
	])
	# The lint's generic wording is replaced by the engine's reason for the same row; another row keeps
	# its own words.
	EventSheetSaveChecks.set_lint_layer(sheet, [
		{"uid": "4242", "message": "Script block doesn't compile: Does not compile (parse/analyze failed - see Output for details).", "suggestion": ""},
		{"uid": "77", "message": "Variable \"x\" shadows a Node member - rename it.", "suggestion": ""},
	])
	var joined: Array = EventSheetSaveChecks.merged_diagnostics(sheet)
	passed = SUPPORT.pins(NAME, [
		["both rows are marked once", joined.size(), 2],
		["the generic words give way to the engine's", str((joined[0] as Dictionary).get("message", "")).contains("\"flub\" not declared"), true],
		["a row the engine did not name keeps its own", str((joined[1] as Dictionary).get("message", "")).begins_with("Variable"), true],
	]) and passed
	# A clean answer clears the marks and the stored errors.
	dock.status = ""
	checks.apply_engine_result(request, [])
	passed = SUPPORT.pins(NAME, [
		["a parse that now succeeds stores no errors", EventSheetParseErrors.error_count(sheet), 0],
		["and says nothing", str(dock.status), ""],
	]) and passed
	# The tab moved on to another sheet: the answer is filed for its sheet and not painted on this one.
	var other: EventSheetResource = EventSheetResource.new()
	other.external_source_path = "res://tests/silent_holes_other_sheet.gd"
	dock._current_sheet = other
	checks.apply_engine_result(request, errors)
	passed = SUPPORT.pins(NAME, [
		["a stale answer says nothing about the open sheet", str(dock.status), ""],
		["and stores nothing on it", EventSheetParseErrors.error_count(other), 0],
	]) and passed
	# Coming back to the sheet the answer was about: nothing was lost on the way.
	dock._current_sheet = sheet
	checks.on_sheet_shown(sheet)
	passed = SUPPORT.pins(NAME, [
		["the answer that landed while another tab was up is told on return", str(dock.status).contains("\"flub\" not declared"), true],
		["and a .gd sheet stores it", EventSheetParseErrors.error_count(sheet), 1],
	]) and passed
	dock.status = ""
	checks.on_sheet_shown(sheet)
	passed = SUPPORT.check(NAME, "and it is told once", str(dock.status), "") and passed
	# Two saves in a row: the answer to the first file is about bytes that no longer exist.
	dock.status = ""
	checks._waiting = {"path": sheet.external_source_path, "sheet_key": EventSheetCompileFindings.key_of(sheet)}
	checks._request = request
	checks._check_returned(errors)
	passed = SUPPORT.check(NAME, "an answer overtaken by a newer save of the same file says nothing", str(dock.status), "") and passed
	# A write makes the last engine answer obsolete. Its marks name rows of the file that was just
	# replaced; counted now they would read "1 row(s) need attention" on a sheet the reader has just fixed.
	EventSheetSaveChecks.clear_layers()
	EventSheetSaveChecks.set_engine_layer(sheet, [{"uid": "4242", "message": "old", "suggestion": ""}])
	checks.after_write(sheet, "user://not_a_project_file.gd", {"warnings": [], "warning_rows": [], "source_map": []})
	passed = SUPPORT.check(NAME, "a write drops the engine's marks about the file it replaced",
		EventSheetSaveChecks.merged_diagnostics(sheet), []) and passed
	# And the marks painted from it do not outlive an answer that says the file is clean.
	var marks_left: Array = EventSheetSaveChecks.merged_diagnostics(sheet)
	checks.apply_engine_result(request, [])
	passed = SUPPORT.check(NAME, "a clean answer after a write leaves no mark", marks_left, []) and passed
	EventSheetSaveChecks.clear_layers()
	dock.free()
	return passed


static func _engine_check_reads_a_real_file() -> bool:
	var path: String = "res://tests/fixtures/silent_holes_runtime_broken.gd"
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return SUPPORT.check(NAME, "the temporary script can be written", false, true)
	file.store_string("extends Node\n\n\nfunc _ready() -> void:\n\tvar total: int = flub + 1\n\tprint(total)\n")
	file.close()
	var started: int = Time.get_ticks_msec()
	var errors: Array = EventSheetParseErrors.check_file(path)
	var elapsed: int = Time.get_ticks_msec() - started
	var cached_started: int = Time.get_ticks_msec()
	var cached: Array = EventSheetParseErrors.check_file(path)
	var cached_elapsed: int = Time.get_ticks_msec() - cached_started
	# A file's modified time is in whole seconds: a fix saved inside the same second as the broken file
	# has the same stamp. The save tells the cache it wrote, so the fix is not answered with the old errors.
	var fixed: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	fixed.store_string("extends Node\n\n\nfunc _ready() -> void:\n\tvar total: int = 1\n\tprint(total)\n")
	fixed.close()
	EventSheetParseErrors.forget(path)
	var after_fix: Array = EventSheetParseErrors.check_file(path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("silent_holes_save_test: engine check of a 6-line script took %d ms (cached ask %d ms)" % [elapsed, cached_elapsed])
	return SUPPORT.pins(NAME, [
		["a file written again is checked again, whatever its time stamp says", after_fix, []],
		["the engine names the line", int((errors[0] as Dictionary).get("line", 0)) if not errors.is_empty() else 0, 5],
		["in its own words", str((errors[0] as Dictionary).get("message", "")).contains("flub") if not errors.is_empty() else false, true],
		["the check is inside its budget", elapsed < ENGINE_CHECK_BUDGET_MS, true],
		["a second ask of the same bytes is answered from the cache", cached, errors],
	])
