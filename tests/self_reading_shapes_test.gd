# EventForge - the shapes the editor's own source is written in, opened as rows.
#
# The plugin is asked to open its own code as sheets, and its code leans on a few shapes a game's
# script rarely does: a table of dictionaries at file scope, a doc comment of two paragraphs, a file
# that ends with a blank line under its last function. Each one here is a small file in that shape,
# opened the way the dock opens it: what rows it becomes, and that saving it untouched gives the same
# bytes back.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const NAME := "self_reading_shapes_test"
const VERIFY_PATH := "user://self_reading_shapes_test.gd"


static func run() -> bool:
	var passed: bool = true
	passed = _test_a_folded_literal_is_one_row() and passed
	passed = _test_a_trailing_blank_line_is_layout() and passed
	passed = _test_a_doc_comment_under_a_table() and passed
	passed = _test_a_doc_line_left_as_text_keeps_its_gap() and passed
	passed = _test_a_table_of_dictionaries_is_one_declaration() and passed
	return passed


## A TABLE HANDED TO A STATEMENT, written with a nested value, stays one verbatim row per line, and
## the canvas draws the run as ONE row: the statement's own sentence, with the entries as chips. The
## wordless measure counts what is drawn, so that is one row with words - not a head, an entry, a
## nested entry and closing brackets, five rows that say nothing.
static func _test_a_folded_literal_is_one_row() -> bool:
	var source: String = "extends RefCounted\n\n\nfunc snapshot() -> Dictionary:\n" \
		+ "\treturn {\n" \
		+ "\t\t\"stats\": {\n" \
		+ "\t\t\t\"hp\": 10,\n" \
		+ "\t\t},\n" \
		+ "\t}\n"
	var sheet: EventSheetResource = SUPPORT.reopen(source, true, VERIFY_PATH)
	return SUPPORT.pins(NAME, [
		["the table's lines are no rows of their own, and none of them says nothing",
			EventSheetGenericRows.measure(sheet), {"generic": 0, "rows": 4, "percent": 0}],
		["and the file comes back byte for byte", SUPPORT.reemit(source, VERIFY_PATH), source],
	])


## A FILE THAT ENDS WITH A BLANK LINE under its last function still opens as rows. The blank is
## layout, so it is counted rather than kept, and written back on save.
static func _test_a_trailing_blank_line_is_layout() -> bool:
	var source: String = "extends RefCounted\n\n\nfunc first() -> int:\n\treturn 1\n\n\n" \
		+ "func last(amount: int) -> void:\n\tprint(amount)\n\n"
	var two_blanks: String = source + "\n"
	return SUPPORT.pins(NAME, [
		["its functions open as functions", _function_names(SUPPORT.reopen(source, true, VERIFY_PATH)),
			PackedStringArray(["first", "last"])],
		["and the file comes back byte for byte", SUPPORT.reemit(source, VERIFY_PATH), source],
		["two blank lines at the end open the same way", _function_names(
			SUPPORT.reopen(two_blanks, true, VERIFY_PATH)), PackedStringArray(["first", "last"])],
		["and come back as two", SUPPORT.reemit(two_blanks, VERIFY_PATH), two_blanks],
	])


## A DOC COMMENT UNDER A TABLE. A top-level table the import reads as entries is a structured row,
## so the blank lines under it arrive as a row of their own rather than glued to text - and the gap
## is that row and the doc's own leading blanks together. A doc of two paragraphs, a bare `##`
## between them, is one doc. Each shape used to send the whole file back to code.
static func _test_a_doc_comment_under_a_table() -> bool:
	var table: String = "extends RefCounted\n\nconst OPENERS: Array[String] = [\n\t\"if \", \"elif \",\n" \
		+ "\t\"pass\", \"break\"\n]\n\n\n"
	var tail: String = "static func code_text(text: String) -> String:\n\treturn text\n\n\n" \
		+ "## Last one.\nstatic func other() -> int:\n\treturn 1\n"
	var one_paragraph: String = table + "## The code a comment's text is.\n" + tail
	var two_paragraphs: String = table + "## The code a comment's text is.\n##\n## A second paragraph.\n" + tail
	return SUPPORT.pins(NAME, [
		["a one-paragraph doc under a table: the functions open",
			_function_names(SUPPORT.reopen(one_paragraph, true, VERIFY_PATH)),
			PackedStringArray(["code_text", "other"])],
		["and come back byte for byte", SUPPORT.reemit(one_paragraph, VERIFY_PATH), one_paragraph],
		["a two-paragraph doc under a table: the functions open",
			_function_names(SUPPORT.reopen(two_paragraphs, true, VERIFY_PATH)),
			PackedStringArray(["code_text", "other"])],
		["and come back byte for byte", SUPPORT.reemit(two_paragraphs, VERIFY_PATH), two_paragraphs],
	])


## A DOC LINE THAT CANNOT RIDE ON ITS FUNCTION - `## @ace_category Combat`, written without the
## brackets the annotation takes - stays where it is as text, and the functions under it still open.
## The gap above that line is its own, so it is not written a second time under it.
static func _test_a_doc_line_left_as_text_keeps_its_gap() -> bool:
	var source: String = "extends CharacterBody2D\n\n@export var health: int = 100\n\n\n" \
		+ "## @ace_category Combat\nfunc heal(amount: int) -> void:\n\thealth += amount\n\n\n" \
		+ "func is_dead() -> bool:\n\treturn health <= 0\n"
	return SUPPORT.pins(NAME, [
		["the functions under it open", _function_names(SUPPORT.reopen(source, true, VERIFY_PATH)),
			PackedStringArray(["heal", "is_dead"])],
		["and the file comes back byte for byte", SUPPORT.reemit(source, VERIFY_PATH), source],
	])


## A FILE-SCOPE TABLE OF DICTIONARIES, each written one key per line, is one Declare row with one
## entry per dictionary. The entry keeps its lines in the file and shows on one line on the canvas.
## A literal handed to an expression is not a declaration of it, so that one stays as written.
static func _test_a_table_of_dictionaries_is_one_declaration() -> bool:
	var source: String = "extends RefCounted\n\nconst WORDS: Array[Dictionary] = [\n" \
		+ "\t{\n\t\t\"word\": \"glow\",\n\t\t\"spellings\": {\"glow_enabled\": \"Glow\"}\n\t},\n" \
		+ "\t{\"word\": \"fog\"},\n]\n\n" \
		+ "const LINES: String = \"%s and %s\" % [\n\tfunc_a(\n\t\t1),\n\tB,\n]\n"
	var sheet: EventSheetResource = SUPPORT.reopen(source, true, VERIFY_PATH)
	var declared: Array = []
	var shown: PackedStringArray = PackedStringArray()
	for row: Variant in (sheet.events if sheet != null else []):
		if row is CollectionDeclRow:
			var decl: CollectionDeclRow = row as CollectionDeclRow
			declared.append(decl.variable_name())
			for entry_index: int in decl.entry_values.size():
				shown.append(decl.entry_value_on_one_line(entry_index))
	return SUPPORT.pins(NAME, [
		["the table is a declaration, and the expression is not", declared, ["WORDS"]],
		["one entry per dictionary, each on one line", shown, PackedStringArray([
			"{ \"word\": \"glow\", \"spellings\": {\"glow_enabled\": \"Glow\"} }", "{\"word\": \"fog\"}"])],
		["and the file comes back byte for byte", SUPPORT.reemit(source, VERIFY_PATH), source],
	])


## The names of the functions a sheet opened with, in order.
static func _function_names(sheet: EventSheetResource) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	if sheet == null:
		return names
	for function_entry: Variant in sheet.functions:
		if function_entry is EventFunction:
			names.append((function_entry as EventFunction).function_name)
	return names
