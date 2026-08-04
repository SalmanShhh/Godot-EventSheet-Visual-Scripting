# EventSheet - the project-code scanner (interop phase 1). Pins the ANTI-FLOODING contract
# by value: the plugin's own scripts and the bundled packs are never listed, `_`-private and
# class_name-less scripts stay out of the automatic set, autoload entries carry their
# singleton name (the emission target), and an opted-in extra path joins on demand. Also
# pins that the derivation path never instantiates - the scan works on scripts alone, which
# is what makes it correct inside the editor process.
@tool
class_name ProjectScannerTest
extends RefCounted

const TEMP_DIR: String = "res://.eventsheets_scan_test"
const TEMP_SCRIPT: String = TEMP_DIR + "/scratch_interop_source.gd"


static func run() -> bool:
	var ok: bool = true
	EventSheetProjectScanner.reset_for_tests()

	# ── The exclusion predicate (static + pure: no project state needed) ──
	ok = _check("a plain project script qualifies",
		EventSheetProjectScanner.is_project_script_path("res://systems/inventory.gd"), true) and ok
	ok = _check("the plugin's own tree is excluded",
		EventSheetProjectScanner.is_project_script_path("res://addons/eventsheet/editor/x.gd"), false) and ok
	ok = _check("bundled packs are excluded (they already publish)",
		EventSheetProjectScanner.is_project_script_path("res://eventsheet_addons/health/health_behavior.gd"), false) and ok
	ok = _check("non-script paths are excluded",
		EventSheetProjectScanner.is_project_script_path("res://art/player.png"), false) and ok
	ok = _check("empty input is excluded",
		EventSheetProjectScanner.is_project_script_path(""), false) and ok
	ok = _check("a path outside res:// is excluded",
		EventSheetProjectScanner.is_project_script_path("user://tmp.gd"), false) and ok

	ok = _check("a normal class name publishes",
		EventSheetProjectScanner.is_publishable_class_name("Inventory"), true) and ok
	ok = _check("an underscore-private class name never publishes",
		EventSheetProjectScanner.is_publishable_class_name("_InternalCache"), false) and ok
	ok = _check("a class_name-less script never publishes automatically",
		EventSheetProjectScanner.is_publishable_class_name(""), false) and ok

	# ── class_name read from SOURCE (no load, no instancing) ──
	DirAccess.make_dir_recursive_absolute(TEMP_DIR)
	var file: FileAccess = FileAccess.open(TEMP_SCRIPT, FileAccess.WRITE)
	file.store_string("class_name ScratchInteropSource\nextends Node\n\n\nfunc add_item(id: String) -> void:\n\tpass\n")
	file.close()
	ok = _check("the declared class name is read from the source header",
		EventSheetProjectScanner.class_name_for_path(TEMP_SCRIPT), "ScratchInteropSource") and ok
	ok = _check("a missing file reads as no class name",
		EventSheetProjectScanner.class_name_for_path("res://nope_missing.gd"), "") and ok
	# A script whose header declares nothing must not report a phantom name.
	var plain_path: String = TEMP_DIR + "/scratch_plain.gd"
	var plain: FileAccess = FileAccess.open(plain_path, FileAccess.WRITE)
	plain.store_string("extends Node\n\n\nfunc tick() -> void:\n\tpass\n")
	plain.close()
	ok = _check("a script with no class_name reads as empty",
		EventSheetProjectScanner.class_name_for_path(plain_path), "") and ok

	# ── The live scan: exclusions hold against the REAL project ──
	var scanned: Array = EventSheetProjectScanner.list_project_classes()
	var leaked_plugin: bool = false
	var leaked_pack: bool = false
	var shapes_ok: bool = true
	for entry: Dictionary in scanned:
		var path: String = str(entry.get("path", ""))
		if path.begins_with("res://addons/"):
			leaked_plugin = true
		if path.begins_with("res://eventsheet_addons/"):
			leaked_pack = true
		if not entry.has("name") or not entry.has("kind") or not entry.has("autoload"):
			shapes_ok = false
	ok = _check("no plugin script leaks into the project vocabulary", leaked_plugin, false) and ok
	ok = _check("no bundled pack leaks into the project vocabulary", leaked_pack, false) and ok
	ok = _check("every entry carries the documented shape", shapes_ok, true) and ok
	# Deduped by path and sorted by name - the picker's order must be reproducible.
	var names: Array = []
	var paths: Array = []
	var sorted_ok: bool = true
	for entry: Dictionary in scanned:
		if paths.has(str(entry.get("path"))):
			sorted_ok = false
		paths.append(str(entry.get("path")))
		names.append(str(entry.get("name")))
	var expected_order: Array = names.duplicate()
	expected_order.sort()
	ok = _check("entries are unique by path", sorted_ok, true) and ok
	ok = _check("entries are sorted by name (reproducible picker order)", names, expected_order) and ok

	# Autoload entries carry their singleton name - that IS the emission target.
	for entry: Dictionary in EventSheetProjectScanner.list_autoloads():
		if str(entry.get("kind")) != "autoload" or str(entry.get("autoload")).is_empty():
			ok = _check("every autoload entry names its singleton", false, true) and ok
			break

	# ── The opt-in extra path admits a class_name-less folder, and only then ──
	var before: int = EventSheetProjectScanner.list_project_classes().size()
	ProjectSettings.set_setting(EventSheetProjectScanner.EXTRA_PATHS_SETTING, PackedStringArray([TEMP_DIR]))
	EventSheetProjectScanner.reset_for_tests()
	var after: Array = EventSheetProjectScanner.list_project_classes()
	var found_scratch: bool = false
	var found_plain: bool = false
	for entry: Dictionary in after:
		if str(entry.get("path")) == TEMP_SCRIPT:
			found_scratch = true
		if str(entry.get("path")) == plain_path:
			found_plain = true
	ok = _check("an opted-in folder's declared class joins the scan", found_scratch, true) and ok
	ok = _check("the opt-in never publishes a class_name-less script", found_plain, false) and ok
	ok = _check("the opt-in adds exactly the qualifying script", after.size(), before + 1) and ok

	# ── Cleanup: the setting and the scratch files must not survive the test ──
	ProjectSettings.set_setting(EventSheetProjectScanner.EXTRA_PATHS_SETTING, PackedStringArray())
	DirAccess.remove_absolute(TEMP_SCRIPT)
	DirAccess.remove_absolute(plain_path)
	DirAccess.remove_absolute(TEMP_DIR)
	EventSheetProjectScanner.reset_for_tests()
	return ok


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		return true
	print("[FAIL] project_scanner_test: %s - expected %s, got %s" % [label, str(expected), str(actual)])
	return false
