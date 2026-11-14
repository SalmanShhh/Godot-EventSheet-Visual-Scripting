# EventForge - renaming an exported variable carries the values scenes stored for it.
#
# The rename is one undo step that reaches the scene files too: the property name moves on the lines of
# nodes wearing this script, the value text stays byte for byte, and Ctrl+Z puts every file back. A
# variable nothing stores a value for renames exactly as before, and a delete only asks.
@tool
class_name RenameSceneValuesTest
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")
const READER_PATH: String = "res://addons/eventsheet/editor/dock/scene_values.gd"
const FOLDER: String = "user://rename_scene_values_fixture"
const SCRIPT: String = "user://rename_scene_values_fixture/mover.gd"
const LEVEL: String = "user://rename_scene_values_fixture/level.tscn"
const SOURCE: String = "extends Node2D\n\n\n@export var speed: float = 1.0\n\n\nfunc _ready() -> void:\n\tprint(speed)\n"


static func run() -> bool:
	var ok: bool = true
	DirAccess.make_dir_recursive_absolute(FOLDER)
	_write(SCRIPT, SOURCE)
	var level: String = "[gd_scene load_steps=2 format=3]\n\n[ext_resource type=\"Script\" path=\"%s\" id=\"1_mv\"]\n\n[node name=\"Level\" type=\"Node2D\"]\n" % SCRIPT
	for index: int in range(1, 11):
		level += "\n[node name=\"Enemy%d\" type=\"Node2D\" parent=\".\"]\nscript = ExtResource(\"1_mv\")\nspeed = %s\n" % [index, str(index * 25.5)]
	_write(LEVEL, level)
	var reader: GDScript = load(READER_PATH)
	reader.roots = PackedStringArray([FOLDER])

	var dock: EventSheetEditor = EventSheetEditor.new()
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock._load_sheet_from_path(SCRIPT)
	dock._preview_glue._on_preview_edit_requested()
	ok = _check("the variable is an exported one", reader.is_exported_variable(dock._current_sheet, "speed"), true) and ok
	var stored: Dictionary = reader.stored_for(dock, "speed", "")
	ok = _check("the window lists the scene that stores ten values", stored["counts"].get(LEVEL, 0), 10) and ok

	ok = _check("the rename goes through", dock._rename.rename_everywhere("speed", "move_speed"), true) and ok
	var after: String = FileAccess.get_file_as_string(LEVEL)
	ok = _check("all ten values moved to the new name", after.count("\nmove_speed = "), 10) and ok
	ok = _check("none was left under the old name", after.count("\nspeed = "), 0) and ok
	ok = _check("every value is the text it was", after.replace("move_speed = ", "speed = "), level) and ok
	ok = _check("the script on disk says the new name", FileAccess.get_file_as_string(SCRIPT).contains("var move_speed: float = 1.0"), true) and ok
	ok = _check("the line under the sheet says what it did", dock._status_label.text.contains("10 value(s) in 1 scene(s) kept under the new name"), true) and ok

	# One Ctrl+Z puts the sheet and the scene back, byte for byte.
	dock._on_undo_requested()
	ok = _check("undo puts the scene back byte for byte", FileAccess.get_file_as_string(LEVEL), level) and ok
	ok = _check("undo puts the script back", FileAccess.get_file_as_string(SCRIPT).contains("var speed: float = 1.0"), true) and ok
	# And Ctrl+Shift+Z does it again.
	dock._on_redo_requested()
	ok = _check("redo renames the scene's values again", FileAccess.get_file_as_string(LEVEL).count("\nmove_speed = "), 10) and ok

	# A variable no scene stores a value for renames as it always did, and writes no scene.
	dock._on_undo_requested()
	_write(LEVEL, level.replace("speed = ", "other_value = "))
	var untouched: String = FileAccess.get_file_as_string(LEVEL)
	ok = _check("a rename nothing stores a value for goes through", dock._rename.rename_everywhere("speed", "move_speed"), true) and ok
	ok = _check("and writes no scene", FileAccess.get_file_as_string(LEVEL), untouched) and ok

	# The window after a rename that also saved another sheet tells the reader where the way back is, in
	# the editor's own words, and does not assume they use version control.
	var receipt: ConfirmationDialog = dock._rename.show_receipt("speed", "move_speed", 1, PackedStringArray(["other.tres"]))
	var note: Label = receipt.find_child("Note", true, false) as Label
	ok = _check("the note names Sheet Backups", note != null and note.text.contains("Tools > Sheet Backups"), true) and ok
	ok = _check("and does not send the reader to version control", note != null and note.text.contains("version control"), false) and ok
	receipt.queue_free()

	dock.free()
	reader.roots = PackedStringArray(["res://"])
	for name: String in ["mover.gd", "mover.gd.uid", "level.tscn"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("%s/%s" % [FOLDER, name]))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FOLDER))
	return ok


static func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("rename_scene_values_test", label, actual, expected)
