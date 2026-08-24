## @ace_tags(lighting, juice, visual)
## @ace_category("Light Pulse")
## @ace_expose_all(node)
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/light_pulse/icon.svg")
class_name LightPulseBehavior
extends Node
## Makes a light breathe. Attach it to any light, 2D or 3D, and its brightness rides a smooth wave between two numbers - a beacon, a pickup, a rune that should read as deliberate rather than as merely alight. Between and Period Seconds are tuned in the Inspector while the game runs; the sheet says when it starts and when it stops, and what it settles at.

## The node this behavior acts on (its parent). Required host: Node.
var host: Node = null

func _enter_tree() -> void:
	host = get_parent() as Node
	if host == null:
		push_warning("LightPulseBehavior behavior requires a Node parent.")

## The dimmest and brightest the light gets, as a pair. The wave spends most of its time
## near the middle of the two and only touches the ends.
@export var between: Vector2 = Vector2(0.6, 1.4)
## How long one whole breath takes - dim to bright and back again. Two seconds reads as calm;
## a quarter of a second reads as an alarm.
@export_range(0.05, 60, 0.05) var period_seconds: float = 2.0
## Whether the pulse is running right now. On means it starts breathing the moment the scene
## does.
@export var running: bool = true

## The property this host spells brightness with - `energy` on a 2D light, `light_energy` on
## a 3D one. Resolved once when the behaviour starts, because a light answers to exactly one
## of them and the answer cannot change while the game runs.
var _brightness_property: String = ""
## How far into the current breath we are, in seconds. Kept rather than read off the game
## clock so that stopping and starting again resumes from where the wave was, and so that
## changing Period Seconds mid-breath does not snap the light.
var _breath: float = 0.0
## Seconds still to wait before Start Pulsing takes effect, for the row that says "after".
var _waiting: float = 0.0

func _ready() -> void:
	if not _bind_to_light():
		push_warning("Light Pulse needs a light for a parent - a PointLight2D, an OmniLight3D, or any other light node.")

func _process(delta: float) -> void:
	if host == null or _brightness_property.is_empty():
		return
	if _waiting > 0.0:
		_waiting = maxf(_waiting - delta, 0.0)
		running = _waiting <= 0.0
		return
	if not running:
		return
	_breath = fposmod(_breath + delta, maxf(period_seconds, 0.001))
	# A cosine, not a sine: a breath should START at the dim end rather than halfway up it, so
	# a light that begins pulsing does not jump on its first frame.
	var wave: float = (1.0 - cos(TAU * _breath / maxf(period_seconds, 0.001))) * 0.5
	_apply_light(lerpf(between.x, between.y, wave))

## The first of these properties the host really has. `in` on an object is the honest
## question: it answers for a project's own subclass of a light exactly as it does for the
## engine's classes, with no list of class names here to keep in step with the engine.
func _first_property_of(candidates: PackedStringArray) -> String:
	for candidate: String in candidates:
		if host != null and candidate in host:
			return candidate
	return ""

## Binds to the parent light: finds the property it spells brightness with.
## False means the parent is not a light at all, which is the one setup mistake to warn about.
func _bind_to_light() -> bool:
	_brightness_property = _first_property_of(PackedStringArray(["energy", "light_energy"]))
	return not _brightness_property.is_empty()

## Writes one frame of the effect. Brightness is all this pack moves.
func _apply_light(brightness: float) -> void:
	host.set(_brightness_property, brightness)

## @ace_action
## @ace_featured
## @ace_name("Start Pulsing")
## @ace_description("Starts the pulse, either now or after a delay - the delay is what a row uses when a beacon should come up a moment after the thing that switched it on.")
## @ace_display_template("Start pulsing after [b]{after_seconds}[/b] s")
## @ace_icon("res://eventsheet_addons/light_pulse/icon.svg")
## @ace_codegen_template("$LightPulseBehavior.start_pulsing({after_seconds})")
func start_pulsing(after_seconds: float = 0.0) -> void:
	_waiting = maxf(after_seconds, 0.0)
	running = _waiting <= 0.0

## @ace_action
## @ace_name("Stop Pulsing")
## @ace_description("Stops the pulse and leaves the light at one steady brightness - the number the row names.")
## @ace_display_template("Stop pulsing and settle at [b]{settle_at}[/b]")
## @ace_icon("res://eventsheet_addons/light_pulse/icon.svg")
## @ace_codegen_template("$LightPulseBehavior.stop_pulsing({settle_at})")
func stop_pulsing(settle_at: float = 1.0) -> void:
	running = false
	_waiting = 0.0
	if host == null or _brightness_property.is_empty():
		return
	_apply_light(settle_at)

## @ace_condition
## @ace_name("Is Pulsing")
## @ace_description("True while the light is actually pulsing - false while it waits out a delay, and false once it has been stopped.")
## @ace_icon("res://eventsheet_addons/light_pulse/icon.svg")
## @ace_codegen_template("$LightPulseBehavior.is_pulsing()")
func is_pulsing() -> bool:
	return running and _waiting <= 0.0

# Light Pulse: put this under any light and its brightness rides a smooth wave between two numbers. Start Pulsing and Stop Pulsing are the two rows a sheet needs - one takes a delay, the other the brightness to settle at. Between and Period Seconds are Inspector knobs. This pack is an event sheet - extend it by editing it.
