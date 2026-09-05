@tool
## @ace_tags(visual, shapes, drawing, 2d)
## @ace_category("Vector Shapes")
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/behavior.svg")
class_name ShapeLine2D
extends VectorShape2D
## A straight line from the node's origin to a point you drag, drawn by distance so it is one crisp pixel wide at any zoom. Caps, a colour at each end, and dashes that scroll.

# @inspector_preview
# @inspector_handle end_point point
@export_group("Line")
## Where the line ends, in the node's own coordinates. It starts at the node's origin, so moving the
## node moves the start and dragging the handle moves the end.
@export var end_point: Vector2 = Vector2(96.0, 0.0):
	set(value):
		end_point = value
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

## What the two ends of the stroke look like: cut off, squared off half a thickness past the end, or
## rounded.
## @ace_hidden
@export_custom(PROPERTY_HINT_NONE, "eventsheet:toggle_row:none,square,round:segmented") var caps: String = "round":
	set(value):
		caps = value
		shape_changed()

## Turns the stroke into dashes. The Dashed section below sets how they run.
## @ace_hidden
@export var dashed: bool = false:
	set(value):
		dashed = value
		notify_property_list_changed()
		shape_changed()

@export_group("Colour")
## One colour, two (start to end), or a whole ramp along the line.
@export_enum("single", "two", "gradient") var colour_mode: String = "single":
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

# @inspector_show_if dashed
@export_group("Dashed")
## How a dash length is measured: in world pixels, in multiples of the stroke's own thickness, or
## not at all - "count" fits a fixed number of dashes to the shape however long it is.
## @ace_hidden
@export_enum("world", "relative", "count") var dash_space: String = "count":
	set(value):
		dash_space = value
		notify_property_list_changed()
		shape_changed()
## How the pattern meets the ends: off leaves it wherever it falls, tiling makes it fit the shape a
## whole number of times, end to end also centres a dash on each end - which is what puts a dash on
## every corner of a rect and every vertex of a polygon.
## @ace_hidden
@export_enum("off", "tiling", "end to end") var dash_snap: String = "tiling":
	set(value):
		dash_snap = value
		shape_changed()
## One dash, in the space above.
## @ace_hidden
@export var dash_size: float = 12.0:
	set(value):
		dash_size = value
		shape_changed()
# @inspector_link dash_count dash_spacing
## How many dashes the shape carries, in count mode.
## @ace_hidden
@export_range(1, 128, 1) var dash_count: int = 12:
	set(value):
		dash_count = value
		shape_changed()
## The gap after each dash: a share of one dash period in count mode (0.5 is half dash, half gap),
## and a length in the space above otherwise.
## @ace_hidden
@export var dash_spacing: float = 0.5:
	set(value):
		dash_spacing = value
		shape_changed()
## Moves the pattern along the shape. Whole numbers tile, so scrolling never jumps.
## @ace_hidden
@export var dash_offset: float = 0.0:
	set(value):
		dash_offset = value
		shape_changed()
## What one dash looks like: cut square, leaning over, or rounded at both ends.
## @ace_hidden
@export_custom(PROPERTY_HINT_NONE, "eventsheet:toggle_row:plain,angled,rounded:icons=vector_shapes_dash") var dash_style: String = "plain":
	set(value):
		dash_style = value
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
	return Rect2(Vector2.ZERO, Vector2.ZERO).expand(end_point)

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

## @ace_hidden
func shape_kind_id() -> int:
	return 0

## @ace_hidden
func shape_points() -> PackedVector2Array:
	return PackedVector2Array([Vector2.ZERO, end_point])

## @ace_hidden
func shape_is_closed() -> bool:
	return false
