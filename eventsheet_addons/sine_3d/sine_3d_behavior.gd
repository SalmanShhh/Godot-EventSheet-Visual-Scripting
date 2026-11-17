## @ace_category("Sine 3D")
## @ace_expose_all(node)
## @ace_version(1.0.0)
@tool
@icon("res://eventsheet_addons/sine_3d/icon.svg")
class_name Sine3DBehavior
extends Node
## Automatic wobble, bob, and sway for a Node3D: pick an axis (move along x, y, or z, or turn around Y) and a wave shape, and the host oscillates around wherever it started. Runs straight from the Inspector with no event rows, and can be paused, retuned, or restarted live from the sheet.
##
## Changes on its parent: position, rotation.

## @ace_hidden
## The node this behavior acts on. Empty: its parent.
@export var acts_on: Node3D = null

## The node this behavior acts on (Acts on, or else its parent). Required host: Node3D.
var host: Node3D = null

func _enter_tree() -> void:
	host = acts_on if acts_on != null else get_parent() as Node3D
	if host == null:
		push_warning("Sine3D Behavior needs a Node3D: put it under one, or set Acts on. This one is at " + str(get_path()) + ".")

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

## Which axis the host oscillates on - x, y, z position or rotation around Y.
@export_enum("x", "y", "z", "rotation-y") var movement: String = "y"
## The waveform shape used for the oscillation.
@export_enum("sine", "triangle", "sawtooth", "reverse-sawtooth", "square") var wave: String = "sine"
## Seconds the wave takes to complete one full cycle.
@export var period: float = 4.0
## Peak offset from the start position (degrees for rotation-y).
@export var magnitude: float = 2.0
## Starting offset into the wave cycle, in degrees.
@export var phase_degrees: float = 0.0
## Seconds the wave has been running.
var time: float = 0.0
## The host's X position before the wave moved it.
var base_x: float = 0.0
## The host's Y position before the wave moved it.
var base_y: float = 0.0
## The host's Z position before the wave moved it.
var base_z: float = 0.0
## The host's turn around Y before the wave changed it.
var base_rot_y: float = 0.0
## True once the starting values have been recorded.
var base_captured: bool = false
## When on the oscillation runs; turn off to freeze the host.
@export var active: bool = true:
	set(value):
		active = value
		# A frozen host costs nothing per frame; turning it back on restores the tick.
		set_process(value)

func _ready() -> void:
	# Processing runs only while the wobble does - a host authored frozen costs nothing
	# per frame until Set Sine 3D Active turns it on.
	set_process(active)
	if host is RigidBody3D:
		push_warning("Sine 3D on %s: this behaviour moves a RigidBody3D by changing its position, but the physics engine moves that body too, so the two will fight (jitter, snapping back, passing through walls). Put the behaviour under a node that is not a physics body, such as the MeshInstance3D inside it, or move the body with apply_central_impulse() or its linear_velocity instead." % (str(get_path()) if is_inside_tree() else str(name)))

func _process(delta: float) -> void:
	if Engine.is_editor_hint() and not _previewing:
		return
	if not active or host == null:
		return
	if not base_captured:
		base_x = host.position.x
		base_y = host.position.y
		base_z = host.position.z
		base_rot_y = host.rotation.y
		base_captured = true
	time += delta
	var t := time / maxf(period, 0.001) + phase_degrees / 360.0
	var offset := _wave(t) * magnitude
	if movement == "x":
		host.position.x = base_x + offset
	elif movement == "y":
		host.position.y = base_y + offset
	elif movement == "z":
		host.position.z = base_z + offset
	elif movement == "rotation-y":
		host.rotation.y = base_rot_y + offset * 0.0174533

## @ace_action
## @ace_name("Set Sine 3D Active")
## @ace_category("Sine 3D")
## @ace_description("Pauses or resumes the oscillation.")
## @ace_icon("res://eventsheet_addons/sine_3d/icon.svg")
## @ace_codegen_template("$Sine3DBehavior.set_sine3d_active({is_active})")
func set_sine3d_active(is_active: bool) -> void:
	active = is_active
	# A frozen host costs nothing per frame; resuming turns processing back on.
	set_process(is_active)

## @ace_action
## @ace_name("Set Phase")
## @ace_category("Sine 3D")
## @ace_description("Phase offset in degrees.")
## @ace_icon("res://eventsheet_addons/sine_3d/icon.svg")
## @ace_codegen_template("$Sine3DBehavior.set_sine3d_phase({degrees})")
func set_sine3d_phase(degrees: float) -> void:
	phase_degrees = degrees

## @ace_action
## @ace_name("Reset Sine 3D")
## @ace_category("Sine 3D")
## @ace_description("Restarts the wave from the current state.")
## @ace_icon("res://eventsheet_addons/sine_3d/icon.svg")
## @ace_codegen_template("$Sine3DBehavior.reset_sine3d()")
func reset_sine3d() -> void:
	time = 0.0
	base_captured = false

## @ace_hidden
func _wave(t: float) -> float:
	var cycle := fposmod(t, 1.0)
	match wave:
		"triangle":
			return 1.0 - 4.0 * absf(cycle - 0.5)
		"sawtooth":
			return 2.0 * cycle - 1.0
		"reverse-sawtooth":
			return 1.0 - 2.0 * cycle
		"square":
			return 1.0 if cycle < 0.5 else -1.0
	return sin(cycle * TAU)

# Sine 3D behavior (event-sheet-style): oscillates the host along an axis (x, y, z) or around the Y axis (rotation-y), with the full wave set.
