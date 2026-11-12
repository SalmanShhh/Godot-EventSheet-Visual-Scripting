## @ace_category("Orbit 3D")
## @ace_expose_all(node)
## @ace_version(1.0.0)
@tool
@icon("res://eventsheet_addons/orbit_3d/icon.svg")
class_name Orbit3DBehavior
extends Node
## Sweeps a Node3D around a center point in the horizontal XZ plane every frame, keeping its height level like a moon over a planet. Set the radius and speed, retarget the center to move the whole ring, and retune everything live from the sheet.
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
		push_warning("Orbit3D Behavior needs a Node3D: put it under one, or set Acts on.")

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
## X position of the orbit centre, in metres.
var center_x: float = 0.0
## Y position of the orbit centre, in metres.
var center_y: float = 0.0
## Z position of the orbit centre, in metres.
var center_z: float = 0.0
## Distance in world units the host stays from the orbit center.
@export var radius: float = 3.0
## Degrees per second the host travels around the orbit.
@export var speed_degrees: float = 90.0

func _process(delta: float) -> void:
	if Engine.is_editor_hint() and not _previewing:
		return
	if host == null:
		return
	if not center_captured:
		center_x = host.position.x
		center_y = host.position.y
		center_z = host.position.z
		center_captured = true
	angle += deg_to_rad(speed_degrees) * delta
	host.position = Vector3(center_x + cos(angle) * radius, center_y, center_z + sin(angle) * radius)

## @ace_action
## @ace_name("Set Orbit 3D Center")
## @ace_category("Orbit 3D")
## @ace_description("Orbits around the given point from now on.")
## @ace_icon("res://eventsheet_addons/orbit_3d/icon.svg")
## @ace_codegen_template("$Orbit3DBehavior.set_orbit3d_center({x}, {y}, {z})")
func set_orbit3d_center(x: float, y: float, z: float) -> void:
	center_x = x
	center_y = y
	center_z = z
	center_captured = true

## @ace_hidden
static func editor_preview_sample(params: Dictionary, base: Dictionary, time: float) -> Dictionary:
	# Editor-preview contract (Tools > Preview Behaviors on Selected Node): the same circle the
	# tick walks, solved for a time instead of accumulated - angle(t) = speed*t - so the editor
	# can show the ring without running the behavior or touching the saved position. The centre
	# is the host's REST position, which is what the running behavior captures on its first frame.
	var rest: Variant = base.get("position", null)
	if not rest is Vector3:
		return {}
	var centre: Vector3 = rest
	var phase: float = deg_to_rad(float(params.get("speed_degrees", 90.0)) * time)
	var ring_radius: float = float(params.get("radius", 3.0))
	return {"position": Vector3(centre.x + cos(phase) * ring_radius, centre.y, centre.z + sin(phase) * ring_radius)}

# Orbit 3D behavior (event-sheet-style): circles the host around its starting point in the XZ plane (Y stays).
