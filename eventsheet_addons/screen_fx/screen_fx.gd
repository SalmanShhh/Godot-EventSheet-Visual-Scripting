## @ace_tags(effects, shader, juice, camera, visual)
## @ace_category("Screen FX")
## @ace_expose_all(node)
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/screen_fx/icon.svg")
class_name ScreenFx
extends CanvasLayer
## Full-screen effects on one rectangle: a shockwave ring from a point in the world, a fade to a colour you can wait on, a blur, and a chromatic pulse. Add the pack's own scene to a scene once and the verbs are ordinary rows. The rectangle hides itself whenever every effect is idle, so a layer nobody is using costs nothing.

## The ColorRect the effects are drawn on, by the name the shipped scene gives it.
const RECT_NAME: String = "Screen"

## Every dial screen_fx.gdshader declares that can be RUNNING, with the value that means it is
## not. A rectangle whose dials all read these draws the screen back exactly as it arrived,
## which is the moment it is worth switching off. fade_color and shock_center are not here:
## they say what an effect looks like rather than whether one is happening.
const AT_REST: Dictionary = {"blur": 0.0, "fade_amount": 0.0, "shock_strength": 0.0, "chromatic": 0.0}

## How long a shockwave ring takes to cross the screen. A ring is a moment rather than a state,
## so it times itself instead of asking every row how long it should last.
@export_range(0.05, 3.0, 0.05) var ring_seconds: float = 0.55

var _rect: ColorRect = null
var _screen: ShaderMaterial = null

## The walks running right now, keyed by the dial they move, so a second call on the same dial
## replaces the first rather than the two of them fighting over it.
var _walks: Dictionary = {}
## Walks one dial to a value over a number of seconds, hands the tween back, and re-checks the
## rectangle when it lands. No time at all is a straight set rather than a tween nobody sees.
func _walk_dial(dial: String, to_value: float, seconds: float) -> Tween:
	if _screen == null:
		return null
	_stop_walk(dial)
	if seconds <= 0.0 or not is_inside_tree():
		_screen.set_shader_parameter(dial, to_value)
		_settle()
		return null
	if _rect != null:
		_rect.visible = true
	var walk: Tween = create_tween()
	walk.tween_property(_screen, "shader_parameter/" + dial, to_value, seconds)
	walk.finished.connect(_settle)
	_walks[dial] = walk
	return walk

func _ready() -> void:
	_rect = get_node_or_null(RECT_NAME) as ColorRect
	if _rect == null:
		push_warning("Screen FX expects a ColorRect named %s under it - add the pack's own screen_fx.tscn rather than a bare CanvasLayer." % RECT_NAME)
		return
	_screen = _rect.material as ShaderMaterial
	_seed_dials()
	# Whatever the scene was saved with, a layer starts at rest: nothing is running yet, so
	# nothing should be drawing.
	_rect.visible = false

## @ace_action
## @ace_featured
## @ace_name("Shockwave")
## @ace_description("Sends out a ring from a point in the WORLD - a boss that has just died, an explosion, a landing. The camera transform is applied, so the ring stays on the thing that caused it however the camera is moving.")
## @ace_display_template("Shockwave at [b]{at}[/b], strength [b]{strength}[/b]")
## @ace_icon("res://eventsheet_addons/screen_fx/icon.svg")
## @ace_codegen_template("$ScreenFx.shockwave({at}, {strength})")
func shockwave(at: Vector2 = Vector2.ZERO, strength: float = 1.0) -> void:
	if _screen == null:
		return
	_screen.set_shader_parameter("shock_center", _screen_point(at))
	_screen.set_shader_parameter("shock_radius", 0.0)
	_set_dial("shock_strength", clampf(strength, 0.0, 1.0))
	# The ring travels and fades at once, which is why the two walks are parallel: a ring that
	# faded after it had arrived would sit at the edge of the screen for half its life.
	var ring: Tween = _walk_dial("shock_radius", 1.4, ring_seconds)
	if ring != null:
		ring.set_parallel(true)
		ring.tween_property(_screen, "shader_parameter/shock_strength", 0.0, ring_seconds)

## @ace_action
## @ace_featured
## @ace_name("Fade To")
## @ace_description("Fades the whole screen to a colour and WAITS for it to land, so the rows under it are what happens next: change the scene, show the credits, start the level. That is the scene transition, spelled as two rows in one event.")
## @ace_display_template("Fade to [b]{colour}[/b] over [b]{seconds}[/b] s")
## @ace_icon("res://eventsheet_addons/screen_fx/icon.svg")
## @ace_codegen_template("await $ScreenFx.fade_to({colour}, {seconds})")
func fade_to(colour: Color = Color.BLACK, seconds: float = 1.0) -> void:
	if _screen == null:
		return
	_screen.set_shader_parameter("fade_color", colour)
	var walk: Tween = _walk_dial("fade_amount", 1.0, maxf(seconds, 0.0))
	if walk != null:
		await walk.finished

## @ace_action
## @ace_name("Fade Back")
## @ace_description("Fades the screen back from a colour to the game, and waits for that too - the other half of a transition, run once the new scene is up.")
## @ace_display_template("Fade back from [b]{colour}[/b] over [b]{seconds}[/b] s")
## @ace_icon("res://eventsheet_addons/screen_fx/icon.svg")
## @ace_codegen_template("await $ScreenFx.fade_back({colour}, {seconds})")
func fade_back(colour: Color = Color.BLACK, seconds: float = 1.0) -> void:
	if _screen == null:
		return
	_screen.set_shader_parameter("fade_color", colour)
	_set_dial("fade_amount", 1.0)
	var walk: Tween = _walk_dial("fade_amount", 0.0, maxf(seconds, 0.0))
	if walk != null:
		await walk.finished

## @ace_action
## @ace_name("Blur")
## @ace_description("Blurs the whole screen over a time - the world going soft behind a pause menu, a knockout, a dream. 0 is sharp again.")
## @ace_display_template("Blur to [b]{amount}[/b] over [b]{seconds}[/b] s")
## @ace_icon("res://eventsheet_addons/screen_fx/icon.svg")
## @ace_codegen_template("$ScreenFx.blur({amount}, {seconds})")
func blur(amount: float = 2.0, seconds: float = 0.3) -> void:
	_walk_dial("blur", maxf(amount, 0.0), maxf(seconds, 0.0))

## @ace_action
## @ace_name("Chromatic Pulse")
## @ace_description("Pulls the colour channels apart and lets them snap back - the one-frame lens error that reads as impact.")
## @ace_display_template("Chromatic pulse at [b]{strength}[/b]")
## @ace_icon("res://eventsheet_addons/screen_fx/icon.svg")
## @ace_codegen_template("$ScreenFx.chromatic_pulse({strength}, {seconds})")
func chromatic_pulse(strength: float = 0.6, seconds: float = 0.35) -> void:
	_set_dial("chromatic", clampf(strength, 0.0, 1.0))
	_walk_dial("chromatic", 0.0, maxf(seconds, 0.0))

## @ace_action
## @ace_name("Clear Screen Effects")
## @ace_description("Ends every effect at once and puts the screen back the way it was, which is the row a pause menu closing or a scene change wants.")
## @ace_icon("res://eventsheet_addons/screen_fx/icon.svg")
## @ace_codegen_template("$ScreenFx.clear_screen_effects()")
func clear_screen_effects() -> void:
	for dial: String in AT_REST:
		_set_dial(dial, float(AT_REST[dial]))

## @ace_condition
## @ace_name("Screen Effect Is Running")
## @ace_description("True while any effect is running - a fade held on, a blur, a ring still travelling.")
## @ace_icon("res://eventsheet_addons/screen_fx/icon.svg")
## @ace_codegen_template("$ScreenFx.screen_effect_is_running()")
func screen_effect_is_running() -> bool:
	if _screen == null:
		return false
	for dial: String in AT_REST:
		var held: Variant = _screen.get_shader_parameter(dial)
		if held != null and absf(float(held) - float(AT_REST[dial])) > 0.001:
			return true
	return false

## A world point as the shader wants it: 0 to 1 across the viewport. The canvas transform is
## whatever the camera did, so the ring lands where the thing was on screen.
func _screen_point(world: Vector2) -> Vector2:
	var view: Viewport = get_viewport()
	if view == null:
		return Vector2(0.5, 0.5)
	var size: Vector2 = view.get_visible_rect().size
	if size.x <= 0.0 or size.y <= 0.0:
		return Vector2(0.5, 0.5)
	return (view.get_canvas_transform() * world) / size

## Turns one dial straight away and wakes the rectangle if the dial says something is running.
func _set_dial(dial: String, value: float) -> void:
	if _screen == null:
		return
	_stop_walk(dial)
	_screen.set_shader_parameter(dial, value)
	_settle()

## Ends the walk on one dial, if there is one, leaving the dial wherever it had got to.
func _stop_walk(dial: String) -> void:
	var walk: Tween = _walks.get(dial, null)
	if walk != null and walk.is_valid():
		walk.kill()
	_walks.erase(dial)

## THE SWITCH. A rectangle covering the viewport redraws every pixel of it through the shader
## every frame, so one left on with nothing to do is a whole screen of work for no change at
## all. Asked after every change and at the end of every walk: running means visible, at rest
## means hidden, and a hidden Control is not drawn.
func _settle() -> void:
	if _rect != null:
		_rect.visible = screen_effect_is_running()

## Writes every dial the shader declares, once, before anything reads or walks one. An un-set
## uniform reads back as null rather than as the shader's own value, and a tween cannot even
## address `shader_parameter/<dial>` until it has been written.
func _seed_dials() -> void:
	if _screen == null or _screen.shader == null:
		return
	for declared: Dictionary in _screen.shader.get_shader_uniform_list():
		var dial: String = str(declared.get("name", ""))
		if dial.is_empty() or _screen.get_shader_parameter(dial) != null:
			continue
		var starts_at: Variant = RenderingServer.shader_get_parameter_default(
			_screen.shader.get_rid(), dial)
		# A renderer that draws nothing - a headless run, a dedicated server - knows no shader
		# defaults and answers null. The declared TYPE is still known, so an empty one of that is
		# written instead: the dial is addressable, and its value is never seen because nothing
		# is being drawn.
		if starts_at == null:
			starts_at = type_convert(starts_at, int(declared.get("type", TYPE_NIL)))
		_screen.set_shader_parameter(dial, starts_at)

# Screen FX: add screen_fx.tscn to your scene once (the pack does it for you when you add it to an object) and the four verbs are rows - Shockwave at a world point, Fade To a colour, Blur, Chromatic Pulse. Fade To is awaited, so the rows after it run when the fade lands: that is the scene transition. The rectangle turns itself off whenever nothing is running. This pack is an event sheet - extend it by editing it.
