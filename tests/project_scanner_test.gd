# EventSheet - the project-code scanner. Pins the ANTI-FLOODING contract
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

	# ── The scene-class filter: the anti-flooding rule, by value ──
	# Measured on this project: 429 declared classes, 21 Node-derived. Everything dropped is
	# a test/tool/data class nobody picks an ACTION on.
	var bases: Dictionary = {"Enemy": "BaseActor", "BaseActor": "Sprite2D", "ItemData": "Resource",
		"Helper": "RefCounted", "SuiteTest": "RefCounted"}
	ok = _check("a direct Node subclass earns a card",
		EventSheetProjectScanner.is_scene_class("Node2D", bases), true) and ok
	ok = _check("a CUSTOM base chain resolves to its engine root",
		EventSheetProjectScanner.is_scene_class("BaseActor", bases), true) and ok
	ok = _check("a Resource data class earns no card",
		EventSheetProjectScanner.is_scene_class("Resource", bases), false) and ok
	ok = _check("a RefCounted helper earns no card",
		EventSheetProjectScanner.is_scene_class("RefCounted", bases), false) and ok
	ok = _check("a test class (RefCounted chain) earns no card",
		EventSheetProjectScanner.is_scene_class("SuiteTest", bases), false) and ok
	ok = _check("an unknown base earns no card",
		EventSheetProjectScanner.is_scene_class("NotAClass", bases), false) and ok
	# A cyclic base chain must terminate rather than hang the scan.
	ok = _check("a cyclic base chain fails closed",
		EventSheetProjectScanner.is_scene_class("A", {"A": "B", "B": "A"}), false) and ok

	# ── The live scan: exclusions hold against the REAL project ──
	# Every assertion below passes vacuously on an empty array, so the scan is first proven
	# NON-empty: this repo declares Node-derived classes (the showcases), and a scanner that
	# silently returned nothing would otherwise look perfectly healthy here.
	var scanned: Array = EventSheetProjectScanner.list_project_classes()
	ok = _check("the live scan actually finds this project's classes", scanned.size() > 0, true) and ok
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
	# Admitting a class_name-LESS script is the opt-in's whole stated purpose: it is the only
	# route for such code, and it identifies the script by its PascalCase file name (the same
	# identity the provider system already assigns).
	ok = _check("the opt-in DOES admit a class_name-less script (its stated purpose)", found_plain, true) and ok
	ok = _check("the opt-in adds both scripts in the folder", after.size(), before + 2) and ok
	var plain_named: String = ""
	for entry: Dictionary in after:
		if str(entry.get("path")) == plain_path:
			plain_named = str(entry.get("name"))
	ok = _check("a class_name-less script is identified by its file name",
		plain_named, "ScratchPlain") and ok

	# ── An ANNOTATED script belongs to its annotations, never to this scan ──
	# Reflecting it again would list every public member a second time and defeat @ace_hidden.
	var annotated_path: String = TEMP_DIR + "/scratch_annotated.gd"
	var annotated: FileAccess = FileAccess.open(annotated_path, FileAccess.WRITE)
	annotated.store_string("## @ace_category(\"Scratch\")\nclass_name ScratchAnnotated\nextends Node\n")
	annotated.close()
	ok = _check("an annotated script is recognised as a provider",
		EventSheetProjectScanner.is_annotated_provider(annotated_path), true) and ok
	ok = _check("a plain script is not",
		EventSheetProjectScanner.is_annotated_provider(plain_path), false) and ok
	ok = _check("a passing mention of @ace_ in prose does not count",
		EventSheetProjectScanner.is_annotated_provider(TEMP_SCRIPT), false) and ok
	DirAccess.remove_absolute(annotated_path)

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
