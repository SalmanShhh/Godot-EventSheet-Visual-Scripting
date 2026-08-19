@tool
class_name Batch12UndoFunnelFixture
extends RefCounted

var _dock: Control = null
var mode: String = ""


func _init(dock: Control) -> void:
	_dock = dock


func apply() -> void:
	var changed: bool = _dock._perform_undoable_sheet_edit("Apply Cell Edit", func() -> bool:
		if mode == "new_condition_event":
			_append_condition_entry()
			return true
		if mode == "replace_action":
			_replace_action()
			return true
		return false)
	if changed:
		_dock._set_status("Applied.")


func _append_condition_entry() -> void:
	mode = "done"


func _replace_action() -> void:
	mode = "done"
