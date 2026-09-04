# EventForge - the three FILE runs that are several statements and one sentence.
#
# A sheet that reads a spreadsheet, writes one back, or adds a line to a log emits a RUN of
# statements, because none of those three jobs is one line of GDScript. Opened again, each of those
# runs came back as the statements it is made of - a code block for the read, and a scatter of Set
# and Call Method rows for the other two - so a sheet lost the sentence it was written in the moment
# it was reopened. This family claims each run as the one row that emits it.
#
# WHAT EACH RUN IS:
#   - THE TABLE READ. Table Of File is an EXPRESSION, so it lands in the value slot of a Set: the
#     emitted statement is `rows = (func(__path: String) -> Array: … ).call(<path>)`, one statement
#     written over fifteen lines. The row handed back is the Set it always was, with the whole
#     expression in its value slot - exactly where the one-line Table From File already sits when a
#     sheet using it is reopened.
#   - THE TABLE WRITE. Write Table To File emits an open, a guard, and a loop that hands each record
#     to the engine's own CSV writer. It comes back as the Write Table To File row, with its path,
#     its table, its separator and its first-line answer.
#   - THE APPEND. Append To File emits an open in READ_WRITE, a guard, a seek to the end, a write and
#     a close. It comes back as the Append To File row - and so does the same five-line run written
#     by hand, whatever the file was held in and whether the text went out through store_string or
#     store_line.
#
# WHY THE SHAPES ARE DERIVED, NEVER TYPED OUT. Each shape below is the SHIPPED template of the row it
# means, filled with sentinels instead of values, so the spelling this family recognises cannot drift
# from the spelling the compiler writes. A run is claimed by matching that shape, and the row's own
# template is then filled with the values that came out of it and compared against the run BYTE FOR
# BYTE before anything is handed back - so a run this family claims is one it can write again exactly
# as it found it.
#
# WHY THESE ARE NOT LIFT-TABLE ENTRIES. The table engine stores a claimed run by splicing each
# statement's own spelling, one statement at a time. Every run here re-uses a value in more than one
# place - the local the file is held in, five times over; the table, twice inside one statement - and
# a spliced run would carry that value as a `{slot}` in the line it was captured from and as literal
# text everywhere else, so editing the row would move it in one line and leave the others behind.
# Each run is therefore matched against the whole shape at once, which is also what makes the byte
# comparison above possible.
#
# WHAT IS DELIBERATELY NOT CLAIMED:
#   - A HAND-WRITTEN CSV READ LOOP (a list, an open, a while, an append into the list) is left
#     exactly as it was. It is not one statement, so it cannot be the value of a Set, and reading it
#     as one would mean writing the sheet's own lambda over somebody's loop - a different program,
#     which the lossless contract forbids. It opens as the honest statements it is.
#   - A HAND-WRITTEN TABLE WRITE. That run names five locals after the row's own uid, and those names
#     are not values of the row, so a chain that calls them something else cannot be written back
#     from what the row holds. It opens as the statements it is.
#   - A WRITE OR AN APPEND WITH NO GUARD around the handle. Both rows emit `if <file>:` because
#     FileAccess.open answers null on a bad path; a run without it crashes where the row would not,
#     so claiming it would say a line does something it does not do.
@tool
class_name EventForgeFileRunsLift
extends RefCounted

## The module the two table templates and the first-line question's two words live on. Loaded by path
## rather than by class name so the importer never waits on the editor's class cache - the rule every
## other file here follows.
const TableACEs := preload("res://addons/eventforge/registration/modules/table_aces.gd")

## Where the shipped Append To File descriptor lives, and the id it is registered under. Read off the
## descriptor rather than copied, so the append this family recognises is the append the compiler
## writes.
const FILE_MODULE_PATH: String = "res://addons/eventforge/registration/modules/file_aces.gd"
const APPEND_ACE_ID: String = "AppendTextFile"

## The rows the other two runs mean. Frozen with the descriptors they name.
const WRITE_ACE_ID: String = "WriteFileTable"
const SET_ACE_ID: String = "SetVar"
const SET_LOCAL_ACE_ID: String = "SetLocalVarTyped"

## The templates the two Set rows emit. Named here because the read is the one run whose row does not
## carry a template of its own: the expression rides in the value slot, and that slot re-emits it.
const SET_TEMPLATE: String = "{var_name} = {value}"
const SET_LOCAL_TEMPLATE: String = "var {name}: {var_type} = {value}"

## The cheap first refusals. Every statement of every opened file reaches this family, so each run is
## ruled out on a substring before a pattern is built: a table read opens on the lambda head, and the
## write and the append both open on a handle being taken.
const READ_MARK: String = "(func(__path: String) -> Array:"
const OPEN_MARK: String = "FileAccess.open("

## The sentinels a shape carries where a value goes. Each is wrapped in control characters so that no
## spelling a real file could hold is ever mistaken for one, and each says in words which slot it
## stands for.
const HEAD_MARK: String = "\u0001head\u0001"
const PATH_MARK: String = "\u0001path\u0001"
const SEPARATOR_MARK: String = "\u0001separator\u0001"
const TABLE_MARK: String = "\u0001table\u0001"
const UID_MARK: String = "\u0001uid\u0001"
const LOCAL_MARK: String = "\u0001local\u0001"
const TEXT_MARK: String = "\u0001text\u0001"

## What the shipped append template holds its handle in, and the head that declares it. Both are
## swapped for sentinels below, which is what lets the same five-line shape be recognised whatever a
## hand-written run called its file.
const APPEND_LOCAL: String = "__file_{uid}"
const APPEND_HEAD: String = "var __file_{uid} = "

## The two calls a run writes its text with. A spelling, not a template: both are replacements over
## the shipped append, so neither can drift from what the row itself emits.
const APPEND_CALLS: Array[String] = ["store_string", "store_line"]

## Compiled patterns, held for the life of the session: this family is asked about every statement of
## every opened file, and compiling a shape per line was the whole cost of doing this by hand.
static var _regexes: Dictionary = {}

## The shapes and their patterns, built once. Building one asks the registry for a descriptor, so
## they are worth holding rather than rebuilding per statement.
static var _shapes: Dictionary = {}


## The row a run of statements means, or {} when this family does not claim it. `lines` is the
## function body as the lifter holds it, `index` the statement the run would open on, and `depth` the
## indentation that statement is written at. Returns {ace_id, params, template, consumed}.
static func match_run(lines: PackedStringArray, index: int, depth: int) -> Dictionary:
	var opener: String = _statement_at(lines, index, depth)
	if opener.is_empty():
		return {}
	if opener.contains(READ_MARK):
		return _match_read(lines, index, depth)
	if not opener.contains(OPEN_MARK):
		return {}
	var written: Dictionary = _match_write(lines, index, depth)
	return written if not written.is_empty() else _match_append(lines, index, depth)


# ── the table read ──────────────────────────────────────────────────────────


## The Set whose value is a Table Of File expression, or {} when the run is not one. The row is the
## Set it was authored as, and the expression rides back in its value slot - the slot that re-emits
## it - so none of the fifteen lines is stored anywhere a reader cannot edit.
static func _match_read(lines: PackedStringArray, index: int, depth: int) -> Dictionary:
	for answer: String in [TableACEs.HEADERS_NAMED, TableACEs.HEADERS_PLAIN]:
		var run: Dictionary = _claim(lines, index, depth, _read_shape(answer),
			[HEAD_MARK, PATH_MARK, SEPARATOR_MARK])
		if run.is_empty():
			continue
		var head: String = str((run["values"] as Dictionary)[HEAD_MARK])
		var text: String = str(run["text"])
		var claimed: Dictionary = _read_row(head, text.substr(head.length() + 3),
			int(run["consumed"]), text)
		if not claimed.is_empty():
			return claimed
	return {}


## The Set row a claimed read becomes: the plain assignment a sheet variable is written with, or the
## typed local a temporary is declared as. Both are shipped rows with a value slot, so the run is
## re-emitted through that slot rather than through anything this family stores.
static func _read_row(head: String, value: String, consumed: int, run: String) -> Dictionary:
	var declared: RegExMatch = _regex(
		"^var (?<name>[A-Za-z_][A-Za-z0-9_]*): (?<var_type>.+)$").search(head)
	if declared != null:
		return _verified(SET_LOCAL_ACE_ID, SET_LOCAL_TEMPLATE,
			{"name": declared.get_string("name"), "var_type": declared.get_string("var_type"),
				"value": value}, consumed, run)
	return _verified(SET_ACE_ID, SET_TEMPLATE, {"var_name": head, "value": value}, consumed, run)


## The whole assignment with sentinels where its head, its path and its separator go: the Table Of
## File expression as the compiler writes it, with the Set's own head in front of it.
static func _read_shape(answer: String) -> String:
	var key: String = "read:%s" % answer
	if not _shapes.has(key):
		_shapes[key] = "%s = %s" % [HEAD_MARK, ActionCodegen._apply_template(
			TableACEs.file_table_expression(),
			{"path": PATH_MARK, "separator": SEPARATOR_MARK, "headers": answer})]
	return str(_shapes[key])


# ── the table write ─────────────────────────────────────────────────────────


## The Write Table To File run, or {} when the statements are not one. Both answers of the row's
## first-line question are tried, and the answer that matched becomes the row's own - so a file
## written without a header line reopens saying so rather than quietly gaining one.
static func _match_write(lines: PackedStringArray, index: int, depth: int) -> Dictionary:
	for answer: String in [TableACEs.HEADERS_NAMED, TableACEs.HEADERS_PLAIN]:
		var run: Dictionary = _claim(lines, index, depth, _write_shape(answer),
			[UID_MARK, PATH_MARK, TABLE_MARK, SEPARATOR_MARK])
		if run.is_empty():
			continue
		var values: Dictionary = run["values"]
		var params: Dictionary = {"path": str(values[PATH_MARK]), "table": str(values[TABLE_MARK]),
			"separator": str(values[SEPARATOR_MARK]), "headers": answer}
		# The uid is baked onto the template exactly as the dock bakes it when a row is applied, so
		# the lifted row is the row the picker would have authored - and the first-line answer stays a
		# LIVE choice, because the template keeps the segment marks that choice picks between.
		var template: String = TableACEs.write_table_template().replace("{uid}",
			str(values[UID_MARK]))
		return _verified(WRITE_ACE_ID, template, params, int(run["consumed"]), str(run["text"]))
	return {}


## The Write Table To File template with sentinels where its uid, its path, its table and its
## separator go, in one answer of the first-line question.
static func _write_shape(answer: String) -> String:
	var key: String = "write:%s" % answer
	if not _shapes.has(key):
		_shapes[key] = ActionCodegen._apply_template(TableACEs.write_table_template(),
			{"uid": UID_MARK, "path": PATH_MARK, "table": TABLE_MARK,
				"separator": SEPARATOR_MARK, "headers": answer})
	return str(_shapes[key])


# ── the append ──────────────────────────────────────────────────────────────


## The Append To File run, or {} when the statements are not one. Four spellings are tried: the
## handle declared with its type and without, and the text written with store_string or store_line.
## The local is not a value of the row - it is matched, agreed on across all five lines, and written
## back exactly as it was found, which is what lets a run somebody wrote by hand come back as the
## sentence it is without a byte of it moving.
static func _match_append(lines: PackedStringArray, index: int, depth: int) -> Dictionary:
	for head: String in _append_heads():
		for call: String in APPEND_CALLS:
			var shape: String = _append_shape(head, call)
			var run: Dictionary = _claim(lines, index, depth, shape,
				[LOCAL_MARK, PATH_MARK, TEXT_MARK])
			if run.is_empty():
				continue
			var values: Dictionary = run["values"]
			var template: String = shape.replace(PATH_MARK, "{path}").replace(TEXT_MARK,
				"{text}").replace(LOCAL_MARK, str(values[LOCAL_MARK]))
			var claimed: Dictionary = _verified(APPEND_ACE_ID, template,
				{"path": str(values[PATH_MARK]), "text": str(values[TEXT_MARK])},
				int(run["consumed"]), str(run["text"]))
			if not claimed.is_empty():
				return claimed
	return {}


## The two ways a run declares the handle: the way the row itself writes it, and the same line with
## the type written out, which is what the style guide asks of hand-written code.
static func _append_heads() -> Array[String]:
	return ["var %s = " % LOCAL_MARK, "var %s: FileAccess = " % LOCAL_MARK]


## The Append To File template with sentinels where its local, its path and its text go, declared the
## way this spelling declares it and writing the text the way this spelling writes it. Every one of
## those is a replacement over the SHIPPED template, so the guard, the seek and the close stay the
## row's own.
static func _append_shape(head: String, call: String) -> String:
	var key: String = "append:%s:%s" % [head, call]
	if not _shapes.has(key):
		var template: String = _append_template()
		if template.is_empty():
			return ""
		_shapes[key] = ActionCodegen._apply_template(template,
			{"path": PATH_MARK, "text": TEXT_MARK}).replace(APPEND_HEAD, head).replace(
			APPEND_LOCAL, LOCAL_MARK).replace(".store_string(", ".%s(" % call)
	return str(_shapes[key])


## The shipped Append To File template, off the descriptor that ships it. Empty when the module
## cannot be read, which makes every append shape refuse rather than guess at a spelling - and an
## empty answer is deliberately NOT remembered, so a read that failed once does not silence the
## family for the rest of the session.
static func _append_template() -> String:
	if _shapes.has("append"):
		return str(_shapes["append"])
	var module: GDScript = load(FILE_MODULE_PATH)
	if module == null:
		return ""
	for descriptor: ACEDescriptor in module.get_descriptors():
		if descriptor.ace_id == APPEND_ACE_ID:
			_shapes["append"] = str(descriptor.codegen_template)
			return str(_shapes["append"])
	return ""


# ── the pieces ──────────────────────────────────────────────────────────────


## The run at `index` read as `shape`, or {} when it is not that shape. Returns {values, text,
## consumed}: `values` is one entry per sentinel, `text` the run exactly as it is written, with its
## indentation relative to the statement it opens on.
##
## A sentinel appearing more than once must read the SAME text every time, which is how a shape says
## "the handle opened on the first line is the one closed on the last" without that name ever
## becoming a value of the row.
static func _claim(lines: PackedStringArray, index: int, depth: int, shape: String,
		marks: Array) -> Dictionary:
	if shape.is_empty():
		return {}
	var shape_lines: PackedStringArray = shape.split("\n")
	var written: PackedStringArray = PackedStringArray()
	for step: int in shape_lines.size():
		var indent: int = _indent_of(shape_lines[step])
		var text: String = _statement_at(lines, index + step, depth + indent)
		if text.is_empty():
			return {}
		written.append("\t".repeat(indent) + text)
	var run: String = "\n".join(written)
	var hit: RegExMatch = _regex(_pattern_of(shape, marks)).search(run)
	if hit == null:
		return {}
	var values: Dictionary = {}
	for mark: String in marks:
		var agreed: String = _agreed(hit, mark, shape)
		if agreed.is_empty():
			return {}
		values[mark] = agreed
	return {"values": values, "text": run, "consumed": shape_lines.size()}


## What every occurrence of one sentinel read, when they all read the same thing - and "" when the
## sentinel was not in the shape at all, or its occurrences disagree, either of which refuses the run.
static func _agreed(hit: RegExMatch, mark: String, shape: String) -> String:
	var occurrences: int = shape.count(mark)
	if occurrences == 0:
		return ""
	var agreed: String = ""
	for occurrence: int in occurrences:
		var name: String = _group_name(mark, occurrence)
		if hit.get_start(name) < 0:
			return ""
		var read: String = hit.get_string(name)
		if occurrence == 0:
			agreed = read
		elif read != agreed:
			return ""
	return agreed


## A shape as one anchored pattern: every character of it taken literally, and every sentinel a
## capture of its own. Each OCCURRENCE gets a group of its own rather than a back reference, because
## a run is only refused once its occurrences have been compared - and a back reference would refuse
## it inside the engine, where nothing could say which of them disagreed.
static func _pattern_of(shape: String, marks: Array) -> String:
	var key: String = "pattern:%s" % shape
	if _shapes.has(key):
		return str(_shapes[key])
	var pattern: String = ""
	var rest: String = shape
	var counts: Dictionary = {}
	while true:
		var at: int = -1
		var found: String = ""
		for mark: String in marks:
			var where: int = rest.find(mark)
			if where >= 0 and (at < 0 or where < at):
				at = where
				found = mark
		if at < 0:
			pattern += _escaped(rest)
			break
		var seen: int = int(counts.get(found, 0))
		counts[found] = seen + 1
		pattern += _escaped(rest.substr(0, at)) + "(?<%s>.+?)" % _group_name(found, seen)
		rest = rest.substr(at + found.length())
	_shapes[key] = "^%s$" % pattern
	return str(_shapes[key])


## One occurrence of one sentinel as a capture name: the sentinel's own word with its control
## characters dropped, numbered, because a group name has to be a bare identifier.
static func _group_name(mark: String, occurrence: int) -> String:
	return "%s_%d" % [mark.replace("\u0001", ""), occurrence]


## Every character of a text taken literally by a pattern. Written out rather than borrowed because
## Godot's RegEx has no escape of its own, and a shape holds `{}`, `()` and `[]` of real code.
static func _escaped(text: String) -> String:
	var escaped: String = ""
	for index: int in text.length():
		var character: String = text[index]
		if "\\^$.|?*+()[]{}".contains(character):
			escaped += "\\"
		escaped += character
	return escaped


## The row a claimed run becomes, once the row has WRITTEN THE RUN AGAIN and got the same bytes back.
## That comparison is the whole guarantee: a run this family hands back is one the compiler re-emits
## exactly as it was found, so a sheet that opens somebody's file and saves it untouched leaves it
## untouched. A row that fails it is not handed back at all, and the statements stay as they are.
static func _verified(ace_id: String, template: String, params: Dictionary, consumed: int,
		run: String) -> Dictionary:
	if EventForgeLiftTable.emit_row(template, params, EventForgeLiftTable.DEFAULT_PROVIDER,
			ace_id) != run:
		return {}
	return {"ace_id": ace_id, "params": params, "template": template, "consumed": consumed}


## How many tabs a line of a shape is written at.
static func _indent_of(line: String) -> int:
	var tabs: int = 0
	while tabs < line.length() and line[tabs] == "\t":
		tabs += 1
	return tabs


## One line of the body at exactly `indent` tabs, or "" when the line is blank, absent, shallower or
## deeper than that. Deeper matters: every one of these runs has a block inside it, and each of those
## lines is claimed at the one indentation it is allowed to be at.
static func _statement_at(lines: PackedStringArray, index: int, indent: int) -> String:
	if index < 0 or index >= lines.size():
		return ""
	var line: String = lines[index]
	if not line.begins_with("\t".repeat(indent)):
		return ""
	var rest: String = line.substr(indent)
	if rest.begins_with("\t") or rest.strip_edges().is_empty():
		return ""
	return rest


## A pattern, compiled once and held.
static func _regex(pattern: String) -> RegEx:
	if not _regexes.has(pattern):
		_regexes[pattern] = RegEx.create_from_string(pattern)
	return _regexes[pattern]
