## @ace_category("Move To")
## @ace_expose_all(node)
## @ace_version(1.0.0)
@tool
@icon("res://eventsheet_addons/move_to/icon.svg")
class_name MoveToBehavior
extends Node
## Glides the host Node2D to a point at a steady speed, walks queued waypoints in order, and fires On Arrived at the last stop. Smooth point-to-point movement for enemies, pickups, and cursor tokens without writing tween code.
##
## Changes on its parent: position, rotation.

## @ace_hidden
## The node this behavior acts on. Empty: its parent.
@export var acts_on: Node2D = null

## The node this behavior acts on (Acts on, or else its parent). Required host: Node2D.
var host: Node2D = null

func _enter_tree() -> void:
	host = acts_on if acts_on != null else get_parent() as Node2D
	if host == null:
		push_warning("Move To Behavior needs a Node2D: put it under one, or set Acts on.")

@warning_ignore("unused_private_class_variable")
## @ace_hidden
## Plays in the editor. Your scene is not changed.
@export_tool_button("Preview", "Play") var _preview_start_button: Callable = _preview_start

@warning_ignore("unused_private_class_variable")
## @ace_hidden
## Plays in the editor. Your scene is not changed.
@export_tool_button("Stop preview", "Stop") var _preview_stop_button: Callable = _preview_stop

## The Engine meta key every previewing behaviour shares for its table of rest values, one entry per host.
const _PREVIEW_TABLE_META: String = "_eventsheets_previews"

## The key of a table entry's remembered rest values.
const _PREVIEW_REST: String = "rest"

## The key of a table entry's count of behaviours previewing on that host.
const _PREVIEW_USERS: String = "users"

## True while Preview is playing in the editor. Always false in a running game.
var _previewing: bool = false

## Counts the Preview presses, so a repeat loop from an earlier press ends.
var _preview_run: int = 0

## This behaviour's own unsaved values from when Preview started, put back on Stop.
var _preview_own: Dictionary = {}

func _validate_property(property: Dictionary) -> void:
	if property.name == "_preview_start_button" and _previewing:
		property.usage = PROPERTY_USAGE_NONE
	elif property.name == "_preview_stop_button" and not _previewing:
		property.usage = PROPERTY_USAGE_NONE

func _notification(what: int) -> void:
	if not Engine.is_editor_hint() or not _previewing:
		return
	if what == NOTIFICATION_EXIT_TREE:
		_preview_stop()
	elif what == NOTIFICATION_EDITOR_PRE_SAVE:
		_preview_put_back(host, _preview_rest_of(host))

static func _preview_values(node: Object, own: bool) -> Dictionary:
	var values: Dictionary = {}
	for info: Dictionary in node.get_property_list():
		var usage: int = info.usage
		var prop_name: String = info.name
		if info.type == TYPE_NIL or info.type == TYPE_CALLABLE or prop_name.contains("/") or prop_name == "script" or prop_name == "owner":
			continue
		if own:
			if not (usage & PROPERTY_USAGE_SCRIPT_VARIABLE) or (usage & PROPERTY_USAGE_STORAGE) or prop_name.begins_with("_preview") or prop_name == "host":
				continue
		elif not (usage & PROPERTY_USAGE_STORAGE):
			continue
		var value: Variant = node.get(prop_name)
		values[prop_name] = value.duplicate() if (value is Array or value is Dictionary) else value
	return values

static func _preview_put_back(node: Object, values: Dictionary) -> void:
	if node == null or not is_instance_valid(node):
		return
	for prop_name: String in values:
		var now: Variant = node.get(prop_name)
		var rest: Variant = values[prop_name]
		if typeof(now) != typeof(rest) or now != rest:
			node.set(prop_name, rest)

static func _preview_table() -> Dictionary:
	if not Engine.has_meta(_PREVIEW_TABLE_META):
		Engine.set_meta(_PREVIEW_TABLE_META, {})
	return Engine.get_meta(_PREVIEW_TABLE_META)

func _preview_rest_of(node: Object) -> Dictionary:
	if node == null:
		return {}
	var entry: Dictionary = _preview_table().get(node.get_instance_id(), {})
	return entry.get(_PREVIEW_REST, {})

func _preview_start() -> void:
	if not Engine.is_editor_hint() or _previewing or host == null or not is_inside_tree():
		return
	var table: Dictionary = _preview_table()
	var key: int = host.get_instance_id()
	if table.has(key):
		_preview_put_back(host, table[key][_PREVIEW_REST])
		table[key][_PREVIEW_USERS] += 1
	else:
		table[key] = {_PREVIEW_REST: _preview_values(host, false), _PREVIEW_USERS: 1}
	_preview_own = _preview_values(self, true)
	_previewing = true
	_preview_run += 1
	notify_property_list_changed()
	_preview_kick()
	_preview_repeat(_preview_run)

func _preview_stop() -> void:
	if not _previewing:
		return
	_previewing = false
	_preview_kill_tweens()
	_preview_put_back(self, _preview_own)
	var table: Dictionary = _preview_table()
	var key: int = host.get_instance_id() if host != null else 0
	if table.has(key):
		_preview_put_back(host, table[key][_PREVIEW_REST])
		table[key][_PREVIEW_USERS] -= 1
		if table[key][_PREVIEW_USERS] <= 0:
			table.erase(key)
	notify_property_list_changed()

func _preview_kill_tweens() -> void:
	for info: Dictionary in get_property_list():
		if not (info.usage & PROPERTY_USAGE_SCRIPT_VARIABLE) or info.name == "host":
			continue
		var held: Variant = get(info.name)
		var live_tweens: Array = []
		if held is Tween:
			live_tweens.append(held)
		elif held is Dictionary:
			live_tweens.append_array((held as Dictionary).values())
		elif held is Array:
			live_tweens.append_array(held)
		for candidate: Variant in live_tweens:
			if candidate is Tween and (candidate as Tween).is_valid():
				(candidate as Tween).kill()

func _preview_kick() -> void:
	_preview_put_back(host, _preview_rest_of(host))
	move_to_position(host.position.x + max_speed, host.position.y)

func _preview_repeat(run: int) -> void:
	while true:
		await get_tree().create_timer(maxf(1.4, 0.1)).timeout
		if not _previewing or run != _preview_run:
			return
		_preview_kick()

## @ace_trigger
## @ace_name("On Arrived")
## @ace_category("Move To")
signal arrived
## @ace_trigger
## @ace_name("On Path Blocked")
## @ace_category("Move To")
signal path_blocked

## Pixels per second the host glides toward its target.
@export var max_speed: float = 200.0
## When on, the host faces its direction of travel.
@export var rotate_toward_motion: bool = false
## Sweep the path each frame instead of gliding straight to the next point, so a fast mover cannot pass through a thin wall between two frames.
@export var stepping: bool = false
## Collision layers the swept path tests against. Each layer is a bit, so layers 1 and 3 are 1 + 4 = 5.
@export var step_mask: int = 1
## Also stop the sweep on Area2D nodes, which it ignores by default.
@export var step_hits_areas: bool = false
## Drop the waypoint queue and stop when the path is blocked. Turn off to keep pushing at the obstacle and just report it.
@export var stop_on_step_hit: bool = true
## The points the host is walking through, in order.
var waypoints: Array = []
## True while the host is travelling toward a point.
var moving: bool = false

func _ready() -> void:
	self.set_process(moving)

func _process(delta: float) -> void:
	if Engine.is_editor_hint() and not _previewing:
		return
	if moving and is_instance_valid(host) and not waypoints.is_empty():
		var target: Vector2 = waypoints[0]
		var previous: Vector2 = host.position
		host.position = step_toward(host.position, host.position.move_toward(target, max_speed * delta))
		if rotate_toward_motion and host.position != previous:
			host.rotation = (host.position - previous).angle()
		if host.position.distance_to(target) < 0.5:
			waypoints.pop_front()
			if waypoints.is_empty():
				moving = false
				self.set_process(false)
				arrived.emit()

## @ace_hidden
func step_toward(from: Vector2, to: Vector2) -> Vector2:
	if not stepping or from == to or host == null or not host.is_inside_tree():
		return to
	var world_from: Vector2 = host.global_position
	var step_query := PhysicsRayQueryParameters2D.create(world_from, world_from + (to - from), step_mask, [])
	step_query.collide_with_areas = step_hits_areas
	var step_hit := host.get_world_2d().direct_space_state.intersect_ray(step_query)
	if step_hit.is_empty():
		return to
	if stop_on_step_hit:
		waypoints.clear()
		moving = false
		self.set_process(false)
	path_blocked.emit()
	return from + (step_hit.get("position", world_from) - (to - from).normalized() * 0.5 - world_from)

## @ace_action
## @ace_name("Move To Position")
## @ace_category("Move To")
## @ace_description("Replaces the queue and glides toward the point.")
## @ace_icon("res://eventsheet_addons/move_to/icon.svg")
## @ace_codegen_template("$MoveToBehavior.move_to_position({x}, {y})")
func move_to_position(x: float, y: float) -> void:
	waypoints = [Vector2(x, y)]
	moving = true
	self.set_process(true)

## @ace_action
## @ace_name("Add Waypoint")
## @ace_category("Move To")
## @ace_description("Appends a stop to the queue (waypoints).")
## @ace_icon("res://eventsheet_addons/move_to/icon.svg")
## @ace_codegen_template("$MoveToBehavior.add_waypoint({x}, {y})")
func add_waypoint(x: float, y: float) -> void:
	waypoints.append(Vector2(x, y))
	moving = true
	self.set_process(true)

## @ace_action
## @ace_name("Stop Moving")
## @ace_category("Move To")
## @ace_description("Clears the queue without firing On Arrived.")
## @ace_icon("res://eventsheet_addons/move_to/icon.svg")
## @ace_codegen_template("$MoveToBehavior.stop_moving()")
func stop_moving() -> void:
	moving = false
	waypoints = []
	self.set_process(false)

# Move To behavior (event-sheet parity): glides through a waypoint queue (Move To Position replaces it, Add Waypoint appends) and fires On Arrived at the final stop. rotate_toward_motion faces the travel direction.
