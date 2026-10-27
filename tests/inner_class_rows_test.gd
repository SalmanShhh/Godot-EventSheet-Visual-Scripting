# Godot EventSheets - a class written inside a script reads as a Class head with its members under it.
#
# The class's body is opened as a sheet of its own, so its variables are variable rows and its
# functions are function events; the file still saves back byte for byte, a class that cannot come
# back exactly stays code on its own (the rest of the file still reads), a class of fields alone keeps
# the Data type reading it already had, and double-clicking the head turns the class back into the
# code block it is written as.
@tool
class_name InnerClassRowsTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const LINES := preload("res://tools/reading_lines.gd")
const LIFT := preload("res://addons/eventforge/importer/inner_class_lift.gd")
const NAME := "inner_class_rows_test"
const PATH := "user://inner_class_rows_test.gd"
const SOURCE := "extends Node\n\nvar hits: int = 0\n\n\nclass Hit:\n\tvar amount: int = 1\n\tvar from: Node = null\n\n" \
	+ "\tfunc is_critical() -> bool:\n\t\treturn amount > 10\n\n\nfunc _ready() -> void:\n\thits = 0\n"
## Two classes: the first has a member indented with spaces, which the body one tab shallower cannot
## hold, so it stays code; the second reads. A class of fields alone sits between them.
const MIXED := "extends Node\n\n\nclass Odd:\n    var spaced: int = 0\n\n\nclass Stats:\n\tvar speed: float = 1.0\n\n\n" \
	+ "class Even:\n\tvar n: int = 2\n\n\tfunc twice() -> int:\n\t\treturn n * 2\n\n\nfunc _ready() -> void:\n\tprint(1)\n"


static func run() -> bool:
	var ok: bool = true
	var sheet: EventSheetResource = _open(SOURCE)
	var inner: InnerClassRow = _first_inner(sheet)
	ok = _check("the class reads as an InnerClassRow", inner != null, true) and ok
	if inner == null:
		return false
	ok = SUPPORT.pins(NAME, [
		["the header is kept as written", inner.header, "class Hit:"],
		["its name", inner.inner_class_name(), "Hit"],
		["its members are variable rows", _kinds(inner.body.events), ["var amount", "var from"]],
		["its function is a function event", _function_names(inner.body), ["is_critical"]],
		["whose line is an action", _first_action_id(inner.body), "ReturnValue"],
		["the file saves back byte for byte", SUPPORT.compile_output(sheet, PATH), SOURCE],
	]) and ok
	# The map says which lines are the class, and keeps the body's own rows on the lines under it.
	var source_map: Array = SheetCompiler.echo(sheet).get("source_map", [])
	ok = _check("the map holds the class's lines", _span_of(source_map, "inner_class"), [6, 11]) and ok
	ok = _check("and the body's variable rows below its header", _starts_of(source_map, "variable").slice(1), [7, 8]) and ok

	var mixed: EventSheetResource = _open(MIXED)
	ok = SUPPORT.pins(NAME, [
		["a class that cannot come back stays code on its own, and the others read",
			_top_kinds(mixed), ["code", "code: class Odd:", "code: class Stats:", "class Even", "function"]],
		["the mixed file saves back byte for byte", SUPPORT.compile_output(mixed, PATH), MIXED],
	]) and ok

	# The reading instruments count a class's rows as read under its head, never as dropped.
	var reasons: Array = []
	var measured: EventSheetResource = _open(SOURCE)
	for entry: Variant in LINES.events_without_cells(measured, LINES.readings_of_sheet(measured, PATH)):
		reasons.append(str((entry as Dictionary)["reason"]))
	ok = SUPPORT.pins(NAME, [
		["the class's own rows are read under it", reasons.has(LINES.NO_CELL_IN_CLASS), true],
		["and none is dropped", reasons.has(LINES.NO_CELL_DROPPED), false],
	]) and ok

	ok = _one_class_moving_bytes() and ok
	ok = _rows(sheet) and ok
	return ok


## The whole-file gate is per CLASS too. Two classes each come back alone, but putting the second in
## moves bytes elsewhere (its row is made to write another header here, the one way to provoke that
## on purpose): the second stays code and the first still reads, where the gate used to throw every
## class in the file back to code.
static func _one_class_moving_bytes() -> bool:
	var code: String = "extends Node


class Even:
	var n: int = 2

	func twice() -> int:
		return n * 2


" 		+ "class Odd:
	var m: int = 1

	func once() -> int:
		return m"
	var sheet: EventSheetResource = EventSheetResource.new()
	var raw: RawCodeRow = RawCodeRow.new()
	raw.code = code
	sheet.events.append(raw)
	sheet.external_source_path = InnerClassRow.BODY_PATH
	var source: String = str(SheetCompiler.echo(sheet).get("output", ""))
	var before_rows: Array = sheet.events.duplicate()
	var holders: Array[Dictionary] = LIFT._holders(before_rows, RegEx.create_from_string(LIFT.HEADER_PATTERN))
	var read: Array = []
	for holder: Dictionary in holders:
		for inner: Variant in (holder["classes"] as Dictionary).values():
			read.append((inner as InnerClassRow).inner_class_name())
	var ok: bool = _check("both classes come back on their own", read, ["Even", "Odd"])
	if read.size() == 2:
		((holders[0]["classes"] as Dictionary).values()[1] as InnerClassRow).header = "class Odd extends Node:"
	LIFT._place(sheet, before_rows, holders, source)
	return SUPPORT.pins(NAME, [
		["only the class that moved a byte stays code", _top_kinds(sheet), ["code", "class Even", "code: class Odd:"]],
		["and the file still writes what it read", str(SheetCompiler.echo(sheet).get("output", "")), source],
	]) and ok


## The canvas: one full-width head, the members under it read as the rows they are and inert, and a
## double-click turning the class back into its code block.
static func _rows(sheet: EventSheetResource) -> bool:
	var ok: bool = true
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(sheet)
	var head: EventRowData = null
	for entry: Dictionary in dock._active_view().get_flat_rows():
		var row_data: EventRowData = entry.get("row")
		if row_data != null and row_data.source_resource is InnerClassRow:
			head = row_data
	ok = _check("the class has a head row", head != null, true) and ok
	if head != null:
		var child_uids: Array = []
		var inert: bool = true
		for child: EventRowData in head.children:
			child_uids.append(child.row_uid.split("/")[0] + "/" + child.row_uid.split("/")[1].left(9))
			inert = inert and child.source_resource == null
		ok = SUPPORT.pins(NAME, [
			["the head is full width", head.row_type, EventRowData.RowType.SECTION],
			# The class icon says what the line is: no "Class" word stands in front of the name.
			["and leads with the class icon, then the name as written",
				[head.spans[0].text, str(head.spans[0].metadata.get("object_glyph", "")), head.spans.size()], ["Hit", "class", 1]],
			["the members sit under it, keyed by it", child_uids,
				["inner_class_Hit/variable_", "inner_class_Hit/variable_", "inner_class_Hit/define_fn"]],
			["one indent deeper", head.children[0].indent, head.indent + 1],
			["the members are read, not edited", inert, true],
			["the head opens unfolded", head.folded, false],
			["hovering it says how other code makes one",
				str((head.spans[0].metadata as Dictionary).get("hover_note", "")).contains("Hit.new()"), true],
		]) and ok
	var inner: InnerClassRow = _first_inner(dock._current_sheet)
	var as_code: RawCodeRow = dock._code_panel_glue.call("_class_as_code", inner)
	ok = SUPPORT.pins(NAME, [
		["double-clicking the head turns the class back into its code",
			as_code.code if as_code != null else "", "class Hit:\n\tvar amount: int = 1\n\tvar from: Node = null\n\n\tfunc is_critical() -> bool:\n\t\treturn amount > 10"],
		["which takes the class's place in the sheet", dock._current_sheet.events.find(as_code) >= 0, true],
		["and saves the same bytes", SUPPORT.compile_output(dock._current_sheet, PATH), SOURCE],
	]) and ok
	dock.free()
	return ok


static func _open(source: String) -> EventSheetResource:
	var sheet: EventSheetResource = SUPPORT.reopen(source, true, PATH)
	sheet.external_source_path = PATH
	return sheet


static func _first_inner(sheet: EventSheetResource) -> InnerClassRow:
	for entry: Variant in sheet.events:
		if entry is InnerClassRow:
			return entry as InnerClassRow
	return null


## What each row of a list is, in words a pin can hold.
static func _kinds(rows: Array) -> Array:
	var kinds: Array = []
	for entry: Variant in rows:
		if entry is LocalVariable:
			kinds.append("var %s" % (entry as LocalVariable).name)
		elif entry is RawCodeRow:
			kinds.append("code")
		elif entry is FunctionAnchorRow:
			kinds.append("function")
	return kinds


static func _top_kinds(sheet: EventSheetResource) -> Array:
	var kinds: Array = []
	for entry: Variant in sheet.events:
		if entry is InnerClassRow:
			kinds.append("class %s" % (entry as InnerClassRow).inner_class_name())
		elif entry is RawCodeRow and (entry as RawCodeRow).code.contains("class "):
			kinds.append("code: %s" % (entry as RawCodeRow).code.strip_edges().split("\n")[0])
		elif entry is RawCodeRow and not (entry as RawCodeRow).code.strip_edges().is_empty():
			kinds.append("code")
		elif entry is FunctionAnchorRow or entry is EventRow:
			kinds.append("function")
	return kinds


static func _function_names(sheet: EventSheetResource) -> Array:
	var names: Array = []
	for entry: Variant in sheet.functions:
		names.append((entry as EventFunction).function_name)
	return names


static func _first_action_id(sheet: EventSheetResource) -> String:
	for entry: Variant in sheet.functions:
		for event: Variant in (entry as EventFunction).events:
			for action: Variant in (event as EventRow).actions:
				if action is ACEAction:
					return (action as ACEAction).ace_id
	return ""


static func _span_of(source_map: Array, kind: String) -> Array:
	for entry: Variant in source_map:
		if str((entry as Dictionary).get("kind", "")) == kind:
			return [int((entry as Dictionary).get("start", 0)), int((entry as Dictionary).get("end", 0))]
	return []


static func _starts_of(source_map: Array, kind: String) -> Array:
	var starts: Array = []
	for entry: Variant in source_map:
		if str((entry as Dictionary).get("kind", "")) == kind:
			starts.append(int((entry as Dictionary).get("start", 0)))
	return starts


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check(NAME, label, actual, expected)
