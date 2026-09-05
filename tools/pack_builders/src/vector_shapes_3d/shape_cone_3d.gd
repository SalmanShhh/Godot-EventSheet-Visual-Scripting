# Pack source - vector_shapes, the Cone wrapper: the engine's own cylinder mesh with its top pinched
# to a point, with the family's colour, blend and depth fields on it - the spotlight volume, the
# arrow head, the vision cone you can walk around.
extends "res://tools/pack_builders/src/vector_shapes_3d/vector_shape_3d.gd"

#region cone_3d_geometry
# @inspector_preview
# @inspector_handle radius length
@export_group("Cone")
## How wide the cone is at its base, in the node's own units.
## @ace_hidden
@export var radius: float = 0.5:
	set(value):
		radius = value
		shape_changed()
## How tall the cone is. It stands on the node's origin and points up the node's own Y.
@export var height: float = 1.0:
	set(value):
		height = value
		shape_changed()
## Closes the wide end. An open cone is a funnel you can see up, which is what a spotlight volume
## wants; a closed one is a solid.
@export var capped: bool = true:
	set(value):
		capped = value
		shape_changed()
#endregion

#region cone_3d_runtime
## @ace_hidden
func shape_is_solid() -> bool:
	return true

## @ace_hidden
func shape_volume_mesh(detail: int) -> Mesh:
	var horn: CylinderMesh = CylinderMesh.new()
	horn.top_radius = 0.0
	horn.bottom_radius = radius
	horn.height = maxf(height, 0.001)
	horn.radial_segments = detail
	horn.rings = 1
	horn.cap_bottom = capped
	horn.cap_top = false
	return horn

## @ace_hidden
func shape_plane_bounds() -> Rect2:
	return Rect2(Vector2(-radius, -height * 0.5), Vector2(radius * 2.0, height))
#endregion
