@tool
extends EventSheetInspectorLook

## Direction dial
## The vector as an arrow on a dial. Without this plugin it is X and Y fields.

## The kinds of property this look can be put on.
@export var works_on: String = "Vector2"
## How far the arrow can reach: the length at the rim of the dial.
@warning_ignore("shadowed_global_identifier")
@export var max: float = 100

## The sentence the preview card says under a variable that wears this look.
const PREVIEW_SENTENCE := "Shown as a direction dial."

var _dial: Control


func _look_built() -> void:
	_dial = EventSheetAttributeDrawers.widgets().DrawerVectorDial.new(max)
	_dial.connect("value_changed", _on_dial_changed)
	add_child(_dial)
	set_bottom_editor(_dial)


func _value_shown(value: Variant) -> void:
	_dial.call("set_value", value)


func _on_dial_changed(value: Vector2) -> void:
	set_field_value(value)
