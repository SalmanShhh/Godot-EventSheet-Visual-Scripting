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
# THE ASK is found the same way, in the two shapes an ask can take: a row whose verb is declared on a
# FileDialog, and a row whose emitted line opens the PLATFORM'S own chooser. Either is a row that
# stops and asks the player, whatever it is called.
#
# A WATCH IS ITS OWN READING. A folder read once and a folder read every two seconds for the rest of
# the session are not the same thing to say about a sheet, so a row that starts a watch reads as
# "watching <folder> every N s" - the interval included, because that is the half a path cannot say.
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
## a builtin one is - and the SAME one the Doctor's fixes derive their path parameters from, spelled
## once in EventForgeFilePlaces so the band and the fix can never disagree about which field is a
## path.
const PATH_HINT: String = EventForgeFilePlaces.PATH_HINT

## The class a verb is declared on when the verb's whole job is to ask the player for a file.
const CHOOSER_CLASS: String = "FileDialog"

## The call a verb makes when it opens the PLATFORM'S own chooser rather than building a node for it.
const CHOOSER_CALL: String = "DisplayServer.file_dialog_show("

## The call a row makes when it starts WATCHING a folder - the Folder Watcher pack's own verb, whose
## name is a shipped public id exactly as an ace_id is. A watch is not a read that happened once: it
## is a directory read every few seconds for as long as the game runs, which is the one thing about a
## sheet worth knowing before opening the row that started it. Matched on the CALL, the same way the
## platform chooser above is, so a row that compiles to this line is on the band whatever it is named.
const WATCH_CALL: String = "watch_folder("

## The two values pulled out of that call - the folder, then the seconds between looks. Read off the
## row's own emitted line rather than off parameter ids, so the band and the code cannot drift.
const WATCH_PATTERN: String = "watch_folder\\(\\s*(?<folder>.*?)\\s*,\\s*(?<seconds>[^,()]*?)\\s*\\)"

## The shortest gap a watch can really have, and the way the band spells it. A zero or negative
## interval would be a directory read every single frame, which is nobody's idea of an interval, so
## the shipped watcher floors it - and a band printing the row's `0` beside a watcher keeping a tenth
## of a second is the band saying something untrue about the sheet. The number is the watcher's own;
## the pair of them is pinned in the suite so the two can never drift apart silently.
const SHORTEST_LOOK: float = 0.1
const SHORTEST_LOOK_TEXT: String = "0.1"

## How many paths the band names before it starts counting.
const SHOWN_LIMIT: int = 4

## The engine calls that CHANGE something on disk. Read off the row's emitted template, so this is a
## vocabulary of Godot's own file API rather than a list of the plugin's verbs.
const WRITING_CALLS: Array[String] = [
	"FileAccess.WRITE", "FileAccess.READ_WRITE", ".store_", "make_dir",
	"remove_absolute", "rename_absolute", "copy_absolute", "ZIPPacker",
	# The engine's own resource writer, which is how a scene or a `.tres` reaches disk. Without it a
	# row that saves a branch of the running game as a scene file touched a path the band could not
	# see, which is the one thing the band exists to show.
	"ResourceSaver.save(",
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
## counting the paths it touches that the band did not name, then every folder it WATCHES, then the
## ask if the sheet has one.
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
	# THE SAME SCALE LAW THE PATHS OBEY. A sheet that starts ten watches would otherwise wear ten
	# bands on top of four paths and the ask, and a head longer than the sheet is not a head.
	var watches: Array[Dictionary] = watched_folders(sheet)
	for index: int in range(mini(watches.size(), SHOWN_LIMIT)):
		var watch: Dictionary = watches[index]
		readings.append({
			"value": EventSheetL10n.translate("watching %s every %s s") % [
				str(watch.get("folder", "")), str(watch.get("seconds", ""))],
			"echo": str(watch.get("echo", "")),
			"reference": "",
		})
	var unwatched: int = watches.size() - SHOWN_LIMIT
	if unwatched > 0:
		readings.append({
			"value": EventSheetL10n.translate("and %d more watched folder(s)") % unwatched,
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
			_walk_rows(_function_rows(event_function), rows)
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
			_walk_chooser_rows(_function_rows(event_function), found)
	return found[0] if not found.is_empty() else {}


## One function's rows. A function built by the editor holds `events`; one lifted out of a
## hand-written file may hold `rows` instead, and the Doctor's own walk has always read both - a band
## that read one of them would go quiet on exactly the files this plugin is for.
static func _function_rows(event_function: EventFunction) -> Array:
	return event_function.events if not event_function.events.is_empty() else event_function.rows


## Every folder this sheet WATCHES, first mention first, each as {"folder", "seconds", "echo"}. A
## watch is the one file fact a path alone cannot tell you: the same folder read once and read every
## two seconds forever are different things to do to somebody's disk, so the interval is part of the
## reading rather than a detail inside the row.
##
## The same folder started twice at the same interval is one fact; started at two different intervals
## it is two, because those really are two different things the sheet does.
static func watched_folders(sheet: EventSheetResource) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	if sheet == null:
		return found
	var rows: Array[Dictionary] = []
	_walk_rows(sheet.events, rows)
	for entry: Variant in sheet.functions:
		var event_function: EventFunction = entry as EventFunction
		if event_function != null:
			_walk_rows(_function_rows(event_function), rows)
	var seen: Dictionary = {}
	var matcher: RegEx = RegEx.create_from_string(WATCH_PATTERN)
	for row: Dictionary in rows:
		var text: String = str(row.get("text", ""))
		if not text.contains(WATCH_CALL):
			continue
		for hit: RegExMatch in matcher.search_all(text):
			var reading: Dictionary = {
				"folder": bare(hit.get_string("folder")),
				"seconds": honoured_seconds(hit.get_string("seconds")),
				"echo": hit.get_string().strip_edges(),
			}
			var key: String = "%s|%s" % [reading["folder"], reading["seconds"]]
			if seen.has(key):
				continue
			seen[key] = true
			found.append(reading)
	return found


## The interval the watcher will really keep, as the band says it. A row asking for a gap shorter than
## the floor gets the floor, so a band reading `every 0 s` beside a watcher looking ten times a second
## is a head that is wrong about its own sheet. Only a NUMBER is answered for: an interval held in an
## expression is one nothing here can work out, and it rides through as the expression it is.
static func honoured_seconds(written: String) -> String:
	var text: String = written.strip_edges()
	if not text.is_valid_float():
		return text
	return text if text.to_float() >= SHORTEST_LOOK else SHORTEST_LOOK_TEXT


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
				# A verbatim block can sit IN a lane as well as between events - a hand-written
				# FileAccess call under a trigger is a file this sheet touches exactly as one at the
				# top of it is, and it carries no descriptor to be read through.
				if entry is RawCodeRow:
					var lane_code: String = (entry as RawCodeRow).code
					found.append({"text": lane_code, "echo": _first_line_of(lane_code),
						"paths": PackedStringArray()})
					continue
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
		# A CHOOSER SOMEBODY WROTE BY HAND IS THE SAME FACT. The band already reads verbatim blocks
		# for the paths in them, and the ask is found by the LINE it opens rather than by an id, so a
		# hand-written `DisplayServer.file_dialog_show` is a row that stops and asks the player
		# exactly as the verb is.
		if item is RawCodeRow:
			_record_chooser_code((item as RawCodeRow).code, found)
			continue
		var event_row: EventRow = item as EventRow
		if event_row == null:
			continue
		for lane: Array in [event_row.conditions, event_row.actions]:
			for entry: Variant in lane:
				if entry is RawCodeRow:
					_record_chooser_code((entry as RawCodeRow).code, found)
					continue
				var ace: Resource = entry as Resource
				if ace == null:
					continue
				var descriptor: ACEDescriptor = ACERegistry.find_descriptor(
					str(ace.get("provider_id")), str(ace.get("ace_id")))
				if descriptor == null:
					continue
				if descriptor.node_type == CHOOSER_CLASS:
					found.append({"ace_id": descriptor.ace_id,
						"echo": "%s.%s" % [CHOOSER_CLASS, descriptor.codegen_template.split("\n")[0]]})
					continue
				# A row that opens the PLATFORM'S own chooser is the same fact said another way, and
				# it is declared on no node at all. Found by the call it makes rather than by an id,
				# so a row added later is on the band the day it compiles to this line.
				var opens: String = _chooser_call_line(str(descriptor.codegen_template))
				if not opens.is_empty():
					found.append({"ace_id": descriptor.ace_id, "echo": opens})
		_walk_chooser_rows(event_row.sub_events, found)


## One verbatim block's ask, if it holds one. Filed with no `ace_id`, because there is no verb here
## to name - what the band says is that this sheet asks, and the echo is the line that does it.
static func _record_chooser_code(code: String, found: Array[Dictionary]) -> void:
	var opens: String = _chooser_call_line(code)
	if not opens.is_empty():
		found.append({"ace_id": "", "echo": opens})


## The line of a template that opens the platform's own file chooser, trimmed of its indentation, or
## "" when the template opens none. The echo shows THAT line rather than the template's first, which
## on an Ask row is the branch that chooses between the two choosers.
static func _chooser_call_line(template: String) -> String:
	for line: String in template.split("\n"):
		if line.contains(CHOOSER_CALL):
			return line.strip_edges()
	return ""


## True when a template makes any of these calls.
static func _mentions(template: String, calls: Array[String]) -> bool:
	for call_text: String in calls:
		if template.contains(call_text):
			return true
	return false
