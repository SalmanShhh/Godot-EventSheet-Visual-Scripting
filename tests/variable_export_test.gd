# EventForge — Global variable private/global (export) toggle
#
# A global variable marked exported compiles to `@export var` (readable outside the script);
# a private one compiles to a plain `var`. Guards the toggle's effect on codegen.
@tool
class_name VariableExportTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true

	var exported_sheet: EventSheetResource = EventSheetResource.new()
	exported_sheet.variables = {"health": {"type": "int", "default": 100, "exported": true}}
	var exported_output: String = str(SheetCompiler.compile(exported_sheet, "user://eventforge_ve_export.gd").get("output", ""))
	all_passed = _check("exported global compiles to @export var",
		exported_output.contains("@export var health: int = 100"), true) and all_passed

	var private_sheet: EventSheetResource = EventSheetResource.new()
	private_sheet.variables = {"health": {"type": "int", "default": 100, "exported": false}}
	var private_output: String = str(SheetCompiler.compile(private_sheet, "user://eventforge_ve_private.gd").get("output", ""))
	all_passed = _check("private global compiles to a plain var",
		private_output.contains("var health: int = 100") and not private_output.contains("@export var health"), true) and all_passed

	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] variable_export_test: %s" % label)
		return true
	print("[FAIL] variable_export_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
