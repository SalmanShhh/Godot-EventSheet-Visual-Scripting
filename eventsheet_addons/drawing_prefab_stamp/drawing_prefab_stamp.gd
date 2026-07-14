@tool
## @ace_tags(drawing, visual)
## @ace_category("Drawing Canvas")
@icon("res://eventsheet_addons/behavior.svg")
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
				canvas.draw_line(at, at + Vector2(p1, p2), tint, maxf(p3, 1.0))
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

func _draw() -> void:
	draw_prefab_steps(self, prefab, Vector2.ZERO, prefab_scale, prefab_rotation)
