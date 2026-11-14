## @ace_tags(movement, visual)
## @ace_category("Rotate")
## @ace_version(1.0.0)
@tool
@icon("res://eventsheet_addons/rotate/icon.svg")
class_name RotateBehavior
extends Node
## Constant rotation for the host node: spins at Speed in degrees per second, optionally ramping by Acceleration, with one Rotation Type knob covering a 2D node's rotation and a 3D node's X, Y, or Z axis. Previewable in the editor with the Preview button in the Inspector, no game run needed.

## @ace_hidden
## The node this behavior acts on. Empty: its parent.
@export var acts_on: Node = null

## The node this behavior acts on (Acts on, or else its parent). Required host: Node.
var host: Node = null

func _enter_tree() -> void:
	host = acts_on if acts_on != null else get_parent() as Node
	if host == null:
		push_warning("Rotate Behavior needs a parent node: put it under one, or set Acts on.")

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

# --- Choices (the stored words are the promise: saved scenes keep them) ---
## Spin a Node2D by its rotation.
const ROTATION_TYPE_2D := "2d"
## Spin a Node3D about its x axis.
const ROTATION_TYPE_X := "x"
## Spin a Node3D about its y axis.
const ROTATION_TYPE_Y := "y"
## Spin a Node3D about its z axis.
const ROTATION_TYPE_Z := "z"

# --- Designer knobs (tune in the Inspector) ---
## Spin on/off - Set Rotation Enabled flips it at runtime.
@export var rotate_enabled: bool = true:
	set(value):
		rotate_enabled = value
		# Every write lands here - a sheet's Set Rotate Enabled action, the Inspector, another
		# script - so the physics frame follows the spin whoever switched it, not just the
		# Set Rotation Enabled row.
		set_physics_process(value)
## Rotation speed in degrees per second (negative = the other way).
@export var speed: float = 90.0
## Speed change in degrees per second, per second (0 = constant speed).
@export var acceleration: float = 0.0
## What to spin: a Node2D's rotation, or a Node3D's X / Y / Z axis.
@export_enum("2d", "x", "y", "z") var rotation_type: String = "2d"

# --- Internal state ---
# The live speed (deg/s) - starts at the Speed knob, then Acceleration ramps it.
## Rotation speed now, in degrees per second, easing toward the target speed.
var _current_speed: float = 0.0
## True once the current speed has been set from the Inspector.
var _speed_primed: bool = false

func _ready() -> void:
	# Physics processing runs only while the spin does - a host authored with Spin off costs
	# nothing per frame until Set Rotation Enabled turns it on. Speed is deliberately not part
	# of this test: Acceleration can ramp a spin up from a standing start.
	set_physics_process(rotate_enabled)

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() and not _previewing:
		return
	if not rotate_enabled or host == null:
		return
	if not _speed_primed:
		_current_speed = speed
		_speed_primed = true
	_current_speed += acceleration * delta
	var step: float = deg_to_rad(_current_speed * delta)
	# Type-safe spin: a mismatched host (rotation_type "2d" on a Node3D) is a no-op,
	# never an error - swap the knob or the parent freely.
	if rotation_type == ROTATION_TYPE_2D and host is Node2D:
		(host as Node2D).rotation += step
	elif host is Node3D:
		match rotation_type:
			ROTATION_TYPE_X:
				(host as Node3D).rotation.x += step
			ROTATION_TYPE_Y:
				(host as Node3D).rotation.y += step
			ROTATION_TYPE_Z:
				(host as Node3D).rotation.z += step

## @ace_condition
## @ace_name("Is Rotating")
## @ace_icon("res://eventsheet_addons/rotate/icon.svg")
## @ace_codegen_template("$RotateBehavior.is_rotating()")
func is_rotating() -> bool:
	return rotate_enabled and absf(_current_speed if _speed_primed else speed) > 0.001

## @ace_expression
## @ace_name("Rotation Speed")
## @ace_icon("res://eventsheet_addons/rotate/icon.svg")
## @ace_codegen_template("$RotateBehavior.rotation_speed()")
func rotation_speed() -> float:
	return _current_speed if _speed_primed else speed

## Turns the spin on or off - the pause/resume toggle.
## @ace_action
## @ace_name("Set Rotation Enabled")
## @ace_icon("res://eventsheet_addons/rotate/icon.svg")
## @ace_codegen_template("$RotateBehavior.set_rotation_enabled({enabled})")
func set_rotation_enabled(enabled: bool) -> void:
	rotate_enabled = enabled
	# A stopped spin costs nothing per physics frame; turning it back on restores the tick.
	set_physics_process(enabled)

## Sets the live rotation speed in degrees per second (negative = the other way).
## @ace_action
## @ace_name("Set Rotation Speed")
## @ace_icon("res://eventsheet_addons/rotate/icon.svg")
## @ace_codegen_template("$RotateBehavior.set_rotation_speed({degrees_per_second})")
func set_rotation_speed(degrees_per_second: float) -> void:
	speed = degrees_per_second
	_current_speed = degrees_per_second
	_speed_primed = true

## Sets the acceleration in degrees per second, per second (0 = constant).
## @ace_action
## @ace_name("Set Rotation Acceleration")
## @ace_icon("res://eventsheet_addons/rotate/icon.svg")
## @ace_codegen_template("$RotateBehavior.set_rotation_acceleration({degrees_per_second_squared})")
func set_rotation_acceleration(degrees_per_second_squared: float) -> void:
	acceleration = degrees_per_second_squared

## Switches what spins: a Node2D's rotation, or a Node3D's X / Y / Z axis.
## @ace_action
## @ace_name("Set Rotation Type")
## @ace_param_options(type 2d=2D rotation, x=3D X axis, y=3D Y axis, z=3D Z axis)
## @ace_icon("res://eventsheet_addons/rotate/icon.svg")
## @ace_codegen_template("$RotateBehavior.set_rotation_type("{type}")")
func set_rotation_type(type: String) -> void:
	if type in [ROTATION_TYPE_2D, ROTATION_TYPE_X, ROTATION_TYPE_Y, ROTATION_TYPE_Z]:
		rotation_type = type

## Flips the spin direction (negates the live speed).
## @ace_action
## @ace_name("Reverse Rotation")
## @ace_icon("res://eventsheet_addons/rotate/icon.svg")
## @ace_codegen_template("$RotateBehavior.reverse_rotation()")
func reverse_rotation() -> void:
	if not _speed_primed:
		_current_speed = speed
		_speed_primed = true
	_current_speed = -_current_speed
	speed = _current_speed

# Rotate behavior (event-sheet parity): spins the host at Speed degrees/second, ramping by Acceleration. Rotation Type covers a 2D node's rotation and a 3D node's X, Y, or Z axis - one pack for pickups, fans, planets, and drills. Set Rotation Enabled toggles it; Reverse flips direction. Previewable in the editor with the Preview button in the Inspector. This pack is an event sheet - extend it by editing it.
