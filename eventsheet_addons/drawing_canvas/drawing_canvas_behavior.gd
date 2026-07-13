## @ace_tags(drawing, visual)
## @ace_category("Drawing Canvas")
@icon("res://eventsheet_addons/behavior.svg")
class_name DrawingCanvas
extends Node

## The node this behavior acts on (its parent). Required host: Node2D.
var host: Node2D = null

func _enter_tree() -> void:
	host = get_parent() as Node2D
	if host == null:
		push_warning("DrawingCanvas behavior requires a Node2D parent.")

# --- Designer knobs (tune in the Inspector) ---
## Canvas texture width in pixels.
@export var canvas_width: int = 512
## Canvas texture height in pixels.
@export var canvas_height: int = 512
## On: the canvas clears itself every frame - re-issue draw verbs each tick (vision
## cones, telegraphs). Off: strokes accumulate until Clear Canvas (paint, splats).
@export var auto_clear: bool = false
## How draw coordinates are read: world = scene positions (the canvas is centered on
## the host and follows it); canvas = raw pixels on the texture (0,0 = top-left).
@export_enum("world", "canvas") var coordinates: String = "world"
## Show the canvas on the host (a centered Sprite2D child). Off: the canvas renders
## offscreen and you place Canvas Texture wherever you want it.
@export var display_on_host: bool = true

# --- Internal state ---
var _canvas_viewport: SubViewport = null
var _drawer: Node2D = null
var _display: Sprite2D = null
var _commands: Array = []
var _ribbons: Array = []
## The canvas's LIVE texture - assign it to a TextureRect, a material, a particle, or a
## 3D Decal (the Decal Painter pack accepts it directly). Updates as the canvas draws.
## @ace_expression
## @ace_name("Canvas Texture")
func canvas_texture() -> Texture2D:
	_ensure_canvas()
	return _canvas_viewport.get_texture() if _canvas_viewport != null else null

func _ready() -> void:
	_ensure_canvas()

func _physics_process(delta: float) -> void:
	if _ribbons.is_empty() or _drawer == null:
		return
	var kept: Array = []
	for ribbon: Dictionary in _ribbons:
		var followed: Node2D = instance_from_id(int(ribbon["id"])) as Node2D
		var line: Line2D = ribbon["line"]
		if followed == null or not is_instance_valid(line):
			if is_instance_valid(line):
				line.queue_free()
			continue
		kept.append(ribbon)
		var trail: Array = ribbon["trail"]
		trail.append(followed.global_position)
		while trail.size() > int(ribbon["length"]):
			trail.pop_front()
		# Trail points are stored in WORLD space and mapped fresh each frame - the canvas
		# follows the host, so old points must re-map against the host's current position.
		var mapped: PackedVector2Array = PackedVector2Array()
		for point: Variant in trail:
			mapped.append(_to_canvas(point))
		line.points = mapped

## @ace_hidden
func _ensure_canvas() -> void:
	if _canvas_viewport != null or not is_inside_tree():
		return
	_canvas_viewport = SubViewport.new()
	_canvas_viewport.size = Vector2i(maxi(canvas_width, 8), maxi(canvas_height, 8))
	_canvas_viewport.transparent_bg = true
	_canvas_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_canvas_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS if auto_clear else SubViewport.CLEAR_MODE_NEVER
	add_child(_canvas_viewport)
	_drawer = Node2D.new()
	_canvas_viewport.add_child(_drawer)
	_drawer.draw.connect(_run_draw_commands)
	if display_on_host and host is Node2D:
		_display = Sprite2D.new()
		_display.texture = _canvas_viewport.get_texture()
		# Deferred: at On Ready the host is still mid-setup and a direct add_child on
		# the PARENT is rejected ("parent busy setting up children").
		(host as Node2D).add_child.call_deferred(_display)

## @ace_hidden
func _to_canvas(point: Vector2) -> Vector2:
	if coordinates != "world" or not (host is Node2D):
		return point
	return point - (host as Node2D).global_position + Vector2(canvas_width, canvas_height) * 0.5

## @ace_hidden
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
			"stamp":
				var texture: Texture2D = command["texture"]
				if texture != null:
					_drawer.draw_set_transform(command["at"], command["rotation"], Vector2.ONE * float(command["scale"]))
					_drawer.draw_texture(texture, -texture.get_size() * 0.5)
					_drawer.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_commands.clear()

## @ace_condition
## @ace_name("Is Auto Clear")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$DrawingCanvas.is_auto_clear()")
func is_auto_clear() -> bool:
	return auto_clear

## @ace_hidden
func _push_command(command: Dictionary) -> void:
	_ensure_canvas()
	if _drawer == null:
		return
	_commands.append(command)
	_drawer.queue_redraw()

## @ace_action
## @ace_name("Clear Canvas")
## @ace_description("Wipes the canvas. In persistent mode the wipe happens on the next frame and the canvas keeps strokes again afterwards.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$DrawingCanvas.clear_canvas()")
func clear_canvas() -> void:
	_ensure_canvas()
	_commands.clear()
	if _canvas_viewport != null and not auto_clear:
		_canvas_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ONCE
	if _drawer != null:
		_drawer.queue_redraw()

## @ace_action
## @ace_name("Set Auto Clear")
## @ace_description("On: the canvas wipes itself every frame (re-issue draws each tick - vision cones, telegraphs). Off: strokes stay until Clear Canvas (paint, splats, skid marks).")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$DrawingCanvas.set_auto_clear({enabled})")
func set_auto_clear(enabled: bool) -> void:
	auto_clear = enabled
	if _canvas_viewport != null:
		_canvas_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS if enabled else SubViewport.CLEAR_MODE_NEVER

## @ace_action
## @ace_name("Set Canvas Visible")
## @ace_description("Shows or hides the canvas display on the host.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$DrawingCanvas.set_canvas_visible({visible_now})")
func set_canvas_visible(visible_now: bool) -> void:
	if _display != null:
		_display.visible = visible_now

## @ace_action
## @ace_name("Draw Line")
## @ace_description("Draws a line segment - attack direction indicators, lasers, aim guides.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$DrawingCanvas.draw_canvas_line({from_x}, {from_y}, {to_x}, {to_y}, {width}, {color})")
func draw_canvas_line(from_x: float, from_y: float, to_x: float, to_y: float, width: float, color: Color) -> void:
	_push_command({"kind": "line", "a": _to_canvas(Vector2(from_x, from_y)), "b": _to_canvas(Vector2(to_x, to_y)), "width": width, "color": color})

## @ace_action
## @ace_name("Draw Circle")
## @ace_description("Draws a filled circle - the classic soft blob shadow under a character.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$DrawingCanvas.draw_canvas_circle({x}, {y}, {radius}, {color})")
func draw_canvas_circle(x: float, y: float, radius: float, color: Color) -> void:
	_push_command({"kind": "circle", "at": _to_canvas(Vector2(x, y)), "radius": radius, "color": color})

## @ace_action
## @ace_name("Draw Ring")
## @ace_description("Draws a circle outline - selection rings, blast-radius previews.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$DrawingCanvas.draw_canvas_ring({x}, {y}, {radius}, {width}, {color})")
func draw_canvas_ring(x: float, y: float, radius: float, width: float, color: Color) -> void:
	_push_command({"kind": "ring", "at": _to_canvas(Vector2(x, y)), "radius": radius, "width": width, "color": color})

## @ace_action
## @ace_name("Draw Rect")
## @ace_description("Draws a filled rectangle (x/y = top-left corner).")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$DrawingCanvas.draw_canvas_rect({x}, {y}, {width}, {height}, {color})")
func draw_canvas_rect(x: float, y: float, width: float, height: float, color: Color) -> void:
	_push_command({"kind": "rect", "rect": Rect2(_to_canvas(Vector2(x, y)), Vector2(width, height)), "color": color})

## @ace_action
## @ace_name("Draw Cone")
## @ace_description("Draws a filled wedge - the attack-telegraph cone (pair with Auto Clear so it follows the attacker every frame).")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$DrawingCanvas.draw_canvas_cone({x}, {y}, {facing_deg}, {fov_deg}, {radius}, {color})")
func draw_canvas_cone(x: float, y: float, facing_deg: float, fov_deg: float, radius: float, color: Color) -> void:
	var center: Vector2 = _to_canvas(Vector2(x, y))
	var points: PackedVector2Array = PackedVector2Array([center])
	for i: int in 33:
		var angle: float = deg_to_rad(facing_deg - fov_deg * 0.5 + fov_deg * float(i) / 32.0)
		points.append(center + Vector2.from_angle(angle) * radius)
	_push_command({"kind": "polygon", "points": points, "color": color})

## @ace_action
## @ace_name("Draw Stamp")
## @ace_description("Stamps a texture onto the canvas - bullet holes, footprints, splats. In persistent mode stamps pile up like decals.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$DrawingCanvas.draw_canvas_stamp({texture}, {x}, {y}, {scale_factor}, {rotation_deg})")
func draw_canvas_stamp(texture: Texture2D, x: float, y: float, scale_factor: float, rotation_deg: float) -> void:
	_push_command({"kind": "stamp", "texture": texture, "at": _to_canvas(Vector2(x, y)), "scale": maxf(scale_factor, 0.01), "rotation": deg_to_rad(rotation_deg)})

## @ace_action
## @ace_name("Draw Line Of Sight")
## @ace_description("Draws a character's LINE OF SIGHT as a filled fan: rays cast against the collision mask stop at walls, so the shape hugs the level exactly. Re-issue each tick with Auto Clear on for a live vision cone. Origin and range are WORLD coordinates.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$DrawingCanvas.draw_line_of_sight({origin_x}, {origin_y}, {facing_deg}, {fov_deg}, {max_range}, {collision_mask}, {color})")
func draw_line_of_sight(origin_x: float, origin_y: float, facing_deg: float, fov_deg: float, max_range: float, collision_mask: int, color: Color) -> void:
	_ensure_canvas()
	if host == null or not is_inside_tree() or _drawer == null:
		return
	var space: PhysicsDirectSpaceState2D = (host as Node2D).get_world_2d().direct_space_state if host is Node2D else null
	if space == null:
		return
	var origin: Vector2 = Vector2(origin_x, origin_y)
	var points: PackedVector2Array = PackedVector2Array([_to_canvas(origin)])
	for i: int in 49:
		var angle: float = deg_to_rad(facing_deg - fov_deg * 0.5 + fov_deg * float(i) / 48.0)
		var direction: Vector2 = Vector2.from_angle(angle)
		var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(origin, origin + direction * max_range, collision_mask)
		if host is CollisionObject2D:
			query.exclude = [(host as CollisionObject2D).get_rid()]
		var hit: Dictionary = space.intersect_ray(query)
		var end_point: Vector2 = hit["position"] if not hit.is_empty() else origin + direction * max_range
		points.append(_to_canvas(end_point))
	_push_command({"kind": "polygon", "points": points, "color": color})

## @ace_action
## @ace_name("Draw Prefab")
## @ace_description("Replays a DrawingPrefabResource's steps IN ORDER at a position, scaled and rotated - author a target marker or scorch formation once as a .tres, stamp it everywhere.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$DrawingCanvas.draw_prefab({prefab}, {x}, {y}, {scale_factor}, {rotation_deg})")
func draw_prefab(prefab: Resource, x: float, y: float, scale_factor: float, rotation_deg: float) -> void:
	if prefab == null:
		return
	var steps: Variant = prefab.get("steps")
	if not (steps is Array):
		return
	var origin: Vector2 = Vector2(x, y)
	var spin: float = deg_to_rad(rotation_deg)
	var scale_by: float = maxf(scale_factor, 0.01)
	for step: Variant in steps:
		if not (step is Dictionary):
			continue
		var entry: Dictionary = step
		var at: Vector2 = origin + (Vector2(float(entry.get("x", 0.0)), float(entry.get("y", 0.0))) * scale_by).rotated(spin)
		var p1: float = float(entry.get("p1", 0.0))
		var p2: float = float(entry.get("p2", 0.0))
		var p3: float = float(entry.get("p3", 0.0))
		var tint: Color = Color.from_string(str(entry.get("color", "white")), Color.WHITE)
		match str(entry.get("kind", "")):
			"circle":
				draw_canvas_circle(at.x, at.y, p1 * scale_by, tint)
			"ring":
				draw_canvas_ring(at.x, at.y, p1 * scale_by, maxf(p2 * scale_by, 1.0), tint)
			"rect":
				# Rects rotate with the prefab: the four corners transform into a polygon.
				var corners: PackedVector2Array = PackedVector2Array()
				for corner: Vector2 in [Vector2.ZERO, Vector2(p1, 0.0), Vector2(p1, p2), Vector2(0.0, p2)]:
					corners.append(_to_canvas(origin + ((Vector2(float(entry.get("x", 0.0)), float(entry.get("y", 0.0))) + corner) * scale_by).rotated(spin)))
				_push_command({"kind": "polygon", "points": corners, "color": tint})
			"line":
				var to_point: Vector2 = origin + (Vector2(p1, p2) * scale_by).rotated(spin)
				draw_canvas_line(at.x, at.y, to_point.x, to_point.y, maxf(p3 * scale_by, 1.0), tint)
			"cone":
				draw_canvas_cone(at.x, at.y, p1 + rotation_deg, p2, p3 * scale_by, tint)
			"stamp":
				var texture_path: String = str(entry.get("texture", "")).strip_edges()
				if not texture_path.is_empty() and ResourceLoader.exists(texture_path):
					draw_canvas_stamp(load(texture_path) as Texture2D, at.x, at.y, maxf(p1, 0.01) * scale_by, p2 + rotation_deg)

## @ace_action
## @ace_name("Start Ribbon")
## @ace_description("Starts a textured ribbon trailing a node - sword swooshes, skid marks, comet tails. The ribbon follows for Point Count frames of history; Set Ribbon Texture skins it.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$DrawingCanvas.start_ribbon({follow}, {point_count}, {width}, {color})")
func start_ribbon(follow: Node, point_count: int, width: float, color: Color) -> void:
	_ensure_canvas()
	if _drawer == null or not (follow is Node2D):
		return
	stop_ribbon(follow)
	var line: Line2D = Line2D.new()
	line.width = width
	line.default_color = color
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	_drawer.add_child(line)
	_ribbons.append({"id": follow.get_instance_id(), "line": line, "trail": [], "length": maxi(point_count, 2)})

## @ace_action
## @ace_name("Set Ribbon Texture")
## @ace_description("Skins a running ribbon with a texture, stretched along its length.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$DrawingCanvas.set_ribbon_texture({follow}, {texture})")
func set_ribbon_texture(follow: Node, texture: Texture2D) -> void:
	if follow == null:
		return
	for ribbon: Dictionary in _ribbons:
		if int(ribbon["id"]) == follow.get_instance_id() and is_instance_valid(ribbon["line"]):
			(ribbon["line"] as Line2D).texture = texture
			(ribbon["line"] as Line2D).texture_mode = Line2D.LINE_TEXTURE_STRETCH

## @ace_action
## @ace_name("Stop Ribbon")
## @ace_description("Ends the ribbon trailing a node.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$DrawingCanvas.stop_ribbon({follow})")
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

# Drawing Canvas behavior (event-sheet parity): a texture your sheet draws onto with verbs - lines, circles, rings, rects, cones, texture stamps, textured ribbons, and a raycast LINE OF SIGHT fan. Persistent mode keeps strokes until Clear Canvas (paint, blood splats, skid marks); Auto Clear redraws every frame (attack telegraphs, vision cones). Canvas Texture exposes the live texture for materials, UI, or a 3D Decal. This pack is an event sheet - extend it by editing it.
