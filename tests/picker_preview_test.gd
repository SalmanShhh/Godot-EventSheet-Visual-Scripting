# EventSheet - the Picker Preview census: what the LIVE sheet will publish, as the picker will
# read it. Pins VALUES: kind classification, display-name/category/featured overrides, param
# names, annotation shells, signal triggers, knobs from BOTH variable layers, and the exposure
# gate (internal helpers never preview).
@tool
class_name PickerPreviewTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"

	var dps: EventFunction = EventFunction.new()
	dps.function_name = "dps"
	dps.return_type = TYPE_FLOAT
	dps.expose_as_ace = true
	dps.ace_display_name = "Damage Per Second"
	dps.ace_category = "Combat"
	dps.featured = true
	var armor: ACEParam = ACEParam.new()
	armor.id = "armor"
	armor.name = "armor"
	dps.params.append(armor)
	sheet.functions.append(dps)
	var reset: EventFunction = EventFunction.new()
	reset.function_name = "reset_all"
	reset.return_type = TYPE_NIL
	reset.expose_as_ace = true
	sheet.functions.append(reset)
	var helper: EventFunction = EventFunction.new()
	helper.function_name = "internal_helper"
	helper.return_type = TYPE_FLOAT
	helper.expose_as_ace = false
	sheet.functions.append(helper)

	var shell: RawCodeRow = RawCodeRow.new()
	shell.code = "## @ace_condition\n## @ace_name(\"Is Charged\")\n## @ace_category(\"Combat\")"
	sheet.events.append(shell)
	var trigger: SignalRow = SignalRow.new()
	trigger.signal_name = "wave_started"
	trigger.trigger = true
	trigger.ace_name = "On Wave Started"
	sheet.events.append(trigger)
	var knob: LocalVariable = LocalVariable.new()
	knob.name = "max_health"
	knob.exported = true
	sheet.events.append(knob)
	sheet.variables = {"speed": {"type": "float", "exported": true}, "hidden_state": {"type": "int", "exported": false}}

	var entries: Array = EventSheetPickerPreviewPanel.collect_preview(sheet)
	all_passed = _check("the value function previews as a FEATURED expression with overrides",
		_entry(entries, "Damage Per Second"),
		{"kind": "expression", "name": "Damage Per Second", "category": "Combat", "featured": true, "params": ["armor"]}) and all_passed
	all_passed = _check("the void function previews as an action under its capitalized name",
		str(_entry(entries, "Reset All").get("kind")), "action") and all_passed
	all_passed = _check("an unexposed function never previews", _entry(entries, "Internal Helper"), {}) and all_passed
	all_passed = _check("an annotation shell previews with its declared kind and name",
		str(_entry(entries, "Is Charged").get("kind")), "condition") and all_passed
	all_passed = _check("a signal trigger previews under its published name",
		str(_entry(entries, "On Wave Started").get("kind")), "trigger") and all_passed
	all_passed = _check("a tree knob previews once, labelled with its four verbs",
		str(_entry(entries, "Max Health").get("category")), "get / set / add / subtract") and all_passed
	all_passed = _check("a dict knob previews too", str(_entry(entries, "Speed").get("kind")), "knob") and all_passed
	all_passed = _check("a non-exported dict variable never previews", _entry(entries, "Hidden State"), {}) and all_passed
	all_passed = _check("a null sheet previews nothing", EventSheetPickerPreviewPanel.collect_preview(null), []) and all_passed
	return all_passed


static func _entry(entries: Array, name: String) -> Dictionary:
	for entry: Variant in entries:
		if entry is Dictionary and str((entry as Dictionary).get("name")) == name:
			return entry as Dictionary
	return {}


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		return true
	print("[FAIL] picker_preview_test: %s - expected %s, got %s" % [label, str(expected), str(actual)])
	return false
