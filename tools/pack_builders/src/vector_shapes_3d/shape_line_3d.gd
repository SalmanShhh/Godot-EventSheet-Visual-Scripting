# Pack source - vector_shapes, the Line 3D node's own half: two points in space and a strip between
# them. Unlike every other shape here it has no plane of its own - a rope between a hand and a
# grapple point runs wherever the two ends are - so it is built as a RIBBON: four vertices widened
# across the direction it is read from, the node's own +Z when it is flat and the camera when it is
# a billboard.
extends "res://tools/pack_builders/src/vector_shapes_3d/vector_shape_3d.gd"

#region line_3d_geometry
# @inspector_preview
# @inspector_handle start_point point
# @inspector_handle end_point point
@export_group("Line")
## Where the line starts, in the node's own coordinates. Both ends are handles in the 3D viewport
## while the node is selected.
@export var start_point: Vector3 = Vector3.ZERO:
	set(value):
		start_point = value
		shape_changed()
## Where the line ends.
@export var end_point: Vector3 = Vector3(1.0, 0.0, 0.0):
	set(value):
		end_point = value
		shape_changed()
#endregion

#region line_3d_colour_mode
@export_group("Colour")
## One colour, two (start to end), or a whole ramp along the line.
@export_enum("single", "two", "gradient") var colour_mode: String = "single":
	set(value):
		colour_mode = value
		notify_property_list_changed()
		shape_changed()
#endregion

#region line_3d_runtime
## @ace_hidden
func shape_kind_id() -> int:
	return 0

## @ace_hidden
func shape_points_3d() -> PackedVector3Array:
	return PackedVector3Array([start_point, end_point])

## @ace_hidden
func shape_is_closed() -> bool:
	return false

## @ace_hidden
func shape_is_ribbon() -> bool:
	return true

## @ace_hidden
func shape_plane_bounds() -> Rect2:
	return Rect2(Vector2(start_point.x, start_point.y), Vector2.ZERO).expand(Vector2(end_point.x, end_point.y))
#endregion
