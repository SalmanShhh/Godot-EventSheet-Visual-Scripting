# EventForge - Save As a .tres from a sheet opened from a .gd.
#
# The .gd stays on disk and every scene that uses it keeps running it, while the new .tres writes a
# generated script of its own that nothing uses yet. The status line says so and names the script to
# attach. A save that fails leaves the tab linked to the .gd it came from instead of unlinking it first.
@tool
class_name SaveAsTresFromGdTest
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")
const FOLDER: String = "user://save_as_tres_fixture"
const SOURCE_GD: String = "user://save_as_tres_fixture/mover.gd"
const SOURCE: String = "extends Node2D\n\n\nfunc _ready() -> void:\n\tprint(\"hi\")\n"


static func run() -> bool:
	var ok: bool = true
	DirAccess.make_dir_recursive_absolute(FOLDER)
	var file: FileAccess = FileAccess.open(SOURCE_GD, FileAccess.WRITE)
	file.store_string(SOURCE)
	file.close()
	var dock: EventSheetEditor = EventSheetEditor.new()
	dock._load_sheet_from_path(SOURCE_GD)
	dock._preview_glue._on_preview_edit_requested()

	# A save that fails: the tab is still the .gd's sheet, and the line says which file and why.
	dock._sheet_io._save_sheet_to_path("user://save_as_tres_fixture/no_such_folder/mover_copy.tres")
	ok = _check("a failed save leaves the sheet linked to its .gd", dock._current_sheet.external_source_path, SOURCE_GD) and ok
	ok = _check("and says so in plain words", _said(dock).contains("mover_copy.tres") and _said(dock).contains("still linked to mover.gd"), true) and ok
	ok = _check("and is shown as a problem", dock._status_label.text.begins_with("⚠"), true) and ok

	# A save that works: scenes still run the .gd, and the line names the script that is written for the .tres.
	dock._sheet_io._save_sheet_to_path("user://save_as_tres_fixture/mover_copy.tres")
	ok = _check("the sheet is no longer linked to the .gd", dock._current_sheet.external_source_path, "") and ok
	ok = _check("the line says scenes still run the .gd", _said(dock).contains("Scenes still run mover.gd"), true) and ok
	ok = _check("and names the script to attach instead", _said(dock).contains("mover_copy_generated.gd"), true) and ok
	ok = _check("the .gd was left as it was", FileAccess.get_file_as_string(SOURCE_GD), SOURCE) and ok

	dock.free()
	var dir: DirAccess = DirAccess.open(FOLDER)
	for name: String in dir.get_files():
		DirAccess.remove_absolute(ProjectSettings.globalize_path("%s/%s" % [FOLDER, name]))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FOLDER))
	return ok


## The whole sentence the status line holds (its tooltip carries the text without the warning mark).
static func _said(dock: EventSheetEditor) -> String:
	return dock._status_label.tooltip_text


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("save_as_tres_from_gd_test", label, actual, expected)
