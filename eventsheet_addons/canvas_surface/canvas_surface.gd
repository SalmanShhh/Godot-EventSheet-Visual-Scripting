## @ace_requires(DrawingPrefabResource)
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/canvas_surface/icon.svg")
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
var _paste_textures: Array = []  # keeps pasted node textures alive - a freed source node (bake decor then Destroy) must not leave the persistent canvas re-drawing a dangling texture as a white block
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
## The camera's visible world rectangle (the screen corners mapped back through the canvas transform).
## Zero when there is no viewport yet.
func _visible_world_rect() -> Rect2:
	if _host == null or not _host.is_inside_tree():
		return Rect2()
	var vp: Viewport = _host.get_viewport()
	if vp == null:
		return Rect2()
	return _enclosing_rect(vp.get_canvas_transform().affine_inverse(), vp.get_visible_rect())
## The world-space AABB of a node's drawable rect (its texture rect run through its global transform).
## Zero when the node has no texture to paste.
func _node_world_rect(node: CanvasItem) -> Rect2:
	var info: Dictionary = _node_texture_info(node)
	if info.is_empty():
		return Rect2()
	return _enclosing_rect(node.get_global_transform(), info["dest_rect"])
## Axis-aligned rectangle enclosing the four corners of local_rect transformed by xform.
func _enclosing_rect(xform: Transform2D, local_rect: Rect2) -> Rect2:
	var c0: Vector2 = xform * local_rect.position
	var c1: Vector2 = xform * (local_rect.position + Vector2(local_rect.size.x, 0.0))
	var c2: Vector2 = xform * (local_rect.position + local_rect.size)
	var c3: Vector2 = xform * (local_rect.position + Vector2(0.0, local_rect.size.y))
	var min_p: Vector2 = c0.min(c1).min(c2).min(c3)
	var max_p: Vector2 = c0.max(c1).max(c2).max(c3)
	return Rect2(min_p, max_p - min_p)

# --- The draw style, and the shapes drawn in it ---
#
# A raster row carries its own width and colour, which is right for one line and wrong for thirty.
# The rows below take neither: the canvas keeps a STYLE, they draw in it, and Push and Pop nest one
# inside another so a debug overlay is a style and then its shapes.
#
# HOW THEY DRAW. When the Vector Shapes pack is installed and the canvas is redrawing every frame,
# each styled shape goes into a MultiMesh per shape kind - one draw call for every arc in the frame
# however many there are - wearing the same distance-field shader a placed shape wears. Without that
# pack, and in the persistent mode that bakes strokes into the raster once, exactly the same shapes
# are drawn the raster way instead. Nothing else changes: the same rows, the same numbers.

## Where the shape shader the batches wear lives once the Vector Shapes pack is installed. Its
## absence is not a fault - it is the canvas drawing the same shapes the raster way.
const BATCH_SHADER_PATH: String = "res://eventsheet_addons/vector_shapes/vector_shape_batch.gdshader"

## The shape kinds one MultiMesh each is filled with, in the order the batch shader numbers them.
## A kind NOT in this list is always drawn the raster way: a polygon and a polyline are meshes
## rather than a distance field, and text and a texture are neither.
const BATCH_KINDS: PackedStringArray = ["arc", "pie", "rounded_rect", "regular_polygon", "grid", "cross", "arrow"]

## What a draw style says, and what the canvas draws with before anything sets one. The keys are
## spelled the way a Shape Style file spells them, so a style tuned on a placed shape is read here
## unchanged and a resource that carries only some of them leaves the rest alone.
const STYLE_DEFAULTS: Dictionary = {
	"thickness": 2.0,
	"caps": "round",
	"colour": Color.WHITE,
	"colour_b": Color.WHITE,
	"colour_mode": "single",
	"filled": false,
	"dashed": false,
	"dash_space": "count",
	"dash_snap": "tiling",
	"dash_size": 12.0,
	"dash_count": 12,
	"dash_spacing": 0.5,
	"dash_style": "plain"
}

## The cap words, the colour modes, the dash snaps and the dash ends, each in the shader's own
## order - the position in the list IS the number the shader is handed.
const CAP_WORDS: PackedStringArray = ["none", "square", "round"]
const COLOUR_MODE_WORDS: PackedStringArray = ["single", "two", "radial", "angular", "gradient", "per corner"]
const DASH_SNAP_WORDS: PackedStringArray = ["off", "tiling", "end to end"]
const DASH_STYLE_WORDS: PackedStringArray = ["plain", "angled", "rounded"]

## How wide the fade at a drawn edge is, in pixels. One number on both sides of the wire: the quad a
## shape is drawn on is grown by it here, and the shader fades over it there.
const ANTIALIAS_WIDTH: float = 1.0

## How many segments a raster arc is drawn with when there is no shader to solve it per pixel.
const RASTER_ARC_SEGMENTS: int = 64

## How many draws a batch may sit out before its node is shelved for re-use, and how many shelved
## nodes are kept. Both are small on purpose: a canvas that has finished with two hundred styles
## must not go on paying for two hundred nodes, and a style that comes back a frame later must not
## pay to rebuild one.
const BATCH_IDLE_DRAWS: int = 2
const BATCH_SHELF_LIMIT: int = 8

# The style stack. The last entry is the style in force; an empty stack is the defaults above.
var _styles: Array = []

# One MultiMeshInstance2D per kind-and-style being drawn, kept and re-filled rather than rebuilt.
# A frame that draws two hundred arcs in one style builds no node and no material; what it does
# build is the plan the fill reads, which is a list of small dictionaries and is deliberately data
# so the batching decision can be checked without a canvas at all.
var _batches: Dictionary = {}

# How many draws each batch has sat out. A STYLE IS PART OF THE KEY, and a style can be a colour
# being tweened or a thickness that moves every frame, so the set of keys a canvas has ever drawn
# is unbounded while the set it is drawing right now is not. A batch nothing has drawn for
# BATCH_IDLE_DRAWS goes back on the shelf below instead of sitting in the SubViewport for ever.
var _batch_idle: Dictionary = {}

# Retired batch nodes, kept to be handed straight back out. A style that changes every frame gives
# one back and claims one each draw, so the canvas settles at a handful of nodes rather than
# growing one per frame for the life of the game.
var _batch_shelf: Array = []

# The style the cached keys below were worked out for, and one key per shape kind in it. The style
# in force is ONE dictionary shared by every shape drawn in it, so the key it makes is too: this is
# what keeps a frame of two hundred arcs from sorting the same thirteen field names two hundred
# times. A shape that overrides a style field (a filled rounded rect) has a style of its own and
# takes the plain path.
var _key_style: Dictionary = {}
var _keys_by_kind: Dictionary = {}

# The shader every batch wears, loaded once per session, and whether we have looked for it yet.
static var _batch_shader: Shader = null
static var _batch_shader_sought: bool = false

# The unit quad every batch instances, built once per session.
static var _batch_mesh: ArrayMesh = null
## The shader every batch wears, loaded once per session. Null when the Vector Shapes pack is not
## installed, which is what sends the same shapes down the raster path.
static func batch_shader() -> Shader:
	if not _batch_shader_sought:
		_batch_shader_sought = true
		if ResourceLoader.exists(BATCH_SHADER_PATH):
			_batch_shader = load(BATCH_SHADER_PATH)
	return _batch_shader
## The unit quad every instanced shape is drawn on, from -1 to 1 with its UV over the same square,
## built once per session. The instance transform scales it to the shape's own reach.
static func batch_mesh() -> ArrayMesh:
	if _batch_mesh != null:
		return _batch_mesh
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector2Array([Vector2(-1.0, -1.0), Vector2(1.0, -1.0), Vector2(1.0, 1.0), Vector2(-1.0, 1.0)])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	_batch_mesh = ArrayMesh.new()
	_batch_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return _batch_mesh

## Applies configuration (from the behavior's exports) and rebuilds the surface if it already exists.
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
	# Ribbons are the only thing this surface needs a frame for, and a fresh surface has none:
	# every other draw is queued and redrawn on demand rather than polled, so an ordinary canvas
	# costs nothing per frame until Start Ribbon asks for one.
	set_physics_process(false)
	_ensure()

## The display sprite lives on the HOST, not on this surface, so freeing (or re-creating) the surface
## would leave a stray Sprite2D parented to the host still pointing at a dead ViewportTexture. Take it
## with us on the way out.
func _exit_tree() -> void:
	if is_instance_valid(_display):
		_display.queue_free()
	_display = null

## Builds the offscreen render target once: a SubViewport holding the drawer whose draw signal
## replays the queue. Clear mode is the whole persistence story - NEVER accumulates (paint), ALWAYS
## wipes (live redraw), and clear() flips to ONCE.
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

## World position -> canvas pixels: the canvas is centered on the host, so the mapping is a
## translation. In canvas coordinate mode points pass through untouched.
func to_canvas(point: Vector2) -> Vector2:
	if coordinates != "world" or _host == null:
		return point
	return point - _host.global_position + Vector2(canvas_width, canvas_height) * 0.5

func _run_draw_commands() -> void:
	# The styled shapes this frame can instance, and the keys those batches took - everything
	# else, styled or not, is drawn the raster way in the order it was queued. THE TWO HALVES DO
	# NOT INTERLEAVE: the instanced shapes are children of the SubViewport and the raster ones are
	# drawn by the drawer under them, so a texture queued AFTER an arc still lands beneath it. A
	# frame that needs one exact stacking order is a persistent canvas, which draws every shape
	# the raster way.
	var batched: Array = []
	var taken: Dictionary = {}
	if _use_batches():
		for batch: Dictionary in plan_batches(_commands):
			if _batches.has(str(batch["key"])):
				batched.append(batch)
				taken[str(batch["key"])] = true
	for command: Dictionary in plan_raster(_commands, taken):
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
			"node_stamp":
				var node_tex: Texture2D = command["texture"]
				if node_tex != null:
					_drawer.draw_set_transform_matrix(command["xform"])
					var src_rect: Rect2 = command["src_rect"]
					if src_rect.size.x > 0.0 and src_rect.size.y > 0.0:
						_drawer.draw_texture_rect_region(node_tex, command["dest_rect"], src_rect, command["modulate"])
					else:
						_drawer.draw_texture_rect(node_tex, command["dest_rect"], false, command["modulate"])
					_drawer.draw_set_transform_matrix(Transform2D.IDENTITY)
			"arc":
				_drawer.draw_arc(command["at"], command["radius"], command["from"], command["to"], RASTER_ARC_SEGMENTS, command["color"], command["width"])
			"polyline":
				_drawer.draw_polyline(command["points"], command["color"], command["width"])
			"text":
				var face: Font = ThemeDB.fallback_font
				if face != null:
					_drawer.draw_string(face, command["at"], str(command["message"]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(command["size"]), command["color"])
			"texture_rect":
				var drawn_texture: Texture2D = command["texture"]
				if drawn_texture != null:
					_drawer.draw_texture_rect(drawn_texture, command["rect"], false, command["color"])
	_fill_batches(batched)
	_commands.clear()

func _push(command: Dictionary) -> void:
	_ensure()
	_commands.append(command)  # buffered even before the drawer exists; _ensure flushes it
	if str(command.get("kind", "")) == "node_stamp" and command.get("texture") != null and not _paste_textures.has(command["texture"]):
		_paste_textures.append(command["texture"])
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

## Typed draw entries for a prefab: the resource's cached compiled_steps() (parsed once, shared by
## every draw) when it exposes one, else a raw parse of any Resource's steps into the same shape.
func _prefab_entries(prefab_res: Resource) -> Array:
	if prefab_res.has_method("compiled_steps"):
		var compiled: Variant = prefab_res.compiled_steps()
		if compiled is Array:
			return compiled
	var raw: Variant = prefab_res.get("steps")
	if not (raw is Array):
		return []
	return DrawingPrefabResource.compile_steps(raw)

## Bakes one node's current visual onto the canvas at its own world transform. No-op for a node with no
## resolvable texture (a plain Node2D, a TileMap - nothing to paste).
func paste_node(node: Node) -> void:
	var command: Dictionary = _node_paste_command(node, null)
	if not command.is_empty():
		_push(command)

## Bakes a node's visual at an EXPLICIT spot (x, y read the same way as the other draw actions), scaled
## and rotated - decouples the stamp from the node's own transform (paste an off-screen template).
func paste_node_at(node: Node, x: float, y: float, scale_factor: float, rotation_deg: float) -> void:
	# --- Paste: bake a live node's visual (or a whole layer's) onto the canvas as a decal. Texture-bearing
	# CanvasItems (Sprite2D, AnimatedSprite2D, TextureRect, or anything exposing a `texture`) stamp at their
	# exact world transform - rotation, scale, flip, region/frame and modulate preserved. Non-destructive: the
	# original node stays, so pair with a Destroy/Hide action to truly flatten a layer for performance. ---
	if not (node is Node2D):
		return
	var placed: Transform2D = Transform2D(deg_to_rad(rotation_deg), Vector2.ONE * maxf(scale_factor, 0.01), 0.0, Vector2(x, y))
	var command: Dictionary = _node_paste_command(node, placed)
	if not command.is_empty():
		_push(command)

## Bakes every visible texture-bearing CanvasItem under `layer` that is currently ON SCREEN (its world
## rect intersects the camera's visible rectangle). `layer` is any parent - a CanvasLayer, a container,
## or the scene root.
func paste_layer_on_screen(layer: Node) -> void:
	var view_rect: Rect2 = _visible_world_rect()
	if view_rect.size == Vector2.ZERO:
		return
	_paste_layer_in_rect(layer, view_rect)

## Bakes every visible texture-bearing CanvasItem under `layer` whose world rect intersects the box
## Rect2(x, y, width, height), in WORLD coordinates - flatten a region regardless of the camera.
func paste_layer_in_box(layer: Node, x: float, y: float, width: float, height: float) -> void:
	_paste_layer_in_rect(layer, Rect2(x, y, width, height))

func _paste_layer_in_rect(layer: Node, world_rect: Rect2) -> void:
	if layer == null:
		return
	for item: CanvasItem in _descendant_canvas_items(layer):
		var item_rect: Rect2 = _node_world_rect(item)
		if item_rect.size.x <= 0.0 or item_rect.size.y <= 0.0:
			continue
		if world_rect.intersects(item_rect):
			paste_node(item)

## Depth-first collect of every VISIBLE CanvasItem under root, skipping this surface's own drawer/display/
## viewport so a layer paste never re-bakes the canvas onto itself. An invisible node prunes its subtree.
func _descendant_canvas_items(root: Node) -> Array:
	var out: Array = []
	for child: Node in root.get_children():
		if child == self or child == _display or child == _viewport:
			continue
		if child is CanvasItem and not (child as CanvasItem).visible:
			continue
		if child is CanvasItem:
			out.append(child)
		out.append_array(_descendant_canvas_items(child))
	return out

## Composes a node's world transform into canvas space and returns a "node_stamp" draw command, or {}
## when the node has no resolvable texture. A Transform2D override places the stamp explicitly instead
## of at the node's own transform.
func _node_paste_command(node: Node, world_xform_override: Variant) -> Dictionary:
	if not (node is CanvasItem):
		return {}
	var info: Dictionary = _node_texture_info(node as CanvasItem)
	if info.is_empty():
		return {}
	var world_xform: Transform2D = (node as CanvasItem).get_global_transform()
	if world_xform_override is Transform2D:
		world_xform = world_xform_override
	# World -> canvas is a pure translation (canvas centered on the host) in world mode, identity in canvas
	# mode, so composing it just remaps the origin - rotation, scale and flip carry through untouched.
	var canvas_xform: Transform2D = world_xform
	canvas_xform.origin = to_canvas(world_xform.origin)
	if bool(info["flip_h"]) or bool(info["flip_v"]):
		var flip: Transform2D = Transform2D(Vector2(-1.0 if info["flip_h"] else 1.0, 0.0), Vector2(0.0, -1.0 if info["flip_v"] else 1.0), Vector2.ZERO)
		canvas_xform = canvas_xform * flip
	return {"kind": "node_stamp", "texture": info["texture"], "xform": canvas_xform, "src_rect": info["src_rect"], "dest_rect": info["dest_rect"], "modulate": info["modulate"]}

## Pulls a drawable texture, source region, LOCAL destination rect, tint and flip flags from a node.
## Handles Sprite2D (centered/offset/region/hframes/vframes/frame/flip), AnimatedSprite2D (current
## frame), TextureRect (its rect), and any CanvasItem exposing a `texture` (drawn centered). {} when
## there is nothing to draw.
func _node_texture_info(node: CanvasItem) -> Dictionary:
	var tint: Color = node.self_modulate * node.modulate
	if node is Sprite2D:
		return _sprite_info(node as Sprite2D, tint)
	if node is AnimatedSprite2D:
		return _animated_sprite_info(node as AnimatedSprite2D, tint)
	if node is TextureRect and (node as TextureRect).texture != null:
		var rect_node: TextureRect = node as TextureRect
		return {"texture": rect_node.texture, "src_rect": Rect2(), "dest_rect": Rect2(Vector2.ZERO, rect_node.size), "modulate": tint, "flip_h": false, "flip_v": false}
	var generic: Variant = node.get("texture")
	if generic is Texture2D:
		var generic_tex: Texture2D = generic
		return {"texture": generic_tex, "src_rect": Rect2(), "dest_rect": Rect2(-generic_tex.get_size() * 0.5, generic_tex.get_size()), "modulate": tint, "flip_h": false, "flip_v": false}
	return {}

## Sprite2D current frame -> {texture, src_rect, local dest_rect (centered/offset applied), tint, flip}.
func _sprite_info(sprite: Sprite2D, tint: Color) -> Dictionary:
	if sprite.texture == null:
		return {}
	var tex: Texture2D = sprite.texture
	var frame_size: Vector2 = tex.get_size()
	var src: Rect2 = Rect2()
	if sprite.region_enabled:
		src = sprite.region_rect
		frame_size = src.size
	elif sprite.hframes > 1 or sprite.vframes > 1:
		var cols: int = maxi(sprite.hframes, 1)
		var rows: int = maxi(sprite.vframes, 1)
		frame_size = Vector2(tex.get_width() / float(cols), tex.get_height() / float(rows))
		var cell: int = sprite.frame
		src = Rect2(Vector2(cell % cols, (cell / cols) % rows) * frame_size, frame_size)
	var dest_pos: Vector2 = sprite.offset
	if sprite.centered:
		dest_pos -= frame_size * 0.5
	return {"texture": tex, "src_rect": src, "dest_rect": Rect2(dest_pos, frame_size), "modulate": tint, "flip_h": sprite.flip_h, "flip_v": sprite.flip_v}

## AnimatedSprite2D current frame -> the same info shape, read from the SpriteFrames.
func _animated_sprite_info(sprite: AnimatedSprite2D, tint: Color) -> Dictionary:
	var frames: SpriteFrames = sprite.sprite_frames
	if frames == null or not frames.has_animation(sprite.animation):
		return {}
	var tex: Texture2D = frames.get_frame_texture(sprite.animation, sprite.frame)
	if tex == null:
		return {}
	var frame_size: Vector2 = tex.get_size()
	var dest_pos: Vector2 = sprite.offset
	if sprite.centered:
		dest_pos -= frame_size * 0.5
	return {"texture": tex, "src_rect": Rect2(), "dest_rect": Rect2(dest_pos, frame_size), "modulate": tint, "flip_h": sprite.flip_h, "flip_v": sprite.flip_v}

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

## Dashes a polyline and pushes the segments as one multiline command (a single draw call).
func _push_dashes(points: PackedVector2Array, dash_length: float, gap_length: float, width: float, color: Color) -> void:
	# --- Dashed shapes: ONE dash primitive turns any polyline into disjoint dash segments, drawn in a
	# single draw_multiline call. Line = 2 points, ring = a sampled circle, rect = 4 closed corners - the
	# same routine serves all three and any future dashed shape. ---
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
	# A ribbon is refreshed every physics frame, so the first one buys the tick back.
	set_physics_process(true)

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
	if _ribbons.is_empty():
		set_physics_process(false)

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
	# The last ribbon's followed node was freed: nothing is left to refresh, so stop paying for
	# the frame until another Start Ribbon.
	if _ribbons.is_empty():
		set_physics_process(false)

## The style the next drawn shape will wear.
func current_style() -> Dictionary:
	if _styles.is_empty():
		return STYLE_DEFAULTS.duplicate()
	return _styles[_styles.size() - 1]

## Replaces the style in force. Every styled row after this one draws in it until it is replaced,
## popped or reset. A null style is the canvas's own defaults.
func set_draw_style(style: Resource) -> void:
	var fields: Dictionary = style_fields(style)
	if _styles.is_empty():
		_styles.append(fields)
	else:
		_styles[_styles.size() - 1] = fields

## Sets a style with the one in force kept underneath it, to come back on Pop Draw Style.
func push_draw_style(style: Resource) -> void:
	_styles.append(style_fields(style))

## Goes back to the style that was in force before the last Push Draw Style.
func pop_draw_style() -> void:
	if not _styles.is_empty():
		_styles.remove_at(_styles.size() - 1)

## Drops the whole stack: the canvas draws in its own defaults again.
func reset_draw_style() -> void:
	_styles.clear()

## One style resource read as the fields the canvas draws with. Read BY NAME rather than by class,
## so a Shape Style file, a shape node's own style or a project's own resource with the same field
## names all work, and a resource that has not got a field leaves that field alone.
static func style_fields(style: Resource) -> Dictionary:
	var fields: Dictionary = STYLE_DEFAULTS.duplicate()
	if style == null:
		return fields
	for key: String in STYLE_DEFAULTS:
		var value: Variant = style.get(key)
		if value == null:
			continue
		if typeof(value) == typeof(fields[key]):
			fields[key] = value
		elif (value is float or value is int) and (fields[key] is float or fields[key] is int):
			fields[key] = float(value) if fields[key] is float else int(value)
	return fields

## Draws an arc of a circle in the current style: a cooldown sweep, a health ring, a turn radius.
func draw_arc_shape(x: float, y: float, radius: float, from_degrees: float, to_degrees: float) -> void:
	_push_shape("arc", Vector2(x, y), 0.0, Vector4(radius, 0.0, deg_to_rad(from_degrees), deg_to_rad(maxf(to_degrees, from_degrees))), {})

## Draws a filled wedge of a circle in the current style - the same two angles as an arc, filled in.
func draw_pie(x: float, y: float, radius: float, from_degrees: float, to_degrees: float) -> void:
	_push_shape("pie", Vector2(x, y), 0.0, Vector4(radius, 0.0, deg_to_rad(from_degrees), deg_to_rad(maxf(to_degrees, from_degrees))), {})

## Draws a rectangle with rounded corners, from its CENTRE, filled or as an outline.
func draw_rounded_rect(x: float, y: float, width: float, height: float, corner_radius: float, filled: bool) -> void:
	_push_shape("rounded_rect", Vector2(x, y), 0.0, Vector4(width * 0.5, height * 0.5, maxf(corner_radius, 0.0), 0.0), {"filled": filled})

## Draws a shape of N equal sides at a radius, from its centre - a hexagon grid cell, a warning
## triangle, a stop sign.
func draw_regular_polygon(x: float, y: float, radius: float, sides: int, angle_degrees: float, filled: bool) -> void:
	_push_shape("regular_polygon", Vector2(x, y), 0.0, Vector4(radius, float(maxi(sides, 3)), deg_to_rad(angle_degrees), 0.0), {"filled": filled})

## Draws a grid of rulings filling a box, from its centre - the level editor's floor, the debug
## overlay's ruler.
func draw_grid(x: float, y: float, width: float, height: float, cell_size: float) -> void:
	_push_shape("grid", Vector2(x, y), 0.0, Vector4(width * 0.5, height * 0.5, maxf(cell_size, 1.0), 0.0), {})

## Draws a cross - the marker on a spot, the "no" over a placement.
func draw_cross(x: float, y: float, arm_length: float, angle_degrees: float) -> void:
	_push_shape("cross", Vector2(x, y), deg_to_rad(angle_degrees), Vector4(maxf(arm_length, 0.01), 0.0, 0.0, 0.0), {})

## Draws an arrow from one point to another, its head sized in pixels - a force, a facing, a route.
func draw_arrow(from_x: float, from_y: float, to_x: float, to_y: float, head_size: float) -> void:
	var from_point: Vector2 = Vector2(from_x, from_y)
	var to_point: Vector2 = Vector2(to_x, to_y)
	var span: Vector2 = to_point - from_point
	var head: float = maxf(head_size, 1.0)
	_push_shape("arrow", (from_point + to_point) * 0.5, span.angle(), Vector4(maxf(span.length() * 0.5, 0.01), head, head, 0.0), {})

## Draws a closed outline through a list of positions, filled or hollow. A polygon is a mesh rather
## than a distance field, so it is drawn the raster way whatever else the frame is doing.
func draw_polygon_shape(points: Array, filled: bool) -> void:
	_push_shape("polygon", Vector2.ZERO, 0.0, Vector4.ZERO, {"filled": filled, "points": _as_points(points)})

## Draws a path through a list of positions, open or closed - a route preview, a drawn trail.
func draw_polyline_shape(points: Array, closed: bool) -> void:
	_push_shape("polyline", Vector2.ZERO, 0.0, Vector4.ZERO, {"closed": closed, "points": _as_points(points)})

## Draws a line of text at a spot, in the style's own colour - a state name over an enemy, a number
## over a tile.
func draw_text(message: String, x: float, y: float, size: float) -> void:
	_push_shape("text", Vector2(x, y), 0.0, Vector4(maxf(size, 1.0), 0.0, 0.0, 0.0), {"message": message})

## Draws a texture stretched into a box, from its centre, tinted by the style's colour.
func draw_texture_in_rect(texture_res: Texture2D, x: float, y: float, width: float, height: float) -> void:
	_push_shape("texture", Vector2(x, y), 0.0, Vector4(width * 0.5, height * 0.5, 0.0, 0.0), {"texture": texture_res})

## One styled shape, queued the way every other draw is. The style is COPIED onto the command, so a
## shape drawn now and the same shape drawn after the style changed keep their own looks. Anything
## in `extra` that a style speaks for joins the style; everything else (a list of points, a message,
## a texture) rides the command, where it belongs to that one shape.
func _push_shape(kind: String, at: Vector2, angle: float, numbers: Vector4, extra: Dictionary) -> void:
	_ensure()
	# The style in force rides the command AS IT IS. Nothing ever edits a stored style in place -
	# Set, Push, Pop and Reset each replace one - so a hundred shapes drawn in one style share the
	# one dictionary, and only a shape that has to CHANGE a field takes a copy of its own.
	var style: Dictionary = _style_in_force()
	var own_style: bool = false
	var command: Dictionary = {"kind": kind, "styled": true, "at": to_canvas(at), "angle": angle, "numbers": numbers}
	for key: String in extra:
		if STYLE_DEFAULTS.has(key):
			if not own_style:
				style = style.duplicate()
				own_style = true
			style[key] = extra[key]
		else:
			command[key] = extra[key]
	command["style"] = style
	if _use_batches() and BATCH_KINDS.has(kind):
		# Worked out once here and carried on the command, because the plan and the raster fallback
		# each ask for it again and a key is a sort and a dozen joins.
		var shape_key: String = _batch_key_in_force(kind, style, own_style)
		command["batch_key"] = shape_key
		_reserve_batch(shape_key)
	_push(command)

## The style in force WITHOUT a copy, for the queueing path above. current_style() is the public
## reading and still hands back a copy, because a caller that edited what it got back would be
## editing the canvas's own defaults - which are a constant.
func _style_in_force() -> Dictionary:
	if _styles.is_empty():
		return STYLE_DEFAULTS
	return _styles[_styles.size() - 1]

## One shape's batch key, cached per style. The style in force is one dictionary shared by every
## shape drawn in it, so its key per kind is worked out on the first shape and read by the rest; a
## shape carrying a style of its own is spelled out the plain way, once.
func _batch_key_in_force(kind: String, style: Dictionary, own_style: bool) -> String:
	if own_style:
		return batch_key(kind, style)
	if not is_same(style, _key_style):
		_key_style = style
		_keys_by_kind.clear()
	if not _keys_by_kind.has(kind):
		_keys_by_kind[kind] = batch_key(kind, style)
	return str(_keys_by_kind[kind])

## A list of positions as points on the canvas, however the row spelled them.
func _as_points(points: Array) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for entry: Variant in points:
		if entry is Vector2:
			out.append(to_canvas(entry))
	return out

## Whether this frame's styled shapes go through the instanced path. Two things say yes: the Vector
## Shapes pack is installed, so there is a shader to draw them with, and the canvas redraws every
## frame - a PERSISTENT canvas bakes its strokes into the raster once, which is the whole point of
## it, and a MultiMesh re-drawn into a surface that never clears would pile up on itself.
func _use_batches() -> bool:
	return auto_clear and batch_shader() != null

## Which batch a styled command belongs in: its kind and the style it was drawn in. Two arcs in one
## style are one draw; the same two in two styles are two, because a style is shader uniforms.
static func batch_key(kind: String, style: Dictionary) -> String:
	var keys: Array = style.keys()
	keys.sort()
	var parts: PackedStringArray = PackedStringArray([kind])
	for key: String in keys:
		parts.append("%s=%s" % [key, style[key]])
	return "|".join(parts)

## This frame's instanced draws: one entry per kind-and-style, in the order the frame first drew
## each, holding every instance of it. This is the whole of the batching decision, and it is a plain
## reading of the queue so it can be checked without a canvas at all.
static func plan_batches(commands: Array) -> Array:
	var order: PackedStringArray = PackedStringArray()
	var by_key: Dictionary = {}
	for command: Dictionary in commands:
		if not bool(command.get("styled", false)):
			continue
		var kind: String = str(command.get("kind", ""))
		if not BATCH_KINDS.has(kind):
			continue
		var style: Dictionary = command.get("style", {})
		var key: String = str(command["batch_key"]) if command.has("batch_key") else batch_key(kind, style)
		if not by_key.has(key):
			by_key[key] = {"key": key, "kind": kind, "kind_id": BATCH_KINDS.find(kind), "style": style, "instances": []}
			order.append(key)
		var instances: Array = by_key[key]["instances"]
		instances.append({
			"at": command["at"],
			"angle": float(command["angle"]),
			"numbers": command["numbers"],
			"extent": batch_extent(kind, command["numbers"], style)
		})
	var plan: Array = []
	for key: String in order:
		plan.append(by_key[key])
	return plan

## How far a shape reaches from its own centre, in pixels: how big the quad it is instanced onto
## has to be. THE BATCH SHADER WORKS THE SAME NUMBER OUT from the same four numbers, and the two
## must agree - a quad smaller than its shape clips it.
static func batch_extent(kind: String, numbers: Vector4, style: Dictionary) -> float:
	var margin: float = maxf(float(style.get("thickness", 2.0)), 0.01) * 0.5 + ANTIALIAS_WIDTH + 2.0
	if kind == "rounded_rect" or kind == "grid":
		return maxf(absf(numbers.x), absf(numbers.y)) + margin
	if kind == "arrow":
		return maxf(absf(numbers.x), absf(numbers.z)) + margin
	return absf(numbers.x) + margin

## This frame's raster draws, in the order they were queued: every command that is not a styled
## shape exactly as it was pushed, and every styled shape turned into the one primitive that draws
## it. `taken` holds the batch keys the MultiMesh path has already claimed this frame, so a shape
## whose batch could not be built is still drawn rather than silently dropped.
static func plan_raster(commands: Array, taken: Dictionary) -> Array:
	var out: Array = []
	for command: Dictionary in commands:
		if not bool(command.get("styled", false)):
			out.append(command)
			continue
		var key: String = str(command["batch_key"]) if command.has("batch_key") else batch_key(str(command.get("kind", "")), command.get("style", {}))
		if taken.has(key):
			continue
		var drawn: Dictionary = raster_shape(command)
		if not drawn.is_empty():
			out.append(drawn)
	return out

## One styled shape as the raster primitive that draws it - the same shape, solved on the CPU. The
## dash pattern the shader would have cut is walked by the shared dash primitive instead, so a
## dashed arc is dashed either way.
static func raster_shape(command: Dictionary) -> Dictionary:
	var style: Dictionary = command.get("style", {})
	var colour: Color = style.get("colour", Color.WHITE)
	var width: float = maxf(float(style.get("thickness", 2.0)), 0.5)
	var filled: bool = bool(style.get("filled", false))
	var at: Vector2 = command.get("at", Vector2.ZERO)
	var numbers: Vector4 = command.get("numbers", Vector4.ZERO)
	match str(command.get("kind", "")):
		"arc":
			if bool(style.get("dashed", false)):
				return {"kind": "multiline", "points": dashed_walk(arc_points(at, numbers.x, numbers.z, numbers.w), false, style), "width": width, "color": colour}
			return {"kind": "arc", "at": at, "radius": numbers.x, "from": numbers.z, "to": numbers.w, "width": width, "color": colour}
		"pie":
			var wedge: PackedVector2Array = PackedVector2Array([at])
			for step: int in 33:
				wedge.append(at + Vector2.from_angle(lerpf(numbers.z, numbers.w, float(step) / 32.0)) * numbers.x)
			return {"kind": "polygon", "points": wedge, "color": colour}
		"rounded_rect":
			var outline: PackedVector2Array = rounded_rect_points(at, Vector2(numbers.x, numbers.y), numbers.z)
			if filled:
				return {"kind": "polygon", "points": outline, "color": colour}
			if bool(style.get("dashed", false)):
				return {"kind": "multiline", "points": dashed_walk(outline, true, style), "width": width, "color": colour}
			outline.append(outline[0])
			return {"kind": "polyline", "points": outline, "width": width, "color": colour}
		"regular_polygon":
			var corners: PackedVector2Array = regular_polygon_points(at, numbers.x, int(numbers.y), numbers.z)
			if filled:
				return {"kind": "polygon", "points": corners, "color": colour}
			if bool(style.get("dashed", false)):
				return {"kind": "multiline", "points": dashed_walk(corners, true, style), "width": width, "color": colour}
			corners.append(corners[0])
			return {"kind": "polyline", "points": corners, "width": width, "color": colour}
		"grid":
			return {"kind": "multiline", "points": grid_points(at, Vector2(numbers.x, numbers.y), numbers.z), "width": width, "color": colour}
		"cross":
			var arm: Vector2 = Vector2(numbers.x, 0.0).rotated(float(command.get("angle", 0.0)))
			var down: Vector2 = arm.orthogonal()
			return {"kind": "multiline", "points": PackedVector2Array([at - arm, at + arm, at - down, at + down]), "width": width, "color": colour}
		"arrow":
			return {"kind": "multiline", "points": arrow_points(at, float(command.get("angle", 0.0)), numbers.x, numbers.y, numbers.z), "width": width, "color": colour}
		"polygon":
			var points: PackedVector2Array = command.get("points", PackedVector2Array())
			if points.size() < 3:
				return {}
			if filled:
				return {"kind": "polygon", "points": points, "color": colour}
			if bool(style.get("dashed", false)):
				return {"kind": "multiline", "points": dashed_walk(points, true, style), "width": width, "color": colour}
			var ring: PackedVector2Array = points.duplicate()
			ring.append(ring[0])
			return {"kind": "polyline", "points": ring, "width": width, "color": colour}
		"polyline":
			var path: PackedVector2Array = command.get("points", PackedVector2Array())
			if path.size() < 2:
				return {}
			var loop: bool = bool(command.get("closed", false))
			if bool(style.get("dashed", false)):
				return {"kind": "multiline", "points": dashed_walk(path, loop, style), "width": width, "color": colour}
			var walk: PackedVector2Array = path.duplicate()
			if loop:
				walk.append(walk[0])
			return {"kind": "polyline", "points": walk, "width": width, "color": colour}
		"text":
			return {"kind": "text", "at": at, "message": str(command.get("message", "")), "size": numbers.x, "color": colour}
		"texture":
			return {"kind": "texture_rect", "texture": command.get("texture"), "rect": Rect2(at - Vector2(numbers.x, numbers.y), Vector2(numbers.x, numbers.y) * 2.0), "color": colour}
	return {}

## An arc as points. The dash primitive walks points, and an arc the shader would have solved per
## pixel has none, so the raster half samples one.
static func arc_points(at: Vector2, radius: float, from_angle: float, to_angle: float) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for step: int in RASTER_ARC_SEGMENTS + 1:
		out.append(at + Vector2.from_angle(lerpf(from_angle, to_angle, float(step) / float(RASTER_ARC_SEGMENTS))) * radius)
	return out

## One outline cut into dashes by the style in force - the SAME pattern the shader cuts, walked on
## the CPU by the dash primitive the canvas already uses for its dashed line, ring and rect. In count
## mode the period is the outline's own length divided by the count, which is what makes a dashed
## ring of any radius carry the number of dashes it was asked for.
static func dashed_walk(points: PackedVector2Array, closed: bool, style: Dictionary) -> PackedVector2Array:
	var walk: PackedVector2Array = points.duplicate()
	if closed and walk.size() > 1:
		walk.append(walk[0])
	var space: String = str(style.get("dash_space", "count"))
	var thickness: float = maxf(float(style.get("thickness", 2.0)), 0.01)
	var dash: float = maxf(float(style.get("dash_size", 12.0)), 0.5)
	var gap: float = maxf(float(style.get("dash_spacing", 6.0)), 0.0)
	if space == "count":
		var total: float = 0.0
		for index: int in maxi(walk.size() - 1, 0):
			total += walk[index].distance_to(walk[index + 1])
		var period: float = total / maxf(float(int(style.get("dash_count", 12))), 1.0)
		gap = period * clampf(float(style.get("dash_spacing", 0.5)), 0.0, 0.95)
		dash = maxf(period - gap, 0.5)
	elif space == "relative":
		dash *= thickness
		gap *= thickness
	return _dash_polyline(walk, dash, gap)

## The outline of a rounded rectangle centred on a point, as points - what the raster half draws
## when there is no shader to solve the corner per pixel.
static func rounded_rect_points(at: Vector2, half_size: Vector2, corner: float) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	var radius: float = clampf(corner, 0.0, minf(half_size.x, half_size.y))
	var centres: Array = [
		Vector2(half_size.x - radius, half_size.y - radius),
		Vector2(-half_size.x + radius, half_size.y - radius),
		Vector2(-half_size.x + radius, -half_size.y + radius),
		Vector2(half_size.x - radius, -half_size.y + radius)
	]
	for quadrant: int in 4:
		var start: float = float(quadrant) * PI * 0.5
		for step: int in 5:
			out.append(at + centres[quadrant] + Vector2.from_angle(start + PI * 0.5 * float(step) / 4.0) * radius)
	return out

## The corners of a shape of N equal sides, centred on a point.
static func regular_polygon_points(at: Vector2, radius: float, sides: int, angle: float) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	var count: int = maxi(sides, 3)
	for corner: int in count:
		out.append(at + Vector2.from_angle(angle + TAU * float(corner) / float(count)) * radius)
	return out

## The rulings of a grid filling a box, as the endpoint pairs one draw call takes.
static func grid_points(at: Vector2, half_size: Vector2, cell: float) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	var step: float = maxf(cell, 1.0)
	var across: int = mini(int(half_size.x / step), 512)
	var down: int = mini(int(half_size.y / step), 512)
	for index: int in range(-across, across + 1):
		var x: float = at.x + float(index) * step
		out.append(Vector2(x, at.y - half_size.y))
		out.append(Vector2(x, at.y + half_size.y))
	for index: int in range(-down, down + 1):
		var y: float = at.y + float(index) * step
		out.append(Vector2(at.x - half_size.x, y))
		out.append(Vector2(at.x + half_size.x, y))
	return out

## An arrow's shaft and the two sides of its head, as the endpoint pairs one draw call takes.
static func arrow_points(at: Vector2, angle: float, half_length: float, head: float, head_width: float) -> PackedVector2Array:
	var tip: Vector2 = at + Vector2(half_length, 0.0).rotated(angle)
	var tail: Vector2 = at - Vector2(half_length, 0.0).rotated(angle)
	var base: Vector2 = at + Vector2(half_length - head, 0.0).rotated(angle)
	var side: Vector2 = Vector2(0.0, head_width * 0.5).rotated(angle)
	return PackedVector2Array([tail, tip, base - side, tip, base + side, tip])

## Makes sure a batch has somewhere to draw: one MultiMeshInstance2D per kind-and-style, taken off
## the shelf if a retired one is waiting and built otherwise, then re-filled every draw after.
## Called as a shape is QUEUED, never while the canvas is drawing, so nothing joins the tree
## mid-draw.
func _reserve_batch(key: String) -> void:
	if _batches.has(key) or _viewport == null:
		return
	var node: MultiMeshInstance2D = null
	while node == null and not _batch_shelf.is_empty():
		var shelved: Variant = _batch_shelf.pop_back()
		if is_instance_valid(shelved):
			node = shelved
	if node == null:
		var holder: MultiMesh = MultiMesh.new()
		holder.transform_format = MultiMesh.TRANSFORM_2D
		holder.use_custom_data = true
		holder.mesh = batch_mesh()
		node = MultiMeshInstance2D.new()
		node.multimesh = holder
		var shaded: ShaderMaterial = ShaderMaterial.new()
		shaded.shader = batch_shader()
		node.material = shaded
		_viewport.add_child(node)
	node.visible = true
	_batches[key] = node
	_batch_idle[key] = 0

## Fills this draw's batches, empties the ones it did not draw so a kind that has stopped being
## drawn stops appearing, and RETIRES the ones nothing has drawn for a few draws in a row. That
## last part is the whole reason this is not a dictionary that only grows: a batch is keyed by its
## style's own values, so a colour being tweened onto Set Draw Style, or a Push Draw Style handed a
## fresh resource each tick, mints a key a frame - and would otherwise leave a node behind in the
## SubViewport for every one of them, for the life of the canvas.
func _fill_batches(plan: Array) -> void:
	var drawn: Dictionary = {}
	for batch: Dictionary in plan:
		var key: String = str(batch["key"])
		if not _batches.has(key):
			continue
		drawn[key] = true
		var node: MultiMeshInstance2D = _batches[key]
		_push_style_uniforms(node.material, batch["style"], int(batch["kind_id"]))
		var holder: MultiMesh = node.multimesh
		var instances: Array = batch["instances"]
		holder.instance_count = instances.size()
		for index: int in instances.size():
			var instance: Dictionary = instances[index]
			var extent: float = float(instance["extent"])
			holder.set_instance_transform_2d(index, Transform2D(float(instance["angle"]), Vector2(extent, extent), 0.0, instance["at"]))
			var numbers: Vector4 = instance["numbers"]
			holder.set_instance_custom_data(index, Color(numbers.x, numbers.y, numbers.z, numbers.w))
	for key: String in _batches:
		if drawn.has(key):
			_batch_idle[key] = 0
			continue
		(_batches[key] as MultiMeshInstance2D).multimesh.instance_count = 0
		_batch_idle[key] = int(_batch_idle.get(key, 0)) + 1
	for key: String in batches_to_retire(_batch_idle, drawn):
		_shelve_batch(key)

## Which batches a draw retires: the ones it did not draw, once each has sat out more draws than
## BATCH_IDLE_DRAWS. A plain reading of two dictionaries, and static, so the rule can be checked
## without a canvas at all - which matters here, because the thing it prevents (one more node in
## the SubViewport every frame, for ever) is invisible until a game has been running a while.
static func batches_to_retire(idle: Dictionary, drawn: Dictionary) -> PackedStringArray:
	var retired: PackedStringArray = PackedStringArray()
	for key: String in idle:
		if not drawn.has(key) and int(idle[key]) > BATCH_IDLE_DRAWS:
			retired.append(key)
	retired.sort()
	return retired

## Takes a batch nothing is drawing off its key and puts its node on the shelf to be handed out
## again. The node stays a child of the SubViewport - hidden and emptied - so claiming it back
## costs nothing at all; past the shelf's limit it is freed instead, because a canvas that has
## finished with two hundred styles should not go on holding two hundred nodes.
func _shelve_batch(key: String) -> void:
	var node: MultiMeshInstance2D = _batches[key]
	_batches.erase(key)
	_batch_idle.erase(key)
	if not is_instance_valid(node):
		return
	node.visible = false
	node.multimesh.instance_count = 0
	if _batch_shelf.size() >= BATCH_SHELF_LIMIT:
		node.queue_free()
		return
	_batch_shelf.append(node)

## Hands one batch's style to its material - the same uniforms a placed shape sets, so the two draw
## the same dashes, the same caps and the same colour modes.
func _push_style_uniforms(target: ShaderMaterial, style: Dictionary, kind_id: int) -> void:
	if target == null:
		return
	var thickness: float = maxf(float(style.get("thickness", 2.0)), 0.01)
	var space: String = str(style.get("dash_space", "count"))
	target.set_shader_parameter("batch_kind", kind_id)
	target.set_shader_parameter("thickness_px", thickness)
	target.set_shader_parameter("aa_width", ANTIALIAS_WIDTH)
	target.set_shader_parameter("filled", bool(style.get("filled", false)))
	target.set_shader_parameter("caps", maxi(CAP_WORDS.find(str(style.get("caps", "round"))), 0))
	target.set_shader_parameter("colour_a", style.get("colour", Color.WHITE))
	target.set_shader_parameter("colour_b", style.get("colour_b", Color.WHITE))
	target.set_shader_parameter("colour_mode", maxi(COLOUR_MODE_WORDS.find(str(style.get("colour_mode", "single"))), 0))
	target.set_shader_parameter("dashed", bool(style.get("dashed", false)))
	target.set_shader_parameter("dash_snap", maxi(DASH_SNAP_WORDS.find(str(style.get("dash_snap", "tiling"))), 0))
	target.set_shader_parameter("dash_style", maxi(DASH_STYLE_WORDS.find(str(style.get("dash_style", "plain"))), 0))
	target.set_shader_parameter("dash_offset", 0.0)
	target.set_shader_parameter("dash_count", int(style.get("dash_count", 12)) if space == "count" else 0)
	target.set_shader_parameter("dash_gap_share", clampf(float(style.get("dash_spacing", 0.5)), 0.0, 0.95))
	var size: float = maxf(float(style.get("dash_size", 12.0)), 0.0)
	var gap: float = maxf(float(style.get("dash_spacing", 6.0)), 0.0)
	target.set_shader_parameter("dash_length_px", size * thickness if space == "relative" else size)
	target.set_shader_parameter("dash_gap_px", gap * thickness if space == "relative" else gap)
