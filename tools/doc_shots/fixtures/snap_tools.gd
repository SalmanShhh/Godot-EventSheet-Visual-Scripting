@tool
extends EditorPlugin

var dock: Control = null


func _enter_tree() -> void:
	add_tool_menu_item("Snap Selection", _snap)
	add_control_to_dock(EditorPlugin.DOCK_SLOT_LEFT_UL, dock)
	add_custom_type("Waypoint", "Node2D", null, null)


func _exit_tree() -> void:
	remove_tool_menu_item("Snap Selection")


func _forward_canvas_draw_over_viewport(overlay: Control) -> void:
	overlay.draw_circle(Vector2.ZERO, 6, Color.YELLOW)


func _align_left() -> void:
	var ur = get_undo_redo()
	ur.create_action("Align Left")
	ur.add_do_property(dock, "position:x", 0)
	ur.add_undo_property(dock, "position:x", dock.position.x)
	ur.add_do_method(self, "_refresh")
	ur.commit_action()


func _snap() -> void:
	pass


func _refresh() -> void:
	pass
