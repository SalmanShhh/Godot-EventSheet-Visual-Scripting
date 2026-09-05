# Pack source - vector_shapes, the Torus wrapper: the engine's own torus mesh with the family's
# colour, blend and depth fields on it - the portal ring, the halo, the hoop a racer flies through.
extends "res://tools/pack_builders/src/vector_shapes_3d/vector_shape_3d.gd"

#region torus_3d_geometry
# @inspector_preview
# @inspector_handle radius length
@export_group("Torus")
## How far the outside of the ring reaches from the node's origin, in the node's own units.
## @ace_hidden
@export var radius: float = 0.5:
	set(value):
		radius = value
		shape_changed()
## How far the hole in the middle reaches. The difference between the two is how thick the ring is.
@export var inner_radius: float = 0.35:
	set(value):
		inner_radius = value
		shape_changed()
#endregion

#region torus_3d_runtime
## @ace_hidden
func shape_is_solid() -> bool:
	return true

## @ace_hidden
func shape_volume_mesh(detail: int) -> Mesh:
	var hoop: TorusMesh = TorusMesh.new()
	hoop.inner_radius = minf(inner_radius, radius)
	hoop.outer_radius = maxf(radius, inner_radius + 0.001)
	hoop.rings = detail
	hoop.ring_segments = maxi(detail / 2, 3)
	return hoop

## @ace_hidden
func shape_plane_bounds() -> Rect2:
	return Rect2(Vector2(-radius, -radius), Vector2(radius, radius) * 2.0)
#endregion
