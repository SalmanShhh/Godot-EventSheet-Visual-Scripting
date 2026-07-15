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
var _field_edit_popup: PopupPanel = null
var _field_edit_field: LineEdit = null
var _field_edit_raw: Resource = null
var _field_edit_index: int = -1
var _field_edit_part: String = ""


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


## Double-clicking a "Data class" block field's name / type / default value opens the same one-field
## editor an ACE param uses. The field lives inside a RawCodeRow's GDScript text (a `class X:` of typed
## fields), not in a params dict, so the commit re-emits the whole class from its structured model: parse
## raw_row.code -> mutate the field at field_index's part -> emit -> write back, all through the undo funnel.
## Because the class only lifted to an editable block when its model reproduced the source byte-for-byte,
## re-emitting after an edit changes ONLY the touched field's line - every other field, the header and the
## doc prefix round-trip unchanged.
func on_data_class_field_edit_requested(raw_row: Resource, field_index: int, part: String, current_text: String) -> void:
	if not (raw_row is RawCodeRow) or field_index < 0 or part.is_empty():
		return
	if _field_edit_popup == null:
		_field_edit_popup = PopupPanel.new()
		_field_edit_field = LineEdit.new()
		_field_edit_field.custom_minimum_size = Vector2(180.0, 0.0)
		_field_edit_field.text_submitted.connect(func(_t: String) -> void: _commit_data_class_field_edit())
		_field_edit_popup.add_child(_field_edit_field)
		_dock.add_child(_field_edit_popup)
	_field_edit_raw = raw_row
	_field_edit_index = field_index
	_field_edit_part = part
	_field_edit_field.text = current_text
	_field_edit_field.placeholder_text = part
	_field_edit_field.tooltip_text = "Editing field %s" % part
	if not _field_edit_popup.is_inside_tree():
		return  # headless tests: state is set, there is no window to pop
	_field_edit_popup.popup(Rect2i(Vector2i(DisplayServer.mouse_get_position()), Vector2i(200, 36)))
	_field_edit_field.grab_focus()
	_field_edit_field.select_all()


## Applies the committed value to a field's DEFAULT and re-emits the class into raw_row.code (one undo step).
## Only the default is editable (a rename / type change would leave use sites elsewhere in the .gd broken -
## the builder does not expose those parts). Two covenant guards: (1) the value is NOT stripped, so a field
## whose default carried surrounding whitespace re-emits byte-identically and a no-op Enter changes nothing;
## (2) the no-change check runs BEFORE the undo funnel - `_perform_undoable_sheet_edit` unlocks a read-only
## preview on entry, so a no-op must never reach it, or merely double-clicking + Enter would unlock a pack
## opened just to look.
func _commit_data_class_field_edit() -> void:
	var raw_row: Resource = _field_edit_raw
	var field_index: int = _field_edit_index
	if _field_edit_popup != null:
		_field_edit_popup.hide()
	if not (raw_row is RawCodeRow) or field_index < 0 or _field_edit_part != "default":
		return
	# Raw text, not strip_edges: preserve the exact bytes so an unchanged value re-emits identically.
	var new_value: String = _field_edit_field.text
	var new_code: String = _emit_data_class_default_edit(raw_row, field_index, new_value)
	if new_code.is_empty() or new_code == str(raw_row.get("code")):
		return  # invalid target, or no change: touch nothing (no funnel, so no unlock, no dirty)
	var changed: bool = _dock._perform_undoable_sheet_edit("Edit Field", func() -> bool:
		# Recompute from the LIVE code inside the funnel (the sheet may have moved since the popup opened).
		var live_code: String = _emit_data_class_default_edit(raw_row, field_index, new_value)
		if live_code.is_empty() or live_code == str(raw_row.get("code")):
			return false
		raw_row.set("code", live_code)
		return true
	)
	if changed:
		_dock._refresh_after_edit()
		_dock._mark_dirty("Field updated.")


## Returns raw_row's class text with the field at field_index's default set to new_value ("" when the row is
## no longer a lifting data class or field_index is not a field, so the caller leaves it untouched). An empty
## new_value drops the ` = default` entirely. Pure re-emit through the same model the block was built from.
func _emit_data_class_default_edit(raw_row: Resource, field_index: int, new_value: String) -> String:
	var model: Dictionary = ViewportRowBuilder.parse_data_class(str(raw_row.get("code")))
	if model.is_empty():
		return ""
	var body: Array = model["body"]
	if field_index < 0 or field_index >= body.size():
		return ""
	var entry: Dictionary = body[field_index]
	if str(entry.get("kind")) != "field":
		return ""
	entry["has_default"] = not new_value.is_empty()
	entry["default"] = new_value
	return ViewportRowBuilder.emit_data_class(model)


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
