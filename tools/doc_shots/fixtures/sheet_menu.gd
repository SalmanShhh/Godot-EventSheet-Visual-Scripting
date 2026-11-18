@tool
extends Node

var sheet_popup: PopupMenu = null


func _build_menu() -> void:
	sheet_popup = PopupMenu.new()
	sheet_popup.add_item("New…", 0)
	sheet_popup.add_item("Open…", 1)
	sheet_popup.add_item("Save", 2)
	sheet_popup.add_separator()
	sheet_popup.add_item("Sheet Type…", 4)
	sheet_popup.id_pressed.connect(_on_sheet_chosen)


func _on_sheet_chosen(id: int) -> void:
	match id:
		0:
			_new_sheet()
		1:
			_open_sheet_dialog()
		2:
			_save_current_sheet()
		4:
			_open_sheet_type_dialog()


func _new_sheet() -> void:
	pass


func _open_sheet_dialog() -> void:
	pass


func _save_current_sheet() -> void:
	pass


func _open_sheet_type_dialog() -> void:
	pass
