# EventForge - the dock's Undo reaches the editor's history, not the manager that keeps it.
# Inside the editor the undo manager is an EditorUndoRedoManager, which has NO has_undo, has_redo, undo
# or redo of its own: they live on the plain UndoRedo of each history it keeps. The adapter asked the
# manager, so in the real editor the dock's Undo button, its Ctrl+Z and the History panel all found
# "nothing to undo" after every edit, a drag-drop included, while every test (run on a plain UndoRedo)
# passed. The stand-in below has exactly the editor manager's shape, missing methods and all.
@tool
class_name EditorUndoHistoryTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const DOCK_HISTORY: int = 7
const SCENE_HISTORY: int = 3


## Records each call it gets, so the test can say which side of the step ran.
class Target:
	extends RefCounted
	var calls: PackedStringArray = PackedStringArray()


	func apply(value: String) -> void:
		calls.append(value)


## The editor manager's shape: one UndoRedo per history, picked by the step's context object, and no
## has_undo / undo / redo on the manager itself.
class EditorManagerStandIn:
	extends Object
	var histories: Dictionary = {DOCK_HISTORY: UndoRedo.new(), SCENE_HISTORY: UndoRedo.new()}
	var context_seen: Object = null
	var cleared: Array = []
	var _open: UndoRedo = null


	func create_action(action_name: String, merge_mode: int = UndoRedo.MERGE_DISABLE, custom_context: Object = null) -> void:
		context_seen = custom_context
		_open = histories[get_object_history_id(custom_context)]
		_open.create_action(action_name, merge_mode)


	func add_do_method(object: Object, method: StringName, ...args: Array) -> void:
		_open.add_do_method(Callable(object, method).bindv(args))


	func add_undo_method(object: Object, method: StringName, ...args: Array) -> void:
		_open.add_undo_method(Callable(object, method).bindv(args))


	func commit_action(execute: bool = true) -> void:
		_open.commit_action(execute)


	func get_object_history_id(object: Object) -> int:
		return DOCK_HISTORY if object != null else SCENE_HISTORY


	func get_history_undo_redo(id: int) -> UndoRedo:
		return histories.get(id)


	func clear_history(id: int = -99, _increase_version: bool = true) -> void:
		cleared.append(id)
		if histories.has(id):
			(histories[id] as UndoRedo).clear_history()


	func free_histories() -> void:
		for history: UndoRedo in histories.values():
			history.free()


static func run() -> bool:
	var target: Target = Target.new()
	var dock: Node = Node.new()
	var manager: EditorManagerStandIn = EditorManagerStandIn.new()
	var adapter: EventSheetUndoRedoAdapter = EventSheetUndoRedoAdapter.new()
	adapter.set_manager(manager)
	adapter.set_context(dock)
	# A step in the scene's history the dock must never touch.
	var scene_history: UndoRedo = manager.get_history_undo_redo(SCENE_HISTORY)
	scene_history.create_action("Move node")
	scene_history.add_do_method(Callable(target, "apply").bind("scene"))
	scene_history.commit_action(false)
	# The edit, as _perform_undoable_sheet_edit makes it after a drop.
	adapter.create_action("Move Condition")
	adapter.add_do_method(target, "apply", ["after"])
	adapter.add_undo_method(target, "apply", ["before"])
	adapter.commit_action()
	var rows: Array = [
		["the step goes into the dock's own history", manager.context_seen == dock, true],
		["committing runs the do side once (the editor's commit executes)", target.calls.duplicate(), PackedStringArray(["after"])],
		["Undo finds the step", adapter.has_undo(), true],
	]
	adapter.undo()
	rows.append(["Undo runs the undo side", target.calls.duplicate(), PackedStringArray(["after", "before"])])
	rows.append(["and leaves a redo", adapter.has_redo(), true])
	adapter.redo()
	rows.append(["Redo runs the do side again", target.calls.duplicate(), PackedStringArray(["after", "before", "after"])])
	adapter.clear_history()
	rows.append(["clearing names only the dock's history", manager.cleared.duplicate(), [DOCK_HISTORY]])
	rows.append(["the scene's history keeps its step", scene_history.has_undo(), true])
	rows.append(["the dock's history is empty", adapter.has_undo(), false])
	manager.free_histories()
	manager.free()
	dock.free()
	return SUPPORT.pins("editor_undo_history_test", rows)
