@tool
class_name ConsoleAcesTest
extends RefCounted
# The Console module's "As" dropdown shows a friendly label (Message / Warning / Error) but inserts
# the matching Godot call (print / push_warning / push_error). This pins the friendly-label combo
# infrastructure end to end — the factory keeps {key,label} dict options, the adapter carries the
# label↔value split into the dialog-facing param dict, and the stored KEY is what lands in the
# generated code (so the dropdown reads "Warning" while the line is push_warning(...)).

const ConsoleACEs := preload("res://addons/eventforge/registration/modules/console_aces.gd")
const Adapter := preload("res://addons/eventsheet/ace/ace_adapter.gd")
const ActionCodegenLib := preload("res://addons/eventforge/compiler/action_codegen.gd")
const GDScriptImporter := preload("res://addons/eventforge/importer/gdscript_importer.gd")


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
	all_passed = _check("adapter keeps all 4 level options", level_opts.size(), 4) and all_passed
	var adapted_warn: Dictionary = level_opts[1] if level_opts.size() > 1 and level_opts[1] is Dictionary else {}
	all_passed = _check("adapter shows 'Warning'", str(adapted_warn.get("label", "")), "Warning") and all_passed
	all_passed = _check("adapter inserts 'push_warning'", str(adapted_warn.get("key", "")), "push_warning") and all_passed

	# The stored KEY (not the label) is what lands in the generated GDScript.
	var line: String = ActionCodegenLib._apply_template("if {condition}: {level}({message})",
		{"condition": "true", "level": "push_warning", "message": "\"x\""})
	all_passed = _check("the level key compiles into the line", line, "if true: push_warning(\"x\")") and all_passed

	# --- The bare "Log" verb round-trips AS ITSELF via the marker (not as Push Warning) ---
	var sheet: EventSheetResource = _sheet_with_action("ConsoleLog", "{level}({message})  # @ace:Core.ConsoleLog",
		{"level": "push_warning", "message": "\"low hp\""})
	var output: String = str(SheetCompiler.compile(sheet).get("output", ""))
	all_passed = _check("Log emits the marked line", output.contains("push_warning(\"low hp\")  # @ace:Core.ConsoleLog"), true) and all_passed

	var reopened: EventSheetResource = GDScriptImporter.new().import_external_source(output)
	var lifted: ACEAction = _find_action(reopened.events, "ConsoleLog")
	all_passed = _check("the marked line lifts back to Log (not Push Warning)", lifted != null, true) and all_passed
	if lifted != null:
		all_passed = _check("the As level is recovered", str(lifted.params.get("level", "")), "push_warning") and all_passed
	reopened.external_source_path = "user://_consolelog_rt.gd"
	var recompiled: String = str(SheetCompiler.compile(reopened, "user://_consolelog_rt.gd").get("output", ""))
	all_passed = _check("Log re-save is byte-identical (drift=0)", recompiled == output, true) and all_passed

	# --- Disambiguation: a PLAIN push_warning (no marker) still lifts to the specific Push Warning ---
	var plain: EventSheetResource = _sheet_with_action("PushWarning", "push_warning({message})", {"message": "\"plain\""})
	var plain_reopened: EventSheetResource = GDScriptImporter.new().import_external_source(str(SheetCompiler.compile(plain).get("output", "")))
	all_passed = _check("a plain push_warning lifts to Push Warning", _find_action(plain_reopened.events, "PushWarning") != null, true) and all_passed
	all_passed = _check("a plain push_warning does NOT become Log", _find_action(plain_reopened.events, "ConsoleLog") == null, true) and all_passed

	return all_passed


## Builds a one-row sheet (OnProcess trigger + a single action with a baked template) for round-trip checks.
static func _sheet_with_action(ace_id: String, template: String, params: Dictionary) -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	var row: EventRow = EventRow.new()
	row.trigger_provider_id = "Core"
	row.trigger_id = "OnProcess"
	var act: ACEAction = ACEAction.new()
	act.provider_id = "Core"
	act.ace_id = ace_id
	act.codegen_template = template
	act.params = params
	row.actions.append(act)
	sheet.events.append(row)
	return sheet


## Recursively finds the first action with this ace_id across event rows, their sub-events, and groups.
static func _find_action(rows: Array, ace_id: String) -> ACEAction:
	for r: Variant in rows:
		if r is EventRow:
			for a: Variant in (r as EventRow).actions:
				if a is ACEAction and (a as ACEAction).ace_id == ace_id:
					return a
			var nested: ACEAction = _find_action((r as EventRow).sub_events, ace_id)
			if nested != null:
				return nested
		elif r is EventGroup:
			var inside: ACEAction = _find_action((r as EventGroup).events, ace_id)
			if inside != null:
				return inside
	return null


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] console_aces_test: %s" % label)
		return true
	print("[FAIL] console_aces_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
