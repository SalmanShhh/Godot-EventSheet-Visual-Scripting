@tool
extends EventSheetInspectorLook

## Swatch row
## A row of colour swatches to pick from. Without this plugin it is a plain colour.

## The kinds of property this look can be put on.
@export var works_on: String = "Color"

## The sentence the preview card says under a variable that wears this look.
const PREVIEW_SENTENCE := "Shown as color swatches."

var _row: Control


func _look_built() -> void:
	_row = EventSheetAttributeDrawers.widgets().DrawerSwatchRow.new()
	_row.connect("value_changed", _on_row_changed)
	add_child(_row)


func _value_shown(value: Variant) -> void:
	_row.call("set_value", value)


func _on_row_changed(color: Color) -> void:
	set_field_value(color)
