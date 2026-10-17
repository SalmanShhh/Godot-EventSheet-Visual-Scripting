# EventForge - the shapes the plugin's OWN code is written in, opened as rows.
#
# The editor's source is the hardest hand-written GDScript the reader meets: tables handed to
# `return` and to calls, long expressions continued over lines, engine callbacks written the way the
# engine's own docs write them. Each section below is one of those shapes, pinned two ways - what the
# row IS once the file is open, and that the file still comes back byte for byte, because a reading
# that moves a byte is not a reading.
@tool
class_name OwnCodeShapesTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const LINES := preload("res://tools/reading_lines.gd")

## Tables and lists handed on by a statement rather than declared: the four heads the editor's own
## source writes most, a list of records, and two that must stay per-line (a nested value, and lines
## that only look like a table because they sit inside a long string).
const HANDED_ON_SOURCE := """extends Node

var sources: Array = []
var connections: Dictionary = {}


func snapshot(path: String) -> Dictionary:
	return {
		"path": path,
		"kind": "scene",
	}


func remember(path: String, handler: String) -> void:
	sources.append({
		"path": path,
		"trees": 2,
	})
	connections[handler] = {
		"path": path,
		"once": true
	}
	print_rich(path, [
		"first",
		"second",
	])


func records() -> Array:
	return [
		{"name": "calm", "count": 3},
		{"name": "busy", "count": 8},
	]


func nested() -> Dictionary:
	return {
		"outer": {
			"inner": 1,
		},
	}


func shader_text() -> String:
	var text: String = \"\"\"
	shade({
		alpha: 1,
	})
	\"\"\"
	return text
"""


static func run() -> bool:
	var ok: bool = true
	ok = _test_handed_on_literals() and ok
	return ok


## A literal handed on by a statement is ONE structured row, reads as the statement with its entries
## as chips, edits one entry at a time, and the file still comes back byte for byte.
static func _test_handed_on_literals() -> bool:
	var ok: bool = true
	var sheet: EventSheetResource = SUPPORT.reopen(HANDED_ON_SOURCE)
	sheet.external_source_path = "user://own_code_shapes_handed_on.gd"
	ok = _check("a file of handed-on literals reproduces byte-identically",
		SUPPORT.compile_output(sheet, "user://own_code_shapes_handed_on.gd"), HANDED_ON_SOURCE) and ok
	var heads: Array = []
	for decl: CollectionDeclRow in _decls(sheet):
		heads.append([decl.head, decl.close, decl.is_statement(), decl.entry_values.size()])
	ok = _check("every canonical handed-on literal is one structured row", heads, [
		["return {", "}", true, 2],
		["sources.append({", "})", true, 2],
		["connections[handler] = {", "}", true, 2],
		["print_rich(path, [", "])", true, 2],
		["return [", "]", true, 2],
	]) and ok
	var remember: EventRow = _event_of(sheet, "remember")
	ok = _check("the statements around a literal stay rows of their own",
		remember.actions.size() if remember != null else -1, 3) and ok
	# The reading is the statement with a hole where the literal sat - the same one the run of lines
	# used to draw - and the record list keeps one entry per record.
	var appended: CollectionDeclRow = _decls(sheet)[1]
	ok = _check("a literal passed to a call reads as the call around it",
		str(EventSheetValueLiteralRows.of_statement(appended).get("statement", "")), "sources.append(⟦⟧)") and ok
	var record_list: CollectionDeclRow = _decls(sheet)[4]
	ok = _check("a list of records keeps one entry per record", Array(record_list.entry_values),
		["{\"name\": \"calm\", \"count\": 3}", "{\"name\": \"busy\", \"count\": 8}"]) and ok
	ok = _check("a nested value is not claimed, and stays the lines it was",
		_raw_codes(_event_of(sheet, "nested")), ["return {", "\t\"outer\": {", "\t\t\"inner\": 1,", "\t},", "}"]) and ok
	ok = _check("lines inside a long string are never a table",
		_decls_in(_event_of(sheet, "shader_text")).size(), 0) and ok
	# The canvas draws each as one row - the statement and its chips - in exactly the words the run of
	# lines a structured row replaced drew (the nested table and the string still are such runs).
	var cells: Array = []
	for reading: Variant in LINES.readings_of_sheet(SUPPORT.reopen(HANDED_ON_SOURCE), "own"):
		var text: String = " | ".join(reading.plain)
		if reading.lane == "action" and (text.contains(" | table | ") or text.contains(" | list | ")):
			cells.append(text)
	ok = _check("the canvas reads each literal as one row, structured or not", cells, [
		"Return  | table | path = path | kind = \"scene\"",
		"Push back  | table | path = path | trees = 2 |  to sources",
		"Set connections[handler] to  | table | path = path | once = true",
		"print rich   path    | list | \"first\" | \"second\"",
		"Return  | list | {\"name\": \"calm\", \"count\": 3} | {\"name\": \"busy\", \"count\": 8}",
		"Return  | table | outer = table (inner = 1)",
		"shade    | table | alpha = 1",
	]) and ok
	var event_index: int = remember.actions.find(appended) if remember != null else -1
	ok = _check("a chip edit rewrites its one entry", EventSheetViewport._apply_decl_entry_edit(remember,
		"decl_entry_line:%d:1" % event_index, "\"trees\" = 5"), true) and ok
	ok = _check("and the file says exactly that",
		SUPPORT.compile_output(sheet, "user://own_code_shapes_handed_on.gd"),
		HANDED_ON_SOURCE.replace("\t\t\"trees\": 2,", "\t\t\"trees\": 5,")) and ok
	# A whole-sheet text edit follows the lines a structured table writes, as it does a verbatim row's:
	# a variable rename, and Replace All.
	var edited: EventSheetResource = SUPPORT.reopen(HANDED_ON_SOURCE)
	var rename_counter: Dictionary = {"count": 0}
	var replace_counter: Dictionary = {"count": 0}
	for function_entry: Variant in edited.functions:
		EventSheetRenameRefactor.new()._rename_in_rows((function_entry as EventFunction).events,
			RegEx.create_from_string("\\bhandler\\b"), "slot", rename_counter)
		EventSheetFindBar.new()._replace_in_rows((function_entry as EventFunction).events,
			"\"scene\"", "\"level\"", replace_counter)
	ok = _check("a rename reaches the head of a structured table",
		[(_decls(edited)[2] as CollectionDeclRow).head, int(rename_counter["count"])],
		["connections[slot] = {", 1]) and ok
	ok = _check("Replace All reaches its entries",
		[(_decls(edited)[0] as CollectionDeclRow).entry_values[1], int(replace_counter["count"])],
		["\"level\"", 1]) and ok
	var referenced: Array = []
	var findable: Array = []
	for function_entry: Variant in sheet.functions:
		EventSheetFindReferences._collect((function_entry as EventFunction).events, referenced)
		EventSheetProjectFind._collect_findable_text((function_entry as EventFunction).events, findable)
	ok = _check("Find References and project Find read what a table writes", [
		referenced.any(func(entry: Dictionary) -> bool: return str(entry["text"]).contains("\"trees\": 5")),
		findable.any(func(entry: Dictionary) -> bool: return str(entry["text"]).contains("connections[handler] = {")),
	], [true, true]) and ok
	# A declaration is still a declaration: the widening is for statements only.
	ok = _check("a declared table still parses as a declaration",
		CollectionDeclRow.parse(PackedStringArray(["var waves := {", "\t\"calm\": 3,", "}"]), true).is_statement(), false) and ok
	ok = _check("a statement head is refused where only declarations belong",
		CollectionDeclRow.parse(PackedStringArray(["return {", "\t\"calm\": 3,", "}"])), null) and ok
	ok = _check("a loop over a list is not a statement head",
		CollectionDeclRow.parse(PackedStringArray(["for pair in [", "\t1,", "]:"]), true), null) and ok
	return ok


static func _decls(sheet: EventSheetResource) -> Array:
	var found: Array = []
	for function_entry: Variant in sheet.functions:
		if function_entry is EventFunction:
			for event: Variant in (function_entry as EventFunction).events:
				found.append_array(_decls_in(event as EventRow))
	for event: Variant in sheet.events:
		found.append_array(_decls_in(event as EventRow))
	return found


static func _decls_in(event: EventRow) -> Array:
	var found: Array = []
	if event == null:
		return found
	for action: Variant in event.actions:
		if action is CollectionDeclRow:
			found.append(action)
	return found


static func _raw_codes(event: EventRow) -> Array:
	var codes: Array = []
	if event == null:
		return codes
	for action: Variant in event.actions:
		if action is RawCodeRow:
			codes.append((action as RawCodeRow).code)
	return codes


## The event a named function's body lifted to - a function opened from a file is an EventFunction
## whose first event holds its statements.
static func _event_of(sheet: EventSheetResource, function_name: String) -> EventRow:
	for function_entry: Variant in sheet.functions:
		var event_function: EventFunction = function_entry as EventFunction
		if event_function != null and event_function.function_name == function_name and not event_function.events.is_empty():
			return event_function.events[0] as EventRow
	return null


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("own_code_shapes_test", label, actual, expected)
