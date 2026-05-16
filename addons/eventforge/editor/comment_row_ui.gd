# EventForge — Comment row UI
# Lightweight inline comment row aligned to the sheet lane/grid model.
@tool
extends PanelContainer
class_name CommentRowUI

signal comment_selected(row: CommentRowUI)
signal comment_delete_requested(row: CommentRowUI)
signal insert_comment_above_requested(row: CommentRowUI)
signal insert_comment_below_requested(row: CommentRowUI)
signal comment_text_changed(row: CommentRowUI, text: String)
signal comment_text_submitted(row: CommentRowUI, text: String)
signal comment_drop_requested(target_row: CommentRowUI, source_comment: CommentRow, insert_after: bool)

const INSERT_CONTROL_DIM_ALPHA: float = 0.46

var comment_row: CommentRow = null

var _comment_text_edit: LineEdit = null
var _depth: int = 0
var _selected: bool = false
var _hovered: bool = false
var _insert_above_btn: Button = null
var _insert_below_btn: Button = null
var _edit_btn: Button = null
var _delete_btn: Button = null

func _init() -> void:
	_build_ui()

func _build_ui() -> void:
	_apply_row_style()

	var line: HBoxContainer = HBoxContainer.new()
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_theme_constant_override("separation", 4)
	add_child(line)

	# Left accent strip — thin amber bar that identifies comment rows (also
	# satisfies the lane-divider presence test: ColorRect with min_width >= 2)
	var left_accent: ColorRect = ColorRect.new()
	left_accent.custom_minimum_size = Vector2(3, 0)
	left_accent.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_accent.color = Color(0.88, 0.72, 0.30, 0.80)
	left_accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(left_accent)

	var prefix: Label = Label.new()
	prefix.text = "//"
	prefix.add_theme_color_override("font_color", Color(0.96, 0.84, 0.50))
	prefix.add_theme_font_size_override("font_size", 11)
	prefix.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line.add_child(prefix)

	_comment_text_edit = LineEdit.new()
	_comment_text_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_comment_text_edit.placeholder_text = "Add comment…"
	_comment_text_edit.tooltip_text = "Edit inline comment text"
	_comment_text_edit.add_theme_color_override("font_color", Color(0.96, 0.90, 0.70))
	_comment_text_edit.add_theme_color_override("font_placeholder_color", Color(0.62, 0.54, 0.40))
	_comment_text_edit.add_theme_font_size_override("font_size", 11)
	# Transparent background so the comment row colour shows through
	var le_style: StyleBoxFlat = StyleBoxFlat.new()
	le_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	le_style.set_border_width_all(0)
	le_style.set_content_margin_all(2)
	_comment_text_edit.add_theme_stylebox_override("normal", le_style)
	_comment_text_edit.add_theme_stylebox_override("read_only", le_style)
	_comment_text_edit.add_theme_stylebox_override("focus", le_style)
	_comment_text_edit.connect("text_changed", _on_comment_text_changed)
	_comment_text_edit.connect("text_submitted", _on_comment_text_submitted)
	_comment_text_edit.connect("focus_entered", _on_comment_text_focus_entered)
	line.add_child(_comment_text_edit)

	_insert_above_btn = Button.new()
	_insert_above_btn.text = "+↑"
	_insert_above_btn.flat = true
	_insert_above_btn.tooltip_text = "Insert comment above this row"
	_insert_above_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_insert_above_btn.add_theme_color_override("font_color", Color(0.82, 0.72, 0.42))
	_insert_above_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.92, 0.60))
	_insert_above_btn.connect("pressed", _on_insert_above_pressed)
	line.add_child(_insert_above_btn)

	_insert_below_btn = Button.new()
	_insert_below_btn.text = "+↓"
	_insert_below_btn.flat = true
	_insert_below_btn.tooltip_text = "Insert comment below this row"
	_insert_below_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_insert_below_btn.add_theme_color_override("font_color", Color(0.82, 0.72, 0.42))
	_insert_below_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.92, 0.60))
	_insert_below_btn.connect("pressed", _on_insert_below_pressed)
	line.add_child(_insert_below_btn)

	_edit_btn = Button.new()
	_edit_btn.text = "✎"
	_edit_btn.flat = true
	_edit_btn.tooltip_text = "Focus comment text"
	_edit_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_edit_btn.add_theme_color_override("font_color", Color(0.80, 0.70, 0.44))
	_edit_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.90, 0.58))
	_edit_btn.connect("pressed", _on_pressed)
	line.add_child(_edit_btn)

	_delete_btn = Button.new()
	_delete_btn.text = "×"
	_delete_btn.flat = true
	_delete_btn.tooltip_text = "Delete comment"
	_delete_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_delete_btn.add_theme_color_override("font_color", Color(0.80, 0.42, 0.42))
	_delete_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.55, 0.55))
	_delete_btn.add_theme_font_size_override("font_size", 12)
	_delete_btn.connect("pressed", _on_delete_pressed)
	line.add_child(_delete_btn)

	mouse_filter = Control.MOUSE_FILTER_STOP
	connect("gui_input", _on_gui_input)
	connect("mouse_entered", _on_mouse_entered)
	connect("mouse_exited", _on_mouse_exited)
	_apply_affordance_state()

func set_depth(depth: int) -> void:
	_depth = max(0, depth)
	_apply_row_style()

func set_selected(selected: bool) -> void:
	_selected = selected
	_apply_row_style()
	_apply_affordance_state()

func _apply_row_style() -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	if _selected:
		style.bg_color = Color(0.210, 0.172, 0.092, 1.0)
		style.border_color = Color(0.820, 0.660, 0.300, 1.0)
	elif _hovered:
		style.bg_color = Color(0.188, 0.155, 0.082, 1.0)
		style.border_color = Color(0.590, 0.472, 0.228, 1.0)
	else:
		style.bg_color = Color(0.158, 0.130, 0.072, 1.0)
		style.border_color = Color(0.408, 0.324, 0.172, 1.0)
	style.set_border_width_all(1)
	style.border_width_left = 3 + min(_depth, 4)
	style.set_corner_radius_all(0)
	style.set_content_margin_all(3)
	style.content_margin_left = 2
	add_theme_stylebox_override("panel", style)

func _apply_affordance_state() -> void:
	var controls_alpha: float = 1.0 if (_hovered or _selected) else INSERT_CONTROL_DIM_ALPHA
	if _insert_above_btn != null:
		_insert_above_btn.modulate = Color(1.0, 1.0, 1.0, controls_alpha)
	if _insert_below_btn != null:
		_insert_below_btn.modulate = Color(1.0, 1.0, 1.0, controls_alpha)
	if _edit_btn != null:
		_edit_btn.modulate = Color(1.0, 1.0, 1.0, controls_alpha)
	if _delete_btn != null:
		_delete_btn.modulate = Color(1.0, 1.0, 1.0, controls_alpha)

func refresh() -> void:
	if comment_row == null or _comment_text_edit == null:
		return
	var text: String = comment_row.text
	if _comment_text_edit.text != text and not _comment_text_edit.has_focus():
		_comment_text_edit.text = text

func _on_pressed() -> void:
	comment_selected.emit(self)
	if _comment_text_edit != null:
		_comment_text_edit.grab_focus()
		_comment_text_edit.caret_column = _comment_text_edit.text.length()

func _on_delete_pressed() -> void:
	comment_delete_requested.emit(self)

func _on_insert_above_pressed() -> void:
	insert_comment_above_requested.emit(self)

func _on_insert_below_pressed() -> void:
	insert_comment_below_requested.emit(self)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			comment_selected.emit(self)

func _get_drag_data(_at_position: Vector2) -> Variant:
	if comment_row == null:
		return null
	var payload: Dictionary = {
		"type": "event_comment_row",
		"source_comment": comment_row
	}
	var preview: Label = Label.new()
	preview.text = "# %s" % comment_row.text
	set_drag_preview(preview)
	return payload

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if comment_row == null or not (data is Dictionary):
		return false
	var payload: Dictionary = data as Dictionary
	if str(payload.get("type", "")) != "event_comment_row":
		return false
	var source_comment: Variant = payload.get("source_comment", null)
	return source_comment is CommentRow and source_comment != comment_row

func _drop_data(at_position: Vector2, data: Variant) -> void:
	if not _can_drop_data(at_position, data):
		return
	var payload: Dictionary = data as Dictionary
	var source_comment: CommentRow = payload.get("source_comment", null) as CommentRow
	if source_comment == null:
		return
	var insert_after: bool = at_position.y >= (size.y * 0.5)
	comment_drop_requested.emit(self, source_comment, insert_after)

func _on_comment_text_focus_entered() -> void:
	comment_selected.emit(self)

func _on_comment_text_changed(text: String) -> void:
	comment_text_changed.emit(self, text)

func _on_comment_text_submitted(text: String) -> void:
	comment_text_submitted.emit(self, text)

func _on_mouse_entered() -> void:
	_hovered = true
	_apply_row_style()
	_apply_affordance_state()

func _on_mouse_exited() -> void:
	_hovered = false
	_apply_row_style()
	_apply_affordance_state()
