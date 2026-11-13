@tool
extends EventSheetInspectorLook

## Four corners
## Four numbers, one per corner, with a button that keeps them the same.

## The kinds of property this look can be put on.
@export var works_on: String = "Vector4"

## The sentence the preview card says under a variable that wears this look.
const PREVIEW_SENTENCE := "Shown as four corners."

var _corners: Control


func _look_built() -> void:
	_corners = EventSheetAttributeDrawers.widgets().DrawerCorners.new()
	_corners.connect("value_changed", _on_corners_changed)
	add_child(_corners)
	draw_background = false


func _value_shown(value: Variant) -> void:
	_corners.call("set_value", value if value is Vector4 else Vector4.ZERO)


func _on_corners_changed(value: Vector4) -> void:
	set_field_value(value)
