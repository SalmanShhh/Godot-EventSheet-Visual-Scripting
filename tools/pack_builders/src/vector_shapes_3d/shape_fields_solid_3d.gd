# Pack source - vector_shapes, the fields the four SOLID wrappers carry. A Sphere, a Cuboid, a Cone
# and a Torus are real geometry and nothing else: no stroke, no dashes, no distance field, so they
# share none of the flat family's fields and are declared in a file of their own rather than being
# switched off one by one in the Inspector.
extends "res://tools/pack_builders/src/vector_shapes_3d/vector_shape_3d.gd"

#region fields_solid_3d
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
#endregion
