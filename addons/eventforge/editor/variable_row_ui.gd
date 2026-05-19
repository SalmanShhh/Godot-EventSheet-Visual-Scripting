# EventForge — Variable row UI
# Renders a single global variable as a document line row.
@tool
extends PanelContainer
class_name VariableRowUI

const EDIT_VARIABLE_TOOLTIP_PREFIX: String = "Edit variable"

## Emitted when this variable row requests to be edited (single click or double-click).
signal variable_selected(row: VariableRowUI)
## Emitted when this variable row is double-clicked for immediate edit launch.
signal variable_edit_requested(row: VariableRowUI)
## Emitted when the delete button is pressed on this variable row.
signal variable_delete_requested(row: VariableRowUI)

var var_name: String = ""
var var_info: Dictionary = {}

var _summary_label: Label = null
var _edit_btn: Button = null
var _depth: int = 0
var _selected: bool = false
var _hovered: bool = false

func _init() -> void:
	_build_ui()

func _build_ui() -> void:
	_apply_row_style()

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(hbox)

	var badge_panel: PanelContainer = PanelContainer.new()
	var badge_style: StyleBoxFlat = StyleBoxFlat.new()
	badge_style.bg_color = Color(0.168, 0.240, 0.342, 1.0)
	badge_style.border_color = Color(0.320, 0.466, 0.674, 1.0)
	badge_style.set_border_width_all(1)
	badge_style.set_corner_radius_all(0)
	badge_style.set_content_margin(SIDE_LEFT, 5)
	badge_style.set_content_margin(SIDE_RIGHT, 5)
	badge_style.set_content_margin(SIDE_TOP, 1)
	badge_style.set_content_margin(SIDE_BOTTOM, 1)
	badge_panel.add_theme_stylebox_override("panel", badge_style)
	var badge: Label = Label.new()
	badge.text = "Global"
	badge.add_theme_color_override("font_color", Color(0.90, 0.96, 1.0))
	badge.add_theme_font_size_override("font_size", 10)
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge_panel.add_child(badge)
	hbox.add_child(badge_panel)

	_summary_label = Label.new()
	_summary_label.add_theme_color_override("font_color", Color(0.96, 0.98, 1.0))
	_summary_label.add_theme_font_size_override("font_size", 12)
	_summary_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(_summary_label)

	_edit_btn = Button.new()
	_edit_btn.text = "✎"
	_edit_btn.flat = true
	_edit_btn.tooltip_text = "Edit variable"
	_edit_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_edit_btn.add_theme_color_override("font_color", Color(0.78, 0.85, 0.98))
	_edit_btn.add_theme_color_override("font_hover_color", Color(0.90, 0.94, 1.0))
	_edit_btn.add_theme_font_size_override("font_size", 10)
	_edit_btn.connect("pressed", _on_pressed)
	hbox.add_child(_edit_btn)

	var delete_btn: Button = Button.new()
	delete_btn.text = "×"
	delete_btn.flat = true
	delete_btn.tooltip_text = "Delete variable"
	delete_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	delete_btn.add_theme_color_override("font_color", Color(0.80, 0.42, 0.42))
	delete_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.55, 0.55))
	delete_btn.add_theme_font_size_override("font_size", 12)
	delete_btn.connect("pressed", _on_delete_pressed)
	hbox.add_child(delete_btn)

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
		style.bg_color = Color(0.146, 0.220, 0.323, 1.0)
		style.border_color = Color(0.500, 0.740, 0.980, 1.0)
	elif _hovered:
		style.bg_color = Color(0.126, 0.187, 0.279, 1.0)
		style.border_color = Color(0.342, 0.510, 0.718, 1.0)
	else:
		style.bg_color = Color(0.110, 0.165, 0.246, 1.0)
		style.border_color = Color(0.262, 0.390, 0.558, 1.0)
	style.set_border_width_all(1)
	style.border_width_left = 4 + min(_depth, 4)
	style.set_corner_radius_all(0)
	style.set_content_margin_all(4)
	style.content_margin_left = 8
	add_theme_stylebox_override("panel", style)

## Refreshes the label from var_name and var_info.
func refresh() -> void:
	if _summary_label == null:
		return
	_summary_label.text = format_summary(var_name, var_info)
	var tooltip: String = format_tooltip(var_name, var_info)
	tooltip_text = tooltip
	_summary_label.tooltip_text = tooltip
	if _edit_btn != null:
		_edit_btn.tooltip_text = EDIT_VARIABLE_TOOLTIP_PREFIX + "\n\n" + tooltip

## Returns a formatted summary string for a global variable.
## var_info may contain: type (String), default (Variant), value (Variant)
static func format_summary(name: String, info: Dictionary) -> String:
	var type_str: String = str(info.get("type", "Variant"))
	var raw_default: Variant = info.get("default", info.get("value", null))
	var default_str: String = _format_default(type_str, raw_default)
	return "%s (%s) = %s" % [name, type_str, default_str]

## Returns compact tooltip text for a global variable row/button.
## Includes optional description when present.
static func format_tooltip(name: String, info: Dictionary) -> String:
	var type_str: String = str(info.get("type", "Variant"))
	var raw_default: Variant = info.get("default", info.get("value", null))
	var default_str: String = _format_default(type_str, raw_default)
	var lines: Array[String] = []
	lines.append("%s (%s)" % [name, type_str])
	lines.append("Default: %s" % default_str)
	var description: String = str(info.get("description", "")).strip_edges()
	if not description.is_empty():
		lines.append("")
		lines.append(description)
	return "\n".join(lines)

## Formats a default value for display.
static func _format_default(type_str: String, raw: Variant) -> String:
	if raw == null:
		return "null"
	if type_str == "String" or type_str == "StringName":
		var s: String = str(raw)
		if s.begins_with('"') and s.ends_with('"') and s.length() >= 2:
			s = s.substr(1, s.length() - 2)
		s = s.replace('"', '\\"')
		return '"%s"' % s
	if type_str == "float":
		var f: float = float(raw)
		var s: String = str(f)
		if not "." in s and not "e" in s and not "inf" in s and not "nan" in s:
			s = s + ".0"
		return s
	return str(raw)

func _on_pressed() -> void:
	variable_selected.emit(self)

func _on_delete_pressed() -> void:
	variable_delete_requested.emit(self)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			if mb.double_click:
				variable_edit_requested.emit(self)
			else:
				variable_selected.emit(self)

func _on_mouse_entered() -> void:
	_hovered = true
	_apply_row_style()

func _on_mouse_exited() -> void:
	_hovered = false
	_apply_row_style()
