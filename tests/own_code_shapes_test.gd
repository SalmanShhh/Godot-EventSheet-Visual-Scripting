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


## A statement continued with a trailing `\`, and notes written inside a callback's body.
const CONTINUED_SOURCE := """extends Node

var title: String = ""


func open_for(object_label: String) -> void:
	title = "Add behavior to %s" % object_label \\
		if not object_label.is_empty() else "Add behavior"
	var apply: Callable = func() -> void:
		title = object_label
		# why the callback says so
		# and the second line of it
		print(title)
	apply.call()
"""


## The engine callbacks the editor writes in the engine docs' own spelling: a notification handler
## as an `if`/`elif` chain (each arm holding more than one row), a property list built by hand
## between other functions, and properties whose accessors sit on their headers' own lines.
const CALLBACKS_SOURCE := """extends Control

var _panel: Node = null
var _resizes: int = 0


func _ready() -> void:
	_panel = Node.new()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		# Count it, and only redraw once there is a panel to redraw.
		_resizes += 1
		if _panel != null:
			queue_redraw()
		update_minimum_size()
	elif what == NOTIFICATION_MOUSE_EXIT:
		queue_redraw()


func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	properties.append({"name": "resizes", "type": TYPE_INT})
	return properties


func helper() -> void:
	pass

var _tree: Tree:
	get: return _panel.get_child(0)
	set(value): _panel.add_child(value)

var _only_read: int:
	get: return _resizes
"""

## The language-changed trigger's own compiled shape, which keeps the path it already had.
const TRANSLATION_SOURCE := """extends Node


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		print("language")
"""


static func run() -> bool:
	var ok: bool = true
	ok = _test_handed_on_literals() and ok
	ok = _test_continued_statements() and ok
	ok = _test_engine_callbacks() and ok
	ok = _test_shipped_pack_readings() and ok
	return ok


## Three readings of shipped packs, pinned where a lift change moved them once. A save-state table
## handed to `return` is still evidence of the skill tree it saves, so its event keeps the chip. And a
## handler wired inside another function and called by name as well opens as the function it is,
## with the wire row saying which signal reaches it: `walk` is a local of the function that wires
## it, so a standalone "walk: On Finished" event would name an object the file does not have.
static func _test_shipped_pack_readings() -> bool:
	var ok: bool = true
	var upgrades: Array = _cell_texts("res://eventsheet_addons/upgrades/upgrades_addon.gd")
	var save_at: int = _index_ending(upgrades, "Function | On save_state")
	var load_at: int = _index_ending(upgrades, "Function | On load_state")
	ok = _check("the save-state table keeps the skill tree chip",
		upgrades.slice(save_at, load_at).has("⟡ A skill tree - prerequisites, points and unlocks") if save_at >= 0 and load_at > save_at else false,
		true) and ok
	var screen_fx: Array = _cell_texts("res://eventsheet_addons/screen_fx/screen_fx.gd")
	var drawing: Array = _cell_texts("res://eventsheet_addons/drawing_prefab_resource/drawing_prefab_resource.gd")
	ok = _check("a handler wired in a function and called by name opens as a function", [
		_index_ending(screen_fx, "Function | On _settle") >= 0, screen_fx.has("Wire On Finished to _settle"), screen_fx.has("Call _settle"),
		_index_ending(drawing, "Function | On _invalidate_compiled") >= 0, drawing.has("Wire On Changed to _invalidate_compiled"),
	], [true, true, true, true, true]) and ok
	return ok


## Every cell of a file opened as a sheet, its segments joined with " | ".
static func _cell_texts(path: String) -> Array:
	var texts: Array = []
	var sheet: EventSheetResource = SUPPORT.reopen(FileAccess.get_file_as_string(path), true, path)
	for reading: Variant in LINES.readings_of_sheet(sheet, "pack"):
		texts.append(" | ".join(reading.plain))
	return texts


## The first cell whose text ends in `suffix` (a function head leads with its scope badge), or -1.
static func _index_ending(texts: Array, suffix: String) -> int:
	for index: int in range(texts.size()):
		if str(texts[index]).ends_with(suffix):
			return index
	return -1


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
		"Return  | table | \"path\" = path | \"kind\" = \"scene\"",
		"Push back  | table | \"path\" = path | \"trees\" = 2 |  to sources",
		"Set connections[handler] to  | table | \"path\" = path | \"once\" = true",
		"Print rich   path    | list | \"first\" | \"second\"",
		"Return  | list | {\"name\": \"calm\", \"count\": 3} | {\"name\": \"busy\", \"count\": 8}",
		"Return  | table | \"outer\" = table (\"inner\" = 1)",
		"Shade    | table | alpha = 1",
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


## A line ending in `\` is ONE statement with the lines it continues onto, never a row whose value
## ends in a stray backslash above an orphan `if … else …` row. A note inside a block that stayed code
## is a note row. And the wordless measure reads an indented statement the way the canvas does.
static func _test_continued_statements() -> bool:
	var ok: bool = true
	var sheet: EventSheetResource = SUPPORT.reopen(CONTINUED_SOURCE)
	sheet.external_source_path = "user://own_code_shapes_continued.gd"
	ok = _check("a file of continued statements reproduces byte-identically",
		SUPPORT.compile_output(sheet, "user://own_code_shapes_continued.gd"), CONTINUED_SOURCE) and ok
	var event: EventRow = _event_of(sheet, "open_for")
	var first: Resource = event.actions[0] if event != null and not event.actions.is_empty() else null
	ok = _check("the continued statement is one row holding both of its lines",
		(first as RawCodeRow).code if first is RawCodeRow else "", "title = \"Add behavior to %s\" % object_label \\\n\tif not object_label.is_empty() else \"Add behavior\"") and ok
	var notes: Array = []
	for action: Variant in (event.actions if event != null else []):
		if action is CommentRow:
			notes.append([(action as CommentRow).source_marker, (action as CommentRow).text])
	ok = _check("a note inside the callback is a note row that keeps its indent",
		notes, [["\t# ", "why the callback says so\nand the second line of it"]]) and ok
	var cells: Array = []
	for reading: Variant in LINES.readings_of_sheet(SUPPORT.reopen(CONTINUED_SOURCE), "own"):
		if reading.lane == "action":
			cells.append(" | ".join(reading.plain))
	ok = _check("the canvas reads the continued statement as one sentence",
		cells[0] if not cells.is_empty() else "",
		"Set title to \"Add behavior to \" & object_label if not object_label' count = 0 else \"Add behavior\"") and ok
	ok = SUPPORT.pins("own_code_shapes_test", [
		["an indented statement is not a literal entry",
			ViewportRowBuilder.is_literal_part("\tlabel.text = str(said[0])"), false],
		["an indented entry still is", ViewportRowBuilder.is_literal_part("\t\"walk\", \"run\","), true],
		["an indented note is not", ViewportRowBuilder.is_literal_part("\t# why"), false],
		["an indented statement with words is not wordless",
			EventSheetGenericRows.is_generic_code("\tlabel.text = str(said[0])"), false],
		["an indented bare call is wordless, the same as at its own depth",
			EventSheetGenericRows.is_generic_code("\twords.add_child(label)"),
			EventSheetGenericRows.is_generic_code("words.add_child(label)")],
		["a backslash in a comment continues nothing", EventSheetACELifter.ends_in_continuation("x = 1 # a \\"), false],
		["nor one inside a string", EventSheetACELifter.ends_in_continuation("x = \"a \\"), false],
		["a trailing backslash does", EventSheetACELifter.ends_in_continuation("x = a + \\"), true],
	]) and ok
	return ok


## The `if`/`elif` notification chain opens as its notifications' triggers and writes the chain back;
## `_get_property_list` is a function row in its place; one-line accessors are the property's get/set.
static func _test_engine_callbacks() -> bool:
	var ok: bool = true
	var sheet: EventSheetResource = SUPPORT.reopen(CALLBACKS_SOURCE)
	sheet.external_source_path = "user://own_code_shapes_callbacks.gd"
	ok = _check("a file of engine callbacks reproduces byte-identically",
		SUPPORT.compile_output(sheet, "user://own_code_shapes_callbacks.gd"), CALLBACKS_SOURCE) and ok
	var triggers: Array = []
	for entry: Variant in sheet.events:
		if entry is EventRow and (entry as EventRow).trigger_id.begins_with("OnNotification:"):
			triggers.append((entry as EventRow).trigger_id)
	ok = _check("each arm is its notification's trigger, a branch inside one its own row", triggers,
		["OnNotification:NOTIFICATION_RESIZED", "OnNotification:NOTIFICATION_RESIZED",
			"OnNotification:NOTIFICATION_RESIZED", "OnNotification:NOTIFICATION_MOUSE_EXIT"]) and ok
	var raw_blocks: Array = []
	for entry: Variant in sheet.events:
		if entry is RawCodeRow and (entry as RawCodeRow).code.strip_edges().begins_with("func "):
			raw_blocks.append((entry as RawCodeRow).code.split("\n")[0])
	ok = _check("no callback is left a block of code", raw_blocks, []) and ok
	var property_list: EventFunction = null
	for entry: Variant in sheet.functions:
		if entry is EventFunction and (entry as EventFunction).function_name == "_get_property_list":
			property_list = entry
	ok = _check("the hand-built property list is a function row", property_list != null, true) and ok
	var accessors: Array = []
	for variable: Variant in sheet.events:
		var local_var: LocalVariable = variable as LocalVariable
		if local_var != null and local_var.has_accessor_bodies():
			accessors.append([local_var.name, local_var.getter_body, local_var.setter_body])
	ok = _check("one-line accessors are the property's get and set", accessors, [
		["_tree", "return _panel.get_child(0)", "_panel.add_child(value)"],
		["_only_read", "return _resizes", ""],
	]) and ok
	# A getter grown past one line writes the block form: the one-line spelling is the file's, not a rule.
	var tree_var: LocalVariable = null
	for variable: Variant in sheet.events:
		if variable is LocalVariable and (variable as LocalVariable).name == "_tree":
			tree_var = variable
	if tree_var != null:
		tree_var.getter_body = "var first: Node = _panel.get_child(0)\nreturn first"
	ok = _check("a getter grown past one line writes its block", SUPPORT.compile_output(sheet,
		"user://own_code_shapes_callbacks.gd").contains("\tget:\n\t\tvar first: Node = _panel.get_child(0)\n\t\treturn first\n\tset(value): _panel.add_child(value)"),
		true) and ok
	var translated: EventSheetResource = SUPPORT.reopen(TRANSLATION_SOURCE)
	var translated_triggers: Array = []
	for entry: Variant in translated.events:
		if entry is EventRow:
			translated_triggers.append((entry as EventRow).trigger_id)
	ok = _check("the language-changed arm keeps the path it had", translated_triggers, []) and ok
	ok = _check("and still reproduces byte-identically",
		SUPPORT.reemit(TRANSLATION_SOURCE, "user://own_code_shapes_translation.gd"), TRANSLATION_SOURCE) and ok
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
