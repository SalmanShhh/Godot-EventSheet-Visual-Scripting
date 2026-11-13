@tool
extends EventSheetInspectorLook

## Number with its unit
## A number with a unit dropdown beside it - switching the unit changes the reading, never the stored value.

## The kinds of property this look can be put on.
@export var works_on: String = "float"
## Units
## px|world|screen, store=world
@export var units: String = ""

## The sentence the preview card says under a variable that wears this look.
const PREVIEW_SENTENCE := "Shown with a unit dropdown."

var _field: Control


## No unit at all leaves the plain number field, as without this plugin.
func _can_draw() -> bool:
	return not _spec_units().is_empty()


func _look_built() -> void:
	# The stored number never moves: the dropdown converts the VIEW, and the marker says which unit
	# the file (and therefore the running game) is written in.
	_field = EventSheetAttributeDrawers.widgets().DrawerUnitField.new(_spec_units(), str(EventSheetAttributeDrawers.parse_unit_spec(units).get("store", "")))
	_field.connect("value_changed", _on_field_changed)
	add_child(_field)
	add_focusable(_field)


func _value_shown(value: Variant) -> void:
	_field.call("set_value", float(value))


func _on_field_changed(value: float) -> void:
	set_field_value(value)


func _spec_units() -> PackedStringArray:
	return EventSheetAttributeDrawers.parse_unit_spec(units).get("units", PackedStringArray())
