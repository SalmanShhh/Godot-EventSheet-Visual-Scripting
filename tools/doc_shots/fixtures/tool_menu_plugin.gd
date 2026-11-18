@tool
extends EditorPlugin

const MENU_ITEM := "Snap Props"


func _enter_tree() -> void:
	add_tool_menu_item(MENU_ITEM, _snap_props)


func _exit_tree() -> void:
	remove_tool_menu_item(MENU_ITEM)


func _snap_props() -> void:
	print("snapped")
