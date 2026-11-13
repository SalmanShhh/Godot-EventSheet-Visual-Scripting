@tool
extends EventSheetInspectorLook

## Four corners
## One number for all four corners, with a button that opens a box per corner.

## The kinds of property this look can be put on.
@export var works_on: String = "Vector4"

var _corners: Control


func _look_built() -> void:
	_corners = EventSheetAttributeDrawers.widgets().DrawerCorners.new()
	_corners.connect("value_changed", _on_corners_changed)
	add_child(_corners)
	set_bottom_editor(_corners)


func _value_shown(value: Variant) -> void:
	_corners.call("set_value", value if value is Vector4 else Vector4.ZERO)


func _on_corners_changed(value: Vector4) -> void:
	set_field_value(value)
