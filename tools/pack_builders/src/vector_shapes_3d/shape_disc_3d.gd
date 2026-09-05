# Pack source - vector_shapes, the Disc 3D node's own half. Two radii and two angles are four shapes:
# a disc, a ring, a pie and an arc - the range ring on the ground, the scanning cone, the cooldown
# wheel over a unit's head.
extends "res://tools/pack_builders/src/vector_shapes_3d/vector_shape_3d.gd"

#region disc_3d_geometry
# @inspector_preview
# @inspector_handle radius length
@export_group("Disc")
## How far the disc reaches from the node's origin, in the node's own units.
## @ace_hidden
@export var radius: float = 0.5:
	set(value):
		radius = value
		shape_changed()
## Above zero turns the disc into a RING: the hole in the middle, in the same units as the radius.
@export var inner_radius: float = 0.0:
	set(value):
		inner_radius = value
		shape_changed()
## Where the sweep starts. The dropdown at the field's edge reads the number in degrees, turns or
## radians; the number stored is always degrees, so nothing moves when you flip it.
## @ace_hidden
@export_custom(PROPERTY_HINT_NONE, "eventsheet:unit:kinds=deg|turn|rad,store=deg") var start_angle: float = 0.0:
	set(value):
		start_angle = value
		shape_changed()
## Where the sweep ends. A full turn past the start is a whole disc; anything less is the pie or the
## arc a cooldown or a scanning cone is drawn as.
## @ace_hidden
@export_custom(PROPERTY_HINT_NONE, "eventsheet:unit:kinds=deg|turn|rad,store=deg") var end_angle: float = 360.0:
	set(value):
		end_angle = value
		shape_changed()
#endregion

#region disc_3d_colour_mode
@export_group("Colour")
## One colour, out from the middle (radial), round the sweep (angular), inner to outer (two), or a
## whole ramp.
@export_enum("single", "two", "radial", "angular", "gradient") var colour_mode: String = "single":
	set(value):
		colour_mode = value
		notify_property_list_changed()
		shape_changed()
#endregion

#region disc_3d_runtime
## How many points the outline is sampled at when a row asks for its length, its area or whether a
## click landed on it. The drawing itself is exact - it is a distance field, not these points.
const OUTLINE_SAMPLES: int = 24

## @ace_hidden
func shape_kind_id() -> int:
	return 1

## @ace_hidden
func shape_points_3d() -> PackedVector3Array:
	var sweep: float = deg_to_rad(clampf(end_angle - start_angle, 0.0, 360.0))
	var outline: PackedVector3Array = PackedVector3Array()
	if sweep < TAU - 0.001 and inner_radius <= 0.0:
		outline.append(Vector3.ZERO)
	for step: int in OUTLINE_SAMPLES:
		var angle: float = deg_to_rad(start_angle) + sweep * float(step) / float(OUTLINE_SAMPLES - 1)
		outline.append(Vector3(cos(angle) * radius, sin(angle) * radius, 0.0))
	return outline

## @ace_hidden
func shape_is_closed() -> bool:
	return end_angle - start_angle >= 359.9 or _flag("fill")

## @ace_hidden
func shape_plane_bounds() -> Rect2:
	var reach: float = maxf(radius, inner_radius)
	return Rect2(Vector2(-reach, -reach), Vector2(reach, reach) * 2.0)

## The volumetric disc is one of the engine's own primitives rather than a tube: a ring is a torus
## and a solid disc is a very flat cylinder, both of which the engine already builds well.
## @ace_hidden
func shape_volume_mesh(detail: int) -> Mesh:
	if inner_radius > 0.0:
		var ring: TorusMesh = TorusMesh.new()
		ring.inner_radius = minf(inner_radius, radius)
		ring.outer_radius = maxf(radius, inner_radius + 0.001)
		ring.rings = detail
		ring.ring_segments = maxi(detail / 2, 3)
		return ring
	var plate: CylinderMesh = CylinderMesh.new()
	plate.top_radius = radius
	plate.bottom_radius = radius
	plate.height = maxf(_number("thickness", 0.05), 0.001)
	plate.radial_segments = detail
	plate.rings = 1
	return plate
#endregion
