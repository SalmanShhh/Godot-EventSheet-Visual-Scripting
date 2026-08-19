@tool
class_name DataTableSheetTest
extends RefCounted

# V4b. A .tres opened as a TABLE, and a folder of .tres opened as ONE grid.
#
# Pins the model the table view is drawn from - what the columns are, what each asset holds, what a
# new row and a deleted row do - and, above everything else, the promise the view rests on:
#
#   OPENING A DATA ASSET AS A TABLE AND SAVING IT WITH NOTHING EDITED WRITES THE FILE BACK
#   BYTE-IDENTICALLY.
#
# That promise is the whole reason the view is safe to open. A grid that quietly reformatted a
# designer's assets would show up as a diff in every commit, so the gate below writes an asset,
# reads it as a table, saves each field back with the value it already had, and compares the bytes.

const FOLDER := "user://eventforge_data_table"

const TYPE_PATH := "user://eventforge_data_table/enemy_stats_test_type.gd"

const TYPE_SOURCE: String = """@tool
class_name EventForgeDataTableTestType
extends Resource

@export var hp: int = 10
@export var speed: float = 60.0
@export var drops: Array[String] = []
"""


static func run() -> bool:
	var ok: bool = true
	_make_folder()
	var script: Script = _test_type()
	if script == null:
		print("[FAIL] data_table_sheet_test: the test data type could not be written")
		return false
	var slime: String = FOLDER.path_join("slime.tres")
	var bat: String = FOLDER.path_join("bat.tres")
	_write_asset(script, slime, 8, 90.0, PackedStringArray(["slime", "gel"]))
	_write_asset(script, bat, 4, 140.0, PackedStringArray(["wing"]))

	ok = _columns(slime) and ok
	ok = _one_asset(slime) and ok
	ok = _grid() and ok
	ok = _byte_stable(slime) and ok
	ok = _edits(slime) and ok
	ok = _new_and_delete() and ok
	ok = _titles(slime) and ok
	return ok


## The COLUMNS a data asset opens with: one per exported field, in declaration order, under the
## header a designer reads. Godot's own Resource bookkeeping is not data and is not a column.
static func _columns(path: String) -> bool:
	var ok: bool = true
	var columns: Array = EventSheetDataTable.columns_at(path)
	var names: PackedStringArray = PackedStringArray()
	var words: PackedStringArray = PackedStringArray()
	for entry: Variant in columns:
		names.append(str((entry as Dictionary).get("name", "")))
		words.append(str((entry as Dictionary).get("words", "")))
	ok = _check("the columns are the exported fields, in order", ",".join(names),
		"hp,speed,drops") and ok
	ok = _check("each column's header is the field a designer reads", ",".join(words),
		"Hp,Speed,Drops") and ok
	ok = _check("resource_name is not a column", names.has("resource_name"), false) and ok
	return ok


## ONE asset as a row of values, named the way a reader calls it.
static func _one_asset(path: String) -> bool:
	var ok: bool = true
	var row: Dictionary = EventSheetDataTable.asset_row(path)
	ok = _check("the row is named after the file, not the path", str(row.get("name", "")), "slime") and ok
	var values: Dictionary = row.get("values", {})
	ok = _check("the row carries the value on disk", int(values.get("hp", 0)), 8) and ok
	ok = _check("the row carries the fraction on disk", float(values.get("speed", 0.0)), 90.0) and ok
	ok = _check("a .tres of a scripted Resource is a data asset",
		EventSheetDataTable.is_data_asset(path), true) and ok
	ok = _check("the type is named the way the head bar says it",
		EventSheetDataTable.type_words(path), "Event Forge Data Table Test Type") and ok
	return ok


## A FOLDER of one type as one grid: the shared columns once, a row per asset.
static func _grid() -> bool:
	var ok: bool = true
	ok = _check("a folder of one type opens as a grid",
		EventSheetDataTable.is_one_type_folder(FOLDER), true) and ok
	var grid: Dictionary = EventSheetDataTable.folder_grid(FOLDER)
	ok = _check("the grid names the type its rows share", str(grid.get("type", "")),
		"EventForgeDataTableTestType") and ok
	ok = _check("the grid has one row per asset", (grid.get("rows", []) as Array).size(), 2) and ok
	ok = _check("the grid has one column per field", (grid.get("columns", []) as Array).size(), 3) and ok
	return ok


## THE PROMISE. Reading the table and writing every field back with the value it already holds must
## not touch the file - not one byte, not one line ending.
static func _byte_stable(path: String) -> bool:
	var ok: bool = true
	var before: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var row: Dictionary = EventSheetDataTable.asset_row(path)
	var values: Dictionary = row.get("values", {})
	var wrote: bool = false
	for field: String in values:
		var result: Dictionary = EventSheetDataTable.write_field(path, field, values[field])
		if bool(result.get("changed", false)):
			wrote = true
	ok = _check("a save with nothing edited writes nothing", wrote, false) and ok
	ok = _check("a save with nothing edited leaves every byte in place",
		FileAccess.get_file_as_bytes(path) == before, true) and ok
	return ok


## An edit goes to disk through ResourceSaver, and a field nobody declared is refused rather than
## silently added.
static func _edits(path: String) -> bool:
	var ok: bool = true
	var changed: Dictionary = EventSheetDataTable.write_field(path, "hp", 12)
	ok = _check("an edited field is written", bool(changed.get("changed", false)), true) and ok
	ok = _check("the edit is on disk",
		int((EventSheetDataTable.asset_row(path).get("values", {}) as Dictionary).get("hp", 0)), 12) and ok
	# A whole number typed where a fraction lives is the same value, not a change: a table that
	# rewrote the file every time a designer tabbed through it would be no better than no table.
	var same: Dictionary = EventSheetDataTable.write_field(path, "speed", 90)
	ok = _check("90 written where 90.0 lives is not a change",
		bool(same.get("changed", false)), false) and ok
	var unknown: Dictionary = EventSheetDataTable.write_field(path, "nonesuch", 1)
	ok = _check("a field the type does not have is refused",
		bool(unknown.get("ok", false)), false) and ok
	EventSheetDataTable.write_field(path, "hp", 8)
	return ok


## A new row is a new asset beside the others; a deleted row is a deleted file, behind a confirm
## that names it.
static func _new_and_delete() -> bool:
	var ok: bool = true
	var made: Dictionary = EventSheetDataTable.new_asset(FOLDER, "EventForgeDataTableTestType", "ghost")
	ok = _check("a new row writes a new asset", bool(made.get("ok", false)), true) and ok
	var path: String = str(made.get("path", ""))
	ok = _check("the new asset is in the folder's grid",
		EventSheetDataTable.folder_assets(FOLDER).has(path), true) and ok
	ok = _check("the confirm names the file being deleted",
		EventSheetDataTable.delete_confirm_text(path).contains("ghost.tres"), true) and ok
	ok = _check("deleting a row removes the file",
		bool(EventSheetDataTable.delete_asset(path).get("ok", false)), true) and ok
	ok = _check("the deleted asset is gone from the grid",
		EventSheetDataTable.folder_assets(FOLDER).has(path), false) and ok
	return ok


## What the tab and the FileSystem entry say about a table.
static func _titles(path: String) -> bool:
	var ok: bool = true
	ok = _check("an asset's tab is named after the asset",
		EventSheetDataTable.tab_title(path), "slime.tres") and ok
	ok = _check("a folder's tab is named after the folder",
		EventSheetDataTable.tab_title(FOLDER), "eventforge_data_table") and ok
	ok = _check("Open as Event Sheet offers a data asset",
		EventSheetWorkflow.is_openable_as_sheet(path), true) and ok
	ok = _check("Open as Event Sheet offers a folder of one type",
		EventSheetWorkflow.is_openable_as_sheet(FOLDER), true) and ok
	ok = _check("Open as Event Sheet still refuses a plain file",
		EventSheetWorkflow.is_openable_as_sheet("res://not_a_sheet.txt"), false) and ok
	return ok


static func _make_folder() -> void:
	DirAccess.make_dir_recursive_absolute(FOLDER)


## The Resource script the test's assets are made of, written to disk and loaded from there: the
## script behind a .tres has to BE a file, or the saved asset would point at nothing.
static func _test_type() -> Script:
	var file: FileAccess = FileAccess.open(TYPE_PATH, FileAccess.WRITE)
	if file == null:
		return null
	file.store_string(TYPE_SOURCE)
	file.close()
	var script := GDScript.new()
	script.source_code = TYPE_SOURCE
	script.resource_path = TYPE_PATH
	script.reload()
	return script


static func _write_asset(script: Script, path: String, hp: int, speed: float,
		drops: PackedStringArray) -> void:
	var made: Variant = script.new()
	if not (made is Resource):
		return
	var resource: Resource = made
	resource.set("hp", hp)
	resource.set("speed", speed)
	var list: Array[String] = []
	for entry: String in drops:
		list.append(entry)
	resource.set("drops", list)
	ResourceSaver.save(resource, path)


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] data_table_sheet_test: %s" % label)
		return true
	print("[FAIL] data_table_sheet_test: %s - expected %s, got %s" % [label, expected, actual])
	return false
