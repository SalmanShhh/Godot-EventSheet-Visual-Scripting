# Godot EventSheets - Visual theme editor (designer-facing)
# A live theme workbench: the left pane is a REAL EventSheetViewport rendering a sample
# sheet; the right pane is a token form generated REFLECTIVELY from the style resources'
# exported properties (Color → color picker, float/int → spinbox, bool → checkbox), so new
# tokens added to the style classes appear here automatically - no editor changes needed.
# Edits write into a duplicated working style and repaint live; "Apply" assigns it to the
# current sheet, "Save As Preset…" writes a shareable .tres.
@tool
class_name EventSheetThemeEditor
extends RefCounted

var _dialog: AcceptDialog = null
var _preview_viewport: EventSheetViewport = null
var _working_style: EventSheetEditorStyle = null
var _dock: Control = null
var _save_dialog: FileDialog = null
# Quick Style: derive the whole palette from a few colours (no token-by-token tweaking).
var _detail_form: VBoxContainer = null
var _quick_base: ColorPickerButton = null
var _quick_accent: ColorPickerButton = null
var _quick_font: ColorPickerButton = null


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
	tint.comment = "Cell note (⊳)"
	tint_event.actions.append(tint)
	# Loop/pick rows, BBCode comments, and a disabled row - the newest vocabulary, so
	# restyling sees everything the renderer can draw.
	var repeat_pick: PickFilter = PickFilter.new()
	repeat_pick.collection_kind = PickFilter.CollectionKind.REPEAT
	repeat_pick.collection_value = "3"
	repeat_pick.iterator_name = "i"
	tint_event.pick_filters.append(repeat_pick)
	sheet.events.append(tint_event)
	var bbcode_comment: CommentRow = CommentRow.new()
	bbcode_comment.text = "[b]Bold[/b], [i]italic[/i] and [color=orange]colored[/color] BBCode"
	sheet.events.append(bbcode_comment)
	# A language block (a pure-data inner class) so the language_block_accent_color token shows live.
	var language_sample: RawCodeRow = RawCodeRow.new()
	language_sample.code = "class Sample:\n\tvar speed: float = 1.0"
	sheet.events.append(language_sample)
	var disabled_event: EventRow = EventRow.new()
	disabled_event.trigger_provider_id = "Core"
	disabled_event.trigger_id = "OnReady"
	disabled_event.enabled = false
	var disabled_action: ACEAction = ACEAction.new()
	disabled_action.provider_id = "Core"
	disabled_action.ace_id = "QueueFree"
	disabled_event.actions.append(disabled_action)
	sheet.events.append(disabled_event)
	return sheet


## Plain-language descriptions of what each theme token does, shown as a hover tooltip on its row.
## A token not listed here falls back to its humanized name (still readable, just less descriptive).
const _TOKEN_DESCRIPTIONS := {
	"sheet_background_color": "The colour behind the whole sheet, outside the rows.",
	"row_background_color": "The background of a normal event row.",
	"row_background_alt_color": "The background of every OTHER row (the zebra stripe).",
	"row_border_color": "The thin line between rows.",
	"condition_lane_color": "A faint tint over the conditions (left) lane.",
	"action_lane_color": "A faint tint over the actions (right) lane.",
	"lane_divider_color": "The vertical line splitting conditions from actions.",
	"condition_lane_ratio": "How much of the row width the conditions lane takes (0.2 - 0.8).",
	"minimum_conditions_lane_width": "The conditions lane never shrinks below this many pixels.",
	"condition_lane_padding": "Inner padding on the conditions lane, in pixels.",
	"condition_badge_column_width": "Width reserved for the trigger/condition badge column.",
	"action_lane_padding": "Inner padding on the actions lane, in pixels.",
	"lane_divider_width": "Thickness of the conditions/actions divider line.",
	"minimum_row_height": "Height of a single event row, in pixels - raise it for more breathing room.",
	"group_row_height": "Height of a group header bar, in pixels - double an event row by default; lower it for the classic slim bar.",
	"trigger_badge_background_color": "Fill of the trigger arrow badge (On Ready, On Signal...).",
	"trigger_badge_foreground_color": "Icon/text colour on the trigger badge.",
	"group_background_color": "Background of a group header row.",
	"group_background_alt_color": "Alternate group header background (zebra).",
	"group_accent_color": "The group's left accent stripe and hairlines.",
	"group_title_color": "The group title text colour.",
	"group_badge_background_color": "Fill of the count badge on a group.",
	"group_badge_foreground_color": "Text colour on the group count badge.",
	"group_fold_background_color": "Background of the fold triangle box on a group.",
	"comment_row_background_color": "The banner colour behind a full-width comment.",
	"comment_text_color": "The text colour of comments.",
	"selection_fill_color": "The highlight over a selected row.",
	"hover_fill_color": "The tint over the row under the mouse.",
	"column_header_background_color": "Background of the Conditions / Actions column header bar.",
	"column_header_conditions_color": "The 'Conditions' header label colour.",
	"column_header_actions_color": "The 'Actions' header label colour.",
	"invert_marker_color": "The red X shown on an inverted (negated) condition.",
	"object_label_color": "The object/origin label before each condition/action (System, node class).",
	"value_highlight_color": "Parameter values (numbers, strings) highlighted inside ACE text.",
	"cell_hover_color": "Tint over a single condition/action cell under the mouse.",
	"behavior_accent_color": "The soft-purple 'this is a behavior' accent (banner, region default).",
	"language_block_accent_color": "The stripe + wash on language blocks (a data class, a host binding, a switch case) so they read as code structure, not regular events.",
	"event_corner_radius": "Corner roundness of the event block, in pixels (0 = square).",
	"cell_corner_radius": "Corner roundness of individual condition/action cells.",
	"group_corner_radius": "Corner roundness of group rows (0 = square bar).",
	"region_corner_radius": "Corner roundness of region marker bubbles.",
	"region_line_width": "Line thickness of region marker borders.",
	"font_size_delta": "Text size adjustment for this chip kind, relative to the sheet font (+/- points).",
	"horizontal_padding": "Space inside the chip, left and right of its text, in pixels.",
	"vertical_padding": "Space inside the chip, above and below its text, in pixels.",
	"gap_after": "Space between this chip and the next one, in pixels.",
	"badge_extra_width": "Extra width reserved for the role badge on the chip, in pixels.",
	"text_color": "The text colour of the chip.",
	"chip_background_color": "Fill of the condition/action chip.",
	"chip_border_color": "Border of the condition/action chip.",
	"chip_hover_color": "Chip fill when hovered.",
	"badge_background_color": "Fill of the role badge on the chip.",
	"badge_foreground_color": "Text colour of the role badge.",
	"corner_radius": "Corner roundness of the chip, in pixels.",
}


## The hover description for a token (falls back to its humanized name).
static func _token_description(token_name: String) -> String:
	return str(_TOKEN_DESCRIPTIONS.get(token_name, token_name.capitalize()))


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
	# Both panes carry REAL minimum sizes (field-test catch: with none, the dialog
	# auto-sized to the preview alone and the token controls collapsed to a sliver -
	# the editor looked like "just highlighting things").
	split.split_offset = 560
	split.custom_minimum_size = Vector2(1000.0, 540.0)

	var preview_scroll: ScrollContainer = ScrollContainer.new()
	preview_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_scroll.custom_minimum_size = Vector2(420.0, 0.0)
	_preview_viewport = EventSheetViewport.new()
	preview_scroll.add_child(_preview_viewport)
	split.add_child(preview_scroll)

	var form_scroll: ScrollContainer = ScrollContainer.new()
	form_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	form_scroll.custom_minimum_size = Vector2(380.0, 0.0)
	form_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var form: VBoxContainer = VBoxContainer.new()
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Quick Style (whole-palette recolour) on top, then the per-token detail form below it.
	_build_quick_style(form)
	_detail_form = VBoxContainer.new()
	_detail_form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form.add_child(_detail_form)
	_rebuild_detail_form()
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


## Quick Style - three colours drive the whole palette (base tone, accent, text). One
## button regenerates every colour token via EventSheetGodotTheme.apply, so re-skinning is
## "pick a colour, click Generate" instead of tuning thirty fields by hand.
func _build_quick_style(form: VBoxContainer) -> void:
	# Quick Style as a themed inset card with an accent header (consistent with the token sections below).
	var quick_box: VBoxContainer = EventSheetPopupUI.form_box()
	quick_box.add_child(EventSheetPopupUI.hint_label("Pick a base + accent, then Generate. Fine-tune individual tokens below."))
	_quick_base = _quick_color_row(quick_box, "Base (background tone)", Color("#252525"))
	_quick_accent = _quick_color_row(quick_box, "Accent (groups, selection)", Color("#569eff"))
	_quick_font = _quick_color_row(quick_box, "Text", Color("#ced0d2"))
	var buttons: HBoxContainer = HBoxContainer.new()
	var generate: Button = Button.new()
	generate.text = "Generate Theme"
	generate.tooltip_text = "Rebuild every colour token from the three colours above."
	generate.pressed.connect(_generate_quick_style)
	buttons.add_child(generate)
	var reset: Button = Button.new()
	reset.text = "Reset To Default"
	reset.tooltip_text = "Restore the bundled default look."
	reset.pressed.connect(_reset_to_default)
	buttons.add_child(reset)
	quick_box.add_child(buttons)
	form.add_child(EventSheetPopupUI.titled_card("Quick Style - recolour everything at once", quick_box))


## One labelled colour picker, returned so Quick Style can read it back on Generate.
func _quick_color_row(form: VBoxContainer, label_text: String, default_color: Color) -> ColorPickerButton:
	var row: HBoxContainer = HBoxContainer.new()
	var label: Label = Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(230.0, 0.0)
	row.add_child(label)
	var picker: ColorPickerButton = ColorPickerButton.new()
	picker.color = default_color
	picker.custom_minimum_size = Vector2(72.0, 0.0)
	row.add_child(picker)
	form.add_child(row)
	return picker


## Derives the two dark tones from the base, regenerates the whole sheet palette, and
## refreshes the detail form + live preview.
func _generate_quick_style() -> void:
	if _working_style == null:
		return
	var base: Color = _quick_base.color
	EventSheetGodotTheme.apply(_working_style, base, base.darkened(0.15), base.darkened(0.25), _quick_accent.color, _quick_font.color)
	_rebuild_detail_form()
	if _preview_viewport != null:
		_preview_viewport.set_sheet(build_sample_sheet(_working_style))


## Restores the bundled default look - a clean starting point.
func _reset_to_default() -> void:
	_working_style = duplicate_style(null)
	if _working_style.has_method("ensure_defaults"):
		_working_style.call("ensure_defaults")
	_rebuild_detail_form()
	if _preview_viewport != null:
		_preview_viewport.set_sheet(build_sample_sheet(_working_style))


## (Re)builds the reflective per-token form into _detail_form, clearing any prior fields so
## the spinboxes/pickers always reflect the current (possibly just-regenerated) style.
func _rebuild_detail_form() -> void:
	if _detail_form == null:
		return
	for child: Node in _detail_form.get_children():
		_detail_form.remove_child(child)
		child.queue_free()
	_build_section(_detail_form, "Editor (hover, selection, lanes)", _working_style)
	_build_section(_detail_form, "Sheet & rows (event style)", _working_style.event_style)
	_build_section(_detail_form, "Condition cells", _working_style.condition_style)
	_build_section(_detail_form, "Action cells", _working_style.action_style)


## One labeled control per editable token, reflectively.
func _build_section(form: VBoxContainer, title: String, style_resource: Resource) -> void:
	# Each style section is a themed inset card with an accent header (matches the picker's panels).
	var section_box: VBoxContainer = EventSheetPopupUI.form_box()
	for token: Dictionary in editable_tokens(style_resource):
		var token_name: String = str(token.get("name"))
		var description: String = _token_description(token_name)
		var row: HBoxContainer = HBoxContainer.new()
		row.tooltip_text = description
		var label: Label = Label.new()
		label.text = token_name.capitalize()
		label.custom_minimum_size = Vector2(230.0, 0.0)
		label.tooltip_text = description
		label.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(label)
		match int(token.get("type")):
			TYPE_COLOR:
				var picker: ColorPickerButton = ColorPickerButton.new()
				picker.color = style_resource.get(token_name)
				picker.custom_minimum_size = Vector2(72.0, 0.0)
				picker.tooltip_text = description
				picker.color_changed.connect(func(value: Color) -> void: _on_token_edited(style_resource, token_name, value))
				row.add_child(picker)
			TYPE_BOOL:
				var check: CheckBox = CheckBox.new()
				check.button_pressed = bool(style_resource.get(token_name))
				check.tooltip_text = description
				check.toggled.connect(func(value: bool) -> void: _on_token_edited(style_resource, token_name, value))
				row.add_child(check)
			_:
				var spin: SpinBox = SpinBox.new()
				spin.step = 0.5 if int(token.get("type")) == TYPE_FLOAT else 1.0
				spin.min_value = -4096.0
				spin.max_value = 4096.0
				spin.value = float(style_resource.get(token_name))
				spin.tooltip_text = description
				spin.value_changed.connect(func(value: float) -> void: _on_token_edited(style_resource, token_name, value if int(token.get("type")) == TYPE_FLOAT else int(value)))
				row.add_child(spin)
		section_box.add_child(row)
	form.add_child(EventSheetPopupUI.titled_card(title, section_box))


func _on_token_edited(style_resource: Resource, token_name: String, value: Variant) -> void:
	if apply_token(style_resource, token_name, value) and _preview_viewport != null:
		# Rebuild the sample sheet so BOTH colour and STRUCTURAL tokens (row height, corner radii, lane
		# widths, line thickness) show live - a plain repaint keeps the old cached layout.
		_preview_viewport.set_sheet(build_sample_sheet(_working_style))


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
