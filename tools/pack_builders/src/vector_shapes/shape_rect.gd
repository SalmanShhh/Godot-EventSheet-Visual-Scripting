# Pack source - vector_shapes, the Rect node's own half: a size, and four corner radii that are
# usually one number - which is what the corners drawer is for.
extends "res://tools/pack_builders/src/vector_shapes/vector_shape_2d.gd"

#region rect_geometry
# @inspector_preview
@export_group("Rect")
## How big the rectangle is. It is centred on the node's origin, so rotating the node turns it about
## its middle.
@export var size: Vector2 = Vector2(128.0, 72.0):
	set(value):
		size = value
		shape_changed()
## How round the four corners are, clockwise from the top-left. One box while they agree, four when
## they should not.
## @ace_hidden
@export_custom(PROPERTY_HINT_NONE, "eventsheet:corners") var corner_radius: Vector4 = Vector4.ZERO:
	set(value):
		corner_radius = value
		shape_changed()
#endregion

#region rect_colour_mode
@export_group("Colour")
## One colour, a blend across it, out from the middle, or a colour per corner.
@export_enum("single", "two", "radial", "gradient", "per corner") var colour_mode: String = "single":
	set(value):
		colour_mode = value
		notify_property_list_changed()
		shape_changed()
#endregion

#region rect_runtime
## @ace_hidden
func shape_kind_id() -> int:
	return 2

## @ace_hidden
func shape_points() -> PackedVector2Array:
	var half: Vector2 = size * 0.5
	return PackedVector2Array([
		Vector2(-half.x, -half.y),
		Vector2(half.x, -half.y),
		Vector2(half.x, half.y),
		Vector2(-half.x, half.y)
	])

## @ace_hidden
func shape_is_closed() -> bool:
	return true

## @ace_hidden
func shape_bounds() -> Rect2:
	return Rect2(-size * 0.5, size)
#endregion
