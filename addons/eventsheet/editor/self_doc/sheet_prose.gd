# Godot EventSheets - which comment rows are the book, and which ones never leave the sheet.
#
# GDScript already made this decision, for every file anybody ever wrote: a line opening `##` is
# documentation the engine renders, a line opening a single `#` is a private note to whoever opens
# the file. The sheet adopts that rule whole rather than inventing a "publish this comment" flag -
# there is no second field, no second store, and no way for a row and the line it writes to disagree
# about which one it is.
#
# THE SPLIT CHANGES ONLY WHERE LINES ARE READ, NEVER WHAT IS WRITTEN. Emission is untouched by this
# file: a `#` row and a `##` row both write exactly the marker they carry, byte for byte, and a sheet
# opened and saved is identical whether anything here ever ran. What the split decides is who is
# ALLOWED to read a line - the manual and the project-wide find read `##` rows and nothing else.
#
# A `#` LINE IS NOT DEBT. It is not counted as an undescribed thing, it does not appear in coverage,
# and nothing nudges anybody to promote it. The one exception is a note that opens `TODO` or `FIXME`,
# which is listed once as a task chip - a to-do list, which is a different thing from a book.
@tool
class_name EventSheetSheetProse
extends RefCounted

## What a paragraph entry carries: the prose itself, the place in the sheet it was written (the
## function or group it sits in, "" at sheet level), and the marker it writes. Frozen with the manual
## page's shape, because an exported page lands in version control.
const PARAGRAPH_KEYS: PackedStringArray = ["text", "where", "marker"]


## Every DOCUMENTATION paragraph in one sheet, in sheet order - the prose the manual sets between its
## figures. Each entry is {text, where, marker}. Private notes are not here, and there is no argument
## that makes them appear.
static func paragraphs(sheet: EventSheetResource) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	if sheet == null:
		return found
	_walk(sheet.events, "", found)
	for function_entry: Variant in sheet.functions:
		if function_entry is EventFunction:
			var event_function: EventFunction = function_entry as EventFunction
			_walk(event_function.events if not event_function.events.is_empty() else event_function.rows,
				event_function.function_name, found)
	return found


## Every task note in one sheet, in sheet order - the `TODO` and `FIXME` lines, whichever marker they
## carry. Each entry is {text, where, word}. This is the ONLY reading a private note has, and it is a
## list of things to do rather than anything a reader of the game's manual is shown.
static func tasks(sheet: EventSheetResource) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	if sheet == null:
		return found
	_walk_tasks(sheet.events, "", found)
	for function_entry: Variant in sheet.functions:
		if function_entry is EventFunction:
			var event_function: EventFunction = function_entry as EventFunction
			_walk_tasks(event_function.events if not event_function.events.is_empty() else event_function.rows,
				event_function.function_name, found)
	return found


## THE GATE every reader outside this file asks: may this comment row's words leave the sheet?
## One function, so the manual, the find and an export cannot each answer it slightly differently.
static func is_readable(comment_row: CommentRow) -> bool:
	if comment_row == null or not comment_row.enabled:
		return false
	if not comment_row.is_documentation():
		return false
	return not comment_row.text.strip_edges().is_empty()


## How many documentation paragraphs a sheet carries. Stated as a fact beside the described count; a
## sheet's private notes are deliberately absent from this number and from every number near it.
static func paragraph_count(sheet: EventSheetResource) -> int:
	return paragraphs(sheet).size()


## The recursive walk for prose: a group replaces `where` for its own children, so a paragraph reads
## as belonging to the chapter it was written in.
static func _walk(rows: Array, where: String, into: Array[Dictionary]) -> void:
	for entry: Variant in rows:
		if entry is EventGroup:
			var group: EventGroup = entry as EventGroup
			_walk(group.events if not group.events.is_empty() else group.rows,
				EventSheetDescriptions.group_name_of(group), into)
		elif entry is CommentRow:
			var comment_row: CommentRow = entry as CommentRow
			if is_readable(comment_row):
				into.append({
					"text": comment_row.text.strip_edges(),
					"where": where,
					"marker": comment_row.emit_marker(),
				})
		elif entry is EventRow:
			var row: EventRow = entry as EventRow
			for action_entry: Variant in row.actions:
				if action_entry is CommentRow and is_readable(action_entry as CommentRow):
					into.append({
						"text": (action_entry as CommentRow).text.strip_edges(),
						"where": where,
						"marker": (action_entry as CommentRow).emit_marker(),
					})
			_walk(row.sub_events, where, into)


## The recursive walk for tasks, shaped exactly like the prose walk so a note cannot be found by one
## and missed by the other.
static func _walk_tasks(rows: Array, where: String, into: Array[Dictionary]) -> void:
	for entry: Variant in rows:
		if entry is EventGroup:
			var group: EventGroup = entry as EventGroup
			_walk_tasks(group.events if not group.events.is_empty() else group.rows,
				EventSheetDescriptions.group_name_of(group), into)
		elif entry is CommentRow:
			_append_task(entry as CommentRow, where, into)
		elif entry is EventRow:
			var row: EventRow = entry as EventRow
			for action_entry: Variant in row.actions:
				if action_entry is CommentRow:
					_append_task(action_entry as CommentRow, where, into)
			_walk_tasks(row.sub_events, where, into)


## One task chip, when this row opens with a task word.
static func _append_task(comment_row: CommentRow, where: String, into: Array[Dictionary]) -> void:
	if comment_row == null or not comment_row.enabled:
		return
	var word: String = comment_row.task_word()
	if word.is_empty():
		return
	into.append({"text": comment_row.text.strip_edges(), "where": where, "word": word})
