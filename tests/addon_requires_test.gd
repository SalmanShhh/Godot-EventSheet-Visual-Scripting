# Godot EventSheets - pack dependency declarations (@ace_requires)
# A pack states what it needs - class names, "autoload:Name", "pack:folder" - in
# `sheet.addon_requires`, emitted as one class-level `## @ace_requires(a, b)` line
# (metadata only, exactly the @ace_tags family). Pins: emission position (after the
# metadata markers, before @icon/class_name), the byte-exact importer recovery (split
# is the exact inverse of the join), the empty-default no-line rule, the typo-gate
# whitelist, and the shipped StatForge declaration.
@tool
class_name AddonRequiresTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true

	# ---- emission: one line, fixed position, exact join ----
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "Node"
	sheet.custom_class_name = "NeedyBehavior"
	sheet.custom_class_icon = "res://icon.svg"
	sheet.addon_requires = PackedStringArray(["autoload:AdvancedRandom", "StatSheetResource"])
	var output: String = str(SheetCompiler.compile(sheet, "user://eventsheets_requires_probe.gd").get("output", ""))
	all_passed = _check("the declaration emits as one annotation line",
		output.contains("## @ace_requires(autoload:AdvancedRandom, StatSheetResource)"), true) and all_passed
	all_passed = _check("it sits above @icon", output.find("@ace_requires") < output.find("@icon("), true) and all_passed
	all_passed = _check("it sits above class_name", output.find("@ace_requires") < output.find("class_name NeedyBehavior"), true) and all_passed
	var generated: GDScript = GDScript.new()
	generated.source_code = output
	all_passed = _check("the emitted script parses", generated.reload(true) == OK, true) and all_passed

	# ---- round-trip: the importer recovers the exact list (split inverts the join) ----
	var imported: EventSheetResource = GDScriptImporter.new().import_external_source(output)
	all_passed = _check("the importer recovers the declaration",
		imported.addon_requires, PackedStringArray(["autoload:AdvancedRandom", "StatSheetResource"])) and all_passed

	# ---- empty default: no line, so all existing packs stay byte-identical ----
	var bare_sheet: EventSheetResource = EventSheetResource.new()
	bare_sheet.behavior_mode = true
	bare_sheet.host_class = "Node"
	bare_sheet.custom_class_name = "PlainBehavior"
	var bare_output: String = str(SheetCompiler.compile(bare_sheet, "user://eventsheets_requires_bare.gd").get("output", ""))
	all_passed = _check("an empty declaration emits nothing", bare_output.contains("@ace_requires"), false) and all_passed

	# ---- typo-gate: the token is whitelisted, so scanning a declaring pack never warns ----
	var probe_source: String = "## A dependent pack.\n## @ace_requires(SomeClass)\nclass_name RequiresProbe\nextends Node\n"
	var probe_path: String = "user://eventsheets_requires_annotation_probe.gd"
	var probe_file: FileAccess = FileAccess.open(probe_path, FileAccess.WRITE)
	probe_file.store_string(probe_source)
	probe_file.close()
	var probe_script: GDScript = GDScript.new()
	probe_script.source_code = probe_source
	probe_script.take_over_path(probe_path)
	var metadata: Dictionary = EventSheetSemanticAnalyzer.new().parse_source_metadata(probe_script)
	all_passed = _check("@ace_requires is a known annotation (no typo warning)",
		(metadata.get("unknown_annotations", []) as Array).is_empty(), true) and all_passed
	all_passed = _check("the declaration stays out of the description",
		str(metadata.get("class_description", "")), "A dependent pack.") and all_passed

	# ---- the shipped demo: StatForge declares its resource-class dependency ----
	var stat_forge: String = FileAccess.get_file_as_string("res://eventsheet_addons/stat_forge/stat_forge_behavior.gd")
	all_passed = _check("StatForge declares StatSheetResource",
		stat_forge.contains("## @ace_requires(StatSheetResource)"), true) and all_passed

	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		return true
	print("  [FAIL] addon_requires_test: %s" % label)
	print("    expected: %s" % str(expected))
	print("    actual:   %s" % str(actual))
	return false
