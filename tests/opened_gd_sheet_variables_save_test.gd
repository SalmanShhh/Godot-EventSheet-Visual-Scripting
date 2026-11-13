# Godot EventSheets - a sheet opened FROM a .gd saves what the Variable window stored on it.
# The Variable window keeps an Instance-scope variable in the sheet's own `variables` table, and an
# opened .gd writes its rows in order, so that table is the part of the sheet the order-preserving
# save has to carry as well. Pins: an Instance variable, a constant and a private one reach the bytes
# Save writes (the same compile call the dock's Save makes), they come back as ordinary variable rows
# on reopen, a second save is byte-stable, and an untouched file still round-trips byte for byte.
@tool
class_name OpenedGdSheetVariablesSaveTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const PATH := "user://opened_gd_sheet_variables_save_probe.gd"
const SOURCE := "extends Node\n\n\nvar speed: int = 5\n\n\nfunc _ready() -> void:\n\tpass\n"


static func run() -> bool:
	var name: String = "opened_gd_sheet_variables_save_test"
	var passed: bool = true
	var file: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(SOURCE)
	file.close()

	# An untouched file still saves as the bytes it was.
	var untouched: EventSheetResource = EventSheetGDScriptImporter.new().import_external(PATH)
	EventSheetCompiler.compile(untouched, untouched.external_source_path)
	passed = SUPPORT.check(name, "an untouched file saves byte for byte", FileAccess.get_file_as_string(PATH), SOURCE) and passed

	# The Variable window's three Instance-scope shapes, stored the way it stores them.
	var sheet: EventSheetResource = EventSheetGDScriptImporter.new().import_external(PATH)
	sheet.variables["health"] = {"type": "int", "default": 10, "const": false, "exported": true, "exposed": true, "options": [], "attributes": {}}
	sheet.variables["secret"] = {"type": "float", "default": 2.5, "const": false, "exported": false, "exposed": false, "options": [], "attributes": {}}
	sheet.variables["MAX_HP"] = {"type": "int", "default": 99, "const": true, "exported": false, "exposed": false, "options": [], "attributes": {}}
	var signal_row: SignalRow = SignalRow.new()
	signal_row.signal_name = "died"
	sheet.events.append(signal_row)
	var enum_row: EnumRow = EnumRow.new()
	enum_row.enum_name = "Kind"
	enum_row.members = PackedStringArray(["A", "B"])
	sheet.events.append(enum_row)
	var result: Dictionary = EventSheetCompiler.compile(sheet, sheet.external_source_path)
	var saved: String = FileAccess.get_file_as_string(PATH)
	passed = SUPPORT.check(name, "the compile succeeds", bool(result.get("success", false)), true) and passed
	passed = SUPPORT.check(name, "an exported Instance variable is written", saved.contains("@export var health: int = 10"), true) and passed
	passed = SUPPORT.check(name, "a private Instance variable is written", saved.contains("var secret: float = 2.5"), true) and passed
	passed = SUPPORT.check(name, "a constant stored in the table is written", saved.contains(" MAX_HP: int = 99"), true) and passed
	passed = SUPPORT.check(name, "a signal row is written", saved.contains("signal died"), true) and passed
	passed = SUPPORT.check(name, "an enum row is written", saved.contains("enum Kind"), true) and passed
	passed = SUPPORT.check(name, "the file's own variable is still there once", saved.count("var speed: int = 5"), 1) and passed

	# Reopened, the new declarations are ordinary rows; a second save changes nothing.
	var reopened: EventSheetResource = EventSheetGDScriptImporter.new().import_external(PATH)
	var names: PackedStringArray = PackedStringArray()
	for entry: Variant in reopened.events:
		if entry is LocalVariable:
			names.append((entry as LocalVariable).name)
	passed = SUPPORT.check(name, "reopened, each is a variable row", names.has("health") and names.has("secret") and names.has("MAX_HP"), true) and passed
	EventSheetCompiler.compile(reopened, reopened.external_source_path)
	passed = SUPPORT.check(name, "a second save is byte-stable", FileAccess.get_file_as_string(PATH), saved) and passed
	passed = SUPPORT.check(name, "no declaration is doubled", FileAccess.get_file_as_string(PATH).count("var health"), 1) and passed
	var parsed: GDScript = GDScript.new()
	parsed.source_code = saved
	passed = SUPPORT.check(name, "the saved file parses", parsed.reload(true), OK) and passed
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	return passed
