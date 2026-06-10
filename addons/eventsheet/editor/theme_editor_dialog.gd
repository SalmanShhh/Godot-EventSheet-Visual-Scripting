# Godot EventSheets — Visual theme editor (designer-facing)
# A live theme workbench: the left pane is a REAL EventSheetViewport rendering a sample
# sheet; the right pane is a token form generated REFLECTIVELY from the style resources'
# exported properties (Color → color picker, float/int → spinbox, bool → checkbox), so new
# tokens added to the style classes appear here automatically — no editor changes needed.
# Edits write into a duplicated working style and repaint live; "Apply" assigns it to the
# current sheet, "Save As Preset…" writes a shareable .tres.
# Token reference: docs/EVENTSHEET_THEME_TOKEN_SPEC.md.
@tool
class_name EventSheetThemeEditor
extends RefCounted

var _dialog: AcceptDialog = null
var _preview_viewport: EventSheetViewport = null
var _working_style: EventSheetEditorStyle = null
var _dock: Control = null
var _save_dialog: FileDialog = null

## Opens the theme editor seeded from the dock's active style (or defaults).
func open(dock: Control, base_style: EventSheetEditorStyle) -> void:
	_dock = dock
	_working_style = duplicate_style(base_style)
	_ensure_dialog()
	_preview_viewport.set_sheet(build_sample_sheet(_working_style))
	_dialog.popup_centered(Vector2i(1080, 620))

## Deep-duplicates a style so live edits never touch the original resource.
static func duplicate_style(base_style: EventSheetEditorStyle) -> EventSheetEditorStyle:
	var style: EventSheetEditorStyle = base_style.duplicate(true) if base_style != null else EventSheetEditorStyle.new()
	if style.event_style == null:
		style.event_style = EventSheetEventStyle.new()
	if style.condition_style == null:
		style.condition_style = EventSheetElementStyle.new()
	if style.action_style == null:
		style.action_style = EventSheetElementStyle.new()
	return style

## The sample sheet shown in the preview: one of everything the theme touches.
static func build_sample_sheet(style: EventSheetEditorStyle) -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.editor_style = style
	sheet.variables = {"health": {"type": "int", "default": 100, "exported": true}}
	var group: EventGroup = EventGroup.new()
	group.name = "Gameplay"
	group.group_name = "Gameplay"
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnProcess"
	var condition: ACECondition = ACECondition.new()
	condition.provider_id = "Core"
	condition.ace_id = "IsOnFloor"
	event.conditions.append(condition)
	var negated: ACECondition = ACECondition.new()
	negated.provider_id = "Core"
	negated.ace_id = "IsOnFloor"
	negated.negated = true
	event.conditions.append(negated)
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "QueueFree"
	event.actions.append(action)
	var note: CommentRow = CommentRow.new()
	note.text = "Sub-event comment"
	event.sub_events.append(note)
	group.events.append(event)
	sheet.events.append(group)
	var comment: CommentRow = CommentRow.new()
	comment.text = "Colored comment\nsecond line"
	comment.custom_color = Color(0.32, 0.27, 0.14, 1.0)
	sheet.events.append(comment)
	# Newer row kinds so the live preview exercises their tokens too (keyword badges,
	# declaration text, color swatches).
	var sample_enum: EnumRow = EnumRow.new()
	sample_enum.enum_name = "State"
	sample_enum.members = PackedStringArray(["IDLE", "RUN"])
	sheet.events.append(sample_enum)
	var sample_signal: SignalRow = SignalRow.new()
	sample_signal.signal_name = "hit"
	sample_signal.params = PackedStringArray(["damage: int"])
	sheet.events.append(sample_signal)
	var tint_event: EventRow = EventRow.new()
	tint_event.trigger_provider_id = "Core"
	tint_event.trigger_id = "OnReady"
	var tint: ACEAction = ACEAction.new()
	tint.provider_id = "Core"
	tint.ace_id = "SetModulate"
	tint.codegen_template = "modulate = {color}"
	tint.params = {"color": "Color(0.4, 0.7, 1.0, 1.0)"}
	tint_event.actions.append(tint)
	sheet.events.append(tint_event)
	return sheet

## Exported tokens of a style resource that the form can edit (Color/float/int/bool).
static func editable_tokens(style_resource: Resource) -> Array[Dictionary]:
	var tokens: Array[Dictionary] = []
	if style_resource == null:
		return tokens
	for property_info: Dictionary in style_resource.get_property_list():
		if not (property_info.get("usage", 0) & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var token_type: int = int(property_info.get("type", TYPE_NIL))
		if token_type in [TYPE_COLOR, TYPE_FLOAT, TYPE_INT, TYPE_BOOL]:
			tokens.append({"name": str(property_info.get("name")), "type": token_type})
	return tokens

## Writes one token and reports whether the value actually changed.
static func apply_token(style_resource: Resource, token_name: String, value: Variant) -> bool:
	if style_resource == null or style_resource.get(token_name) == value:
		return false
	style_resource.set(token_name, value)
	return true

func _ensure_dialog() -> void:
	if _dialog != null:
		return
	_dialog = AcceptDialog.new()
	_dialog.title = "Theme Editor"
	_dialog.ok_button_text = "Close"
	var split: HSplitContainer = HSplitContainer.new()
	split.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	split.split_offset = 620

	var preview_scroll: ScrollContainer = ScrollContainer.new()
	preview_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview_viewport = EventSheetViewport.new()
	preview_scroll.add_child(_preview_viewport)
	split.add_child(preview_scroll)

	var form_scroll: ScrollContainer = ScrollContainer.new()
	form_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var form: VBoxContainer = VBoxContainer.new()
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_build_section(form, "Sheet & rows (event style)", _working_style.event_style)
	_build_section(form, "Condition cells", _working_style.condition_style)
	_build_section(form, "Action cells", _working_style.action_style)
	var buttons: HBoxContainer = HBoxContainer.new()
	var apply_button: Button = Button.new()
	apply_button.text = "Apply To Current Sheet"
	apply_button.pressed.connect(_apply_to_sheet)
	buttons.add_child(apply_button)
	var save_button: Button = Button.new()
	save_button.text = "Save As Preset…"
	save_button.pressed.connect(_open_save_dialog)
	buttons.add_child(save_button)
	form.add_child(buttons)
	form_scroll.add_child(form)
	split.add_child(form_scroll)
	_dialog.add_child(split)
	_dock.add_child(_dialog)

## One labeled control per editable token, reflectively.
func _build_section(form: VBoxContainer, title: String, style_resource: Resource) -> void:
	var header: Label = Label.new()
	header.text = title
	header.add_theme_font_size_override("font_size", 15)
	form.add_child(header)
	for token: Dictionary in editable_tokens(style_resource):
		var token_name: String = str(token.get("name"))
		var row: HBoxContainer = HBoxContainer.new()
		var label: Label = Label.new()
		label.text = token_name.capitalize()
		label.custom_minimum_size = Vector2(230.0, 0.0)
		label.tooltip_text = token_name
		row.add_child(label)
		match int(token.get("type")):
			TYPE_COLOR:
				var picker: ColorPickerButton = ColorPickerButton.new()
				picker.color = style_resource.get(token_name)
				picker.custom_minimum_size = Vector2(72.0, 0.0)
				picker.color_changed.connect(func(value: Color) -> void: _on_token_edited(style_resource, token_name, value))
				row.add_child(picker)
			TYPE_BOOL:
				var check: CheckBox = CheckBox.new()
				check.button_pressed = bool(style_resource.get(token_name))
				check.toggled.connect(func(value: bool) -> void: _on_token_edited(style_resource, token_name, value))
				row.add_child(check)
			_:
				var spin: SpinBox = SpinBox.new()
				spin.step = 0.5 if int(token.get("type")) == TYPE_FLOAT else 1.0
				spin.min_value = -4096.0
				spin.max_value = 4096.0
				spin.value = float(style_resource.get(token_name))
				spin.value_changed.connect(func(value: float) -> void: _on_token_edited(style_resource, token_name, value if int(token.get("type")) == TYPE_FLOAT else int(value)))
				row.add_child(spin)
		form.add_child(row)

func _on_token_edited(style_resource: Resource, token_name: String, value: Variant) -> void:
	if apply_token(style_resource, token_name, value) and _preview_viewport != null:
		_preview_viewport.queue_redraw()

func _apply_to_sheet() -> void:
	if _dock != null and _dock.has_method("apply_theme_style"):
		_dock.call("apply_theme_style", _working_style.duplicate(true))

func _open_save_dialog() -> void:
	if _save_dialog == null:
		_save_dialog = FileDialog.new()
		_save_dialog.title = "Save Theme Preset"
		_save_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
		_save_dialog.access = FileDialog.ACCESS_RESOURCES
		_save_dialog.filters = PackedStringArray(["*.tres ; EventSheetEditorStyle"])
		_save_dialog.file_selected.connect(save_preset)
		_dialog.add_child(_save_dialog)
	_save_dialog.popup_centered(Vector2i(720, 480))

## Saves the working style as a shareable preset .tres. Returns OK on success.
func save_preset(path: String) -> Error:
	var to_save: EventSheetEditorStyle = _working_style.duplicate(true)
	var error: Error = ResourceSaver.save(to_save, path)
	if error == OK and _dock != null and _dock.has_method("_set_status"):
		_dock.call("_set_status", "Theme preset saved: %s" % path.get_file())
	return error
