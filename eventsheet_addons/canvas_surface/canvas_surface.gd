@icon("res://eventsheet_addons/behavior.svg")
class_name CanvasSurface
extends Node2D
## Shared 2D drawing runtime for the Drawing Canvas behaviour and the Draw ACEs: an offscreen render target, a command queue, and self-updating ribbons. One per host, cached on the host - call CanvasSurface.for_node(host).

const META_KEY: String = "__canvas_surface"

var canvas_width: int = 512
var canvas_height: int = 512
var auto_clear: bool = false
var coordinates: String = "world"  # "world" (centered on the host) or "canvas" (raw texture pixels)
var display_on_host: bool = true

var _host: Node2D = null
var _viewport: SubViewport = null
var _drawer: Node2D = null
var _display: Sprite2D = null
var _commands: Array = []
var _ribbons: Array = []
## Returns the host's canvas surface, creating (and attaching) one on first use. Cached on the host
## via metadata, so every "... on {node}" draw shares one surface. Null-safe.
static func for_node(host: Node) -> CanvasSurface:
	if not (host is Node2D):
		return null
	var host_2d: Node2D = host as Node2D
	if host_2d.has_meta(META_KEY):
		var existing: Variant = host_2d.get_meta(META_KEY)
		if is_instance_valid(existing):
			return existing
	var surface: CanvasSurface = CanvasSurface.new()
	surface.name = "CanvasSurface"
	surface._host = host_2d
	host_2d.set_meta(META_KEY, surface)
	# Deferred: for_node commonly fires from the host's own child-setup (a behavior's On Ready), when a
	# direct add_child to the host is rejected as 'parent busy'. Draws buffer until the surface's _ready
	# builds the drawer and flushes them, so an On-Ready-time draw is not lost.
	host_2d.add_child.call_deferred(surface)
	return surface
# --- Public draw surface (called by the Drawing Canvas behaviour and the builtin Draw ACEs) ---
func texture() -> Texture2D:
	_ensure()
	return _viewport.get_texture() if _viewport != null else null
# --- Dashed shapes: ONE dash primitive turns any polyline into disjoint dash segments, drawn in a
# single draw_multiline call. Line = 2 points, ring = a sampled circle, rect = 4 closed corners - the
# same routine serves all three and any future dashed shape. ---
## Walks a polyline by arc length, carrying the dash phase across vertices so the rhythm stays
## continuous around ring and rect corners, and returns endpoint PAIRS for draw_multiline. dash_len
## is floored at 0.5 and gap at 0 so a zero-gap value degrades to a solid stroke, never an infinite loop.
static func _dash_polyline(points: PackedVector2Array, dash_len: float, gap_len: float) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	var d: float = maxf(dash_len, 0.5)
	var g: float = maxf(gap_len, 0.0)
	var period: float = d + g
	if points.size() < 2 or period <= 0.0:
		return out
	var phase: float = 0.0
	for i: int in range(points.size() - 1):
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		var seg: Vector2 = b - a
		var seg_len: float = seg.length()
		if seg_len <= 0.0001:
			continue
		var dir: Vector2 = seg / seg_len
		var t: float = 0.0
		while t < seg_len:
			var pos: float = fmod(phase + t, period)
			if pos < d:
				var t_end: float = minf(t + (d - pos), seg_len)
				out.append(a + dir * t)
				out.append(a + dir * t_end)
				t = t_end
			else:
				t += period - pos
		phase = fmod(phase + seg_len, period)
	return out

func configure(width: int, height: int, clear_each_frame: bool, coords: String, show_on_host: bool) -> void:
	canvas_width = width
	canvas_height = height
	auto_clear = clear_each_frame
	coordinates = coords
	display_on_host = show_on_host
	if _viewport != null:
		_viewport.size = Vector2i(maxi(canvas_width, 8), maxi(canvas_height, 8))
		_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS if auto_clear else SubViewport.CLEAR_MODE_NEVER

func _ready() -> void:
	set_physics_process(true)
	_ensure()

func _ensure() -> void:
	if _viewport != null or not is_inside_tree():
		return
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(maxi(canvas_width, 8), maxi(canvas_height, 8))
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS if auto_clear else SubViewport.CLEAR_MODE_NEVER
	add_child(_viewport)
	_drawer = Node2D.new()
	_viewport.add_child(_drawer)
	_drawer.draw.connect(_run_draw_commands)
	if display_on_host and _host != null:
		_display = Sprite2D.new()
		_display.texture = _viewport.get_texture()
		_host.add_child.call_deferred(_display)
	if not _commands.is_empty():
		_drawer.queue_redraw()  # flush draws buffered before the surface entered the tree

func to_canvas(point: Vector2) -> Vector2:
	if coordinates != "world" or _host == null:
		return point
	return point - _host.global_position + Vector2(canvas_width, canvas_height) * 0.5

func _run_draw_commands() -> void:
	for command: Dictionary in _commands:
		match str(command["kind"]):
			"line":
				_drawer.draw_line(command["a"], command["b"], command["color"], command["width"])
			"circle":
				_drawer.draw_circle(command["at"], command["radius"], command["color"])
			"ring":
				_drawer.draw_arc(command["at"], command["radius"], 0.0, TAU, 64, command["color"], command["width"])
			"rect":
				_drawer.draw_rect(command["rect"], command["color"])
			"polygon":
				_drawer.draw_colored_polygon(command["points"], command["color"])
			"multiline":
				_drawer.draw_multiline(command["points"], command["color"], command["width"])
			"stamp":
				var texture: Texture2D = command["texture"]
				if texture != null:
					_drawer.draw_set_transform(command["at"], command["rotation"], Vector2.ONE * float(command["scale"]))
					_drawer.draw_texture(texture, -texture.get_size() * 0.5)
					_drawer.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_commands.clear()

func _push(command: Dictionary) -> void:
	_ensure()
	_commands.append(command)  # buffered even before the drawer exists; _ensure flushes it
	if _drawer != null:
		_drawer.queue_redraw()

func clear() -> void:
	_ensure()
	_commands.clear()
	if _viewport != null and not auto_clear:
		_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ONCE
	if _drawer != null:
		_drawer.queue_redraw()

func set_auto_clear(enabled: bool) -> void:
	auto_clear = enabled
	if _viewport != null:
		_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS if enabled else SubViewport.CLEAR_MODE_NEVER

func set_display_visible(visible_now: bool) -> void:
	if _display != null:
		_display.visible = visible_now

func line(from_x: float, from_y: float, to_x: float, to_y: float, width: float, color: Color) -> void:
	_push({"kind": "line", "a": to_canvas(Vector2(from_x, from_y)), "b": to_canvas(Vector2(to_x, to_y)), "width": width, "color": color})

func circle(x: float, y: float, radius: float, color: Color) -> void:
	_push({"kind": "circle", "at": to_canvas(Vector2(x, y)), "radius": radius, "color": color})

func ring(x: float, y: float, radius: float, width: float, color: Color) -> void:
	_push({"kind": "ring", "at": to_canvas(Vector2(x, y)), "radius": radius, "width": width, "color": color})

func rect(x: float, y: float, width: float, height: float, color: Color) -> void:
	_push({"kind": "rect", "rect": Rect2(to_canvas(Vector2(x, y)), Vector2(width, height)), "color": color})

func cone(x: float, y: float, facing_deg: float, fov_deg: float, radius: float, color: Color) -> void:
	var center: Vector2 = to_canvas(Vector2(x, y))
	var points: PackedVector2Array = PackedVector2Array([center])
	for i: int in 33:
		var angle: float = deg_to_rad(facing_deg - fov_deg * 0.5 + fov_deg * float(i) / 32.0)
		points.append(center + Vector2.from_angle(angle) * radius)
	_push({"kind": "polygon", "points": points, "color": color})

func stamp(texture_res: Texture2D, x: float, y: float, scale_factor: float, rotation_deg: float) -> void:
	_push({"kind": "stamp", "texture": texture_res, "at": to_canvas(Vector2(x, y)), "scale": maxf(scale_factor, 0.01), "rotation": deg_to_rad(rotation_deg)})

func line_of_sight(origin_x: float, origin_y: float, facing_deg: float, fov_deg: float, max_range: float, collision_mask: int, color: Color) -> void:
	_ensure()
	if _host == null or not is_inside_tree() or _drawer == null:
		return
	var space: PhysicsDirectSpaceState2D = _host.get_world_2d().direct_space_state
	if space == null:
		return
	var origin: Vector2 = Vector2(origin_x, origin_y)
	var points: PackedVector2Array = PackedVector2Array([to_canvas(origin)])
	for i: int in 49:
		var angle: float = deg_to_rad(facing_deg - fov_deg * 0.5 + fov_deg * float(i) / 48.0)
		var direction: Vector2 = Vector2.from_angle(angle)
		var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(origin, origin + direction * max_range, collision_mask)
		if _host is CollisionObject2D:
			query.exclude = [(_host as CollisionObject2D).get_rid()]
		var hit: Dictionary = space.intersect_ray(query)
		var end_point: Vector2 = hit["position"] if not hit.is_empty() else origin + direction * max_range
		points.append(to_canvas(end_point))
	_push({"kind": "polygon", "points": points, "color": color})

func prefab(prefab_res: Resource, x: float, y: float, scale_factor: float, rotation_deg: float) -> void:
	if prefab_res == null:
		return
	# One expansion path fed by pre-typed entries (the resource's cached compiled_steps() when it
	# exposes one, else a raw parse) - the same circle/ring/rect/line/cone/stamp calls, minus the
	# per-step Color.from_string, so drawing a prefab 1000x per frame does not re-parse strings.
	var entries: Array = _prefab_entries(prefab_res)
	if entries.is_empty():
		return
	var origin: Vector2 = Vector2(x, y)
	var spin: float = deg_to_rad(rotation_deg)
	var scale_by: float = maxf(scale_factor, 0.01)
	for entry: Dictionary in entries:
		var local: Vector2 = Vector2(entry["x"], entry["y"])
		var at: Vector2 = origin + (local * scale_by).rotated(spin)
		var p1: float = entry["p1"]
		var p2: float = entry["p2"]
		var p3: float = entry["p3"]
		var tint: Color = entry["color"]
		match str(entry["kind"]):
			"circle":
				circle(at.x, at.y, p1 * scale_by, tint)
			"ring":
				ring(at.x, at.y, p1 * scale_by, maxf(p2 * scale_by, 1.0), tint)
			"rect":
				var corners: PackedVector2Array = PackedVector2Array()
				for corner: Vector2 in [Vector2.ZERO, Vector2(p1, 0.0), Vector2(p1, p2), Vector2(0.0, p2)]:
					corners.append(to_canvas(origin + ((local + corner) * scale_by).rotated(spin)))
				_push({"kind": "polygon", "points": corners, "color": tint})
			"line":
				var to_point: Vector2 = origin + (Vector2(p1, p2) * scale_by).rotated(spin)
				line(at.x, at.y, to_point.x, to_point.y, maxf(p3 * scale_by, 1.0), tint)
			"cone":
				cone(at.x, at.y, p1 + rotation_deg, p2, p3 * scale_by, tint)
			"stamp":
				var texture: Texture2D = entry["tex"]
				if texture != null:
					stamp(texture, at.x, at.y, maxf(p1, 0.01) * scale_by, p2 + rotation_deg)

func _prefab_entries(prefab_res: Resource) -> Array:
	if prefab_res.has_method("compiled_steps"):
		var compiled: Variant = prefab_res.compiled_steps()
		if compiled is Array:
			return compiled
	var raw: Variant = prefab_res.get("steps")
	if not (raw is Array):
		return []
	return DrawingPrefabResource.compile_steps(raw)

func _push_dashes(points: PackedVector2Array, dash_length: float, gap_length: float, width: float, color: Color) -> void:
	var segments: PackedVector2Array = _dash_polyline(points, dash_length, gap_length)
	if segments.is_empty():
		return
	_push({"kind": "multiline", "points": segments, "color": color, "width": maxf(width, 0.5)})

func dashed_line(from_x: float, from_y: float, to_x: float, to_y: float, dash_length: float, gap_length: float, width: float, color: Color) -> void:
	_push_dashes(PackedVector2Array([to_canvas(Vector2(from_x, from_y)), to_canvas(Vector2(to_x, to_y))]), dash_length, gap_length, width, color)

func dashed_ring(x: float, y: float, radius: float, dash_length: float, gap_length: float, width: float, color: Color) -> void:
	var center: Vector2 = to_canvas(Vector2(x, y))
	var points: PackedVector2Array = PackedVector2Array()
	for i: int in 65:
		points.append(center + Vector2.from_angle(TAU * float(i) / 64.0) * radius)
	_push_dashes(points, dash_length, gap_length, width, color)

func dashed_rect(x: float, y: float, width: float, height: float, dash_length: float, gap_length: float, line_width: float, color: Color) -> void:
	var o: Vector2 = Vector2(x, y)
	var corners: PackedVector2Array = PackedVector2Array([to_canvas(o), to_canvas(o + Vector2(width, 0.0)), to_canvas(o + Vector2(width, height)), to_canvas(o + Vector2(0.0, height)), to_canvas(o)])
	_push_dashes(corners, dash_length, gap_length, line_width, color)

func start_ribbon(follow: Node, point_count: int, width: float, color: Color) -> void:
	_ensure()
	if _drawer == null or not (follow is Node2D):
		return
	stop_ribbon(follow)
	var ribbon_line: Line2D = Line2D.new()
	ribbon_line.width = width
	ribbon_line.default_color = color
	ribbon_line.joint_mode = Line2D.LINE_JOINT_ROUND
	ribbon_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	ribbon_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	_drawer.add_child(ribbon_line)
	_ribbons.append({"id": follow.get_instance_id(), "line": ribbon_line, "trail": [], "length": maxi(point_count, 2)})

func set_ribbon_texture(follow: Node, texture_res: Texture2D) -> void:
	# --- Ribbons: Line2D children refreshed every physics frame - this update runs HERE, so the
	# behaviour no longer carries a per-frame GDScript loop. ---
	if follow == null:
		return
	for ribbon: Dictionary in _ribbons:
		if int(ribbon["id"]) == follow.get_instance_id() and is_instance_valid(ribbon["line"]):
			(ribbon["line"] as Line2D).texture = texture_res
			(ribbon["line"] as Line2D).texture_mode = Line2D.LINE_TEXTURE_STRETCH

func stop_ribbon(follow: Node) -> void:
	if follow == null:
		return
	var kept: Array = []
	for ribbon: Dictionary in _ribbons:
		if int(ribbon["id"]) == follow.get_instance_id():
			if is_instance_valid(ribbon["line"]):
				(ribbon["line"] as Line2D).queue_free()
		else:
			kept.append(ribbon)
	_ribbons = kept

func _physics_process(_delta: float) -> void:
	if _ribbons.is_empty() or _drawer == null:
		return
	var kept: Array = []
	for ribbon: Dictionary in _ribbons:
		var followed: Node2D = instance_from_id(int(ribbon["id"])) as Node2D
		var ribbon_line: Line2D = ribbon["line"]
		if followed == null or not is_instance_valid(ribbon_line):
			if is_instance_valid(ribbon_line):
				ribbon_line.queue_free()
			continue
		kept.append(ribbon)
		var trail: Array = ribbon["trail"]
		trail.append(followed.global_position)
		while trail.size() > int(ribbon["length"]):
			trail.pop_front()
		var mapped: PackedVector2Array = PackedVector2Array()
		for point: Variant in trail:
			mapped.append(to_canvas(point))
		ribbon_line.points = mapped
	_ribbons = kept
