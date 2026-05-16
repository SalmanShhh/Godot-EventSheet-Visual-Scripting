# EventForge — Variable row UI
# Renders a global sheet variable as a canvas block/row in the event sheet document.
# Clicking the row selects the variable for focused inspector editing.
@tool
extends PanelContainer
class_name VariableRowUI

signal selected(var_name: String)

var var_name: String = ""
var descriptor: Dictionary = {}

var _summary_label: Label

## Initialises the row with the given variable name and descriptor dictionary.
func setup(v_name: String, v_desc: Dictionary) -> void:
	var_name = v_name
	descriptor = v_desc

	if _summary_label == null:
		_summary_label = Label.new()
		_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		add_child(_summary_label)

	_summary_label.text = format_summary(v_name, v_desc)
	set_selected(false)

## Formats the one-line summary shown in the canvas row.
## Public so it can be called from tests without constructing the full UI.
static func format_summary(v_name: String, v_desc: Dictionary) -> String:
	var type_str: String = str(v_desc.get("type", "Variant"))
	var default_val: Variant = v_desc.get("default", null)
	var default_str: String = "" if default_val == null else str(default_val)
	if type_str == "String":
		default_str = '"%s"' % default_str
	return "Global %s %s = %s" % [type_str, v_name, default_str]

## Updates the selection highlight.
func set_selected(is_selected: bool) -> void:
	var bg: Color = Color(0.14, 0.30, 0.14, 0.55) if is_selected else Color(0.10, 0.18, 0.10, 0.28)
	add_theme_stylebox_override("panel", _make_stylebox(bg, is_selected))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		emit_signal("selected", var_name)

func _make_stylebox(color: Color, is_selected: bool) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = color
	box.border_width_left = 2
	box.border_width_top = 2
	box.border_width_right = 2
	box.border_width_bottom = 2
	box.border_color = Color(0.38, 0.78, 0.38, 0.9) if is_selected else Color(0.20, 0.45, 0.20, 0.40)
	box.corner_radius_top_left = 4
	box.corner_radius_top_right = 4
	box.corner_radius_bottom_left = 4
	box.corner_radius_bottom_right = 4
	box.content_margin_left = 8
	box.content_margin_top = 5
	box.content_margin_right = 8
	box.content_margin_bottom = 5
	return box
