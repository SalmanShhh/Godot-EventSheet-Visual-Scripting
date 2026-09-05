# Pack source - vector_shapes, the Rect 3D node's own half: a size, and four corner radii that are
# usually one number - which is what the corners drawer is for. The panel over a machine, the
# selection box on the floor, the plate behind a unit's health bar.
extends "res://tools/pack_builders/src/vector_shapes_3d/vector_shape_3d.gd"

#region rect_3d_geometry
# @inspector_preview
@export_group("Rect")
## How big the rectangle is, in the node's own units. It is centred on the node's origin, so
## rotating the node turns it about its middle.
@export var size: Vector2 = Vector2(1.0, 0.6):
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

#region rect_3d_colour_mode
@export_group("Colour")
## One colour, a blend across it, out from the middle, or a colour per corner.
@export_enum("single", "two", "radial", "gradient", "per corner") var colour_mode: String = "single":
	set(value):
		colour_mode = value
		notify_property_list_changed()
		shape_changed()
#endregion

#region rect_3d_runtime
## @ace_hidden
func shape_kind_id() -> int:
	return 2

## @ace_hidden
func shape_points_3d() -> PackedVector3Array:
	var half: Vector2 = size * 0.5
	return PackedVector3Array([
		Vector3(-half.x, -half.y, 0.0),
		Vector3(half.x, -half.y, 0.0),
		Vector3(half.x, half.y, 0.0),
		Vector3(-half.x, half.y, 0.0)
	])

## @ace_hidden
func shape_is_closed() -> bool:
	return true

## @ace_hidden
func shape_plane_bounds() -> Rect2:
	return Rect2(-size * 0.5, size)

## The volumetric rect is a box as deep as the stroke is wide - a slab, which is what a panel or a
## step in the world actually is.
## @ace_hidden
func shape_volume_mesh(_detail: int) -> Mesh:
	var slab: BoxMesh = BoxMesh.new()
	slab.size = Vector3(size.x, size.y, maxf(_number("thickness", 0.05), 0.001))
	return slab
#endregion
