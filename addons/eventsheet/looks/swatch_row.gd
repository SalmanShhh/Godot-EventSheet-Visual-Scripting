@tool
extends EventSheetInspectorLook

## Swatch row
## A row of colour swatches to pick from. Without this plugin it is a plain colour.

## The kinds of property this look can be put on.
@export var works_on: String = "Color"

var _row: Control


func _look_built() -> void:
	_row = EventSheetAttributeDrawers.widgets().DrawerSwatchRow.new()
	_row.connect("value_changed", _on_row_changed)
	add_child(_row)
	set_bottom_editor(_row)


func _value_shown(value: Variant) -> void:
	_row.call("set_value", value)


func _on_row_changed(color: Color) -> void:
	set_field_value(color)
