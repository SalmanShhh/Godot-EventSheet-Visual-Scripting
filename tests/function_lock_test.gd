# Godot EventSheets - the lock on a function body, and what stays of it.
#
# A function in a script the user wrote is an ordinary event: it edits from the first click, with no
# lock and no menu step. Only two things lock one - the user locking it by hand, and a file in a shipped
# behaviour pack folder, which asks once on the help strip (with one door, Edit it anyway) before its
# first edit. Whatever was chosen is remembered in the project's editor metadata, never in the .gd, and
# an edit to an opened file rewrites only the lines of the rows it changes.
@tool
class_name FunctionLockTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const LOCKS := preload("res://addons/eventsheet/editor/interaction/function_locks.gd")
const P := "function_lock_test"
const OWN_PATH := "user://function_lock_own.gd"
const PACK_PATH := "user://eventsheet_addons/bullet/lock_probe.gd"
const PROBE := "user://function_lock_probe.gd"

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


	func undo() -> void:
		history.undo()


static func run() -> bool:
	var ok: bool = true
	ok = _test_own_file_has_no_lock() and ok
	ok = _test_hand_lock() and ok
	ok = _test_pack_asks_once() and ok
	ok = _test_choices_are_remembered() and ok
	ok = _test_one_line_edit() and ok
	return ok


## A script the user wrote: no lock, the menu offers Lock, and a path that only shares a folder NAME
## with a pack is not a pack.
static func _test_own_file_has_no_lock() -> bool:
	var sheet: EventSheetResource = SUPPORT.reopen(SOURCE, true, "")
	sheet.external_source_path = OWN_PATH
	var view: EventSheetViewport = _view(sheet)
	var rows: Array = [
		["a function of the user's own script is unlocked from the start", view.is_function_body_unlocked("hit"), true],
		["and so is every sibling", view.is_function_body_unlocked("other"), true],
		["its body is live rows", _body_live(view, "hit"), true],
		["a script in a folder that only shares a pack's name is not a pack",
			LOCKS.is_shipped_pack_file("res://bullet/bullet.gd"), false],
		["a file under eventsheet_addons in a shipped folder is a pack",
			LOCKS.is_shipped_pack_file("res://eventsheet_addons/bullet/bullet.gd"), true],
		["a library copy in the project is a pack too",
			LOCKS.is_shipped_pack_file("res://game/eventsheet_addons/platformer_movement/platformer_movement.gd"), true],
		["a user's own folder under eventsheet_addons is not a pack",
			LOCKS.is_shipped_pack_file("res://eventsheet_addons/my_own_thing/thing.gd"), false],
	]
	view.free()
	return SUPPORT.pins(P, rows)


## A function locked by hand reads inert, a drag on it is refused in words that name the menu item, and
## the menu item unlocks it again.
static func _test_hand_lock() -> bool:
	var sheet: EventSheetResource = SUPPORT.reopen(SOURCE, true, "")
	sheet.external_source_path = OWN_PATH
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(sheet)
	var history := History.new()
	editor.set_undo_redo_manager(history)
	var status := Label.new()
	editor._status_label = status
	var viewport: EventSheetViewport = editor.get_viewport_control()
	viewport.toggle_function_body_lock("hit")
	var rows: Array = [
		["a hand-locked function is locked", viewport.is_function_body_unlocked("hit"), false],
		["and reads as locked by hand", viewport.is_function_locked_by_hand("hit"), true],
		["its sibling is still unlocked", viewport.is_function_body_unlocked("other"), true],
		["its body draws no live rows", _body_live(viewport, "hit"), false],
	]
	var drag: Dictionary = _drag_in_hit(viewport, sheet)
	rows.append(["a drag in a hand-locked function moves nothing", SUPPORT.compile_output(sheet, PROBE), SOURCE])
	rows.append(["and makes no undo step", history.has_undo(), false])
	rows.append(["and the status says which menu item unlocks it", status.text.contains("Unlock this function"), true])
	rows.append(["a hand lock never offers the shipped-pack door", editor._row_help_finding.get("family", ""), ""])
	rows.append(["the drag was laid out", bool(drag.get("laid_out", false)), true])
	viewport.toggle_function_body_lock("hit")
	rows.append(["the menu item unlocks it again", viewport.is_function_body_unlocked("hit"), true])
	rows.append(["and its body is live again", _body_live(viewport, "hit"), true])
	rows.append(["the lock never touched the bytes", SUPPORT.compile_output(sheet, PROBE), SOURCE])
	editor._status_label = null
	status.free()
	editor.free()
	return SUPPORT.pins(P, rows)


## A shipped pack file: every edit gesture asks on the help strip and is not performed; the strip's one
## door unlocks the whole file; the repeated gesture then works; undoing it never locks the file again.
static func _test_pack_asks_once() -> bool:
	var sheet: EventSheetResource = SUPPORT.reopen(SOURCE, true, "")
	sheet.external_source_path = PACK_PATH
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(sheet)
	var history := History.new()
	editor.set_undo_redo_manager(history)
	var viewport: EventSheetViewport = editor.get_viewport_control()
	var rows: Array = [
		["a pack file's functions start locked", viewport.is_function_body_unlocked("hit"), false],
		["the file is a shipped pack", viewport.is_shipped_pack_sheet(), true],
		["no door is showing before any gesture", editor._pack_notice.visible, false],
	]
	var first: Dictionary = _drag_in_hit(viewport, sheet)
	rows.append(["the first drag shows the notice line", editor._pack_notice.visible, true])
	rows.append(["the notice names the file and the risk",
		editor._pack_notice_label.text, "lock_probe.gd is a shipped behaviour: adding a newer version of the pack replaces this file and your edits."])
	rows.append(["with one door, Edit it anyway", [editor._pack_notice_button.visible, editor._pack_notice_button.text],
		[true, "Edit it anyway"]])
	rows.append(["and the strip itself says nothing at the same time", [editor._row_help_label.visible, editor._row_help_button_second.visible], [false, false]])
	rows.append(["the gesture itself is not performed", SUPPORT.compile_output(sheet, PROBE), SOURCE])
	rows.append(["and makes no undo step", history.has_undo(), false])
	rows.append(["the drag was laid out", bool(first.get("laid_out", false)), true])
	# A double-click, the Add action gesture and Delete ask the same way.
	editor._pack_notice.visible = false
	var head: EventRowData = _row_for(viewport, _function(sheet, "hit"))
	var action_rect: Rect2 = _action_rect(head, 1)
	var double: InputEventMouseButton = _button(action_rect.get_center(), true)
	double.double_click = true
	viewport._input_handlers.handle_mouse_button(double)
	viewport._input_handlers.handle_mouse_button(_button(action_rect.get_center(), false))
	rows.append(["a double-click asks too", editor._pack_notice.visible, true])
	editor._pack_notice.visible = false
	editor._ace_apply._on_viewport_ace_picker_requested(head, "action")
	rows.append(["Add action asks too", editor._pack_notice.visible, true])
	editor._pack_notice.visible = false
	viewport._select_row(_flat_index(viewport, _function(sheet, "hit")))
	editor._row_edit_ops._delete_selected_rows()
	rows.append(["Delete asks too", editor._pack_notice.visible, true])
	rows.append(["and deletes nothing", SUPPORT.compile_output(sheet, PROBE), SOURCE])
	# The strip's door.
	_drag_in_hit(viewport, sheet)
	editor.apply_selected_row_fix()
	rows.append(["Edit it anyway unlocks the file", viewport.is_pack_file_unlocked(), true])
	rows.append(["and the notice line goes away", editor._pack_notice.visible, false])
	rows.append(["every function of it", [viewport.is_function_body_unlocked("hit"), viewport.is_function_body_unlocked("other")], [true, true]])
	rows.append(["the unlock alone changes no bytes", SUPPORT.compile_output(sheet, PROBE), SOURCE])
	var again: Dictionary = _drag_in_hit(viewport, sheet)
	rows.append(["the repeated drag now works", SUPPORT.compile_output(sheet, PROBE), REORDERED])
	rows.append(["as one undo step", history.has_undo(), true])
	history.undo()
	rows.append(["Undo puts the body back", SUPPORT.compile_output(editor._current_sheet, PROBE), SOURCE])
	rows.append(["and never locks the file again", viewport.is_pack_file_unlocked(), true])
	rows.append(["the second drag was laid out", bool(again.get("laid_out", false)), true])
	editor.free()
	return SUPPORT.pins(P, rows)


## What was chosen survives closing and reopening the editor: a fresh view on the same file finds it, a
## file with nothing set stores nothing, and the choice is never in the .gd.
static func _test_choices_are_remembered() -> bool:
	LOCKS.use_memory = true
	LOCKS.memory = {}
	var own: EventSheetResource = SUPPORT.reopen(SOURCE, true, "")
	own.external_source_path = OWN_PATH
	var pack: EventSheetResource = SUPPORT.reopen(SOURCE, true, "")
	pack.external_source_path = PACK_PATH
	var first_own: EventSheetViewport = _view(own)
	first_own.toggle_function_body_lock("hit")
	var first_pack: EventSheetViewport = _view(pack)
	first_pack.unlock_pack_file()
	var rows: Array = [
		["a lock set by hand is stored for the file", LOCKS.memory.get(OWN_PATH, {}), {"locked": ["hit"], "unlocked": [], "file": false}],
		["an unlocked pack file is stored for the file", LOCKS.memory.get(PACK_PATH, {}), {"locked": [], "unlocked": [], "file": true}],
	]
	first_own.free()
	first_pack.free()
	# The editor closes and opens again: nothing is carried but the metadata.
	var reopened_own: EventSheetViewport = _view(own)
	var reopened_pack: EventSheetViewport = _view(pack)
	rows.append_array([
		["a reopened file finds the function still locked", reopened_own.is_function_body_unlocked("hit"), false],
		["and its sibling still unlocked", reopened_own.is_function_body_unlocked("other"), true],
		["a reopened pack file is still unlocked", reopened_pack.is_function_body_unlocked("hit"), true],
		["the .gd carries none of it", SUPPORT.compile_output(own, PROBE), SOURCE],
	])
	reopened_own.toggle_function_body_lock("hit")
	rows.append(["unlocking a function clears what was stored", LOCKS.memory.has(OWN_PATH), false])
	# A function unlocked alone inside a pack file is remembered by name, and the file stays locked.
	var lone: EventSheetResource = SUPPORT.reopen(SOURCE, true, "")
	lone.external_source_path = "user://eventsheet_addons/car/lone.gd"
	var lone_view: EventSheetViewport = _view(lone)
	lone_view.toggle_function_body_lock("hit")
	var lone_again: EventSheetViewport = _view(lone)
	rows.append(["one function unlocked alone in a pack file is remembered",
		[lone_again.is_function_body_unlocked("hit"), lone_again.is_function_body_unlocked("other")], [true, false]])
	for view: EventSheetViewport in [reopened_own, reopened_pack, lone_view, lone_again]:
		view.free()
	LOCKS.use_memory = false
	LOCKS.memory = {}
	return SUPPORT.pins(P, rows)


## An edit rewrites only the lines of the row it changes: one action of one function of a hand-written
## script changes one line, the file keeps its length, and everything else is the file's own bytes.
static func _test_one_line_edit() -> bool:
	var sheet: EventSheetResource = SUPPORT.reopen(SOURCE, true, "")
	sheet.external_source_path = OWN_PATH
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(sheet)
	editor.set_undo_redo_manager(History.new())
	var before: String = SUPPORT.compile_output(editor._current_sheet, PROBE)
	var edited: bool = editor._perform_undoable_sheet_edit("Edit Action", func() -> bool:
		var live: EventFunction = _function(editor._current_sheet, "hit")
		var step: EventRow = live.lane_event() if live != null else null
		if step == null:
			return false
		for action: Variant in step.actions:
			if action is ACEAction:
				for key: Variant in (action as ACEAction).params.keys():
					if str((action as ACEAction).params[key]) == "10":
						(action as ACEAction).params[key] = "25"
						return true
		return false
	)
	var after: String = SUPPORT.compile_output(editor._current_sheet, PROBE)
	var before_lines: PackedStringArray = before.split("\n")
	var after_lines: PackedStringArray = after.split("\n")
	var changed: Array = []
	for index: int in range(mini(before_lines.size(), after_lines.size())):
		if before_lines[index] != after_lines[index]:
			changed.append([index + 1, before_lines[index], after_lines[index]])
	editor.free()
	return SUPPORT.pins(P, [
		["the file reproduces itself before the edit", before, SOURCE],
		["the edit was made through the undo funnel", edited, true],
		["the file keeps its line count", after_lines.size(), before_lines.size()],
		["exactly one line changed, and it is the edited action", changed, [[10, "\tscore += 10", "\tscore += 25"]]],
	])


## Presses the second action of `hit` and drags it onto the lower half of the third, the real way: press,
## motion, release through the viewport's own input handlers.
static func _drag_in_hit(viewport: EventSheetViewport, sheet: EventSheetResource) -> Dictionary:
	var index: int = _flat_index(viewport, _function(sheet, "hit"))
	if index < 0:
		return {}
	var width: float = viewport.get_canvas_logical_width()
	viewport._layout_builder.get_or_build_row_layout(index, width, viewport._get_font(), viewport._get_font_size())
	var head: EventRowData = viewport._row_at(index)
	var second: Rect2 = _action_rect(head, 1)
	var third: Rect2 = _action_rect(head, 2)
	if second.size.x <= 0.0 or third.size.x <= 0.0:
		return {}
	var drop: Vector2 = Vector2(third.get_center().x, third.position.y + third.size.y * 0.8)
	viewport._input_handlers.handle_mouse_button(_button(second.get_center(), true))
	viewport._input_handlers.handle_mouse_motion(_motion(drop))
	viewport._input_handlers.handle_mouse_button(_button(drop, false))
	return {"laid_out": true}


static func _view(sheet: EventSheetResource) -> EventSheetViewport:
	var view := EventSheetViewport.new()
	view.set_ace_registry(EventSheetACERegistry.new())
	view.size = Vector2(1200.0, 900.0)
	view.set_sheet(sheet)
	return view


static func _body_live(view: EventSheetViewport, function_name: String) -> bool:
	var row: EventRowData = _row_for(view, _function(view._sheet, function_name))
	if row == null:
		return false
	return view.ace_owner(row.source_resource) != null


static func _function(sheet: EventSheetResource, function_name: String) -> EventFunction:
	for entry: Variant in sheet.functions:
		if entry is EventFunction and (entry as EventFunction).function_name == function_name:
			return entry as EventFunction
	return null


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
