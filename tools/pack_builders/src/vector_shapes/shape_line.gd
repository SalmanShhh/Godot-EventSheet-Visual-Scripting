# Pack source - vector_shapes, the Line node's own half: where it goes, and what its outline is.
extends "res://tools/pack_builders/src/vector_shapes/vector_shape_2d.gd"

#region line_geometry
# @inspector_preview
# @inspector_handle end_point point
@export_group("Line")
## Where the line ends, in the node's own coordinates. It starts at the node's origin, so moving the
## node moves the start and dragging the handle moves the end.
@export var end_point: Vector2 = Vector2(96.0, 0.0):
	set(value):
		end_point = value
		shape_changed()
#endregion

#region line_colour_mode
@export_group("Colour")
## One colour, two (start to end), or a whole ramp along the line.
@export_enum("single", "two", "gradient") var colour_mode: String = "single":
	set(value):
		colour_mode = value
		notify_property_list_changed()
		shape_changed()
#endregion

#region line_runtime
## @ace_hidden
func shape_kind_id() -> int:
	return 0

## @ace_hidden
func shape_points() -> PackedVector2Array:
	return PackedVector2Array([Vector2.ZERO, end_point])

## @ace_hidden
func shape_is_closed() -> bool:
	return false

## @ace_hidden
func shape_bounds() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2.ZERO).expand(end_point)
#endregion
