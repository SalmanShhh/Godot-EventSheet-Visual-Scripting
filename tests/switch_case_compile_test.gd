# EventForge - a structured switch/case (a MatchRow with `cases`) compiles to a plain GDScript `match`: each
# MatchCase is one `pattern:` branch whose action-lane body compiles one indent deeper (through the ordinary
# action codegen), an empty branch becomes `pass`. Pins: the emitted block shape + indentation, that the
# output is valid GDScript, that structured `cases` win over branches_text, and - covenant-critical - that an
# old raw-text MatchRow (no cases) still compiles from branches_text unchanged (additive, byte-safe).
@tool
class_name SwitchCaseCompileTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true

	# ── A structured match on a declared `phase` var: a `0` branch (one action) and a default `_` (empty).
	# The subject + the action target are declared sheet variables so the whole output is self-contained. ──
	var idle_action: ACEAction = ACEAction.new()
	idle_action.provider_id = "Core"
	idle_action.ace_id = "SetVar"
	idle_action.codegen_template = "{var_name} = {value}"
	idle_action.params = {"var_name": "phase", "value": "1"}
	var idle_case: MatchCase = MatchCase.new()
	idle_case.pattern = "0"
	idle_case.events = [idle_action]
	var default_case: MatchCase = MatchCase.new()
	default_case.pattern = "_"
	default_case.events = []  # empty -> `pass`
	var match_row: MatchRow = MatchRow.new()
	match_row.match_expression = "phase"
	match_row.branches_text = "SHOULD_NOT_APPEAR:\n\tbreakpoint"  # must be ignored when cases exist
	match_row.cases = [idle_case, default_case]

	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnProcess"
	event.actions.append(match_row)
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	sheet.variables = {"phase": {"type": "int", "default": 0}}
	sheet.events.append(event)

	var output: String = str(SheetCompiler.compile(sheet, "user://switch_case_test_out.gd").get("output", ""))

	# The whole match block, contiguous, at _process's one-tab body indent.
	var expected: String = "\tmatch phase:\n\t\t0:\n\t\t\tphase = 1\n\t\t_:\n\t\t\tpass\n"
	ok = _check("structured cases compile to the expected match block", output.contains(expected), true) and ok
	ok = _check("branches_text is ignored when cases are present", output.contains("SHOULD_NOT_APPEAR"), false) and ok
	ok = _check("the compiled output is valid GDScript", _compiles(output), true) and ok

	# ── Covenant: an old raw-text MatchRow (no cases) still compiles from branches_text, unchanged ──
	var raw_match: MatchRow = MatchRow.new()
	raw_match.match_expression = "mode"
	raw_match.branches_text = "1:\n\tprint(\"one\")\n_:\n\tpass"
	var raw_event: EventRow = EventRow.new()
	raw_event.trigger_provider_id = "Core"
	raw_event.trigger_id = "OnProcess"
	raw_event.actions.append(raw_match)
	var raw_sheet: EventSheetResource = EventSheetResource.new()
	raw_sheet.host_class = "Node2D"
	raw_sheet.variables = {"mode": {"type": "int", "default": 0}}
	raw_sheet.events.append(raw_event)
	var raw_output: String = str(SheetCompiler.compile(raw_sheet, "user://switch_case_raw_out.gd").get("output", ""))
	ok = _check("a cases-less MatchRow still emits its branches_text verbatim",
		raw_output.contains("\tmatch mode:\n\t\t1:\n\t\t\tprint(\"one\")\n\t\t_:\n\t\t\tpass\n"), true) and ok
	ok = _check("the raw-text match output is valid GDScript", _compiles(raw_output), true) and ok

	return ok


static func _compiles(source: String) -> bool:
	var script: GDScript = GDScript.new()
	script.source_code = source
	return script.reload() == OK


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] switch_case_compile_test: %s" % label)
		return true
	print("[FAIL] switch_case_compile_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
