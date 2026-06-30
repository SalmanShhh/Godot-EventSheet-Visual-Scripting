@tool
extends RefCounted
class_name ColorNoAlphaTest
# A Color variable with the "No alpha" tick compiles to @export_color_no_alpha (a solid RGB swatch in
# the Inspector) and round-trips STRUCTURALLY — reopening the .gd recovers the no_alpha attribute (so the
# dialog tick is re-checked + survives editing), not a verbatim hint. Verify-lift-gated like the drawers.

const GDScriptImporter := preload("res://addons/eventforge/importer/gdscript_importer.gd")

static func run() -> bool:
	var all_passed: bool = true

	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	var tint: LocalVariable = LocalVariable.new()
	tint.name = "tint"
	tint.type_name = "Color"
	tint.default_value = Color(1, 1, 1, 1)
	tint.exported = true
	tint.attributes = {"no_alpha": true}
	sheet.events.append(tint)

	var output: String = str(SheetCompiler.compile(sheet).get("output", ""))
	all_passed = _check("emits @export_color_no_alpha", output.contains("@export_color_no_alpha var tint: Color ="), true) and all_passed

	# Reopen: the hint is recovered into the structured no_alpha attribute (not left verbatim).
	var sheet2: EventSheetResource = GDScriptImporter.new().import_external_source(output)
	var found: LocalVariable = null
	for ev: Variant in sheet2.events:
		if ev is LocalVariable and (ev as LocalVariable).name == "tint":
			found = ev
	all_passed = _check("lifts back to a Color variable", found != null and found.type_name == "Color", true) and all_passed
	if found != null:
		all_passed = _check("no_alpha recovered structurally", found.attributes is Dictionary and bool((found.attributes as Dictionary).get("no_alpha", false)), true) and all_passed
		all_passed = _check("export_hint cleared (dialog-editable, not verbatim)", found.export_hint.strip_edges(), "") and all_passed

	# Re-saving the reopened sheet reproduces the .gd byte-for-byte.
	sheet2.external_source_path = "user://_no_alpha_rt_verify.gd"
	var recompiled: String = str(SheetCompiler.compile(sheet2, "user://_no_alpha_rt_verify.gd").get("output", ""))
	all_passed = _check("re-save is byte-identical (drift=0)", recompiled == output, true) and all_passed

	return all_passed

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] color_no_alpha_test: %s" % label)
		return true
	print("[FAIL] color_no_alpha_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
