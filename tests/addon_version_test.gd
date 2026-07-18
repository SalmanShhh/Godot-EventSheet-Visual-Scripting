# Godot EventSheets - pack identity metadata (@ace_version / @ace_author / @ace_help)
# A pack declares its version, author, and help link in sheet fields, emitted as class-level
# annotations in the @ace_tags family (metadata only, byte-exact round-trip, empty = no
# line). Pins: emission position and quoting, importer recovery as the exact inverse, the
# empty defaults emitting nothing, the typo-gate whitelist, every shipped pack carrying the
# 1.0.0 stamp, and the banner chip picking the version up.
@tool
class_name AddonVersionTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true

	# ---- emission: the three lines, ordered after @ace_requires, before @icon ----
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "Node"
	sheet.custom_class_name = "VersionedBehavior"
	sheet.custom_class_icon = "res://icon.svg"
	sheet.addon_requires = PackedStringArray(["Node2D"])
	sheet.addon_version = "2.3.1"
	sheet.addon_author = "Jam Author"
	sheet.addon_help_url = "https://example.com/help"
	var output: String = str(SheetCompiler.compile(sheet, "user://eventsheets_version_probe.gd").get("output", ""))
	all_passed = _check("version emits unquoted", output.contains("## @ace_version(2.3.1)"), true) and all_passed
	all_passed = _check("author emits quoted", output.contains("## @ace_author(\"Jam Author\")"), true) and all_passed
	all_passed = _check("help emits quoted", output.contains("## @ace_help(\"https://example.com/help\")"), true) and all_passed
	all_passed = _check("identity sits after requires", output.find("@ace_requires") < output.find("@ace_version"), true) and all_passed
	all_passed = _check("identity sits above @icon", output.find("@ace_help") < output.find("@icon("), true) and all_passed
	var generated: GDScript = GDScript.new()
	generated.source_code = output
	all_passed = _check("the emitted script parses", generated.reload(true) == OK, true) and all_passed

	# ---- round-trip: the importer recovers all three exactly ----
	var imported: EventSheetResource = GDScriptImporter.new().import_external_source(output)
	all_passed = _check("version recovers", imported.addon_version, "2.3.1") and all_passed
	all_passed = _check("author recovers", imported.addon_author, "Jam Author") and all_passed
	all_passed = _check("help recovers", imported.addon_help_url, "https://example.com/help") and all_passed

	# ---- empty defaults: no lines, so undeclared sheets stay byte-identical ----
	var bare: EventSheetResource = EventSheetResource.new()
	bare.behavior_mode = true
	bare.host_class = "Node"
	bare.custom_class_name = "PlainBehavior"
	var bare_output: String = str(SheetCompiler.compile(bare, "user://eventsheets_version_bare.gd").get("output", ""))
	all_passed = _check("empty identity emits nothing", bare_output.contains("@ace_version") or bare_output.contains("@ace_author") or bare_output.contains("@ace_help"), false) and all_passed

	# ---- typo-gate: the three tokens are whitelisted ----
	var probe_source: String = "## A versioned pack.\n## @ace_version(1.2.0)\n## @ace_author(\"Someone\")\n## @ace_help(\"https://x.y\")\nclass_name VersionProbe\nextends Node\n"
	var probe_path: String = "user://eventsheets_version_annotation_probe.gd"
	var probe_file: FileAccess = FileAccess.open(probe_path, FileAccess.WRITE)
	probe_file.store_string(probe_source)
	probe_file.close()
	var probe_script: GDScript = GDScript.new()
	probe_script.source_code = probe_source
	probe_script.take_over_path(probe_path)
	var metadata: Dictionary = EventSheetSemanticAnalyzer.new().parse_source_metadata(probe_script)
	all_passed = _check("the identity tokens are known annotations", (metadata.get("unknown_annotations", []) as Array).is_empty(), true) and all_passed
	all_passed = _check("identity stays out of the description", str(metadata.get("class_description", "")), "A versioned pack.") and all_passed

	# ---- every shipped pack carries the 1.0.0 stamp ----
	var unstamped: Array[String] = []
	for pack_script: String in EventSheetAddonScanner.list_addon_scripts():
		if not FileAccess.get_file_as_string(pack_script).contains("## @ace_version("):
			unstamped.append(pack_script)
	all_passed = _check("all shipped packs are versioned (got unstamped: %s)" % str(unstamped), unstamped.is_empty(), true) and all_passed

	# ---- the banner chip picks the version up ----
	var banner: SheetIdentityBanner = SheetIdentityBanner.new()
	banner.update_from_sheet(sheet, "res://eventsheet_addons/versioned/versioned_behavior.gd")
	all_passed = _check("the banner reads the pack version", banner._addon_version, "2.3.1") and all_passed
	all_passed = _check("the banner knows it is a pack", banner._is_addon_pack, true) and all_passed
	banner.free()

	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		return true
	print("  [FAIL] addon_version_test: %s (got %s, expected %s)" % [label, str(actual), str(expected)])
	return false
