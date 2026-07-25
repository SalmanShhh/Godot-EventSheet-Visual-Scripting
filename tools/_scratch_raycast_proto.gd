@tool
extends SceneTree

const EIGHT_DIRECTION := "res://eventsheet_addons/eight_direction/eight_direction_movement_behavior.gd"
const DRAWING_CANVAS := "res://eventsheet_addons/drawing_canvas/drawing_canvas_behavior.gd"
const OUT_DIR := "res://demo/showcase/_proto_raycast"


func _init() -> void:
	var ok: bool = _build()
	print("[proto] ALL_OK=", ok)
	quit(0 if ok else 1)


func _condition(provider: String, ace_id: String, template: String, params: Dictionary) -> ACECondition:
	var c: ACECondition = ACECondition.new()
	c.provider_id = provider
	c.ace_id = ace_id
	c.codegen_template = template
	c.params = params
	return c


func _action(provider: String, ace_id: String, template: String, params: Dictionary) -> ACEAction:
	var a: ACEAction = ACEAction.new()
	a.provider_id = provider
	a.ace_id = ace_id
	a.codegen_template = template
	a.params = params
	return a


func _set_var(name_of: String, value: String) -> ACEAction:
	return _action("Core", "SetVar", "{var_name} = {value}", {"var_name": name_of, "value": value})


func _raw(code: String) -> RawCodeRow:
	var r: RawCodeRow = RawCodeRow.new()
	r.code = code
	return r


func _attach_behavior(parent: Node, node_name: String, path: String, root: Node, props: Dictionary = {}) -> Node:
	var node: Node = (load(path) as GDScript).new()
	node.name = node_name
	parent.add_child(node)
	node.owner = root
	for key: String in props.keys():
		node.set(key, props[key])
	return node


func _own_deep(node: Node, root: Node) -> void:
	node.owner = root
	for child: Node in node.get_children():
		_own_deep(child, root)


func _compile(sheet: EventSheetResource, gd_path: String) -> bool:
	EventSheetACELifter.lift_function_bodies(sheet)
	EventSheetACELifter.lift_event_bodies(sheet)
	EventSheetACELifter.lift_signal_declarations(sheet, false)
	EventSheetACELifter.lift_function_declarations(sheet, false)
	EventSheets.stabilize_row_uids(sheet)
	DirAccess.make_dir_recursive_absolute(gd_path.get_base_dir())
	var result: Dictionary = SheetCompiler.compile(sheet, gd_path, true)
	print("[proto] compile=", result.get("success", false), " warnings=", result.get("warnings", []), " errors=", result.get("errors", []))
	return bool(result.get("success", false))


func _save_scene(root: Node, path: String) -> bool:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var packed: PackedScene = PackedScene.new()
	var pack_err: Error = packed.pack(root)
	var save_err: Error = ResourceSaver.save(packed, path)
	if save_err == OK:
		var text: String = FileAccess.get_file_as_string(path)
		var re: RegEx = RegEx.new()
		re.compile(" unique_id=\\d+")
		var stripped: String = re.sub(text, "", true)
		if stripped != text:
			var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
			f.store_string(stripped)
			f.close()
	print("[proto] pack=", pack_err, " save=", save_err)
	return pack_err == OK and save_err == OK


func _actor(actor_name: String, world_position: Vector2, tint: Color) -> CharacterBody2D:
	var actor: CharacterBody2D = CharacterBody2D.new()
	actor.name = actor_name
	actor.position = world_position
	var collider: CollisionShape2D = CollisionShape2D.new()
	collider.name = "Collider"
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(22.0, 28.0)
	collider.shape = shape
	actor.add_child(collider)
	var visual: ColorRect = ColorRect.new()
	visual.name = "Visual"
	visual.color = tint
	visual.position = Vector2(-11.0, -14.0)
	visual.size = Vector2(22.0, 28.0)
	actor.add_child(visual)
	return actor


func _build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	sheet.custom_class_name = "RaycastLabDemo"
	sheet.emit_live_values = false
	sheet.variables = {
		"sweep_deg": {"type": "float", "default": 0.0, "exported": false},
		"hit": {"type": "Dictionary", "default": {}, "exported": false},
		"picked": {"type": "Array", "default": [], "exported": false},
		"nearby": {"type": "Array", "default": [], "exported": false},
		"travel": {"type": "float", "default": 1.0, "exported": false},
		"radar_hit": {"type": "bool", "default": false, "exported": false},
		"radar_end": {"type": "Vector2", "default": Vector2.ZERO, "exported": false},
		"radar_normal": {"type": "Vector2", "default": Vector2.ZERO, "exported": false},
		"laser_end": {"type": "Vector2", "default": Vector2.ZERO, "exported": false},
		"laser_normal": {"type": "Vector2", "default": Vector2.ZERO, "exported": false},
		"laser_on_target": {"type": "bool", "default": false, "exported": false},
		"probe_end": {"type": "Vector2", "default": Vector2.ZERO, "exported": false},
		"gate_travel": {"type": "float", "default": 1.0, "exported": false},
		"gate_count": {"type": "int", "default": 0, "exported": false},
		"gate_name": {"type": "String", "default": "", "exported": false}
	}

	var about: CommentRow = CommentRow.new()
	about.text = "[b]Raycast Lab[/b] - six ways to ask the physics world a question, all drawn live."
	sheet.events.append(about)

	var sample: EventRow = EventRow.new()
	sample.trigger_provider_id = "Core"
	sample.trigger_id = "OnPhysicsProcess"
	sample.actions.append(_set_var("sweep_deg", "fmod(sweep_deg + 55.0 * delta, 360.0)"))
	sample.actions.append(_set_var("radar_hit", "false"))
	sample.actions.append(_set_var("laser_on_target", "false"))
	sample.actions.append(_set_var("gate_name", "\"\""))
	sample.actions.append(_action("Core", "SetRotationDeg", "{target.}rotation_degrees = {degrees}", {"degrees": "sweep_deg", "target": "$Player/Radar"}))
	sample.actions.append(_action("Core", "RayCast2DForceUpdate", "{target.}force_raycast_update()", {"target": "$Player/Radar"}))
	sample.actions.append(_set_var("radar_end", "$Player/Radar.to_global($Player/Radar.target_position)"))
	sample.actions.append(_action("Core", "CastRayInto2D",
		"var __rq_laser := PhysicsRayQueryParameters2D.create({from}, {to}, {mask}, {exclude})\n__rq_laser.collide_with_areas = {hit_areas}\n{into} = get_world_2d().direct_space_state.intersect_ray(__rq_laser)",
		{"into": "hit", "from": "$Player.global_position", "to": "get_global_mouse_position()", "mask": "1", "exclude": "[$Player.get_rid()]", "hit_areas": "false"}))
	sample.actions.append(_set_var("laser_end", "get_global_mouse_position()"))
	sample.actions.append(_set_var("laser_normal", "Vector2.ZERO"))
	sample.actions.append(_action("Core", "QueryBodiesUnderMouse2D",
		"var __pq_pick := PhysicsPointQueryParameters2D.new()\n__pq_pick.position = get_global_mouse_position()\n__pq_pick.collide_with_areas = {hit_areas}\n{into} = []\nfor __hit_pick in get_world_2d().direct_space_state.intersect_point(__pq_pick, {max_results}):\n\t{into}.append(__hit_pick.get(\"collider\"))",
		{"into": "picked", "hit_areas": "false", "max_results": "8"}))
	sample.actions.append(_action("Core", "QueryBodiesInCircle2D",
		"var __cs_zone := CircleShape2D.new()\n__cs_zone.radius = {radius}\nvar __sq_zone := PhysicsShapeQueryParameters2D.new()\n__sq_zone.shape = __cs_zone\n__sq_zone.transform = Transform2D(0.0, {center})\n{into} = []\nfor __hit_zone in get_world_2d().direct_space_state.intersect_shape(__sq_zone, {max_results}):\n\t{into}.append(__hit_zone.get(\"collider\"))",
		{"into": "nearby", "center": "$Player.global_position", "radius": "130.0", "max_results": "16"}))
	sample.actions.append(_action("Core", "CastCircleMotion2D",
		"var __cs_probe := CircleShape2D.new()\n__cs_probe.radius = {radius}\nvar __sq_probe := PhysicsShapeQueryParameters2D.new()\n__sq_probe.shape = __cs_probe\n__sq_probe.transform = Transform2D(0.0, {from})\n__sq_probe.motion = {motion}\n__sq_probe.collision_mask = {mask}\nvar __cm_probe := get_world_2d().direct_space_state.cast_motion(__sq_probe)\n{into} = __cm_probe[0] if __cm_probe.size() > 0 else 1.0",
		{"into": "travel", "from": "$Player.global_position", "motion": "get_global_mouse_position() - $Player.global_position", "radius": "18.0", "mask": "1"}))
	sample.actions.append(_set_var("probe_end", "$Player.global_position + (get_global_mouse_position() - $Player.global_position) * travel"))
	sample.actions.append(_action("Core", "ShapeCast2DForceUpdate", "{target.}force_shapecast_update()", {"target": "$Gate"}))
	sample.actions.append(_set_var("gate_count", "$Gate.get_collision_count()"))
	sample.actions.append(_set_var("gate_travel", "$Gate.get_closest_collision_safe_fraction()"))

	var radar_hit_row: EventRow = EventRow.new()
	radar_hit_row.conditions.append(_condition("Core", "RayCast2DIsColliding", "{target.}is_colliding()", {"target": "$Player/Radar"}))
	radar_hit_row.actions.append(_set_var("radar_hit", "true"))
	radar_hit_row.actions.append(_set_var("radar_end", "$Player/Radar.get_collision_point()"))
	radar_hit_row.actions.append(_set_var("radar_normal", "$Player/Radar.get_collision_normal()"))
	sample.sub_events.append(radar_hit_row)

	var laser_hit_row: EventRow = EventRow.new()
	laser_hit_row.conditions.append(_condition("Core", "RayResultHit2D", "not {result}.is_empty()", {"result": "hit"}))
	laser_hit_row.actions.append(_set_var("laser_end", "hit.get(\"position\", Vector2.ZERO)"))
	laser_hit_row.actions.append(_set_var("laser_normal", "hit.get(\"normal\", Vector2.ZERO)"))
	var laser_group_row: EventRow = EventRow.new()
	laser_group_row.conditions.append(_condition("Core", "RayResultInGroup2D",
		"({result}.get(\"collider\", null) != null and {result}[\"collider\"].is_in_group({group}))",
		{"result": "hit", "group": "\"targets\""}))
	laser_group_row.actions.append(_set_var("laser_on_target", "true"))
	laser_hit_row.sub_events.append(laser_group_row)
	sample.sub_events.append(laser_hit_row)

	var gate_row: EventRow = EventRow.new()
	gate_row.conditions.append(_condition("Core", "ShapeCast2DIsColliding", "{target.}is_colliding()", {"target": "$Gate"}))
	gate_row.actions.append(_set_var("gate_name", "$Gate.get_collider(0).name"))
	sample.sub_events.append(gate_row)

	sheet.events.append(sample)

	var paint: EventRow = EventRow.new()
	paint.trigger_provider_id = "Core"
	paint.trigger_id = "OnProcess"
	paint.actions.append(_raw("\n".join(PackedStringArray([
		"var ink: DrawingCanvas = $InkLayer/Ink",
		"var player_pos: Vector2 = $Player.global_position",
		"var mouse_pos: Vector2 = get_global_mouse_position()",
		"# RAYCAST2D NODE - the sweeping radar. Dim to its full reach, bright to what it found.",
		"ink.draw_canvas_line(player_pos.x, player_pos.y, radar_end.x, radar_end.y, 2.0, Color(1.0, 0.85, 0.3, 0.45))",
		"if radar_hit:",
		"\tink.draw_canvas_line(player_pos.x, player_pos.y, radar_end.x, radar_end.y, 3.0, Color(1.0, 0.85, 0.3, 0.95))",
		"\tink.draw_canvas_ring(radar_end.x, radar_end.y, 9.0, 2.0, Color(1.0, 0.85, 0.3, 1.0))",
		"\tink.draw_canvas_line(radar_end.x, radar_end.y, radar_end.x + radar_normal.x * 26.0, radar_end.y + radar_normal.y * 26.0, 2.0, Color(1.0, 1.0, 1.0, 0.8))",
		"# QUERY BODIES IN CIRCLE - the 130px scan ring and a mark on everything it collected.",
		"ink.draw_canvas_dashed_ring(player_pos.x, player_pos.y, 130.0, 9.0, 7.0, 1.0, Color(0.45, 1.0, 0.6, 0.5))",
		"for body: Node2D in nearby:",
		"\tink.draw_canvas_ring(body.global_position.x, body.global_position.y, 20.0, 2.0, Color(0.45, 1.0, 0.6, 0.75))",
		"# CAST RAY INTO - the cursor laser, stopped at the first thing in the way.",
		"ink.draw_canvas_line(player_pos.x, player_pos.y, laser_end.x, laser_end.y, 2.0, Color(0.4, 0.85, 1.0, 0.9))",
		"if laser_normal != Vector2.ZERO:",
		"\tink.draw_canvas_ring(laser_end.x, laser_end.y, 7.0, 2.0, Color(0.4, 0.85, 1.0, 1.0))",
		"\tink.draw_canvas_line(laser_end.x, laser_end.y, laser_end.x + laser_normal.x * 24.0, laser_end.y + laser_normal.y * 24.0, 2.0, Color(1.0, 1.0, 1.0, 0.7))",
		"if laser_on_target:",
		"\tink.draw_canvas_ring(laser_end.x, laser_end.y, 16.0, 3.0, Color(1.0, 0.55, 0.2, 1.0))",
		"# CAST CIRCLE MOTION - how far an 18px disc could slide toward the cursor before it jams.",
		"ink.draw_canvas_dashed_line(player_pos.x, player_pos.y, probe_end.x, probe_end.y, 8.0, 6.0, 1.0, Color(1.0, 0.45, 0.85, 0.5))",
		"ink.draw_canvas_ring(probe_end.x, probe_end.y, 18.0, 2.0, Color(1.0, 0.45, 0.85, 0.9))",
		"# QUERY BODIES UNDER MOUSE - a ring around whatever the cursor is sitting on.",
		"ink.draw_canvas_ring(mouse_pos.x, mouse_pos.y, 5.0, 1.0, Color(1.0, 1.0, 1.0, 0.5))",
		"for body: Node2D in picked:",
		"\tink.draw_canvas_ring(body.global_position.x, body.global_position.y, 30.0, 3.0, Color(1.0, 1.0, 1.0, 0.9))",
		"# SHAPECAST2D NODE - the rail it sweeps, and the disc parked at its safe fraction.",
		"var gate_pos: Vector2 = $Gate.global_position",
		"var gate_reach: Vector2 = $Gate.target_position",
		"ink.draw_canvas_dashed_line(gate_pos.x, gate_pos.y, gate_pos.x + gate_reach.x, gate_pos.y + gate_reach.y, 10.0, 8.0, 1.0, Color(0.5, 0.7, 1.0, 0.45))",
		"ink.draw_canvas_ring(gate_pos.x + gate_reach.x * gate_travel, gate_pos.y + gate_reach.y * gate_travel, 16.0, 2.0, Color(0.5, 0.7, 1.0, 0.9))",
		"$HudLayer/Readout.text = \"under cursor %d - in circle %d - disc travel %.2f - gate sweep %.2f - gate sees %s\" % [picked.size(), nearby.size(), travel, gate_travel, gate_name if gate_count > 0 else \"nothing\"]"
	]))))
	sheet.events.append(paint)

	var gd_path: String = OUT_DIR + "/raycast_lab.gd"
	if not _compile(sheet, gd_path):
		return false
	var emitted: String = FileAccess.get_file_as_string(gd_path)
	emitted = emitted.replace("\n\nfunc ", "\n\n\nfunc ")
	emitted = emitted.replace("\n\n## @ace_hidden\nfunc ", "\n\n\n## @ace_hidden\nfunc ")
	var out: FileAccess = FileAccess.open(gd_path, FileAccess.WRITE)
	out.store_string(emitted)
	out.close()

	var root: Node2D = Node2D.new()
	root.name = "RaycastLab"
	root.set_script(load(gd_path))
	var backdrop: ColorRect = ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = Color(0.075, 0.085, 0.11)
	backdrop.size = Vector2(1152.0, 648.0)
	root.add_child(backdrop)
	backdrop.owner = root

	var wall_index: int = 0
	for wall_spec: Array in [[Vector2(576.0, 150.0), Vector2(420.0, 28.0)], [Vector2(352.0, 330.0), Vector2(28.0, 240.0)], [Vector2(830.0, 320.0), Vector2(28.0, 260.0)], [Vector2(600.0, 520.0), Vector2(360.0, 28.0)]]:
		var wall: StaticBody2D = StaticBody2D.new()
		wall.name = "Wall%d" % wall_index
		wall_index += 1
		wall.position = wall_spec[0]
		wall.collision_layer = 1
		var wall_shape: CollisionShape2D = CollisionShape2D.new()
		wall_shape.name = "Shape"
		var wall_rect: RectangleShape2D = RectangleShape2D.new()
		wall_rect.size = wall_spec[1]
		wall_shape.shape = wall_rect
		wall.add_child(wall_shape)
		var wall_visual: ColorRect = ColorRect.new()
		wall_visual.name = "Visual"
		wall_visual.color = Color(0.36, 0.4, 0.5)
		wall_visual.position = -(wall_spec[1] as Vector2) / 2.0
		wall_visual.size = wall_spec[1]
		wall.add_child(wall_visual)
		root.add_child(wall)
		_own_deep(wall, root)

	var block_index: int = 0
	for block_pos: Vector2 in [Vector2(520.0, 250.0), Vector2(700.0, 400.0), Vector2(960.0, 480.0), Vector2(250.0, 470.0)]:
		var block: StaticBody2D = StaticBody2D.new()
		block.name = "Target%d" % block_index
		block_index += 1
		block.position = block_pos
		block.collision_layer = 1
		var block_shape: CollisionShape2D = CollisionShape2D.new()
		block_shape.name = "Shape"
		var block_rect: RectangleShape2D = RectangleShape2D.new()
		block_rect.size = Vector2(44.0, 44.0)
		block_shape.shape = block_rect
		block.add_child(block_shape)
		var block_visual: ColorRect = ColorRect.new()
		block_visual.name = "Visual"
		block_visual.color = Color(0.85, 0.55, 0.22)
		block_visual.position = Vector2(-22.0, -22.0)
		block_visual.size = Vector2(44.0, 44.0)
		block.add_child(block_visual)
		root.add_child(block)
		_own_deep(block, root)
		block.add_to_group("targets", true)

	var ink_layer: Node2D = Node2D.new()
	ink_layer.name = "InkLayer"
	ink_layer.position = Vector2(576.0, 324.0)
	root.add_child(ink_layer)
	ink_layer.owner = root
	_attach_behavior(ink_layer, "Ink", DRAWING_CANVAS, root, {"canvas_width": 1152, "canvas_height": 648, "auto_clear": true})

	var gate: ShapeCast2D = ShapeCast2D.new()
	gate.name = "Gate"
	gate.position = Vector2(120.0, 600.0)
	gate.target_position = Vector2(400.0, 0.0)
	gate.collision_mask = 2
	var gate_shape: CircleShape2D = CircleShape2D.new()
	gate_shape.radius = 16.0
	gate.shape = gate_shape
	root.add_child(gate)
	gate.owner = root

	var player: CharacterBody2D = _actor("Player", Vector2(250.0, 300.0), Color(0.35, 0.65, 1.0))
	player.collision_layer = 2
	player.collision_mask = 1
	root.add_child(player)
	_own_deep(player, root)
	_attach_behavior(player, "Movement", EIGHT_DIRECTION, root)
	var radar: RayCast2D = RayCast2D.new()
	radar.name = "Radar"
	radar.target_position = Vector2(0.0, -230.0)
	radar.collision_mask = 1
	player.add_child(radar)
	radar.owner = root

	var hud_layer: CanvasLayer = CanvasLayer.new()
	hud_layer.name = "HudLayer"
	root.add_child(hud_layer)
	hud_layer.owner = root
	var hud: Label = Label.new()
	hud.name = "Hud"
	hud.position = Vector2(24.0, 14.0)
	hud.add_theme_font_size_override("font_size", 18)
	hud.text = "Arrows / WASD move - the mouse aims everything that points at the cursor"
	hud_layer.add_child(hud)
	hud.owner = root
	var readout: Label = Label.new()
	readout.name = "Readout"
	readout.position = Vector2(24.0, 44.0)
	readout.add_theme_font_size_override("font_size", 16)
	readout.text = "under cursor 0"
	hud_layer.add_child(readout)
	readout.owner = root

	return _save_scene(root, OUT_DIR + "/raycast_lab.tscn")
