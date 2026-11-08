# Godot EventSheets - a `#` note among a function's statements is the NOTE OF THE ACTION BELOW IT.
#
# The lines a person wrote directly above a statement explain that statement, so they ride on it
# (ACEAction.note_above): dragging the action drags its note, the sheet draws the note quietly beside
# the action, and the file comes back byte for byte. A TODO, a note kept apart by an empty line, a
# commented-out statement and a `##` line are not that - they stay the comment rows they have always been.
@tool
class_name NoteAboveActionTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "note_above_action_test"

const SOURCE := """extends Node2D

var lives = 3
var score = 0


func hit() -> void:
	lives -= 1

	# remember to flash
	# then reset the score
	score = 0
	print("hit")
	# TODO: fix later
	print("later")

	# kept apart from the line below

	print("end")
	if lives < 0:
		# inside the branch
		print("dead")
	#spaceless note
	print("tail")
"""


static func run() -> bool:
	var sheet: EventSheetResource = SUPPORT.reopen(SOURCE, true, "")
	var event: EventRow = _function_event(sheet)
	var rows: Array = [["the function opens as an event", event != null, true]]
	if event != null:
		var carried: Array = []
		var comment_rows: Array = []
		for body_row: Variant in _body_rows(sheet):
			for entry: Variant in (body_row as EventRow).actions:
				if entry is ACEAction and not (entry as ACEAction).note_above.is_empty():
					carried.append([(entry as ACEAction).note_above, (entry as ACEAction).note_above_marker])
				elif entry is CommentRow:
					comment_rows.append((entry as CommentRow).text)
		rows.append(["the notes touching an action ride on it", carried,
			[["remember to flash\nthen reset the score", ""], ["inside the branch", ""], ["spaceless note", "#"]]])
		rows.append(["a TODO and a note kept apart by an empty line stay comment rows", comment_rows,
			["TODO: fix later", "kept apart from the line below"]])
	rows.append(["the file saves back to the same bytes", SUPPORT.reemit(SOURCE, "user://note_above_probe.gd") == SOURCE, true])
	# Moving the action moves its note: put `score = 0` first and the note is still directly above it.
	var moved: EventSheetResource = SUPPORT.reopen(SOURCE, true, "")
	var moved_event: EventRow = _function_event(moved)
	if moved_event != null:
		var at: int = -1
		for index: int in moved_event.actions.size():
			var candidate: Variant = moved_event.actions[index]
			if candidate is ACEAction and not (candidate as ACEAction).note_above.is_empty():
				at = index
				break
		if at > 0:
			var action: Variant = moved_event.actions[at]
			moved_event.actions.remove_at(at)
			moved_event.actions.insert(0, action)
			var written: String = SUPPORT.compile_output(moved, "user://note_above_moved.gd")
			rows.append(["the moved action writes its note directly above it", written.contains("\t# remember to flash\n\t# then reset the score\n\tscore = 0\n\tlives -= 1\n"), true])
			rows.append(["the note is written once", written.count("# remember to flash"), 1])
			rows.append(["the line it left is not written with the note", written.contains("\t# remember to flash\n\tlives -= 1"), false])
	return SUPPORT.pins(P, rows)


static func _function_event(sheet: EventSheetResource) -> EventRow:
	if sheet == null:
		return null
	for function_row: Variant in sheet.functions:
		if function_row is EventFunction and str((function_row as EventFunction).function_name) == "hit":
			for body_row: Variant in (function_row as EventFunction).events:
				if body_row is EventRow:
					return body_row as EventRow
	return null


## Every event of the `hit` function's body, in order, each followed by the events nested under it.
static func _body_rows(sheet: EventSheetResource) -> Array:
	var rows: Array = []
	for function_row: Variant in sheet.functions:
		if function_row is EventFunction:
			for body_row: Variant in (function_row as EventFunction).events:
				_collect(body_row, rows)
	return rows


static func _collect(entry: Variant, rows: Array) -> void:
	if entry is EventRow:
		rows.append(entry)
		for sub: Variant in (entry as EventRow).sub_events:
			_collect(sub, rows)
