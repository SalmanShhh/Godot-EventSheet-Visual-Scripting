@tool
class_name EventSheetCommentAndScopeDialogs
extends RefCounted

# Comment editing, "With node X:" action scoping, and comment <-> action-cell conversion.
#
# Two small ConfirmationDialogs (Edit Comment: multiline text + per-comment background colour;
# Scope Actions To Node: a node-expression field) plus the logic that moves a standalone comment
# row into the action cells of the event above it, and back out again. Extracted from
# event_sheet_dock.gd so the dock stays focused; the dock keeps thin delegates (_open_comment_dialog
# / _open_with_node_dialog / _attach_comment_to_event_above / _detach_comment_to_row) so the viewport
# signal connections and the row/action context menus keep calling the dock unchanged. This class
# reaches back through the dock reference for the active sheet, the undoable-edit wrapper, and the
# refresh / dirty / status feedback.

var _dock: Control = null


func init(dock: Control) -> void:
	_dock = dock

var _comment_dialog: ConfirmationDialog = null
var _comment_text_edit: TextEdit = null
var _comment_color_button: ColorPickerButton = null
var _comment_dialog_target: CommentRow = null


## Dialog editor for comments: multiline comment rows, action-cell comments, and the row
## context menu's "Edit Comment…". Single-line comment rows keep inline editing.
func open_comment_dialog(comment_resource: Resource) -> void:
	var comment_row: CommentRow = comment_resource as CommentRow
	if comment_row == null:
		return
	_ensure_comment_dialog()
	_comment_dialog_target = comment_row
	_comment_text_edit.text = comment_row.text
	_comment_color_button.color = comment_row.custom_color
	_comment_dialog.popup_centered(Vector2i(560, 320))
	_comment_text_edit.grab_focus()


func _ensure_comment_dialog() -> void:
	if _comment_dialog != null:
		return
	_comment_dialog = ConfirmationDialog.new()
	_comment_dialog.title = "Edit Comment"
	var form: VBoxContainer = EventSheetPopupUI.form_box()
	form.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_comment_text_edit = TextEdit.new()
	_comment_text_edit.custom_minimum_size = Vector2(520.0, 200.0)
	_comment_text_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_comment_text_edit.placeholder_text = "Comment text (multiline supported)"
	form.add_child(_comment_text_edit)
	_comment_color_button = ColorPickerButton.new()
	_comment_color_button.custom_minimum_size = Vector2(64.0, 0.0)
	_comment_color_button.color = Color(0, 0, 0, 0)
	form.add_child(EventSheetPopupUI.form_row("Background", _comment_color_button))
	form.add_child(EventSheetPopupUI.hint_label("Alpha 0 = theme default."))
	_comment_dialog.add_child(EventSheetPopupUI.margined(form))
	_comment_dialog.confirmed.connect(_on_comment_dialog_confirmed)
	_dock.add_child(_comment_dialog)


func _on_comment_dialog_confirmed() -> void:
	if _comment_dialog_target == null:
		return
	var target: CommentRow = _comment_dialog_target
	var new_text: String = _comment_text_edit.text
	var new_color: Color = _comment_color_button.color
	var changed: bool = _dock._perform_undoable_sheet_edit("Edit Comment", func() -> bool:
		target.text = new_text
		target.custom_color = new_color
		return true
	)
	if changed:
		_dock._refresh_after_edit()
		_dock._mark_dirty("Comment updated.")

# ── With-node scope dialog ("With node X:" — scope a row's actions to another node) ──
var _with_node_dialog: ConfirmationDialog = null
var _with_node_target_edit: LineEdit = null
var _with_node_dialog_target: EventRow = null


## Opens the editor for a row's "With node X:" scope. The target is a node expression ($Enemy,
## get_node("…"), a variable); blank removes the scope so the row's actions act on the host again.
func open_with_node_dialog(event_resource: Resource) -> void:
	var event_row: EventRow = event_resource as EventRow
	if event_row == null:
		return
	_ensure_with_node_dialog()
	_with_node_dialog_target = event_row
	_with_node_target_edit.text = event_row.with_node_target
	_with_node_dialog.popup_centered(Vector2i(460, 160))
	_with_node_target_edit.grab_focus()
	_with_node_target_edit.select_all()


func _ensure_with_node_dialog() -> void:
	if _with_node_dialog != null:
		return
	_with_node_dialog = ConfirmationDialog.new()
	_with_node_dialog.title = "Scope Actions To Node"
	var form: VBoxContainer = EventSheetPopupUI.form_box()
	# Width-bound hint (helper handles autowrap + width clamp) so the label can't balloon the dialog.
	var hint: Label = EventSheetPopupUI.hint_label("Actions in this event act on this node instead of the host.\nUse $Enemy, get_node(\"UI/Score\"), or a variable. Leave blank to act on this node.", 420.0)
	form.add_child(hint)
	_with_node_target_edit = LineEdit.new()
	_with_node_target_edit.placeholder_text = "$Enemy"
	_with_node_target_edit.custom_minimum_size = Vector2(420.0, 0.0)
	_with_node_target_edit.text_submitted.connect(func(_submitted: String) -> void:
		_with_node_dialog.hide()
		_on_with_node_dialog_confirmed()
	)
	form.add_child(_with_node_target_edit)
	_with_node_dialog.add_child(EventSheetPopupUI.margined(form))
	_with_node_dialog.confirmed.connect(_on_with_node_dialog_confirmed)
	_dock.add_child(_with_node_dialog)


func _on_with_node_dialog_confirmed() -> void:
	if _with_node_dialog_target == null:
		return
	var target: EventRow = _with_node_dialog_target
	var new_target: String = _with_node_target_edit.text.strip_edges()
	var changed: bool = _dock._perform_undoable_sheet_edit("Scope To Node", func() -> bool:
		target.with_node_target = new_target
		return true
	)
	if changed:
		_dock._refresh_after_edit()
		_dock._mark_dirty("Scoped actions to %s." % (new_target if not new_target.is_empty() else "this node (host)"))

# ── Comment ↔ action-cell conversion ─────────────────────────────────────────


## Finds the array + index holding `target` among sheet rows (recursing into groups and
## sub-events). Returns {} when not found.
func _locate_row_container(rows: Array, target: Resource) -> Dictionary:
	for index in range(rows.size()):
		var row: Variant = rows[index]
		if row == target:
			return {"container": rows, "index": index}
		if row is EventRow:
			var found: Dictionary = _locate_row_container((row as EventRow).sub_events, target)
			if not found.is_empty():
				return found
		elif row is EventGroup:
			var group_children: Array = _dock._group_children_array(row as EventGroup)
			var found_in_group: Dictionary = _locate_row_container(group_children, target)
			if not found_in_group.is_empty():
				return found_in_group
	return {}


## Finds the EventRow whose actions contain `target` (action-cell comments/blocks).
func _locate_owning_event(rows: Array, target: Resource) -> EventRow:
	for row: Variant in rows:
		if row is EventRow:
			if (row as EventRow).actions.has(target):
				return row as EventRow
			var nested: EventRow = _locate_owning_event((row as EventRow).sub_events, target)
			if nested != null:
				return nested
		elif row is EventGroup:
			var found: EventRow = _locate_owning_event(_dock._group_children_array(row as EventGroup), target)
			if found != null:
				return found
	return null


## Comment row → action-cell comment of the nearest EventRow ABOVE it (the "comment in
## the actions"). The reverse of detach_comment_to_row.
func attach_comment_to_event_above(comment_row: CommentRow) -> void:
	if _dock._current_sheet == null or comment_row == null:
		return
	var location: Dictionary = _locate_row_container(_dock._current_sheet.events, comment_row)
	if location.is_empty():
		_dock._set_status("Comment not found in the sheet.", true)
		return
	var container: Array = location.get("container")
	var target_event: EventRow = null
	for index in range(int(location.get("index")) - 1, -1, -1):
		if container[index] is EventRow:
			target_event = container[index] as EventRow
			break
	if target_event == null:
		_dock._set_status("No event above this comment to attach to.", true)
		return
	var changed: bool = _dock._perform_undoable_sheet_edit("Attach Comment To Event", func() -> bool:
		container.erase(comment_row)
		target_event.actions.append(comment_row)
		return true
	)
	if changed:
		_dock._refresh_after_edit()
		_dock._mark_dirty("Comment attached to the event above (action note).")


## Action-cell comment → standalone comment row directly below its event.
func detach_comment_to_row(comment_row: CommentRow) -> void:
	if _dock._current_sheet == null or comment_row == null:
		return
	var owner_event: EventRow = _locate_owning_event(_dock._current_sheet.events, comment_row)
	if owner_event == null:
		_dock._set_status("This comment is not inside an event.", true)
		return
	var owner_location: Dictionary = _locate_row_container(_dock._current_sheet.events, owner_event)
	if owner_location.is_empty():
		_dock._set_status("Owning event not found in the sheet.", true)
		return
	var changed: bool = _dock._perform_undoable_sheet_edit("Detach Comment", func() -> bool:
		owner_event.actions.erase(comment_row)
		var container: Array = owner_location.get("container")
		container.insert(int(owner_location.get("index")) + 1, comment_row)
		return true
	)
	if changed:
		_dock._refresh_after_edit()
		_dock._mark_dirty("Comment detached to its own row.")
