# EventForge — Group row UI
# Lightweight display row for EventGroup in sheet-native composition.
@tool
extends PanelContainer
class_name GroupRowUI

## Emitted when this group row is clicked for inspection.
signal group_selected(row: GroupRowUI)
## Emitted when this group's collapsed state is toggled.
signal group_collapsed_toggled(row: GroupRowUI, collapsed: bool)
## Emitted when the delete button is pressed on this group row.
signal group_delete_requested(row: GroupRowUI)
## Emitted when insertion of a new event is requested above this group row.
signal insert_event_above_requested(row: GroupRowUI)
## Emitted when insertion of a new event is requested below this group row.
signal insert_event_below_requested(row: GroupRowUI)

var event_group: EventGroup = null

var _group_name_label: Label = null
var _count_label: Label = null
var _disclosure_btn: Button = null
var _depth: int = 0
var _selected: bool = false
var _hovered: bool = false
var _insert_above_btn: Button = null
var _insert_below_btn: Button = null
const INSERT_CONTROL_DIM_ALPHA: float = 0.46

func _init() -> void:
	_build_ui()

func _build_ui() -> void:
	_apply_row_style()

	var line: HBoxContainer = HBoxContainer.new()
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_theme_constant_override("separation", 4)
	add_child(line)

	# Left accent strip — thin purple/indigo bar that identifies group rows
	# (also satisfies the lane-divider presence test: ColorRect with min_width >= 2)
	var left_accent: ColorRect = ColorRect.new()
	left_accent.custom_minimum_size = Vector2(3, 0)
	left_accent.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_accent.color = Color(0.60, 0.48, 0.88, 0.80)
	left_accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(left_accent)

	_disclosure_btn = Button.new()
	_disclosure_btn.flat = true
	_disclosure_btn.tooltip_text = "Expand/collapse group"
	_disclosure_btn.add_theme_color_override("font_color", Color(0.80, 0.74, 0.98))
	_disclosure_btn.add_theme_color_override("font_hover_color", Color(0.94, 0.90, 1.0))
	_disclosure_btn.connect("pressed", _on_toggle_pressed)
	line.add_child(_disclosure_btn)

	var badge_label: Label = Label.new()
	badge_label.text = "Group"
	badge_label.add_theme_color_override("font_color", Color(0.68, 0.60, 0.90))
	badge_label.add_theme_font_size_override("font_size", 9)
	badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line.add_child(badge_label)

	_group_name_label = Label.new()
	_group_name_label.add_theme_color_override("font_color", Color(0.95, 0.93, 1.0))
	_group_name_label.add_theme_font_size_override("font_size", 11)
	_group_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(_group_name_label)

	_count_label = Label.new()
	_count_label.add_theme_color_override("font_color", Color(0.56, 0.50, 0.74))
	_count_label.add_theme_font_size_override("font_size", 9)
	_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line.add_child(_count_label)

	_insert_above_btn = Button.new()
	_insert_above_btn.text = "+↑"
	_insert_above_btn.flat = true
	_insert_above_btn.tooltip_text = "Insert event above this group"
	_insert_above_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_insert_above_btn.add_theme_color_override("font_color", Color(0.74, 0.68, 0.94))
	_insert_above_btn.add_theme_color_override("font_hover_color", Color(0.88, 0.84, 1.0))
	_insert_above_btn.connect("pressed", _on_insert_above_pressed)
	line.add_child(_insert_above_btn)

	_insert_below_btn = Button.new()
	_insert_below_btn.text = "+↓"
	_insert_below_btn.flat = true
	_insert_below_btn.tooltip_text = "Insert event below this group"
	_insert_below_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_insert_below_btn.add_theme_color_override("font_color", Color(0.74, 0.68, 0.94))
	_insert_below_btn.add_theme_color_override("font_hover_color", Color(0.88, 0.84, 1.0))
	_insert_below_btn.connect("pressed", _on_insert_below_pressed)
	line.add_child(_insert_below_btn)

	var btn: Button = Button.new()
	btn.text = "✎"
	btn.flat = true
	btn.tooltip_text = "Edit group"
	btn.add_theme_color_override("font_color", Color(0.80, 0.74, 0.96))
	btn.add_theme_color_override("font_hover_color", Color(0.90, 0.86, 1.0))
	btn.connect("pressed", _on_pressed)
	line.add_child(btn)

	var delete_btn: Button = Button.new()
	delete_btn.text = "×"
	delete_btn.flat = true
	delete_btn.tooltip_text = "Delete group"
	delete_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	delete_btn.add_theme_color_override("font_color", Color(0.80, 0.42, 0.42))
	delete_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.55, 0.55))
	delete_btn.add_theme_font_size_override("font_size", 12)
	delete_btn.connect("pressed", _on_delete_pressed)
	line.add_child(delete_btn)

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
		style.bg_color = Color(0.168, 0.124, 0.230, 1.0)
		style.border_color = Color(0.640, 0.490, 0.940, 1.0)
	elif _hovered:
		style.bg_color = Color(0.148, 0.108, 0.208, 1.0)
		style.border_color = Color(0.432, 0.338, 0.624, 1.0)
	else:
		style.bg_color = Color(0.125, 0.094, 0.178, 1.0)
		style.border_color = Color(0.312, 0.248, 0.456, 1.0)
	style.set_border_width_all(1)
	style.border_width_left = 3 + min(_depth, 4)
	style.set_corner_radius_all(0)
	style.set_content_margin_all(3)
	style.content_margin_left = 2
	add_theme_stylebox_override("panel", style)

## Refreshes the display from the assigned event_group resource.
func refresh() -> void:
	if event_group == null or _group_name_label == null:
		return
	var collapsed: bool = event_group.is_collapsed()
	if _disclosure_btn != null:
		_disclosure_btn.text = "▶" if collapsed else "▼"
	var display_name: String = event_group.name
	if display_name.is_empty():
		display_name = event_group.group_name
	if display_name.is_empty():
		display_name = "(unnamed group)"
	_group_name_label.text = display_name
	if _count_label != null:
		var child_rows: Array = event_group.events if not event_group.events.is_empty() else event_group.rows
		var count: int = child_rows.size()
		_count_label.text = "(%d)" % count if count > 0 else ""

func _on_pressed() -> void:
	group_selected.emit(self)

func _on_delete_pressed() -> void:
	group_delete_requested.emit(self)

func _on_insert_above_pressed() -> void:
	insert_event_above_requested.emit(self)

func _on_insert_below_pressed() -> void:
	insert_event_below_requested.emit(self)

func _on_toggle_pressed() -> void:
	if event_group == null:
		return
	var collapsed: bool = event_group.is_collapsed()
	event_group.set_collapsed_state(not collapsed)
	refresh()
	group_collapsed_toggled.emit(self, event_group.collapsed)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			group_selected.emit(self)

func _on_mouse_entered() -> void:
	_hovered = true
	_apply_row_style()
	_apply_affordance_state()

func _on_mouse_exited() -> void:
	_hovered = false
	_apply_row_style()
	_apply_affordance_state()

func _apply_affordance_state() -> void:
	var controls_alpha: float = 1.0 if (_hovered or _selected) else INSERT_CONTROL_DIM_ALPHA
	if _insert_above_btn != null:
		_insert_above_btn.modulate = Color(1.0, 1.0, 1.0, controls_alpha)
	if _insert_below_btn != null:
		_insert_below_btn.modulate = Color(1.0, 1.0, 1.0, controls_alpha)
