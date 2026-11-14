@tool
## @ace_tags(visual, shapes, drawing, style, 2d)
## @ace_category("Vector Shapes")
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/vector_shapes/icon.svg")
class_name ShapeStyle
extends Resource
## A stroke style twenty shapes can share: thickness, caps, colour mode and colours, dashes and blend, as a file. Drop one into a 2D shape's Style slot and those fields are read from the file; save one out of a shape you have tuned with Save As Style.

# @inspector_look unit:kinds=px|world|screen,store=px
## Stroke width; the dropdown reads it in pixels, world units or screen units.
## @ace_hidden
@export_range(0, 1, 0.001, "or_greater", "or_less", "hide_slider", "suffix:px") var thickness: float = 2.0:
	set(value):
		thickness = value
		emit_changed()
## Whether the stroke follows the node's own scale, or keeps the weight it has on screen however far the camera zooms.
## @ace_hidden
@export_enum("with the node", "fixed on screen") var thickness_scale: String = "with the node":
	set(value):
		thickness_scale = value
		emit_changed()
# @inspector_look toggle_row:segmented
## What the two ends of a stroke look like: cut off, squared off half a thickness past the end, or rounded.
## @ace_hidden
@export_enum("none", "square", "round") var caps: String = "round":
	set(value):
		caps = value
		emit_changed()
@export_group("Colour")
## How the shape is coloured; each shape offers the modes it can draw.
## @ace_hidden
@export_enum("single", "two", "radial", "angular", "gradient", "per corner") var colour_mode: String = "single":
	set(value):
		colour_mode = value
		emit_changed()
## The main colour - the whole shape in single mode, and the first end of the blend in the others.
## @ace_hidden
@export_custom(PROPERTY_HINT_NONE, "eventsheet:swatch_row") var colour: Color = Color("#e6e6e6"):
	set(value):
		colour = value
		emit_changed()
## The other end of the blend.
## @ace_hidden
@export_custom(PROPERTY_HINT_NONE, "eventsheet:swatch_row") var colour_b: Color = Color("#4a90d9"):
	set(value):
		colour_b = value
		emit_changed()
## The ramp a gradient shape is coloured with. An empty slot leaves each shape its own ramp.
## @ace_hidden
@export var gradient: Gradient = null:
	set(value):
		gradient = value
		emit_changed()
@export_group("Dashed")
## Turns the stroke into dashes on every shape wearing this style.
## @ace_hidden
@export var dashed: bool = false:
	set(value):
		dashed = value
		emit_changed()
## How dash length is measured: world units, thickness multiples, or count.
## @ace_hidden
@export_enum("world", "relative", "count") var dash_space: String = "count":
	set(value):
		dash_space = value
		emit_changed()
## How dashes meet the ends: off, tiling to fit whole, or end to end.
## @ace_hidden
@export_enum("off", "tiling", "end to end") var dash_snap: String = "tiling":
	set(value):
		dash_snap = value
		emit_changed()
## One dash, in the space above.
## @ace_hidden
@export var dash_size: float = 12.0:
	set(value):
		dash_size = value
		emit_changed()
## How many dashes the shape carries, in count mode.
## @ace_hidden
@export_range(1, 128, 1) var dash_count: int = 12:
	set(value):
		dash_count = value
		emit_changed()
## The gap after each dash: a share of one dash period in count mode, a length otherwise.
## @ace_hidden
@export var dash_spacing: float = 0.5:
	set(value):
		dash_spacing = value
		emit_changed()
# @inspector_look toggle_row:icons=vector_shapes_dash
## What one dash looks like: cut square, leaning over, or rounded at both ends.
## @ace_hidden
@export_enum("plain", "angled", "rounded") var dash_style: String = "plain":
	set(value):
		dash_style = value
		emit_changed()
@export_group("Drawing")
## How a shape wearing this style meets what is behind it.
## @ace_hidden
@export_enum("normal", "add", "subtract", "multiply", "premultiplied") var blend: String = "normal":
	set(value):
		blend = value
		emit_changed()

## The shape fields a style speaks for, spelled as the shapes spell them. A field NOT in this list
## is the shape's own however the style is filled in - which is what keeps a style a LOOK rather
## than a second copy of a shape: a radius, an end point and a list of points are never in here.
## @ace_hidden
static func styled_keys() -> PackedStringArray:
	return PackedStringArray(["thickness", "thickness_scale", "caps", "colour_mode", "colour", "colour_b", "gradient", "dashed", "dash_space", "dash_snap", "dash_size", "dash_count", "dash_spacing", "dash_style", "blend"])

## What this style says one field should be, or null when it says nothing about it. A shape asks
## this for every field it draws with, so an unfilled gradient slot (null) leaves the shape's own.
## @ace_hidden
func value_for(key: String) -> Variant:
	if not styled_keys().has(key):
		return null
	return get(key)

# A Shape Style is a look, not a shape: the fields it speaks for are the ones a designer re-uses (thickness and its scale rule, caps, the colour mode and its colours, the dash pattern, the blend), and never a radius, an end point or a list of points. A shape that has not got a field the style carries is untouched by it. This pack is an event sheet - extend it by editing it.
