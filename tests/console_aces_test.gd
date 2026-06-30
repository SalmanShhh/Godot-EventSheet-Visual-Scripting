@tool
extends RefCounted
class_name ConsoleAcesTest
# The Console module's "As" dropdown shows a friendly label (Message / Warning / Error) but inserts
# the matching Godot call (print / push_warning / push_error). This pins the friendly-label combo
# infrastructure end to end — the factory keeps {key,label} dict options, the adapter carries the
# label↔value split into the dialog-facing param dict, and the stored KEY is what lands in the
# generated code (so the dropdown reads "Warning" while the line is push_warning(...)).

const ConsoleACEs := preload("res://addons/eventforge/registration/modules/console_aces.gd")
const Adapter := preload("res://addons/eventsheet/ace/ace_adapter.gd")
const ActionCodegenLib := preload("res://addons/eventforge/compiler/action_codegen.gd")

static func run() -> bool:
	var all_passed: bool = true

	var log_if: ACEDescriptor = null
	for d: ACEDescriptor in ConsoleACEs.get_descriptors():
		if d.ace_id == "ConsoleLogIf":
			log_if = d
	all_passed = _check("ConsoleLogIf descriptor exists", log_if != null, true) and all_passed
	if log_if == null:
		return false

	# The factory preserved the {key,label} dict options on the level param (label != key).
	var level_param: ACEParam = null
	for p: ACEParam in log_if.params:
		if p.id == "level":
			level_param = p
	all_passed = _check("level param exists", level_param != null, true) and all_passed
	var warn_dict: Dictionary = {}
	if level_param != null and level_param.options.size() >= 2 and level_param.options[1] is Dictionary:
		warn_dict = level_param.options[1]
	all_passed = _check("factory kept the friendly label", str(warn_dict.get("label", "")), "Warning") and all_passed
	all_passed = _check("factory kept the inserted value", str(warn_dict.get("key", "")), "push_warning") and all_passed

	# The adapter carries the label↔value split into the dialog-facing param dict.
	var def: ACEDefinition = Adapter.from_eventforge_descriptor(log_if)
	var level_opts: Array = []
	for pd: Variant in def.parameters:
		if pd is Dictionary and str((pd as Dictionary).get("id", "")) == "level":
			level_opts = (pd as Dictionary).get("options", [])
	all_passed = _check("adapter keeps all 3 level options", level_opts.size(), 3) and all_passed
	var adapted_warn: Dictionary = level_opts[1] if level_opts.size() > 1 and level_opts[1] is Dictionary else {}
	all_passed = _check("adapter shows 'Warning'", str(adapted_warn.get("label", "")), "Warning") and all_passed
	all_passed = _check("adapter inserts 'push_warning'", str(adapted_warn.get("key", "")), "push_warning") and all_passed

	# The stored KEY (not the label) is what lands in the generated GDScript.
	var line: String = ActionCodegenLib._apply_template("if {condition}: {level}({message})",
		{"condition": "true", "level": "push_warning", "message": "\"x\""})
	all_passed = _check("the level key compiles into the line", line, "if true: push_warning(\"x\")") and all_passed

	return all_passed

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] console_aces_test: %s" % label)
		return true
	print("[FAIL] console_aces_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
