@tool
extends EventSheetInspectorLook

## Min-max range
## Two handles on one slider: x is the low end, y the high end.

## The kinds of property this look can be put on.
@export var works_on: String = "Vector2"
## The value at the left end of the slider.
@warning_ignore("shadowed_global_identifier")
@export var min: float = 0
## The value at the right end of the slider.
@warning_ignore("shadowed_global_identifier")
@export var max: float = 100

var _slider: Control


func _look_built() -> void:
	_slider = EventSheetAttributeDrawers.widgets().DrawerMinMaxSlider.new(min, max)
	_slider.connect("value_changed", _on_slider_changed)
	add_child(_slider)
	add_focusable(_slider)


func _value_shown(value: Variant) -> void:
	_slider.call("set_value", value)


func _on_slider_changed(value: Vector2) -> void:
	set_field_value(value)
