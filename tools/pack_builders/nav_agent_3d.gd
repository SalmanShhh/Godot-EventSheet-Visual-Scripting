# Pack builder - nav_agent_3d (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## 3D pathfinding made sheet-shaped: a thin
## wrapper over Godot's navmesh navigation with THE SAME verb names as the 2D Platformer
## Pathfinding pack (Find Path To, Stop Pathfinding, the Found/Failed/Complete trio, Has Path).
## A NavigationAgent3D child is auto-inserted (zero wiring); auto-control drives a sibling that
## carries the universal AI seam (the FPS Controller's ai_move_x/ai_move_z) or, with no driver,
## moves the CharacterBody3D itself. 3D "slopes" are inherent to the navmesh bake - nothing to
## register; Bake Navigation Region rebakes at runtime.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "CharacterBody3D"
	sheet.custom_class_name = "NavAgent3D"
	sheet.class_description = "Navmesh pathfinding for 3D with zero wiring: attach under a CharacterBody3D, keep a NavigationRegion3D in the scene, and call Find Path To - a NavigationAgent3D child is inserted and tuned for you and the agent walks the baked navmesh. The verbs mirror the 2D Platformer Pathfinding pack, so learning one pack teaches both."
	sheet.addon_category = "Nav Agent 3D"
	sheet.ace_expose_all_mode = "node"
	sheet.addon_tags = PackedStringArray(["movement", "3d", "ai", "pathfinding"])
	sheet.variables = {
		"auto_control": {"type": "bool", "default": true, "exported": true,
			"attributes": {"tooltip": "Drive the sibling FPS Controller (or the body itself) automatically. Off = paths still compute; read Path Move X/Z and steer yourself."}},
		"move_speed": {"type": "float", "default": 4.0, "exported": true,
			"attributes": {"tooltip": "The built-in driver's speed (m/s). A driver sibling uses its own speed."}},
		"gravity": {"type": "float", "default": 9.8, "exported": true,
			"attributes": {"tooltip": "The built-in driver's gravity (a driver sibling applies its own)."}},
		"agent_radius": {"type": "float", "default": 0.5, "exported": true,
			"attributes": {"tooltip": "The navigation agent's radius (match your collider)."}},
		"agent_height": {"type": "float", "default": 1.8, "exported": true,
			"attributes": {"tooltip": "The navigation agent's height."}},
		"target_desired_distance": {"type": "float", "default": 1.0, "exported": true,
			"attributes": {"tooltip": "How close (m) counts as having arrived at the target."}},
		"avoidance_enabled": {"type": "bool", "default": false, "exported": true,
			"attributes": {"tooltip": "Agents steer around each other (applies to the built-in driver; a driver sibling owns its own velocity)."}},
	}

	var about: CommentRow = CommentRow.new()
	about.text = "3D pathfinding on Godot's navmesh, sheet-shaped: attach under a CharacterBody3D inside a scene with a NavigationRegion3D and call Find Path To - a NavigationAgent3D child is inserted for you. The verbs mirror the 2D Platformer Pathfinding pack, auto-control drives the FPS Controller through the universal AI seam (or the body itself when no driver exists), and slopes come free from the navmesh bake."
	sheet.events.append(about)

	var block: RawCodeRow = RawCodeRow.new()
	block.code = "\n".join(PackedStringArray([
		"# --- Internal state ---",
		"var _agent: NavigationAgent3D = null",
		"var _driver: Node = null",
		"var _active: bool = false",
		"var _pending_check: bool = false",
		"var _pending_mode: String = \"nearest\"",
		"var _move_x: float = 0.0",
		"var _move_z: float = 0.0",
		"var _safe_velocity: Vector3 = Vector3.ZERO",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Path Found\")",
		"signal path_found",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Path Failed\")",
		"signal path_failed",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Path Complete\")",
		"signal path_complete",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Waypoint Reached\")",
		"signal waypoint_reached",
		"",
		"## @ace_condition",
		"## @ace_name(\"Has Path\")",
		"func has_path() -> bool:",
		"\treturn _active",
		"",
		"## @ace_condition",
		"## @ace_name(\"Target Is Reachable\")",
		"func target_is_reachable() -> bool:",
		"\treturn _agent != null and is_instance_valid(_agent) and _agent.is_target_reachable()",
		"",
		"## @ace_expression",
		"## @ace_name(\"Current Waypoint X\")",
		"func current_waypoint_x() -> float:",
		"\treturn _agent.get_next_path_position().x if _active and _agent != null else 0.0",
		"",
		"## @ace_expression",
		"## @ace_name(\"Current Waypoint Y\")",
		"func current_waypoint_y() -> float:",
		"\treturn _agent.get_next_path_position().y if _active and _agent != null else 0.0",
		"",
		"## @ace_expression",
		"## @ace_name(\"Current Waypoint Z\")",
		"func current_waypoint_z() -> float:",
		"\treturn _agent.get_next_path_position().z if _active and _agent != null else 0.0",
		"",
		"## @ace_expression",
		"## @ace_name(\"Distance To Target\")",
		"func distance_to_target() -> float:",
		"\treturn host.global_position.distance_to(_agent.target_position) if _active and _agent != null and host != null else 0.0",
		"",
		"## @ace_expression",
		"## @ace_name(\"Path Move X\")",
		"func path_move_x() -> float:",
		"\treturn _move_x",
		"",
		"## @ace_expression",
		"## @ace_name(\"Path Move Z\")",
		"func path_move_z() -> float:",
		"\treturn _move_z",
		"",
		"## The NavigationAgent3D child, inserted and tuned on first use - the zero-wiring promise.",
		"## @ace_hidden",
		"func _ensure_agent() -> NavigationAgent3D:",
		"\tif _agent != null and is_instance_valid(_agent):",
		"\t\treturn _agent",
		"\tif host == null:",
		"\t\treturn null",
		"\t_agent = host.get_node_or_null(\"NavAgent\") as NavigationAgent3D",
		"\tif _agent == null:",
		"\t\t_agent = NavigationAgent3D.new()",
		"\t\t_agent.name = \"NavAgent\"",
		"\t\thost.add_child(_agent)",
		"\t_agent.radius = agent_radius",
		"\t_agent.height = agent_height",
		"\t_agent.target_desired_distance = target_desired_distance",
		"\t_agent.path_desired_distance = 0.6",
		"\t_agent.avoidance_enabled = avoidance_enabled",
		"\tif not _agent.waypoint_reached.is_connected(_on_agent_waypoint):",
		"\t\t_agent.waypoint_reached.connect(_on_agent_waypoint)",
		"\tif not _agent.velocity_computed.is_connected(_on_safe_velocity):",
		"\t\t_agent.velocity_computed.connect(_on_safe_velocity)",
		"\treturn _agent",
		"",
		"## @ace_hidden",
		"func _on_agent_waypoint(_details: Dictionary) -> void:",
		"\twaypoint_reached.emit()",
		"",
		"## @ace_hidden",
		"func _on_safe_velocity(safe_velocity: Vector3) -> void:",
		"\t_safe_velocity = safe_velocity",
		"",
		"## The driver sibling, duck-typed on the universal AI seam (ai_controlled + ai_move_x/z -",
		"## the FPS Controller carries it; so can your own controller).",
		"## @ace_hidden",
		"func _find_driver() -> Node:",
		"\tif _driver != null and is_instance_valid(_driver):",
		"\t\treturn _driver",
		"\tif host == null:",
		"\t\treturn null",
		"\tfor child in host.get_children():",
		"\t\tif child != self and child.get(\"ai_move_z\") != null and child.get(\"ai_controlled\") != null:",
		"\t\t\t_driver = child",
		"\t\t\treturn _driver",
		"\treturn null"
	]))
	sheet.events.append(block)

	var on_ready: EventRow = EventRow.new()
	on_ready.trigger_provider_id = "Core"
	on_ready.trigger_id = "OnReady"
	var ready_body: RawCodeRow = RawCodeRow.new()
	ready_body.code = "_ensure_agent()"
	on_ready.actions.append(ready_body)
	sheet.events.append(on_ready)

	# Per-physics-tick drive: reachability verdict one tick after a request (the nav server
	# needs a sync), then steer the driver sibling or the body toward the agent's next point.
	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"
	tick.trigger_id = "OnPhysicsProcess"
	var tick_body: RawCodeRow = RawCodeRow.new()
	tick_body.code = "\n".join(PackedStringArray([
		"if host == null or _agent == null or not is_instance_valid(_agent):",
		"\treturn",
		"if _pending_check:",
		"\t_pending_check = false",
		"\tif _pending_mode == \"reach\" and not _agent.is_target_reachable():",
		"\t\tstop_pathfinding()",
		"\t\tpath_failed.emit()",
		"\t\treturn",
		"\tpath_found.emit()",
		"if not _active:",
		"\treturn",
		"if _agent.is_navigation_finished():",
		"\tstop_pathfinding()",
		"\tpath_complete.emit()",
		"\treturn",
		"var to_next: Vector3 = _agent.get_next_path_position() - host.global_position",
		"var flat: Vector3 = Vector3(to_next.x, 0.0, to_next.z)",
		"var desired: Vector3 = flat.normalized() * move_speed if flat.length() > 0.05 else Vector3.ZERO",
		"_move_x = clampf(desired.x / maxf(move_speed, 0.001), -1.0, 1.0)",
		"_move_z = clampf(desired.z / maxf(move_speed, 0.001), -1.0, 1.0)",
		"if not auto_control:",
		"\treturn",
		"var driver: Node = _find_driver()",
		"if driver != null:",
		"\t# World direction into the driver's LOCAL axes - it moves relative to its own yaw.",
		"\tvar local: Vector3 = host.global_transform.basis.inverse() * desired",
		"\tdriver.set(\"ai_controlled\", true)",
		"\tdriver.set(\"ai_move_x\", clampf(local.x / maxf(move_speed, 0.001), -1.0, 1.0))",
		"\tdriver.set(\"ai_move_z\", clampf(local.z / maxf(move_speed, 0.001), -1.0, 1.0))",
		"else:",
		"\t# No driver: the built-in mover drives the body (gravity + slide), with optional",
		"\t# agent avoidance steering around other agents.",
		"\tif not host.is_on_floor():",
		"\t\thost.velocity.y -= gravity * delta",
		"\tif avoidance_enabled:",
		"\t\t_agent.velocity = Vector3(desired.x, host.velocity.y, desired.z)",
		"\t\thost.velocity.x = _safe_velocity.x",
		"\t\thost.velocity.z = _safe_velocity.z",
		"\telse:",
		"\t\thost.velocity.x = desired.x",
		"\t\thost.velocity.z = desired.z",
		"\thost.move_and_slide()"
	]))
	tick.actions.append(tick_body)
	sheet.events.append(tick)

	# ── Exposed actions (verb-symmetric with the 2D pack) ──────────────────────────
	Lib.append_function(sheet, "find_path_to", "Find Path To", "Nav Agent 3D",
		"Routes to a world position across the baked navmesh and starts moving. Mode \"reach\" fails (On Path Failed) when the spot is off the mesh; \"nearest\" never fails - the agent goes to the closest point on the mesh instead. Fires On Path Found / On Path Failed.",
		[["x", "float"], ["y", "float"], ["z", "float"], ["mode", "String"]],
		"\n".join(PackedStringArray([
			"var agent: NavigationAgent3D = _ensure_agent()",
			"if agent == null:",
			"\tpath_failed.emit()",
			"\treturn",
			"agent.target_position = Vector3(x, y, z)",
			"_active = true",
			"_pending_check = true",
			"_pending_mode = mode"
		])))
	_default(sheet, "mode", "nearest")
	_param_options(sheet, "mode", ["nearest", "reach"])
	Lib.append_function(sheet, "find_path_to_node", "Find Path To Node", "Nav Agent 3D",
		"Routes to another node's position (the player, a beacon) - Find Path To with the position read for you. Re-call on a timer to chase.",
		[["target", "Node"], ["mode", "String"]],
		"if target is Node3D:\n\tvar spot: Vector3 = (target as Node3D).global_position\n\tfind_path_to(spot.x, spot.y, spot.z, mode)\nelse:\n\tpath_failed.emit()")
	_default(sheet, "mode", "nearest")
	_param_options(sheet, "mode", ["nearest", "reach"])
	Lib.append_function(sheet, "stop_pathfinding", "Stop Pathfinding", "Nav Agent 3D",
		"Clears the path and hands the driver sibling back to the player (ai_controlled off).",
		[],
		"\n".join(PackedStringArray([
			"_active = false",
			"_pending_check = false",
			"_move_x = 0.0",
			"_move_z = 0.0",
			"var driver: Node = _find_driver()",
			"if driver != null:",
			"\tdriver.set(\"ai_move_x\", 0.0)",
			"\tdriver.set(\"ai_move_z\", 0.0)",
			"\tdriver.set(\"ai_controlled\", false)"
		])))
	Lib.append_function(sheet, "set_auto_control", "Set Auto Control", "Nav Agent 3D",
		"On (default): drive the sibling controller or the body. Off: paths still compute - read Path Move X/Z and Current Waypoint X/Y/Z and drive anything you like.",
		[["enabled", "bool"]],
		"auto_control = enabled\nif not enabled:\n\tvar driver: Node = _find_driver()\n\tif driver != null:\n\t\tdriver.set(\"ai_controlled\", false)")
	Lib.append_function(sheet, "set_avoidance", "Set Avoidance", "Nav Agent 3D",
		"Agents steer around each other (RVO avoidance). Applies to the built-in driver; a driver sibling owns its own velocity.",
		[["enabled", "bool"]],
		"avoidance_enabled = enabled\nif _agent != null and is_instance_valid(_agent):\n\t_agent.avoidance_enabled = enabled")
	Lib.append_function(sheet, "set_move_speed", "Set Move Speed", "Nav Agent 3D",
		"Changes the built-in driver's speed (m/s).",
		[["value", "float"]],
		"move_speed = value")
	Lib.append_function(sheet, "bake_navigation_region", "Bake Navigation Region", "Nav Agent 3D",
		"Rebakes a NavigationRegion3D's navmesh from its current child geometry, at runtime - call it on ready (or after the level changes) and every agent sees the walkable world. Slopes come free: the bake's max-angle setting decides what is walkable.",
		[["region", "Node"]],
		"if region is NavigationRegion3D:\n\t(region as NavigationRegion3D).bake_navigation_mesh()")

	return Lib.save_pack(sheet, "res://eventsheet_addons/nav_agent_3d/nav_agent_3d_behavior")


## Pre-fills the last-appended ACE's parameter default (authoring-time metadata only).
static func _default(sheet: EventSheetResource, param_id: String, value: String) -> void:
	var fn: EventFunction = sheet.functions[sheet.functions.size() - 1]
	for parameter: ACEParam in fn.params:
		if parameter.id == param_id:
			parameter.default_value = value


## Sets the dropdown options[] on the last-appended ACE's parameter.
static func _param_options(sheet: EventSheetResource, param_id: String, choices: Array) -> void:
	var typed: Array[String] = []
	for choice: Variant in choices:
		typed.append(str(choice))
	var fn: EventFunction = sheet.functions[sheet.functions.size() - 1]
	for parameter: ACEParam in fn.params:
		if parameter.id == param_id:
			parameter.options = typed
