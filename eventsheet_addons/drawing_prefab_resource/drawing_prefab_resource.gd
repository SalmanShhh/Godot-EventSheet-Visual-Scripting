## @ace_version(1.0.0)
@icon("res://eventsheet_addons/drawing_prefab_resource/icon.svg")
class_name DrawingPrefabResource
extends Resource
## A reusable drawing: an ordered grid of shape steps replayed by the Drawing Canvas's Draw Prefab action at any position, scale, and rotation. Fill the steps grid in the Inspector and save as a .tres.

## A label for your own reference (the canvas does not read it).
@export var prefab_name: String = "marker"
## The shapes drawn top to bottom: kind, offset and size values for each.
@export_custom(PROPERTY_HINT_NONE, "eventsheet:table:kind=enum(circle|ring|rect|line|cone|stamp|arc|pie|rounded_rect|regular_polygon),x=float,y=float,p1=float,p2=float,p3=float,color=color,texture=String") var steps: Array = []

# Runtime only (not
# exported, so never serialized). Read ONLY on the main thread (the draw paths); the off-thread
# thumbnail rasterizer reads the raw steps instead and never calls this.
## Steps pre-parsed for drawing, cached until the resource changes.
var _compiled: Array = []
## True when the compiled strokes match the current settings.
var _compiled_valid: bool = false
## Size the strokes were last compiled for; -1 until compiled.
var _compiled_size: int = -1
## The transform a stamp step is drawn under, in the prefab's own space: its offset, turned by its Spin
## (degrees, about its centre). The stamp node draws every stamp under this, as Draw Prefab turns one.
static func stamp_frame(entry: Dictionary) -> Transform2D:
	return Transform2D(deg_to_rad(float(entry.get("p2", 0.0))), Vector2(float(entry.get("x", 0.0)), float(entry.get("y", 0.0))))

## Returns steps pre-parsed to typed entries {kind, x, y, p1, p2, p3, color: Color, tex: Texture2D},
## building and caching on first call and after any change. The size guard also rebuilds when steps
## are appended or removed at runtime; an in-place value edit needs emit_changed() (the Inspector
## does this automatically on every cell edit).
func compiled_steps() -> Array:
	if not changed.is_connected(_invalidate_compiled):
		changed.connect(_invalidate_compiled)
	if _compiled_valid and _compiled_size == steps.size():
		return _compiled
	_compiled = compile_steps(steps)
	_compiled_size = steps.size()
	_compiled_valid = true
	return _compiled

func _invalidate_compiled() -> void:
	_compiled_valid = false
	_compiled = []

## A line step's two points, both in the prefab's own space: where it starts (its offset) and where
## it ends (its End, measured from the prefab's origin, not from the offset). Every renderer takes
## the span from here so a line ends at the same point in the game, the viewport and the Inspector.
## Works on a raw step and on a compiled entry alike.
static func line_span(entry: Dictionary) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(float(entry.get("x", 0.0)), float(entry.get("y", 0.0))),
		Vector2(float(entry.get("p1", 0.0)), float(entry.get("p2", 0.0))),
	])

## The outline of a step drawn as a polygon or a stroke - an arc, a pie, a rounded rectangle or a regular
## polygon - as points in the prefab's own space. The stamp node, Draw Prefab and the Inspector picture
## all draw these four from the same rules, so a shape is one picture wherever it is seen. An arc is the
## points of its stroke (a polyline); the other three are closed shapes (a polygon). A step that would
## draw nothing (no radius, no sweep, no width, no size) answers an empty list. Works on a raw step and
## on a compiled entry alike.
##
##   arc, pie           p1 radius, p2 start angle, p3 end angle (degrees, 0 = right, growing clockwise on
##                      screen). The sweep runs from the start to the end, backwards when the end is below
##                      the start, and is held to one full turn.
##   rounded_rect       p1 width, p2 height, p3 corner radius, placed right and down from the offset like
##                      a Rectangle; corners larger than half the short side are held to half of it.
##   regular_polygon    p1 radius (centre to corner), p2 sides (3 to 32), p3 angle of the first corner.
## @ace_hidden
static func shape_outline(entry: Dictionary) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	var at: Vector2 = Vector2(float(entry.get("x", 0.0)), float(entry.get("y", 0.0)))
	var p1: float = float(entry.get("p1", 0.0))
	var p2: float = float(entry.get("p2", 0.0))
	var p3: float = float(entry.get("p3", 0.0))
	var kind: String = str(entry.get("kind", ""))
	match kind:
		"arc", "pie":
			var start: float = deg_to_rad(p2)
			var sweep: float = clampf(deg_to_rad(p3) - start, -TAU, TAU)
			if p1 <= 0.0 or absf(sweep) < 0.0005:
				return out
			var segments: int = maxi(ceili(absf(sweep) / TAU * 48.0), 2)
			if kind == "pie":
				out.append(at)
			# A pie turned all the way round would end on the point it began at: it keeps one of the two.
			var rim: int = segments if kind == "pie" and absf(sweep) >= TAU - 0.0005 else segments + 1
			for step: int in rim:
				out.append(at + Vector2.from_angle(start + sweep * float(step) / float(segments)) * p1)
		"rounded_rect":
			var box: Rect2 = Rect2(at, Vector2(p1, p2)).abs()
			if box.size.x <= 0.0 or box.size.y <= 0.0:
				return out
			var radius: float = clampf(p3, 0.0, minf(box.size.x, box.size.y) * 0.5)
			if radius < 0.01:
				return PackedVector2Array([box.position, Vector2(box.end.x, box.position.y), box.end, Vector2(box.position.x, box.end.y)])
			var inner: Rect2 = box.grow(-radius)
			var centres: Array[Vector2] = [inner.end, Vector2(inner.position.x, inner.end.y), inner.position, Vector2(inner.end.x, inner.position.y)]
			for quadrant: int in 4:
				for step: int in 7:
					out.append(centres[quadrant] + Vector2.from_angle(PI * 0.5 * (float(quadrant) + float(step) / 6.0)) * radius)
		"regular_polygon":
			var sides: int = clampi(roundi(p2), 3, 32)
			if p1 <= 0.0:
				return out
			for corner: int in sides:
				out.append(at + Vector2.from_angle(deg_to_rad(p3) + TAU * float(corner) / float(sides)) * p1)
	return out

## One line step's stroke: its ends, and its dash pattern when it has one. A step that says
## neither draws the single plain line it always drew, so an older prefab is untouched.
## @ace_hidden
static func draw_stroke(canvas: CanvasItem, from: Vector2, to: Vector2, width: float, tint: Color, entry: Dictionary) -> void:
	if not bool(entry.get("dashed", false)):
		draw_capped(canvas, from, to, width, tint, str(entry.get("caps", "none")))
		return
	var span: float = from.distance_to(to)
	if span <= 0.001:
		return
	var direction: Vector2 = (to - from) / span
	var dash: float = maxf(float(entry.get("dash_size", 8.0)), 0.5)
	var period: float = dash + maxf(float(entry.get("dash_spacing", 6.0)), 0.0)
	var style: String = str(entry.get("dash_style", "plain"))
	# Whole periods of offset land where they started, so a scrolled pattern never jumps.
	var along: float = -fposmod(float(entry.get("dash_offset", 0.0)) * period, period)
	while along < span:
		var starts: float = maxf(along, 0.0)
		var ends: float = minf(along + dash, span)
		if ends > starts:
			if style == "angled":
				draw_leaning_dash(canvas, from, direction, starts, ends, width, tint)
			else:
				draw_capped(canvas, from + direction * starts, from + direction * ends, width, tint, "round" if style == "rounded" else "none")
		along += period

## One straight run with its ends: cut square at the point (none), half a width past it
## (square), or rounded off with a disc at each end (round).
## @ace_hidden
static func draw_capped(canvas: CanvasItem, from: Vector2, to: Vector2, width: float, tint: Color, caps: String) -> void:
	var line_from: Vector2 = from
	var line_to: Vector2 = to
	if caps == "square" and from.distance_to(to) > 0.001:
		var reach: Vector2 = (to - from).normalized() * width * 0.5
		line_from -= reach
		line_to += reach
	canvas.draw_line(line_from, line_to, tint, width)
	if caps == "round":
		canvas.draw_circle(from, width * 0.5, tint)
		canvas.draw_circle(to, width * 0.5, tint)

## One angled dash: the same run leaning over by half a width, drawn as the parallelogram it
## is - which is what makes a row of them read as a slant rather than as ticks.
## @ace_hidden
static func draw_leaning_dash(canvas: CanvasItem, from: Vector2, direction: Vector2, starts: float, ends: float, width: float, tint: Color) -> void:
	var half: float = width * 0.5
	var side: Vector2 = Vector2(-direction.y, direction.x) * half
	canvas.draw_colored_polygon(PackedVector2Array([
		from + direction * (starts - half) + side,
		from + direction * (ends - half) + side,
		from + direction * (ends + half) - side,
		from + direction * (starts + half) - side,
	]), tint)

## Parses raw steps (Dictionaries of strings) into typed entries - colors parsed once, stamp
## textures loaded once (main thread). The renderers use the SAME shape for their generic-Resource
## fallback, so a cached draw and an uncached draw are identical.
##
## The eight stored keys (kind, x, y, p1, p2, p3, color, texture) mean exactly what they always
## did. Beside them a step may carry the optional look keys the Inspector card writes - the ends
## of a line, its dash pattern, an arc's thickness, and whether a stroke's thickness follows the stamp's scale - and a step
## that carries none of them compiles to the values it always drew with.
static func compile_steps(raw: Array) -> Array:
	var out: Array = []
	for step: Variant in raw:
		if not (step is Dictionary):
			continue
		var entry: Dictionary = step
		var kind: String = str(entry.get("kind", ""))
		var tex: Texture2D = null
		if kind == "stamp":
			var texture_path: String = str(entry.get("texture", "")).strip_edges()
			if not texture_path.is_empty() and ResourceLoader.exists(texture_path):
				tex = load(texture_path) as Texture2D
		out.append({
			"kind": kind,
			"x": float(entry.get("x", 0.0)),
			"y": float(entry.get("y", 0.0)),
			"p1": float(entry.get("p1", 0.0)),
			"p2": float(entry.get("p2", 0.0)),
			"p3": float(entry.get("p3", 0.0)),
			"color": Color.from_string(str(entry.get("color", "white")), Color.WHITE),
			"tex": tex,
			"caps": str(entry.get("caps", "none")),
			"scale_mode": str(entry.get("scale_mode", "uniform")),
			"thickness": float(entry.get("thickness", 2.0)),
			"dashed": bool(entry.get("dashed", false)),
			"dash_size": float(entry.get("dash_size", 8.0)),
			"dash_spacing": float(entry.get("dash_spacing", 6.0)),
			"dash_offset": float(entry.get("dash_offset", 0.0)),
			"dash_style": str(entry.get("dash_style", "plain")),
		})
	return out
