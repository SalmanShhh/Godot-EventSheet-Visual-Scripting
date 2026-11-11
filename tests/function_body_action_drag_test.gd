# Godot EventSheets - dragging an action inside a function's body moves it.
#
# A hand-written function opens as an event whose statements read as the head's own actions. The
# drop handler used to look for an EventRow behind the head row and found an EventFunction, so a
# drag within the body (or into / out of it) did nothing at all. Pinned here through the real
# press -> motion -> release path, then through the drop handler for the cross-event moves, each
# followed by a save and a reopen that must come back byte for byte, and by one undo step.
@tool
class_name FunctionBodyActionDragTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "function_body_action_drag_test"
const PROBE := "user://function_body_drag_probe.gd"
const REOPEN := "user://function_body_drag_reopen.gd"

const SOURCE := """extends Node2D

var lives = 3
var score = 0


func hit() -> void:
	lives -= 1
	# flash the sprite
	score += 10
	print("hit")


func other() -> void:
	print("other")
"""

const REORDERED := """extends Node2D

var lives = 3
var score = 0


func hit() -> void:
	lives -= 1
	print("hit")
	# flash the sprite
	score += 10


func other() -> void:
	print("other")
"""

const MOVED_OUT := """extends Node2D

var lives = 3
var score = 0


func hit() -> void:
	lives -= 1
	print("hit")


func other() -> void:
	# flash the sprite
	score += 10
	print("other")
"""

const MOVED_IN := """extends Node2D

var lives = 3
var score = 0


func hit() -> void:
	lives -= 1
	# flash the sprite
	score += 10
	print("hit")
	print("other")


func other() -> void:
	pass
"""


## The editor's undo manager in miniature: one UndoRedo, executed on commit.
class History:
	extends RefCounted
	var history: UndoRedo = UndoRedo.new()


	func create_action(action_name: String, merge_mode: int = UndoRedo.MERGE_DISABLE, _context: Object = null) -> void:
		history.create_action(action_name, merge_mode)


	func add_do_method(object: Object, method: StringName, ...args: Array) -> void:
		history.add_do_method(Callable(object, method).bindv(args))


	func add_undo_method(object: Object, method: StringName, ...args: Array) -> void:
		history.add_undo_method(Callable(object, method).bindv(args))


	func commit_action(execute: bool = true) -> void:
		history.commit_action(execute)


	func has_undo() -> bool:
		return history.has_undo()


	func has_redo() -> bool:
		return history.has_redo()


	func undo() -> void:
		history.undo()


	func redo() -> void:
		history.redo()


	func clear_history() -> void:
		history.clear_history()


static func run() -> bool:
	var rows: Array = []
	var sheet: EventSheetResource = SUPPORT.reopen(SOURCE, true, "")
	sheet.external_source_path = PROBE
	var hit: EventFunction = _function(sheet, "hit")
	rows.append(["the function opens with its statements as actions", _action_count(hit), 3])
	if hit == null:
		return SUPPORT.pins(P, rows)
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(sheet)
	var history := History.new()
	editor.set_undo_redo_manager(history)
	var viewport: EventSheetViewport = editor.get_viewport_control()
	var index: int = _flat_index(viewport, hit)
	rows.append(["the function head is a row", index >= 0, true])
	if index < 0:
		editor.free()
		return SUPPORT.pins(P, rows)
	var width: float = viewport.get_canvas_logical_width()
	viewport._layout_builder.get_or_build_row_layout(index, width, viewport._get_font(), viewport._get_font_size())
	var head: EventRowData = viewport._row_at(index)
	var second: Rect2 = _action_rect(head, 1)
	var third: Rect2 = _action_rect(head, 2)
	rows.append(["the action cells are laid out", second.size.x > 0.0 and third.size.x > 0.0, true])

	# The real drag: the second action (with its note) onto the lower half of the third.
	var start: Vector2 = second.get_center()
	var drop: Vector2 = Vector2(third.get_center().x, third.position.y + third.size.y * 0.8)
	viewport._input_handlers.handle_mouse_button(_button(start, true))
	rows.append(["pressing an action in a function body starts a drag", viewport._drag_ace_entries.is_empty(), false])
	viewport._input_handlers.handle_mouse_motion(_motion(drop))
	rows.append(["the drop marker lands in the function body", viewport._drag_ace_target_row_index, index])
	viewport._input_handlers.handle_mouse_button(_button(drop, false))
	var written: String = SUPPORT.compile_output(sheet, PROBE)
	rows.append(["the dragged action lands after the one below it", written, REORDERED])
	rows.append(["the reordered file reopens and saves back to the same bytes", SUPPORT.reemit(written, REOPEN), written])
	rows.append(["the drag is one undo step", history.has_undo(), true])
	history.undo()
	rows.append(["Undo puts the body back as it was", SUPPORT.compile_output(editor._current_sheet, PROBE), SOURCE])
	editor.free()

	rows.append_array(_locked_rows())
	rows.append_array(_cross_rows(true))
	rows.append_array(_cross_rows(false))
	return SUPPORT.pins(P, rows)


## Moves the noted action out of `hit` into `other` (out), or the `other` print into `hit` (in), through
## the drop handler the viewport's release calls.
static func _cross_rows(out: bool) -> Array:
	var label: String = "out of the function" if out else "into the function"
	var sheet: EventSheetResource = SUPPORT.reopen(SOURCE, true, "")
	sheet.external_source_path = PROBE
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(sheet)
	var history := History.new()
	editor.set_undo_redo_manager(history)
	var viewport: EventSheetViewport = editor.get_viewport_control()
	var hit: EventFunction = _function(sheet, "hit")
	var other: EventFunction = _function(sheet, "other")
	var rows: Array = []
	var hit_row: EventRowData = _row_for(viewport, hit)
	var other_row: EventRowData = _row_for(viewport, other)
	rows.append(["both ends of the move are rows (%s)" % label, hit_row != null and other_row != null, true])
	if hit_row == null or other_row == null:
		editor.free()
		return rows
	if out:
		editor._ace_apply._on_viewport_ace_drop_requested(
			[{"source_resource": hit, "kind": "action", "ace_index": 1}],
			other_row, "action", 0, "before", false)
	else:
		editor._ace_apply._on_viewport_ace_drop_requested(
			[{"source_resource": other, "kind": "action", "ace_index": 0}],
			hit_row, "action", 2, "after", false)
	var written: String = SUPPORT.compile_output(sheet, PROBE)
	rows.append(["the action moves %s" % label, written, MOVED_OUT if out else MOVED_IN])
	rows.append(["and the file reopens byte for byte (%s)" % label, SUPPORT.reemit(written, REOPEN), written])
	rows.append(["one undo step (%s)" % label, history.has_undo(), true])
	history.undo()
	rows.append(["Undo restores the file (%s)" % label, SUPPORT.compile_output(editor._current_sheet, PROBE), SOURCE])
	editor.free()
	return rows


## A function the user locked by hand refuses the drop in words, and the file is untouched.
static func _locked_rows() -> Array:
	var sheet: EventSheetResource = SUPPORT.reopen(SOURCE, true, "")
	sheet.external_source_path = PROBE
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(sheet)
	var history := History.new()
	editor.set_undo_redo_manager(history)
	var status := Label.new()
	editor._status_label = status
	var viewport: EventSheetViewport = editor.get_viewport_control()
	viewport.toggle_function_body_lock("hit")
	viewport.toggle_function_body_lock("other")
	var hit_row: EventRowData = _row_for(viewport, _function(sheet, "hit"))
	var other_row: EventRowData = _row_for(viewport, _function(sheet, "other"))
	var rows: Array = [["both functions are rows (locked)", hit_row != null and other_row != null, true]]
	if hit_row == null or other_row == null:
		editor.free()
		return rows
	editor._ace_apply._on_viewport_ace_drop_requested(
		[{"source_resource": _function(sheet, "hit"), "kind": "action", "ace_index": 1}],
		other_row, "action", 0, "before", false)
	rows.append(["a locked body takes no drop", SUPPORT.compile_output(sheet, PROBE), SOURCE])
	rows.append(["and no undo step is made", history.has_undo(), false])
	rows.append(["and the status strip says why", status.text.contains("Unlock this function"), true])
	editor._status_label = null
	status.free()
	editor.free()
	return rows


static func _function(sheet: EventSheetResource, function_name: String) -> EventFunction:
	for entry: Variant in sheet.functions:
		if entry is EventFunction and (entry as EventFunction).function_name == function_name:
			return entry as EventFunction
	return null


static func _action_count(function_row: EventFunction) -> int:
	if function_row == null or function_row.lane_event() == null:
		return -1
	return function_row.lane_event().actions.size()


static func _action_rect(row_data: EventRowData, ace_index: int) -> Rect2:
	for span in row_data.spans:
		if span == null or not (span.metadata is Dictionary):
			continue
		var meta: Dictionary = span.metadata
		if str(meta.get("kind", "")) == "action" and int(meta.get("ace_index", -1)) == ace_index:
			return span.rect
	return Rect2()


static func _button(at: Vector2, pressed: bool) -> InputEventMouseButton:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = at
	return event


static func _motion(at: Vector2) -> InputEventMouseMotion:
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.position = at
	return event


static func _flat_index(viewport: EventSheetViewport, resource: Resource) -> int:
	var flat: Array[Dictionary] = viewport.get_flat_rows()
	for i in range(flat.size()):
		var row_data: EventRowData = flat[i].get("row")
		if row_data != null and row_data.source_resource == resource:
			return i
	return -1


static func _row_for(viewport: EventSheetViewport, resource: Resource) -> EventRowData:
	var found: int = _flat_index(viewport, resource)
	return viewport._row_at(found) if found >= 0 else null
