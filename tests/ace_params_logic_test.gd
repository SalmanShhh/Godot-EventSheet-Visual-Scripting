# EventForge — ACE params dialog logic
#
# Verifies the pure (non-GUI) logic of ACEParamsDialog: expression-template substitution,
# variable-name resolution, back/re-edit flags, and hint text. The dialog form itself needs
# a display server and is verified by opening the editor.
@tool
extends RefCounted
class_name ACEParamsLogicTest

static func run() -> bool:
	var all_passed: bool = true
	var dialog: ACEParamsDialog = ACEParamsDialog.new()

	# Expression template: codegen template with default params substituted.
	var expr: ACEDefinition = ACEDefinition.new()
	expr.metadata = {"codegen_template": "move_to({target}, {speed})"}
	expr.parameters = [
		{"id": "target", "default_value": "Vector2.ZERO"},
		{"id": "speed", "default_value": "100"}
	]
	all_passed = _check("expression template fills named params", dialog._expression_template(expr), "move_to(Vector2.ZERO, 100)") and all_passed

	# Expression template: no codegen -> falls back to display.
	var expr2: ACEDefinition = ACEDefinition.new()
	expr2.display_name = "Health"
	expr2.metadata = {}
	all_passed = _check("expression template falls back to display name", dialog._expression_template(expr2), "Health") and all_passed

	# Variable-name resolution via provider callable.
	dialog._variable_names_provider = func() -> Array: return ["hp", "speed"]
	all_passed = _check("variable provider resolves names", dialog._resolve_variable_names(), PackedStringArray(["hp", "speed"])) and all_passed
	dialog._variable_names_provider = Callable()
	all_passed = _check("missing provider yields empty names", dialog._resolve_variable_names(), PackedStringArray()) and all_passed

	# Back/re-edit flags.
	dialog._context = {"from_picker": true}
	all_passed = _check("from_picker context shows back", dialog._came_from_picker(), true) and all_passed
	dialog._context = {}
	all_passed = _check("no flag hides back", dialog._came_from_picker(), false) and all_passed
	dialog._context = {"mode": "replace_condition"}
	all_passed = _check("replace mode is re-edit", dialog._is_reedit_flow(), true) and all_passed
	dialog._context = {"mode": "append_action"}
	all_passed = _check("append mode is not re-edit", dialog._is_reedit_flow(), false) and all_passed

	# Hint text: blocked apply explains the missing-variable situation.
	dialog._apply_blocked = true
	all_passed = _check("blocked hint mentions adding a variable", dialog._build_hint_text().to_lower().contains("add a variable"), true) and all_passed
	dialog._apply_blocked = false
	dialog._context = {"mode": "append_action"}
	all_passed = _check("append_action hint", dialog._build_hint_text().begins_with("Adding an action"), true) and all_passed

	# Bool parsing (static helper used by checkbox fields).
	all_passed = _check("parse bool true", ACEParamsDialog._parse_bool("true"), true) and all_passed
	all_passed = _check("parse bool false", ACEParamsDialog._parse_bool("nope"), false) and all_passed

	# Value extraction from a LineEdit field.
	var line_edit: LineEdit = LineEdit.new()
	line_edit.text = "hello"
	all_passed = _check("extract LineEdit value", dialog._extract_value(line_edit), "hello") and all_passed
	line_edit.free()

	# ── Tier-1 tedium cuts: per-ACE value memory + Apply & Add Another ────────────
	var host: Node = Node.new()
	var flow_dialog: ACEParamsDialog = ACEParamsDialog.new()
	flow_dialog.init_dialog(host)
	var flow_def: ACEDefinition = ACEDefinition.new()
	flow_def.id = "TierOneProbe"
	flow_def.display_name = "Tier One Probe"
	flow_def.parameters = [{"id": "amount", "display_name": "Amount", "default_value": "1"}]
	# A fresh add starts at the descriptor default…
	flow_dialog._definition = flow_def
	flow_dialog._context = {"mode": "append_action"}
	flow_dialog._build_form(flow_def, {})
	all_passed = _check("fresh add uses the descriptor default",
		str(flow_dialog._extract_value(flow_dialog._fields["amount"])), "1") and all_passed
	# …editing the value and committing remembers it.
	(flow_dialog._fields["amount"] as LineEdit).text = "42"
	flow_dialog._commit(false)
	all_passed = _check("commit remembers the last value per ace id",
		str((ACEParamsDialog._remembered_values["TierOneProbe"] as Dictionary).get("amount")), "42") and all_passed
	# Re-adding the same ACE prefills the remembered value (open_with_values needs a
	# display server, so exercise the prefill path through _build_form directly).
	flow_dialog._definition = flow_def
	flow_dialog._context = {"mode": "append_action"}
	var remembered: Dictionary = ACEParamsDialog._remembered_values["TierOneProbe"]
	flow_dialog._build_form(flow_def, remembered.duplicate(true))
	all_passed = _check("re-adding prefills the remembered value",
		str(flow_dialog._extract_value(flow_dialog._fields["amount"])), "42") and all_passed

	# Add-Another visibility: append modes only (the target event is stable there).
	flow_dialog._add_another_button.visible = str(flow_dialog._context.get("mode", "")) in ["append_condition", "append_action"]
	all_passed = _check("Add Another shows in append modes", flow_dialog._add_another_button.visible, true) and all_passed
	flow_dialog._context = {"mode": "replace_condition"}
	flow_dialog._add_another_button.visible = str(flow_dialog._context.get("mode", "")) in ["append_condition", "append_action"]
	all_passed = _check("Add Another hides when replacing", flow_dialog._add_another_button.visible, false) and all_passed

	# Chaining marks the context so the dock reopens the picker.
	flow_dialog._definition = flow_def
	flow_dialog._context = {"mode": "append_action", "selected_resource": null}
	var chained: Array = [false]
	flow_dialog.params_confirmed.connect(func(_d, _v, c) -> void: chained[0] = bool(c.get("chain_add", false)))
	flow_dialog._commit(true)
	all_passed = _check("Apply & Add Another flags the context for re-opening",
		chained[0], true) and all_passed
	host.free()

	# "Did you mean …?" typo quick-fix: a fat-fingered variable name resolves to the closest
	# real one; an unrelated name suggests nothing (no nonsense fixes).
	var typo_sheet := EventSheetResource.new()
	typo_sheet.variables = {"health": {"type": "int", "default": 100}, "speed": {"type": "float", "default": 50.0}}
	all_passed = _check("did-you-mean catches a one-letter typo",
		ACEParamsDialog.closest_known_identifier("helth", typo_sheet), "health") and all_passed
	all_passed = _check("did-you-mean catches a transposition",
		ACEParamsDialog.closest_known_identifier("sped", typo_sheet), "speed") and all_passed
	all_passed = _check("did-you-mean stays silent for an unrelated name",
		ACEParamsDialog.closest_known_identifier("xyzzy", typo_sheet), "") and all_passed

	return all_passed

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] ace_params_logic_test: %s" % label)
		return true
	print("[FAIL] ace_params_logic_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
