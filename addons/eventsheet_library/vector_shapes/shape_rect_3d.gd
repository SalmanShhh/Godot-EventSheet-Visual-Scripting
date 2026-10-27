@tool
## @ace_tags(visual, shapes, drawing, 3d)
## @ace_category("Vector Shapes")
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/vector_shapes/icon.svg")
class_name ShapeRect3D
extends VectorShape3D
## A rectangle with rounded corners (one number, or four), a fill, a border, and dashes on that border - the panel over a machine, the selection box on the floor, the plate behind a health bar.

@export_group("Geometry")
## How this shape lives in 3D: flat on its own plane, always turned to face the camera, or as real
## geometry a light and a depth buffer treat like anything else in the scene.
## @ace_hidden
@export_custom(PROPERTY_HINT_NONE, "eventsheet:toggle_row:flat,billboard,volumetric:segmented") var geometry: String = "billboard":
	set(value):
		geometry = value
		notify_property_list_changed()
		shape_changed()
## How many sides the volumetric form is built from. Higher is rounder and costs more vertices; it
## is read only when the shape is volumetric, because a flat one has no vertices to spend.
## @ace_hidden
@export_range(3, 64, 1) var detail: int = 16:
	set(value):
		detail = value
		shape_changed()

# @inspector_preview
@export_group("Rect")
## How big the rectangle is, in the node's own units. It is centred on the node's origin, so
## rotating the node turns it about its middle.
@export var size: Vector2 = Vector2(1.0, 0.6):
	set(value):
		size = value
		shape_changed()
## How round the four corners are, clockwise from the top-left. One box while they agree, four when
## they should not.
## @ace_hidden
@export_custom(PROPERTY_HINT_NONE, "eventsheet:corners") var corner_radius: Vector4 = Vector4.ZERO:
	set(value):
		corner_radius = value
		shape_changed()

@export_group("Stroke")
## How wide the stroke is, in whichever unit the row below says.
## @ace_hidden
@export var thickness: float = 0.05:
	set(value):
		thickness = value
		shape_changed()
## What the number above means: world units are the node's own (a rope five centimetres thick is
## 0.05), and screen units are PIXELS - the shape keeps that weight however far away the camera is,
## which is what a range ring or a gizmo line wants. The unit is a mode rather than a view here,
## because a distance is what turns one into the other and only the camera knows it.
## @ace_hidden
@export_custom(PROPERTY_HINT_NONE, "eventsheet:toggle_row:world,screen:segmented") var thickness_unit: String = "world":
	set(value):
		thickness_unit = value
		shape_changed()

## Turns the stroke into dashes. The Dashed section below sets how they run.
## @ace_hidden
@export var dashed: bool = false:
	set(value):
		dashed = value
		notify_property_list_changed()
		shape_changed()

@export_group("Colour")
## One colour, a blend across it, out from the middle, or a colour per corner.
@export_enum("single", "two", "radial", "gradient", "per corner") var colour_mode: String = "single":
	set(value):
		colour_mode = value
		notify_property_list_changed()
		shape_changed()

@export_group("Colour")
## The shape's colour - the whole of it in single mode, and the first end of the blend in every
## other mode.
## @ace_hidden
@export_custom(PROPERTY_HINT_NONE, "eventsheet:swatch_row") var colour: Color = Color("#e6e6e6"):
	set(value):
		colour = value
		shape_changed()
## The other end of the blend: the far end of a rope, the outer edge of a ring, the end of a sweep.
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
## The fourth corner's colour, in per-corner mode.
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
## its stroke, so the two can never sit a unit apart.
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
## How wide the border is, in the same unit as the stroke above.
## @ace_hidden
@export var border_thickness: float = 0.02:
	set(value):
		border_thickness = value
		shape_changed()

# @inspector_show_if dashed
@export_group("Dashed")
## How a dash length is measured: in the node's own units, in multiples of the stroke's own
## thickness, or not at all - "count" fits a fixed number of dashes to the shape however long it is.
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
@export var dash_size: float = 0.2:
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
## How the shape meets what is behind it. These are the five blends the pack compiles a shader for;
## a volumetric shape reads the same word off its own surface.
## @ace_hidden
@export_enum("normal", "add", "subtract", "multiply", "premultiplied") var blend: String = "normal":
	set(value):
		blend = value
		shape_changed()
## Whether the shape is sorted against the world the ordinary way, or drawn over everything in front
## of it - which is what a gizmo line or a range ring that has to read through a wall wants. Drawing
## through walls is honest about its cost: it is a second shader, not a flag on the same one.
## @ace_hidden
@export_custom(PROPERTY_HINT_NONE, "eventsheet:toggle_row:test,through walls:segmented") var depth: String = "test":
	set(value):
		depth = value
		shape_changed()
## How wide the fade at an edge is, in pixels. One pixel is a crisp edge at any distance; wider is a
## deliberate glow; zero is a hard, aliased edge.
## @ace_hidden
@export_range(0.0, 4.0, 0.1) var antialias_width: float = 1.0:
	set(value):
		antialias_width = value
		shape_changed()

## @ace_hidden
func shape_plane_bounds() -> Rect2:
	return Rect2(-size * 0.5, size)
## The volumetric rect is a box as deep as the stroke is wide - a slab, which is what a panel or a
## step in the world actually is.
## @ace_hidden
func shape_volume_mesh(_detail: int) -> Mesh:
	var slab: BoxMesh = BoxMesh.new()
	slab.size = Vector3(size.x, size.y, maxf(_number("thickness", 0.05), 0.001))
	return slab

## Inspector conditions: a field that has nothing to say in the mode the shape is in hides, rather
## than sitting there meaning nothing. Godot's own way, so a hidden field still stores and still
## reads back - this only decides what the Inspector draws.
func _validate_property(property: Dictionary) -> void:
	var mode: String = _word("colour_mode", "single")
	var solid: bool = shape_geometry() == "volumetric"
	var blends_two: bool = mode == "two" or mode == "radial" or mode == "angular"
	var per_corner: bool = mode == "per corner"
	if str(property.name) == "detail" and not bool(solid):
		property.usage &= ~PROPERTY_USAGE_EDITOR
	if str(property.name) in ["caps", "dashed", "antialias_width", "colour_mode"] and bool(solid):
		property.usage &= ~PROPERTY_USAGE_EDITOR
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
	if str(property.name) in ["dash_space", "dash_snap", "dash_size", "dash_count", "dash_spacing", "dash_offset", "dash_style"] and not bool(_flag("dashed") and not solid):
		property.usage &= ~PROPERTY_USAGE_EDITOR
	if str(property.name) == "dash_size" and not bool(_word("dash_space", "count") != "count"):
		property.usage &= ~PROPERTY_USAGE_EDITOR
	if str(property.name) == "dash_count" and not bool(_word("dash_space", "count") == "count"):
		property.usage &= ~PROPERTY_USAGE_EDITOR

## @ace_hidden
func shape_kind_id() -> int:
	return 2

## @ace_hidden
func shape_points_3d() -> PackedVector3Array:
	var half: Vector2 = size * 0.5
	return PackedVector3Array([
		Vector3(-half.x, -half.y, 0.0),
		Vector3(half.x, -half.y, 0.0),
		Vector3(half.x, half.y, 0.0),
		Vector3(-half.x, half.y, 0.0)
	])

## @ace_hidden
func shape_is_closed() -> bool:
	return true
