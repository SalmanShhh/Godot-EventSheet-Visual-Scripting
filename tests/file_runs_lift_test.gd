# Godot EventSheets - the three FILE runs, opened again as the rows that wrote them.
#
# Reading a spreadsheet, writing one back and adding a line to a log are each SEVERAL statements of
# GDScript and one sentence on a sheet. Before this gate, reopening a sheet that did any of them gave
# back the statements: a code block for the read, and a scatter of Set and Call Method rows for the
# other two. The bytes were never in danger - they round-tripped then and they round-trip now - but
# the sentence was, and a sentence a sheet cannot get back is a sentence its author has to write
# again.
#
# WHAT IS WORTH TESTING HERE, and why:
#   - THE ROW COMES BACK, with its values. Every pin below is a VALUE (the path, the table, the
#     separator, the first-line answer), never a count of rows, because a count passes just as
#     happily when the reading is wrong.
#   - THE BYTES DO NOT MOVE. Each case re-emits the file it opened and compares it whole. That is the
#     lossless contract, and it is the only reason a lift is allowed to fire at all.
#   - THE DROPDOWN IS STILL LIVE. A lifted Write Table To File keeps the segment marks its first-line
#     question picks between, so changing the answer changes the code. A lift that baked the answer
#     into the template would pass every other pin here and leave the reader with a dropdown that
#     does nothing.
#   - WHAT IS REFUSED. A hand-written read loop, a hand-written write chain and an append with no
#     guard around the handle are each a DIFFERENT program from the row that would claim them, so
#     each must come back as the code it is. A lift is only as trustworthy as the runs it declines.
@tool
class_name FileRunsLiftTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const TABLE_MODULE := "res://addons/eventforge/registration/modules/table_aces.gd"
const NAME := "file_runs_lift_test"

## The path every case re-emits through. One path on both sides of a comparison, which is what the
## round-trip helper asks for.
const VERIFY_PATH := "user://file_runs_lift_verify.gd"


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _run_read() and all_passed
	all_passed = _run_write() and all_passed
	all_passed = _run_append() and all_passed
	all_passed = _run_refusals() and all_passed
	if FileAccess.file_exists(VERIFY_PATH):
		DirAccess.remove_absolute(VERIFY_PATH)
	if all_passed:
		print("[PASS] %s: the three file runs open as the rows that wrote them" % NAME)
	return all_passed


## The table read: a Set whose value is the Table Of File expression, over both answers of the
## first-line question. The row that comes back is the Set it was authored as, and the whole
## expression is in the slot a reader edits it in.
static func _run_read() -> bool:
	var ok: bool = true
	for answer: String in [EventForgeTableACEs.HEADERS_NAMED, EventForgeTableACEs.HEADERS_PLAIN]:
		var expression: String = _emitted("FileTable", {"path": "\"res://data/items.csv\"",
			"separator": "\",\"", "headers": answer})
		var source: String = _sheet_with([_action("SetVar", {"var_name": "items",
			"value": expression})])
		var rows: Array = _actions_of(source)
		ok = SUPPORT.pins(NAME, [
			["the read opens as one row (%s)" % answer, rows.size(), 1],
			["and that row is the Set it was authored as (%s)" % answer,
				_ace_id(rows), "SetVar"],
			["holding the variable it filled (%s)" % answer,
				_param(rows, "var_name"), "items"],
			["and the whole expression in its value slot (%s)" % answer,
				_param(rows, "value"), expression],
			["the file re-emits byte for byte (%s)" % answer,
				SUPPORT.reemit(source, VERIFY_PATH), source]
		]) and ok
	# The same expression assigned to a typed local, which is the other Set a sheet writes.
	var typed_expression: String = _emitted("FileTable", {"path": "\"res://data/items.csv\"",
		"separator": "\";\"", "headers": EventForgeTableACEs.HEADERS_NAMED})
	var typed_source: String = _sheet_with([_action("SetLocalVarTyped", {"name": "rows",
		"var_type": "Array", "value": typed_expression})])
	var typed_rows: Array = _actions_of(typed_source)
	ok = SUPPORT.pins(NAME, [
		["a typed local reads as the local it declares", _ace_id(typed_rows),
			"SetLocalVarTyped"],
		["with its own name", _param(typed_rows, "name"), "rows"],
		["and its own type", _param(typed_rows, "var_type"), "Array"],
		["and the expression in its value slot", _param(typed_rows, "value"), typed_expression],
		["a semicolon file re-emits byte for byte", SUPPORT.reemit(typed_source, VERIFY_PATH),
			typed_source]
	]) and ok
	return ok


## The table write: the open, the guard and the loop that hands each record to the engine's own CSV
## writer, back as the one row - and still answering its first-line question out loud.
static func _run_write() -> bool:
	var ok: bool = true
	for answer: String in [EventForgeTableACEs.HEADERS_NAMED, EventForgeTableACEs.HEADERS_PLAIN]:
		var source: String = _sheet_with([_baked("WriteFileTable", {
			"path": "\"user://scores.csv\"", "table": "items", "separator": "\",\"",
			"headers": answer})])
		var rows: Array = _actions_of(source)
		ok = SUPPORT.pins(NAME, [
			["the write opens as one row (%s)" % answer, rows.size(), 1],
			["and that row is the write (%s)" % answer, _ace_id(rows), "WriteFileTable"],
			["with the file it wrote (%s)" % answer, _param(rows, "path"),
				"\"user://scores.csv\""],
			["the table it wrote (%s)" % answer, _param(rows, "table"), "items"],
			["the separator it used (%s)" % answer, _param(rows, "separator"), "\",\""],
			["and the first-line answer it was written with (%s)" % answer,
				_param(rows, "headers"), answer],
			["the file re-emits byte for byte (%s)" % answer,
				SUPPORT.reemit(source, VERIFY_PATH), source]
		]) and ok
	# The dropdown is a LIVE choice on the lifted row, not a decision baked into it while it was
	# being read: answering the other way writes the other shape. Pinned on a value the two shapes
	# disagree about - only the header-naming answer writes a line of column names first.
	var lifted: Array = _actions_of(_sheet_with([_baked("WriteFileTable", {
		"path": "\"user://scores.csv\"", "table": "items", "separator": "\",\"",
		"headers": EventForgeTableACEs.HEADERS_NAMED})]))
	var flipped: ACEAction = _flipped(lifted, EventForgeTableACEs.HEADERS_PLAIN)
	ok = SUPPORT.pins(NAME, [
		["answering the other way stops writing a header line",
			ActionCodegen.generate_action(flipped).contains("keys())"), false],
		["and writes every entry as plain cells instead",
			ActionCodegen.generate_action(flipped).contains("for __row_"), true]
	]) and ok
	return ok


## The append: the five-line run, however the handle was declared and whichever call put the text
## out. The row's own spelling and the two a person writes by hand all read as the same sentence.
static func _run_append() -> bool:
	var ok: bool = true
	var written: String = _sheet_with([_baked("AppendTextFile", {"path": "\"user://log.txt\"",
		"text": "\"hello\""})])
	var written_rows: Array = _actions_of(written)
	ok = SUPPORT.pins(NAME, [
		["the sheet's own append opens as one row", written_rows.size(), 1],
		["and that row is the append", _ace_id(written_rows), "AppendTextFile"],
		["with the file it added to", _param(written_rows, "path"), "\"user://log.txt\""],
		["and the text it added", _param(written_rows, "text"), "\"hello\""],
		["the file re-emits byte for byte", SUPPORT.reemit(written, VERIFY_PATH), written]
	]) and ok
	for spelling: Dictionary in _hand_written_appends():
		var source: String = str(spelling["source"])
		var rows: Array = _actions_of(source)
		var label: String = str(spelling["label"])
		ok = SUPPORT.pins(NAME, [
			["a hand-written append is one row (%s)" % label, rows.size(), 1],
			["and reads as the append (%s)" % label, _ace_id(rows), "AppendTextFile"],
			["with the file it added to (%s)" % label, _param(rows, "path"),
				str(spelling["path"])],
			["and the text it added (%s)" % label, _param(rows, "text"), str(spelling["text"])],
			["re-emitting the author's own spelling (%s)" % label,
				SUPPORT.reemit(source, VERIFY_PATH), source]
		]) and ok
	return ok


## The four spellings of a hand-written append that this family claims: the handle declared with its
## type and without, and the text written with store_string and with store_line. The row's reading is
## the same sentence for all four, and each re-emits as its author wrote it.
static func _hand_written_appends() -> Array[Dictionary]:
	var spellings: Array[Dictionary] = []
	for head: String in ["var log_file = ", "var log_file: FileAccess = "]:
		for call: String in ["store_string", "store_line"]:
			spellings.append({
				"label": "%s%s" % [head.trim_prefix("var log_file"), call],
				"path": "\"user://notes.txt\"",
				"text": "\"a line\"",
				"source": _handwritten([
					"%sFileAccess.open(\"user://notes.txt\", FileAccess.READ_WRITE)" % head,
					"if log_file:",
					"\tlog_file.seek_end()",
					"\tlog_file.%s(\"a line\")" % call,
					"\tlog_file.close()"
				])
			})
	return spellings


## The runs that are a DIFFERENT program from the row that would claim them, and so are left as the
## code they are. Each is pinned by what the first row reads as, because "several rows" is a count
## and the point is which reading a reader gets.
static func _run_refusals() -> bool:
	var unguarded: String = _handwritten([
		"var log_file = FileAccess.open(\"user://notes.txt\", FileAccess.READ_WRITE)",
		"log_file.seek_end()",
		"log_file.store_line(\"a line\")",
		"log_file.close()"
	])
	var loop: String = _handwritten([
		"var rows: Array = []",
		"var data_file: FileAccess = FileAccess.open(\"res://data/items.csv\", FileAccess.READ)",
		"while not data_file.eof_reached():",
		"\trows.append(data_file.get_csv_line(\",\"))"
	])
	var chain: String = _handwritten([
		"var out_file = FileAccess.open(\"user://scores.csv\", FileAccess.WRITE)",
		"if out_file:",
		"\tfor entry: Variant in items:",
		"\t\tout_file.store_csv_line(PackedStringArray(entry), \",\")",
		"\tout_file.close()"
	])
	return SUPPORT.pins(NAME, [
		["an append with no guard is not read as the append",
			_ace_id(_actions_of(unguarded)) == "AppendTextFile", false],
		["and its bytes are still its own", SUPPORT.reemit(unguarded, VERIFY_PATH), unguarded],
		# The loop's first statement is the empty list it declares, and it still declares it: a lift
		# that had swallowed the loop would have put the sheet's own lambda in that value slot.
		["a hand-written read loop keeps declaring its own list",
			_param(_actions_of(loop), "value"), "[]"],
		["and its bytes are still its own", SUPPORT.reemit(loop, VERIFY_PATH), loop],
		["a hand-written write chain is not read as the write row",
			_ace_id(_actions_of(chain)) == "WriteFileTable", false],
		["and its bytes are still its own", SUPPORT.reemit(chain, VERIFY_PATH), chain]
	])


# ── the pieces ──────────────────────────────────────────────────────────────


## A whole `.gd` file holding one `_ready` with these statements in it, spelled the way somebody
## writing GDScript by hand would spell it.
static func _handwritten(statements: PackedStringArray) -> String:
	var lines: PackedStringArray = PackedStringArray(["extends Node", "", "",
		"func _ready() -> void:"])
	for statement: String in statements:
		lines.append("\t" + statement)
	return "\n".join(lines) + "\n"


## A compiled sheet holding these actions under one On Ready, as the file the editor would save.
static func _sheet_with(actions: Array) -> String:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	sheet.variables["items"] = {"type": "Array", "default": []}
	var row: EventRow = EventRow.new()
	row.trigger_provider_id = "Core"
	row.trigger_id = "OnReady"
	for action: Variant in actions:
		row.actions.append(action)
	sheet.events.append(row)
	return str(SheetCompiler.compile(sheet, VERIFY_PATH).get("output", ""))


## The actions of the one event a reopened file holds. Empty when the file came back with no event at
## all, which every pin above then reads as a mismatch rather than as a crash.
static func _actions_of(source: String) -> Array:
	var reopened: EventSheetResource = SUPPORT.reopen(source)
	if reopened == null:
		return []
	for event: Variant in reopened.events:
		if event is EventRow and not (event as EventRow).actions.is_empty():
			return (event as EventRow).actions
	return []


## The ace_id of the first action, or "" when there is none.
static func _ace_id(actions: Array) -> String:
	if actions.is_empty() or not (actions[0] is ACEAction):
		return ""
	return str((actions[0] as ACEAction).ace_id)


## One value off the first action, or "" when the row has no such value.
static func _param(actions: Array, key: String) -> String:
	if actions.is_empty() or not (actions[0] is ACEAction):
		return ""
	return str((actions[0] as ACEAction).params.get(key, ""))


## The first lifted action with its first-line question answered the other way - a copy, because a
## row that came off a reopened sheet belongs to that sheet.
static func _flipped(actions: Array, answer: String) -> ACEAction:
	var action: ACEAction = (actions[0] as ACEAction).duplicate()
	action.params = (actions[0] as ACEAction).params.duplicate()
	action.params["headers"] = answer
	return action


## An action carrying the shipped template with a uid already baked onto it, which is what the dock
## does the moment a row is applied.
static func _baked(ace_id: String, params: Dictionary) -> ACEAction:
	var action: ACEAction = _action(ace_id, params)
	action.codegen_template = _template(ace_id).replace("{uid}", "lift_probe")
	return action


static func _action(ace_id: String, params: Dictionary) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = ace_id
	action.params = params
	return action


## One shipped template filled with these values, through the compiler's own substitution.
static func _emitted(ace_id: String, params: Dictionary) -> String:
	return ActionCodegen._apply_template(_template(ace_id), params)


## One shipped template, off the descriptor that ships it.
static func _template(ace_id: String) -> String:
	for path: String in [TABLE_MODULE,
			"res://addons/eventforge/registration/modules/file_aces.gd"]:
		for descriptor: ACEDescriptor in load(path).get_descriptors():
			if descriptor.ace_id == ace_id:
				return str(descriptor.codegen_template)
	return ""
