## @ace_tags(camera, juice)
## @ace_category("Juice")
## @ace_expose_all(node)
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/juice/icon.svg")
class_name JuiceBehavior
extends Node
## Game feel from event rows: screenshake, recoil, head bob, zoom, squash and stretch, slowmo, hitstop, damage flash and blink, punch transforms, ghost trails, screen FX (vignette, chromatic kick, speed lines), varied one-shot audio, and eased score tickers in one behavior. Camera effects find the active Camera2D on their own, and every effect is fire-and-forget with an On Finished trigger so you can chain the next beat.

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
## @ace_trigger
## @ace_name("On Hitstop Finished")
signal hitstop_finished
## @ace_trigger
## @ace_name("On Tilt Finished")
signal tilt_finished
## @ace_trigger
## @ace_name("On Flash Finished")
signal flash_finished
## @ace_trigger
## @ace_name("On Punch Finished")
signal punch_finished
## @ace_trigger
## @ace_name("On Ticker Finished")
signal ticker_finished(ticker_name: String)

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
## Slowmo: which direction the fade-IN curve eases (in / out / in-out / out-in).
@export_enum("in", "out", "in_out", "out_in") var slowmo_fade_in_ease: String = "out"
## Slowmo: how time ramps back OUT to normal.
@export_enum("linear", "sine", "quad", "cubic", "expo", "circ", "back") var slowmo_fade_out_trans: String = "sine"
## Slowmo: which direction the fade-OUT curve eases back to normal speed (in / out / in-out / out-in).
@export_enum("in", "out", "in_out", "out_in") var slowmo_fade_out_ease: String = "in"
## Slowmo: seconds spent fading in / out (the ramp lengths, separate from the HOLD).
@export_range(0.0, 2.0, 0.05) var slowmo_fade_in_secs: float = 0.15
## Slowmo: seconds spent easing back OUT to normal speed (separate from the HOLD).
@export_range(0.0, 2.0, 0.05) var slowmo_fade_out_secs: float = 0.35
## Spring Squash: stiffness + damping of the spring-back (lower damping = bouncier).
@export_range(1.0, 1000.0, 1.0) var squash_stiffness: float = 250.0
## Spring Squash: how quickly the spring-back settles (lower = bouncier, higher = calmer).
@export_range(0.0, 1.0, 0.01) var squash_damping: float = 0.6
## How fast a Recoil kick returns to centre, in pixels per second.
@export_range(10.0, 2000.0, 5.0) var recoil_recovery: float = 140.0

# --- Internal state ---
var trauma: float = 0.0
var shake_time: float = 0.0
var _shaking: bool = false
# True while ANY camera effect is holding the camera away from its captured rest pose.
var _cam_driving: bool = false
var _recoil_vec: Vector2 = Vector2.ZERO
var _bob_active: bool = false
var _bob_time: float = 0.0
var _bob_amplitude: float = 6.0
var _bob_frequency: float = 2.2
var _jitter_active: bool = false
var _jitter_time: float = 0.0
var _jitter_amount: float = 3.0
var _tilt_roll: float = 0.0
var _tilt_tween: Tween = null
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
# Hitstop state (a brief freeze; driven by a REALTIME timer so it un-freezes even at time_scale 0).
var _hitstop_active: bool = false
var _hitstop_prev_scale: float = 1.0
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

# The tint overlay: a top CanvasLayer ColorRect built on first use - the screen
# wash for damage reds, poison greens, flashback sepias. Strength IS the opacity.
var _tint_overlay: CanvasLayer = null
var _tint_rect: ColorRect = null

# Flash / blink state (modulate-based, so both compose with Set Host Tint).
var _flash_tween: Tween = null
var _flash_restore: Color = Color.WHITE
var _blink_active: bool = false
var _blink_time: float = 0.0
var _blink_rate: float = 8.0
var _blink_min_alpha: float = 0.15
var _blink_base_alpha: float = 1.0
# Punch state (kick out, spring back; rest captured per gesture so repeats never drift).
var _punch_rot_tween: Tween = null
var _punch_rot_rest: float = 0.0
var _punch_pos_tween: Tween = null
var _punch_pos_rest: Vector2 = Vector2.ZERO
# Ghost-trail state (stamped fading sprite copies).
var _trail_active: bool = false
var _trail_interval: float = 0.05
var _trail_fade: float = 0.4
var _trail_tint: Color = Color.WHITE
var _trail_timer: float = 0.0
# Eased tickers (Count To): name -> displayed value / target / driving tween.
var _tickers: Dictionary = {}
var _ticker_targets: Dictionary = {}
var _ticker_tweens: Dictionary = {}

# The screen-FX overlay: one full-screen shader with three dials (vignette, chromatic
# aberration, radial speed lines) built on first use, hidden whenever every dial is 0.
var _fx_layer: CanvasLayer = null
var _fx_rect: ColorRect = null
var _fx_material: ShaderMaterial = null
var _vignette_tween: Tween = null
var _chroma_tween: Tween = null
const _FX_SHADER: String = """
shader_type canvas_item;
uniform sampler2D screen_texture: hint_screen_texture, filter_linear_mipmap;
uniform float vignette_strength = 0.0;
uniform vec4 vignette_color: source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float chroma_strength = 0.0;
uniform float speed_lines = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 centered = uv - vec2(0.5);
	vec2 chroma_offset = centered * chroma_strength * 0.03;
	vec3 col = vec3(
		texture(screen_texture, uv + chroma_offset).r,
		texture(screen_texture, uv).g,
		texture(screen_texture, uv - chroma_offset).b);
	float vignette = smoothstep(0.35, 1.0, length(centered) * 1.5) * vignette_strength;
	col = mix(col, vignette_color.rgb, clamp(vignette, 0.0, 1.0));
	float angle = atan(centered.y, centered.x);
	float streak = step(0.86, fract(sin(floor(angle * 60.0) + floor(TIME * 24.0) * 7.0) * 43758.545));
	float ring = smoothstep(0.2, 0.65, length(centered));
	col = mix(col, vec3(1.0), streak * ring * clamp(speed_lines, 0.0, 1.0) * 0.65);
	COLOR = vec4(col, 1.0);
}
"""

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
	_hitstop_active = false
	clear_slowmo()

func _process(delta: float) -> void:
	# Effect STATE advances camera-or-not (headless-safe: trauma must decay and recoil must
	# recover even when no viewport exists); only the camera write below needs a camera.
	if trauma > 0.0:
		trauma = maxf(trauma - shake_decay * delta, 0.0)
		shake_time += delta
		_shaking = true
	if trauma <= 0.0 and _shaking:
		_shaking = false
		shake_stopped.emit()
	if _recoil_vec != Vector2.ZERO:
		_recoil_vec = _recoil_vec.move_toward(Vector2.ZERO, recoil_recovery * delta)
	if _bob_active:
		_bob_time += delta * _bob_frequency
	if _jitter_active:
		_jitter_time += delta * shake_frequency
	var cam: Camera2D = _camera()
	if cam != null:
		# One mixer for every camera effect: all contributions sum around ONE captured rest pose,
		# so shake + recoil + bob + jitter + tilt compose instead of fighting over the offset.
		var cam_wants: bool = trauma > 0.0 or _bob_active or _jitter_active or _recoil_vec != Vector2.ZERO or absf(_tilt_roll) > 0.0001
		if cam_wants:
			if not _cam_driving:
				_cam_driving = true
				_base_offset = cam.offset
				_base_rotation = cam.rotation
			var fx_offset: Vector2 = _recoil_vec
			var fx_roll: float = deg_to_rad(_tilt_roll)
			if trauma > 0.0:
				# Square the trauma so the shake ramps in perceptually (Squirrel Eiserloh's model).
				var amount: float = trauma * trauma
				var t: float = shake_time * shake_frequency
				fx_offset += Vector2(max_offset.x * amount * _noise.get_noise_2d(t, 0.0), max_offset.y * amount * _noise.get_noise_2d(0.0, t))
				fx_roll += deg_to_rad(max_roll_degrees) * amount * _noise.get_noise_2d(t, t)
			if _jitter_active:
				fx_offset += Vector2(_jitter_amount * _noise.get_noise_2d(_jitter_time, 100.0), _jitter_amount * _noise.get_noise_2d(100.0, _jitter_time))
			if _bob_active:
				# A walking figure-8: side sway at half rate, one vertical dip per step.
				fx_offset += Vector2(sin(_bob_time * TAU * 0.5) * _bob_amplitude * 0.5, sin(_bob_time * TAU) * _bob_amplitude)
			cam.offset = _base_offset + fx_offset
			cam.rotation = _base_rotation + fx_roll
		elif _cam_driving:
			# Every effect settled: hand the camera back exactly as we found it.
			cam.offset = _base_offset
			cam.rotation = _base_rotation
			_cam_driving = false
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
	if _blink_active and host is CanvasItem:
		_blink_time += delta * _blink_rate
		var blink_item: CanvasItem = host as CanvasItem
		var blink_color: Color = blink_item.modulate
		blink_color.a = _blink_base_alpha if fmod(_blink_time, 1.0) < 0.5 else _blink_min_alpha
		blink_item.modulate = blink_color
	if _trail_active:
		_trail_timer -= delta
		if _trail_timer <= 0.0:
			_trail_timer = maxf(_trail_interval, 0.01)
			_stamp_ghost()

## @ace_action
## @ace_featured
## @ace_name("Shake")
## @ace_category("Juice")
## @ace_description("Adds screenshake to the active camera (0 = none, 1 = max). Stacks and decays automatically - fire it on every hit.")
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
## @ace_codegen_template("$JuiceBehavior.shake({strength})")
func shake(strength: float) -> void:
	trauma = clampf(trauma + strength, 0.0, 1.0)

## @ace_action
## @ace_name("Stop Shake")
## @ace_category("Juice")
## @ace_description("Cancels any shake immediately (the camera returns to rest unless another effect - recoil, bob, jitter, tilt - is still holding it).")
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
## @ace_codegen_template("$JuiceBehavior.stop_shake()")
func stop_shake() -> void:
	trauma = 0.0
	shake_time = 0.0
	_shaking = false
	var cam: Camera2D = _camera()
	if cam != null and _cam_driving and not (_bob_active or _jitter_active or _recoil_vec != Vector2.ZERO or absf(_tilt_roll) > 0.0001):
		cam.offset = _base_offset
		cam.rotation = _base_rotation
		_cam_driving = false

## @ace_action
## @ace_name("Use Camera")
## @ace_category("Juice")
## @ace_description("Pin the effects to a specific Camera2D (by path). Leave it unused to auto-target whichever camera is active.")
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
## @ace_codegen_template("$JuiceBehavior.use_camera({camera_path})")
func use_camera(camera_path: NodePath) -> void:
	_camera_override = get_node_or_null(camera_path) as Camera2D

## @ace_action
## @ace_name("Recoil")
## @ace_category("Juice")
## @ace_description("Kicks the camera a distance (pixels) in a direction (degrees: -90 = up, 0 = right) and springs it back at the Recoil Recovery rate. Fire on every shot - kicks stack, so rapid fire climbs. Composes with Shake/Bob/Jitter.")
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
## @ace_codegen_template("$JuiceBehavior.recoil({angle_degrees}, {strength})")
func recoil(angle_degrees: float, strength: float) -> void:
	_recoil_vec += Vector2.from_angle(deg_to_rad(angle_degrees)) * strength

## @ace_action
## @ace_name("Start Head Bob")
## @ace_category("Juice")
## @ace_description("Starts a walking head-bob on the camera: a figure-8 sway (side at half rate, one vertical dip per step). Amplitude is pixels, frequency is steps per second. Call while your character moves; Stop Head Bob when they halt.")
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
## @ace_codegen_template("$JuiceBehavior.start_head_bob({amplitude}, {frequency})")
func start_head_bob(amplitude: float, frequency: float) -> void:
	_bob_amplitude = amplitude
	_bob_frequency = maxf(frequency, 0.01)
	_bob_active = true

## @ace_action
## @ace_name("Stop Head Bob")
## @ace_category("Juice")
## @ace_description("Stops the head bob (the camera returns to rest once every other effect settles too).")
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
## @ace_codegen_template("$JuiceBehavior.stop_head_bob()")
func stop_head_bob() -> void:
	_bob_active = false

## @ace_action
## @ace_name("Start Jitter")
## @ace_category("Juice")
## @ace_description("Starts a continuous nervous wobble on the camera (pixels) that runs until Stop Jitter - unlike Shake it never decays. Great for engines idling, drunk vision, earthquakes building, low-health unease.")
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
## @ace_codegen_template("$JuiceBehavior.start_jitter({amount})")
func start_jitter(amount: float) -> void:
	_jitter_amount = amount
	_jitter_active = true

## @ace_action
## @ace_name("Stop Jitter")
## @ace_category("Juice")
## @ace_description("Stops the jitter wobble.")
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
## @ace_codegen_template("$JuiceBehavior.stop_jitter()")
func stop_jitter() -> void:
	_jitter_active = false

## @ace_action
## @ace_name("Tilt To")
## @ace_category("Juice")
## @ace_description("Eases the camera roll to an angle (degrees) and HOLDS it - lean into a drift, a hill, or a dramatic dutch angle. Tilt back to 0 to level out. Emits On Tilt Finished.")
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
## @ace_codegen_template("$JuiceBehavior.tilt_to({degrees}, {duration})")
func tilt_to(degrees: float, duration: float) -> void:
	if _tilt_tween != null:
		_tilt_tween.kill()
	var tw: Tween = create_tween()
	tw.tween_property(self, "_tilt_roll", degrees, maxf(duration, 0.001)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.finished.connect(func() -> void: tilt_finished.emit())
	_tilt_tween = tw

## @ace_action
## @ace_name("Zoom By Percent")
## @ace_category("Juice")
## @ace_description("Smoothly zooms the camera (100 = no change, 150 = zoom in 1.5x, 50 = zoom out). Clamped to the min/max zoom knobs.")
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
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
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
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
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
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
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
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
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
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
## @ace_param_options(duration_clock realtime, gametime)
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
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
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
## @ace_codegen_template("$JuiceBehavior.clear_slowmo()")
func clear_slowmo() -> void:
	if _slowmo_tween != null:
		_slowmo_tween.kill()
		_slowmo_tween = null
	Engine.time_scale = 1.0

## @ace_action
## @ace_featured
## @ace_name("Hitstop")
## @ace_category("Juice")
## @ace_description("The punchy hit-pause you feel on a connecting blow: freezes Engine.time_scale (0 = full stop) for a few frames, then snaps back to what it was. Uses a realtime timer so it un-freezes even at a full stop, ignores repeat hits already mid-freeze, pauses any active Slowmo for the duration, and emits On Hitstop Finished. Fire it the instant a hit lands.")
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
## @ace_codegen_template("$JuiceBehavior.hitstop({freeze_duration}, {freeze_scale})")
func hitstop(freeze_duration: float, freeze_scale: float) -> void:
	if _hitstop_active:
		return
	_hitstop_active = true
	_hitstop_prev_scale = Engine.time_scale
	if _slowmo_tween != null and is_instance_valid(_slowmo_tween) and _slowmo_tween.is_running():
		_slowmo_tween.pause()
	Engine.time_scale = maxf(freeze_scale, 0.0)
	await get_tree().create_timer(maxf(freeze_duration, 0.0), true, false, true).timeout
	if not _hitstop_active:
		return
	_hitstop_active = false
	Engine.time_scale = _hitstop_prev_scale
	if _slowmo_tween != null and is_instance_valid(_slowmo_tween):
		_slowmo_tween.play()
	hitstop_finished.emit()

## @ace_action
## @ace_featured
## @ace_name("Flash")
## @ace_category("Juice")
## @ace_description("Pops the host to a solid color, then fades back to how it looked (tints included) - THE damage-hit read. Fire with Hitstop + Shake for a complete hit-confirm. Emits On Flash Finished.")
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
## @ace_codegen_template("$JuiceBehavior.flash({color}, {seconds})")
func flash(color: Color, seconds: float) -> void:
	var flash_item: CanvasItem = host as CanvasItem
	if flash_item == null:
		return
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	else:
		_flash_restore = flash_item.modulate
	flash_item.modulate = Color(color.r, color.g, color.b, _flash_restore.a)
	var tw: Tween = create_tween()
	tw.tween_property(flash_item, "modulate", _flash_restore, maxf(seconds, 0.01)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.finished.connect(func() -> void: flash_finished.emit())
	_flash_tween = tw

## @ace_action
## @ace_name("Start Blinking")
## @ace_category("Juice")
## @ace_description("Strobes the host's opacity (full / faint) - the invulnerability-frames look, a low-health warning, an interactable highlight. Runs until Stop Blinking.")
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
## @ace_codegen_template("$JuiceBehavior.start_blinking({times_per_second}, {min_alpha})")
func start_blinking(times_per_second: float, min_alpha: float) -> void:
	if host is CanvasItem and not _blink_active:
		_blink_base_alpha = (host as CanvasItem).modulate.a
	_blink_rate = maxf(times_per_second, 0.1)
	_blink_min_alpha = clampf(min_alpha, 0.0, 1.0)
	_blink_time = 0.0
	_blink_active = true

## @ace_action
## @ace_name("Stop Blinking")
## @ace_category("Juice")
## @ace_description("Stops the blink and restores the host's opacity.")
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
## @ace_codegen_template("$JuiceBehavior.stop_blinking()")
func stop_blinking() -> void:
	_blink_active = false
	if host is CanvasItem:
		var restored: Color = (host as CanvasItem).modulate
		restored.a = _blink_base_alpha
		(host as CanvasItem).modulate = restored

## @ace_action
## @ace_name("Punch Scale")
## @ace_category("Juice")
## @ace_description("Kicks the host's scale up (or down, negative) and springs it back elastically - button pops, pickups, flinches, beat pulses. Composes with Flash + Hitstop for melee hits. Emits On Punch Finished.")
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
## @ace_codegen_template("$JuiceBehavior.punch_scale({strength}, {duration})")
func punch_scale(strength: float, duration: float) -> void:
	if host == null:
		return
	_apply_host_scale(_base_scale * (1.0 + clampf(strength, -0.9, 5.0)))
	var tw: Tween = create_tween()
	tw.tween_property(host, "scale", _base_scale, maxf(duration, 0.001)).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.finished.connect(func() -> void: punch_finished.emit())

## @ace_action
## @ace_name("Punch Rotation")
## @ace_category("Juice")
## @ace_description("Kicks the host's rotation by an angle (degrees) and springs it back elastically - wobbling signs, chest-opening jolts, portrait reactions. Emits On Punch Finished.")
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
## @ace_codegen_template("$JuiceBehavior.punch_rotation({degrees}, {duration})")
func punch_rotation(degrees: float, duration: float) -> void:
	if not (host is CanvasItem):
		return
	if host is Control:
		(host as Control).pivot_offset = (host as Control).size / 2.0
	if _punch_rot_tween != null and _punch_rot_tween.is_valid():
		_punch_rot_tween.kill()
	else:
		_punch_rot_rest = (host as CanvasItem).rotation
	(host as CanvasItem).rotation = _punch_rot_rest + deg_to_rad(degrees)
	var tw: Tween = create_tween()
	tw.tween_property(host, "rotation", _punch_rot_rest, maxf(duration, 0.001)).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.finished.connect(func() -> void: punch_finished.emit())
	_punch_rot_tween = tw

## @ace_action
## @ace_name("Punch Position")
## @ace_category("Juice")
## @ace_description("Kicks the host's position by an offset (pixels) and springs it back elastically - knockback reads, UI nudges, impact shoves away from an attacker. Emits On Punch Finished.")
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
## @ace_codegen_template("$JuiceBehavior.punch_position({offset}, {duration})")
func punch_position(offset: Vector2, duration: float) -> void:
	if not (host is Node2D or host is Control):
		return
	if _punch_pos_tween != null and _punch_pos_tween.is_valid():
		_punch_pos_tween.kill()
	else:
		_punch_pos_rest = host.position
	host.position = _punch_pos_rest + offset
	var tw: Tween = create_tween()
	tw.tween_property(host, "position", _punch_pos_rest, maxf(duration, 0.001)).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.finished.connect(func() -> void: punch_finished.emit())
	_punch_pos_tween = tw

## @ace_action
## @ace_name("Kick Camera Away From Point")
## @ace_category("Juice")
## @ace_description("Kicks the camera AWAY from a world position (an explosion, a hit source) and springs back - Recoil's directional sibling when you know the cause's location, so the kick always reads as pushback. Composes with Shake.")
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
## @ace_codegen_template("$JuiceBehavior.kick_away_from({world_position}, {strength})")
func kick_away_from(world_position: Vector2, strength: float) -> void:
	var cam: Camera2D = _camera()
	if cam == null:
		return
	var away: Vector2 = cam.get_screen_center_position() - world_position
	away = away.normalized() if away.length() > 0.001 else Vector2.UP
	_recoil_vec += away * strength

## @ace_action
## @ace_name("Start Ghost Trail")
## @ace_category("Juice")
## @ace_description("Starts stamping fading afterimages of the host's sprite behind it - dashes, teleports, speed power-ups, bullet-time evades. Works on a Sprite2D/AnimatedSprite2D host or the host's first Sprite2D child. Runs until Stop Ghost Trail.")
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
## @ace_codegen_template("$JuiceBehavior.start_ghost_trail({stamps_per_second}, {fade_seconds}, {tint})")
func start_ghost_trail(stamps_per_second: float, fade_seconds: float, tint: Color) -> void:
	_trail_interval = 1.0 / maxf(stamps_per_second, 0.1)
	_trail_fade = maxf(fade_seconds, 0.05)
	_trail_tint = tint
	_trail_timer = 0.0
	_trail_active = true

## @ace_action
## @ace_name("Stop Ghost Trail")
## @ace_category("Juice")
## @ace_description("Stops stamping afterimages (the ones already out finish fading on their own).")
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
## @ace_codegen_template("$JuiceBehavior.stop_ghost_trail()")
func stop_ghost_trail() -> void:
	_trail_active = false

## @ace_action
## @ace_name("Pulse Vignette")
## @ace_category("Juice")
## @ace_description("Darkens the screen edges to a color at a strength (0..1), then fades back out - taking damage, a near miss, holding your breath. Composes with Slowmo + Fade Screen Tint for last-stand moments.")
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
## @ace_codegen_template("$JuiceBehavior.pulse_vignette({strength}, {color}, {seconds})")
func pulse_vignette(strength: float, color: Color, seconds: float) -> void:
	_ensure_fx_overlay()
	if _fx_material == null:
		return
	if _vignette_tween != null and _vignette_tween.is_valid():
		_vignette_tween.kill()
	_fx_material.set_shader_parameter("vignette_color", Color(color.r, color.g, color.b, 1.0))
	_fx_material.set_shader_parameter("vignette_strength", clampf(strength, 0.0, 1.0))
	_fx_rect.visible = true
	var tw: Tween = create_tween()
	tw.tween_property(_fx_material, "shader_parameter/vignette_strength", 0.0, maxf(seconds, 0.01)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.finished.connect(_fx_update_visibility)
	_vignette_tween = tw

## @ace_action
## @ace_name("Chromatic Kick")
## @ace_category("Juice")
## @ace_description("Splits the screen's color channels for an instant and settles back - the AAA impact frame. Fire with Shake + Hitstop on explosions and heavy hits.")
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
## @ace_codegen_template("$JuiceBehavior.chromatic_kick({strength}, {seconds})")
func chromatic_kick(strength: float, seconds: float) -> void:
	_ensure_fx_overlay()
	if _fx_material == null:
		return
	if _chroma_tween != null and _chroma_tween.is_valid():
		_chroma_tween.kill()
	_fx_material.set_shader_parameter("chroma_strength", clampf(strength, 0.0, 1.0))
	_fx_rect.visible = true
	var tw: Tween = create_tween()
	tw.tween_property(_fx_material, "shader_parameter/chroma_strength", 0.0, maxf(seconds, 0.01)).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.finished.connect(_fx_update_visibility)
	_chroma_tween = tw

## @ace_action
## @ace_name("Set Speed Lines")
## @ace_category("Juice")
## @ace_description("Radial anime-style speed streaks at an intensity (0..1) that HOLD until you set 0 - sprints, dashes, adrenaline modes. Pair with Zoom By Percent or FOV punches for full sprint feel.")
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
## @ace_codegen_template("$JuiceBehavior.set_speed_lines({intensity})")
func set_speed_lines(intensity: float) -> void:
	_ensure_fx_overlay()
	if _fx_material == null:
		return
	_fx_material.set_shader_parameter("speed_lines", clampf(intensity, 0.0, 1.0))
	_fx_update_visibility()

## @ace_action
## @ace_name("Play Sound Varied")
## @ace_category("Juice")
## @ace_description("Plays a sound with a random pitch and volume wobble around the base - the #1 trick against repetitive footsteps, hits, coins, and clicks. Fire-and-forget (the player frees itself).")
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
## @ace_codegen_template("$JuiceBehavior.play_sound_varied({path}, {pitch_jitter}, {volume_jitter_db})")
func play_sound_varied(path: String, pitch_jitter: float, volume_jitter_db: float) -> void:
	_spawn_one_shot(path, 1.0 + randf_range(-pitch_jitter, pitch_jitter), randf_range(-absf(volume_jitter_db), 0.0))

## @ace_action
## @ace_name("Play Sound With Intensity")
## @ace_category("Juice")
## @ace_description("Plays a sound scaled by an intensity (0..1): quiet + lower-pitched when light, full + brighter when heavy - drive it, Shake, and Punch Scale from ONE hit-power value so light and heavy hits differ by one number.")
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
## @ace_codegen_template("$JuiceBehavior.play_sound_intensity({path}, {intensity})")
func play_sound_intensity(path: String, intensity: float) -> void:
	var power: float = clampf(intensity, 0.0, 1.0)
	_spawn_one_shot(path, lerpf(0.85, 1.15, power) * (1.0 + randf_range(-0.03, 0.03)), lerpf(-14.0, 0.0, power))

## @ace_action
## @ace_name("Count To")
## @ace_category("Juice")
## @ace_description("Eases a named display value toward a target over a duration - scores and gold ROLL instead of snapping. Read it with the Ticker Value expression; emits On Ticker Finished (with the name) when it lands.")
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
## @ace_codegen_template("$JuiceBehavior.count_to({ticker_name}, {target}, {duration})")
func count_to(ticker_name: String, target: float, duration: float) -> void:
	var from: float = float(_tickers.get(ticker_name, 0.0))
	_ticker_targets[ticker_name] = target
	var old_tween: Tween = _ticker_tweens.get(ticker_name, null)
	if old_tween != null and is_instance_valid(old_tween):
		old_tween.kill()
	var tw: Tween = create_tween()
	tw.tween_method(func(v: float) -> void: _tickers[ticker_name] = v, from, target, maxf(duration, 0.001)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.finished.connect(_finish_ticker.bind(ticker_name))
	_ticker_tweens[ticker_name] = tw

## @ace_action
## @ace_name("Set Ticker")
## @ace_category("Juice")
## @ace_description("Sets a named display value INSTANTLY (cancelling any roll) - initialise a score at 0, or snap on a reset.")
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
## @ace_codegen_template("$JuiceBehavior.set_ticker({ticker_name}, {value})")
func set_ticker(ticker_name: String, value: float) -> void:
	var old_tween: Tween = _ticker_tweens.get(ticker_name, null)
	if old_tween != null and is_instance_valid(old_tween):
		old_tween.kill()
	_tickers[ticker_name] = value
	_ticker_targets[ticker_name] = value

## Drives an ANCHORED zoom: keeps _zoom_anchor pinned under the same screen point as the zoom
## interpolates (mouse-wheel-to-cursor feel). Called by Zoom Toward Point's tween each frame.
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
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
## @ace_codegen_template("$JuiceBehavior.is_shaking()")
func is_shaking() -> bool:
	return trauma > 0.0

## @ace_expression
## @ace_name("Trauma")
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
## @ace_codegen_template("$JuiceBehavior.current_trauma()")
func current_trauma() -> float:
	return trauma

## @ace_condition
## @ace_name("Is Hitstopped")
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
## @ace_codegen_template("$JuiceBehavior.is_hitstopped()")
func is_hitstopped() -> bool:
	return _hitstop_active

func _set_time_scale(s: float) -> void:
	Engine.time_scale = s

## Maps a slowmo easing-curve name (Inspector enum) to a Tween.TransitionType.
func _slowmo_trans(easing_name: String) -> int:
	match easing_name:
		"linear": return Tween.TRANS_LINEAR
		"quad": return Tween.TRANS_QUAD
		"cubic": return Tween.TRANS_CUBIC
		"expo": return Tween.TRANS_EXPO
		"circ": return Tween.TRANS_CIRC
		"back": return Tween.TRANS_BACK
		_: return Tween.TRANS_SINE

## Maps a slowmo easing-direction name (Inspector enum) to a Tween.EaseType.
func _slowmo_ease(easing_name: String) -> int:
	match easing_name:
		"in": return Tween.EASE_IN
		"in_out": return Tween.EASE_IN_OUT
		"out_in": return Tween.EASE_OUT_IN
		_: return Tween.EASE_OUT

## Applies a scale to the host whether it's a Node2D or a Control (centring a Control's pivot so
## it scales from the middle). Used by Spring Squash's per-frame integrator.
func _apply_host_scale(s: Vector2) -> void:
	if host is Node2D:
		(host as Node2D).scale = s
	elif host is Control:
		var c: Control = host as Control
		c.pivot_offset = c.size / 2.0
		c.scale = s

## @ace_hidden
func _ensure_tint_overlay() -> void:
	if _tint_overlay != null or not is_inside_tree():
		return
	_tint_overlay = CanvasLayer.new()
	_tint_overlay.layer = 90
	add_child(_tint_overlay)
	_tint_rect = ColorRect.new()
	_tint_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	_tint_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tint_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tint_overlay.add_child(_tint_rect)

## @ace_action
## @ace_name("Set Host Tint")
## @ace_description("Tints the HOST object: blends its color toward the tint by Strength (0 = its own colors untouched, 1 = fully the tint color) - the classic object tint, with the strength as your opacity dial. Children inherit (modulate).")
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
## @ace_codegen_template("$JuiceBehavior.set_host_tint({color}, {strength})")
func set_host_tint(color: Color, strength: float) -> void:
	if host is CanvasItem:
		(host as CanvasItem).modulate = Color.WHITE.lerp(Color(color.r, color.g, color.b, 1.0), clampf(strength, 0.0, 1.0))

## @ace_action
## @ace_name("Clear Host Tint")
## @ace_description("Removes the host tint (back to its own colors).")
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
## @ace_codegen_template("$JuiceBehavior.clear_host_tint()")
func clear_host_tint() -> void:
	if host is CanvasItem:
		(host as CanvasItem).modulate = Color.WHITE

## @ace_action
## @ace_name("Set Screen Tint")
## @ace_description("Washes the WHOLE SCREEN with a color at Strength opacity (0..1) - damage red, poison green, night blue, flashback sepia. Call again to retune; strength 0 clears.")
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
## @ace_codegen_template("$JuiceBehavior.set_screen_tint({color}, {strength})")
func set_screen_tint(color: Color, strength: float) -> void:
	_ensure_tint_overlay()
	if _tint_rect != null:
		_tint_rect.color = Color(color.r, color.g, color.b, clampf(strength, 0.0, 1.0))
		_tint_rect.visible = _tint_rect.color.a > 0.001

## @ace_action
## @ace_name("Fade Screen Tint")
## @ace_description("Fades the screen tint's strength to zero over the given seconds - the damage-flash pattern: Set Screen Tint red 0.4, then Fade Screen Tint 0.3.")
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
## @ace_codegen_template("$JuiceBehavior.fade_screen_tint({seconds})")
func fade_screen_tint(seconds: float) -> void:
	if _tint_rect == null or not _tint_rect.visible:
		return
	create_tween().tween_property(_tint_rect, "color:a", 0.0, maxf(seconds, 0.01))

## @ace_action
## @ace_name("Clear Screen Tint")
## @ace_description("Removes the screen tint instantly.")
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
## @ace_codegen_template("$JuiceBehavior.clear_screen_tint()")
func clear_screen_tint() -> void:
	if _tint_rect != null:
		_tint_rect.visible = false

## @ace_expression
## @ace_name("Ticker Value")
## @ace_description("What a ticker currently SHOWS - the eased value Count To is rolling toward its target. Print or draw this instead of the real variable and scores roll instead of snapping.")
## @ace_icon("res://eventsheet_addons/juice/icon.svg")
## @ace_codegen_template("$JuiceBehavior.ticker_value({ticker_name})")
func ticker_value(ticker_name: String) -> float:
	return float(_tickers.get(ticker_name, 0.0))

## @ace_hidden
func _finish_ticker(ticker_name: String) -> void:
	_tickers[ticker_name] = _ticker_targets.get(ticker_name, _tickers.get(ticker_name, 0.0))
	ticker_finished.emit(ticker_name)

## @ace_hidden
func _stamp_ghost() -> void:
	var source: Node2D = host as Node2D
	if source == null or not is_inside_tree() or source.get_parent() == null:
		return
	var ghost: Sprite2D = Sprite2D.new()
	var pose_source: Node2D = source
	if source is Sprite2D:
		var sprite: Sprite2D = source as Sprite2D
		ghost.texture = sprite.texture
		ghost.hframes = sprite.hframes
		ghost.vframes = sprite.vframes
		ghost.frame = sprite.frame
		ghost.region_enabled = sprite.region_enabled
		ghost.region_rect = sprite.region_rect
		ghost.flip_h = sprite.flip_h
		ghost.flip_v = sprite.flip_v
		ghost.centered = sprite.centered
		ghost.offset = sprite.offset
	elif source is AnimatedSprite2D:
		var animated: AnimatedSprite2D = source as AnimatedSprite2D
		if animated.sprite_frames == null:
			return
		ghost.texture = animated.sprite_frames.get_frame_texture(animated.animation, animated.frame)
		ghost.flip_h = animated.flip_h
		ghost.flip_v = animated.flip_v
		ghost.centered = animated.centered
		ghost.offset = animated.offset
	else:
		var body_sprite: Sprite2D = null
		for child in source.get_children():
			if child is Sprite2D:
				body_sprite = child as Sprite2D
				break
		if body_sprite == null or body_sprite.texture == null:
			return
		ghost.texture = body_sprite.texture
		ghost.hframes = body_sprite.hframes
		ghost.vframes = body_sprite.vframes
		ghost.frame = body_sprite.frame
		ghost.flip_h = body_sprite.flip_h
		ghost.flip_v = body_sprite.flip_v
		ghost.centered = body_sprite.centered
		ghost.offset = body_sprite.offset
		pose_source = body_sprite
	if ghost.texture == null:
		return
	ghost.modulate = _trail_tint
	ghost.z_index = pose_source.z_index - 1
	source.get_parent().add_child(ghost)
	ghost.global_transform = pose_source.global_transform
	var tw: Tween = ghost.create_tween()
	tw.tween_property(ghost, "modulate:a", 0.0, maxf(_trail_fade, 0.05))
	tw.finished.connect(ghost.queue_free)

## @ace_hidden
func _spawn_one_shot(path: String, pitch: float, volume_db: float) -> void:
	var stream: AudioStream = load(path) as AudioStream
	if stream == null:
		return
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.stream = stream
	player.pitch_scale = maxf(pitch, 0.05)
	player.volume_db = volume_db
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

## @ace_hidden
func _ensure_fx_overlay() -> void:
	if _fx_layer != null or not is_inside_tree():
		return
	_fx_layer = CanvasLayer.new()
	_fx_layer.layer = 91
	add_child(_fx_layer)
	_fx_rect = ColorRect.new()
	_fx_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var fx_shader: Shader = Shader.new()
	fx_shader.code = _FX_SHADER
	_fx_material = ShaderMaterial.new()
	_fx_material.shader = fx_shader
	# Seed every uniform so get_shader_parameter never returns null: reading an un-set uniform
	# returns null (NOT the shader default), and _fx_update_visibility's float() would fault on it
	# whenever only one of the three effects had been used.
	_fx_material.set_shader_parameter("vignette_strength", 0.0)
	_fx_material.set_shader_parameter("chroma_strength", 0.0)
	_fx_material.set_shader_parameter("speed_lines", 0.0)
	_fx_rect.material = _fx_material
	_fx_rect.visible = false
	_fx_layer.add_child(_fx_rect)

## @ace_hidden
func _fx_update_visibility() -> void:
	if _fx_rect == null or _fx_material == null:
		return
	_fx_rect.visible = float(_fx_material.get_shader_parameter("vignette_strength")) > 0.001 \
			or float(_fx_material.get_shader_parameter("chroma_strength")) > 0.001 \
			or float(_fx_material.get_shader_parameter("speed_lines")) > 0.001

# Game feel, batteries included: screenshake, recoil, head bob, jitter, camera tilt, smooth zoom, and squash & stretch. The camera is found automatically - attach this anywhere and call Shake / Recoil / Zoom; all camera effects compose around one rest pose. Squash & Stretch animates the node it's attached to. (3D camera? Use the Juice 3D pack - same verbs on the active Camera3D.)
