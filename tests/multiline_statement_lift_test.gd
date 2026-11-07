# A statement written over several lines - a call whose closing bracket stands on a line of its own, an
# assignment whose value is spread over lines, a line ended with a backslash - opens as ONE action with its
# value read on one line, keeps the layout it was written with, and saves back to the same lines.
@tool
class_name MultilineStatementLiftTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const NAME := "multiline_statement_lift_test"
const SOURCE := """extends Node2D


func _ready() -> void:
	for i in 3:
		var bullet := Bullet.new()
		bullet.position = Vector2(
			randf_range(0, 10) + 5,
			randf_range(0, 20)
		)
	spawn_ring(
		Vector2(10, 20),
		Color.PURPLE,
		2.0
	)
	draw_rect(
		Rect2(1, 2, 3, 4),
		Color.RED,
		true
	)
	hide()
	var total := first_value + \\
		second_value
"""


static func run() -> bool:
	var ok: bool = true
	var sheet: EventSheetResource = SUPPORT.reopen(SOURCE)
	var statements: Array = []
	_collect_actions(sheet.events, statements)
	var raw_count: int = 0
	for item: Variant in statements:
		if item is RawCodeRow:
			raw_count += 1
	ok = SUPPORT.check(NAME, "no multi-line statement stays a block of code", raw_count, 0) and ok
	var position_set: ACEAction = _action_with_param(statements, "randf_range(0, 10) + 5")
	ok = SUPPORT.check(NAME, "the assignment reads as one action", position_set != null, true) and ok
	if position_set != null:
		var value: String = ""
		for param_value: Variant in position_set.params.values():
			if str(param_value).begins_with("Vector2("):
				value = str(param_value)
		ok = SUPPORT.check(NAME, "its value reads on one line", value, "Vector2(randf_range(0, 10) + 5, randf_range(0, 20))") and ok
		ok = SUPPORT.check(NAME, "it remembers the lines it was written over", position_set.written_params.is_empty(), false) and ok
	var ring: ACEAction = _action_with_param(statements, "Color.PURPLE")
	ok = SUPPORT.check(NAME, "a call with its bracket on its own line reads as one action", ring != null, true) and ok
	# A call whose parts are separate parameters of its verb keeps its lines for the whole statement.
	var drawn: ACEAction = _action_with_param(statements, "Color.RED")
	ok = SUPPORT.check(NAME, "a call with several parameters reads as one action that keeps its lines", drawn != null and not drawn.written_params.is_empty(), true) and ok
	ok = SUPPORT.check(NAME, "the file is written back byte for byte", SUPPORT.reemit(SOURCE, "user://multiline_statement_out.gd"), SOURCE) and ok
	# Edited on one line, the value is written as it now reads.
	if ring != null:
		for param_id: Variant in ring.params.keys():
			if str(ring.params[param_id]).contains("Color.PURPLE"):
				ring.params[param_id] = "Vector2(1, 2), Color.RED, 3.0"
		sheet.external_source_path = "user://multiline_statement_edit.gd"
		var edited: String = SUPPORT.compile_output(sheet, "user://multiline_statement_edit.gd")
		ok = SUPPORT.check(NAME, "an edited value is written on one line", edited.contains("spawn_ring(Vector2(1, 2), Color.RED, 3.0)"), true) and ok
	return ok


static func _collect_actions(rows: Array, into: Array) -> void:
	for row: Variant in rows:
		if row is EventRow:
			into.append_array((row as EventRow).actions)
			_collect_actions((row as EventRow).sub_events, into)
		elif row is EventGroup:
			_collect_actions((row as EventGroup).events, into)


static func _action_with_param(actions: Array, fragment: String) -> ACEAction:
	for item: Variant in actions:
		if item is ACEAction:
			for param_value: Variant in (item as ACEAction).params.values():
				if str(param_value).contains(fragment):
					return item as ACEAction
	return null
