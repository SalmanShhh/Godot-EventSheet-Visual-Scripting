@tool
class_name EventSheetUndoRedoAdapter
extends RefCounted

var _manager: Variant = null
## The object whose edits these are (the dock). Inside the editor it names the history every step
## goes into, so asking "is there anything to undo" reads the same history the steps were put in.
var _context: Object = null


func set_manager(manager: Variant) -> void:
	_manager = manager


func set_context(context: Object) -> void:
	_context = context


func get_manager() -> Variant:
	return _manager


func has_manager() -> bool:
	return _manager != null


## Inside the editor the step is pinned to the context's history, the one has_undo and undo read.
func create_action(action_name: String) -> void:
	if _is_editor_manager() and _context != null:
		_call("create_action", [action_name, UndoRedo.MERGE_DISABLE, _context], false)
		return
	_call("create_action", [action_name], false)


func add_do_method(target: Object, method_name: String, args: Array = []) -> void:
	_call("add_do_method", _method_payload(target, method_name, args), false)


func add_undo_method(target: Object, method_name: String, args: Array = []) -> void:
	_call("add_undo_method", _method_payload(target, method_name, args), false)


## The editor's EditorUndoRedoManager takes (object, method, args...), but the plain UndoRedo the
## dock falls back to with no editor around (tests, preview harnesses) takes ONE Callable. Handing it
## the editor's spelling printed "expected 1 argument(s), but called with 3" on every edit and
## recorded nothing, so a fallback edit could not be undone.
func _method_payload(target: Object, method_name: String, args: Array) -> Array:
	if _manager is UndoRedo:
		return [Callable(target, method_name).bindv(args)]
	var payload: Array = [target, method_name]
	payload.append_array(args)
	return payload


## The plain UndoRedo records the step WITHOUT running it: every caller has already applied its edit,
## and with no editor around the step never ran at commit before either (its methods were refused),
## so the fallback keeps what it did and gains a history that undo and redo can walk.
func commit_action() -> void:
	_call("commit_action", [false] if _manager is UndoRedo else [], false)


## The editor's EditorUndoRedoManager has no has_undo, has_redo, undo or redo of its own: those live on
## the plain UndoRedo of each history it keeps. Asking the manager itself answered "nothing to undo"
## for every step, so the dock's Undo button, its Ctrl+Z and the History panel all did nothing in the
## editor while every test (which runs on a plain UndoRedo) passed.
func has_undo() -> bool:
	return bool(_history_call("has_undo", false))


func has_redo() -> bool:
	return bool(_history_call("has_redo", false))


func undo() -> void:
	_history_call("undo")


func redo() -> void:
	_history_call("redo")


## Inside the editor only the dock's own history is cleared. The manager's clear_history() with no
## history named clears EVERY history, the open scenes' included.
func clear_history() -> void:
	if _is_editor_manager():
		_call("clear_history", [_history_id()])
		return
	_call("clear_history")


func _is_editor_manager() -> bool:
	return _manager != null and _manager.has_method("get_history_undo_redo") \
		and _manager.has_method("get_object_history_id")


func _history_id() -> int:
	return int(_manager.call("get_object_history_id", _context)) if _context != null else 0


func _history_call(method: String, fallback: Variant = null) -> Variant:
	if not _is_editor_manager():
		return _call(method, [], fallback)
	var history: Object = _manager.call("get_history_undo_redo", _history_id())
	if history == null or not history.has_method(method):
		return fallback
	return history.call(method)


func _call(method: String, args: Array = [], fallback: Variant = null) -> Variant:
	if _manager == null:
		return fallback
	if not _manager.has_method(method):
		return fallback
	return _manager.callv(method, args)
