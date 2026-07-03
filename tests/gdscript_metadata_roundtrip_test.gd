# Godot EventSheets — sheet metadata round-trips through a .gd-backed sheet.
#
# Toward "no .tres needed": opening a .gd as a sheet, editing, and saving must not lose authoring
# metadata. addon_tags (## @ace_tags) and autoload identity (the project's [autoload] registration)
# are now recovered on import. Both are METADATA-ONLY — the annotation text stays verbatim in the
# file and the registration is read from ProjectSettings — so the byte-exact round-trip is unchanged
# (no double-emit).
@tool
class_name GDScriptMetadataRoundtripTest
extends RefCounted

const TAGGED_SOURCE := "@tool\n## @ace_tags(movement, retro, jam)\n@icon(\"res://icon.svg\")\nclass_name Patrol\nextends CharacterBody2D\n"
const PROBE_PATH := "res://__eventsheet_metadata_probe.gd"
const PROBE_AUTOLOAD := "autoload/__EventSheetProbeAutoload"


static func run() -> bool:
	var all_passed: bool = true
	var importer: GDScriptImporter = GDScriptImporter.new()

	# addon_tags are recovered from the ## @ace_tags annotation.
	var sheet: EventSheetResource = importer.import_external_source(TAGGED_SOURCE)
	all_passed = _check("addon_tags recovered from @ace_tags",
		sheet.addon_tags, PackedStringArray(["movement", "retro", "jam"])) and all_passed
	# The other identity fields still round-trip alongside it.
	all_passed = _check("custom_class_name still recovered", sheet.custom_class_name, "Patrol") and all_passed
	all_passed = _check("custom_class_icon still recovered", sheet.custom_class_icon, "res://icon.svg") and all_passed

	# Byte-identity is preserved: the @ace_tags line stays verbatim, never double-emitted.
	sheet.external_source_path = PROBE_PATH
	var compile_result: Dictionary = SheetCompiler.compile(sheet, PROBE_PATH)
	all_passed = _check("tagged source round-trips byte-identically",
		str(compile_result.get("output", "")), TAGGED_SOURCE) and all_passed
	_remove_probe_file()

	# A source without tags leaves addon_tags empty (no spurious recovery).
	var untagged: EventSheetResource = importer.import_external_source("extends Node\n")
	all_passed = _check("no tags → addon_tags stays empty", untagged.addon_tags.is_empty(), true) and all_passed

	# The tags regex is non-greedy: trailing text after the close paren is not swallowed into a tag.
	var trailing: EventSheetResource = importer.import_external_source("## @ace_tags(movement, retro) and a note)\nextends Node\n")
	all_passed = _check("tags stop at the first close paren (no over-match)",
		trailing.addon_tags, PackedStringArray(["movement", "retro"])) and all_passed

	# The autoload matcher resolves res:// directly (uid:// is resolved via ResourceUID at runtime).
	all_passed = _check("autoload matcher: exact res:// path matches",
		GDScriptImporter._autoload_target_matches("res://game_state.gd", "res://game_state.gd"), true) and all_passed
	all_passed = _check("autoload matcher: a different path does not match",
		GDScriptImporter._autoload_target_matches("res://other.gd", "res://game_state.gd"), false) and all_passed

	# Autoload identity is recovered from the project's [autoload] registration (the source of truth).
	var had_setting: bool = ProjectSettings.has_setting(PROBE_AUTOLOAD)
	ProjectSettings.set_setting(PROBE_AUTOLOAD, "*" + PROBE_PATH)
	var autoload_sheet: EventSheetResource = EventSheetResource.new()
	GDScriptImporter._recover_autoload_identity(autoload_sheet, PROBE_PATH)
	all_passed = _check("autoload_mode recovered from registration", autoload_sheet.autoload_mode, true) and all_passed
	all_passed = _check("autoload_name recovered from registration", autoload_sheet.autoload_name, "__EventSheetProbeAutoload") and all_passed
	# An unregistered .gd is a plain sheet, not an autoload.
	var plain_sheet: EventSheetResource = EventSheetResource.new()
	GDScriptImporter._recover_autoload_identity(plain_sheet, "res://__never_registered.gd")
	all_passed = _check("unregistered .gd is not an autoload", plain_sheet.autoload_mode, false) and all_passed
	if not had_setting:
		ProjectSettings.set_setting(PROBE_AUTOLOAD, null)

	return all_passed


static func _remove_probe_file() -> void:
	if FileAccess.file_exists(PROBE_PATH):
		DirAccess.remove_absolute(PROBE_PATH)
	if FileAccess.file_exists(PROBE_PATH + ".uid"):
		DirAccess.remove_absolute(PROBE_PATH + ".uid")


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] gdscript_metadata_roundtrip_test: %s" % label)
		return true
	print("[FAIL] gdscript_metadata_roundtrip_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
