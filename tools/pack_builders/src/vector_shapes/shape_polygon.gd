# Pack source - vector_shapes, the Polygon node's own half: a list of points, dragged in the
# viewport rather than typed.
extends "res://tools/pack_builders/src/vector_shapes/vector_shape_2d.gd"

#region polygon_geometry
# @inspector_preview
# @inspector_handle points points
@export_group("Polygon")
## The corners, in the node's own coordinates. Each one is a handle in the 2D viewport while the
## node is selected. Past thirty-two points this is Godot's own Polygon2D's job, and the extra
## points are left undrawn rather than silently thinned.
## @ace_hidden
@export var points: PackedVector2Array = PackedVector2Array([
	Vector2(-48.0, 40.0), Vector2(0.0, -48.0), Vector2(48.0, 40.0), Vector2(0.0, 16.0)
]):
	set(value):
		points = value
		shape_changed()
#endregion

#region polygon_colour_mode
@export_group("Colour")
## One colour, a blend across it, out from the middle, or a whole ramp.
@export_enum("single", "two", "radial", "gradient") var colour_mode: String = "single":
	set(value):
		colour_mode = value
		notify_property_list_changed()
		shape_changed()
#endregion

#region polygon_runtime
## @ace_hidden
func shape_kind_id() -> int:
	return 3

## @ace_hidden
func shape_points() -> PackedVector2Array:
	return points

## @ace_hidden
func shape_is_closed() -> bool:
	return true

## @ace_hidden
func shape_bounds() -> Rect2:
	if points.is_empty():
		return Rect2()
	var box: Rect2 = Rect2(points[0], Vector2.ZERO)
	for point: Vector2 in points:
		box = box.expand(point)
	return box
#endregion
