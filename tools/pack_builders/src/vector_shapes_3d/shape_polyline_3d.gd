# Pack source - vector_shapes, the Polyline 3D node's own half: the same list of points as a polygon,
# drawn as a path rather than as an area - the patrol route, the pipe run, the cable.
extends "res://tools/pack_builders/src/vector_shapes_3d/vector_shape_3d.gd"

#region polyline_3d_geometry
# @inspector_preview
# @inspector_handle points points
@export_group("Polyline")
## The points the path runs through, in the node's own coordinates. Each one is a handle in the 3D
## viewport while the node is selected.
## @ace_hidden
@export var points: PackedVector3Array = PackedVector3Array([
	Vector3(-0.7, 0.25, 0.0), Vector3(-0.2, -0.35, 0.0), Vector3(0.35, 0.2, 0.0), Vector3(0.8, -0.25, 0.0)
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

#region polyline_3d_colour_mode
@export_group("Colour")
## One colour, two (start to end), or a whole ramp along the path.
@export_enum("single", "two", "gradient") var colour_mode: String = "single":
	set(value):
		colour_mode = value
		notify_property_list_changed()
		shape_changed()
#endregion

#region polyline_3d_runtime
## @ace_hidden
func shape_kind_id() -> int:
	return 4

## @ace_hidden
func shape_points_3d() -> PackedVector3Array:
	return points

## @ace_hidden
func shape_is_closed() -> bool:
	return closed

## @ace_hidden
func shape_plane_bounds() -> Rect2:
	if points.is_empty():
		return Rect2()
	var box: Rect2 = Rect2(Vector2(points[0].x, points[0].y), Vector2.ZERO)
	for point: Vector3 in points:
		box = box.expand(Vector2(point.x, point.y))
	return box
#endregion
