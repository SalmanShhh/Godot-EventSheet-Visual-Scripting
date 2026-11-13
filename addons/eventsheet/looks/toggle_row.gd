@tool
extends EventSheetInspectorLook

## Toggle buttons
## A row of buttons, one per choice. Without this plugin it is a plain text box.

## The kinds of property this look can be put on.
@export var works_on: String = "String"
## Choices
## easy, normal, hard
@export var choices: String = ""

## An int a script already marked keeps its place in the row, so it is drawn, but only text is offered in the window.
const ALSO_DRAWS_ON := "int"

## The sentence the preview card says under a variable that wears this look.
const PREVIEW_SENTENCE := "Shown as toggle buttons."

var _row: Control
var _options: PackedStringArray = PackedStringArray()


## The marker's own grammar (a list, then the optional tails `segmented` and `icons=<source>`) is read by
## the attribute drawers from the arguments exactly as they were written. No choices leaves the plain field.
func _can_draw() -> bool:
	return not EventSheetAttributeDrawers.parse_toggle_spec(marker_args).get("options", PackedStringArray()).is_empty()


func _look_built() -> void:
	var spec: Dictionary = EventSheetAttributeDrawers.parse_toggle_spec(marker_args)
	_options = spec.get("options", PackedStringArray())
	_row = EventSheetAttributeDrawers.widgets().DrawerToggleRow.new(_options, str(spec.get("icons", "")), bool(spec.get("segmented", false)))
	_row.connect("value_changed", _on_row_changed)
	add_child(_row)
	set_bottom_editor(_row)


func _value_shown(value: Variant) -> void:
	if field_type() != TYPE_INT:
		_row.call("set_value", str(value))
		return
	var index: int = int(value)
	_row.call("set_value", _options[index] if index >= 0 and index < _options.size() else "")


func _on_row_changed(value: String) -> void:
	if field_type() != TYPE_INT:
		set_field_value(value)
		return
	var index: int = Array(_options).find(value)
	if index >= 0:
		set_field_value(index)
