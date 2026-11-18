@tool
extends Node


func _run() -> void:
	EditorInterface.get_editor_undo_redo().create_action("On Editor Run")
	var __node_s1: Node = %Crate
	var __undo_s1 := EditorInterface.get_editor_undo_redo()
	__undo_s1.add_do_property(__node_s1, &"position", Vector2(64, 64))
	__undo_s1.add_undo_property(__node_s1, &"position", __node_s1.position)
	print("Snapped.")
	var __node_s4: Node = Marker2D.new()
	var __undo_s4 := EditorInterface.get_editor_undo_redo()
	__undo_s4.add_do_method(EditorInterface.get_edited_scene_root(), "add_child", __node_s4)
	__undo_s4.add_do_method(__node_s4, "set_owner", EditorInterface.get_edited_scene_root())
	__undo_s4.add_do_reference(__node_s4)
	__undo_s4.add_undo_method(EditorInterface.get_edited_scene_root(), "remove_child", __node_s4)
	EditorInterface.get_editor_undo_redo().commit_action()
