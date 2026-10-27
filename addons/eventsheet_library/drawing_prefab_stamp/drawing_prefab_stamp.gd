@tool
## @ace_tags(drawing, visual)
## @ace_category("Drawing Canvas")
## @ace_requires(DrawingPrefabResource)
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/drawing_prefab_stamp/icon.svg")
class_name DrawingPrefabStamp
extends Node2D
## Draws a DrawingPrefabResource in the 2D viewport (editor and game) - a placeable, previewable stamp of a prefab formation.

## The formation to draw. Fill its steps grid in the Inspector - a live preview appears here and on the node.
@export var prefab: DrawingPrefabResource = null:
	set(value):
		if prefab != null and prefab.changed.is_connected(queue_redraw):
			prefab.changed.disconnect(queue_redraw)
		prefab = value
		if prefab != null and not prefab.changed.is_connected(queue_redraw):
			prefab.changed.connect(queue_redraw)
		queue_redraw()
## Uniform scale applied to the whole formation.
@export var prefab_scale: float = 1.0:
	set(value):
		prefab_scale = value
		queue_redraw()
## Rotation of the whole formation, in degrees.
@export var prefab_rotation: float = 0.0:
	set(value):
		prefab_rotation = value
		queue_redraw()

func _draw() -> void:
	draw_prefab_steps(self, prefab, Vector2.ZERO, prefab_scale, prefab_rotation)

## Draws a DrawingPrefabResource's ordered steps onto any CanvasItem at an origin, scaled and
## rotated as one - the shared vector renderer for the stamp node and the DrawingCanvas preview
## gizmo. Sets the canvas transform once so every step draws in prefab-local space.
## @ace_hidden
static func draw_prefab_steps(canvas: CanvasItem, prefab_res: Resource, origin: Vector2, scale_by: float, rotation_deg: float) -> void:
	if prefab_res == null:
		return
	# One draw path fed by pre-typed entries: the resource's cached compiled_steps() when available,
	# else a raw parse of a generic Resource's steps (same shape). Colors and kinds are already parsed,
	# so 1000+ stamps sharing a prefab never re-run Color.from_string per draw.
	var entries: Array = _prefab_entries(prefab_res)
	if entries.is_empty():
		return
	canvas.draw_set_transform(origin, deg_to_rad(rotation_deg), Vector2.ONE * maxf(scale_by, 0.001))
	for entry: Dictionary in entries:
		var at: Vector2 = Vector2(entry["x"], entry["y"])
		var p1: float = entry["p1"]
		var p2: float = entry["p2"]
		var p3: float = entry["p3"]
		var tint: Color = entry["color"]
		match str(entry["kind"]):
			"circle":
				canvas.draw_circle(at, maxf(p1, 0.5), tint)
			"ring":
				canvas.draw_arc(at, maxf(p1, 0.5), 0.0, TAU, 48, tint, maxf(p2, 1.0))
			"rect":
				canvas.draw_rect(Rect2(at, Vector2(p1, p2)), tint)
			"line":
				var width: float = maxf(p3, 1.0)
				if str(entry.get("scale_mode", "uniform")) == "fixed":
					width /= maxf(scale_by, 0.001)
				draw_stroke(canvas, at, at + Vector2(p1, p2), width, tint, entry)
			"cone":
				var points: PackedVector2Array = PackedVector2Array([at])
				for i: int in 25:
					var angle: float = deg_to_rad(p1 - p2 * 0.5 + p2 * float(i) / 24.0)
					points.append(at + Vector2.from_angle(angle) * maxf(p3, 0.5))
				canvas.draw_colored_polygon(points, tint)
			"stamp":
				var texture: Texture2D = entry["tex"]
				if texture != null:
					canvas.draw_texture_rect(texture, Rect2(at - texture.get_size() * maxf(p1, 0.01) * 0.5, texture.get_size() * maxf(p1, 0.01)), false, tint)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

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

## Typed draw entries for a prefab: the resource's cached compiled_steps() (parsed once, shared by
## every stamp) when it exposes one, else a raw parse of any Resource's steps into the same shape -
## so the draw loop above is a single path and the generic "any Resource with steps" contract holds.
## @ace_hidden
static func _prefab_entries(prefab_res: Resource) -> Array:
	if prefab_res.has_method("compiled_steps"):
		var compiled: Variant = prefab_res.compiled_steps()
		if compiled is Array:
			return compiled
	var steps: Variant = prefab_res.get("steps")
	if not (steps is Array):
		return []
	return DrawingPrefabResource.compile_steps(steps)
