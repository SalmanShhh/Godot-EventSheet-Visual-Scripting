@tool
class_name EventSheetGenericRows
extends RefCounted

# HOW MUCH OF AN OPENED FILE READS IN THE SHEET'S OWN WORDS, and how much of it merely opened.
#
# The reading-coverage chip beside this one answers "did it open" - what share of the file arrived as
# rows instead of a wall of code. That number reached 100% on the editor's own source long before the
# rows said anything: a file can be all rows and still read as `Call method`, `Call method`, `Set x to
# thing` three hundred times over, which is the file's shape with none of its meaning.
#
# So this counts the OTHER number: a GENERIC row - one whose sentence carries no words of its own -
# against every row in the file. Three shapes, and only three, because each one is a row a reader
# learns nothing from:
#
#   1. A raw literal entry. One line of a list or a dictionary, standing alone as its own row.
#   2. A bare call. `queue_redraw()`, `_dock._refresh_after_edit()` - a row that says "something was
#      called" and stops.
#   3. A set to a bare function name. `var found = _collect_rows()` - the name of the call is the
#      whole sentence, so the row says the function's name back to the reader and nothing else.
#
# A row that came from the vocabulary is never generic: it was written with words on purpose, and
# whether those words are GOOD is a question for a reader, not for a counter. And a script block is
# not generic either - it is not a row, it is the code that never became one, which the coverage
# number beside this already counts.
#
# THE WALK MIRRORS THE RENDERER'S DISPATCH, for the same reason the coverage walk does: a measure
# taken over how rows are STORED would go on reporting a clean file while the canvas filled up with
# rows that say nothing.

## A call standing alone as a whole statement: `thing()`, `a.b.c(1, 2)`. Anchored at both ends, so an
## assignment, a comparison or an `await` is not one.
const BARE_CALL_PATTERN: String = "^[A-Za-z_][A-Za-z0-9_]*(\\.[A-Za-z_][A-Za-z0-9_]*)*\\(.*\\)$"

## An assignment whose whole right-hand side is one snake_case call or name: `var x = _do_thing()`,
## `total = collected_rows`. The name is the only word the row has.
const BARE_NAME_SET_PATTERN: String = "^(var\\s+)?[A-Za-z_][A-Za-z0-9_.\\[\\]\"']*(\\s*:\\s*[A-Za-z0-9_.\\[\\]]+)?\\s*=\\s*[a-z_][a-z0-9_]*(\\(\\s*\\))?$"

static var _bare_call: RegEx = null
static var _bare_name_set: RegEx = null


## The measure of one sheet: {"generic", "rows", "percent"}. `percent` is the share of rows that say
## nothing of their own, rounded down - the number the gate pins and the Doctor reports.
static func measure(sheet: EventSheetResource) -> Dictionary:
	var tally: Dictionary = {"generic": 0, "rows": 0}
	if sheet == null:
		return {"generic": 0, "rows": 0, "percent": 0}
	_walk(sheet.events, true, tally)
	for function_entry: Variant in sheet.functions:
		if function_entry is EventFunction:
			_walk((function_entry as EventFunction).events, false, tally)
	var rows: int = int(tally["rows"])
	var generic: int = int(tally["generic"])
	var percent: int = 0 if rows <= 0 else int(floor(100.0 * float(generic) / float(rows)))
	return {"generic": generic, "rows": rows, "percent": percent}


## The reading health of the editor's own source, per role group:
##   [{role, files, percent, worst_percent, worst_path}]
## in ROLE_ORDER, skipping a group with no files. `per_role_limit` bounds how many files of a group
## are opened, because opening one means running the importer and the compiler over it - this answers
## a question a reader asked for, and it has to answer it in a moment rather than in a minute.
static func health_by_role(entries_by_role: Dictionary, per_role_limit: int = 6) -> Array[Dictionary]:
	var report: Array[Dictionary] = []
	for role: String in EventSheetThisEditor.ROLE_ORDER:
		var entries: Array = entries_by_role.get(role, [])
		if entries.is_empty():
			continue
		var generic: int = 0
		var rows: int = 0
		var opened: int = 0
		var worst: int = 0
		var worst_path: String = ""
		for entry_value: Variant in entries:
			if opened >= per_role_limit:
				break
			var path: String = str((entry_value as Dictionary).get("path", ""))
			var sheet: EventSheetResource = GDScriptImporter.new().import_external(path)
			if sheet == null:
				continue
			opened += 1
			var measured: Dictionary = measure(sheet)
			generic += int(measured["generic"])
			rows += int(measured["rows"])
			if int(measured["percent"]) >= worst:
				worst = int(measured["percent"])
				worst_path = path
		report.append({
			"role": role,
			"files": opened,
			"percent": 0 if rows <= 0 else int(floor(100.0 * float(generic) / float(rows))),
			"worst_percent": worst,
			"worst_path": worst_path,
		})
	return report


## One health line's words - what this group of the editor reads like, and which file in it reads
## worst. Pure, so the Doctor's message and a test's expectation are the same string.
static func health_message(entry: Dictionary) -> String:
	return EventSheetL10n.translate("%s: %d files read, %d%% of their rows say nothing of their own. Worst: %s at %d%%.") % [
		EventSheetThisEditor.role_heading(str(entry.get("role", ""))),
		int(entry.get("files", 0)), int(entry.get("percent", 0)),
		str(entry.get("worst_path", "")).get_file(), int(entry.get("worst_percent", 0))]


## True when one verbatim row's code reads as a row with no words of its own. Pure and public, so the
## gate, the Doctor and a test all ask the same question of the same string.
static func is_generic_code(code: String) -> bool:
	if ViewportRowBuilder.is_literal_part(code):
		return true
	if code.contains("\n"):
		return false
	var text: String = code.strip_edges()
	if text.is_empty() or text.begins_with("#"):
		return false
	_ensure_patterns()
	if _bare_call.search(text) != null:
		return true
	return _bare_name_set.search(text) != null


static func _ensure_patterns() -> void:
	if _bare_call == null:
		_bare_call = RegEx.create_from_string(BARE_CALL_PATTERN)
	if _bare_name_set == null:
		_bare_name_set = RegEx.create_from_string(BARE_NAME_SET_PATTERN)


## The one walk both numbers come from. A row is one thing a reader looks at: an event line, one of
## its conditions, one action, one declaration, one verbatim row. A script block counts as a row that
## is not generic - it is code the sheet never claimed, which the coverage measure reports instead.
static func _walk(items: Array, top_level: bool, tally: Dictionary) -> void:
	for item: Variant in items:
		if item is RawCodeRow:
			var raw: RawCodeRow = item as RawCodeRow
			tally["rows"] = int(tally["rows"]) + 1
			if not EventSheetReadingCoverage.renders_as_block(raw, top_level) and is_generic_code(raw.code):
				tally["generic"] = int(tally["generic"]) + 1
		elif item is EventRow:
			var event: EventRow = item as EventRow
			tally["rows"] = int(tally["rows"]) + 1 + event.conditions.size()
			_walk(event.actions, false, tally)
			_walk(event.sub_events, false, tally)
		elif item is EventFunction:
			tally["rows"] = int(tally["rows"]) + 1
			_walk((item as EventFunction).events, false, tally)
		elif item is EventGroup:
			_walk((item as EventGroup).events, top_level, tally)
		elif item != null:
			tally["rows"] = int(tally["rows"]) + 1
