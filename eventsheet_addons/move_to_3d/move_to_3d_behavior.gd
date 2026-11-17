## @ace_category("Move To 3D")
## @ace_expose_all(node)
## @ace_version(1.0.0)
@tool
@icon("res://eventsheet_addons/move_to_3d/icon.svg")
class_name MoveTo3DBehavior
extends Node
## Point-to-point movement for any Node3D: hand it Vector3 targets and it glides the host straight toward each one at a steady speed, popping waypoints off a queue and firing On Arrived at the last stop. Attach under a drone, elevator, pickup, or camera rig and tune the pace with the single max_speed knob.
##
## Changes on its parent: position.

## @ace_hidden
## The node this behavior acts on. Empty: its parent.
@export var acts_on: Node3D = null

## The node this behavior acts on (Acts on, or else its parent). Required host: Node3D.
var host: Node3D = null

func _enter_tree() -> void:
	host = acts_on if acts_on != null else get_parent() as Node3D
	if host == null:
		push_warning("Move To3D Behavior needs a Node3D: put it under one, or set Acts on.")

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
	_preview_repeat(_preview_run)
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
	_preview_put_back(host, _preview_rest_of(host))
	move_to_position_3d(host.position.x + max_speed, host.position.y, host.position.z)

func _preview_repeat(run: int) -> void:
	while true:
		await get_tree().create_timer(maxf(1.4, 0.1)).timeout
		if not _previewing or run != _preview_run:
			return
		_preview_kick()

## @ace_trigger
## @ace_name("On Arrived (3D)")
signal arrived
## @ace_trigger
## @ace_name("On Path Blocked (3D)")
signal path_blocked

## Units per second the host glides toward each waypoint.
@export var max_speed: float = 5.0
## Sweep the path each frame instead of gliding straight to the next point, so a fast mover cannot pass through thin geometry between two frames.
@export var stepping: bool = false
## Collision layers the swept path tests against. Each layer is a bit, so layers 1 and 3 are 1 + 4 = 5.
@export var step_mask: int = 1
## Also stop the sweep on Area3D nodes, which it ignores by default.
@export var step_hits_areas: bool = false
## Drop the waypoint queue and stop when the path is blocked. Turn off to keep pushing at the obstacle and just report it.
@export var stop_on_step_hit: bool = true
## The points the host is walking through, in order.
var waypoints: Array = []
## True while the host is travelling toward a point.
var moving: bool = false

func _ready() -> void:
	# A host that has not been sent anywhere yet has nothing to glide toward, so the tick starts
	# off and every verb that hands it a destination turns it back on. `moving` is what the whole
	# tick is gated on, so reading it here keeps the two in step with no second flag.
	set_process(moving)
	if host is RigidBody3D:
		push_warning("Move To 3D on %s: this behaviour moves a RigidBody3D by changing its position, but the physics engine moves that body too, so the two will fight (jitter, snapping back, passing through walls). Put the behaviour under a node that is not a physics body, such as the MeshInstance3D inside it, or move the body with apply_central_impulse() or its linear_velocity instead." % (str(get_path()) if is_inside_tree() else str(name)))

func _process(delta: float) -> void:
	if Engine.is_editor_hint() and not _previewing:
		return
	if not moving or host == null or waypoints.is_empty():
		return
	var target: Vector3 = waypoints[0]
	host.position = step_toward(host.position, host.position.move_toward(target, max_speed * delta))
	if host.position.distance_to(target) < 0.05:
		waypoints.pop_front()
		if waypoints.is_empty():
			moving = false
			# The last stop is reached, so there is nothing left to glide toward. Processing goes
			# off BEFORE the trigger fires, so a row that answers On Arrived with another Move To
			# turns it straight back on.
			set_process(false)
			arrived.emit()

## @ace_action
## @ace_name("Move To Position (3D)")
## @ace_category("Move To 3D")
## @ace_description("Replaces the queue and glides toward the point.")
## @ace_icon("res://eventsheet_addons/move_to_3d/icon.svg")
## @ace_codegen_template("$MoveTo3DBehavior.move_to_position_3d({x}, {y}, {z})")
func move_to_position_3d(x: float, y: float, z: float) -> void:
	waypoints = [Vector3(x, y, z)]
	moving = true
	# There is somewhere to be again, so the per-frame glide is worth paying for.
	set_process(true)

## @ace_action
## @ace_name("Add Waypoint (3D)")
## @ace_category("Move To 3D")
## @ace_description("Appends a stop to the queue.")
## @ace_icon("res://eventsheet_addons/move_to_3d/icon.svg")
## @ace_codegen_template("$MoveTo3DBehavior.add_waypoint_3d({x}, {y}, {z})")
func add_waypoint_3d(x: float, y: float, z: float) -> void:
	waypoints.append(Vector3(x, y, z))
	moving = true
	# A stop appended to an empty queue restarts the glide, so the tick has to come back on.
	set_process(true)

## @ace_action
## @ace_name("Stop Moving (3D)")
## @ace_category("Move To 3D")
## @ace_description("Clears the queue without firing On Arrived.")
## @ace_icon("res://eventsheet_addons/move_to_3d/icon.svg")
## @ace_codegen_template("$MoveTo3DBehavior.stop_moving_3d()")
func stop_moving_3d() -> void:
	moving = false
	waypoints = []
	# A stopped mover costs nothing per frame; Move To Position turns processing back on.
	set_process(false)

## The furthest point on the way to `to` that is actually reachable this frame.
##
## Gliding sets position outright, so at speed the host can cross thin geometry entirely between
## two frames and never touch it. With Stepping on, a swept ray finds what the glide skipped and
## returns the contact point instead. Positions are in the parent's space, so the sweep converts
## by offsetting the host's global position by the same delta.
func step_toward(from: Vector3, to: Vector3) -> Vector3:
	if not stepping or from == to or host == null or not host.is_inside_tree():
		return to
	var world_from: Vector3 = host.global_position
	var step_query := PhysicsRayQueryParameters3D.create(world_from, world_from + (to - from), step_mask, [])
	step_query.collide_with_areas = step_hits_areas
	var step_hit := host.get_world_3d().direct_space_state.intersect_ray(step_query)
	if step_hit.is_empty():
		return to
	if stop_on_step_hit:
		waypoints.clear()
		moving = false
		# A blocked path that drops its queue is stopped, so nothing is left for the tick to
		# do - Move To Position and Add Waypoint turn processing back on.
		set_process(false)
	path_blocked.emit()
	var contact: Vector3 = step_hit.get("position", world_from)
	# Park just SHORT of the surface, never exactly on it: a ray that STARTS on a shape does not
	# report that shape (hit-from-inside is off), so a host left touching the wall sails straight
	# through on the next frame's sweep. A centimetre of clearance keeps the next ray honest.
	return from + (contact - (to - from).normalized() * 0.01 - world_from)

# Move To 3D behavior (event-sheet-style): glides through a queue of Vector3 waypoints and fires On Arrived at the final stop.
