# Pack source - vector_shapes, the Polyline node's own half: the same list of points as a polygon,
# drawn as a path rather than as an area.
extends "res://tools/pack_builders/src/vector_shapes/vector_shape_2d.gd"

#region polyline_geometry
# @inspector_preview
# @inspector_handle points points
@export_group("Polyline")
## The points the line runs through, in the node's own coordinates. Each one is a handle in the 2D
## viewport while the node is selected.
## @ace_hidden
@export var points: PackedVector2Array = PackedVector2Array([
	Vector2(-64.0, 24.0), Vector2(-16.0, -32.0), Vector2(32.0, 16.0), Vector2(72.0, -24.0)
]):
	set(value):
		points = value
		shape_changed()
## Joins the last point back to the first, so the path comes round on itself.
@export var closed: bool = false:
	set(value):
		closed = value
		shape_changed()
#endregion

#region polyline_colour_mode
@export_group("Colour")
## One colour, two (start to end), or a whole ramp along the path.
@export_enum("single", "two", "gradient") var colour_mode: String = "single":
	set(value):
		colour_mode = value
		notify_property_list_changed()
		shape_changed()
#endregion

#region polyline_runtime
## @ace_hidden
func shape_kind_id() -> int:
	return 4

## @ace_hidden
func shape_points() -> PackedVector2Array:
	return points

## @ace_hidden
func shape_is_closed() -> bool:
	return closed

## @ace_hidden
func shape_bounds() -> Rect2:
	if points.is_empty():
		return Rect2()
	var box: Rect2 = Rect2(points[0], Vector2.ZERO)
	for point: Vector2 in points:
		box = box.expand(point)
	return box
#endregion
