# @ace_tags(movement, path, curve)
# @ace_category("Path")
# @ace_version(1.0.0)
@tool
@icon("res://eventsheet_addons/follow_path/icon.svg")
class_name PathFollowBehavior
extends Node
## Walks the host Node2D along a drawn Path2D at a real speed - patrol routes, conveyors, camera dollies and tower-defence lanes. Once, Loop or Ping-pong, with optional rotate-to-face, and On Path Finished when a one-shot run reaches the end.
##
## Changes on its parent: global_position, global_rotation.

# @ace_hidden
## The node this behavior acts on. Empty: its parent.
@export var acts_on: Node2D = null

## The node this behavior acts on (Acts on, or else its parent). Required host: Node2D.
var host: Node2D = null

func _enter_tree() -> void:
	host = acts_on if acts_on != null else get_parent() as Node2D
	if host == null:
		push_warning("Path Follow Behavior needs a Node2D: put it under one, or set Acts on. This one is at " + str(get_path()) + ".")

@warning_ignore("unused_private_class_variable")
# @ace_hidden
## Plays in the editor. Your scene is not changed.
@export_tool_button("Preview", "Play") var _preview_start_button: Callable = _preview_start

@warning_ignore("unused_private_class_variable")
# @ace_hidden
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
	if route != null and not _following:
		follow_path(route, travel_speed, loop_mode)

func _preview_repeat(run: int) -> void:
	while true:
		await get_tree().create_timer(maxf((route.curve.get_baked_length() / maxf(travel_speed, 1.0) + 0.5) if route != null and route.curve != null else 2.0, 0.1)).timeout
		if not _previewing or run != _preview_run:
			return
		_preview_kick()

# @ace_trigger
# @ace_name("On Path Finished")
signal path_finished

# --- Choices (the stored words are the promise: saved scenes keep them) ---
## Stop at the end and fire On Path Finished.
const LOOP_MODE_ONCE := "once"
## Start over at the end.
const LOOP_MODE_LOOP := "loop"
## Walk back at the end.
const LOOP_MODE_PINGPONG := "pingpong"

# --- Designer knobs (tune in the Inspector) ---
## The drawn route. Follow Path can hand over a different one at runtime; this is the starting route, and the one the editor gizmo draws.
@export var route: Path2D = null
## Pixels per second along the curve. Arc-length paced, so corners do not speed it up.
@export var travel_speed: float = 120.0
## What happens at the end: stop (and fire On Path Finished), start over, or walk back.
@export_enum("once", "loop", "pingpong") var loop_mode: String = "once"
## When on, the host turns to face the direction it is travelling along the curve.
@export var rotate_to_face: bool = false
## Start walking the route as soon as the scene runs, with no Follow Path row needed.
@export var auto_start: bool = false

# --- Internal state ---
# How far along the curve the host is, in PIXELS of arc length (not a 0..1 fraction):
# pacing by baked length is what keeps a tight corner from being crossed faster than a
# straight. _travel_direction is +1 walking forward, -1 on the way back in ping-pong.
## How far along the path the host is, in pixels.
var _distance: float = 0.0
## Which way along the path the host is going: 1 forward, -1 back.
var _travel_direction: int = 1
## True while the host is travelling along the path.
var _following: bool = false

func _process(delta: float) -> void:
	if Engine.is_editor_hint() and not _previewing:
		return
	if not _following or host == null or route == null or route.curve == null:
		return
	var length: float = route.curve.get_baked_length()
	if length <= 0.0:
		return
	_distance += travel_speed * delta * float(_travel_direction)
	if _distance >= length:
		if loop_mode == LOOP_MODE_LOOP:
			_distance = fmod(_distance, length)
		elif loop_mode == LOOP_MODE_PINGPONG:
			# Reflect the overshoot rather than clamping it, so a fast mover keeps its pace
			# through the turn instead of pausing for a frame at the end.
			_distance = maxf(length - (_distance - length), 0.0)
			_travel_direction = -1
		else:
			_distance = length
			_following = false
			_apply_path_position()
			# The end of a Once run is a stop. Processing goes off BEFORE the trigger fires, so a
			# row that answers On Path Finished with another Follow Path turns it straight back on.
			set_process(false)
			path_finished.emit()
			return
	elif _distance <= 0.0 and _travel_direction < 0:
		_distance = minf(-_distance, length)
		_travel_direction = 1
	_apply_path_position()

func _ready() -> void:
	if host is RigidBody2D:
		push_warning("Follow Path on %s: this behaviour moves a RigidBody2D by changing its position, but the physics engine moves that body too, so the two will fight (jitter, snapping back, passing through walls). Put the behaviour under a node that is not a physics body, such as the Sprite2D inside it, or move the body with apply_central_impulse() or its linear_velocity instead." % (str(get_path()) if is_inside_tree() else str(name)))
	if auto_start and route != null:
		follow_path(route, travel_speed, loop_mode)
	# A host that is not walking a route has nothing to work out each frame, so a pack left
	# waiting for a Follow Path row costs nothing until that row runs.
	set_process(_following)

# @ace_hidden
## Puts the host where _distance says, and turns it if rotate_to_face is on. Positions come
## out of the curve in the PATH's own space, so they are converted through the path node.
func _apply_path_position() -> void:
	if host == null or route == null or route.curve == null:
		return
	var sample: Transform2D = route.curve.sample_baked_with_rotation(clampf(_distance, 0.0, route.curve.get_baked_length()))
	host.global_position = route.to_global(sample.origin)
	if rotate_to_face:
		var facing: Vector2 = sample.x if _travel_direction >= 0 else -sample.x
		host.global_rotation = route.global_rotation + facing.angle()

# @ace_action
# @ace_name("Follow Path")
# @ace_description("Sends the host travelling along a drawn Path2D at a real speed - patrol routes, conveyor lanes, camera dollies, tower-defence lanes. Ping-pong walks it back and forth forever; Once fires On Path Finished at the end.")
# @ace_param_hint(path node)
# @ace_param_options(mode once=Once, loop=Loop, pingpong=Ping-pong)
# @ace_codegen_template("$PathFollowBehavior.follow_path({path}, {speed}, "{mode}")")
func follow_path(path: Path2D, speed: float = 120.0, mode: String = "once") -> void:
	if path == null or path.curve == null or path.curve.get_baked_length() <= 0.0:
		return
	route = path
	travel_speed = speed
	loop_mode = mode
	_distance = 0.0
	_travel_direction = 1
	_following = true
	# There is a route to walk again, so the per-frame pacing is worth paying for.
	set_process(true)
	_apply_path_position()

# @ace_action
# @ace_name("Stop Following Path")
# @ace_description("Halts the run where it stands, WITHOUT firing On Path Finished - a stunned patroller, a conveyor switched off, a dolly interrupted by the player. Follow Path starts it again from the top.")
# @ace_codegen_template("$PathFollowBehavior.stop_following_path()")
func stop_following_path() -> void:
	_following = false
	# A halted run costs nothing per frame; Follow Path turns processing back on.
	set_process(false)

# @ace_condition
# @ace_name("Is Following Path")
# @ace_description("True while the host is actually travelling - the gate for a walk animation, a conveyor's hum, or a Stop row that should only fire once.")
# @ace_codegen_template("$PathFollowBehavior.is_following_path()")
func is_following_path() -> bool:
	return _following

# @ace_condition
# @ace_name("Is At Path End")
# @ace_description("True while the host is parked at the far end of its route right now. This is the STATE question, asked whenever a row is reached; for the moment of arrival use the On Path Finished trigger instead - it fires once, for free, with no per-frame checking.")
# @ace_codegen_template("$PathFollowBehavior.is_at_path_end()")
func is_at_path_end() -> bool:
	if route == null or route.curve == null:
		return false
	return _distance >= route.curve.get_baked_length() - 0.5

# @ace_expression
# @ace_name("Progress Along Path")
# @ace_description("How far along its route the host has come, from 0 at the start to 1 at the end - a racer's lap bar, a delivery tracker, a boss phase keyed to how far the sweep has gone.")
# @ace_codegen_template("$PathFollowBehavior.progress_along_path()")
func progress_along_path() -> float:
	if route == null or route.curve == null or route.curve.get_baked_length() <= 0.0:
		return 0.0
	return clampf(_distance / route.curve.get_baked_length(), 0.0, 1.0)

# @ace_expression
# @ace_name("Point On Path At")
# @ace_description("The world point a fraction of the way along a path (0 is the start, 1 is the end) - drive a camera dolly, a progress marker, or a preview ghost without moving anything.")
# @ace_param_hint(path node)
# @ace_codegen_template("$PathFollowBehavior.point_on_path_at({path}, {progress})")
func point_on_path_at(path: Path2D, progress: float = 0.5) -> Vector2:
	if path == null or path.curve == null:
		return Vector2.ZERO
	return path.to_global(path.curve.sample_baked(clampf(progress, 0.0, 1.0) * path.curve.get_baked_length()))

# @ace_expression
# @ace_name("Direction Along Path At")
# @ace_description("Which way the path is heading a fraction of the way along it, as a direction one unit long - point a camera down the track, aim a spawned thing along the lane, or rotate a marker to match the curve.")
# @ace_param_hint(path node)
# @ace_codegen_template("$PathFollowBehavior.direction_along_path_at({path}, {progress})")
func direction_along_path_at(path: Path2D, progress: float = 0.5) -> Vector2:
	if path == null or path.curve == null:
		return Vector2.RIGHT
	var sample: Transform2D = path.curve.sample_baked_with_rotation(clampf(progress, 0.0, 1.0) * path.curve.get_baked_length())
	return (Vector2.RIGHT.rotated(path.global_rotation + sample.x.angle())).normalized()

# @ace_expression
# @ace_name("Path Length")
# @ace_description("How long a route is in pixels, measured along the curve rather than corner to corner - divide by a speed to know how many seconds the trip takes, or space things evenly along it.")
# @ace_param_hint(path node)
# @ace_codegen_template("$PathFollowBehavior.path_length({path})")
func path_length(path: Path2D) -> float:
	if path == null or path.curve == null:
		return 0.0
	return path.curve.get_baked_length()

# @ace_expression
# @ace_name("Nearest Point On Path")
# @ace_description("The point on a route closest to a world position - snap a dragged tower onto the lane, work out where a stray unit rejoins its patrol, or find the spot on the track a racer left.")
# @ace_param_hint(path node)
# @ace_codegen_template("$PathFollowBehavior.nearest_point_on_path({path}, {point})")
func nearest_point_on_path(path: Path2D, point: Vector2) -> Vector2:
	if path == null or path.curve == null:
		return point
	return path.to_global(path.curve.get_closest_point(path.to_local(point)))

static func editor_gizmo_draw(params: Dictionary, gizmo_host: Node2D, canvas: CanvasItem) -> void:
	# Editor-gizmo contract (select the host or this behavior in the editor): draws the route
	# in the 2D viewport, with a green dot at the start and an orange one at the end, so a
	# patrol reads at a glance and a route drawn backwards is obvious before you press play.
	var drawn_route: Path2D = params.get("route", null) as Path2D
	if drawn_route == null or drawn_route.curve == null or drawn_route.curve.get_point_count() < 2:
		return
	var baked: PackedVector2Array = drawn_route.curve.get_baked_points()
	if baked.size() < 2:
		return
	var points: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in baked:
		points.append(drawn_route.to_global(point))
	# The points are world-space; the canvas rides the host, so draw through the inverse.
	canvas.draw_set_transform_matrix(gizmo_host.get_global_transform().affine_inverse())
	canvas.draw_polyline(points, Color(0.36, 0.78, 1.0, 0.9), 2.0)
	canvas.draw_circle(points[0], 4.0, Color(0.45, 1.0, 0.6, 0.9))
	canvas.draw_circle(points[points.size() - 1], 4.0, Color(1.0, 0.55, 0.35, 0.9))

# Follow Path behavior: walks the host along a drawn Path2D at a real speed (arc-length paced, so a tight corner does not speed it up). Follow Path starts a run, On Path Finished fires when a Once run reaches the end, and Is At Path End answers the other question - is it parked there right now. This pack is an event sheet - extend it by editing it.
