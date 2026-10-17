# Godot EventSheets - what the first EDITS do to a script the plugin never wrote.
#
# existing_project_round_trip_test asks that an untouched hand-written file saves back byte for
# byte. This asks the next question: once such a file is open, does the reading it was given hold up
# when somebody changes it?
#   - A declaration whose value runs over several lines (`var waves = [` ... `]`) must not read as a
#     variable whose value is `[` with the rest stranded in code blocks after it - moving or editing
#     that row would write a file that no longer parses.
#   - Change Type Everywhere on a declaration written with no type (`var target = null`) or with an
#     inferred one (`var slot := 0`) must write the type it was asked for, or the file still says what
#     it said and reopens as the old type.
#   - OK on the variable window of an untyped line, changing nothing, must leave the line as it was:
#     `@export var tint = Color.WHITE` opened as Any type, and OK wrote it back as
#     `@export var tint: Variant = "Color.WHITE"` - a String where the file had a Color.
#   - Reading what a sheet compiles to (a preview, a line lookup) writes nothing.
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const TEST_NAME := "existing_project_edits_test"
const OUT_PATH := "user://existing_project_edits_test.gd"


static func run() -> bool:
	var rows: Array = []
	var multi_line: String = "extends Node\n\nvar waves = [\n\t3,\n\t5,\n]\nvar limits: Array = [\n\t1,\n]\nvar total = max(\n\t1, 2)\nvar after = 1\n"
	var sheet: EventSheetResource = _open(multi_line)
	rows.append(["a value that runs over lines is not read as a variable holding its first line",
		_variable_defaults(sheet), {"after": 1}])
	rows.append(["the multi-line declarations still save back byte for byte", _compile(sheet), multi_line])

	var untyped: String = "extends Node\n\nvar target = null\nvar label = \"spawner\"\nvar slot := 0\nvar radius = 240.0\n"
	var retyped: EventSheetResource = _open(untyped)
	for change: Array in [["target", "Node2D"], ["label", "StringName"], ["slot", "float"], ["radius", "int"]]:
		EventSheetVariableRetype.apply(retyped, str(change[0]), str(change[1]))
	var written: String = _compile(retyped)
	rows.append(["a retyped untyped or inferred declaration writes the new type", Array(written.split("\n")).slice(2, 6),
		["var target: Node2D = null", "var label: StringName = \"spawner\"", "var slot: float = 0.0", "var radius: int = 240"]])
	rows.append(["and reopens as the type it was given", _variable_types(_open(written)),
		{"target": "Node2D", "label": "StringName", "slot": "float", "radius": "int"}])

	# Reading what a sheet compiles to writes nothing. A compile with no output path writes the opened
	# file itself, or res://event_sheet_generated.gd for a sheet with no file - so a preview, a line
	# lookup or a type check that compiled that way saved the open tab's unsaved edits over the
	# person's file, or left a stray script declaring the class about to be inserted.
	var stray: String = "res://event_sheet_generated.gd"
	var stray_was_there: bool = FileAccess.file_exists(stray)
	var head: String = load("res://addons/eventsheet/editor/dock/insert_object_dialog.gd").file_head("CharacterBody2D", "Hero", false)
	var global_source: String = EventSheetBehaviourAddonScaffold.source_of(EventSheetBehaviourAddonScaffold.global_sheet("Keeps the score."))
	rows.append(["the Insert and New global previews leave no script behind", [head.begins_with("class_name Hero\n"),
		global_source.contains("extends Node"), FileAccess.file_exists(stray)], [true, true, stray_was_there]])
	var on_disk: String = "extends Node\n\nvar hp: int = 1\n"
	var disk_file: FileAccess = FileAccess.open(OUT_PATH, FileAccess.WRITE)
	disk_file.store_string(on_disk)
	disk_file.close()
	var edited: EventSheetResource = _open(on_disk)
	(edited.events[1] as LocalVariable).default_value = 5
	var row: Resource = edited.events[1]
	var references: Array = [{"row": row}]
	EventSheetFindReferences.stamp_source_lines(edited, references)
	rows.append(["finding where a row is leaves the file on disk as it was", [FileAccess.get_file_as_string(OUT_PATH),
		str(SheetCompiler.echo(edited).get("output", "")).contains("var hp: int = 5")], [on_disk, true]])
	DirAccess.remove_absolute(OUT_PATH)
	var hand_written: String = "\n".join(PackedStringArray(["extends Node", "",
		"@export var tint = Color.WHITE", "var rng = RandomNumberGenerator.new()", "@export var damage = 3",
		"var target = null", "var big = 1e3", "var half = .5", "@export var where = Vector2(1, 2)",
		"var delay: float = 1.5 # seconds", "@export_range(0, 100) var chance = 50",
		"@export_range(0, 1, 0.01, \"exp\", \"hide_slider\") var smoothing: float = 0.2",
		"@export_multiline var credits = \"\"", "const SAVE_FILE := \"user://save.cfg\"", ""]))
	rows.append(["OK on the variable window of every row, changing nothing, leaves the file as it was",
		_after_window_ok(hand_written), hand_written])
	return SUPPORT.pins(TEST_NAME, rows)


## Opens every variable row in the variable window the way its menu's Edit does, presses OK without
## touching anything, and returns the file the sheet then saves.
static func _after_window_ok(source: String) -> String:
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(_open(source))
	# By name, fetched again each time: an edit's commit replaces the rows with copies.
	for row_name: String in _variable_types(dock._current_sheet).keys():
		for entry: Variant in dock._current_sheet.events:
			if entry is LocalVariable and (entry as LocalVariable).name == row_name:
				dock._variables._context_variable = {"scope": "tree", "name": row_name, "resource": entry}
		dock._variables._edit_context_variable()
		dock._variable_dlg._on_confirmed()
	var saved: String = _compile(dock._current_sheet)
	dock.free()
	DirAccess.remove_absolute(OUT_PATH)
	return saved


static func _open(source: String) -> EventSheetResource:
	var sheet: EventSheetResource = GDScriptImporter.new().import_external_source(source, true, OUT_PATH)
	sheet.external_source_path = OUT_PATH
	return sheet


static func _compile(sheet: EventSheetResource) -> String:
	return str(SheetCompiler.compile(sheet, OUT_PATH).get("output", ""))


static func _variable_defaults(sheet: EventSheetResource) -> Dictionary:
	var found: Dictionary = {}
	for entry: Variant in sheet.events:
		if entry is LocalVariable:
			found[(entry as LocalVariable).name] = (entry as LocalVariable).default_value
	return found


static func _variable_types(sheet: EventSheetResource) -> Dictionary:
	var found: Dictionary = {}
	for entry: Variant in sheet.events:
		if entry is LocalVariable:
			found[(entry as LocalVariable).name] = (entry as LocalVariable).type_name
	return found
