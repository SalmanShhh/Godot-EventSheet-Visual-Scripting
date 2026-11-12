## @ace_category("Orbit")
## @ace_expose_all(node)
## @ace_version(1.0.0)
@tool
@icon("res://eventsheet_addons/orbit/icon.svg")
class_name OrbitBehavior
extends Node
## Sweeps a Node2D around a center point every frame: attach to a moon, shield orb, or spinning hazard and it circles on a radius (or tilted ellipse) at a speed you can change live. The center is captured from wherever the node starts, and the node can face the direction it is travelling.
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
		push_warning("Orbit Behavior needs a Node2D: put it under one, or set Acts on.")

@warning_ignore("unused_private_class_variable")
## @ace_hidden
## Plays in the editor. Your scene is not changed.
@export_tool_button("Preview", "Play") var _preview_start_button: Callable = _preview_start

@warning_ignore("unused_private_class_variable")
## @ace_hidden
## Plays in the editor. Your scene is not changed.
@export_tool_button("Stop preview", "Stop") var _preview_stop_button: Callable = _preview_stop

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
	if not Engine.has_meta("_eventsheets_previews"):
		Engine.set_meta("_eventsheets_previews", {})
	return Engine.get_meta("_eventsheets_previews")

func _preview_rest_of(node: Object) -> Dictionary:
	if node == null:
		return {}
	var entry: Dictionary = _preview_table().get(node.get_instance_id(), {})
	return entry.get("rest", {})

func _preview_start() -> void:
	if not Engine.is_editor_hint() or _previewing or host == null or not is_inside_tree():
		return
	var table: Dictionary = _preview_table()
	var key: int = host.get_instance_id()
	if table.has(key):
		_preview_put_back(host, table[key].rest)
		table[key].users += 1
	else:
		table[key] = {"rest": _preview_values(host, false), "users": 1}
	_preview_own = _preview_values(self, true)
	_previewing = true
	_preview_run += 1
	notify_property_list_changed()
	_preview_kick()

func _preview_stop() -> void:
	if not _previewing:
		return
	_previewing = false
	_preview_kill_tweens()
	_preview_put_back(self, _preview_own)
	var table: Dictionary = _preview_table()
	var key: int = host.get_instance_id() if host != null else 0
	if table.has(key):
		_preview_put_back(host, table[key].rest)
		table[key].users -= 1
		if table[key].users <= 0:
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
	pass

## Current angle around the centre, in degrees.
var angle: float = 0.0
## True once the centre has been taken from the host's position.
var center_captured: bool = false
## Horizontal position of the orbit centre, in pixels.
var center_x: float = 0.0
## Vertical position of the orbit centre, in pixels.
var center_y: float = 0.0
## When on, the node rotates to face its direction of travel.
@export var match_rotation: bool = false
## Tilts the whole ellipse by this many degrees.
@export var offset_angle_degrees: float = 0.0
## Orbit radius on the primary axis, in pixels.
@export var primary_radius: float = 100.0
## Orbit radius on the second axis, in pixels; 0 makes a circle from the primary radius.
@export var secondary_radius: float = 0.0
## Degrees per second traveled around the orbit; negative reverses direction.
@export var speed_degrees: float = 90.0
## Total angle travelled since the orbit started, in degrees, counting full turns.
var total_rotation: float = 0.0

func _process(delta: float) -> void:
	if Engine.is_editor_hint() and not _previewing:
		return
	if host == null:
		return
	if not center_captured:
		center_x = host.position.x
		center_y = host.position.y
		center_captured = true
	var step := deg_to_rad(speed_degrees) * delta
	angle += step
	total_rotation += absf(step)
	var radius_b := secondary_radius if secondary_radius > 0.0 else primary_radius
	var local := Vector2(cos(angle) * primary_radius, sin(angle) * radius_b).rotated(deg_to_rad(offset_angle_degrees))
	var previous := host.position
	host.position = Vector2(center_x, center_y) + local
	if match_rotation and host.position != previous:
		host.rotation = (host.position - previous).angle()

## @ace_action
## @ace_name("Set Orbit Center")
## @ace_category("Orbit")
## @ace_description("Orbits around the given point from now on.")
## @ace_icon("res://eventsheet_addons/orbit/icon.svg")
## @ace_codegen_template("$OrbitBehavior.set_orbit_center({x}, {y})")
func set_orbit_center(x: float, y: float) -> void:
	center_x = x
	center_y = y
	center_captured = true

## @ace_action
## @ace_name("Set Orbit Speed")
## @ace_category("Orbit")
## @ace_description("Degrees per second (negative reverses).")
## @ace_icon("res://eventsheet_addons/orbit/icon.svg")
## @ace_codegen_template("$OrbitBehavior.set_orbit_speed({degrees_per_second})")
func set_orbit_speed(degrees_per_second: float) -> void:
	speed_degrees = degrees_per_second

## @ace_action
## @ace_name("Set Orbit Radii")
## @ace_category("Orbit")
## @ace_description("Primary/secondary radii (secondary 0 = circle).")
## @ace_icon("res://eventsheet_addons/orbit/icon.svg")
## @ace_codegen_template("$OrbitBehavior.set_orbit_radii({primary}, {secondary})")
func set_orbit_radii(primary: float, secondary: float) -> void:
	primary_radius = primary
	secondary_radius = secondary

# Orbit behavior (event-sheet parity): circles or ellipses around a point. secondary_radius 0 = circle; offset_angle tilts the ellipse; match_rotation faces the travel direction.
