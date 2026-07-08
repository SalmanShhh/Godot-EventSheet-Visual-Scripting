# Godot EventSheets - the raw-GDScript-block editor.
#
# A CodeEdit that accepts a Scene-dock node (or FileSystem asset) dropped onto it - inserting the node's
# $Path / %Name reference (or a quoted res:// path) at the caret via the shared param converter. Overriding
# the drop virtuals to add this would normally DISABLE the editor's native text drag-drop (GDScript can't
# `super` into the C++ base handler), so this also re-handles the text (String) payload itself: on an
# internal move it drags the current selection, so the selection is removed first (else the text would
# duplicate), then the dropped text is inserted at the drop position.
@tool
class_name EventSheetRawCodeEdit
extends CodeEdit


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return _is_node_or_file_drag(data) or data is String


func _drop_data(at_position: Vector2, data: Variant) -> void:
	if _is_node_or_file_drag(data):
		var snippet: String = ACEParamsDialog.drop_data_to_expression(data)
		if not snippet.is_empty():
			insert_text_at_caret(snippet)
		return
	if data is String:
		if has_selection():
			delete_selection()
		var drop_pos: Vector2i = get_line_column_at_pos(Vector2i(at_position))
		set_caret_line(drop_pos.y)
		set_caret_column(drop_pos.x)
		insert_text_at_caret(str(data))


static func _is_node_or_file_drag(data: Variant) -> bool:
	return data is Dictionary and str((data as Dictionary).get("type", "")) in ["files", "nodes"]
