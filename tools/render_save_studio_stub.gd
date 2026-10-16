# Minimal dock stub for the Save Studio render harness: the Studio reaches back for the open sheets
# (What gets saved), the undo funnel a Save pick goes through, and the status line - nothing else.
@tool
extends Control

var _open_tabs: Array[Dictionary] = []
var _active_tab_index: int = 0
var _current_sheet: EventSheetResource = null
var _current_sheet_path: String = ""


func _set_status(_message: String, _is_error: bool = false) -> void:
	pass


func _mark_dirty(_message: String = "") -> void:
	pass


func activate_open_tab(index: int) -> void:
	_active_tab_index = index
	_current_sheet = _open_tabs[index]["sheet"]
	_current_sheet_path = str(_open_tabs[index]["path"])


func _perform_undoable_sheet_edit(_label: String, mutation: Callable) -> bool:
	return bool(mutation.call())


## Opens one sheet, the way the dock would have it: a Player with the board's five variables.
func open_player() -> void:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.custom_class_name = "Player"
	sheet.host_class = "CharacterBody2D"
	sheet.variables = {
		"health": {"type": "int", "default": 3, "exported": true, "attributes": {"tooltip": "hit points left", "save": "auto"}},
		"coins": {"type": "int", "default": 0, "exported": true, "attributes": {"tooltip": "coins collected", "save": "auto"}},
		"position": {"type": "Vector2", "default": Vector2.ZERO, "exported": false, "attributes": {"tooltip": "where the player stands", "save": "manual"}},
		"speed": {"type": "float", "default": 120.0, "exported": true, "attributes": {"tooltip": "usually a setting, not progress"}},
		"_cooldown": {"type": "float", "default": 0.0, "exported": false, "attributes": {"tooltip": "private, short-lived"}},
	}
	_open_tabs = [{"sheet": sheet, "path": "res://player.gd"}]
	activate_open_tab(0)
