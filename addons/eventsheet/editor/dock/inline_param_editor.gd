@tool
class_name EventSheetInlineParamEditor
extends RefCounted

# The fastest editing gestures - no dialog. Double-click a highlighted parameter value to edit it in
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
var _param_edit_hint: Label = null
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
		var box: VBoxContainer = VBoxContainer.new()
		box.add_theme_constant_override("separation", 2)
		_param_edit_field = LineEdit.new()
		_param_edit_field.custom_minimum_size = Vector2(180.0, 0.0)
		_param_edit_field.text_submitted.connect(func(_t: String) -> void: _commit_inline_param_edit())
		_param_edit_field.gui_input.connect(_on_param_field_input)
		box.add_child(_param_edit_field)
		# The bulk-retune hint, shown only when several rows are selected: Ctrl+Enter writes the value
		# into the SAME verb's same param on every selected row - one undo step.
		_param_edit_hint = Label.new()
		_param_edit_hint.add_theme_font_size_override("font_size", 10)
		_param_edit_hint.modulate = Color(1.0, 1.0, 1.0, 0.65)
		box.add_child(_param_edit_hint)
		_param_edit_popup.add_child(box)
		_dock.add_child(_param_edit_popup)
	_param_edit_target = ace
	_param_edit_key = param_id
	_param_edit_field.text = current_text
	# Name the param being edited (placeholder when empty + tooltip always), so a blind popup never
	# leaves the user guessing which value they're typing - e.g. the ghost row's follow-up hop lands
	# here on a param the sentence didn't fill.
	_param_edit_field.placeholder_text = param_id
	_param_edit_field.tooltip_text = "Editing \"%s\"" % param_id
	var selected_count: int = _dock._top_level_selected_resources().size()
	_param_edit_hint.visible = selected_count > 1
	_param_edit_hint.text = "⏎ this row  ·  Ctrl+⏎ apply to all %d selected" % selected_count
	if not _param_edit_popup.is_inside_tree():
		return  # headless tests: state is set, there is no window to pop
	var popup_at: Vector2i = Vector2i(DisplayServer.mouse_get_position())
	if anchor_screen is Rect2 and (anchor_screen as Rect2).size.x > 0.0:
		popup_at = Vector2i((anchor_screen as Rect2).position + Vector2(0.0, (anchor_screen as Rect2).size.y + 2.0))
	_param_edit_popup.popup(Rect2i(popup_at, Vector2i(200, 36)))
	_param_edit_field.grab_focus()
	_param_edit_field.select_all()


## Ctrl+Enter = the bulk commit (Enter alone commits just this row via text_submitted).
func _on_param_field_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not (event as InputEventKey).pressed:
		return
	var key: InputEventKey = event as InputEventKey
	if key.keycode in [KEY_ENTER, KEY_KP_ENTER] and (key.ctrl_pressed or key.meta_pressed):
		_commit_inline_param_edit(true)
		_param_edit_field.accept_event()


func _commit_inline_param_edit(apply_to_all_selected: bool = false) -> void:
	if _param_edit_target == null or _param_edit_key.is_empty():
		return
	var target: Resource = _param_edit_target
	var key: String = _param_edit_key
	var new_text: String = _param_edit_field.text
	var updated := {"count": 0}
	var changed: bool
	if apply_to_all_selected:
		# Bulk retune: write the value into the SAME verb's same param on every selected row -
		# structure-aware (only ACEs with the matching id that actually carry this param), type-safe
		# (the value goes through the same params dict as a single edit), ONE undo step.
		var targets: Array = _collect_matching_aces(target, key)
		changed = _dock._perform_undoable_sheet_edit("Edit Parameter (all selected)", func() -> bool:
			var any: bool = false
			for ace: Resource in targets:
				var params: Dictionary = ace.get("params")
				if str(params.get(key, "")) == new_text:
					continue
				params[key] = new_text
				any = true
				updated["count"] = int(updated["count"]) + 1
			return any
		)
	else:
		changed = _dock._perform_undoable_sheet_edit("Edit Parameter", func() -> bool:
			var params: Dictionary = target.get("params")
			if str(params.get(key, "")) == new_text:
				return false
			params[key] = new_text
			return true
		)
	_param_edit_popup.hide()
	if changed:
		_dock._refresh_after_edit()
		var note: String = "Parameter updated."
		if apply_to_all_selected:
			note = "Set %s on %d matching verbs." % [key, int(updated["count"])]
		_dock._mark_dirty(note)


## Every ACE across the selected rows that is the SAME verb as the edited one (matching provider+id)
## and carries the edited param - the bulk-apply target set. Walks each selected row's trigger,
## conditions, actions, and sub-events (and group children, when a group is selected). The edited
## ACE itself is always included, selected or not.
func _collect_matching_aces(edited: Resource, param_id: String) -> Array:
	var matches: Array = [edited]
	for resource: Variant in _dock._top_level_selected_resources():
		_collect_matching_in(resource, edited, param_id, matches)
	return matches


func _collect_matching_in(resource: Variant, edited: Resource, param_id: String, matches: Array) -> void:
	if resource is EventGroup:
		var group: EventGroup = resource as EventGroup
		var group_rows: Array = group.events if not group.events.is_empty() else group.rows
		for child: Variant in group_rows:
			_collect_matching_in(child, edited, param_id, matches)
		return
	if not (resource is EventRow):
		return
	var event_row: EventRow = resource as EventRow
	var candidates: Array = []
	if event_row.trigger != null:
		candidates.append(event_row.trigger)
	candidates.append_array(event_row.conditions)
	candidates.append_array(event_row.actions)
	for candidate: Variant in candidates:
		if not (candidate is Resource) or candidate == edited:
			continue
		var ace: Resource = candidate as Resource
		if str(ace.get("ace_id")) != str(edited.get("ace_id")) or str(ace.get("provider_id")) != str(edited.get("provider_id")):
			continue
		if ace.get("params") is Dictionary and (ace.get("params") as Dictionary).has(param_id):
			matches.append(ace)
	for sub_event: Variant in event_row.sub_events:
		_collect_matching_in(sub_event, edited, param_id, matches)


## Clicking a cell's colour swatch opens a ColorPicker right there (no params dialog), inline.
## The pick is committed once, when the popup closes - so dragging the picker is one clean undo step, not
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


## A scene node was dropped onto a condition/action param value - set that param to the node reference
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
