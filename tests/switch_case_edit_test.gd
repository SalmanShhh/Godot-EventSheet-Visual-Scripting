# EventForge - switch/case editing: the match dialog edits a switch as first-class cases (a pattern + body
# per branch, add/remove), like the enum editor. Pins: authoring cases via the dialog sets structured cases
# that compile and - because the importer lifts a match back to cases - ROUND-TRIP as structured on reopen;
# opening the dialog on a structured match shows one panel per case; adding a case grows the switch. Editing
# is a deliberate change (not byte-preserving), but it must produce a switch that re-opens as the same cases.
@tool
class_name SwitchCaseEditTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true

	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	sheet.variables = {"phase": {"type": "int", "default": 0}}
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnProcess"
	var match_row: MatchRow = MatchRow.new()
	match_row.match_expression = "phase"
	event.actions.append(match_row)
	sheet.events.append(event)

	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(sheet)
	var dialogs: EventSheetStructRowDialogs = dock._struct_rows
	dialogs._ensure_match_dialog()

	# ── Author two cases (0 -> phase = 1, _ -> pass) via the dialog ──
	dialogs._match_target = match_row
	dialogs._match_expression_edit.text = "phase"
	dialogs._clear_match_case_rows()
	dialogs._add_match_case_row("0", "phase = 1")
	dialogs._add_match_case_row("_", "")  # empty body compiles to pass
	dialogs._on_match_dialog_confirmed()

	var live: MatchRow = _first_match(dock.get_current_sheet())
	ok = _check("two cases are authored", live != null and live.cases.size() == 2, true) and ok
	if live != null and live.cases.size() == 2:
		ok = _check("first case pattern", str((live.cases[0] as MatchCase).pattern), "0") and ok
		ok = _check("first case body", _body(live.cases[0]), "phase = 1") and ok
		ok = _check("the default case has no body (pass)", (live.cases[1] as MatchCase).events.is_empty(), true) and ok

	# ── It compiles to a plain match, and re-opening the file lifts it back to the SAME structured cases ──
	var compiled: String = str(SheetCompiler.compile(dock.get_current_sheet(), "user://switch_edit_out.gd").get("output", ""))
	ok = _check("the authored cases compile to a match block",
		compiled.contains("\tmatch phase:\n\t\t0:\n\t\t\tphase = 1\n\t\t_:\n\t\t\tpass\n"), true) and ok
	var reimported: EventSheetResource = GDScriptImporter.new().import_external_source(compiled)
	var relifted: MatchRow = _first_match(reimported)
	ok = _check("the authored switch round-trips as structured cases",
		relifted != null and relifted.cases.size() == 2 and str((relifted.cases[0] as MatchCase).pattern) == "0", true) and ok

	# ── Opening the dialog on the structured match shows one panel per case ──
	dialogs._populate_match_dialog(live)
	ok = _check("the dialog shows one panel per case", dialogs._match_case_rows.size(), 2) and ok
	ok = _check("the first panel shows the pattern", str((dialogs._match_case_rows[0]["pattern"] as LineEdit).text), "0") and ok
	ok = _check("the first panel shows the body", str((dialogs._match_case_rows[0]["body"] as TextEdit).text), "phase = 1") and ok

	# ── Adding a case grows the switch ──
	dialogs._add_match_case_row("1", "phase = 2")
	dialogs._on_match_dialog_confirmed()
	var live2: MatchRow = _first_match(dock.get_current_sheet())
	ok = _check("adding a case grows the switch to three", live2 != null and live2.cases.size() == 3, true) and ok

	dock.free()
	return ok


static func _first_match(sheet: EventSheetResource) -> MatchRow:
	for row: Variant in sheet.events:
		if row is EventRow:
			for a: Variant in (row as EventRow).actions:
				if a is MatchRow:
					return a as MatchRow
	return null


static func _body(match_case: MatchCase) -> String:
	var events: Array = match_case.events
	return str((events[0] as RawCodeRow).code) if not events.is_empty() and events[0] is RawCodeRow else "<none>"


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] switch_case_edit_test: %s" % label)
		return true
	print("[FAIL] switch_case_edit_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
