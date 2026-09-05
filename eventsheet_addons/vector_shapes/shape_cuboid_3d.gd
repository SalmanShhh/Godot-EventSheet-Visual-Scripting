@tool
## @ace_tags(visual, shapes, drawing, 3d)
## @ace_category("Vector Shapes")
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/vector_shapes/icon.svg")
class_name ShapeCuboid3D
extends VectorShape3D
## The engine's own box with the family's colour, blend and depth fields on it - the block-out volume, the crate, the trigger you want to see.

# @inspector_preview
@export_group("Cuboid")
## How big the box is, in the node's own units. It is centred on the node's origin.
@export var size: Vector3 = Vector3.ONE:
	set(value):
		size = value
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
func shape_volume_mesh(_detail: int) -> Mesh:
	var block: BoxMesh = BoxMesh.new()
	block.size = size
	return block
## @ace_hidden
func shape_plane_bounds() -> Rect2:
	return Rect2(Vector2(-size.x, -size.y) * 0.5, Vector2(size.x, size.y))

## @ace_hidden
func shape_is_solid() -> bool:
	return true
