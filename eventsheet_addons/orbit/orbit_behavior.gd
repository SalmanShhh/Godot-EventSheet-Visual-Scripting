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
		push_warning("Orbit Behavior needs a Node2D: put it under one, or set Acts on. This one is at " + str(get_path()) + ".")

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

## The key of a table entry's host values as the preview last left them, to tell a hand edit from the preview's own writes.
const _PREVIEW_SEEN: String = "seen"

## The Engine meta key that holds the editor's own low-processor setting while any preview plays, so it can be put back.
const _PREVIEW_IDLE_META: String = "_eventsheets_previews_low_processor"

## True while Preview is playing in the editor. Always false in a running game.
var _previewing: bool = false

## Counts the Preview presses, so a repeat loop from an earlier press ends.
var _preview_run: int = 0

## This behaviour's own unsaved values from when Preview started, put back on Stop.
var _preview_own: Dictionary = {}

## True when the host's values were noted since the last check for a hand edit, so the note is fresh enough to trust.
var _preview_noted: bool = false

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
		_preview_keep_hand_edits()
		_preview_put_back(host, _preview_rest_of(host))
		_preview_note_seen()

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
	_preview_watch_begin()

## Starts watching for a hand edit: notes the host as it stands now, then again just before each drawn frame, and
## checks at the start of each physics and process frame, before anything has written to the host that frame.
func _preview_watch_begin() -> void:
	if not Engine.has_meta(_PREVIEW_IDLE_META):
		Engine.set_meta(_PREVIEW_IDLE_META, OS.low_processor_usage_mode)
		OS.low_processor_usage_mode = false
	_preview_note_seen()
	var tree: SceneTree = get_tree()
	if not RenderingServer.frame_pre_draw.is_connected(_preview_note_seen):
		RenderingServer.frame_pre_draw.connect(_preview_note_seen)
	if tree != null and not tree.physics_frame.is_connected(_preview_watch):
		tree.physics_frame.connect(_preview_watch)
	if tree != null and not tree.process_frame.is_connected(_preview_watch):
		tree.process_frame.connect(_preview_watch)

func _preview_watch_end() -> void:
	_preview_noted = false
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if RenderingServer.frame_pre_draw.is_connected(_preview_note_seen):
		RenderingServer.frame_pre_draw.disconnect(_preview_note_seen)
	if tree != null and tree.physics_frame.is_connected(_preview_watch):
		tree.physics_frame.disconnect(_preview_watch)
	if tree != null and tree.process_frame.is_connected(_preview_watch):
		tree.process_frame.disconnect(_preview_watch)

## Writes the host's values down as the preview leaves them. Taken just before a frame is drawn, it is what the
## next frame's check compares the host with.
func _preview_note_seen() -> void:
	if not is_instance_valid(host):
		return
	var entry: Dictionary = _preview_table().get(host.get_instance_id(), {})
	if entry.is_empty():
		return
	entry[_PREVIEW_SEEN] = _preview_values(host, false)
	_preview_noted = true

## Takes anything on the host that is not what the preview last left there as the host's new resting value, so
## Stop and a save keep it. Returns whether there was any. A note that has not been refreshed since the last check
## is stale and proves nothing, so then there is nothing to keep.
func _preview_keep_hand_edits() -> bool:
	if not _preview_noted or not is_instance_valid(host):
		return false
	var entry: Dictionary = _preview_table().get(host.get_instance_id(), {})
	if not entry.has(_PREVIEW_SEEN):
		return false
	var seen: Dictionary = entry[_PREVIEW_SEEN]
	var rest: Dictionary = entry.get(_PREVIEW_REST, {})
	var kept: bool = false
	for prop_name: String in seen:
		var now: Variant = host.get(prop_name)
		var before: Variant = seen[prop_name]
		if typeof(now) != typeof(before) or now != before:
			rest[prop_name] = now.duplicate() if (now is Array or now is Dictionary) else now
			kept = true
	return kept

## Runs at the start of every physics and process frame, once per drawn frame: a hand edit ends the preview and keeps the edit.
func _preview_watch() -> void:
	if not _previewing or not _preview_noted:
		return
	if _preview_keep_hand_edits():
		_preview_stop()
	_preview_noted = false

func _preview_stop() -> void:
	if not _previewing:
		return
	_preview_keep_hand_edits()
	_preview_watch_end()
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
	if table.is_empty() and Engine.has_meta(_PREVIEW_IDLE_META):
		OS.low_processor_usage_mode = Engine.get_meta(_PREVIEW_IDLE_META)
		Engine.remove_meta(_PREVIEW_IDLE_META)
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

func _ready() -> void:
	if host is RigidBody2D:
		push_warning("Orbit on %s: this behaviour moves a RigidBody2D by changing its position, but the physics engine moves that body too, so the two will fight (jitter, snapping back, passing through walls). Put the behaviour under a node that is not a physics body, such as the Sprite2D inside it, or move the body with apply_central_impulse() or its linear_velocity instead." % (str(get_path()) if is_inside_tree() else str(name)))

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
