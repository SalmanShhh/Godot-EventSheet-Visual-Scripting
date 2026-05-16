# EventForge — Group row UI
# Renders an EventGroup block header in the event sheet canvas.
#
# Architecture direction (planned):
# - Groups act as containers for local variables and nested event rows.
# - Local variables declared inside a group are scoped to that group's subtree.
# - Local variable compiler scoping is deferred; see docs/EDITOR-UI-SPEC.md.
# - Nested event rows inside a group render indented below the group header.
@tool
extends PanelContainer
class_name GroupRowUI

signal selected(group: EventGroup)

var group: EventGroup = null

var _title_label: Label

## Binds an EventGroup resource and refreshes the header label.
func setup(g: EventGroup) -> void:
	group = g

	if _title_label == null:
		_title_label = Label.new()
		_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		add_child(_title_label)

	var display_name: String = group.name
	if display_name.is_empty():
		display_name = group.group_name
	if display_name.is_empty():
		display_name = "Group"
	_title_label.text = "Group: %s" % display_name
	set_selected(false)

## Updates the selection highlight.
func set_selected(is_selected: bool) -> void:
	var bg: Color = Color(0.28, 0.16, 0.46, 0.55) if is_selected else Color(0.16, 0.10, 0.28, 0.28)
	add_theme_stylebox_override("panel", _make_stylebox(bg, is_selected))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and group != null:
		emit_signal("selected", group)

func _make_stylebox(color: Color, is_selected: bool) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = color
	box.border_width_left = 3
	box.border_width_top = 2
	box.border_width_right = 2
	box.border_width_bottom = 2
	box.border_color = Color(0.70, 0.38, 0.96, 0.9) if is_selected else Color(0.42, 0.20, 0.65, 0.50)
	box.corner_radius_top_left = 4
	box.corner_radius_top_right = 4
	box.corner_radius_bottom_left = 4
	box.corner_radius_bottom_right = 4
	box.content_margin_left = 8
	box.content_margin_top = 5
	box.content_margin_right = 8
	box.content_margin_bottom = 5
	return box
