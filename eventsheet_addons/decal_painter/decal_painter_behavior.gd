## @ace_tags(3d, drawing, visual)
## @ace_category("Decal Painter")
@icon("res://eventsheet_addons/behavior.svg")
class_name DecalPainter
extends Node

## The node this behavior acts on (its parent). Required host: Node3D.
var host: Node3D = null

func _enter_tree() -> void:
	host = get_parent() as Node3D
	if host == null:
		push_warning("DecalPainter behavior requires a Node3D parent.")

# --- Designer knobs (tune in the Inspector) ---
## The most spawned decals kept alive - the oldest is freed when the cap is hit.
@export var max_decals: int = 64
## Seconds a decal spends fading out when its lifetime ends.
@export var fade_seconds: float = 0.5

# --- Internal state ---
var _decals: Array = []
var _blobs: Array = []
var _clock: float = 0.0
## The parent every spawned Decal goes under (the host, so decals live in the world).
## @ace_hidden
func _decal_parent() -> Node:
	return host if host != null else self
## The soft radial shadow texture, generated - no asset needed.
## @ace_hidden
func _blob_texture(opacity: float) -> GradientTexture2D:
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, Color(0.0, 0.0, 0.0, clampf(opacity, 0.0, 1.0)))
	gradient.set_color(1, Color(0.0, 0.0, 0.0, 0.0))
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	texture.width = 128
	texture.height = 128
	return texture

func _physics_process(delta: float) -> void:
	_clock += delta
	var kept: Array = []
	for entry: Dictionary in _decals:
		var decal: Decal = entry["node"] if is_instance_valid(entry["node"]) else null
		if decal == null:
			continue
		var lifetime: float = float(entry["lifetime"])
		if lifetime > 0.0:
			var age: float = _clock - float(entry["born"])
			if age >= lifetime + fade_seconds:
				decal.queue_free()
				continue
			if age >= lifetime:
				decal.modulate.a = 1.0 - (age - lifetime) / maxf(fade_seconds, 0.01)
		kept.append(entry)
	_decals = kept
	var live_blobs: Array = []
	for blob: Dictionary in _blobs:
		var followed: Node3D = instance_from_id(int(blob["id"])) as Node3D
		var decal: Decal = blob["decal"] if is_instance_valid(blob["decal"]) else null
		if followed == null or decal == null:
			if decal != null:
				decal.queue_free()
			continue
		live_blobs.append(blob)
		# Ground snap: a ray straight down from the followed node against the floor mask;
		# the deep projection box catches slopes and small steps around the hit.
		var at: Vector3 = followed.global_position
		if is_inside_tree():
			var space: PhysicsDirectSpaceState3D = (host as Node3D).get_world_3d().direct_space_state if host is Node3D else null
			if space != null:
				var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.5, at + Vector3.DOWN * 100.0, int(blob["mask"]))
				var hit: Dictionary = space.intersect_ray(query)
				if not hit.is_empty():
					at = hit["position"]
		decal.global_position = at + Vector3.UP * 0.05
	_blobs = live_blobs

func _track(decal: Decal, lifetime: float) -> void:
	_decals.append({"node": decal, "born": _clock, "lifetime": lifetime})
	while _decals.size() > maxi(max_decals, 1):
		var oldest: Dictionary = _decals.pop_front()
		if is_instance_valid(oldest["node"]):
			(oldest["node"] as Decal).queue_free()

## @ace_expression
## @ace_name("Decal Count")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$DecalPainter.decal_count()")
func decal_count() -> int:
	var alive: int = 0
	for entry: Dictionary in _decals:
		if is_instance_valid(entry["node"]):
			alive += 1
	return alive

func spawn_decal(texture: Texture2D, x: float, y: float, z: float, size: float, rotation_deg: float, lifetime: float) -> void:
	var decal: Decal = Decal.new()
	decal.texture_albedo = texture
	decal.size = Vector3(maxf(size, 0.05), 4.0, maxf(size, 0.05))
	_decal_parent().add_child(decal)
	decal.global_position = Vector3(x, y, z)
	decal.rotate_y(deg_to_rad(rotation_deg))
	_track(decal, maxf(lifetime, 0.0))

func spawn_blob_shadow(follow: Node, radius: float, opacity: float, collision_mask_3d: int) -> void:
	if not (follow is Node3D):
		return
	stop_blob_shadow(follow)
	var decal: Decal = Decal.new()
	decal.texture_albedo = _blob_texture(opacity)
	decal.size = Vector3(radius * 2.0, 4.0, radius * 2.0)
	_decal_parent().add_child(decal)
	decal.global_position = (follow as Node3D).global_position
	_blobs.append({"id": follow.get_instance_id(), "decal": decal, "mask": collision_mask_3d})

func stop_blob_shadow(follow: Node) -> void:
	if follow == null:
		return
	var kept: Array = []
	for blob: Dictionary in _blobs:
		if int(blob["id"]) == follow.get_instance_id():
			if is_instance_valid(blob["decal"]):
				(blob["decal"] as Decal).queue_free()
		else:
			kept.append(blob)
	_blobs = kept

func spawn_canvas_decal(canvas: Node, x: float, y: float, z: float, size: float, rotation_deg: float) -> void:
	if canvas == null or not canvas.has_method("canvas_texture"):
		return
	spawn_decal(canvas.call("canvas_texture") as Texture2D, x, y, z, size, rotation_deg, 0.0)

func clear_decals() -> void:
	for entry: Dictionary in _decals:
		if is_instance_valid(entry["node"]):
			(entry["node"] as Decal).queue_free()
	_decals = []
	for blob: Dictionary in _blobs:
		if is_instance_valid(blob["decal"]):
			(blob["decal"] as Decal).queue_free()
	_blobs = []

func set_max_decals(count: int) -> void:
	max_decals = maxi(count, 1)
	while _decals.size() > max_decals:
		var oldest: Dictionary = _decals.pop_front()
		if is_instance_valid(oldest["node"]):
			(oldest["node"] as Decal).queue_free()

# Decal Painter behavior (3D): sheet-driven Decal nodes - Spawn Decal stamps a texture onto world surfaces (splats, scorch marks, target rings) with an optional lifetime and a max-decals FIFO cap; Spawn Blob Shadow keeps a soft procedural shadow ground-snapped under a character (raycast vs your floor mask); Spawn Canvas Decal projects a 2D Drawing Canvas's live texture onto the world. This pack is an event sheet - extend it by editing it.
