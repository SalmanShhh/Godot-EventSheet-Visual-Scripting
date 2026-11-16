# Godot EventSheets - the small picture of a shape on a Drawing Prefab's card line (editor-only).
#
# A tile that DRAWS the shape's kind - a filled disc, a ring, a rectangle, a line, a wedge, a stamp
# mark - in the step's own colour, so a list of folded cards reads like a thumbnail strip of the
# drawing. It is a picture of the kind only: the size on the line is the summary's job.
#
# On a light editor a pale shape would vanish into the ground, so it keeps a faint dark edge that
# FOLLOWS the shape (never a box round the tile). The same image feeds the Add box, where each kind
# wears its tile in a flat list.
#
# This file carries no `class_name` and is loaded BY PATH from the steps editor, so nothing that runs
# at editor boot names it.
@tool
extends TextureRect

## What the tile shows now, so a test (and a repaint) can read it back.
var shown_kind: String = ""
var shown_color: Color = Color.WHITE
var _side: int = 16
var _on_light: bool = false


func _init(side: int = 16, on_light: bool = false) -> void:
	_side = side
	_on_light = on_light
	custom_minimum_size = Vector2(side, side)
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_PASS


## Draws the tile for a card: its kind and its colour. Done in place, so a colour typed in an open card
## repaints the line above it without the list being rebuilt.
func set_card(card: Dictionary) -> void:
	shown_kind = str(card.get("kind", ""))
	shown_color = Color.from_string(str(card.get("color", "#ffffff")), Color.WHITE)
	texture = ImageTexture.create_from_image(shape_image(shown_kind, shown_color, _side, _on_light))


## One shape as a square picture. Every shape is a signed distance, so its edge is smooth at any size;
## a kind this file does not know draws as a hollow square in a quiet grey.
static func shape_image(kind: String, color: Color, side: int, on_light: bool) -> Image:
	var image: Image = Image.create(side, side, false, Image.FORMAT_RGBA8)
	var half: float = float(side) * 0.5
	# A pale shape on a light ground wears a faint dark edge a little wider than itself.
	var edge: bool = on_light and color.get_luminance() > 0.55
	var edge_colour: Color = Color(0.1, 0.1, 0.12, 0.45)
	var ink: Color = color if kind in ["circle", "ring", "rect", "line", "cone", "stamp"] else Color(0.5, 0.5, 0.55, 1.0)
	for y: int in range(side):
		for x: int in range(side):
			var point: Vector2 = Vector2(float(x) + 0.5 - half, float(y) + 0.5 - half)
			var distance: float = _distance(kind, point, half)
			var pixel: Color = Color(0.0, 0.0, 0.0, 0.0)
			if edge:
				var edge_cover: float = clampf(0.5 - (distance - 0.9), 0.0, 1.0)
				if edge_cover > 0.0:
					pixel = Color(edge_colour.r, edge_colour.g, edge_colour.b, edge_colour.a * edge_cover)
			var cover: float = clampf(0.5 - distance, 0.0, 1.0)
			if cover > 0.0:
				# The shape over whatever the edge left, so the join is smooth.
				var alpha: float = cover + pixel.a * (1.0 - cover)
				var mix: Color = (Color(ink.r, ink.g, ink.b) * cover + Color(pixel.r, pixel.g, pixel.b) * pixel.a * (1.0 - cover)) / maxf(alpha, 0.0001)
				pixel = Color(mix.r, mix.g, mix.b, alpha * ink.a)
			image.set_pixel(x, y, pixel)
	return image


## The signed distance from a point (centre at 0,0) to the kind's outline, in pixels: negative inside.
static func _distance(kind: String, point: Vector2, half: float) -> float:
	var reach: float = half - 1.2
	match kind:
		"circle":
			return point.length() - reach
		"ring":
			return absf(point.length() - (reach - 1.0)) - 1.0
		"rect":
			return _box(point, Vector2(reach, reach * 0.68))
		"line":
			return _segment(point, Vector2(-reach + 1.0, reach - 1.0), Vector2(reach - 1.0, -reach + 1.0)) - 1.1
		"cone":
			return _wedge(point, reach)
		"stamp":
			# A frame with a dot at its centre: the mark a texture carries.
			var frame: float = absf(_box(point, Vector2(reach, reach)) + 1.0) - 0.75
			return minf(frame, point.length() - 1.4)
	# Unknown: a hollow square, so the line says "something is here that is not a shape".
	return absf(_box(point, Vector2(reach, reach)) + 0.8) - 0.8


static func _box(point: Vector2, extent: Vector2) -> float:
	var d: Vector2 = point.abs() - extent
	return Vector2(maxf(d.x, 0.0), maxf(d.y, 0.0)).length() + minf(maxf(d.x, d.y), 0.0)


static func _segment(point: Vector2, a: Vector2, b: Vector2) -> float:
	var along: Vector2 = b - a
	var t: float = clampf((point - a).dot(along) / along.length_squared(), 0.0, 1.0)
	return (point - (a + along * t)).length()


## A wedge opening to the left, like the cone's own picture: the apex on the right, a 90 degree fan.
static func _wedge(point: Vector2, reach: float) -> float:
	var apex: Vector2 = Vector2(reach, 0.0)
	var local: Vector2 = point - apex
	var spread: float = deg_to_rad(36.0)
	# Distance to a sector of the given half-angle pointing along -x, clipped at `reach * 2` from the apex.
	var radius: float = reach * 2.0
	var along: float = -local.x
	var across: float = absf(local.y)
	var rim: float = local.length() - radius
	var side_line: float = (Vector2(sin(spread), -cos(spread)).dot(Vector2(across, along)))
	return maxf(rim, side_line)
