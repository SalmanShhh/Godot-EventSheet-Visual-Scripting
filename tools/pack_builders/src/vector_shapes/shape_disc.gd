# Pack source - vector_shapes, the Disc node's own half. Two radii and two angles are four shapes:
# a disc, a ring, a pie and an arc - which is why there is no separate Ring node to keep in step.
extends "res://tools/pack_builders/src/vector_shapes/vector_shape_2d.gd"

#region disc_geometry
# @inspector_preview
# @inspector_handle radius length
# @inspector_handle start_angle angle
@export_group("Disc")
## How far the disc reaches from the node's origin.
## @ace_hidden
@export var radius: float = 48.0:
	set(value):
		radius = value
		shape_changed()
## Above zero turns the disc into a RING: the hole in the middle, in the same units as the radius.
@export var inner_radius: float = 0.0:
	set(value):
		inner_radius = value
		shape_changed()
## Where the sweep starts, in degrees, measured from the right and turning the way the screen does.
## @ace_hidden
@export_range(-360.0, 360.0, 0.1) var start_angle: float = 0.0:
	set(value):
		start_angle = value
		shape_changed()
## Where the sweep ends. A full turn past the start is a whole disc; anything less is a pie or an
## arc, which is what a cooldown or a vision cone is.
## @ace_hidden
@export_range(-360.0, 720.0, 0.1) var end_angle: float = 360.0:
	set(value):
		end_angle = value
		shape_changed()
#endregion

#region disc_colour_mode
@export_group("Colour")
## One colour, out from the middle (radial), round the sweep (angular), inner to outer (two), or a
## whole ramp.
@export_enum("single", "two", "radial", "angular", "gradient") var colour_mode: String = "single":
	set(value):
		colour_mode = value
		notify_property_list_changed()
		shape_changed()
#endregion

#region disc_runtime
## How many points the outline is sampled at when a row asks for its length, its area or whether a
## click landed on it. The drawing itself is exact - it is a distance field, not these points.
const OUTLINE_SAMPLES: int = 24

## @ace_hidden
func shape_kind_id() -> int:
	return 1

## @ace_hidden
func shape_points() -> PackedVector2Array:
	var sweep: float = deg_to_rad(clampf(end_angle - start_angle, 0.0, 360.0))
	var outline: PackedVector2Array = PackedVector2Array()
	if sweep < TAU - 0.001 and inner_radius <= 0.0:
		outline.append(Vector2.ZERO)
	for step: int in OUTLINE_SAMPLES:
		var angle: float = deg_to_rad(start_angle) + sweep * float(step) / float(OUTLINE_SAMPLES - 1)
		outline.append(Vector2.from_angle(angle) * radius)
	return outline

## @ace_hidden
func shape_is_closed() -> bool:
	return end_angle - start_angle >= 359.9 or _flag("fill")

## @ace_hidden
func shape_bounds() -> Rect2:
	var reach: float = maxf(radius, inner_radius)
	return Rect2(Vector2(-reach, -reach), Vector2(reach, reach) * 2.0)
#endregion
