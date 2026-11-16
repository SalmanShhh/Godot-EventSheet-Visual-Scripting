## @ace_version(1.0.0)
@icon("res://eventsheet_addons/drawing_prefab_resource/icon.svg")
class_name DrawingPrefabResource
extends Resource
## A reusable drawing: an ordered grid of shape steps replayed by the Drawing Canvas's Draw Prefab action at any position, scale, and rotation. Fill the steps grid in the Inspector and save as a .tres.

## A label for your own reference (the canvas does not read it).
@export var prefab_name: String = "marker"
## The shapes drawn top to bottom: kind, offset and size values for each.
@export_custom(PROPERTY_HINT_NONE, "eventsheet:table:kind=enum(circle|ring|rect|line|cone|stamp),x=float,y=float,p1=float,p2=float,p3=float,color=color,texture=String") var steps: Array = []

# Runtime only (not
# exported, so never serialized). Read ONLY on the main thread (the draw paths); the off-thread
# thumbnail rasterizer reads the raw steps instead and never calls this.
## Steps pre-parsed for drawing, cached until the resource changes.
var _compiled: Array = []
## True when the compiled strokes match the current settings.
var _compiled_valid: bool = false
## Size the strokes were last compiled for; -1 until compiled.
var _compiled_size: int = -1

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
## of a line, its dash pattern, and whether its thickness follows the stamp's scale - and a step
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
			"dashed": bool(entry.get("dashed", false)),
			"dash_size": float(entry.get("dash_size", 8.0)),
			"dash_spacing": float(entry.get("dash_spacing", 6.0)),
			"dash_offset": float(entry.get("dash_offset", 0.0)),
			"dash_style": str(entry.get("dash_style", "plain")),
		})
	return out
