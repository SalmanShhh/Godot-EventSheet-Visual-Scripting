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
	var payload: Array = [target, method_name]
	payload.append_array(args)
	_call("add_do_method", payload, false)

func add_undo_method(target: Object, method_name: String, args: Array = []) -> void:
	var payload: Array = [target, method_name]
	payload.append_array(args)
	_call("add_undo_method", payload, false)

func commit_action() -> void:
	_call("commit_action", [], false)

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
