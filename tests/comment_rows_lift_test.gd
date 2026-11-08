# The `#` notes a file keeps open as comment rows: a run above a function or over a declaration is one
# comment row written back exactly where it sits, a note among the statements of a function is a comment
# row between its actions, and the lines that are not notes (`##` documentation, a `#region` fence) stay
# as they were. The file saves back byte for byte.
@tool
class_name CommentRowsLiftTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const NAME := "comment_rows_lift_test"
const SOURCE := """extends Node2D
# This demo moves a lot of things
# without using nodes.

# The speed.
const SPEED = 3
#region Setup
var count := 0
#endregion


# Draws every bullet at once.
# One call each.
func _draw() -> void:
	# Place bullets randomly.
	# Keep them inside.
	run_something(1, 2, 3)
	hide()
	# between
	show()


## Documented for the manual.
func _ready() -> void:
	hide()
"""


static func run() -> bool:
	var ok: bool = true
	var sheet: EventSheetResource = SUPPORT.reopen(SOURCE)
	var notes: Array = []
	var blocks_with_notes: int = 0
	for row: Variant in sheet.events:
		if row is CommentRow and (row as CommentRow).written_in_place:
			notes.append((row as CommentRow).text)
		elif row is RawCodeRow and not (row as RawCodeRow).code.contains("#region") and not (row as RawCodeRow).code.contains("##"):
			for line: String in (row as RawCodeRow).code.split("\n"):
				if line.begins_with("# "):
					blocks_with_notes += 1
	ok = SUPPORT.check(NAME, "the notes of the file open as comment rows", notes, [
		"This demo moves a lot of things\nwithout using nodes.", "The speed.", "Draws every bullet at once.\nOne call each."]) and ok
	ok = SUPPORT.check(NAME, "no note is left inside a block of code", blocks_with_notes, 0) and ok
	var spacing: Array = []
	var empty_blocks: int = 0
	for row: Variant in sheet.events:
		if row is CommentRow and (row as CommentRow).written_in_place:
			spacing.append([(row as CommentRow).blank_lines_before, (row as CommentRow).blank_lines_after])
		elif row is RawCodeRow and (row as RawCodeRow).code.strip_edges().is_empty():
			empty_blocks += 1
	ok = SUPPORT.check(NAME, "the empty lines around a note ride on it instead of leaving rows of their own", [spacing, empty_blocks], [[[0, 1], [0, 0], [2, 0]], 0]) and ok
	var in_function: PackedStringArray = PackedStringArray()
	for row: Variant in sheet.events:
		if row is EventRow:
			for action: Variant in (row as EventRow).actions:
				if action is ACEAction and not (action as ACEAction).note_above.is_empty():
					in_function.append((action as ACEAction).note_above)
				elif action is CommentRow:
					in_function.append("(row) " + (action as CommentRow).text)
	ok = SUPPORT.check(NAME, "the notes among a function's statements are the notes of the actions below them", in_function, PackedStringArray([
		"Place bullets randomly.\nKeep them inside.", "between"])) and ok
	ok = SUPPORT.check(NAME, "the file is written back byte for byte", SUPPORT.reemit(SOURCE, "user://comment_rows_out.gd"), SOURCE) and ok
	return ok
