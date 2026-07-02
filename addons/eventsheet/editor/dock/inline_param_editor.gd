@tool
extends RefCounted
class_name EventSheetInlineParamEditor

# The fastest editing gestures — no dialog. Double-click a highlighted parameter value to edit it in
# a one-field popup at the mouse; click a colour-swatch cell to drop a ColorPicker right there
# (committed once on close, so dragging is one undo step); drop a scene node onto a param to set it to
# that node reference. Extracted from event_sheet_dock.gd so the dock stays focused; the dock keeps
# thin _on_*_requested delegates so the viewport signal connections stay unchanged, and this class
# parents its popups on the dock and reaches back through the dock reference for the undoable-edit
# wrapper plus refresh / dirty feedback.

var _dock: Control = null

func init(dock: Control) -> void:
	_dock = dock

var _param_edit_popup: PopupPanel = null
var _param_edit_field: LineEdit = null
var _param_edit_target: Resource = null
var _param_edit_key: String = ""
var _color_swatch_popup: PopupPanel = null
var _color_swatch_picker: ColorPicker = null
var _color_swatch_target: Resource = null
var _color_swatch_key: String = ""

## Double-clicking a highlighted value opens this one-field editor at the mouse. Keyboard flows
## (the Param Hop's Enter) pass the value's screen rect instead, so the popup lands under the value
## the cursor is on rather than wherever the mouse happens to sit.
func on_param_value_edit_requested(ace: Resource, param_id: String, current_text: String, anchor_screen: Variant = null) -> void:
	if _param_edit_popup == null:
		_param_edit_popup = PopupPanel.new()
		_param_edit_field = LineEdit.new()
		_param_edit_field.custom_minimum_size = Vector2(180.0, 0.0)
		_param_edit_field.text_submitted.connect(func(_t: String) -> void: _commit_inline_param_edit())
		_param_edit_popup.add_child(_param_edit_field)
		_dock.add_child(_param_edit_popup)
	_param_edit_target = ace
	_param_edit_key = param_id
	_param_edit_field.text = current_text
	# Name the param being edited (placeholder when empty + tooltip always), so a blind popup never
	# leaves the user guessing which value they're typing — e.g. the ghost row's follow-up hop lands
	# here on a param the sentence didn't fill.
	_param_edit_field.placeholder_text = param_id
	_param_edit_field.tooltip_text = "Editing \"%s\"" % param_id
	var popup_at: Vector2i = Vector2i(DisplayServer.mouse_get_position())
	if anchor_screen is Rect2 and (anchor_screen as Rect2).size.x > 0.0:
		popup_at = Vector2i((anchor_screen as Rect2).position + Vector2(0.0, (anchor_screen as Rect2).size.y + 2.0))
	_param_edit_popup.popup(Rect2i(popup_at, Vector2i(200, 36)))
	_param_edit_field.grab_focus()
	_param_edit_field.select_all()

func _commit_inline_param_edit() -> void:
	if _param_edit_target == null or _param_edit_key.is_empty():
		return
	var target: Resource = _param_edit_target
	var key: String = _param_edit_key
	var new_text: String = _param_edit_field.text
	var changed: bool = _dock._perform_undoable_sheet_edit("Edit Parameter", func() -> bool:
		var params: Dictionary = target.get("params")
		if str(params.get(key, "")) == new_text:
			return false
		params[key] = new_text
		return true
	)
	_param_edit_popup.hide()
	if changed:
		_dock._refresh_after_edit()
		_dock._mark_dirty("Parameter updated.")

## Clicking a cell's colour swatch opens a ColorPicker right there (no params dialog), inline.
## The pick is committed once, when the popup closes — so dragging the picker is one clean undo step, not
## one per colour change.
func on_color_swatch_edit_requested(ace: Resource, param_id: String, current_color: Color) -> void:
	if _color_swatch_popup == null:
		_color_swatch_popup = PopupPanel.new()
		_color_swatch_picker = ColorPicker.new()
		_color_swatch_picker.edit_alpha = true
		_color_swatch_picker.custom_minimum_size = Vector2(280.0, 0.0)
		_color_swatch_popup.add_child(_color_swatch_picker)
		_dock.add_child(_color_swatch_popup)
		# Commit once on close (final colour) rather than on every continuous color_changed.
		_color_swatch_popup.popup_hide.connect(func() -> void: _commit_color_swatch_edit(_color_swatch_picker.color))
	_color_swatch_target = ace
	_color_swatch_key = param_id
	_color_swatch_picker.color = current_color
	_color_swatch_popup.reset_size()
	_color_swatch_popup.popup(Rect2i(Vector2i(DisplayServer.mouse_get_position()), _color_swatch_popup.size))

func _commit_color_swatch_edit(new_color: Color) -> void:
	if _color_swatch_target == null or _color_swatch_key.is_empty():
		return
	var target: Resource = _color_swatch_target
	var key: String = _color_swatch_key
	var new_text: String = ACEParamsDialog.color_to_literal(new_color)
	var changed: bool = _dock._perform_undoable_sheet_edit("Edit Colour", func() -> bool:
		var params: Dictionary = target.get("params")
		if str(params.get(key, "")) == new_text:
			return false
		params[key] = new_text
		return true
	)
	if changed:
		_dock._refresh_after_edit()
		_dock._mark_dirty("Colour updated.")

## A scene node was dropped onto a condition/action param value — set that param to the node reference
## (e.g. %Player), undoable. The deep-node-friendly gesture: drag from the Scene dock, no dialog.
func on_param_node_drop_requested(ace: Resource, param_id: String, node_reference: String) -> void:
	if ace == null or param_id.is_empty():
		return
	var changed: bool = _dock._perform_undoable_sheet_edit("Drop Node Reference", func() -> bool:
		var params: Dictionary = ace.get("params")
		if str(params.get(param_id, "")) == node_reference:
			return false
		params[param_id] = node_reference
		return true
	)
	if changed:
		_dock._refresh_after_edit()
		_dock._mark_dirty("Set %s to %s." % [param_id, node_reference])
