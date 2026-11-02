@tool
class_name EventSheetColourSquareEditor
extends RefCounted

# The gesture behind a colour value's square: click it and Godot's ColorPicker opens right under it, with
# no parameters window. While the picker is dragged the row's square and its words follow it; closing the
# popup (or Enter) keeps the colour as ONE undo step, "Edit Colour"; Esc puts the old colour back and
# writes nothing. The pick is written in the form the value was typed in (EventSheetColourValue), for a
# variable's default and an action's parameter alike - one writer.
#
# Also the square's right-click menu: Copy As in every form that can say the colour (clipboard only, no
# undo step) and Read Colours As, the project-wide setting for how colour values read on a row.
#
# The preview never touches the undo stack: the target's text is set directly and the rows are built again,
# and the old text is put back before the one real edit is made - so the undo step has the right "before".

## How soon after the last preview the next one may rebuild the rows.
const PREVIEW_INTERVAL_MSEC := 60

var _dock: Control = null
var _popup: PopupPanel = null
var _picker: ColorPicker = null
var _form_line: Label = null
var _menu: PopupMenu = null
var _read_menu: PopupMenu = null
var _copy_values: Array = []

var _request: Dictionary = {}
var _target: Resource = null
var _variable_name: String = ""
var _param_key: String = ""
var _raw: String = ""
var _alpha_slot: bool = true
var _original_default: Variant = null
var _original_expression: bool = false
var _original_had_key: bool = false
var _live_text: String = ""
var _live_note: String = ""
var _opening: bool = false
var _open: bool = false
var _reverted: bool = false
var _last_preview_msec: int = 0
var _preview_waiting: bool = false


func init(dock: Control) -> void:
	_dock = dock


## Whether a picker is open on a colour right now.
func is_open() -> bool:
	return _open


## The text the open picker would write if it closed now ("" when nothing was dragged).
func live_text() -> String:
	return _live_text


## Opens the picker under the square `request` names (see EventSheetViewport.colour_request_for). Headless-safe:
## the state arms and the window itself is skipped, so a test drives the same preview, keep and revert paths.
func open(request: Dictionary) -> void:
	if _open:
		finish(false)
	var info: Dictionary = EventSheetColourValue.parse(str(request.get("raw", "")))
	if not bool(info.get("ok", false)):
		return
	if _dock != null and _dock._viewport != null:
		_dock._viewport.close_head_card()
	_request = request
	_target = request.get("target") as Resource
	_variable_name = str(request.get("variable", ""))
	_param_key = str(request.get("param", ""))
	_raw = str(request.get("raw", ""))
	_alpha_slot = bool(request.get("alpha_slot", true))
	if _target == null:
		return
	if _target is LocalVariable:
		_original_default = (_target as LocalVariable).default_value
		_original_expression = (_target as LocalVariable).expression_default
	else:
		var params: Dictionary = _target.get("params")
		_original_had_key = params.has(_param_key)
		_original_default = params.get(_param_key)
	_live_text = ""
	_live_note = ""
	_reverted = false
	_open = true
	_ensure_popup()
	_opening = true
	var reading: String = EventSheetColourValue.project_reading()
	_picker.edit_alpha = _alpha_slot
	_picker.edit_intensity = bool(info.get("overbright", false))
	_picker.color_mode = _picker_mode_for(EventSheetColourValue.picker_mode(info, reading))
	_picker.color = info["color"]
	_form_line.text = _form_text(_raw, "")
	_opening = false
	if not Engine.is_editor_hint() and DisplayServer.get_name() == "headless":
		return
	_popup.reset_size()
	var anchor: Rect2i = request.get("anchor", Rect2i())
	EventSheetWindowPlacement.popup_below(_popup, anchor, Vector2i(maxi(int(_popup.size.x), 300), int(_popup.size.y)))


func _ensure_popup() -> void:
	if _popup != null:
		return
	_popup = PopupPanel.new()
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	_picker = ColorPicker.new()
	_picker.custom_minimum_size = Vector2(280.0, 0.0)
	_picker.color_changed.connect(_on_picker_changed)
	column.add_child(_picker)
	_form_line = Label.new()
	_form_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_form_line.custom_minimum_size = Vector2(280.0, 0.0)
	_form_line.add_theme_color_override("font_color", EventSheetPopupUI.muted_text_color())
	column.add_child(_form_line)
	_popup.add_child(column)
	_popup.popup_hide.connect(_on_popup_hidden)
	_popup.window_input.connect(_on_popup_input)
	_dock.add_child(_popup)
	for preset: Color in EventSheetColorPresets.all():
		_picker.add_preset(preset)
	_picker.preset_added.connect(func(color: Color) -> void: EventSheetColorPresets.add(color))
	_picker.preset_removed.connect(func(color: Color) -> void: EventSheetColorPresets.remove(color))


static func _picker_mode_for(mode: String) -> ColorPicker.ColorModeType:
	match mode:
		EventSheetColourValue.MODE_HSV:
			return ColorPicker.MODE_HSV
		EventSheetColourValue.MODE_OKHSL:
			return ColorPicker.MODE_OKHSL
	return ColorPicker.MODE_RGB


## The line under the picker: how the value will be written, and when a form had to change, why.
func _form_text(written: String, note: String) -> String:
	var line: String = EventSheetL10n.translate("Written as %s.") % written
	return line if note.is_empty() else "%s %s" % [line, note.substr(0, 1).to_upper() + note.substr(1) + "."]


func _on_popup_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not (event as InputEventKey).pressed:
		return
	var key: int = (event as InputEventKey).keycode
	if key == KEY_ESCAPE:
		_reverted = true
		_popup.hide()
	elif key == KEY_ENTER or key == KEY_KP_ENTER:
		_popup.hide()


func _on_popup_hidden() -> void:
	if _open:
		finish(not _reverted)


func _on_picker_changed(color: Color) -> void:
	if _opening or not _open:
		return
	preview(color)


## The colour the picker holds now, written in the value's form and shown on the row. Nothing reaches the
## undo stack or the saved sheet.
func preview(color: Color) -> void:
	var written: Dictionary = EventSheetColourValue.write_back(_raw, color, _alpha_slot)
	_live_text = str(written["text"])
	_live_note = str(written.get("note", ""))
	if _form_line != null:
		_form_line.text = _form_text(_live_text, _live_note)
	var now: int = Time.get_ticks_msec()
	if now - _last_preview_msec >= PREVIEW_INTERVAL_MSEC:
		_flush_preview()
	elif not _preview_waiting and _dock != null and _dock.is_inside_tree():
		_preview_waiting = true
		_dock.get_tree().create_timer(PREVIEW_INTERVAL_MSEC / 1000.0).timeout.connect(func() -> void:
			_preview_waiting = false
			if _open:
				_flush_preview())


func _flush_preview() -> void:
	_last_preview_msec = Time.get_ticks_msec()
	_write_target(_live_text)
	if _dock != null and _dock._viewport != null:
		_dock._viewport.rebuild_rows()


## Sets the target's text directly (a preview, or putting the old text back). Not an edit.
func _write_target(text: String) -> void:
	if _target is LocalVariable:
		var live: LocalVariable = EventSheetInlineParamEditor.find_variable_by_name(_dock._current_sheet, _variable_name)
		if live == null:
			live = _target as LocalVariable
		live.default_value = text
		live.expression_default = true
	elif _target != null:
		var params: Dictionary = _target.get("params")
		params[_param_key] = text


func _restore_target() -> void:
	if _target is LocalVariable:
		var live: LocalVariable = EventSheetInlineParamEditor.find_variable_by_name(_dock._current_sheet, _variable_name)
		if live == null:
			live = _target as LocalVariable
		live.default_value = _original_default
		live.expression_default = _original_expression
	elif _target != null:
		var params: Dictionary = _target.get("params")
		if _original_had_key:
			params[_param_key] = _original_default
		else:
			params.erase(_param_key)


## Ends the pick. `keep` true writes the colour as one undo step; false puts the old colour back and writes
## nothing. Either way the rows are built again from the sheet as it now stands.
func finish(keep: bool) -> bool:
	if not _open:
		return false
	_open = false
	var new_text: String = _live_text
	var note: String = _live_note
	_restore_target()
	if _popup != null and _popup.visible:
		_popup.hide()
	var changed: bool = false
	if keep and not new_text.is_empty() and new_text != _raw:
		changed = _commit(new_text, note)
	if not changed and _dock != null and _dock._viewport != null and not _live_text.is_empty():
		_dock._viewport.rebuild_rows()
	_live_text = ""
	_live_note = ""
	return changed


## The one real edit: the same writer for a variable's default and an action's parameter.
func _commit(new_text: String, note: String) -> bool:
	var target: Resource = _target
	var variable_name: String = _variable_name
	var key: String = _param_key
	var changed: bool = _dock._perform_undoable_sheet_edit("Edit Colour", func() -> bool:
		if target is LocalVariable:
			var live: LocalVariable = EventSheetInlineParamEditor.find_variable_by_name(_dock._current_sheet, variable_name)
			if live == null or str(live.default_value) == new_text:
				return false
			live.default_value = new_text
			live.expression_default = true
			return true
		var params: Dictionary = target.get("params")
		if str(params.get(key, "")) == new_text:
			return false
		params[key] = new_text
		return true
	)
	if changed:
		if _dock._viewport != null:
			_dock._viewport.remember_colour_switch(new_text, note)
		_dock._refresh_after_edit()
		_dock._mark_dirty(EventSheetL10n.translate("Colour updated.") if note.is_empty() else "%s %s" % [EventSheetL10n.translate("Colour updated."), note])
	return changed


# ---------------------------------------------------------------------------------------------------
# The square's right-click menu
# ---------------------------------------------------------------------------------------------------


## Opens the menu at `global_position`: Copy As (every form that can say the colour, each showing the exact
## text it copies) and Read Colours As (the project setting). Nothing here is an edit.
func open_menu(request: Dictionary, global_position: Vector2) -> void:
	var forms: Array = EventSheetColourValue.copy_forms(str(request.get("raw", "")), bool(request.get("alpha_slot", true)))
	if forms.is_empty():
		return
	if _menu == null:
		_menu = PopupMenu.new()
		_menu.id_pressed.connect(_on_menu_chosen)
		_read_menu = PopupMenu.new()
		_read_menu.name = "ReadColoursAs"
		_read_menu.id_pressed.connect(_on_read_chosen)
		_menu.add_child(_read_menu)
		_dock.add_child(_menu)
	_menu.clear()
	_read_menu.clear()
	_copy_values = []
	_menu.add_separator(EventSheetL10n.translate("Copy As"))
	for form: Variant in forms:
		var label: String = str((form as Array)[0])
		var value: String = str((form as Array)[1])
		_menu.add_item("%s    %s" % [EventSheetColourValue.label_words(label), value], _copy_values.size())
		_copy_values.append(value)
	_menu.add_separator()
	var current: String = EventSheetColourValue.project_reading()
	for index: int in range(EventSheetColourValue.READ_CHOICES.size()):
		var choice: String = EventSheetColourValue.READ_CHOICES[index]
		_read_menu.add_radio_check_item(EventSheetColourValue.label_words(choice), index)
		_read_menu.set_item_checked(index, choice == current)
	_menu.add_submenu_node_item(EventSheetL10n.translate("Read Colours As"), _read_menu)
	if _dock != null and _dock._viewport != null:
		_dock._viewport.close_head_card()
	_menu.reset_size()
	if not Engine.is_editor_hint() and DisplayServer.get_name() == "headless":
		return
	EventSheetWindowPlacement.popup_at(_menu, Vector2i(global_position))


func _on_menu_chosen(id: int) -> void:
	if id >= 0 and id < _copy_values.size():
		DisplayServer.clipboard_set(str(_copy_values[id]))
		_dock._set_status(EventSheetL10n.translate("Copied %s.") % str(_copy_values[id]), false)


func _on_read_chosen(index: int) -> void:
	if index < 0 or index >= EventSheetColourValue.READ_CHOICES.size():
		return
	set_reading(EventSheetColourValue.READ_CHOICES[index])


## Sets how colour values read, project-wide, and builds the rows again so they say it. The setting is the
## project's, so a team reads alike; the sheet's text is untouched.
func set_reading(choice: String) -> void:
	if not EventSheetColourValue.READ_CHOICES.has(choice):
		return
	ProjectSettings.set_setting(EventSheetColourValue.SETTING_NAME, choice)
	if Engine.is_editor_hint():
		ProjectSettings.save()
	if _dock != null and _dock._viewport != null:
		_dock._viewport.rebuild_rows()
