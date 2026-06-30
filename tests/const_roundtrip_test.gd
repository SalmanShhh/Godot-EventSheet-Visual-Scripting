@tool
extends RefCounted
class_name ConstRoundtripTest
# A constant tree-variable compiles to `const NAME: T = v` and — when that .gd is reopened — lifts back
# into a first-class constant variable (is_constant true → the green "const" pill + dialog-editable),
# not a verbatim GDScript block. Byte-verify-gated: a const line whose canonical re-emission doesn't
# match the source stays verbatim, so this can never corrupt the round-trip.

const GDScriptImporter := preload("res://addons/eventforge/importer/gdscript_importer.gd")

static func run() -> bool:
	var all_passed: bool = true

	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	var const_var: LocalVariable = LocalVariable.new()
	const_var.name = "MAX_HP"
	const_var.type_name = "int"
	const_var.default_value = 100
	const_var.is_constant = true
	sheet.events.append(const_var)

	var output: String = str(SheetCompiler.compile(sheet).get("output", ""))
	all_passed = _check("compiles to a const declaration", output.contains("const MAX_HP: int = 100"), true) and all_passed

	# Reopen the .gd: the const must lift back to a first-class is_constant variable (import lifts internally).
	var sheet2: EventSheetResource = GDScriptImporter.new().import_external_source(output)
	var found: LocalVariable = null
	for ev: Variant in sheet2.events:
		if ev is LocalVariable and (ev as LocalVariable).name == "MAX_HP":
			found = ev
	all_passed = _check("const lifts to a first-class variable (not a verbatim block)", found != null, true) and all_passed
	if found != null:
		all_passed = _check("is_constant restored on import", found.is_constant, true) and all_passed
		all_passed = _check("type + default preserved", found.type_name == "int" and int(found.default_value) == 100, true) and all_passed

	# Re-saving the imported sheet reproduces the .gd byte-for-byte (drift=0).
	sheet2.external_source_path = "user://_const_rt_verify.gd"
	var recompiled: String = str(SheetCompiler.compile(sheet2, "user://_const_rt_verify.gd").get("output", ""))
	all_passed = _check("re-save is byte-identical (drift=0)", recompiled == output, true) and all_passed

	return all_passed

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] const_roundtrip_test: %s" % label)
		return true
	print("[FAIL] const_roundtrip_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
