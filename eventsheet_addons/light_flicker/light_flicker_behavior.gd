## @ace_tags(lighting, juice, visual)
## @ace_category("Light Flicker")
## @ace_expose_all(node)
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/light_flicker/icon.svg")
class_name LightFlickerBehavior
extends Node
## Makes a light flicker like a flame. Attach it to any light, 2D or 3D, and its brightness walks between two numbers on a noise field - related from frame to frame, which is what reads as fire rather than as static. Between, Times A Second and Also Flicker Reach are tuned in the Inspector while the game runs; the sheet says when it starts and when it stops, and what it settles at.

## The node this behavior acts on (its parent). Required host: Node.
var host: Node = null

func _enter_tree() -> void:
	host = get_parent() as Node
	if host == null:
		push_warning("LightFlickerBehavior behavior requires a Node parent.")

## The dimmest and brightest the light gets, as a pair. 0.8 and 1.2 is a candle; 0.2 and 1.4
## is a failing bulb.
@export var between: Vector2 = Vector2(0.8, 1.2)
## How fast the flame moves. About 12 reads as a torch; below 3 reads as a slow breathing
## glow, and above 30 as an electrical fault.
@export_range(0.1, 60, 0.1) var times_a_second: float = 12.0
## Also breathe the light's reach in and out with its brightness, which is what a real flame
## does. A directional light has no reach and ignores this.
@export var also_flicker_reach: bool = false
## Whether the flicker is running right now. On means it starts flickering the moment the
## scene does.
@export var running: bool = true

## The property this host spells brightness with - `energy` on a 2D light, `light_energy` on
## a 3D one. Resolved once when the behaviour starts, because a light answers to exactly one
## of them and the answer cannot change while the game runs.
var _brightness_property: String = ""
## The property this host spells reach with, when it has one: a 2D point light scales a
## texture, an omni light has a radius in metres, a spot light has its own. A directional
## light reaches everywhere and has none, and then this stays empty.
var _reach_property: String = ""
## The reach the light was authored with. Reach is SCALED around this rather than
## replaced, so a designer's own radius survives the effect - and a scale of 1 is the way
## back to it, which is what the light settles on when the effect stops.
var _authored_reach: float = 0.0
## The noise field the flame is sampled from, and how far along it we are. NOISE, not a fresh
## random number per frame: consecutive samples of a noise field are RELATED, so the light
## wanders the way a flame does. Independent random numbers read as static instead.
var _flame: FastNoiseLite = null
var _walked: float = 0.0
## Seconds still to wait before Start Flickering takes effect, for the row that says "after".
var _waiting: float = 0.0

func _ready() -> void:
	if not _bind_to_light():
		push_warning("Light Flicker needs a light for a parent - a PointLight2D, an OmniLight3D, or any other light node.")
		return
	_flame = FastNoiseLite.new()
	# A seed per instance, so two torches in one room never flicker in step.
	_flame.seed = randi()
	_flame.frequency = 0.06

func _process(delta: float) -> void:
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

## @ace_action
## @ace_featured
## @ace_name("Start Flickering")
## @ace_description("Starts the flicker, either now or after a delay. The delay is what a row uses when a torch should catch a moment after the thing that lit it.")
## @ace_display_template("Start flickering after [b]{after_seconds}[/b] s")
## @ace_icon("res://eventsheet_addons/light_flicker/icon.svg")
## @ace_codegen_template("$LightFlickerBehavior.start_flickering({after_seconds})")
func start_flickering(after_seconds: float = 0.0) -> void:
	_waiting = maxf(after_seconds, 0.0)
	running = _waiting <= 0.0

## @ace_action
## @ace_name("Stop Flickering")
## @ace_description("Stops the flicker and leaves the light at one steady brightness - the number the row names, so a torch that goes out settles dark and one that is merely calmed settles lit. A flame that was flickering its reach puts that back to whatever the scene was authored with, rather than leaving the radius of the frame it stopped on.")
## @ace_display_template("Stop flickering and settle at [b]{settle_at}[/b]")
## @ace_icon("res://eventsheet_addons/light_flicker/icon.svg")
## @ace_codegen_template("$LightFlickerBehavior.stop_flickering({settle_at})")
func stop_flickering(settle_at: float = 1.0) -> void:
	running = false
	_waiting = 0.0
	if host == null or _brightness_property.is_empty():
		return
	_apply_light(settle_at, 1.0)

## @ace_condition
## @ace_name("Is Flickering")
## @ace_description("True while the light is actually flickering - false while it waits out a delay, and false once it has been stopped.")
## @ace_icon("res://eventsheet_addons/light_flicker/icon.svg")
## @ace_codegen_template("$LightFlickerBehavior.is_flickering()")
func is_flickering() -> bool:
	return running and _waiting <= 0.0

# Light Flicker: put this under any light and its brightness walks between two numbers on a noise field. Start Flickering and Stop Flickering are the two rows a sheet needs - one takes a delay, the other the brightness to settle at. Between, Times A Second and Also Flicker Reach are Inspector knobs. This pack is an event sheet - extend it by editing it.
