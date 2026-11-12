## @ace_tags(lighting, juice, visual)
## @ace_category("Light Flicker")
## @ace_expose_all(node)
## @ace_version(1.0.0)
@tool
@icon("res://eventsheet_addons/light_flicker/icon.svg")
class_name LightFlickerBehavior
extends Node
## Makes a light flicker like a flame. Attach it to any light, 2D or 3D, and its brightness walks between two numbers on a noise field - related from frame to frame, which is what reads as fire rather than as static. Between, Times A Second and Also Flicker Reach are tuned in the Inspector while the game runs; the sheet says when it starts and when it stops, and what it settles at.

## @ace_hidden
## The node this behavior acts on. Empty: its parent.
@export var acts_on: Node = null

## The node this behavior acts on (Acts on, or else its parent). Required host: Node.
var host: Node = null

func _enter_tree() -> void:
	host = acts_on if acts_on != null else get_parent() as Node
	if host == null:
		push_warning("Light Flicker Behavior needs a parent node: put it under one, or set Acts on.")

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

## The dimmest and brightest the light gets, as a pair. 0.8 and 1.2 is a candle; 0.2 and 1.4 is a failing bulb.
@export var between: Vector2 = Vector2(0.8, 1.2)
## How fast the flame moves. About 12 reads as a torch; below 3 reads as a slow breathing glow, and above 30 as an electrical fault.
@export_range(0.1, 60, 0.1) var times_a_second: float = 12.0
## Also breathe the light's reach in and out with its brightness, which is what a real flame does. A directional light has no reach and ignores this.
@export var also_flicker_reach: bool = false
## Whether the flicker is running right now. On means it starts flickering the moment the scene does.
@export var running: bool = true:
	set(value):
		running = value
		# Every write lands here - a sheet's Set Running action, the Inspector, another script -
		# so processing follows the flame whoever switched it. A delay still counts down per
		# frame, which is why waiting counts as running here.
		set_process(value or _waiting > 0.0)

## Name of the host's brightness property: energy in 2D, light_energy in 3D.
var _brightness_property: String = ""
## Name of the host's reach property; empty for lights with none.
var _reach_property: String = ""
## Reach the light was authored with; the flicker scales around it.
var _authored_reach: float = 0.0
# The flame is driven by NOISE, not a fresh
# random number per frame: consecutive samples of a noise field are RELATED, so the light
# wanders the way a flame does. Independent random numbers read as static instead.
## The noise field the flicker samples its brightness from.
var _flame: FastNoiseLite = null
## Running time that drives the flicker pattern.
var _walked: float = 0.0
## Seconds still to wait before Start Flickering takes effect, for the row that says "after".
var _waiting: float = 0.0

func _ready() -> void:
	if not _bind_to_light():
		push_warning("Light Flicker needs a light for a parent - a PointLight2D, an OmniLight3D, or any other light node.")
		# No light to drive means no frame will ever have work; stop paying for the tick at all.
		set_process(false)
		return
	_flame = FastNoiseLite.new()
	# A seed per instance, so two torches in one room never flicker in step.
	_flame.seed = randi()
	_flame.frequency = 0.06
	# Processing runs only while the flame does - a flicker authored as stopped costs nothing
	# until Start Flickering.
	set_process(running)

func _process(delta: float) -> void:
	if Engine.is_editor_hint() and not _previewing:
		return
	if host == null or _brightness_property.is_empty():
		return
	if _waiting > 0.0:
		_waiting = maxf(_waiting - delta, 0.0)
		running = _waiting <= 0.0
		return
	if not running:
		return
	_walked += delta * times_a_second
	# Noise runs -1 to 1; the flame wants 0 to 1 so it can be read as a distance between the
	# two numbers the Inspector holds.
	var flame: float = (_flame.get_noise_1d(_walked) + 1.0) * 0.5
	# A real flame's light shrinks as it dims, so reach follows brightness rather than running
	# on a clock of its own - but only within a tenth either way, because a light whose radius
	# jumps is a light that pops.
	var reach_scale: float = lerpf(0.92, 1.08, flame) if also_flicker_reach else 1.0
	_apply_light(lerpf(between.x, between.y, flame), reach_scale)

## The first of these properties the host really has. `in` on an object is the honest
## question: it answers for a project's own subclass of a light exactly as it does for the
## engine's classes, with no list of class names here to keep in step with the engine.
func _first_property_of(candidates: PackedStringArray) -> String:
	for candidate: String in candidates:
		if host != null and candidate in host:
			return candidate
	return ""

## Binds to the parent light: finds the property it spells brightness with, and remembers the reach it was authored with.
## False means the parent is not a light at all, which is the one setup mistake to warn about.
func _bind_to_light() -> bool:
	_brightness_property = _first_property_of(PackedStringArray(["energy", "light_energy"]))
	_reach_property = _first_property_of(PackedStringArray(["texture_scale", "omni_range", "spot_range"]))
	if not _reach_property.is_empty():
		_authored_reach = float(host.get(_reach_property))
	return not _brightness_property.is_empty()

## Writes one frame of the effect: brightness always, and reach whenever also_flicker_reach asked for it.
## The scale is around the reach the scene was AUTHORED with rather than around the current
## one, so a scale of 1 is the way back - which is what a stopped effect settles on. Skipping
## the write for a scale of 1 is how a torch put out mid-flicker kept the radius of the frame
## it happened to die on.
func _apply_light(brightness: float, reach_scale: float) -> void:
	host.set(_brightness_property, brightness)
	if also_flicker_reach and not _reach_property.is_empty():
		host.set(_reach_property, _authored_reach * reach_scale)

## Starts the flicker, either now or after a delay. The delay is what a row uses when a torch
## should catch a moment after the thing that lit it.
## @ace_action
## @ace_featured
## @ace_name("Start Flickering")
## @ace_display_template("Start flickering after [b]{after_seconds}[/b] s")
## @ace_lift_example("[[target|node: $LightFlickerBehavior]].start_flickering([[after_seconds|argument: 0.5]])")
## @ace_lift_example("[[target|node: $LightFlickerBehavior]].start_flickering()")
## @ace_icon("res://eventsheet_addons/light_flicker/icon.svg")
## @ace_codegen_template("$LightFlickerBehavior.start_flickering({after_seconds})")
func start_flickering(after_seconds: float = 0.0) -> void:
	_waiting = maxf(after_seconds, 0.0)
	running = _waiting <= 0.0
	# A delayed start still counts its delay down per frame - waiting is not idle.
	set_process(true)

## Stops the flicker and leaves the light at one steady brightness - the number the row
## names, so a torch that goes out settles dark and one that is merely calmed settles lit.
## A flame that was flickering its reach puts that back to whatever the scene was authored
## with, rather than leaving the radius of the frame it stopped on.
## @ace_action
## @ace_name("Stop Flickering")
## @ace_display_template("Stop flickering and settle at [b]{settle_at}[/b]")
## @ace_lift_example("[[target|node: $LightFlickerBehavior]].stop_flickering([[settle_at|argument: 1.0]])")
## @ace_lift_example("[[target|node: $LightFlickerBehavior]].stop_flickering()")
## @ace_icon("res://eventsheet_addons/light_flicker/icon.svg")
## @ace_codegen_template("$LightFlickerBehavior.stop_flickering({settle_at})")
func stop_flickering(settle_at: float = 1.0) -> void:
	running = false
	_waiting = 0.0
	# A stopped flame costs nothing per frame; Start Flickering turns processing back on.
	set_process(false)
	if host == null or _brightness_property.is_empty():
		return
	_apply_light(settle_at, 1.0)

## True while the light is actually flickering - false while it waits out a delay, and false
## once it has been stopped.
## @ace_condition
## @ace_name("Is Flickering")
## @ace_icon("res://eventsheet_addons/light_flicker/icon.svg")
## @ace_codegen_template("$LightFlickerBehavior.is_flickering()")
func is_flickering() -> bool:
	return running and _waiting <= 0.0

# Light Flicker: put this under any light and its brightness walks between two numbers on a noise field. Start Flickering and Stop Flickering are the two rows a sheet needs - one takes a delay, the other the brightness to settle at. Between, Times A Second and Also Flicker Reach are Inspector knobs. This pack is an event sheet - extend it by editing it.
