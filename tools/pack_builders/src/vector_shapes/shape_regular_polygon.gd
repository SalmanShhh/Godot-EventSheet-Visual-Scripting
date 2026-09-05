# Pack source - vector_shapes, the Regular Polygon node's own half: a number of sides and a radius,
# which is a triangle, a hexagon and a near-circle from one field.
extends "res://tools/pack_builders/src/vector_shapes/vector_shape_2d.gd"

#region regular_polygon_geometry
# @inspector_preview
# @inspector_handle radius length
@export_group("Regular Polygon")
## How many sides it has. Three is a triangle, six a hexagon; high numbers are a circle drawn the
## expensive way, and a Disc is the cheap one.
## @ace_hidden
@export_range(3, 32, 1) var sides: int = 6:
	set(value):
		sides = value
		shape_changed()
## How far each corner sits from the node's origin.
## @ace_hidden
@export var radius: float = 48.0:
	set(value):
		radius = value
		shape_changed()
## Turns the whole shape, in degrees - the difference between a hexagon standing on a point and one
## standing on a side.
@export_range(-360.0, 360.0, 0.1) var angle: float = -90.0:
	set(value):
		angle = value
		shape_changed()
#endregion

#region regular_polygon_colour_mode
@export_group("Colour")
## One colour, a blend across it, out from the middle, round it, or a whole ramp.
@export_enum("single", "two", "radial", "angular", "gradient") var colour_mode: String = "single":
	set(value):
		colour_mode = value
		notify_property_list_changed()
		shape_changed()
#endregion

#region regular_polygon_runtime
## @ace_hidden
func shape_kind_id() -> int:
	return 6

## @ace_hidden
func shape_points() -> PackedVector2Array:
	var outline: PackedVector2Array = PackedVector2Array()
	var count: int = clampi(sides, 3, MAX_POINTS)
	for step: int in count:
		outline.append(Vector2.from_angle(deg_to_rad(angle) + TAU * float(step) / float(count)) * radius)
	return outline

## @ace_hidden
func shape_is_closed() -> bool:
	return true

## @ace_hidden
func shape_bounds() -> Rect2:
	return Rect2(Vector2(-radius, -radius), Vector2(radius, radius) * 2.0)
#endregion
