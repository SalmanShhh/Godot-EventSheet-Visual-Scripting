@tool
extends EventSheetInspectorLook

## Progress bar
## A filled bar between a min and a max. Without this plugin it is a plain number.

## The kinds of property this look can be put on.
@export var works_on: String = "int,float"
## The value at the empty end of the bar.
@warning_ignore("shadowed_global_identifier")
@export var min: float = 0
## The value at the full end of the bar.
@warning_ignore("shadowed_global_identifier")
@export var max: float = 100

var _bar: Control


func _look_built() -> void:
	_bar = EventSheetAttributeDrawers.widgets().DrawerProgressBar.new(min, max)
	_bar.connect("value_changed", _on_bar_changed)
	add_child(_bar)
	add_focusable(_bar)


func _value_shown(value: Variant) -> void:
	_bar.call("set_value", float(value))


func _on_bar_changed(value: float) -> void:
	set_field_value(int(round(value)) if field_type() == TYPE_INT else value)
