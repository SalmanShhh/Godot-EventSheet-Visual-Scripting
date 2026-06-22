# Godot EventSheets — Signal autocomplete (C3 object-signal parity)
# Signals join member completion (host members, typed variables, $GlobalClass — incl.
# script-declared signals), and signal params get a picker: host-class signals + signals
# declared in the sheet's GDScript blocks, offered as a dropdown instead of typed text.
@tool
extends RefCounted
class_name SignalAutocompleteTest

static func run() -> bool:
	var all_passed: bool = true

	# Dot-completion: typed sheet variable -> its class's signals.
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Area2D"
	sheet.variables = {"zone": {"type": "Area2D", "default": null, "exported": false}}
	var labels: Array[String] = []
	for candidate in EventSheetGDScriptLint.completion_for_context("zone.", sheet):
		labels.append(str(candidate.get("label", "")))
	all_passed = _check("typed variables complete class signals", labels.has("body_entered"), true) and all_passed

	# $GlobalClass. includes script-declared signals (PlatformerMovement declares jumped).
	var pack_labels: Array[String] = []
	for candidate in EventSheetGDScriptLint.completion_for_context("$PlatformerMovement.", sheet):
		pack_labels.append(str(candidate.get("label", "")))
	all_passed = _check("$GlobalClass completes script signals", pack_labels.has("jumped"), true) and all_passed

	# Signal picker options: host signals + block-declared signals, deduplicated + sorted.
	var declared: RawCodeRow = RawCodeRow.new()
	declared.code = "signal custom_hit(damage: int)\nsignal custom_hit(damage: int)\nvar helper := 0"
	sheet.events.append(declared)
	var dialog: ACEParamsDialog = ACEParamsDialog.new()
	dialog.set_lint_context_provider(func() -> EventSheetResource: return sheet)
	var options: Array[String] = dialog._signal_options()
	all_passed = _check("picker offers host-class signals", options.has("body_entered") and options.has("area_entered"), true) and all_passed
	all_passed = _check("picker offers block-declared signals (deduped, args stripped)",
		options.count("custom_hit"), 1) and all_passed

	# The field is a dropdown; unknown current values are preserved as the first option.
	var field: Control = dialog._create_signal_reference_field("signal_name", "my_legacy_signal")
	all_passed = _check("signal params render as dropdowns", field is OptionButton, true) and all_passed
	all_passed = _check("custom values persist in the dropdown",
		(field as OptionButton).get_item_text(0), "my_legacy_signal") and all_passed
	field.free()

	# Descriptors: OnSignal/EmitSignal carry the signal picker hint; EmitSignal emits the modern signal.emit() form.
	var by_id: Dictionary = {}
	for descriptor in EventForgeBuiltinACEs.get_descriptors():
		by_id[descriptor.ace_id] = descriptor
	all_passed = _check("OnSignal uses the signal picker",
		str((by_id["OnSignal"].params[0] as ACEParam).hint), "signal_reference") and all_passed
	all_passed = _check("EmitSignal emits the modern signal.emit() form",
		str(by_id["EmitSignal"].codegen_template).contains("{signal_name}.emit("), true) and all_passed
	all_passed = _check("EmitSignal stores a bare signal identifier",
		str((by_id["EmitSignal"].params[0] as ACEParam).hint), "signal_reference") and all_passed
	var quoted_field: Control = dialog._create_signal_reference_field("signal_name", "\"custom_hit\"", true)
	all_passed = _check("quoted picker shows raw names but stores literals",
		(quoted_field as OptionButton).get_item_metadata((quoted_field as OptionButton).selected), "\"custom_hit\"") and all_passed
	quoted_field.free()

	return all_passed

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] signal_autocomplete_test: %s" % label)
		return true
	print("[FAIL] signal_autocomplete_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
