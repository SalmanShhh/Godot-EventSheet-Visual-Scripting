# EventForge — Group row UI
# Lightweight display row for EventGroup in sheet-native composition.
@tool
extends PanelContainer
class_name GroupRowUI

## Emitted when this group row is clicked for inspection.
signal group_selected(row: GroupRowUI)
## Emitted when this group's collapsed state is toggled.
signal group_collapsed_toggled(row: GroupRowUI, collapsed: bool)

var event_group: EventGroup = null

var _group_name_label: Label = null
var _disclosure_btn: Button = null
var _depth: int = 0
var _selected: bool = false
var _hovered: bool = false

func _init() -> void:
	_build_ui()

func _build_ui() -> void:
	_apply_row_style()

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 6)
	add_child(hbox)

	_disclosure_btn = Button.new()
	_disclosure_btn.flat = true
	_disclosure_btn.tooltip_text = "Expand/collapse group"
	_disclosure_btn.add_theme_color_override("font_color", Color(0.78, 0.72, 0.96))
	_disclosure_btn.add_theme_color_override("font_hover_color", Color(0.91, 0.86, 1.0))
	_disclosure_btn.connect("pressed", _on_toggle_pressed)
	hbox.add_child(_disclosure_btn)

	var badge: Label = Label.new()
	badge.text = "Group"
	badge.add_theme_color_override("font_color", Color(0.83, 0.77, 0.98))
	badge.add_theme_font_size_override("font_size", 9)
	hbox.add_child(badge)

	_group_name_label = Label.new()
	_group_name_label.add_theme_color_override("font_color", Color(0.93, 0.92, 1.0))
	_group_name_label.add_theme_font_size_override("font_size", 11)
	_group_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(_group_name_label)

	var btn: Button = Button.new()
	btn.text = "✎"
	btn.flat = true
	btn.tooltip_text = "Edit group"
	btn.add_theme_color_override("font_color", Color(0.83, 0.77, 0.98))
	btn.add_theme_color_override("font_hover_color", Color(0.90, 0.85, 1.0))
	btn.connect("pressed", _on_pressed)
	hbox.add_child(btn)

	mouse_filter = Control.MOUSE_FILTER_STOP
	connect("gui_input", _on_gui_input)
	connect("mouse_entered", _on_mouse_entered)
	connect("mouse_exited", _on_mouse_exited)

func set_depth(depth: int) -> void:
	_depth = max(0, depth)
	_apply_row_style()

func set_selected(selected: bool) -> void:
	_selected = selected
	_apply_row_style()

func _apply_row_style() -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	if _selected:
		style.bg_color = Color(0.166, 0.116, 0.221, 1.0)
		style.border_color = Color(0.607, 0.455, 0.920, 1.0)
	elif _hovered:
		style.bg_color = Color(0.145, 0.103, 0.205, 1.0)
		style.border_color = Color(0.420, 0.320, 0.608, 1.0)
	else:
		style.bg_color = Color(0.122, 0.090, 0.171, 1.0)
		style.border_color = Color(0.304, 0.238, 0.442, 1.0)
	style.set_border_width_all(1)
	style.border_width_left = 2 + min(_depth, 4)
	style.set_corner_radius_all(5)
	style.set_content_margin_all(6)
	style.content_margin_left = 9
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

func _on_pressed() -> void:
	group_selected.emit(self)

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

func _on_mouse_exited() -> void:
	_hovered = false
	_apply_row_style()
