@tool
class_name EventSheetBBCodeSelectionBar
extends PanelContainer

# The Discord-style formatting bar: highlight text in a TextEdit and a small unfocused
# toolbar floats above the selection - B / I / U / S toggle the matching BBCode wrap on
# the selected text, the swatch wraps [color=#hex]. Every control is FOCUS_NONE so
# clicking never steals the selection, and the host TextEdit keeps its selection on
# focus loss so the color picker can open without losing what you highlighted.
#
# Attach with `EventSheetBBCodeSelectionBar.attach(text_edit)` - the bar parents itself
# to the TextEdit, tracks caret changes, and shows only while a selection exists.
# Ctrl+B / Ctrl+I / Ctrl+U toggle the wraps from the keyboard, Discord-style.

var _text_edit: TextEdit = null
var _color_button: ColorPickerButton = null


static func attach(text_edit: TextEdit) -> EventSheetBBCodeSelectionBar:
	var bar: EventSheetBBCodeSelectionBar = EventSheetBBCodeSelectionBar.new()
	bar._text_edit = text_edit
	# Keep the highlight alive while the bar's color picker (or anything else) takes
	# focus - the selection IS the pending operand.
	text_edit.deselect_on_focus_loss_enabled = false
	text_edit.add_child(bar)
	bar._build()
	text_edit.caret_changed.connect(bar._refresh)
	text_edit.text_changed.connect(bar._refresh)
	text_edit.gui_input.connect(bar._on_text_edit_input)
	bar.visible = false
	return bar


func _build() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 10
	# The Discord-style chip look, self-contained so the bar reads as a floating toolbar
	# over any theme (it sits INSIDE the TextEdit, above the text).
	var chip: StyleBoxFlat = StyleBoxFlat.new()
	chip.bg_color = Color(0.12, 0.13, 0.16, 0.97)
	chip.border_color = Color(0.3, 0.32, 0.38)
	chip.set_border_width_all(1)
	chip.set_corner_radius_all(6)
	chip.content_margin_left = 4.0
	chip.content_margin_right = 4.0
	chip.content_margin_top = 3.0
	chip.content_margin_bottom = 3.0
	add_theme_stylebox_override("panel", chip)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	add_child(row)
	row.add_child(_format_button("B", "Bold (Ctrl+B)", "[b]", "[/b]"))
	row.add_child(_format_button("I", "Italic (Ctrl+I)", "[i]", "[/i]"))
	row.add_child(_format_button("U", "Underline (Ctrl+U)", "[u]", "[/u]"))
	row.add_child(_format_button("S", "Strikethrough", "[s]", "[/s]"))
	_color_button = ColorPickerButton.new()
	_color_button.custom_minimum_size = Vector2(30.0, 0.0)
	_color_button.color = Color(1.0, 0.82, 0.4)
	_color_button.tooltip_text = "Color the selected text"
	_color_button.focus_mode = Control.FOCUS_NONE
	_color_button.popup_closed.connect(func() -> void:
		_wrap_selection("[color=#%s]" % _color_button.color.to_html(false), "[/color]"))
	row.add_child(_color_button)


func _format_button(label: String, tooltip: String, open_tag: String, close_tag: String) -> Button:
	var button: Button = Button.new()
	button.text = label
	button.tooltip_text = tooltip
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(30.0, 0.0)
	button.pressed.connect(func() -> void: _wrap_selection(open_tag, close_tag))
	return button


## Toggle-wraps the selection: an exactly-wrapped selection unwraps (Discord behavior),
## anything else wraps. The result stays selected, so formats stack ([b] then [i]).
func _wrap_selection(open_tag: String, close_tag: String) -> void:
	if _text_edit == null or not _text_edit.has_selection():
		return
	var selected: String = _text_edit.get_selected_text()
	var replacement: String
	var already_wrapped: bool = selected.begins_with(open_tag) and selected.ends_with(close_tag)
	# The color tag's open half varies by hex - any [color=...] counts as wrapped.
	if open_tag.begins_with("[color=") and selected.begins_with("[color=") and selected.ends_with(close_tag):
		already_wrapped = true
	if already_wrapped:
		var inner_start: int = selected.find("]") + 1 if open_tag.begins_with("[color=") else open_tag.length()
		replacement = selected.substr(inner_start, selected.length() - inner_start - close_tag.length())
	else:
		replacement = open_tag + selected + close_tag
	var from_line: int = _text_edit.get_selection_from_line()
	var from_column: int = _text_edit.get_selection_from_column()
	_text_edit.begin_complex_operation()
	_text_edit.delete_selection()
	_text_edit.insert_text_at_caret(replacement)
	_text_edit.end_complex_operation()
	# Re-select the replacement so the next format button stacks onto the same text.
	_text_edit.select(from_line, from_column, _text_edit.get_caret_line(), _text_edit.get_caret_column())
	_refresh()


## Discord keyboard parity on the host TextEdit.
func _on_text_edit_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or not (key.ctrl_pressed or key.meta_pressed) or not _text_edit.has_selection():
		return
	match key.keycode:
		KEY_B:
			_wrap_selection("[b]", "[/b]")
			_text_edit.accept_event()
		KEY_I:
			_wrap_selection("[i]", "[/i]")
			_text_edit.accept_event()
		KEY_U:
			_wrap_selection("[u]", "[/u]")
			_text_edit.accept_event()


## Show above the selection while one exists; hide otherwise. Positions clamp inside the
## TextEdit so the bar never pokes out of the dialog.
func _refresh() -> void:
	if _text_edit == null or not _text_edit.has_selection():
		visible = false
		return
	visible = true
	var anchor: Rect2i = _text_edit.get_rect_at_line_column(_text_edit.get_selection_from_line(), _text_edit.get_selection_from_column())
	var bar_size: Vector2 = get_combined_minimum_size()
	var target: Vector2 = Vector2(anchor.position) + Vector2(0.0, -bar_size.y - 6.0)
	if target.y < 0.0:
		# No room above the first line - sit under the selection's line instead.
		target.y = float(anchor.position.y + anchor.size.y) + 6.0
	target.x = clampf(target.x, 0.0, maxf(_text_edit.size.x - bar_size.x - 8.0, 0.0))
	position = target
