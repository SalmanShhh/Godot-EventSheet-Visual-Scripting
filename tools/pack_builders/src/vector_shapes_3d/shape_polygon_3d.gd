# Pack source - vector_shapes, the Polygon 3D node's own half: a list of points, dragged in the 3D
# viewport rather than typed.
extends "res://tools/pack_builders/src/vector_shapes_3d/vector_shape_3d.gd"

#region polygon_3d_geometry
# @inspector_preview
# @inspector_handle points points
@export_group("Polygon")
## The corners, in the node's own coordinates. Each one is a handle in the 3D viewport while the
## node is selected, dragged on the plane facing the camera. Past thirty-two points this is Godot's
## own mesh tools' job, and the extra points are left undrawn rather than silently thinned.
## @ace_hidden
@export var points: PackedVector3Array = PackedVector3Array([
	Vector3(-0.5, -0.4, 0.0), Vector3(0.0, 0.5, 0.0), Vector3(0.5, -0.4, 0.0), Vector3(0.0, -0.15, 0.0)
]):
	set(value):
		points = value
		shape_changed()
#endregion

#region polygon_3d_colour_mode
@export_group("Colour")
## One colour, a blend across it, out from the middle, or a whole ramp.
@export_enum("single", "two", "radial", "gradient") var colour_mode: String = "single":
	set(value):
		colour_mode = value
		notify_property_list_changed()
		shape_changed()
#endregion

#region polygon_3d_runtime
## @ace_hidden
func shape_kind_id() -> int:
	return 3

## @ace_hidden
func shape_points_3d() -> PackedVector3Array:
	return points

## @ace_hidden
func shape_is_closed() -> bool:
	return true

## @ace_hidden
func shape_plane_bounds() -> Rect2:
	if points.is_empty():
		return Rect2()
	var box: Rect2 = Rect2(Vector2(points[0].x, points[0].y), Vector2.ZERO)
	for point: Vector3 in points:
		box = box.expand(Vector2(point.x, point.y))
	return box
#endregion
