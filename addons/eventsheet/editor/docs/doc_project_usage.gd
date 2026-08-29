# EventSheet - EventSheetDocProjectUsage: the door swinging back.
#
# A reference entry is the same entry in everybody's copy of the plugin. The one thing it can say
# that no written page ever can is where THIS reader already uses the verb - and once it says that,
# their own game is the example gallery, with real rows instead of invented ones.
#
# TWO KINDS OF EVIDENCE, because a project holds two kinds of sheet and neither one may be ignored:
#
#   a sheet there is a MODEL of   the open tabs (the live version of their files - a row added a
#                                 second ago exists only in memory) and the `.tres` sheets, walked
#                                 exactly: a row uses the verb when its ace id says so.
#   a `.gd` nobody has opened     matched on TEXT, against the literal runs of the verb's own
#                                 codegen template. `.gd` is the default sheet format, so skipping
#                                 these would answer "used twice" for a project that uses it thirty
#                                 times - and lifting every script in a project to be exact would
#                                 cost seconds at the moment the reader pressed F1.
#
# The text pass can only ever be as precise as the template it matches: a verb whose template has no
# literal run of its own contributes no text evidence at all rather than matching everything, and a
# run shared with a sibling verb can be generous. It is evidence about the reader's own project,
# offered as a row they can open and read for themselves, which is the point.
#
# NOTHING IS STORED. The walk reads the sheets the project already lists and the script files that
# are already on disk, joined at the moment the entry is drawn, and there is no index of verb uses
# anywhere in the plugin for this to disagree with. Bounded rather than cached: the caps below keep
# the join inside a keypress, and the walks are sorted so two opens list the same rows in the same
# order.
@tool
class_name EventSheetDocProjectUsage
extends RefCounted

## How many sheets the entry lists. Past this the answer stops being "here are your uses" and
## becomes a second search results panel the reader did not ask for; the total keeps counting.
const MAX_SHEETS := 8

## How many rows one sheet contributes to the list. Same reason, one level in.
const MAX_ROWS_PER_SHEET := 6

## How many project scripts the text pass reads. A file read is cheap and a project is not
## unbounded, but a reader pressing F1 is waiting, so the walk has a ceiling it reports rather than
## a cost that grows with the repository.
const MAX_SCRIPTS := 400

## The shortest literal run of a codegen template that counts as evidence. A few characters of
## punctuation - "(", " = ", ", " - match nearly every line of GDScript ever written, so a run has
## to be long enough to be a word before it is allowed to answer for a whole project.
const MIN_SEGMENT_LENGTH := 4


## The literal runs of a codegen template, in the order they appear: everything outside a `{...}`
## placeholder that is long enough to be evidence. Empty for a template that is all placeholder,
## which is the honest answer - there is nothing about such a line to recognise.
static func template_segments(template: String) -> PackedStringArray:
	var segments: PackedStringArray = PackedStringArray()
	var run: String = ""
	var depth: int = 0
	for character: String in template:
		if character == "{":
			depth += 1
			if run.length() >= MIN_SEGMENT_LENGTH:
				segments.append(run)
			run = ""
			continue
		if character == "}":
			depth = maxi(depth - 1, 0)
			continue
		if depth == 0:
			run += character
	if run.length() >= MIN_SEGMENT_LENGTH:
		segments.append(run)
	return segments


## True when one source line carries every literal run of a template, in order. The in-order test is
## what keeps `set_deferred("visible", true)` from answering for a template whose runs happen to
## appear on it back to front.
static func line_matches(line: String, segments: PackedStringArray) -> bool:
	if segments.is_empty():
		return false
	var at: int = 0
	for segment: String in segments:
		var found: int = line.find(segment, at)
		if found < 0:
			return false
		at = found + segment.length()
	return true


## Every use of a verb the project can show, as [{sheet, count, rows}] sorted by sheet path, where
## each row is {line, preview}. Pure over its inputs, so the suite pins the whole answer without a
## project around it:
##   `sheets`   {path: EventSheetResource} - the sheets there is a model of, walked exactly
##   `sources`  {path: String} - the raw text of the scripts nobody has opened
static func uses(provider_id: String, ace_id: String, segments: PackedStringArray,
		sheets: Dictionary, sources: Dictionary) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var paths: PackedStringArray = PackedStringArray(sheets.keys())
	paths.sort()
	for path: String in paths:
		var sheet: EventSheetResource = sheets[path] as EventSheetResource
		if sheet == null:
			continue
		var rows: Array[Resource] = EventSheetDocUsage.rows_using(sheet, provider_id, ace_id)
		if rows.is_empty():
			continue
		found.append({"sheet": path, "count": rows.size(), "rows": _lines_of(sheet, rows)})
	var script_paths: PackedStringArray = PackedStringArray(sources.keys())
	script_paths.sort()
	for path: String in script_paths:
		if sheets.has(path):
			continue
		var rows: Array[Dictionary] = _text_rows(str(sources[path]), segments)
		if rows.is_empty():
			continue
		found.append({"sheet": path, "count": rows.size(), "rows": rows})
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a["sheet"]) < str(b["sheet"]))
	return found


## What the entry prints over the list. Reads as a fact about the reader's own game, and says so
## plainly when the answer is none: a verb the project never uses is not a failure to report, it is
## simply one they have not needed yet.
static func sentence(total: int, sheet_count: int) -> String:
	if total <= 0:
		return EventSheetL10n.translate("Not used anywhere in this project yet.")
	if total == 1:
		return EventSheetL10n.translate("Used once in your project - open it.")
	if sheet_count <= 1:
		return EventSheetL10n.translate("Used %d times in your project - open one.") % total
	return EventSheetL10n.translate("Used %d times across %d sheets in your project - open one.") \
		% [total, sheet_count]


## The totals of a gathered list, as {total, sheets}, so a caller counts once rather than twice.
static func totals(found: Array[Dictionary]) -> Dictionary:
	var total: int = 0
	for entry: Dictionary in found:
		total += int(entry.get("count", 0))
	return {"total": total, "sheets": found.size()}


## The label of one row in the list: the file, and the line inside it. Pure, so the wording is
## pinned without a panel.
static func row_label(sheet_path: String, line: int) -> String:
	var file_name: String = sheet_path.get_file()
	if line <= 0:
		return file_name
	return "%s:%d" % [file_name, line]


## The list, trimmed to what the entry draws: at most MAX_SHEETS sheets, at most MAX_ROWS_PER_SHEET
## rows each. The COUNTS are left alone - the sentence above still reports every use, so a trimmed
## list never becomes a smaller number.
static func trimmed(found: Array[Dictionary]) -> Array[Dictionary]:
	var shown: Array[Dictionary] = []
	for entry: Dictionary in found:
		if shown.size() >= MAX_SHEETS:
			break
		var rows: Array = (entry.get("rows", []) as Array).duplicate()
		if rows.size() > MAX_ROWS_PER_SHEET:
			rows.resize(MAX_ROWS_PER_SHEET)
		var copy: Dictionary = entry.duplicate()
		copy["rows"] = rows
		shown.append(copy)
	return shown


## The rows of a modelled sheet, stamped with the line each one emits at. The line is what survives
## the jump: opening a sheet builds a brand new resource tree, so the row found here and the row in
## the opened tab are different objects, and a line number is a position the editor can land on.
static func _lines_of(sheet: EventSheetResource, rows: Array[Resource]) -> Array[Dictionary]:
	var references: Array = []
	for row: Resource in rows:
		references.append({"row": row})
	EventSheetFindReferences.stamp_source_lines(sheet, references)
	var lines: Array[Dictionary] = []
	for reference: Variant in references:
		lines.append({"line": int((reference as Dictionary).get("line", 0)), "preview": ""})
	return lines


## The lines of one unopened script that carry the verb's template.
static func _text_rows(source: String, segments: PackedStringArray) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if segments.is_empty() or source.is_empty():
		return rows
	var lines: PackedStringArray = source.split("\n")
	for index: int in range(lines.size()):
		var line: String = lines[index]
		if line_matches(line, segments):
			rows.append({"line": index + 1, "preview": line.strip_edges()})
	return rows


# ── The live walk ─────────────────────────────────────────────────────────────────────────────


## Everything the project can show about a verb, gathered from what is already on disk and already
## open. `open_sheets` is {path: EventSheetResource} for the tabs, which the caller holds; the
## `.tres` sheets and the project's own scripts are found here.
static func gather(definition: ACEDefinition, open_sheets: Dictionary = {}) -> Array[Dictionary]:
	if definition == null:
		return []
	var sheets: Dictionary = open_sheets.duplicate()
	for path: String in EventSheetProjectFind.list_project_sheets():
		if sheets.has(path):
			continue
		var sheet: EventSheetResource = load(path) as EventSheetResource
		if sheet != null:
			sheets[path] = sheet
	var segments: PackedStringArray = template_segments(EventSheetDocExplain.ships_as(definition))
	var sources: Dictionary = {}
	if not segments.is_empty():
		var read: int = 0
		for path: String in EventSheetFindReferences.project_scripts():
			if read >= MAX_SCRIPTS:
				break
			if sheets.has(path):
				continue
			read += 1
			var text: String = FileAccess.get_file_as_string(path)
			if not text.is_empty():
				sources[path] = text
	return uses(definition.provider_id, definition.id, segments, sheets, sources)
