# Pack source - vector_shapes, the Regular Polygon 3D node's own half: a number of sides and a
# radius, which is a triangle, a hexagon and a near-circle from one field - the hex tile marker, the
# summoning ring, the landing pad.
extends "res://tools/pack_builders/src/vector_shapes_3d/vector_shape_3d.gd"

#region regular_polygon_3d_geometry
# @inspector_preview
# @inspector_handle radius length
@export_group("Regular Polygon")
## How many sides it has. Three is a triangle, six a hexagon; high numbers are a circle drawn the
## expensive way, and a Disc 3D is the cheap one.
## @ace_hidden
@export_range(3, 32, 1) var sides: int = 6:
	set(value):
		sides = value
		shape_changed()
## How far each corner sits from the node's origin.
## @ace_hidden
@export var radius: float = 0.5:
	set(value):
		radius = value
		shape_changed()
## Turns the whole shape. The dropdown at the field's edge reads the number in degrees, turns or
## radians; the number stored is always degrees.
@export_custom(PROPERTY_HINT_NONE, "eventsheet:unit:kinds=deg|turn|rad,store=deg") var angle: float = 90.0:
	set(value):
		angle = value
		shape_changed()
#endregion

#region regular_polygon_3d_colour_mode
@export_group("Colour")
## One colour, a blend across it, out from the middle, round it, or a whole ramp.
@export_enum("single", "two", "radial", "angular", "gradient") var colour_mode: String = "single":
	set(value):
		colour_mode = value
		notify_property_list_changed()
		shape_changed()
#endregion

#region regular_polygon_3d_runtime
## @ace_hidden
func shape_kind_id() -> int:
	return 6

## @ace_hidden
func shape_points_3d() -> PackedVector3Array:
	var outline: PackedVector3Array = PackedVector3Array()
	var count: int = clampi(sides, 3, SHAPE_WORDS.MAX_POINTS)
	for step: int in count:
		var turn: float = deg_to_rad(angle) + TAU * float(step) / float(count)
		outline.append(Vector3(cos(turn) * radius, sin(turn) * radius, 0.0))
	return outline

## @ace_hidden
func shape_is_closed() -> bool:
	return true

## @ace_hidden
func shape_plane_bounds() -> Rect2:
	return Rect2(Vector2(-radius, -radius), Vector2(radius, radius) * 2.0)
#endregion
