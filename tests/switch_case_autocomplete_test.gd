# EventForge - the switch/case editor steers case patterns by what the switch is ON: when the subject is an
# enum variable, the pattern picker suggests that enum's members (State.IDLE, …); a bool offers true/false;
# and "Fill from enum" adds a case per value at once - so a switch on a typed variable starts with valid,
# correctly-named branches (fewer typos) that stay freely editable. Reads the sheet's enums/variables
# directly (no provider). Pins: subject-enum resolution, the pattern choices, bool, fill, and enums in groups.
@tool
class_name SwitchCaseAutocompleteTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true

	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	var enum_row: EnumRow = EnumRow.new()
	enum_row.enum_name = "State"
	enum_row.members = PackedStringArray(["IDLE", "RUN", "HURT = 4"])
	sheet.events.append(enum_row)
	var state_var: LocalVariable = LocalVariable.new()
	state_var.name = "state"
	state_var.type_name = "State"
	sheet.events.append(state_var)
	var flag_var: LocalVariable = LocalVariable.new()
	flag_var.name = "flag"
	flag_var.type_name = "bool"
	sheet.events.append(flag_var)
	# An enum nested inside a group - must still be found (group-recursive collection).
	var group: EventGroup = EventGroup.new()
	group.group_name = "G"
	var mode_enum: EnumRow = EnumRow.new()
	mode_enum.enum_name = "Mode"
	mode_enum.members = PackedStringArray(["A", "B"])
	group.events.append(mode_enum)
	sheet.events.append(group)
	var match_row: MatchRow = MatchRow.new()
	match_row.match_expression = "state"
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnProcess"
	event.actions.append(match_row)
	sheet.events.append(event)

	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(sheet)
	var dialogs: EventSheetStructRowDialogs = dock._struct_rows
	dialogs._ensure_match_dialog()
	dialogs._match_target = match_row
	dialogs._match_expression_edit.text = "state"

	# ── Enums are read directly off the sheet, groups included ──
	var enum_names: Array = []
	for e: Dictionary in dialogs._sheet_enums():
		enum_names.append(str(e.get("name")))
	ok = _check("sheet enums are collected, including inside groups",
		enum_names.has("State") and enum_names.has("Mode"), true) and ok

	# ── The switch subject resolves to its enum type ──
	ok = _check("the subject variable resolves to its enum type", dialogs._subject_enum_name(), "State") and ok

	# ── The pattern choices are the subject enum's members (values stripped) + the default ──
	var choices: Array = dialogs._match_pattern_choices()
	ok = _check("choices include State.IDLE", choices.has("State.IDLE"), true) and ok
	ok = _check("choices strip the explicit value (State.HURT, not State.HURT = 4)", choices.has("State.HURT"), true) and ok
	ok = _check("choices end with the default branch _", choices.has("_"), true) and ok
	ok = _check("choices are ONLY the subject enum + default (steered, not every enum)", choices.size(), 4) and ok

	# ── A bool subject offers true / false ──
	dialogs._match_expression_edit.text = "flag"
	var bool_choices: Array = dialogs._match_pattern_choices()
	ok = _check("a bool subject offers true and false", bool_choices.has("true") and bool_choices.has("false"), true) and ok

	# ── An unresolved subject falls back to every sheet enum's members (still steered) ──
	dialogs._match_expression_edit.text = "whatever_expr()"
	var fallback: Array = dialogs._match_pattern_choices()
	ok = _check("an unresolved subject still offers enum members to pick from",
		fallback.has("State.IDLE") and fallback.has("Mode.A"), true) and ok

	# ── "Fill from enum" adds one case per value plus a default ──
	dialogs._match_expression_edit.text = "state"
	dialogs._clear_match_case_rows()
	dialogs._fill_cases_from_enum({"name": "State", "members": PackedStringArray(["IDLE", "RUN", "HURT = 4"])})
	ok = _check("fill adds a case per member plus the default", dialogs._match_case_rows.size(), 4) and ok
	ok = _check("the first filled case pattern is State.IDLE",
		str((dialogs._match_case_rows[0]["pattern"] as LineEdit).text), "State.IDLE") and ok
	ok = _check("filling again is non-destructive (no duplicate cases)", _fill_again(dialogs), 4) and ok

	dock.free()
	return ok


static func _fill_again(dialogs: EventSheetStructRowDialogs) -> int:
	dialogs._fill_cases_from_enum({"name": "State", "members": PackedStringArray(["IDLE", "RUN", "HURT = 4"])})
	return dialogs._match_case_rows.size()


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] switch_case_autocomplete_test: %s" % label)
		return true
	print("[FAIL] switch_case_autocomplete_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
