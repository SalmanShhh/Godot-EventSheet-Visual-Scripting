@tool
## @ace_tags(visual, shapes, drawing, 2d)
## @ace_category("Vector Shapes")
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/behavior.svg")
class_name ShapeTriangle2D
extends VectorShape2D
## Three corners, the first of them the node's own origin, with a colour per corner if you want one - the arrow head, the wedge, the pointer.

# @inspector_action save_as_style Save As Style
## A Shape Style file this shape wears instead of its own look. Empty is the usual case - the fields
## below are this shape's own. With one dropped in, every field the style speaks for is read from
## the file and shown greyed here, so twenty lines share one thickness, one cap and one dash
## pattern; the button above writes the current fields out as a new style file to reuse.
## @ace_hidden
@export var style: ShapeStyle = null:
	set(value):
		if style != null and style.changed.is_connected(style_changed_externally):
			style.changed.disconnect(style_changed_externally)
		style = value
		if style != null and not style.changed.is_connected(style_changed_externally):
			style.changed.connect(style_changed_externally)
		notify_property_list_changed()
		shape_changed()

# @inspector_preview
# @inspector_handle corner_b point
# @inspector_handle corner_c point
@export_group("Triangle")
## The second corner, in the node's own coordinates. The first is the origin.
@export var corner_b: Vector2 = Vector2(72.0, 0.0):
	set(value):
		corner_b = value
		shape_changed()
## The third corner, in the node's own coordinates.
@export var corner_c: Vector2 = Vector2(36.0, -64.0):
	set(value):
		corner_c = value
		shape_changed()

@export_group("Stroke")
## How wide the stroke is. The dropdown at the field's right reads the number in pixels, world units
## or screen units; the number stored here is always pixels, so nothing moves when you flip it.
## @ace_hidden
@export_custom(PROPERTY_HINT_NONE, "eventsheet:unit:kinds=px|world|screen,store=px") var thickness: float = 2.0:
	set(value):
		thickness = value
		shape_changed()
## Whether the stroke follows the node's own scale, or keeps the weight it has on screen however far
## the camera zooms - which is what a HUD line wants.
## @ace_hidden
@export_enum("with the node", "fixed on screen") var thickness_scale: String = "with the node":
	set(value):
		thickness_scale = value
		shape_changed()

@export_group("Colour")
## One colour, a blend across it, out from the middle, or a colour per corner.
@export_enum("single", "two", "radial", "gradient", "per corner") var colour_mode: String = "single":
	set(value):
		colour_mode = value
		notify_property_list_changed()
		shape_changed()

## The shape's colour - the whole of it in single mode, and the first end of the blend in every
## other mode.
## @ace_hidden
@export_custom(PROPERTY_HINT_NONE, "eventsheet:swatch_row") var colour: Color = Color("#e6e6e6"):
	set(value):
		colour = value
		shape_changed()
## The other end of the blend: the far end of a line, the outer edge of a ring, the end of a sweep.
## @ace_hidden
@export_custom(PROPERTY_HINT_NONE, "eventsheet:swatch_row") var colour_b: Color = Color("#4a90d9"):
	set(value):
		colour_b = value
		shape_changed()
## The third corner's colour, in per-corner mode.
## @ace_hidden
@export_custom(PROPERTY_HINT_NONE, "eventsheet:swatch_row") var colour_c: Color = Color("#d94a4a"):
	set(value):
		colour_c = value
		shape_changed()
## The fourth corner's colour, in per-corner mode. A three-cornered shape ignores it.
## @ace_hidden
@export_custom(PROPERTY_HINT_NONE, "eventsheet:swatch_row") var colour_d: Color = Color("#4ad98a"):
	set(value):
		colour_d = value
		shape_changed()
## The ramp a gradient shape is coloured with - Godot's own Gradient resource, edited in Godot's own
## gradient editor.
## @ace_hidden
@export var gradient: Gradient = null:
	set(value):
		gradient = value
		shape_changed()

## Fills the shape rather than drawing only its outline. A filled shape draws its BORDER instead of
## its stroke, so the two can never sit a pixel apart.
## @ace_hidden
@export var fill: bool = false:
	set(value):
		fill = value
		shape_changed()

# @inspector_show_if border
@export_group("Border")
## Draws a line around the filled shape, on the fill's own edge.
## @ace_hidden
@export var border: bool = false:
	set(value):
		border = value
		notify_property_list_changed()
		shape_changed()
## The border's colour.
## @ace_hidden
@export_custom(PROPERTY_HINT_NONE, "eventsheet:swatch_row") var border_colour: Color = Color("#1c1c1c"):
	set(value):
		border_colour = value
		shape_changed()
## How wide the border is. Read in pixels, world units or screen units; stored in pixels.
## @ace_hidden
@export_custom(PROPERTY_HINT_NONE, "eventsheet:unit:kinds=px|world|screen,store=px") var border_thickness: float = 2.0:
	set(value):
		border_thickness = value
		shape_changed()

@export_group("Drawing")
## How the shape meets what is behind it. These are the five blends a canvas shader can be compiled
## for; a shape that wants one of the screen-reading modes goes under a parent the Blend Modes pack
## has blended, because a shape owns its own material.
## @ace_hidden
@export_enum("normal", "add", "subtract", "multiply", "premultiplied") var blend: String = "normal":
	set(value):
		blend = value
		shape_changed()
## How wide the fade at an edge is, in pixels. One pixel is a crisp edge at any zoom; wider is a
## deliberate glow; zero is a hard, aliased edge.
## @ace_hidden
@export_range(0.0, 4.0, 0.1) var antialias_width: float = 1.0:
	set(value):
		antialias_width = value
		shape_changed()

## @ace_hidden
func shape_bounds() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2.ZERO).expand(corner_b).expand(corner_c)

## Inspector conditions: a field that has nothing to say in the mode the shape is in hides, rather
## than sitting there meaning nothing. Godot's own way, so a hidden field still stores and still
## reads back - this only decides what the Inspector draws.
func _validate_property(property: Dictionary) -> void:
	var mode: String = _word("colour_mode", "single")
	var blends_two: bool = mode == "two" or mode == "radial" or mode == "angular"
	var per_corner: bool = mode == "per corner"
	if str(property.name) == "colour_b" and not bool(blends_two or per_corner):
		property.usage &= ~PROPERTY_USAGE_EDITOR
	if str(property.name) == "colour_c" and not bool(per_corner):
		property.usage &= ~PROPERTY_USAGE_EDITOR
	if str(property.name) == "colour_d" and not bool(per_corner):
		property.usage &= ~PROPERTY_USAGE_EDITOR
	if str(property.name) == "gradient" and not bool(mode == "gradient"):
		property.usage &= ~PROPERTY_USAGE_EDITOR
	if str(property.name) in ["border_colour", "border_thickness"] and not bool(_flag("border")):
		property.usage &= ~PROPERTY_USAGE_EDITOR
	if str(property.name) in ["dash_space", "dash_snap", "dash_size", "dash_count", "dash_spacing", "dash_offset", "dash_style"] and not bool(_flag("dashed")):
		property.usage &= ~PROPERTY_USAGE_EDITOR
	if str(property.name) == "dash_size" and not bool(_word("dash_space", "count") != "count"):
		property.usage &= ~PROPERTY_USAGE_EDITOR
	if str(property.name) == "dash_count" and not bool(_word("dash_space", "count") == "count"):
		property.usage &= ~PROPERTY_USAGE_EDITOR
	# A field a style speaks for is still THIS shape's field, and still what the file stores - it is
	# simply not what the shape draws with while the style is in the slot. So it is shown greyed
	# rather than hidden: you can read what the shape would look like on its own, and clearing the
	# slot hands it straight back.
	if style_speaks_for(str(property.name)):
		property.usage |= PROPERTY_USAGE_READ_ONLY

## @ace_hidden
func shape_kind_id() -> int:
	return 5

## @ace_hidden
func shape_points() -> PackedVector2Array:
	return PackedVector2Array([Vector2.ZERO, corner_b, corner_c])

## @ace_hidden
func shape_is_closed() -> bool:
	return true
