# Pack builder - decal_painter (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## DecalPainter: spawns and manages Godot Decal nodes from the sheet - blob shadows that
## follow characters (ground-snapped by raycast), splats and scorch marks with lifetimes and
## a FIFO cap, and decals textured straight from a 2D Drawing Canvas (draw the shape in 2D,
## project it onto the 3D world).
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "Node3D"
	sheet.custom_class_name = "DecalPainter"
	sheet.addon_category = "Decal Painter"
	sheet.addon_tags = PackedStringArray(["3d", "drawing", "visual"])
	var about: CommentRow = CommentRow.new()
	about.text = "Decal Painter behavior (3D): sheet-driven Decal nodes - Spawn Decal stamps a texture onto world surfaces (splats, scorch marks, target rings) with an optional lifetime and a max-decals FIFO cap; Spawn Blob Shadow keeps a soft procedural shadow ground-snapped under a character (raycast vs your floor mask); Spawn Canvas Decal projects a 2D Drawing Canvas's live texture onto the world. This pack is an event sheet - extend it by editing it."
	sheet.events.append(about)
	var block: RawCodeRow = RawCodeRow.new()
	block.code = "\n".join(PackedStringArray([
		"# --- Designer knobs (tune in the Inspector) ---",
		"## The most spawned decals kept alive - the oldest is freed when the cap is hit.",
		"@export var max_decals: int = 64",
		"## Seconds a decal spends fading out when its lifetime ends.",
		"@export var fade_seconds: float = 0.5",
		"",
		"# --- Internal state ---",
		"var _decals: Array = []",
		"var _blobs: Array = []",
		"var _clock: float = 0.0",
		"",
		"## The parent every spawned Decal goes under (the host, so decals live in the world).",
		"## @ace_hidden",
		"func _decal_parent() -> Node:",
		"\treturn host if host != null else self",
		"",
		"## Registers a spawned decal in the FIFO ledger and enforces the cap.",
		"## @ace_hidden",
		"func _track(decal: Decal, lifetime: float) -> void:",
		"\t_decals.append({\"node\": decal, \"born\": _clock, \"lifetime\": lifetime})",
		"\twhile _decals.size() > maxi(max_decals, 1):",
		"\t\tvar oldest: Dictionary = _decals.pop_front()",
		"\t\tif is_instance_valid(oldest[\"node\"]):",
		"\t\t\t(oldest[\"node\"] as Decal).queue_free()",
		"",
		"## The soft radial shadow texture, generated - no asset needed.",
		"## @ace_hidden",
		"func _blob_texture(opacity: float) -> GradientTexture2D:",
		"\tvar gradient: Gradient = Gradient.new()",
		"\tgradient.set_color(0, Color(0.0, 0.0, 0.0, clampf(opacity, 0.0, 1.0)))",
		"\tgradient.set_color(1, Color(0.0, 0.0, 0.0, 0.0))",
		"\tvar texture: GradientTexture2D = GradientTexture2D.new()",
		"\ttexture.gradient = gradient",
		"\ttexture.fill = GradientTexture2D.FILL_RADIAL",
		"\ttexture.fill_from = Vector2(0.5, 0.5)",
		"\ttexture.fill_to = Vector2(0.5, 0.0)",
		"\ttexture.width = 128",
		"\ttexture.height = 128",
		"\treturn texture",
		"",
		"## @ace_expression",
		"## @ace_name(\"Decal Count\")",
		"func decal_count() -> int:",
		"\tvar alive: int = 0",
		"\tfor entry: Dictionary in _decals:",
		"\t\tif is_instance_valid(entry[\"node\"]):",
		"\t\t\talive += 1",
		"\treturn alive"
	]))
	sheet.events.append(block)

	# Physics tick: age lifetimes (fade then free) and keep blob shadows ground-snapped
	# under their followed nodes.
	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"
	tick.trigger_id = "OnPhysicsProcess"
	var tick_body: RawCodeRow = RawCodeRow.new()
	tick_body.code = "\n".join(PackedStringArray([
		"_clock += delta",
		"var kept: Array = []",
		"for entry: Dictionary in _decals:",
		"\tvar decal: Decal = entry[\"node\"] if is_instance_valid(entry[\"node\"]) else null",
		"\tif decal == null:",
		"\t\tcontinue",
		"\tvar lifetime: float = float(entry[\"lifetime\"])",
		"\tif lifetime > 0.0:",
		"\t\tvar age: float = _clock - float(entry[\"born\"])",
		"\t\tif age >= lifetime + fade_seconds:",
		"\t\t\tdecal.queue_free()",
		"\t\t\tcontinue",
		"\t\tif age >= lifetime:",
		"\t\t\tdecal.modulate.a = 1.0 - (age - lifetime) / maxf(fade_seconds, 0.01)",
		"\tkept.append(entry)",
		"_decals = kept",
		"var live_blobs: Array = []",
		"for blob: Dictionary in _blobs:",
		"\tvar followed: Node3D = instance_from_id(int(blob[\"id\"])) as Node3D",
		"\tvar decal: Decal = blob[\"decal\"] if is_instance_valid(blob[\"decal\"]) else null",
		"\tif followed == null or decal == null:",
		"\t\tif decal != null:",
		"\t\t\tdecal.queue_free()",
		"\t\tcontinue",
		"\tlive_blobs.append(blob)",
		"\t# Ground snap: a ray straight down from the followed node against the floor mask;",
		"\t# the deep projection box catches slopes and small steps around the hit.",
		"\tvar at: Vector3 = followed.global_position",
		"\tif is_inside_tree():",
		"\t\tvar space: PhysicsDirectSpaceState3D = (host as Node3D).get_world_3d().direct_space_state if host is Node3D else null",
		"\t\tif space != null:",
		"\t\t\tvar query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.5, at + Vector3.DOWN * 100.0, int(blob[\"mask\"]))",
		"\t\t\tvar hit: Dictionary = space.intersect_ray(query)",
		"\t\t\tif not hit.is_empty():",
		"\t\t\t\tat = hit[\"position\"]",
		"\tdecal.global_position = at + Vector3.UP * 0.05",
		"_blobs = live_blobs"
	]))
	tick.actions.append(tick_body)
	sheet.events.append(tick)

	# ── Spawning verbs (raw-block annotated: typed params + the collision-mask picker) ──
	var verbs: RawCodeRow = RawCodeRow.new()
	verbs.code = "\n".join(PackedStringArray([
		"## Stamps a decal onto the world at a position - splats, scorch marks, target rings.",
		"## Lifetime 0 keeps it forever (until the max-decals cap recycles it).",
		"## @ace_action",
		"## @ace_name(\"Spawn Decal\")",
		"func spawn_decal(texture: Texture2D, x: float, y: float, z: float, size: float, rotation_deg: float, lifetime: float) -> void:",
		"\tvar decal: Decal = Decal.new()",
		"\tdecal.texture_albedo = texture",
		"\tdecal.size = Vector3(maxf(size, 0.05), 4.0, maxf(size, 0.05))",
		"\t_decal_parent().add_child(decal)",
		"\tdecal.global_position = Vector3(x, y, z)",
		"\tdecal.rotate_y(deg_to_rad(rotation_deg))",
		"\t_track(decal, maxf(lifetime, 0.0))",
		"",
		"## Keeps a soft shadow blob ground-snapped under a node - the classic character",
		"## shadow, no asset needed. The floor is found by raycast against the collision mask.",
		"## @ace_action",
		"## @ace_name(\"Spawn Blob Shadow\")",
		"func spawn_blob_shadow(follow: Node, radius: float, opacity: float, collision_mask_3d: int) -> void:",
		"\tif not (follow is Node3D):",
		"\t\treturn",
		"\tstop_blob_shadow(follow)",
		"\tvar decal: Decal = Decal.new()",
		"\tdecal.texture_albedo = _blob_texture(opacity)",
		"\tdecal.size = Vector3(radius * 2.0, 4.0, radius * 2.0)",
		"\t_decal_parent().add_child(decal)",
		"\tdecal.global_position = (follow as Node3D).global_position",
		"\t_blobs.append({\"id\": follow.get_instance_id(), \"decal\": decal, \"mask\": collision_mask_3d})",
		"",
		"## Removes the blob shadow following a node.",
		"## @ace_action",
		"## @ace_name(\"Stop Blob Shadow\")",
		"func stop_blob_shadow(follow: Node) -> void:",
		"\tif follow == null:",
		"\t\treturn",
		"\tvar kept: Array = []",
		"\tfor blob: Dictionary in _blobs:",
		"\t\tif int(blob[\"id\"]) == follow.get_instance_id():",
		"\t\t\tif is_instance_valid(blob[\"decal\"]):",
		"\t\t\t\t(blob[\"decal\"] as Decal).queue_free()",
		"\t\telse:",
		"\t\t\tkept.append(blob)",
		"\t_blobs = kept",
		"",
		"## Projects a 2D Drawing Canvas's LIVE texture onto the world as a decal - draw a",
		"## line-of-sight fan or telegraph in 2D and paint it on the 3D floor. Pass the",
		"## DrawingCanvas behavior node; the decal updates as the canvas draws.",
		"## @ace_action",
		"## @ace_name(\"Spawn Canvas Decal\")",
		"func spawn_canvas_decal(canvas: Node, x: float, y: float, z: float, size: float, rotation_deg: float) -> void:",
		"\tif canvas == null or not canvas.has_method(\"canvas_texture\"):",
		"\t\treturn",
		"\tspawn_decal(canvas.call(\"canvas_texture\") as Texture2D, x, y, z, size, rotation_deg, 0.0)",
		"",
		"## Frees every spawned decal and blob shadow.",
		"## @ace_action",
		"## @ace_name(\"Clear Decals\")",
		"func clear_decals() -> void:",
		"\tfor entry: Dictionary in _decals:",
		"\t\tif is_instance_valid(entry[\"node\"]):",
		"\t\t\t(entry[\"node\"] as Decal).queue_free()",
		"\t_decals = []",
		"\tfor blob: Dictionary in _blobs:",
		"\t\tif is_instance_valid(blob[\"decal\"]):",
		"\t\t\t(blob[\"decal\"] as Decal).queue_free()",
		"\t_blobs = []",
		"",
		"## Changes the FIFO cap - the oldest decals free immediately if over it.",
		"## @ace_action",
		"## @ace_name(\"Set Max Decals\")",
		"func set_max_decals(count: int) -> void:",
		"\tmax_decals = maxi(count, 1)",
		"\twhile _decals.size() > max_decals:",
		"\t\tvar oldest: Dictionary = _decals.pop_front()",
		"\t\tif is_instance_valid(oldest[\"node\"]):",
		"\t\t\t(oldest[\"node\"] as Decal).queue_free()"
	]))
	sheet.events.append(verbs)

	return Lib.save_pack(sheet, "res://eventsheet_addons/decal_painter/decal_painter_behavior")
