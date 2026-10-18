# Godot EventSheets - a region drawn around rows of a function body reopens as that region.
#
# A function body is ordinary rows, and a region can be drawn around some of them. The compiler
# writes the two fences where they sit in the body (`\t#region Setup` ... `\t#endregion`), but the
# lift read them back as two comment rows inside the neighbouring events: the file saved byte for
# byte, yet the region was gone from the sheet after one reopen - it could no longer be folded,
# renamed or removed as a region.
#
# The lift now reads a SHEET FUNCTION's top-level fences as fence rows of its body. Every case is a
# REAL file: opened, edited, saved over itself, parsed, opened again and saved again byte for byte.
# A handler's hand-written `#region` lines are not touched - they keep reading as the comments they
# always were - and neither is a fence written below a blank line (the compiler never writes that).
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const GDScriptImporter := preload("res://addons/eventforge/importer/gdscript_importer.gd")
const TEST_NAME := "function_body_region_test"
const FILE_PATH := "user://function_body_region_test.gd"
const RESAVE_PATH := "user://function_body_region_test_resave.gd"


static func run() -> bool:
	var base: String = str(SheetCompiler.compile(_base_sheet(), FILE_PATH).get("output", ""))
	var untouched: Dictionary = _cycle(base, Callable())
	var plain: Dictionary = _cycle(base, func(sheet: EventSheetResource) -> void: _surround(_function(sheet).events, 0, 0, "Setup", false))
	var styled: Dictionary = _cycle(base, func(sheet: EventSheetResource) -> void: _surround(_function(sheet).events, 1, 1, "Report", true))
	var whole: Dictionary = _cycle(base, func(sheet: EventSheetResource) -> void: _surround(_function(sheet).events, 0, 1, "All", false))
	# The region a reopen brings back is a real one: taking its two fences away is the Remove Region door.
	var removed: Dictionary = _cycle(str(plain.get("saved", "")), func(sheet: EventSheetResource) -> void: _remove_fences(_function(sheet).events))
	var tres_sheet: EventSheetResource = _base_sheet()
	_surround(_function(tres_sheet).events, 0, 0, "Setup", false)
	var sheet_native: String = str(SheetCompiler.echo(tres_sheet).get("output", ""))
	return SUPPORT.pins(TEST_NAME, [
		["the base file parses", _parse_error(base), ""],
		["opened and saved untouched it is byte for byte the same", str(untouched.get("saved", "")), base],
		["a region in a function body is written where it sits", _body_of(str(plain.get("saved", ""))),
			["\t#region Setup", "\tif is_on_floor():", "\t\tscore = 0", "\t#endregion", "\tprint(score)"]],
		["the saved script parses", _parse_error(str(plain.get("saved", ""))), ""],
		["it reopens as fence rows of the body", _shape(plain.get("reopened")), ["#region Setup", "event", "#endregion", "event"]],
		["and saves again byte for byte", str(plain.get("resaved", "")), str(plain.get("saved", ""))],
		["a styled region keeps its style line", _body_of(str(styled.get("saved", ""))),
			["\tif is_on_floor():", "\t\tscore = 0", "\t## @ace_region(#D9534F, \"Says the score\")", "\t#region Report", "\tprint(score)", "\t#endregion"]],
		["and reopens styled", _styled_fields(styled.get("reopened")), {"color": "#D9534F", "description": "Says the score", "label": "Report"}],
		["and saves again byte for byte too", str(styled.get("resaved", "")), str(styled.get("saved", ""))],
		["a sheet-native compile writes it in the body as well", _body_of(sheet_native),
			["\t#region Setup", "\tif is_on_floor():", "\t\tscore = 0", "\t#endregion", "\tprint(score)"]],
		["a handler's own #region lines still read as comments", _handler_comment_rows(), ["region Loop", "action", "endregion"]],
		["a fence below a blank line stays a comment, and the file saves as written", _blank_above_fence(), [["event"], true]],
		["a region around the whole body ends on the body's last line", _body_of(str(whole.get("saved", ""))),
			["	#region All", "	if is_on_floor():", "		score = 0", "	print(score)", "	#endregion"]],
		["and reopens as fence rows around both events", _shape(whole.get("reopened")), ["#region All", "event", "event", "#endregion"]],
		["and saves again byte for byte as well", str(whole.get("resaved", "")), str(whole.get("saved", ""))],
		["removed after the reopen, the file is back to what it was", str(removed.get("saved", "")), base],
		["a hand-written helper's own fences read as its region and save as written", _hand_written_helper(),
			[["#region Count", "event", "#endregion"], true]],
	])


## A sheet with a score and one function: an `if` row then a plain one, so the body reads as two rows.
static func _base_sheet() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "CharacterBody2D"
	var score: LocalVariable = LocalVariable.new()
	score.name = "score"
	score.type_name = "int"
	score.default_value = 0
	sheet.events.append(score)
	var on_floor: EventRow = _plain_row("score = 0")
	var condition: ACECondition = ACECondition.new()
	condition.provider_id = "Core"
	condition.ace_id = "IsOnFloor"
	condition.codegen_template = "is_on_floor()"
	on_floor.conditions.append(condition)
	var reset: EventFunction = EventFunction.new()
	reset.function_name = "reset_score"
	reset.events.append(on_floor)
	reset.events.append(_plain_row("print(score)"))
	sheet.functions.append(reset)
	return sheet


## Writes `base` to the file, opens it, applies `edit` (none for an invalid Callable), saves the sheet
## over the file and opens the file again: {saved, reopened, resaved}.
static func _cycle(base: String, edit: Callable) -> Dictionary:
	_write(FILE_PATH, base)
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(FILE_PATH)
	if edit.is_valid():
		edit.call(sheet)
	SheetCompiler.compile(sheet, FILE_PATH)
	var saved: String = FileAccess.get_file_as_string(FILE_PATH)
	var reopened: EventSheetResource = GDScriptImporter.new().import_external(FILE_PATH)
	_write(RESAVE_PATH, saved)
	reopened.external_source_path = RESAVE_PATH
	SheetCompiler.compile(reopened, RESAVE_PATH)
	return {"saved": saved, "reopened": reopened, "resaved": FileAccess.get_file_as_string(RESAVE_PATH)}


## A fence pair around body[first..last], the way Surround with Region does; `styled` gives the opener
## a colour and a description.
static func _surround(body: Array, first: int, last: int, region_name: String, styled: bool) -> void:
	var opener: CustomBlockRow = EventSheetRegionFacts.make_fence(region_name)
	if styled:
		opener.fields["color"] = "#D9534F"
		opener.fields["description"] = "Says the score"
	body.insert(last + 1, EventSheetRegionFacts.make_fence("", true))
	body.insert(first, opener)


## Every fence row of a body taken out, leaving the rows they wrapped where they are.
static func _remove_fences(body: Array) -> void:
	for index: int in range(body.size() - 1, -1, -1):
		if EventSheetRegionFacts.is_fence(body[index]):
			body.remove_at(index)


## A hand-written helper whose body opens and closes on fences: [its body's shape, saves as written].
static func _hand_written_helper() -> Array:
	var source: String = "extends Node2D

var score: int = 0


func tally() -> void:
	#region Count
	score += 1
	#endregion
"
	_write(FILE_PATH, source)
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(FILE_PATH)
	var tally: EventFunction = null
	for entry: Variant in sheet.functions:
		if entry is EventFunction and (entry as EventFunction).function_name == "tally":
			tally = entry as EventFunction
	SheetCompiler.compile(sheet, FILE_PATH)
	return [_shape_rows(tally.events) if tally != null else [], FileAccess.get_file_as_string(FILE_PATH) == source]


## A hand-written handler with `#region` lines of its own, opened: its rows' actions as words.
static func _handler_comment_rows() -> Array:
	var source: String = "extends Node2D\n\nvar score: int = 0\n\n\nfunc _process(delta: float) -> void:\n\t#region Loop\n\tscore += 1\n\t#endregion\n"
	_write(FILE_PATH, source)
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(FILE_PATH)
	var words: Array = []
	for row: Variant in sheet.events:
		if row is EventRow:
			for action: Variant in (row as EventRow).actions:
				words.append((action as CommentRow).text if action is CommentRow else "action")
	return words


## A hand-written helper whose fence sits below a blank line: [its body's shape, saves as written].
static func _blank_above_fence() -> Array:
	var source: String = "extends Node2D\n\nvar score: int = 0\n\n\nfunc tally() -> void:\n\tscore += 1\n\n\t#region Later\n\tprint(score)\n\t#endregion\n"
	_write(FILE_PATH, source)
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(FILE_PATH)
	var tally: EventFunction = null
	for entry: Variant in sheet.functions:
		if entry is EventFunction and (entry as EventFunction).function_name == "tally":
			tally = entry as EventFunction
	SheetCompiler.compile(sheet, FILE_PATH)
	return [_shape_rows(tally.events) if tally != null else [], FileAccess.get_file_as_string(FILE_PATH) == source]


## The reset_score body's lines, from the line after its header to the end of the function.
static func _body_of(text: String) -> Array:
	var lines: PackedStringArray = text.split("\n")
	var at: int = lines.find("func reset_score() -> void:")
	if at < 0:
		return []
	var body: Array = []
	for index: int in range(at + 1, lines.size()):
		if not lines[index].begins_with("\t"):
			break
		body.append(lines[index])
	return body


static func _shape(sheet: Variant) -> Array:
	return _shape_rows(_function(sheet).events) if _function(sheet) != null else []


## A body's rows as words: a fence as its line, an event as "event".
static func _shape_rows(rows: Array) -> Array:
	var shape: Array = []
	for row: Variant in rows:
		if EventSheetRegionFacts.is_closing_fence(row):
			shape.append("#endregion")
		elif EventSheetRegionFacts.is_fence(row):
			shape.append("#region %s" % EventSheetRegionFacts.label(row))
		elif row is EventRow:
			shape.append("event")
		else:
			shape.append(str(row))
	return shape


## The reopened styled opener's fields, or {} when the body holds no opener.
static func _styled_fields(sheet: Variant) -> Dictionary:
	var reset: EventFunction = _function(sheet)
	if reset == null:
		return {}
	for row: Variant in reset.events:
		if EventSheetRegionFacts.is_opening_fence(row):
			var fields: Dictionary = (row as CustomBlockRow).fields
			return {"color": str(fields.get("color", "")), "description": str(fields.get("description", "")),
				"label": str(fields.get("label", ""))}
	return {}


static func _function(sheet: Variant) -> EventFunction:
	if not (sheet is EventSheetResource):
		return null
	for entry: Variant in (sheet as EventSheetResource).functions:
		if entry is EventFunction and (entry as EventFunction).function_name == "reset_score":
			return entry as EventFunction
	return null


static func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


## "" when `source` parses as a script, else the error it fails with.
static func _parse_error(source: String) -> String:
	var script: GDScript = GDScript.new()
	script.source_code = source
	var error: int = script.reload()
	return "" if error == OK else error_string(error)


## A function-body row carrying one plain statement (no trigger: the function header is the entry).
static func _plain_row(code: String) -> EventRow:
	var event: EventRow = EventRow.new()
	var statement: RawCodeRow = RawCodeRow.new()
	statement.code = code
	event.actions.append(statement)
	return event
