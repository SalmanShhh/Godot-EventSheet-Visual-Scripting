# Godot EventSheets - a variable whose value runs over several lines stays ONE variable row.
#
# The value reads on one line - that is what the row shows and what an edit changes - and the lines it
# was written over are written back while it still reads that way. A list or table folds to its count,
# its entries one double-click away. Lines that cannot be read on one line without changing what they
# say (a comment inside them) stay the code they are.
@tool
class_name WrittenValueLinesTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const NAME := "written_value_lines_test"
const PATH := "user://written_value_lines_test.gd"
const SOURCE := "extends Node\n\nvar base_speed: float = 1.0\nvar spawn_points: Array[Vector2] = [\n\tVector2(0, 0),\n\tVector2(64, 0),\n" \
	+ "\tVector2(128, 32),\n]\nvar top_speed: float = (base_speed\n\t* boost\n\t+ wind)\n" \
	+ "const WORDS: PackedStringArray = [\"run\", \"jump\",\n\t\"duck\"]\n\n\nfunc _ready() -> void:\n" \
	+ "\tvar answer: String = str(base_speed,\n\t\ttop_speed)\n\tprint(answer)\n"
const NOTED := "extends Node\n\nvar top_speed: float = (base_speed  # the start\n\t* boost)\n"


static func run() -> bool:
	var ok: bool = true
	ok = SUPPORT.pins(NAME, [
		["a sum over three lines joins onto one",
			EventForgeValueLines.join(PackedStringArray(["(base_speed", "\t* boost", "\t+ wind)"])).get("text"), "(base_speed * boost + wind)"],
		["no space after an opening bracket or before a closing one",
			EventForgeValueLines.join(PackedStringArray(["call(", "\ta,", "\tb", ")"])).get("text"), "call(a, b)"],
		["a line continued by a backslash joins without it",
			EventForgeValueLines.join(PackedStringArray(["a + \\", "\tb"])).get("text"), "a + b"],
		["a comment inside the lines is refused",
			EventForgeValueLines.join(PackedStringArray(["(a  # why", "\t+ b)"])), {}],
		["a hash inside a string is not a comment",
			EventForgeValueLines.join(PackedStringArray(["(\"#\"", "\t+ b)"])).get("text"), "(\"#\" + b)"],
		["a rename keeps the line breaks it does not cross",
			EventForgeValueLines.rewritten({"one_line": "(a + b)", "written": "(a\n\t+ b)"}, func(text: String) -> String:
				return text.replace("a", "x")), {"one_line": "(x + b)", "written": "(x\n\t+ b)"}],
		["a replace across a line break writes the value on one line",
			EventForgeValueLines.rewritten({"one_line": "(a + b)", "written": "(a\n\t+ b)"}, func(text: String) -> String:
				return text.replace("a + b", "c")), {}],
		["a list literal counts its entries", EventForgeValueLines.entry_count("[\"a, b\", [1, 2], c,]"), 3],
		["anything else is not a list", EventForgeValueLines.entry_count("[a] + [b]"), -1],
		["a piece of the one line maps back to the lines it came from",
			EventForgeValueLines.written_part(EventForgeValueLines.join(PackedStringArray(["x = (a", "\t+ b)"])), "(a + b)"), "(a\n\t+ b)"],
	]) and ok

	var sheet: EventSheetResource = _open(SOURCE)
	var top_speed: LocalVariable = _variable(sheet, "top_speed")
	var answer: ACEAction = _first_written_action(sheet)
	ok = SUPPORT.pins(NAME, [
		["a long sum is one variable row", top_speed != null, true],
		["whose value reads on one line", str(top_speed.default_value) if top_speed != null else "", "(base_speed * boost + wind)"],
		["a call over two lines in a function is one action", answer != null, true],
		["whose value reads on one line", str(answer.params.get("value", "")) if answer != null else "", "str(base_speed, top_speed)"],
		["the file saves back with its line breaks", SUPPORT.compile_output(sheet, PATH), SOURCE],
	]) and ok
	if top_speed == null or answer == null:
		return false
	# An edit is written as typed: the kept lines belong to the value as it was.
	top_speed.default_value = "base_speed * 2.0"
	answer.params["value"] = "str(top_speed)"
	var edited: String = SUPPORT.compile_output(sheet, PATH)
	ok = SUPPORT.pins(NAME, [
		["an edited value is written on one line", edited.contains("\nvar top_speed: float = base_speed * 2.0\n"), true],
		["and so is an edited action", edited.contains("\n\tvar answer: String = str(top_speed)\n"), true],
	]) and ok

	var noted: EventSheetResource = _open(NOTED)
	ok = SUPPORT.pins(NAME, [
		["a value with a comment inside stays code", _variable(noted, "top_speed"), null],
		["and still saves back exactly", SUPPORT.compile_output(noted, PATH), NOTED],
	]) and ok

	ok = _rows(_open(SOURCE)) and ok
	return ok


## The canvas: the table is one folded variable row with its entries under it, and the long value's
## echo is the declaration on one line.
static func _rows(sheet: EventSheetResource) -> bool:
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(sheet)
	var table: EventRowData = null
	for entry: Dictionary in dock._active_view().get_flat_rows():
		var row_data: EventRowData = entry.get("row")
		if row_data != null and row_data.source_resource is CollectionDeclRow and row_data.indent == 0 and table == null:
			table = row_data
	var words: Array = []
	if table != null:
		for span: SemanticSpan in table.spans:
			words.append(span.text)
	var ok: bool = SUPPORT.pins(NAME, [
		["a list reads as one variable row", words, ["Array[Vector2]", "spawn_points", "=", "3 entries"]],
		["folded to its count", table.folded if table != null else false, true],
		["its entries are the rows under it", table.children.size() if table != null else 0, 3],
		["each one an entry of its own", str(table.children[2].spans[0].text) if table != null else "", "Vector2(128, 32)"],
		["the long value echoes on one line", EventSheetCodeEcho.line_for(_variable(sheet, "top_speed")),
			"var top_speed: float = (base_speed * boost + wind)"],
		["a list wrapped over lines folds to its count", _value_word(dock, "WORDS"), "3 entries"],
	])
	dock.free()
	return ok


## What a variable row shows as its value.
static func _value_word(dock: EventSheetDock, variable_name: String) -> String:
	for entry: Dictionary in dock._active_view().get_flat_rows():
		var row_data: EventRowData = entry.get("row")
		if row_data == null or not (row_data.source_resource is LocalVariable) \
				or (row_data.source_resource as LocalVariable).name != variable_name:
			continue
		for span: SemanticSpan in row_data.spans:
			if bool((span.metadata as Dictionary).get("variable_value_span", false)):
				return span.text
	return ""


static func _open(source: String) -> EventSheetResource:
	var sheet: EventSheetResource = SUPPORT.reopen(source, true, PATH)
	sheet.external_source_path = PATH
	return sheet


static func _variable(sheet: EventSheetResource, variable_name: String) -> LocalVariable:
	for entry: Variant in sheet.events:
		if entry is LocalVariable and (entry as LocalVariable).name == variable_name:
			return entry as LocalVariable
	return null


static func _first_written_action(sheet: EventSheetResource) -> ACEAction:
	var events: Array = sheet.events.duplicate()
	for function_entry: Variant in sheet.functions:
		events.append_array((function_entry as EventFunction).events)
	for event: Variant in events:
		if event is EventRow:
			for action: Variant in (event as EventRow).actions:
				if action is ACEAction and not (action as ACEAction).written_params.is_empty():
					return action as ACEAction
	return null
