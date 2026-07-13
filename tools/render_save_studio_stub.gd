# Minimal dock stub for the Save Studio render harness: the Studio only reaches back
# through _dock._set_status and _dock.is_inside_tree, so a Control with one method suffices.
@tool
extends Control


func _set_status(_message: String, _is_error: bool = false) -> void:
	pass
