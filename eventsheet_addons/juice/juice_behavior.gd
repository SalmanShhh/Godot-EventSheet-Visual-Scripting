## @ace_tags(camera, juice)
## @ace_category("Juice")
## @ace_expose_all(node)
@icon("res://eventsheet_addons/behavior.svg")
class_name JuiceBehavior
extends Node

## The node this behavior acts on (its parent). Required host: CanvasItem.
var host: CanvasItem = null

func _enter_tree() -> void:
	host = get_parent() as CanvasItem
	if host == null:
		push_warning("JuiceBehavior behavior requires a CanvasItem parent.")

## @ace_trigger
## @ace_name("On Shake Stopped")
signal shake_stopped
## @ace_trigger
## @ace_name("On Zoom Finished")
signal zoom_finished
## @ace_trigger
## @ace_name("On Squash Finished")
signal squash_finished
## @ace_trigger
## @ace_name("On Slowmo Finished")
signal slowmo_finished

# --- Designer knobs (tune the FEEL in the Inspector) ---
## Peak camera shake offset, in pixels, at full trauma.
@export var max_offset: Vector2 = Vector2(24, 16)
## Peak camera roll (rotation) in degrees at full trauma.
@export_range(0.0, 30.0, 0.5) var max_roll_degrees: float = 3.0
## Trauma lost per second - higher means shorter, snappier shakes.
@export_range(0.1, 10.0, 0.1) var shake_decay: float = 1.4
## How fast the shake noise scrolls (the jitter rate).
@export_range(1.0, 60.0, 1.0) var shake_frequency: float = 25.0
## Clamp: the most zoomed-OUT the camera may go (smaller = further out).
@export_range(0.05, 1.0, 0.05) var min_zoom: float = 0.2
## Clamp: the most zoomed-IN the camera may go.
@export_range(1.0, 16.0, 0.5) var max_zoom: float = 5.0
## Slowmo: how the slow-down ramps IN (curve + direction).
@export_enum("linear", "sine", "quad", "cubic", "expo", "circ", "back") var slowmo_fade_in_trans: String = "sine"
@export_enum("in", "out", "in_out", "out_in") var slowmo_fade_in_ease: String = "out"
## Slowmo: how time ramps back OUT to normal.
@export_enum("linear", "sine", "quad", "cubic", "expo", "circ", "back") var slowmo_fade_out_trans: String = "sine"
@export_enum("in", "out", "in_out", "out_in") var slowmo_fade_out_ease: String = "in"
## Slowmo: seconds spent fading in / out (the ramp lengths, separate from the HOLD).
@export_range(0.0, 2.0, 0.05) var slowmo_fade_in_secs: float = 0.15
@export_range(0.0, 2.0, 0.05) var slowmo_fade_out_secs: float = 0.35
## Spring Squash: stiffness + damping of the spring-back (lower damping = bouncier).
@export_range(1.0, 1000.0, 1.0) var squash_stiffness: float = 250.0
@export_range(0.0, 1.0, 0.01) var squash_damping: float = 0.6

# --- Internal state ---
var trauma: float = 0.0
var shake_time: float = 0.0
var _shaking: bool = false
var _base_offset: Vector2 = Vector2.ZERO
var _base_rotation: float = 0.0
var _base_scale: Vector2 = Vector2.ONE
var _noise: FastNoiseLite = null
var _camera_override: Camera2D = null
# Anchored-zoom (Zoom Toward Point) interpolation state.
var _zoom_from: Vector2 = Vector2.ONE
var _zoom_to: Vector2 = Vector2.ONE
var _zoom_anchor: Vector2 = Vector2.ZERO
var _zoom_cam_from: Vector2 = Vector2.ZERO
# Slowmo state (single tween, kill-before-restart).
var _slowmo_tween: Tween = null
# Spring-squash state (per-frame integrator springing the scale back to rest).
var _squash_spring_active: bool = false
var _squash_value: Vector2 = Vector2.ONE
var _squash_velocity: Vector2 = Vector2.ZERO
## The camera these effects drive: an explicit override (Use Camera), else the active Camera2D -
## auto-found, so Shake / Zoom just work from anywhere without wiring a path.
func _camera() -> Camera2D:
	if _camera_override != null and is_instance_valid(_camera_override):
		return _camera_override
	var vp: Viewport = get_viewport()
	if vp == null:
		return null
	return vp.get_camera_2d()

func _ready() -> void:
	tree_exiting.connect(_on_tree_exiting)
	_noise = FastNoiseLite.new()
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 1.0
	_noise.seed = randi()
	if host is Node2D:
		_base_scale = (host as Node2D).scale
	elif host is Control:
		_base_scale = (host as Control).scale

func _on_tree_exiting() -> void:
	clear_slowmo()

func _process(delta: float) -> void:
	if trauma > 0.0:
		trauma = maxf(trauma - shake_decay * delta, 0.0)
		var cam: Camera2D = _camera()
		if cam != null:
			if not _shaking:
				_shaking = true
				_base_offset = cam.offset
				_base_rotation = cam.rotation
			if trauma > 0.0:
				shake_time += delta
				# Square the trauma so the shake ramps in perceptually (Squirrel Eiserloh's model).
				var amount: float = trauma * trauma
				var t: float = shake_time * shake_frequency
				cam.offset = _base_offset + Vector2(max_offset.x * amount * _noise.get_noise_2d(t, 0.0), max_offset.y * amount * _noise.get_noise_2d(0.0, t))
				cam.rotation = _base_rotation + deg_to_rad(max_roll_degrees) * amount * _noise.get_noise_2d(t, t)
			else:
				# Settled this frame: restore the camera's resting offset/roll.
				cam.offset = _base_offset
				cam.rotation = _base_rotation
		if trauma <= 0.0 and _shaking:
			_shaking = false
			shake_stopped.emit()
	if _squash_spring_active:
		# Spring the scale back to rest (semi-implicit, framerate-independent - same model as the Spring pack).
		_squash_velocity += (_base_scale - _squash_value) * squash_stiffness * delta
		_squash_velocity *= pow(1.0 - squash_damping, delta)
		_squash_value += _squash_velocity * delta
		if (_base_scale - _squash_value).length() < 0.001 and _squash_velocity.length() < 0.001:
			_squash_value = _base_scale
			_squash_velocity = Vector2.ZERO
			_squash_spring_active = false
			_apply_host_scale(_base_scale)
			squash_finished.emit()
		else:
			_apply_host_scale(_squash_value)

## @ace_action
## @ace_name("Shake")
## @ace_category("Juice")
## @ace_description("Adds screenshake to the active camera (0 = none, 1 = max). Stacks and decays automatically - fire it on every hit.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$JuiceBehavior.shake({strength})")
func shake(strength: float) -> void:
	trauma = clampf(trauma + strength, 0.0, 1.0)

## @ace_action
## @ace_name("Stop Shake")
## @ace_category("Juice")
## @ace_description("Cancels any shake and restores the camera to rest immediately.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$JuiceBehavior.stop_shake()")
func stop_shake() -> void:
	trauma = 0.0
	shake_time = 0.0
	var cam: Camera2D = _camera()
	if cam != null and _shaking:
		cam.offset = _base_offset
		cam.rotation = _base_rotation
	_shaking = false

## @ace_action
## @ace_name("Use Camera")
## @ace_category("Juice")
## @ace_description("Pin the effects to a specific Camera2D (by path). Leave it unused to auto-target whichever camera is active.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$JuiceBehavior.use_camera({camera_path})")
func use_camera(camera_path: NodePath) -> void:
	_camera_override = get_node_or_null(camera_path) as Camera2D

## @ace_action
## @ace_name("Zoom By Percent")
## @ace_category("Juice")
## @ace_description("Smoothly zooms the camera (100 = no change, 150 = zoom in 1.5x, 50 = zoom out). Clamped to the min/max zoom knobs.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$JuiceBehavior.zoom_by_percent({percent}, {duration})")
func zoom_by_percent(percent: float, duration: float) -> void:
	var cam: Camera2D = _camera()
	if cam == null:
		return
	var target_zoom: Vector2 = cam.zoom * (percent / 100.0)
	target_zoom = Vector2(clampf(target_zoom.x, min_zoom, max_zoom), clampf(target_zoom.y, min_zoom, max_zoom))
	var tw: Tween = create_tween()
	tw.tween_property(cam, "zoom", target_zoom, maxf(duration, 0.001)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.finished.connect(func() -> void: zoom_finished.emit())

## @ace_action
## @ace_name("Zoom To Position")
## @ace_category("Juice")
## @ace_description("Zooms in while gliding the camera so a world position becomes the screen CENTRE - frame a spot in one action.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$JuiceBehavior.zoom_to_position({world_position}, {percent}, {duration})")
func zoom_to_position(world_position: Vector2, percent: float, duration: float) -> void:
	var cam: Camera2D = _camera()
	if cam == null:
		return
	var target_zoom: Vector2 = cam.zoom * (percent / 100.0)
	target_zoom = Vector2(clampf(target_zoom.x, min_zoom, max_zoom), clampf(target_zoom.y, min_zoom, max_zoom))
	var seconds: float = maxf(duration, 0.001)
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(cam, "zoom", target_zoom, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(cam, "global_position", world_position, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.finished.connect(func() -> void: zoom_finished.emit())

## @ace_action
## @ace_name("Zoom Toward Point")
## @ace_category("Juice")
## @ace_description("Zooms while keeping a world position pinned under the same screen spot (mouse-wheel-to-cursor style) - great for strategy/map zoom.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$JuiceBehavior.zoom_toward_point({world_position}, {percent}, {duration})")
func zoom_toward_point(world_position: Vector2, percent: float, duration: float) -> void:
	var cam: Camera2D = _camera()
	if cam == null:
		return
	_zoom_cam_from = cam.global_position
	_zoom_from = cam.zoom
	var target_zoom: Vector2 = cam.zoom * (percent / 100.0)
	_zoom_to = Vector2(clampf(target_zoom.x, min_zoom, max_zoom), clampf(target_zoom.y, min_zoom, max_zoom))
	_zoom_anchor = world_position
	var tw: Tween = create_tween()
	tw.tween_method(_zoom_anchored_step, 0.0, 1.0, maxf(duration, 0.001)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.finished.connect(func() -> void: zoom_finished.emit())

## @ace_action
## @ace_name("Squash & Stretch")
## @ace_category("Juice")
## @ace_description("Pops the host (Node2D or Control) with a volume-preserving stretch that springs back elastically. Positive = stretch tall (a jump), negative = squash wide (a landing).")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$JuiceBehavior.squash_and_stretch({stretch}, {duration})")
func squash_and_stretch(stretch: float, duration: float) -> void:
	if host == null:
		return
	var s: float = clampf(stretch, -0.9, 5.0)
	var stretched: Vector2 = Vector2(_base_scale.x / (1.0 + s), _base_scale.y * (1.0 + s))
	if host is Node2D:
		(host as Node2D).scale = stretched
	elif host is Control:
		var c: Control = host as Control
		# Control scales from its top-left by default; centre the pivot so the pop reads right.
		c.pivot_offset = c.size / 2.0
		c.scale = stretched
	else:
		return
	var tw: Tween = create_tween()
	tw.tween_property(host, "scale", _base_scale, maxf(duration, 0.001)).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.finished.connect(func() -> void: squash_finished.emit())

## @ace_action
## @ace_name("Spring Squash")
## @ace_category("Juice")
## @ace_description("Pops the host (Node2D or Control) with a volume-preserving stretch that springs back via a real spring (the stiffness/damping knobs) - bouncier + more organic than the tween Squash & Stretch. Positive = stretch tall (a jump), negative = squash wide (a landing).")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$JuiceBehavior.spring_squash({stretch})")
func spring_squash(stretch: float) -> void:
	if host == null:
		return
	var s: float = clampf(stretch, -0.9, 5.0)
	_squash_value = Vector2(_base_scale.x / (1.0 + s), _base_scale.y * (1.0 + s))
	_squash_velocity = Vector2.ZERO
	_squash_spring_active = true
	_apply_host_scale(_squash_value)

## @ace_action
## @ace_name("Slowmo")
## @ace_category("Juice")
## @ace_description("Briefly slows Engine.time_scale to the target, HOLDS for a duration, then eases back to normal. Fade curves are Inspector knobs; pick whether the hold counts in realtime or scaled game time. Emits On Slowmo Finished.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$JuiceBehavior.slowmo({target_scale}, {hold_duration}, {duration_clock})")
func slowmo(target_scale: float, hold_duration: float, duration_clock: String) -> void:
	if _slowmo_tween != null:
		_slowmo_tween.kill()
	var ts: float = clampf(target_scale, 0.0, 1.0)
	var tw: Tween = create_tween()
	tw.set_ignore_time_scale(duration_clock == "realtime")
	tw.tween_method(_set_time_scale, Engine.time_scale, ts, maxf(slowmo_fade_in_secs, 0.0001)).set_trans(_slowmo_trans(slowmo_fade_in_trans)).set_ease(_slowmo_ease(slowmo_fade_in_ease))
	tw.tween_interval(maxf(hold_duration, 0.0))
	tw.tween_method(_set_time_scale, ts, 1.0, maxf(slowmo_fade_out_secs, 0.0001)).set_trans(_slowmo_trans(slowmo_fade_out_trans)).set_ease(_slowmo_ease(slowmo_fade_out_ease))
	tw.finished.connect(func() -> void: slowmo_finished.emit())
	_slowmo_tween = tw

## @ace_action
## @ace_name("Clear Slowmo")
## @ace_category("Juice")
## @ace_description("Cancels any slowmo and snaps Engine.time_scale back to 1.0 immediately (call on scene exit if a slowmo might still be running).")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$JuiceBehavior.clear_slowmo()")
func clear_slowmo() -> void:
	if _slowmo_tween != null:
		_slowmo_tween.kill()
		_slowmo_tween = null
	Engine.time_scale = 1.0

func _zoom_anchored_step(f: float) -> void:
	var cam: Camera2D = _camera()
	if cam == null:
		return
	var z: Vector2 = _zoom_from.lerp(_zoom_to, f)
	z.x = maxf(z.x, 0.001)
	z.y = maxf(z.y, 0.001)
	cam.zoom = z
	cam.global_position = _zoom_anchor - (_zoom_anchor - _zoom_cam_from) * (_zoom_from / z)

## @ace_condition
## @ace_name("Is Shaking")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$JuiceBehavior.is_shaking()")
func is_shaking() -> bool:
	return trauma > 0.0

## @ace_expression
## @ace_name("Trauma")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$JuiceBehavior.current_trauma()")
func current_trauma() -> float:
	return trauma

func _set_time_scale(s: float) -> void:
	Engine.time_scale = s

func _slowmo_trans(easing_name: String) -> int:
	match easing_name:
		"linear": return Tween.TRANS_LINEAR
		"quad": return Tween.TRANS_QUAD
		"cubic": return Tween.TRANS_CUBIC
		"expo": return Tween.TRANS_EXPO
		"circ": return Tween.TRANS_CIRC
		"back": return Tween.TRANS_BACK
		_: return Tween.TRANS_SINE

func _slowmo_ease(easing_name: String) -> int:
	match easing_name:
		"in": return Tween.EASE_IN
		"in_out": return Tween.EASE_IN_OUT
		"out_in": return Tween.EASE_OUT_IN
		_: return Tween.EASE_OUT

func _apply_host_scale(s: Vector2) -> void:
	if host is Node2D:
		(host as Node2D).scale = s
	elif host is Control:
		var c: Control = host as Control
		c.pivot_offset = c.size / 2.0
		c.scale = s

# Game feel, batteries included: screenshake, smooth zoom, and squash & stretch. The camera is found automatically - attach this anywhere and call Shake / Zoom; Squash & Stretch animates the node it's attached to.
