# EventForge - a hand-written script opened as a sheet earns a "not a variable" note only for a name
# it really does not declare.
#
# Two ways the note used to fire on a clean file, both met by opening a user's own scripts:
#   - a file with an inner `class` read the class's members as the file's for every row built after
#     the class, so its own `_start_x` and `_dir` were "not a variable of enemy";
#   - a local (`var direction := ...` inside the function) and a function's parameter (`body`) are
#     names the line can use, and the note treated them as missing members.
# And a variable with no written type (`var hits = 3`) is not "any - Subtract from wants a number":
# it holds the number it starts at, so the amber kind note has nothing to say about it.
# The typo control proves the note still fires where it should.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "opened_script_variable_notes_test"

const CLEAN := """extends Area2D

@export var patrol_distance: float = 64.0

var _start_x: float
var _dir := 1.0
var hits = 3


class Patrol:
	var turns: int = 0

	func record_turn() -> void:
		turns += 1


func _ready() -> void:
	_start_x = position.x


func _process(delta: float) -> void:
	var direction := Input.get_axis("ui_left", "ui_right")
	if direction != 0.0:
		_dir = direction


func take(body: Node2D) -> void:
	if body is Sprite2D:
		_dir = body.position.x


func hurt(amount) -> void:
	hits -= amount
"""


static func run() -> bool:
	var typo: String = CLEAN.replace("\t_start_x = position.x", "\t_strat_x = position.x")
	# A local of _process is not a name another function can use: `direction` in spin() is a typo of
	# nothing that function declares, and the note says so instead of being hidden by _process's local.
	var elsewhere: String = CLEAN + "\n\nfunc spin() -> void:\n\tdirection = 2.0\n"
	var declared: Dictionary = {}
	ViewportRowBuilder._collect_code_declared_names(
		"hits = 1  # for example, var nope\nvar real := \"for fake in words\"", declared)
	return SUPPORT.pins(P, [
		["a clean file with a class, a local and a parameter grows no note", _notes(CLEAN, "clean"), []],
		["a name the file does not declare still does", _notes(typo, "typo"),
			["_strat_x is not a variable of opened_script_variable_notes_typo."]],
		["a local of one function does not hide a missing name in another", _notes(elsewhere, "elsewhere"),
			["direction is not a variable of opened_script_variable_notes_elsewhere."]],
		["a comment or a string declares no name in code kept as written", declared.keys(), ["real"]],
	])


## The note rows the canvas hangs under the events of `source`, opened the way the editor opens a file.
static func _notes(source: String, tag: String) -> Array:
	var path: String = "user://opened_script_variable_notes_%s.gd" % tag
	var handle: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	handle.store_string(source)
	handle.close()
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(GDScriptImporter.new().import_external(path))
	var found: Array = []
	_collect(dock._viewport._root_rows, found)
	dock.free()
	return found


static func _collect(rows: Array, into: Array) -> void:
	for row: EventRowData in rows:
		if row.row_uid.contains("variable_note_"):
			var parts: PackedStringArray = PackedStringArray()
			for span: SemanticSpan in row.spans:
				var metadata: Dictionary = span.metadata if span.metadata is Dictionary else {}
				if str(metadata.get("variable_note", "")) != "mark" and not span.text.strip_edges().is_empty():
					parts.append(span.text.strip_edges())
			into.append(" ".join(parts))
		_collect(row.children, into)
