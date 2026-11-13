@tool
extends EventSheetInspectorLook

## Swatch row
## A row of colour swatches to pick from. Without this plugin it is a plain colour.

## The kinds of property this look can be put on.
@export var works_on: String = "Color"

## The sentence the preview card says under a variable that wears this look.
const PREVIEW_SENTENCE := "Shown as color swatches."

var _row: Control
## The full-width line under the label, used when the swatches do not fit beside it.
var _under: MarginContainer
var _beside: bool = true


func _look_built() -> void:
	_row = EventSheetAttributeDrawers.widgets().DrawerSwatchRow.new()
	_row.connect("value_changed", _on_row_changed)
	_under = MarginContainer.new()
	_under.visible = false
	add_child(_under)
	set_bottom_editor(_under)
	add_child(_row)
	draw_background = false
	draw.connect(_place_row, CONNECT_DEFERRED)


## The swatches sit beside the label while they fit in the value column, and on their own line under
## it at the full width when they do not.
func _place_row() -> void:
	var fits: bool = _row.call("width_for_one_line") <= size.x * (1.0 - get_name_split_ratio())
	if fits == _beside:
		return
	_beside = fits
	_row.get_parent().remove_child(_row)
	if fits:
		add_child(_row)
	else:
		_under.add_child(_row)
	_under.visible = not fits


func _value_shown(value: Variant) -> void:
	_row.call("set_value", value)


func _on_row_changed(color: Color) -> void:
	set_field_value(color)
