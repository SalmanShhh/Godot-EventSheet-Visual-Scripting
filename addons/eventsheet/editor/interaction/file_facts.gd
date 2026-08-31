# Godot EventSheets - the FILES band: what this sheet touches on disk.
#
# A sheet that reads a spreadsheet, writes a log and asks the player to pick a file says all three of
# those things in rows halfway down it, one parameter at a time. The three facts a reader wants
# before opening any of those rows are the same three every time: what it WRITES, what it READS, and
# whether it stops to ASK. This band is those facts, said once at the top, in the sheet's own words -
# the same place the reader already looks for `extends` and `@tool`.
#
# WHY IT IS WORTH A BAND. A path is the one parameter whose consequences are invisible from the row:
# a write under res:// works in the editor and fails once the game is exported, and a read of a file
# nobody wrote yet is a silent empty string. The Doctor raises both as findings; the band is what
# makes them visible before there is anything to find, because the paths are all in one place.
#
# HOW A ROW IS CLASSIFIED - derived, never a list of ace_ids. The path parameters are found by their
# `file_path` hint, and the row is read as a write or a read by the ENGINE CALLS its emitted template
# makes. So a path field a pack ships is on the band the day the pack ships, and a verb renamed
# tomorrow is still classified by what it compiles to. `copy_absolute` and `rename_absolute` are in
# both lists on purpose: they genuinely read one path and write another, and the honest reading of a
# copy row is that its paths are read and written.
#
# THE ASK is found the same way: a row whose verb is declared on a FileDialog is a row that stops and
# asks the player, whatever it is called.
#
# THE BAND SCALE LAW. A band lists what the sheet USES and counts the rest. Four paths get four
# bands; twelve get four and one band saying how many more, because a head longer than the sheet is
# not a head.
#
# JOINED AT OPEN, NEVER A SCAN. The rows are already in memory - this walks them once and opens
# nothing. No file is read to find out what a file row says.
#
# PURE + STATIC, like every other band reader: a sheet goes in and a list of readings comes out, so
# the whole band is pinned headless without a canvas.
@tool
class_name EventSheetFileFacts
extends RefCounted

## The parameter hint every path field carries. One hint, so a pack's path field is found exactly as
## a builtin one is.
const PATH_HINT: String = "file_path"

## The class a verb is declared on when the verb's whole job is to ask the player for a file.
const CHOOSER_CLASS: String = "FileDialog"

## How many paths the band names before it starts counting.
const SHOWN_LIMIT: int = 4

## The engine calls that CHANGE something on disk. Read off the row's emitted template, so this is a
## vocabulary of Godot's own file API rather than a list of the plugin's verbs.
const WRITING_CALLS: Array[String] = [
	"FileAccess.WRITE", "FileAccess.READ_WRITE", ".store_", "make_dir",
	"remove_absolute", "rename_absolute", "copy_absolute", "ZIPPacker",
]

## The engine calls that only LOOK. `rename_absolute` and `copy_absolute` appear in both lists
## because a copy really does read one path and write another.
const READING_CALLS: Array[String] = [
	"get_file_as_", "file_exists", "dir_exists", "get_files_at", "get_directories_at",
	"FileAccess.READ)", "FileAccess.READ,", "get_csv_line", "ZIPReader",
	"rename_absolute", "copy_absolute",
]

## What a path is doing in this sheet, as the band says it.
const TOUCH_WRITTEN: String = "written"
const TOUCH_READ: String = "read"
const TOUCH_BOTH: String = "read and written"


## The band's readings, in first-mention order: one entry per path this sheet touches, then one
## counting the paths it touches that the band did not name, then the ask if the sheet has one.
## Empty for a sheet that touches no file, which is what keeps the head of every other sheet exactly
## as it was.
##
## Each entry is the shape the head's scene bands read - `{"value", "echo", "reference"}` - so the
## band model needs to learn nothing about files to show it.
static func bands(sheet: EventSheetResource) -> Array[Dictionary]:
	var readings: Array[Dictionary] = []
	var touched: Array[Dictionary] = touched_paths(sheet)
	for index: int in range(mini(touched.size(), SHOWN_LIMIT)):
		var entry: Dictionary = touched[index]
		readings.append({
			"value": reading(entry),
			"echo": str(entry.get("echo", "")),
			"reference": "",
		})
	var counted: int = touched.size() - SHOWN_LIMIT
	if counted > 0:
		readings.append({
			"value": EventSheetL10n.translate("and %d more path(s)") % counted,
			"echo": "", "reference": "",
		})
	var asked: Dictionary = asks_the_player(sheet)
	if not asked.is_empty():
		readings.append({
			"value": EventSheetL10n.translate("asks the player to pick a file"),
			"echo": str(asked.get("echo", "")),
			"reference": "",
		})
	return readings


## Every path this sheet touches, first mention first, each as
##   {"path", "touch", "echo"}
## where `touch` is one of the three words above and `echo` is the row's own first emitted line. A
## path named by two rows, one reading and one writing, is ONE entry saying both.
##
## TWO PLACES A PATH CAN BE, and both are read. A path field is the obvious one, and it is read
## FIRST so that a path built out of an expression is shown exactly as the field spells it. But a
## path can also sit inside a value - the table read is one expression with the file quoted in the
## middle of it - and it can sit inside a verbatim block somebody wrote by hand. Those are found by
## reading the row's own emitted line for a `res://` or `user://` literal, which is the same text the
## echo comes from and costs nothing extra.
static func touched_paths(sheet: EventSheetResource) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var seen: Dictionary = {}
	if sheet == null:
		return found
	var rows: Array[Dictionary] = []
	_walk_rows(sheet.events, rows)
	for entry: Variant in sheet.functions:
		var event_function: EventFunction = entry as EventFunction
		if event_function != null:
			_walk_rows(event_function.events, rows)
	for row: Dictionary in rows:
		var text: String = str(row.get("text", ""))
		var touch: String = touch_of(text)
		if touch.is_empty():
			continue
		var echo: String = str(row.get("echo", ""))
		for path: String in row.get("paths", PackedStringArray()):
			_record(found, seen, path, touch, echo)
		for path: String in place_literals(text):
			_record(found, seen, path, touch, echo)
	return found


## The `res://` and `user://` paths quoted inside one line of emitted code, in the order they appear.
## Only the two places a Godot path can begin with are recognised, so an ordinary string is never
## mistaken for a file.
static func place_literals(text: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var at: int = text.find("\"")
	while at >= 0:
		var closing: int = text.find("\"", at + 1)
		if closing < 0:
			break
		var quoted: String = text.substr(at + 1, closing - at - 1)
		if (quoted.begins_with("res://") or quoted.begins_with("user://")) and not found.has(quoted):
			found.append(quoted)
		at = text.find("\"", closing + 1)
	return found


## What one row's emitted template does to the path it holds, or "" when it touches no file at all -
## a verb carrying a path field that only builds a string out of it, say.
static func touch_of(template: String) -> String:
	var writes: bool = _mentions(template, WRITING_CALLS)
	var reads: bool = _mentions(template, READING_CALLS)
	if writes and reads:
		return TOUCH_BOTH
	if writes:
		return TOUCH_WRITTEN
	return TOUCH_READ if reads else ""


## One path's reading: the path exactly as the row holds it, and the word for what the sheet does to
## it. The path is not shortened to its file name - `user://` and `res://` are the whole point of
## reading a path at the top of a sheet, and a band showing `save.dat` would hide the one fact worth
## showing.
static func reading(entry: Dictionary) -> String:
	return "%s - %s" % [str(entry.get("path", "")),
		EventSheetL10n.translate(str(entry.get("touch", "")))]


## The row that stops and asks the player for a file, or {} when this sheet never does. Only the
## first is reported: the fact is that this sheet asks, and it is one fact however many rows say it.
static func asks_the_player(sheet: EventSheetResource) -> Dictionary:
	if sheet == null:
		return {}
	var found: Array[Dictionary] = []
	_walk_chooser_rows(sheet.events, found)
	for entry: Variant in sheet.functions:
		var event_function: EventFunction = entry as EventFunction
		if event_function != null:
			_walk_chooser_rows(event_function.events, found)
	return found[0] if not found.is_empty() else {}


## A path field's value without the quotes it is held in - the band says the path, not the literal,
## because the literal is what the echo is for. A path built out of an expression has no quotes to
## strip and rides through as the expression it is.
static func bare(value: String) -> String:
	return value.strip_edges().trim_prefix("\"").trim_suffix("\"").strip_edges()


# -- the pieces ------------------------------------------------------------------------------


## One path recorded once. The same file written by one row and read by another is ONE fact about ONE
## file, so the entry the first row opened gains the second row's word rather than growing a band of
## its own.
static func _record(found: Array[Dictionary], seen: Dictionary, raw_path: String, touch: String,
		echo: String) -> void:
	var path: String = bare(raw_path)
	if path.is_empty():
		return
	if seen.has(path):
		var already: Dictionary = found[int(seen[path])]
		if str(already.get("touch", "")) != touch:
			already["touch"] = TOUCH_BOTH
		return
	seen[path] = found.size()
	found.append({"path": path, "touch": touch, "echo": echo})


## Every row of one list, in sheet order, as
##   {"text", "echo", "paths"}
## where `text` is the row's emitted code with its own values filled in, `echo` its first line, and
## `paths` the values of its path FIELDS. Groups and sub-events are walked into, because a group is a
## bracket around rows rather than another sheet, and a verbatim block is a row of the file like any
## other - a hand-written FileAccess call is a file this sheet touches.
static func _walk_rows(items: Array, found: Array[Dictionary]) -> void:
	for item: Variant in items:
		if item is EventGroup:
			_walk_rows((item as EventGroup).child_rows(), found)
			continue
		if item is RawCodeRow:
			var code: String = (item as RawCodeRow).code
			found.append({"text": code, "echo": _first_line_of(code), "paths": PackedStringArray()})
			continue
		var event_row: EventRow = item as EventRow
		if event_row == null:
			continue
		for lane: Array in [event_row.conditions, event_row.actions]:
			for entry: Variant in lane:
				var read: Dictionary = _row_reading(entry as Resource)
				if not read.is_empty():
					found.append(read)
		_walk_rows(event_row.sub_events, found)


## One row's emitted text, its first line, and the values of its path fields. The verb's descriptor
## says which parameters are paths; the row says what is in them.
static func _row_reading(ace: Resource) -> Dictionary:
	if ace == null:
		return {}
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor(
		str(ace.get("provider_id")), str(ace.get("ace_id")))
	if descriptor == null:
		return {}
	var params: Variant = ace.get("params")
	var values: Dictionary = params as Dictionary if params is Dictionary else {}
	# The row's OWN template when it has one: a template is baked onto a row when it is applied, and
	# that baked copy is the one whose `{uid}` was filled in. Falling back to the descriptor's covers
	# a row built in memory, which is what a test does.
	var baked: String = str(ace.get("codegen_template"))
	var text: String = baked if not baked.strip_edges().is_empty() else descriptor.codegen_template
	for key: Variant in values.keys():
		text = text.replace("{%s}" % str(key), str(values[key]))
	var paths: PackedStringArray = PackedStringArray()
	for entry: Variant in descriptor.params:
		var param: ACEParam = entry as ACEParam
		if param != null and param.hint == PATH_HINT:
			paths.append(str(values.get(param.id, param.default_value)))
	return {"text": text, "echo": _first_line_of(text), "paths": paths}


## The first line of an emitted block, with the node-target marks resolved - the line the file holds
## rather than a sentence about it.
static func _first_line_of(text: String) -> String:
	if text.strip_edges().is_empty():
		return ""
	return text.split("\n")[0].replace("{target.}", "").replace("{target}", "self").strip_edges()


## The rows whose verb is declared on a file chooser, in sheet order. Groups are walked into, because
## a group is a bracket around rows rather than another sheet.
static func _walk_chooser_rows(items: Array, found: Array[Dictionary]) -> void:
	for item: Variant in items:
		if item is EventGroup:
			_walk_chooser_rows((item as EventGroup).child_rows(), found)
			continue
		var event_row: EventRow = item as EventRow
		if event_row == null:
			continue
		for lane: Array in [event_row.conditions, event_row.actions]:
			for entry: Variant in lane:
				var ace: Resource = entry as Resource
				if ace == null:
					continue
				var descriptor: ACEDescriptor = ACERegistry.find_descriptor(
					str(ace.get("provider_id")), str(ace.get("ace_id")))
				if descriptor == null or descriptor.node_type != CHOOSER_CLASS:
					continue
				found.append({"ace_id": descriptor.ace_id,
					"echo": "%s.%s" % [CHOOSER_CLASS, descriptor.codegen_template.split("\n")[0]]})
		_walk_chooser_rows(event_row.sub_events, found)


## True when a template makes any of these calls.
static func _mentions(template: String, calls: Array[String]) -> bool:
	for call_text: String in calls:
		if template.contains(call_text):
			return true
	return false
