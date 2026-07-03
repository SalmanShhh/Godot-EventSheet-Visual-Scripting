# Godot EventSheets — saving a sheet as a plain .gd (the default format; no .tres needed).
#
# "Save As" / New Sheet now default to .gd. Saving to a .gd compiles the sheet to that file and
# re-opens it as the GDScript-backed source of truth (editable, not the read-only preview a casual
# Open gives), so the .gd IS the sheet and future edits round-trip through it. .tres/.res stay
# available. This pins the save-path defaults and the compile->reopen mechanism.
@tool
class_name SaveAsGDScriptTest
extends RefCounted

const PROBE_PATH := "res://__eventsheet_save_gd_probe.gd"


static func run() -> bool:
	var all_passed: bool = true
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.setup(null)

	# .gd is the default: bare/odd extensions normalize to .gd; .tres/.res/.gd are preserved.
	all_passed = _check("extensionless path defaults to .gd", dock._normalize_sheet_save_path("res://foo"), "res://foo.gd") and all_passed
	all_passed = _check("foreign extension coerces to .gd", dock._normalize_sheet_save_path("res://foo.txt"), "res://foo.gd") and all_passed
	all_passed = _check(".gd is preserved", dock._normalize_sheet_save_path("res://foo.gd"), "res://foo.gd") and all_passed
	all_passed = _check(".tres is still preserved", dock._normalize_sheet_save_path("res://foo.tres"), "res://foo.tres") and all_passed
	all_passed = _check("the default save filter is .gd", EventSheetDock.EVENT_SHEET_FILTERS[0].begins_with("*.gd"), true) and all_passed

	# Build a structured sheet and save it as .gd.
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "CharacterBody2D"
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnReady"
	var action: RawCodeRow = RawCodeRow.new()
	action.code = "print(\"ready\")"
	event.actions.append(action)
	sheet.events.append(event)
	dock.setup(sheet)
	_remove_probe()

	var tabs_before: int = dock._open_tabs.size()
	var saved: bool = dock._save_sheet_as_gdscript(PROBE_PATH)
	all_passed = _check("save as .gd succeeds", saved, true) and all_passed
	all_passed = _check("the .gd file was written", FileAccess.file_exists(PROBE_PATH), true) and all_passed
	# The sheet is now GDScript-backed and editable (not a read-only preview).
	all_passed = _check("sheet is now GDScript-backed", dock._current_sheet.external_source_path, PROBE_PATH) and all_passed
	all_passed = _check("backed sheet is editable, not a preview", dock._current_sheet.read_only, false) and all_passed
	all_passed = _check("host class survived the round-trip", dock._current_sheet.host_class, "CharacterBody2D") and all_passed
	# Save As replaces the active tab in place — it must NOT open a duplicate tab.
	all_passed = _check("save as .gd does not open a second tab", dock._open_tabs.size(), tabs_before) and all_passed

	# The source-of-truth .gd must NOT carry the "regenerated companion" banner.
	var on_disk: String = FileAccess.get_file_as_string(PROBE_PATH)
	all_passed = _check("no 'DO NOT EDIT' banner in the source .gd", on_disk.contains("DO NOT EDIT"), false) and all_passed
	all_passed = _check("no 'AUTO-GENERATED' banner in the source .gd", on_disk.contains("AUTO-GENERATED"), false) and all_passed
	all_passed = _check("the source .gd still declares extends", on_disk.contains("extends CharacterBody2D"), true) and all_passed

	# The .gd is now the byte-exact source of truth: recompiling reproduces it.
	var recompiled: Dictionary = SheetCompiler.compile(dock._current_sheet, PROBE_PATH)
	all_passed = _check("re-compile reproduces the .gd byte-for-byte", str(recompiled.get("output", "")), on_disk) and all_passed

	_remove_probe()
	dock.free()
	return all_passed


static func _remove_probe() -> void:
	for suffix: String in ["", ".uid", ".import"]:
		if FileAccess.file_exists(PROBE_PATH + suffix):
			DirAccess.remove_absolute(PROBE_PATH + suffix)


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] save_as_gdscript_test: %s" % label)
		return true
	print("[FAIL] save_as_gdscript_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
