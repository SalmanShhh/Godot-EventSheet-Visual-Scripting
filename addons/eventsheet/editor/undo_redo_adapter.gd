@tool
class_name EventSheetUndoRedoAdapter
extends RefCounted

var _manager: Variant = null


func set_manager(manager: Variant) -> void:
	_manager = manager


func get_manager() -> Variant:
	return _manager


func has_manager() -> bool:
	return _manager != null


func create_action(action_name: String) -> void:
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


func has_undo() -> bool:
	return bool(_call("has_undo", [], false))


func has_redo() -> bool:
	return bool(_call("has_redo", [], false))


func undo() -> void:
	_call("undo")


func redo() -> void:
	_call("redo")


func clear_history() -> void:
	_call("clear_history")


func _call(method: String, args: Array = [], fallback: Variant = null) -> Variant:
	if _manager == null:
		return fallback
	if not _manager.has_method(method):
		return fallback
	return _manager.callv(method, args)
