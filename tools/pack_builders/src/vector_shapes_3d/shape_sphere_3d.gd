# Pack source - vector_shapes, the Sphere wrapper: the engine's own sphere mesh with the family's
# colour, blend and depth fields on it. A debug volume, a stylised planet, the ball at the end of a
# pointer - one node with the same Inspector as the shapes beside it, instead of a MeshInstance3D
# plus a mesh resource plus a material somebody has to remember to make unique.
extends "res://tools/pack_builders/src/vector_shapes_3d/vector_shape_3d.gd"

#region sphere_3d_geometry
# @inspector_preview
# @inspector_handle radius length
@export_group("Sphere")
## How far the sphere reaches from the node's origin, in the node's own units.
## @ace_hidden
@export var radius: float = 0.5:
	set(value):
		radius = value
		shape_changed()
#endregion

#region sphere_3d_runtime
## @ace_hidden
func shape_is_solid() -> bool:
	return true

## @ace_hidden
func shape_volume_mesh(detail: int) -> Mesh:
	var ball: SphereMesh = SphereMesh.new()
	ball.radius = radius
	ball.height = radius * 2.0
	ball.radial_segments = detail
	ball.rings = maxi(detail / 2, 2)
	return ball

## @ace_hidden
func shape_plane_bounds() -> Rect2:
	return Rect2(Vector2(-radius, -radius), Vector2(radius, radius) * 2.0)
#endregion
