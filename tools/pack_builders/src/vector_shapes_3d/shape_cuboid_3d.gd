# Pack source - vector_shapes, the Cuboid wrapper: the engine's own box mesh with the family's
# colour, blend and depth fields on it - the block-out volume, the crate, the trigger you want to see.
extends "res://tools/pack_builders/src/vector_shapes_3d/vector_shape_3d.gd"

#region cuboid_3d_geometry
# @inspector_preview
@export_group("Cuboid")
## How big the box is, in the node's own units. It is centred on the node's origin.
@export var size: Vector3 = Vector3.ONE:
	set(value):
		size = value
		shape_changed()
#endregion

#region cuboid_3d_runtime
## @ace_hidden
func shape_is_solid() -> bool:
	return true

## @ace_hidden
func shape_volume_mesh(_detail: int) -> Mesh:
	var block: BoxMesh = BoxMesh.new()
	block.size = size
	return block

## @ace_hidden
func shape_plane_bounds() -> Rect2:
	return Rect2(Vector2(-size.x, -size.y) * 0.5, Vector2(size.x, size.y))
#endregion
