@tool
## @ace_tags(visual, shapes, drawing, 3d)
## @ace_category("Vector Shapes")
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/behavior.svg")
class_name ShapeTorus3D
extends VectorShape3D
## The engine's own torus with the family's colour, blend and depth fields on it - the portal ring, the halo, the hoop a racer flies through.

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

@export_group("Surface")
## The shape's colour. A solid wrapper is real geometry drawn unshaded, so this is the colour on
## screen rather than a tint a light has an opinion about.
## @ace_hidden
@export_custom(PROPERTY_HINT_NONE, "eventsheet:swatch_row") var colour: Color = Color("#e6e6e6"):
	set(value):
		colour = value
		shape_changed()
## How many sides the mesh is built from. Higher is rounder and costs more vertices.
## @ace_hidden
@export_range(3, 64, 1) var detail: int = 16:
	set(value):
		detail = value
		shape_changed()
## How the shape meets what is behind it.
## @ace_hidden
@export_enum("normal", "add", "subtract", "multiply", "premultiplied") var blend: String = "normal":
	set(value):
		blend = value
		shape_changed()
## Whether the shape is sorted against the world the ordinary way, or drawn over everything in front
## of it - the debug volume you want to see through the level.
## @ace_hidden
@export_custom(PROPERTY_HINT_NONE, "eventsheet:toggle_row:test,through walls:segmented") var depth: String = "test":
	set(value):
		depth = value
		shape_changed()

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

## @ace_hidden
func shape_is_solid() -> bool:
	return true
