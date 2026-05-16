# EventForge — Variable row UI
# Renders a single global variable as a compact event-sheet document row.
@tool
extends PanelContainer
class_name VariableRowUI

const EDIT_VARIABLE_TOOLTIP_PREFIX: String = "Edit variable"
const MAX_NESTING_ACCENT_ADDITION: int = 2

## Emitted when this variable row is clicked for focused editing.
signal variable_selected(row: VariableRowUI)

var var_name: String = ""
var var_info: Dictionary = {}

var _label: Label = null
var _edit_btn: Button = null
var _is_selected: bool = false
var _is_hovered: bool = false
var _nesting_depth: int = 0

func _init() -> void:
	_build_ui()

func _build_ui() -> void:
	_apply_row_style()

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	add_child(hbox)

	# Global badge
	var badge: Label = Label.new()
	badge.text = "Global"
	badge.add_theme_color_override("font_color", Color(0.62, 0.70, 0.89))
	badge.add_theme_font_size_override("font_size", 10)
	hbox.add_child(badge)

	# Summary label
	_label = Label.new()
	_label.add_theme_color_override("font_color", Color(0.86, 0.90, 0.98))
	_label.add_theme_font_size_override("font_size", 11)
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(_label)

	# Click button
	_edit_btn = Button.new()
	_edit_btn.text = "✎"
	_edit_btn.flat = true
	_edit_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_edit_btn.add_theme_color_override("font_color", Color(0.73, 0.79, 0.92))
	_edit_btn.add_theme_color_override("font_hover_color", Color(0.90, 0.94, 1.0))
	_edit_btn.add_theme_font_size_override("font_size", 10)
	_edit_btn.connect("pressed", _on_pressed)
	hbox.add_child(_edit_btn)

	# Make full row clickable via mouse input
	mouse_filter = Control.MOUSE_FILTER_STOP
	connect("gui_input", _on_gui_input)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func set_selected(selected: bool) -> void:
	_is_selected = selected
	_apply_row_style()

func set_nesting_depth(depth: int) -> void:
	_nesting_depth = maxi(0, depth)
	_apply_row_style()

## Refreshes the label from var_name and var_info.
func refresh() -> void:
	if _label == null:
		return
	_label.text = "  " + format_summary(var_name, var_info)
	var tooltip: String = format_tooltip(var_name, var_info)
	tooltip_text = tooltip
	_label.tooltip_text = tooltip
	if _edit_btn != null:
		_edit_btn.tooltip_text = EDIT_VARIABLE_TOOLTIP_PREFIX + "\n\n" + tooltip

## Returns a formatted summary string for a global variable.
## var_info may contain: type (String), default (Variant), value (Variant)
static func format_summary(name: String, info: Dictionary) -> String:
	var type_str: String = str(info.get("type", "Variant"))
	var raw_default: Variant = info.get("default", info.get("value", null))
	var default_str: String = _format_default(type_str, raw_default)
	return "%s  %s = %s" % [type_str, name, default_str]

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
		# If already quoted, strip outer quotes to avoid double-quoting
		if s.begins_with('"') and s.ends_with('"') and s.length() >= 2:
			s = s.substr(1, s.length() - 2)
		# Escape embedded double-quotes
		s = s.replace('"', '\\"')
		return '"%s"' % s
	if type_str == "float":
		var f: float = float(raw)
		var s: String = str(f)
		# Ensure a decimal point is always shown for floats
		if not "." in s and not "e" in s and not "inf" in s and not "nan" in s:
			s = s + ".0"
		return s
	return str(raw)

# ── Private ──────────────────────────────────────────────────────────────────

func _on_pressed() -> void:
	variable_selected.emit(self)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			variable_selected.emit(self)

func _on_mouse_entered() -> void:
	_is_hovered = true
	_apply_row_style()

func _on_mouse_exited() -> void:
	_is_hovered = false
	_apply_row_style()

func _apply_row_style() -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	if _is_selected:
		style.bg_color = Color(0.131, 0.168, 0.238, 1.0)
	elif _is_hovered:
		style.bg_color = Color(0.114, 0.129, 0.172, 1.0)
	else:
		style.bg_color = Color(0.103, 0.115, 0.150, 1.0)
	style.border_color = Color(0.38, 0.58, 0.94, 1.0) if _is_selected else Color(0.129, 0.145, 0.184, 1.0)
	style.set_border_width_all(1)
	style.border_width_left = 3 + mini(_nesting_depth, MAX_NESTING_ACCENT_ADDITION)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(5)
	style.content_margin_left = 8
	add_theme_stylebox_override("panel", style)
