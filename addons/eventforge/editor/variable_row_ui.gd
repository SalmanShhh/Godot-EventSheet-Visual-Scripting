# EventForge — Variable row UI
# Renders a single global variable as a green-tinted document row.
@tool
extends PanelContainer
class_name VariableRowUI

## Emitted when this variable row is clicked for focused editing.
signal variable_selected(row: VariableRowUI)

var var_name: String = ""
var var_info: Dictionary = {}

var _label: Label = null

func _init() -> void:
	_build_ui()

func _build_ui() -> void:
	# Green-tinted card with left accent border
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.22, 0.14, 1.0)
	style.border_color = Color(0.25, 0.75, 0.40, 1.0)
	style.set_border_width_all(0)
	style.border_width_left = 3
	style.set_corner_radius_all(3)
	style.set_content_margin_all(6)
	style.content_margin_left = 10
	add_theme_stylebox_override("panel", style)

	var hbox: HBoxContainer = HBoxContainer.new()
	add_child(hbox)

	# Global badge
	var badge: Label = Label.new()
	badge.text = "Global"
	badge.add_theme_color_override("font_color", Color(0.35, 0.95, 0.55))
	badge.add_theme_font_size_override("font_size", 10)
	hbox.add_child(badge)

	# Summary label
	_label = Label.new()
	_label.add_theme_color_override("font_color", Color(0.90, 0.95, 0.90))
	_label.add_theme_font_size_override("font_size", 11)
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(_label)

	# Click button
	var btn: Button = Button.new()
	btn.text = "✎"
	btn.flat = true
	btn.tooltip_text = "Edit variable"
	btn.connect("pressed", _on_pressed)
	hbox.add_child(btn)

	# Make full row clickable via mouse input
	mouse_filter = Control.MOUSE_FILTER_STOP
	connect("gui_input", _on_gui_input)

## Refreshes the label from var_name and var_info.
func refresh() -> void:
	if _label == null:
		return
	_label.text = "  " + format_summary(var_name, var_info)

## Returns a formatted summary string for a global variable.
## var_info may contain: type (String), default (Variant), value (Variant)
static func format_summary(name: String, info: Dictionary) -> String:
	var type_str: String = str(info.get("type", "Variant"))
	var raw_default: Variant = info.get("default", info.get("value", null))
	var default_str: String = _format_default(type_str, raw_default)
	return "%s  %s = %s" % [type_str, name, default_str]

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
