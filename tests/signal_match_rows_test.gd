# Godot EventSheets - Signal rows + match rows (GDScript language parity)
# Signals get the enum-row treatment (canonical emission, verify-lift, snippets, picker
# integration, dialog guardrails); match statements become structured action rows with a
# whole-construct lint gate (the switch statement).
@tool
class_name SignalMatchRowsTest
extends RefCounted


class NoopUndoManager:
	extends RefCounted
	func create_action(_a = null) -> void: pass
	func add_do_method(_a = null, _b = null, _c = null, _d = null, _e = null) -> void: pass
	func add_undo_method(_a = null, _b = null, _c = null, _d = null, _e = null) -> void: pass
	func commit_action() -> void: pass
	func has_undo() -> bool: return false
	func has_redo() -> bool: return false
	func undo() -> void: pass
	func redo() -> void: pass
	func clear_history() -> void: pass


static func run() -> bool:
	var all_passed: bool = true

	# Compile: signals before variables; match in-flow; custom-signal triggers validate.
	var sheet: EventSheetResource = EventSheetResource.new()
	var state: EnumRow = EnumRow.new()
	state.enum_name = "State"
	state.members = PackedStringArray(["IDLE", "RUN"])
	sheet.events.append(state)
	var hit: SignalRow = SignalRow.new()
	hit.signal_name = "hit"
	hit.params = PackedStringArray(["damage: int"])
	sheet.events.append(hit)
	var current: LocalVariable = LocalVariable.new()
	current.name = "state"
	current.type_name = "State"
	current.default_value = 0
	sheet.events.append(current)
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnProcess"
	var match_row: MatchRow = MatchRow.new()
	match_row.match_expression = "state"
	match_row.branches_text = "State.IDLE:\n\tpass\n_:\n\tqueue_free()"
	event.actions.append(match_row)
	sheet.events.append(event)
	var listener: EventRow = EventRow.new()
	listener.trigger_provider_id = "Core"
	listener.trigger_id = "signal:hit"
	listener.trigger_args = "damage: int"
	var react: ACEAction = ACEAction.new()
	react.provider_id = "Core"
	react.ace_id = "PrintLog"
	react.codegen_template = "print({message})"
	react.params = {"message": "damage"}
	listener.actions.append(react)
	sheet.events.append(listener)
	var result: Dictionary = SheetCompiler.compile(sheet, "user://eventsheets_sig.gd")
	var output: String = str(result.get("output", ""))
	all_passed = _check("canonical signal line emits", output.contains("signal hit(damage: int)"), true) and all_passed
	all_passed = _check("signals emit after enums, before variables",
		output.find("enum State") < output.find("signal hit") and output.find("signal hit") < output.find("var state"), true) and all_passed
	all_passed = _check("match emits in-flow with indented branches",
		output.contains("\tmatch state:") and output.contains("\t\tState.IDLE:") and output.contains("\t\t\tqueue_free()"), true) and all_passed
	all_passed = _check("SignalRow validates custom-signal trigger connections",
		output.contains("hit.connect(_on_hit)"), true) and all_passed
	var generated: GDScript = GDScript.new()
	generated.source_code = output
	all_passed = _check("signal+match output parses", generated.reload(true) == OK, true) and all_passed

	# Verify-lift: canonical signal declarations re-open as rows.
	var external_source: String = "extends Node\n\nsignal plain\n\nsignal typed(damage: int, source: Node)\n\nsignal  weird_spacing\n"
	var imported: EventSheetResource = GDScriptImporter.new().import_external_source(external_source)
	var lifted_names: Array[String] = []
	var weird_stays: bool = false
	for row in imported.events:
		if row is SignalRow:
			lifted_names.append((row as SignalRow).signal_name)
		elif row is RawCodeRow and (row as RawCodeRow).code.contains("weird_spacing"):
			weird_stays = true
	all_passed = _check("canonical signals lift", lifted_names.has("plain") and lifted_names.has("typed"), true) and all_passed
	all_passed = _check("non-canonical signals stay blocks", weird_stays, true) and all_passed
	imported.external_source_path = "user://eventsheets_sig_rt.gd"
	var roundtrip: String = str(SheetCompiler.compile(imported, "user://eventsheets_sig_rt.gd").get("output", ""))
	all_passed = _check("signal round-trip is byte-identical", roundtrip == external_source, true) and all_passed

	# Pickers + lint see SignalRows.
	var dialog: ACEParamsDialog = ACEParamsDialog.new()
	dialog.set_lint_context_provider(func() -> EventSheetResource: return sheet)
	all_passed = _check("signal picker offers SignalRow declarations", dialog._signal_options().has("hit"), true) and all_passed
	all_passed = _check("emitting a declared signal lints",
		bool(EventSheetGDScriptLint.lint("hit.emit(3)", true, sheet).get("ok", false)), true) and all_passed

	# Snippets.
	var snippet: String = EventSheetSnippet.serialize_rows([hit], sheet)
	var parsed: Dictionary = EventSheetSnippet.deserialize(snippet)
	var pasted: SignalRow = null
	for row in parsed.get("rows", []):
		if row is SignalRow:
			pasted = row
	all_passed = _check("signals travel in snippets",
		pasted != null and pasted.signal_name == "hit" and pasted.params[0] == "damage: int", true) and all_passed

	# Editor: rows render; dialogs apply with guardrails.
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(sheet)
	editor.set_undo_redo_manager(NoopUndoManager.new())
	var viewport: EventSheetViewport = editor.get_viewport_control()
	var signal_row_data: EventRowData = null
	var match_event_row: EventRowData = null
	for entry in viewport.get_flat_rows():
		var row: EventRowData = entry.get("row")
		if row != null and row.source_resource == hit:
			signal_row_data = row
		elif row != null and row.source_resource == event:
			match_event_row = row
	# A signal reads in the SAME two lanes as every other row: a kind badge and the name on the left,
	# one cell per value it passes (its type as a plain word, the name as the cell's label), and on the
	# right what actually fires - "internal" for a plain signal that publishes no trigger ACE. Pins the
	# span TEXT, not the span count, so adding a marker chip later does not spuriously fail this.
	var signal_texts: PackedStringArray = PackedStringArray()
	var signal_labels: PackedStringArray = PackedStringArray()
	if signal_row_data != null:
		for span: SemanticSpan in signal_row_data.spans:
			signal_texts.append(span.text)
			var span_meta: Dictionary = span.metadata if span.metadata is Dictionary else {}
			signal_labels.append(str(span_meta.get("object_label", "")))
	all_passed = _check("signal row is an EVENT row",
		signal_row_data != null and signal_row_data.row_type == EventRowData.RowType.EVENT, true) and all_passed
	all_passed = _check("signal row badges its kind", Array(signal_texts).has("Signal"), true) and all_passed
	all_passed = _check("signal row names the signal", Array(signal_texts).has("hit"), true) and all_passed
	all_passed = _check("signal parameter reads as a typed cell",
		Array(signal_texts).has("number") and Array(signal_labels).has("damage"), true) and all_passed
	all_passed = _check("a plain signal publishes nothing", Array(signal_texts).has("internal"), true) and all_passed
	all_passed = _check("the hover carries the real declaration",
		ViewportTooltipHelper.signal_declaration_tooltip(hit), "signal hit(damage: int)") and all_passed
	viewport._ensure_event_spans(match_event_row)
	var match_span_found: bool = false
	for span in match_event_row.spans:
		if span.metadata is Dictionary and bool((span.metadata as Dictionary).get("match_action", false)) and span.text == "match state:":
			match_span_found = true
	all_passed = _check("match renders as action cells", match_span_found, true) and all_passed

	editor._struct_rows._ensure_signal_dialog()
	editor._struct_rows._signal_target = hit
	editor._struct_rows._signal_name_edit.text = "took damage"
	editor._struct_rows._signal_params_edit.text = "amount: int"
	editor._struct_rows._on_signal_dialog_confirmed()
	all_passed = _check("signal dialog sanitizes + applies",
		hit.signal_name == "took_damage" and hit.params == PackedStringArray(["amount: int"]), true) and all_passed

	# The match is edited as first-class cases (a pattern + a body per branch), not a text blob.
	editor._struct_rows._ensure_match_dialog()
	editor._struct_rows._match_target = match_row
	editor._struct_rows._match_expression_edit.text = "state"
	# A broken case body (invalid GDScript) must not commit - the whole construct is lint-gated.
	editor._struct_rows._clear_match_case_rows()
	editor._struct_rows._add_match_case_row("State.RUN", "broken missing colon")
	editor._struct_rows._on_match_dialog_confirmed()
	all_passed = _check("broken match never commits (cases + text unchanged)",
		match_row.cases.is_empty() and match_row.branches_text.contains("State.IDLE:"), true) and all_passed
	# A valid case applies as a structured MatchCase (and keeps branches_text in sync as the raw fallback).
	editor._struct_rows._clear_match_case_rows()
	editor._struct_rows._add_match_case_row("State.RUN", "state = State.IDLE")
	editor._struct_rows._on_match_dialog_confirmed()
	all_passed = _check("valid match applies as a structured case",
		match_row.cases.size() == 1 and (match_row.cases[0] as MatchCase).pattern == "State.RUN", true) and all_passed
	all_passed = _check("branches_text stays in sync with the cases",
		match_row.branches_text, "State.RUN:\n\tstate = State.IDLE") and all_passed
	editor.free()

	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] signal_match_rows_test: %s" % label)
		return true
	print("[FAIL] signal_match_rows_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
