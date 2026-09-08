# Godot EventSheets - the object's variables, as Inspector rows.
#
# The Inspector used to carry a button and a sentence about what was NOT in it; it now carries the
# variables themselves - a band saying how many, then one row per declared variable: the name, the
# type in the sheet's own plain words, the initial value, and a pencil that opens the sheet on the
# line that declares it. This pins what those rows SAY (by value), the line the pencil aims at, the
# fact that a value typed into a row writes the same line the sheet's own table writes and leaves
# every other byte alone, and that building the band for a fifty-variable object is instant.
#
# The type words are spelled twice on purpose: the sheet's reading lives in the row builder, which a
# boot-path file may not name (it carries the whole reading layer with it). The two are held
# together here, by asking both the same table of declarations and comparing the answers.
@tool
class_name InspectorInstanceVariablesTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const PREFIX := "inspector_instance_variables_test"
const DECLARED := preload("res://addons/eventforge/editor/sheet_edit_inspector_plugin.gd")
const BAND := preload("res://addons/eventforge/editor/instance_variables_inspector_plugin.gd")

## The band for a fifty-variable object, built whole (the scan, the words, and every Control the
## Inspector draws), must stay inside this. A selection happens on every click in the Scene dock, so
## the budget is a tenth of a second - measured at about 4 ms on the machine this was written on,
## which leaves the margin a busy editor and a cold file cache need.
const BUILD_BUDGET_MS: float = 100.0


static func run() -> bool:
	var ok: bool = true
	ok = _test_the_rows_a_script_answers_with() and ok
	ok = _test_the_type_words_are_the_sheets_own() and ok
	ok = _test_writing_a_value_touches_one_line() and ok
	ok = _test_building_the_band_is_instant() and ok
	return ok


## ── What the rows say, and where the pencil aims ──────────────────────────────────────────────
##
## Name, type word, initial value and declaration line, for the spellings a real file mixes: a
## declared export, a plain member, an inferred constant, a typed table, a typed list, a property
## with an accessor block, an @onready node reference, and a value with a comment after it.
static func _test_the_rows_a_script_answers_with() -> bool:
	var path: String = "user://inspector_instance_variables_rows.gd"
	var source: String = "extends Node2D\n\n@export var speed: float = 200.0\nvar hp: int = 100\n" \
		+ "const SHADER_DIR := \"res://shaders/\"\nvar mode: String = \"idle\"  # the starting one\n" \
		+ "var _fades: Dictionary = {}\nvar tags: Array[String] = []\n" \
		+ "@onready var body := $Body\nvar armor: int = 3:\n\tget:\n\t\treturn armor\n" \
		+ "const SHELVES: Dictionary = {\n\t\"a\": 1,\n}\n\n" \
		+ "func _ready() -> void:\n\tvar dealt := 0\n\tprint(dealt)\n"
	_write_file(path, source)
	var rows: Array[Dictionary] = DECLARED.member_variables(path)
	var ok: bool = SUPPORT.pins(PREFIX, [
		["the rows are the object's own declarations, in file order", _names(rows),
			"speed, hp, SHADER_DIR, mode, _fades, tags, body, armor, SHELVES"],
		["an exported float reads as a number, at the value the file gives it",
			_row_text(rows, 0), "speed · number · 200.0 · line 3"],
		["a declared int is a whole number", _row_text(rows, 1), "hp · whole number · 100 · line 4"],
		["an inferred constant reads its type off its own value, quotes and all",
			_row_text(rows, 2), "SHADER_DIR · text · \"res://shaders/\" · line 5"],
		["a declared text drops its quotes the way the sheet's own table does, and the comment after it",
			_row_text(rows, 3), "mode · text · idle · line 6"],
		["a table says table, and an empty one shows the braces the file has",
			_row_text(rows, 4), "_fades · table · {} · line 7"],
		["a typed list says what it holds", _row_text(rows, 5), "tags · list of text · [] · line 8"],
		["an @onready node reference is a declaration like any other, and a node path settles no type",
			_row_text(rows, 6), "body · any · $Body · line 9"],
		["a property with an accessor block keeps its type and its value",
			_row_text(rows, 7), "armor · whole number · 3 · line 10"],
		["a table written across several lines shows the fragment its line holds",
			_row_text(rows, 8), "SHELVES · table · { · line 13"],
		["the band counts what it is about to draw", BAND.header_text(rows.size()),
			"Instance variables · 9"],
	])
	ok = SUPPORT.pin_value(PREFIX, "an @export is still the fact that puts one in the Inspector's own list",
		bool(rows[0].get("exported", false)), true) and ok
	ok = SUPPORT.pin_value(PREFIX, "a plain member is not",
		bool(rows[1].get("exported", true)), false) and ok
	ok = SUPPORT.pin_value(PREFIX, "a const says it is one",
		bool(rows[2].get("constant", false)), true) and ok
	ok = SUPPORT.pin_value(PREFIX, "and a var says it is not",
		bool(rows[3].get("constant", true)), false) and ok
	# The pencil hands the SCRIPT's own line number to the same door a stack trace uses, so the row
	# it lands on is the row that line became.
	ok = SUPPORT.pin_value(PREFIX, "the pencil aims at the line the declaration sits on",
		int(rows[3].get("line", 0)), 6) and ok
	ok = SUPPORT.pin_value(PREFIX, "a value that ends on its own line may be typed into",
		bool(rows[3].get("complete", false)), true) and ok
	ok = SUPPORT.pin_value(PREFIX, "one that runs on past it may not",
		bool(rows[8].get("complete", true)), false) and ok
	ok = SUPPORT.pin_value(PREFIX, "a file with no declarations answers with no rows",
		DECLARED.member_variables("user://inspector_instance_variables_missing.gd").size(), 0) and ok
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return ok


## ── The words are the sheet's words ───────────────────────────────────────────────────────────
##
## Every declaration shape the band can meet, asked of the band and of the row builder's own
## reading. A word that moves in one and not the other is a red suite, not a drift nobody sees.
static func _test_the_type_words_are_the_sheets_own() -> bool:
	var ok: bool = true
	var declarations: Array = [
		["float", "200.0"], ["int", "100"], ["bool", "true"], ["String", "\"idle\""],
		["StringName", "&\"idle\""], ["Vector2", "Vector2.ZERO"], ["Color", "Color.RED"],
		["Dictionary", "{}"], ["Array", "[]"], ["Array[String]", "[]"], ["Array[int]", "[]"],
		["PackedStringArray", "PackedStringArray()"], ["PackedVector2Array", ""],
		["PackedColorArray", ""], ["Callable", ""], ["Signal", ""], ["PackedScene", "null"],
		["Node2D", "null"], ["Sprite2D", "null"], ["StatSheet", "null"], ["Variant", ""],
		["", "\"idle\""], ["", "100"], ["", "12.5"], ["", "true"], ["", "false"], ["", "[]"],
		["", "{}"], ["", "Color.RED"], ["", "Vector2(1, 2)"], ["", "$Body"], ["", ""],
	]
	for declaration: Array in declarations:
		var declared: String = str(declaration[0])
		var value: String = str(declaration[1])
		ok = SUPPORT.pin_value(PREFIX, "`var x%s%s` reads the same word in the Inspector as on a row" % [
			"" if declared.is_empty() else ": %s" % declared,
			"" if value.is_empty() else " = %s" % value],
			BAND.type_word(declared, value),
			ViewportRowBuilder._reading_type_word(declared, value, true)) and ok
	return ok


## ── Writing a value from a row ────────────────────────────────────────────────────────────────
##
## The row's value goes to the sheet, through the undo funnel its own variables table writes
## through. So the covenant is the sharper one an edit gets: the line the value lives on changes,
## and every other byte of the file is what it was.
static func _test_writing_a_value_touches_one_line() -> bool:
	var path: String = "user://inspector_instance_variables_write.gd"
	var source: String = "extends Node2D\n\n\nvar speed: float = 200.0\nvar mode := \"idle\"\n\n\n" \
		+ "func _ready() -> void:\n\tprint(speed)\n"
	_write_file(path, source)
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(EventSheetResource.new())
	dock._load_sheet_from_path(path)
	var ok: bool = SUPPORT.pin_value(PREFIX, "the untouched file compiles back byte for byte",
		_compile(dock), source)
	dock.set_instance_variable_value("speed", "320.0")
	var after: String = _compile(dock)
	ok = SUPPORT.pin_value(PREFIX, "writing a value changes exactly the line that declares it",
		_one_line_diff(source, after), "var speed: float = 200.0 -> var speed: float = 320.0") and ok
	# The inferred spelling keeps its own bytes: `var mode := "idle"` emits its default as SOURCE
	# TEXT, so a value typed into the row is written verbatim and the `:=` line stays a `:=` line.
	dock.set_instance_variable_value("mode", "\"walking\"")
	ok = SUPPORT.pin_value(PREFIX, "an inferred declaration is rewritten in its own spelling",
		_one_line_diff(after, _compile(dock)),
		"var mode := \"idle\" -> var mode := \"walking\"") and ok
	ok = SUPPORT.pin_value(PREFIX, "a name the file does not declare writes nothing",
		_compile(dock) == _write_nothing(dock, "no_such_variable"), true) and ok
	dock.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return ok


## ── Instant ───────────────────────────────────────────────────────────────────────────────────
##
## The band is built on every Inspector refresh, so it is measured whole - the scan, the words and
## the Controls - for an object with fifty variables, which is more than any sheet in this repo.
static func _test_building_the_band_is_instant() -> bool:
	var path: String = "user://inspector_instance_variables_fifty.gd"
	var lines: PackedStringArray = PackedStringArray(["extends Node2D", ""])
	for index: int in range(50):
		lines.append("@export var knob_%d: float = %d.0" % [index, index])
	_write_file(path, "\n".join(lines) + "\n")
	# The BAND ITSELF is built, not a stand-in for it: a measurement of something else could stay
	# fast while the thing the Inspector draws got slow. Its three doors are left empty - a preview
	# of the band presses none of them.
	var started: int = Time.get_ticks_usec()
	var control: Control = BAND.build_category(path, path, Callable(), Callable(), Callable())
	var elapsed_ms: float = float(Time.get_ticks_usec() - started) / 1000.0
	var ok: bool = SUPPORT.pin_value(PREFIX, "the band draws every one of the fifty",
		BAND.header_text(DECLARED.member_variables(path).size()), "Instance variables · 50")
	ok = SUPPORT.pin_value(PREFIX, "building it for fifty variables stays under %.0f ms" % BUILD_BUDGET_MS,
		elapsed_ms < BUILD_BUDGET_MS, true) and ok
	if elapsed_ms >= BUILD_BUDGET_MS:
		print("[%s] the band took %.1f ms" % [PREFIX, elapsed_ms])
	control.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return ok


## One row as one line: `speed · number · 200.0 · line 3`. Out-of-range says so rather than
## crashing the table it is a cell of.
static func _row_text(rows: Array[Dictionary], index: int) -> String:
	if index < 0 or index >= rows.size():
		return "<no row %d>" % index
	var row: Dictionary = rows[index]
	return "%s · %s · %s · line %d" % [
		str(row.get("name", "")),
		BAND.type_word(str(row.get("type_name", "")), str(row.get("value", ""))),
		str(row.get("value", "")),
		int(row.get("line", 0))]


static func _names(rows: Array[Dictionary]) -> String:
	var names: PackedStringArray = PackedStringArray()
	for row: Dictionary in rows:
		names.append(str(row.get("name", "")))
	return ", ".join(names)


## The one line that changed, as `before -> after`, or a sentence saying why that is not what
## happened - so a failure prints what the file did instead of a bare false.
static func _one_line_diff(before: String, after: String) -> String:
	var old_lines: PackedStringArray = before.split("\n")
	var new_lines: PackedStringArray = after.split("\n")
	if old_lines.size() != new_lines.size():
		return "the file gained or lost lines (%d -> %d)" % [old_lines.size(), new_lines.size()]
	var changed: PackedStringArray = PackedStringArray()
	for index: int in range(old_lines.size()):
		if old_lines[index] != new_lines[index]:
			changed.append("%s -> %s" % [old_lines[index], new_lines[index]])
	if changed.is_empty():
		return "nothing changed"
	return " and ".join(changed)


## Writing to a name the sheet does not declare, and what the file says afterwards.
static func _write_nothing(dock: EventSheetDock, variable_name: String) -> String:
	dock.set_instance_variable_value(variable_name, "1")
	return _compile(dock)


## Compiled to a THROWAWAY path: the compiler writes its output to the path it is given, and the
## text it returns is what these pins are about.
static func _compile(dock: EventSheetDock) -> String:
	return SUPPORT.compile_output(dock.get_current_sheet(), "user://inspector_instance_variables_out.gd")


static func _write_file(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
