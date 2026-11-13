@tool
extends EventSheetInspectorLook

## Direction dial
## Drag a handle round a circle to aim.

## The kinds of property this look can be put on.
@export var works_on: String = "Vector2"
## Reach
## How far the arrow can reach: the length at the rim of the dial.
@warning_ignore("shadowed_global_identifier")
@export var max: float = 100

## The sentence the preview card says under a variable that wears this look.
const PREVIEW_SENTENCE := "Shown as a direction dial."

var _dial: Control
var _x_field: Range
var _y_field: Range


func _look_built() -> void:
	var fields: HFlowContainer = HFlowContainer.new()
	fields.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_x_field = EventSheetLookStyle.number_field("x", EventSheetLookStyle.axis_color(0))
	_y_field = EventSheetLookStyle.number_field("y", EventSheetLookStyle.axis_color(1))
	for field: Range in [_x_field, _y_field]:
		EventSheetLookStyle.open_number_field(field)
		field.value_changed.connect(_on_field_changed)
		fields.add_child(field)
	add_focusable(_x_field)
	add_focusable(_y_field)
	_dial = EventSheetAttributeDrawers.widgets().DrawerVectorDial.new(max)
	_dial.connect("value_changed", _on_dial_changed)
	add_under_field(fields, _dial)


func _value_shown(value: Variant) -> void:
	var vector: Vector2 = value as Vector2
	_dial.call("set_value", vector)
	_x_field.set_value_no_signal(vector.x)
	_y_field.set_value_no_signal(vector.y)
	EventSheetLookStyle.set_number_field_locked(_x_field, is_field_read_only())
	EventSheetLookStyle.set_number_field_locked(_y_field, is_field_read_only())


func _on_dial_changed(value: Vector2) -> void:
	set_field_value(value)


func _on_field_changed(_value: float) -> void:
	var typed: Vector2 = Vector2(_x_field.value, _y_field.value)
	_dial.call("set_value", typed)
	set_field_value(typed)
