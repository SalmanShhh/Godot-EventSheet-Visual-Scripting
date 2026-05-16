# EventForge — Comment row UI
# Lightweight inline comment row aligned to the sheet lane/grid model.
@tool
extends PanelContainer
class_name CommentRowUI

signal comment_selected(row: CommentRowUI)
signal comment_delete_requested(row: CommentRowUI)
signal insert_comment_above_requested(row: CommentRowUI)
signal insert_comment_below_requested(row: CommentRowUI)

const LANE_DIVIDER_WIDTH: int = 2
const INSERT_CONTROL_DIM_ALPHA: float = 0.46

var comment_row: CommentRow = null

var _comment_text_label: Label = null
var _depth: int = 0
var _selected: bool = false
var _hovered: bool = false
var _insert_above_btn: Button = null
var _insert_below_btn: Button = null

func _init() -> void:
	_build_ui()

func _build_ui() -> void:
	_apply_row_style()

	var line: HBoxContainer = HBoxContainer.new()
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_theme_constant_override("separation", 0)
	add_child(line)

	var meta_lane: PanelContainer = PanelContainer.new()
	meta_lane.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meta_lane.size_flags_stretch_ratio = 1.0
	var meta_lane_style: StyleBoxFlat = StyleBoxFlat.new()
	meta_lane_style.bg_color = Color(0.130, 0.118, 0.100, 1.0)
	meta_lane_style.set_border_width_all(0)
	meta_lane_style.set_corner_radius_all(0)
	meta_lane_style.set_content_margin(SIDE_LEFT, 6)
	meta_lane_style.set_content_margin(SIDE_RIGHT, 4)
	meta_lane_style.set_content_margin(SIDE_TOP, 2)
	meta_lane_style.set_content_margin(SIDE_BOTTOM, 2)
	meta_lane.add_theme_stylebox_override("panel", meta_lane_style)
	line.add_child(meta_lane)

	var left_hbox: HBoxContainer = HBoxContainer.new()
	left_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_hbox.add_theme_constant_override("separation", 6)
	meta_lane.add_child(left_hbox)

	var badge_panel: PanelContainer = PanelContainer.new()
	var badge_style: StyleBoxFlat = StyleBoxFlat.new()
	badge_style.bg_color = Color(0.214, 0.177, 0.104, 1.0)
	badge_style.border_color = Color(0.412, 0.338, 0.175, 1.0)
	badge_style.set_border_width_all(1)
	badge_style.set_corner_radius_all(3)
	badge_style.set_content_margin(SIDE_LEFT, 5)
	badge_style.set_content_margin(SIDE_RIGHT, 5)
	badge_style.set_content_margin(SIDE_TOP, 1)
	badge_style.set_content_margin(SIDE_BOTTOM, 1)
	badge_panel.add_theme_stylebox_override("panel", badge_style)
	var badge: Label = Label.new()
	badge.text = "Comment"
	badge.add_theme_color_override("font_color", Color(1.0, 0.93, 0.66))
	badge.add_theme_font_size_override("font_size", 9)
	badge_panel.add_child(badge)
	left_hbox.add_child(badge_panel)

	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_hbox.add_child(spacer)

	var lane_div: ColorRect = ColorRect.new()
	lane_div.custom_minimum_size = Vector2(LANE_DIVIDER_WIDTH, 0)
	lane_div.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lane_div.color = Color(0.44, 0.36, 0.22, 0.92)
	lane_div.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(lane_div)

	var comment_lane: PanelContainer = PanelContainer.new()
	comment_lane.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	comment_lane.size_flags_stretch_ratio = 1.85
	var comment_lane_style: StyleBoxFlat = StyleBoxFlat.new()
	comment_lane_style.bg_color = Color(0.115, 0.103, 0.086, 1.0)
	comment_lane_style.set_border_width_all(0)
	comment_lane_style.set_corner_radius_all(0)
	comment_lane_style.set_content_margin(SIDE_LEFT, 6)
	comment_lane_style.set_content_margin(SIDE_RIGHT, 4)
	comment_lane_style.set_content_margin(SIDE_TOP, 2)
	comment_lane_style.set_content_margin(SIDE_BOTTOM, 2)
	comment_lane.add_theme_stylebox_override("panel", comment_lane_style)
	line.add_child(comment_lane)

	var comment_hbox: HBoxContainer = HBoxContainer.new()
	comment_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	comment_hbox.add_theme_constant_override("separation", 4)
	comment_lane.add_child(comment_hbox)

	_comment_text_label = Label.new()
	_comment_text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_comment_text_label.add_theme_color_override("font_color", Color(0.90, 0.84, 0.74))
	_comment_text_label.add_theme_font_size_override("font_size", 10)
	comment_hbox.add_child(_comment_text_label)

	_insert_above_btn = Button.new()
	_insert_above_btn.text = "+↑"
	_insert_above_btn.flat = true
	_insert_above_btn.tooltip_text = "Insert comment above this row"
	_insert_above_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_insert_above_btn.add_theme_color_override("font_color", Color(0.90, 0.82, 0.62))
	_insert_above_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.94, 0.76))
	_insert_above_btn.connect("pressed", _on_insert_above_pressed)
	comment_hbox.add_child(_insert_above_btn)

	_insert_below_btn = Button.new()
	_insert_below_btn.text = "+↓"
	_insert_below_btn.flat = true
	_insert_below_btn.tooltip_text = "Insert comment below this row"
	_insert_below_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_insert_below_btn.add_theme_color_override("font_color", Color(0.90, 0.82, 0.62))
	_insert_below_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.94, 0.76))
	_insert_below_btn.connect("pressed", _on_insert_below_pressed)
	comment_hbox.add_child(_insert_below_btn)

	var edit_btn: Button = Button.new()
	edit_btn.text = "✎"
	edit_btn.flat = true
	edit_btn.tooltip_text = "Select comment"
	edit_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	edit_btn.add_theme_color_override("font_color", Color(0.88, 0.82, 0.72))
	edit_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.93, 0.82))
	edit_btn.connect("pressed", _on_pressed)
	comment_hbox.add_child(edit_btn)

	var delete_btn: Button = Button.new()
	delete_btn.text = "×"
	delete_btn.flat = true
	delete_btn.tooltip_text = "Delete comment"
	delete_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	delete_btn.add_theme_color_override("font_color", Color(0.80, 0.42, 0.42))
	delete_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.55, 0.55))
	delete_btn.add_theme_font_size_override("font_size", 12)
	delete_btn.connect("pressed", _on_delete_pressed)
	comment_hbox.add_child(delete_btn)

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
		style.bg_color = Color(0.170, 0.142, 0.098, 1.0)
		style.border_color = Color(0.688, 0.548, 0.268, 1.0)
	elif _hovered:
		style.bg_color = Color(0.146, 0.122, 0.086, 1.0)
		style.border_color = Color(0.520, 0.420, 0.245, 1.0)
	else:
		style.bg_color = Color(0.124, 0.103, 0.073, 1.0)
		style.border_color = Color(0.372, 0.304, 0.184, 1.0)
	style.set_border_width_all(1)
	style.border_width_left = 4 + min(_depth, 4)
	style.set_corner_radius_all(0)
	style.set_content_margin_all(4)
	style.content_margin_left = 8
	add_theme_stylebox_override("panel", style)

func _apply_affordance_state() -> void:
	var controls_alpha: float = 1.0 if (_hovered or _selected) else INSERT_CONTROL_DIM_ALPHA
	if _insert_above_btn != null:
		_insert_above_btn.modulate = Color(1.0, 1.0, 1.0, controls_alpha)
	if _insert_below_btn != null:
		_insert_below_btn.modulate = Color(1.0, 1.0, 1.0, controls_alpha)

func refresh() -> void:
	if comment_row == null or _comment_text_label == null:
		return
	var text: String = comment_row.text.strip_edges()
	_comment_text_label.text = ("# %s" % text) if not text.is_empty() else "# (comment)"

func _on_pressed() -> void:
	comment_selected.emit(self)

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

func _on_mouse_entered() -> void:
	_hovered = true
	_apply_row_style()
	_apply_affordance_state()

func _on_mouse_exited() -> void:
	_hovered = false
	_apply_row_style()
	_apply_affordance_state()
