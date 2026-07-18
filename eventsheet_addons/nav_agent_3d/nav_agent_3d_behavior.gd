## @ace_tags(movement, 3d, ai, pathfinding)
## @ace_category("Nav Agent 3D")
## @ace_expose_all(node)
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/nav_agent_3d/icon.svg")
class_name NavAgent3D
extends Node
## Navmesh pathfinding for 3D with zero wiring: attach under a CharacterBody3D, keep a NavigationRegion3D in the scene, and call Find Path To - a NavigationAgent3D child is inserted and tuned for you and the agent walks the baked navmesh. The verbs mirror the 2D Platformer Pathfinding pack, so learning one pack teaches both.

## The node this behavior acts on (its parent). Required host: CharacterBody3D.
var host: CharacterBody3D = null

func _enter_tree() -> void:
	host = get_parent() as CharacterBody3D
	if host == null:
		push_warning("NavAgent3D behavior requires a CharacterBody3D parent.")

## @ace_trigger
## @ace_name("On Path Found")
signal path_found
## @ace_trigger
## @ace_name("On Path Failed")
signal path_failed
## @ace_trigger
## @ace_name("On Path Complete")
signal path_complete
## @ace_trigger
## @ace_name("On Waypoint Reached")
signal waypoint_reached

## The navigation agent's height.
@export var agent_height: float = 1.8
## The navigation agent's radius (match your collider).
@export var agent_radius: float = 0.5
## Drive the sibling FPS Controller (or the body itself) automatically. Off = paths still compute; read Path Move X/Z and steer yourself.
@export var auto_control: bool = true
## Agents steer around each other (applies to the built-in driver; a driver sibling owns its own velocity).
@export var avoidance_enabled: bool = false
## The built-in driver's gravity (a driver sibling applies its own).
@export var gravity: float = 9.8
## The built-in driver's speed (m/s). A driver sibling uses its own speed.
@export var move_speed: float = 4.0
## How close (m) counts as having arrived at the target.
@export var target_desired_distance: float = 1.0

# --- Internal state ---
var _agent: NavigationAgent3D = null
var _driver: Node = null
var _active: bool = false
var _pending_check: bool = false
var _pending_mode: String = "nearest"
var _move_x: float = 0.0
var _move_z: float = 0.0
var _safe_velocity: Vector3 = Vector3.ZERO
## The NavigationAgent3D child, inserted and tuned on first use - the zero-wiring promise.
## @ace_hidden
func _ensure_agent() -> NavigationAgent3D:
	if _agent != null and is_instance_valid(_agent):
		return _agent
	if host == null:
		return null
	_agent = host.get_node_or_null("NavAgent") as NavigationAgent3D
	if _agent == null:
		_agent = NavigationAgent3D.new()
		_agent.name = "NavAgent"
		host.add_child(_agent)
	_agent.radius = agent_radius
	_agent.height = agent_height
	_agent.target_desired_distance = target_desired_distance
	_agent.path_desired_distance = 0.6
	_agent.avoidance_enabled = avoidance_enabled
	if not _agent.waypoint_reached.is_connected(_on_agent_waypoint):
		_agent.waypoint_reached.connect(_on_agent_waypoint)
	if not _agent.velocity_computed.is_connected(_on_safe_velocity):
		_agent.velocity_computed.connect(_on_safe_velocity)
	return _agent
## The driver sibling, duck-typed on the universal AI seam (ai_controlled + ai_move_x/z -
## the FPS Controller carries it; so can your own controller).
## @ace_hidden
func _find_driver() -> Node:
	if _driver != null and is_instance_valid(_driver):
		return _driver
	if host == null:
		return null
	for child in host.get_children():
		if child != self and child.get("ai_move_z") != null and child.get("ai_controlled") != null:
			_driver = child
			return _driver
	return null

func _ready() -> void:
	_ensure_agent()

func _physics_process(delta: float) -> void:
	if host == null or _agent == null or not is_instance_valid(_agent):
		return
	if _pending_check:
		_pending_check = false
		if _pending_mode == "reach" and not _agent.is_target_reachable():
			stop_pathfinding()
			path_failed.emit()
			return
		path_found.emit()
	if not _active:
		return
	if _agent.is_navigation_finished():
		stop_pathfinding()
		path_complete.emit()
		return
	var to_next: Vector3 = _agent.get_next_path_position() - host.global_position
	var flat: Vector3 = Vector3(to_next.x, 0.0, to_next.z)
	var desired: Vector3 = flat.normalized() * move_speed if flat.length() > 0.05 else Vector3.ZERO
	_move_x = clampf(desired.x / maxf(move_speed, 0.001), -1.0, 1.0)
	_move_z = clampf(desired.z / maxf(move_speed, 0.001), -1.0, 1.0)
	if not auto_control:
		return
	var driver: Node = _find_driver()
	if driver != null:
		# World direction into the driver's LOCAL axes - it moves relative to its own yaw.
		var local: Vector3 = host.global_transform.basis.inverse() * desired
		driver.set("ai_controlled", true)
		driver.set("ai_move_x", clampf(local.x / maxf(move_speed, 0.001), -1.0, 1.0))
		driver.set("ai_move_z", clampf(local.z / maxf(move_speed, 0.001), -1.0, 1.0))
	else:
		# No driver: the built-in mover drives the body (gravity + slide), with optional
		# agent avoidance steering around other agents.
		if not host.is_on_floor():
			host.velocity.y -= gravity * delta
		if avoidance_enabled:
			_agent.velocity = Vector3(desired.x, host.velocity.y, desired.z)
			host.velocity.x = _safe_velocity.x
			host.velocity.z = _safe_velocity.z
		else:
			host.velocity.x = desired.x
			host.velocity.z = desired.z
		host.move_and_slide()

## @ace_action
## @ace_featured
## @ace_name("Find Path To")
## @ace_category("Nav Agent 3D")
## @ace_description("Routes to a world position across the baked navmesh and starts moving. Mode "reach" fails (On Path Failed) when the spot is off the mesh; "nearest" never fails - the agent goes to the closest point on the mesh instead. Fires On Path Found / On Path Failed.")
## @ace_param_options(mode nearest, reach)
## @ace_icon("res://eventsheet_addons/nav_agent_3d/icon.svg")
## @ace_codegen_template("$NavAgent3D.find_path_to({x}, {y}, {z}, {mode})")
func find_path_to(x: float, y: float, z: float, mode: String) -> void:
	var agent: NavigationAgent3D = _ensure_agent()
	if agent == null:
		path_failed.emit()
		return
	agent.target_position = Vector3(x, y, z)
	_active = true
	_pending_check = true
	_pending_mode = mode

## @ace_action
## @ace_name("Find Path To Node")
## @ace_category("Nav Agent 3D")
## @ace_description("Routes to another node's position (the player, a beacon) - Find Path To with the position read for you. Re-call on a timer to chase.")
## @ace_param_options(mode nearest, reach)
## @ace_icon("res://eventsheet_addons/nav_agent_3d/icon.svg")
## @ace_codegen_template("$NavAgent3D.find_path_to_node({target}, {mode})")
func find_path_to_node(target: Node, mode: String) -> void:
	if target is Node3D:
		var spot: Vector3 = (target as Node3D).global_position
		find_path_to(spot.x, spot.y, spot.z, mode)
	else:
		path_failed.emit()

## @ace_action
## @ace_name("Stop Pathfinding")
## @ace_category("Nav Agent 3D")
## @ace_description("Clears the path and hands the driver sibling back to the player (ai_controlled off).")
## @ace_icon("res://eventsheet_addons/nav_agent_3d/icon.svg")
## @ace_codegen_template("$NavAgent3D.stop_pathfinding()")
func stop_pathfinding() -> void:
	_active = false
	_pending_check = false
	_move_x = 0.0
	_move_z = 0.0
	var driver: Node = _find_driver()
	if driver != null:
		driver.set("ai_move_x", 0.0)
		driver.set("ai_move_z", 0.0)
		driver.set("ai_controlled", false)

## @ace_action
## @ace_name("Set Auto Control")
## @ace_category("Nav Agent 3D")
## @ace_description("On (default): drive the sibling controller or the body. Off: paths still compute - read Path Move X/Z and Current Waypoint X/Y/Z and drive anything you like.")
## @ace_icon("res://eventsheet_addons/nav_agent_3d/icon.svg")
## @ace_codegen_template("$NavAgent3D.set_auto_control({enabled})")
func set_auto_control(enabled: bool) -> void:
	auto_control = enabled
	if not enabled:
		var driver: Node = _find_driver()
		if driver != null:
			driver.set("ai_controlled", false)

## @ace_action
## @ace_name("Set Avoidance")
## @ace_category("Nav Agent 3D")
## @ace_description("Agents steer around each other (RVO avoidance). Applies to the built-in driver; a driver sibling owns its own velocity.")
## @ace_icon("res://eventsheet_addons/nav_agent_3d/icon.svg")
## @ace_codegen_template("$NavAgent3D.set_avoidance({enabled})")
func set_avoidance(enabled: bool) -> void:
	avoidance_enabled = enabled
	if _agent != null and is_instance_valid(_agent):
		_agent.avoidance_enabled = enabled

## @ace_action
## @ace_name("Set Move Speed")
## @ace_category("Nav Agent 3D")
## @ace_description("Changes the built-in driver's speed (m/s).")
## @ace_icon("res://eventsheet_addons/nav_agent_3d/icon.svg")
## @ace_codegen_template("$NavAgent3D.set_move_speed({value})")
func set_move_speed(value: float) -> void:
	move_speed = value

## @ace_action
## @ace_name("Bake Navigation Region")
## @ace_category("Nav Agent 3D")
## @ace_description("Rebakes a NavigationRegion3D's navmesh from its current child geometry, at runtime - call it on ready (or after the level changes) and every agent sees the walkable world. Slopes come free: the bake's max-angle setting decides what is walkable.")
## @ace_icon("res://eventsheet_addons/nav_agent_3d/icon.svg")
## @ace_codegen_template("$NavAgent3D.bake_navigation_region({region})")
func bake_navigation_region(region: Node) -> void:
	if region is NavigationRegion3D:
		(region as NavigationRegion3D).bake_navigation_mesh()

## @ace_condition
## @ace_name("Has Path")
## @ace_icon("res://eventsheet_addons/nav_agent_3d/icon.svg")
## @ace_codegen_template("$NavAgent3D.has_path()")
func has_path() -> bool:
	return _active

## @ace_condition
## @ace_name("Target Is Reachable")
## @ace_icon("res://eventsheet_addons/nav_agent_3d/icon.svg")
## @ace_codegen_template("$NavAgent3D.target_is_reachable()")
func target_is_reachable() -> bool:
	return _agent != null and is_instance_valid(_agent) and _agent.is_target_reachable()

## @ace_expression
## @ace_name("Current Waypoint X")
## @ace_icon("res://eventsheet_addons/nav_agent_3d/icon.svg")
## @ace_codegen_template("$NavAgent3D.current_waypoint_x()")
func current_waypoint_x() -> float:
	return _agent.get_next_path_position().x if _active and _agent != null else 0.0

## @ace_expression
## @ace_name("Current Waypoint Y")
## @ace_icon("res://eventsheet_addons/nav_agent_3d/icon.svg")
## @ace_codegen_template("$NavAgent3D.current_waypoint_y()")
func current_waypoint_y() -> float:
	return _agent.get_next_path_position().y if _active and _agent != null else 0.0

## @ace_expression
## @ace_name("Current Waypoint Z")
## @ace_icon("res://eventsheet_addons/nav_agent_3d/icon.svg")
## @ace_codegen_template("$NavAgent3D.current_waypoint_z()")
func current_waypoint_z() -> float:
	return _agent.get_next_path_position().z if _active and _agent != null else 0.0

## @ace_expression
## @ace_name("Distance To Target")
## @ace_icon("res://eventsheet_addons/nav_agent_3d/icon.svg")
## @ace_codegen_template("$NavAgent3D.distance_to_target()")
func distance_to_target() -> float:
	return host.global_position.distance_to(_agent.target_position) if _active and _agent != null and host != null else 0.0

## @ace_expression
## @ace_name("Path Move X")
## @ace_icon("res://eventsheet_addons/nav_agent_3d/icon.svg")
## @ace_codegen_template("$NavAgent3D.path_move_x()")
func path_move_x() -> float:
	return _move_x

## @ace_expression
## @ace_name("Path Move Z")
## @ace_icon("res://eventsheet_addons/nav_agent_3d/icon.svg")
## @ace_codegen_template("$NavAgent3D.path_move_z()")
func path_move_z() -> float:
	return _move_z

## @ace_hidden
func _on_agent_waypoint(_details: Dictionary) -> void:
	waypoint_reached.emit()

## @ace_hidden
func _on_safe_velocity(safe_velocity: Vector3) -> void:
	_safe_velocity = safe_velocity

# 3D pathfinding on Godot's navmesh, sheet-shaped: attach under a CharacterBody3D inside a scene with a NavigationRegion3D and call Find Path To - a NavigationAgent3D child is inserted for you. The verbs mirror the 2D Platformer Pathfinding pack, auto-control drives the FPS Controller through the universal AI seam (or the body itself when no driver exists), and slopes come free from the navmesh bake.
