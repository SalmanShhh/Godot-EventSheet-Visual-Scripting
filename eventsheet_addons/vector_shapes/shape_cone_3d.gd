@tool
## @ace_tags(visual, shapes, drawing, 3d)
## @ace_category("Vector Shapes")
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/behavior.svg")
class_name ShapeCone3D
extends VectorShape3D
## A cone with an optional cap, wearing the family's colour, blend and depth fields - the spotlight volume, the arrow head, the vision cone you can walk around.

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

## @ace_hidden
func shape_is_solid() -> bool:
	return true
