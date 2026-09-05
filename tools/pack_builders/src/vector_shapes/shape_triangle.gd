# Pack source - vector_shapes, the Triangle node's own half: three corners, the first of them the
# node's own origin, so moving the node moves the triangle by a corner you can see.
extends "res://tools/pack_builders/src/vector_shapes/vector_shape_2d.gd"

#region triangle_geometry
# @inspector_preview
# @inspector_handle corner_b point
# @inspector_handle corner_c point
@export_group("Triangle")
## The second corner, in the node's own coordinates. The first is the origin.
@export var corner_b: Vector2 = Vector2(72.0, 0.0):
	set(value):
		corner_b = value
		shape_changed()
## The third corner, in the node's own coordinates.
@export var corner_c: Vector2 = Vector2(36.0, -64.0):
	set(value):
		corner_c = value
		shape_changed()
#endregion

#region triangle_colour_mode
@export_group("Colour")
## One colour, a blend across it, out from the middle, or a colour per corner.
@export_enum("single", "two", "radial", "gradient", "per corner") var colour_mode: String = "single":
	set(value):
		colour_mode = value
		notify_property_list_changed()
		shape_changed()
#endregion

#region triangle_runtime
## @ace_hidden
func shape_kind_id() -> int:
	return 5

## @ace_hidden
func shape_points() -> PackedVector2Array:
	return PackedVector2Array([Vector2.ZERO, corner_b, corner_c])

## @ace_hidden
func shape_is_closed() -> bool:
	return true

## @ace_hidden
func shape_bounds() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2.ZERO).expand(corner_b).expand(corner_c)
#endregion
