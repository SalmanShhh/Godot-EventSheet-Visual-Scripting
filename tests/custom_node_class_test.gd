# EventForge — Custom node types authored by event sheets
#
# A sheet with custom_class_name compiles to `@icon(...)` + `class_name X` + `extends Y`,
# making the generated script a real custom node (Create Node dialog, scene tree icon) —
# the same mechanism as hand-written GDScript. Sheets without a name are unaffected.
@tool
extends RefCounted
class_name CustomNodeClassTest

static func run() -> bool:
	var all_passed: bool = true

	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "CharacterBody2D"
	sheet.custom_class_name = "PatrollingGuard"
	sheet.custom_class_icon = "res://addons/eventsheet/icons/eventsheet.svg"
	var output: String = str(SheetCompiler.compile(sheet, "user://eventforge_custom_node.gd").get("output", ""))
	all_passed = _check("class_name emitted", output.contains("class_name PatrollingGuard"), true) and all_passed
	all_passed = _check("icon annotation emitted", output.contains("@icon(\"res://addons/eventsheet/icons/eventsheet.svg\")"), true) and all_passed
	all_passed = _check("declaration order is @icon, class_name, extends",
		output.find("@icon(") < output.find("class_name ") and output.find("class_name ") < output.find("extends CharacterBody2D"), true) and all_passed

	# Icon without a class name is meaningless and must not emit (invalid placement).
	var icon_only: EventSheetResource = EventSheetResource.new()
	icon_only.custom_class_icon = "res://addons/eventsheet/icons/eventsheet.svg"
	var icon_only_output: String = str(SheetCompiler.compile(icon_only, "user://eventforge_icon_only.gd").get("output", ""))
	all_passed = _check("icon alone does not emit", icon_only_output.contains("@icon"), false) and all_passed

	# Default sheets are byte-unaffected (golden demo output stays stable).
	var plain: EventSheetResource = EventSheetResource.new()
	var plain_output: String = str(SheetCompiler.compile(plain, "user://eventforge_plain_node.gd").get("output", ""))
	all_passed = _check("sheets without a name emit no class_name", plain_output.contains("class_name"), false) and all_passed

	# Icon resolution for the picker: explicit res:// textures load even headless; editor
	# class icons return null outside the editor (graceful degradation, no crash).
	var icon_definition: ACEDefinition = ACEDefinition.new()
	icon_definition.icon = "res://addons/eventsheet/icons/eventsheet.svg"
	var resolved: Texture2D = ACEPickerDialog.resolve_definition_icon(icon_definition)
	all_passed = _check("res:// @ace_icon paths resolve to textures",
		resolved != null if ResourceLoader.exists("res://addons/eventsheet/icons/eventsheet.svg") else resolved == null, true) and all_passed
	all_passed = _check("editor icons degrade to null headless",
		ACEPickerDialog.editor_icon("CharacterBody2D") == null or Engine.is_editor_hint(), true) and all_passed
	all_passed = _check("null definition resolves to no icon", ACEPickerDialog.resolve_definition_icon(null) == null, true) and all_passed

	return all_passed

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] custom_node_class_test: %s" % label)
		return true
	print("[FAIL] custom_node_class_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
