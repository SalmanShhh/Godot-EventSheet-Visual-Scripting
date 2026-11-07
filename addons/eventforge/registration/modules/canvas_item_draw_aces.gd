# EventForge module - Godot's own drawing calls, as actions under On Draw.
#
# A node paints itself in `_draw()`, and what it paints with is the CanvasItem's own `draw_*` calls:
# `draw_rect`, `draw_string`, `draw_arc` and the rest. These rows write exactly those calls, with
# Godot's own argument names, in Godot's own order, so a reader who knows the engine's documentation
# knows the row and a reader who does not learns the documentation from it.
#
# THEY ARE NOT THE DRAWING MODULE. The rows in drawing_aces.gd paint onto ANOTHER node's offscreen
# canvas through the CanvasSurface helper; these paint onto the node that is drawing, in its own
# `_draw()`. Both stay: ace_ids and templates are API once shipped, and neither can speak for the
# other's lines.
#
# THE TRAILING ARGUMENTS ARE OPTIONAL, because Godot's are. A call written with fewer arguments is
# the same row with the later fields left blank, and a blank field writes nothing - so a hand-written
# `draw_line(a, b, Color.RED)` opens as Draw Line and saves back to the same bytes. The lifter reads the
# optional tail as an ORDERED chain (see ORDERED_OPTIONAL_COMMA_ACE_IDS in ace_lifter.gd): a later
# argument can only be given when every argument before it is, exactly as in the call itself.
#
# THE DRAW CALLS ARE ONLY OFFERED UNDER ON DRAW. Godot refuses them anywhere else, so the picker does
# not list them elsewhere (EventSheetPickerGates, "a row that compiles in one place only"). Redraw is
# the one row of the family usable anywhere: it asks the node to run its On Draw event again.
#
# Module contract: see ace_factory.gd.
@tool
class_name EventForgeCanvasItemDrawACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

const CAT := "Drawing: Godot calls"

## Both Node2D and Control are CanvasItems, and draw_* lives on the CanvasItem.
const HOST := "CanvasItem"

## Every id of the family that is only valid inside On Draw starts with this. The picker gate and the
## node-target pass (builtin_aces.gd) read the prefix as text, so a row added here is covered with no
## list to extend.
const DRAW_ONLY_PREFIX := "CanvasItemDraw"


static func get_descriptors() -> Array[ACEDescriptor]:
	var d: Array[ACEDescriptor] = []

	d.append(F.act("CanvasItemDrawLine", "Draw Line", "draw_line({from}, {to}, {color}{, width}{, antialiased})", CAT,
		"Draw line from [b]{from}[/b] to [b]{to}[/b] in [b]{color}[/b]{?width}, width [b]{width}[/b]{/width}",
		"Godot's draw_line: a straight line between two points, drawn by this node. Only works under On Draw.", HOST)
		.param_typed("Vector2", "from", "Vector2(0, 0)", "From", "Where the line starts, in this node's own coordinates.", "expression")
		.param_typed("Vector2", "to", "Vector2(64, 0)", "To", "Where the line ends.", "expression")
		.param_built(_color())
		.param_built(_width("The line's thickness. Godot's default, -1.0, is a thin hardware line that antialiasing cannot smooth."))
		.param_built(_antialiased()).featured())

	d.append(F.act("CanvasItemDrawRect", "Draw Rectangle", "draw_rect({rect}, {color}{, filled}{, width}{, antialiased})", CAT,
		"Draw rectangle [b]{rect}[/b] in [b]{color}[/b]",
		"Godot's draw_rect, filled in: a solid rectangle drawn by this node. Only works under On Draw.", HOST)
		.param_built(_rect())
		.param_built(_color())
		.param_typed("bool", "filled", "true", "Filled", "Godot's default is true. Only true belongs on this row - a hollow rectangle is Draw Rectangle Outline.", "expression")
		.param_built(_width("Ignored for a filled rectangle. Godot's default is -1.0."))
		.param_built(_antialiased()).featured())

	d.append(F.act("CanvasItemDrawRectOutline", "Draw Rectangle Outline", "draw_rect({rect}, {color}, false{, width}{, antialiased})", CAT,
		"Draw rectangle outline [b]{rect}[/b] in [b]{color}[/b]{?width}, width [b]{width}[/b]{/width}",
		"Godot's draw_rect with filled false: only the rectangle's edge, drawn by this node. Only works under On Draw.", HOST)
		.param_built(_rect())
		.param_built(_color())
		.param_built(_width("The edge's thickness. Godot's default, -1.0, is a thin hardware line."))
		.param_built(_antialiased()))

	d.append(F.act("CanvasItemDrawCircle", "Draw Circle", "draw_circle({position}, {radius}, {color}{, filled}{, width}{, antialiased})", CAT,
		"Draw circle at [b]{position}[/b], radius [b]{radius}[/b], in [b]{color}[/b]",
		"Godot's draw_circle, filled in: a solid disc drawn by this node. Only works under On Draw.", HOST)
		.param_typed("Vector2", "position", "Vector2(0, 0)", "Position", "The centre of the circle, in this node's own coordinates.", "expression")
		.param_typed("float", "radius", "16.0", "Radius", "How far the circle reaches from its centre, in pixels.", "expression")
		.param_built(_color())
		.param_typed("bool", "filled", "true", "Filled", "Godot's default is true. Only true belongs on this row - a hollow circle is Draw Circle Outline.", "expression")
		.param_built(_width("Ignored for a filled circle. Godot's default is -1.0."))
		.param_built(_antialiased()))

	d.append(F.act("CanvasItemDrawCircleOutline", "Draw Circle Outline", "draw_circle({position}, {radius}, {color}, false{, width}{, antialiased})", CAT,
		"Draw circle outline at [b]{position}[/b], radius [b]{radius}[/b], in [b]{color}[/b]{?width}, width [b]{width}[/b]{/width}",
		"Godot's draw_circle with filled false: only the circle's edge, drawn by this node. Only works under On Draw.", HOST)
		.param_typed("Vector2", "position", "Vector2(0, 0)", "Position", "The centre of the circle, in this node's own coordinates.", "expression")
		.param_typed("float", "radius", "16.0", "Radius", "How far the circle reaches from its centre, in pixels.", "expression")
		.param_built(_color())
		.param_built(_width("The edge's thickness. Godot's default, -1.0, is a thin hardware line."))
		.param_built(_antialiased()))

	d.append(F.act("CanvasItemDrawArc", "Draw Arc", "draw_arc({center}, {radius}, {start_angle}, {end_angle}, {point_count}, {color}{, width}{, antialiased})", CAT,
		"Draw arc at [b]{center}[/b], radius [b]{radius}[/b], from [b]{start_angle}[/b] to [b]{end_angle}[/b], in [b]{color}[/b]{?width}, width [b]{width}[/b]{/width}",
		"Godot's draw_arc: part of a circle's edge, drawn by this node. Angles are in radians, so TAU is a full turn. Only works under On Draw.", HOST)
		.param_typed("Vector2", "center", "Vector2(0, 0)", "Center", "The centre of the circle the arc is part of.", "expression")
		.param_typed("float", "radius", "32.0", "Radius", "How far the arc is from the centre, in pixels.", "expression")
		.param_typed("float", "start_angle", "0.0", "Start angle", "Where the arc begins, in radians.", "expression")
		.param_typed("float", "end_angle", "PI", "End angle", "Where the arc ends, in radians.", "expression")
		.param_typed("int", "point_count", "32", "Point count", "How many points make up the arc: more is smoother.", "expression")
		.param_built(_color())
		.param_built(_width("The arc's thickness. Godot's default, -1.0, is a thin hardware line."))
		.param_built(_antialiased()))

	d.append(F.act("CanvasItemDrawPolyline", "Draw Polyline", "draw_polyline({points}, {color}{, width}{, antialiased})", CAT,
		"Draw polyline through [b]{points}[/b] in [b]{color}[/b]{?width}, width [b]{width}[/b]{/width}",
		"Godot's draw_polyline: one connected line through a list of points, drawn by this node. Only works under On Draw.", HOST)
		.param_typed("PackedVector2Array", "points", "PackedVector2Array([Vector2(0, 0), Vector2(32, 16), Vector2(64, 0)])", "Points", "The corners the line passes through, in order.", "expression")
		.param_built(_color())
		.param_built(_width("The line's thickness. Godot's default, -1.0, is a thin hardware line."))
		.param_built(_antialiased()))

	d.append(F.act("CanvasItemDrawPolygon", "Draw Polygon", "draw_polygon({points}, {colors}{, uvs}{, texture})", CAT,
		"Draw polygon through [b]{points}[/b] in [b]{colors}[/b]",
		"Godot's draw_polygon: a filled shape through a list of points, one colour per corner or one colour for all. Only works under On Draw.", HOST)
		.param_typed("PackedVector2Array", "points", "PackedVector2Array([Vector2(0, 0), Vector2(64, 0), Vector2(32, 48)])", "Points", "The corners of the shape, in order.", "expression")
		.param_typed("PackedColorArray", "colors", "PackedColorArray([Color.WHITE])", "Colors", "One colour for every corner, or one colour per corner.", "expression")
		.param_typed("PackedVector2Array", "uvs", "PackedVector2Array()", "UVs", "Where on the texture each corner sits. Empty when there is no texture.", "expression")
		.param_typed("Texture2D", "texture", "null", "Texture", "A picture to paint the shape with. null for plain colour.", "expression"))

	d.append(F.act("CanvasItemDrawString", "Draw Text", "draw_string({font}, {pos}, {text}{, alignment}{, width}{, font_size}{, modulate})", CAT,
		"Draw text [b]{text}[/b] at [b]{pos}[/b] in [b]{font}[/b]{?font_size}, size [b]{font_size}[/b]{/font_size}{?modulate}, [b]{modulate}[/b]{/modulate}",
		"Godot's draw_string: a line of text, drawn by this node. The position is the left end of the text's baseline. Only works under On Draw.", HOST)
		.param_typed("Font", "font", "ThemeDB.fallback_font", "Font", "The font to write with. ThemeDB.fallback_font is the one Godot always has.", "expression")
		.param_typed("Vector2", "pos", "Vector2(0, 16)", "Pos", "Where the text starts, at the left end of its baseline.", "expression")
		.param_typed("String", "text", "\"Hello\"", "Text", "What to write.", "expression")
		.param_typed("int", "alignment", "HORIZONTAL_ALIGNMENT_LEFT", "Alignment", "Where the text sits against its width. Godot's default is HORIZONTAL_ALIGNMENT_LEFT.", "expression")
		.param_typed("float", "width", "-1", "Width", "How wide the text may run before it is cut. Godot's default, -1, is no limit.", "expression")
		.param_typed("int", "font_size", "16", "Font size", "How big the text is. Godot's default is 16.", "expression")
		.param_typed("Color", "modulate", "Color.WHITE", "Modulate", "The text's colour. Godot's default is Color.WHITE.", "expression"))

	d.append(F.act("CanvasItemDrawTexture", "Draw Texture", "draw_texture({texture}, {position}{, modulate})", CAT,
		"Draw texture [b]{texture}[/b] at [b]{position}[/b]",
		"Godot's draw_texture: a picture at its own size, its top-left corner at a point, drawn by this node. Only works under On Draw.", HOST)
		.param_typed("Texture2D", "texture", "null", "Texture", "The picture to draw.", "expression")
		.param_typed("Vector2", "position", "Vector2(0, 0)", "Position", "Where the picture's top-left corner goes.", "expression")
		.param_built(_modulate()))

	d.append(F.act("CanvasItemDrawTextureRect", "Draw Texture Rect", "draw_texture_rect({texture}, {rect}, {tile}{, modulate}{, transpose})", CAT,
		"Draw texture [b]{texture}[/b] into [b]{rect}[/b]",
		"Godot's draw_texture_rect: a picture stretched, or tiled, to fill a rectangle, drawn by this node. Only works under On Draw.", HOST)
		.param_typed("Texture2D", "texture", "null", "Texture", "The picture to draw.", "expression")
		.param_built(_rect())
		.param_typed("bool", "tile", "false", "Tile", "True repeats the picture to fill the rectangle; false stretches it.", "expression")
		.param_built(_modulate())
		.param_typed("bool", "transpose", "false", "Transpose", "True swaps the picture's x and y. Godot's default is false.", "expression"))

	d.append(F.act("CanvasItemDrawTextureRectRegion", "Draw Texture Region", "draw_texture_rect_region({texture}, {rect}, {src_rect}{, modulate}{, transpose}{, clip_uv})", CAT,
		"Draw part [b]{src_rect}[/b] of texture [b]{texture}[/b] into [b]{rect}[/b]",
		"Godot's draw_texture_rect_region: one piece of a picture, stretched to fill a rectangle, drawn by this node - a frame of a sprite sheet. Only works under On Draw.", HOST)
		.param_typed("Texture2D", "texture", "null", "Texture", "The picture to take the piece from.", "expression")
		.param_built(_rect())
		.param_typed("Rect2", "src_rect", "Rect2(0, 0, 16, 16)", "Src rect", "The piece of the picture to draw, in the picture's own pixels.", "expression")
		.param_built(_modulate())
		.param_typed("bool", "transpose", "false", "Transpose", "True swaps the picture's x and y. Godot's default is false.", "expression")
		.param_typed("bool", "clip_uv", "true", "Clip UV", "Keeps the piece from bleeding into its neighbours. Godot's default is true.", "expression"))

	d.append(F.act("CanvasItemDrawSetTransform", "Set Draw Transform", "draw_set_transform({position}{, rotation}{, scale})", CAT,
		"Set draw transform to [b]{position}[/b]",
		"Godot's draw_set_transform: moves, turns and scales everything this node draws after it, until the next one. Call it with just a position to put the origin there. Only works under On Draw.", HOST)
		.param_typed("Vector2", "position", "Vector2(0, 0)", "Position", "Where the drawing origin moves to.", "expression")
		.param_typed("float", "rotation", "0.0", "Rotation", "How far to turn the drawing, in radians. Godot's default is 0.0.", "expression")
		.param_typed("Vector2", "scale", "Vector2(1, 1)", "Scale", "How much to scale the drawing. Godot's default is Vector2(1, 1).", "expression"))

	d.append(F.act("CanvasItemQueueRedraw", "Redraw", "queue_redraw()", CAT,
		"Redraw",
		"Godot's queue_redraw: asks the node to paint itself again, which runs its On Draw event. A node paints once and keeps the picture, so call this whenever what it should show has changed. Works anywhere.", HOST).featured())

	return d


static func _rect() -> ACEParam:
	return F.make_param("rect", "Rect2", "Rect2(0, 0, 64, 32)", "Rect", "The rectangle: its top-left corner, then its size.", "expression")


static func _color() -> ACEParam:
	return F.make_param("color", "Color", "Color.WHITE", "Color", "The colour to draw in.", "expression")


static func _modulate() -> ACEParam:
	return F.make_param("modulate", "Color", "Color.WHITE", "Modulate", "Tints the picture. Godot's default is Color.WHITE, no tint.", "expression")


static func _width(words: String) -> ACEParam:
	return F.make_param("width", "float", "-1.0", "Width", words + " Leave it out, with Antialiased, to draw with Godot's defaults.", "expression")


static func _antialiased() -> ACEParam:
	return F.make_param("antialiased", "bool", "false", "Antialiased", "True smooths the edge. Godot's default is false. A call can only give it after a width.", "expression")
