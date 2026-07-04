# EventForge - Zero-config ACE addons (no JSON, no manifest)
#
# Scripts under res://eventsheet_addons/ register project-wide automatically; all metadata
# derives from the script (class_name, top doc comment, @ace_* annotations). The new
# @ace_display_template / @ace_codegen_template / @ace_param_hint annotations lift custom
# ACEs to builtin quality, and baked codegen templates make them genuinely compile.
@tool
class_name ACEAddonTest
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

	# Scanner discovers the demo addon.
	var scripts: Array[String] = EventSheetAddonScanner.list_addon_scripts()
	all_passed = _check("scanner finds the demo addon",
		scripts.has("res://eventsheet_addons/demo_health_addon.gd"), true) and all_passed

	# Analyzer: class description + new annotations parsed from source.
	var analyzer: EventSheetSemanticAnalyzer = EventSheetSemanticAnalyzer.new()
	var addon_script: Script = load("res://eventsheet_addons/demo_health_addon.gd")
	var source_metadata: Dictionary = analyzer.parse_source_metadata(addon_script)
	all_passed = _check("provider description from top doc comment",
		str(source_metadata.get("class_description", "")).contains("Demo EventSheet ACE addon"), true) and all_passed
	var heal_overrides: Dictionary = source_metadata.get("methods", {}).get("heal", {})
	all_passed = _check("@ace_display_template parsed", str(heal_overrides.get("display_template", "")), "Heal {amount} HP") and all_passed
	all_passed = _check("@ace_codegen_template parsed", str(heal_overrides.get("codegen_template", "")), "health += {amount}") and all_passed
	all_passed = _check("@ace_param_hint parsed",
		str((heal_overrides.get("param_hints", {}) as Dictionary).get("amount", "")), "expression") and all_passed

	# Dock: addon ACEs register project-wide with NO per-sheet configuration.
	var editor: EventSheetEditor = EventSheetEditor.new()
	var sheet: EventSheetResource = EventSheetResource.new()
	editor.setup(sheet)
	editor.set_undo_redo_manager(NoopUndoManager.new())
	all_passed = _check("sheet has no provider scripts configured", sheet.ace_provider_scripts.is_empty(), true) and all_passed
	var heal_definition: ACEDefinition = null
	for definition in editor._ace_registry.get_all_definitions():
		if definition.provider_id == "DemoHealthAddon" and definition.id == "method:heal":
			heal_definition = definition
	all_passed = _check("addon ACE registered project-wide (zero-config)", heal_definition != null, true) and all_passed
	if heal_definition != null:
		all_passed = _check("display template drives row text",
			heal_definition.format_display({"amount": 25}), "Heal 25 HP") and all_passed
		all_passed = _check("provider description carried on definitions",
			str(heal_definition.metadata.get("provider_description", "")).contains("Demo EventSheet ACE addon"), true) and all_passed
		var amount_hint: String = ""
		for parameter in heal_definition.parameters:
			if parameter is Dictionary and str((parameter as Dictionary).get("id", "")) == "amount":
				amount_hint = str((parameter as Dictionary).get("hint", ""))
		all_passed = _check("param hint reaches the definition parameters", amount_hint, "expression") and all_passed

		# Baked codegen: the created action compiles via its template (no descriptor needed).
		var action: ACEAction = editor._create_action_from_definition(heal_definition, {"amount": "25"})
		all_passed = _check("codegen template baked onto the action", action.codegen_template, "health += {amount}") and all_passed
		all_passed = _check("addon action compiles through ActionCodegen",
			ActionCodegen.generate_action(action), "health += 25") and all_passed

	# Conditions compile + negate through the baked template too.
	var hurt_definition: ACEDefinition = null
	for definition in editor._ace_registry.get_all_definitions():
		if definition.provider_id == "DemoHealthAddon" and definition.id == "method:is_hurt":
			hurt_definition = definition
	all_passed = _check("addon condition registered", hurt_definition != null, true) and all_passed
	if hurt_definition != null:
		var condition: ACECondition = editor._create_condition_from_definition(hurt_definition, {"threshold": "10"})
		all_passed = _check("addon condition compiles", ConditionCodegen.generate_condition(condition), "health < 10") and all_passed
		condition.negated = true
		all_passed = _check("negation wraps the baked template",
			ConditionCodegen.generate_condition(condition), "not (health < 10)") and all_passed
	editor.free()

	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] ace_addon_test: %s" % label)
		return true
	print("[FAIL] ace_addon_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
