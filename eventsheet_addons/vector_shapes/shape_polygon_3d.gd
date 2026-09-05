@tool
## @ace_tags(visual, shapes, drawing, 3d)
## @ace_category("Vector Shapes")
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/vector_shapes/icon.svg")
class_name ShapePolygon3D
extends VectorShape3D
## A closed outline through points you drag in the 3D viewport, filled or hollow, with a border of its own - the claimed territory, the zone marker, the stylised leaf.

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
# @inspector_handle points points
@export_group("Polygon")
## The corners, in the node's own coordinates. Each one is a handle in the 3D viewport while the
## node is selected, dragged on the plane facing the camera. Past thirty-two points this is Godot's
## own mesh tools' job, and the extra points are left undrawn rather than silently thinned.
## @ace_hidden
@export var points: PackedVector3Array = PackedVector3Array([
	Vector3(-0.5, -0.4, 0.0), Vector3(0.0, 0.5, 0.0), Vector3(0.5, -0.4, 0.0), Vector3(0.0, -0.15, 0.0)
]):
	set(value):
		points = value
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

@export_group("Colour")
## One colour, a blend across it, out from the middle, or a whole ramp.
@export_enum("single", "two", "radial", "gradient") var colour_mode: String = "single":
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
	if points.is_empty():
		return Rect2()
	var box: Rect2 = Rect2(Vector2(points[0].x, points[0].y), Vector2.ZERO)
	for point: Vector3 in points:
		box = box.expand(Vector2(point.x, point.y))
	return box

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
	return 3

## @ace_hidden
func shape_points_3d() -> PackedVector3Array:
	return points

## @ace_hidden
func shape_is_closed() -> bool:
	return true
