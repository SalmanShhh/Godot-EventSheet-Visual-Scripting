## @ace_tags(camera, juice, 3d)
## @ace_category("Juice 3D")
## @ace_expose_all(node)
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/juice_3d/icon.svg")
class_name Juice3DBehavior
extends Node
## 3D camera game feel on the active Camera3D: trauma-based shake, weapon recoil, directional kicks from a world point, head bob, jitter, a held lean, FOV punch/zoom, host blink and punches, screen FX (vignette, chromatic kick, speed lines), varied one-shot audio, and eased score tickers. Every camera effect is an additive offset that is removed and re-applied around whoever owns the camera, so mouse look and animations keep the real pose and your aim is never touched.

## The node this behavior acts on (its parent). Required host: Node3D.
var host: Node3D = null

func _enter_tree() -> void:
	host = get_parent() as Node3D
	if host == null:
		push_warning("Juice3DBehavior behavior requires a Node3D parent.")

## @ace_trigger
## @ace_name("On Punch Finished")
signal punch_finished
## @ace_trigger
## @ace_name("On Ticker Finished")
signal ticker_finished(ticker_name: String)
## @ace_trigger
## @ace_name("On Shake Stopped")
signal shake_stopped
## @ace_trigger
## @ace_name("On Lean Finished")
signal lean_finished
## @ace_trigger
## @ace_name("On Zoom Finished")
signal zoom_finished

# --- Designer knobs (tune the FEEL in the Inspector) ---
## Peak shake rotation, in degrees, at full trauma (pitch/yaw; roll uses a third of it).
@export_range(0.0, 30.0, 0.5) var max_shake_degrees: float = 4.0
## Peak positional shake, in metres, at full trauma (0 = rotation-only shake).
@export_range(0.0, 1.0, 0.01) var max_shake_offset: float = 0.05
## Trauma lost per second - higher means shorter, snappier shakes.
@export_range(0.1, 10.0, 0.1) var shake_decay: float = 1.4
## How fast the shake/jitter noise scrolls (the wobble rate).
@export_range(1.0, 60.0, 1.0) var shake_frequency: float = 25.0
## How fast a Recoil kick re-centres, in degrees per second.
@export_range(1.0, 360.0, 1.0) var recoil_recovery: float = 30.0
## How fast an FOV Punch returns to normal, in degrees per second.
@export_range(5.0, 500.0, 5.0) var fov_recovery: float = 60.0
## How fast a positional Kick (Kick Camera Away From Point) re-centres, in metres per second.
@export_range(0.05, 20.0, 0.05) var kick_recovery: float = 0.6

# --- Internal state ---
var trauma: float = 0.0
var shake_time: float = 0.0
var _shaking: bool = false
var _noise: FastNoiseLite = null
var _camera_override: Camera3D = null
# The camera the offsets were last applied to - offsets are pulled off it before anything
# else, so a camera switch mid-effect can never corrupt the new camera's pose.
var _last_camera: Camera3D = null
# What we added to the camera last frame (subtracted again at the top of every tick).
var _applied_position: Vector3 = Vector3.ZERO
var _applied_rotation: Vector3 = Vector3.ZERO
var _applied_fov: float = 0.0
var _recoil_pitch: float = 0.0
var _recoil_yaw: float = 0.0
var _bob_active: bool = false
var _bob_time: float = 0.0
var _bob_amplitude: float = 0.06
var _bob_frequency: float = 2.2
var _jitter_active: bool = false
var _jitter_time: float = 0.0
var _jitter_offset: float = 0.02
var _jitter_roll: float = 0.5
var _lean_roll: float = 0.0
var _lean_tween: Tween = null
var _fov_kick: float = 0.0
# Positional camera kick (Kick Camera Away From Point) - recovers like recoil.
var _kick_vec: Vector3 = Vector3.ZERO
# Blink state (visibility strobe - the 3D take on invulnerability frames).
var _blink_active: bool = false
var _blink_time: float = 0.0
var _blink_rate: float = 8.0
# Punch state (kick out, spring back; rest captured per gesture so repeats never drift).
var _base_scale3: Vector3 = Vector3.ONE
var _punch_pos_tween: Tween = null
var _punch_pos_rest: Vector3 = Vector3.ZERO
# Eased tickers (Count To): name -> displayed value / target / driving tween.
var _tickers: Dictionary = {}
var _ticker_targets: Dictionary = {}
var _ticker_tweens: Dictionary = {}
## The camera the effects drive: an explicit override (Use Camera), else the active Camera3D.
func _camera() -> Camera3D:
	if _camera_override != null and is_instance_valid(_camera_override):
		return _camera_override
	var vp: Viewport = get_viewport()
	if vp == null:
		return null
	return vp.get_camera_3d()

# The tint overlay: a top CanvasLayer ColorRect built on first use - the screen
# wash for damage reds, poison greens, night blues. Strength IS the opacity.
var _tint_overlay: CanvasLayer = null
var _tint_rect: ColorRect = null

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
	if host is Node3D:
		_base_scale3 = (host as Node3D).scale

func _on_tree_exiting() -> void:
	_unapply()

func _process(delta: float) -> void:
	# Effect STATE advances camera-or-not (headless-safe); only the apply needs a camera.
	if trauma > 0.0:
		trauma = maxf(trauma - shake_decay * delta, 0.0)
		shake_time += delta
		_shaking = true
	if trauma <= 0.0 and _shaking:
		_shaking = false
		shake_stopped.emit()
	_recoil_pitch = move_toward(_recoil_pitch, 0.0, recoil_recovery * delta)
	_recoil_yaw = move_toward(_recoil_yaw, 0.0, recoil_recovery * delta)
	_fov_kick = move_toward(_fov_kick, 0.0, fov_recovery * delta)
	_kick_vec = _kick_vec.move_toward(Vector3.ZERO, kick_recovery * delta)
	if _blink_active and host is Node3D:
		_blink_time += delta * _blink_rate
		(host as Node3D).visible = fmod(_blink_time, 1.0) < 0.5
	if _bob_active:
		_bob_time += delta * _bob_frequency
	if _jitter_active:
		_jitter_time += delta * shake_frequency
	# Additive apply: pull last frame's offsets off first, so the pose the controller wrote
	# this frame is the base - the effects ride on TOP of mouse look, never against it.
	_unapply()
	var cam: Camera3D = _camera()
	if cam == null:
		return
	_last_camera = cam
	var fx_position: Vector3 = _kick_vec
	var fx_rotation: Vector3 = Vector3(deg_to_rad(_recoil_pitch), deg_to_rad(_recoil_yaw), deg_to_rad(_lean_roll))
	if trauma > 0.0:
		# Square the trauma so the shake ramps in perceptually (Squirrel Eiserloh's model).
		var amount: float = trauma * trauma
		var t: float = shake_time * shake_frequency
		fx_rotation += Vector3(deg_to_rad(max_shake_degrees) * amount * _noise.get_noise_2d(t, 0.0), deg_to_rad(max_shake_degrees) * amount * _noise.get_noise_2d(0.0, t), deg_to_rad(max_shake_degrees) * amount * _noise.get_noise_2d(t, t) / 3.0)
		fx_position += Vector3(max_shake_offset * amount * _noise.get_noise_2d(t, 50.0), max_shake_offset * amount * _noise.get_noise_2d(50.0, t), 0.0)
	if _jitter_active:
		fx_position += Vector3(_jitter_offset * _noise.get_noise_2d(_jitter_time, 100.0), _jitter_offset * _noise.get_noise_2d(100.0, _jitter_time), 0.0)
		fx_rotation.z += deg_to_rad(_jitter_roll) * _noise.get_noise_2d(_jitter_time, 200.0)
	if _bob_active:
		# A walking figure-8: side sway at half rate, one vertical dip per step.
		fx_position += Vector3(sin(_bob_time * TAU * 0.5) * _bob_amplitude * 0.5, -absf(sin(_bob_time * TAU * 0.5)) * _bob_amplitude, 0.0)
	cam.position += fx_position
	cam.rotation += fx_rotation
	cam.fov = clampf(cam.fov + _fov_kick, 1.0, 179.0)
	_applied_position = fx_position
	_applied_rotation = fx_rotation
	_applied_fov = _fov_kick

## @ace_action
## @ace_featured
## @ace_name("Shake")
## @ace_category("Juice 3D")
## @ace_description("Adds screenshake to the active 3D camera (0 = none, 1 = max). Stacks and decays automatically - fire it on every hit or explosion.")
## @ace_icon("res://eventsheet_addons/juice_3d/icon.svg")
## @ace_codegen_template("$Juice3DBehavior.shake({strength})")
func shake(strength: float) -> void:
	trauma = clampf(trauma + strength, 0.0, 1.0)

## @ace_action
## @ace_name("Stop Shake")
## @ace_category("Juice 3D")
## @ace_description("Cancels any shake immediately (other effects keep running).")
## @ace_icon("res://eventsheet_addons/juice_3d/icon.svg")
## @ace_codegen_template("$Juice3DBehavior.stop_shake()")
func stop_shake() -> void:
	trauma = 0.0
	shake_time = 0.0
	_shaking = false

## @ace_action
## @ace_name("Recoil")
## @ace_category("Juice 3D")
## @ace_description("Weapon recoil: kicks the view UP by a pitch (degrees) plus a random side spread, then re-centres at the Recoil Recovery rate. Fire on every shot - kicks stack, so sustained fire climbs. Cosmetic (rides on top of mouse look; aim is untouched).")
## @ace_icon("res://eventsheet_addons/juice_3d/icon.svg")
## @ace_codegen_template("$Juice3DBehavior.recoil({vertical_kick}, {horizontal_spread})")
func recoil(vertical_kick: float, horizontal_spread: float) -> void:
	_recoil_pitch += vertical_kick
	_recoil_yaw += randf_range(-horizontal_spread, horizontal_spread)

## @ace_action
## @ace_name("Start Head Bob")
## @ace_category("Juice 3D")
## @ace_description("Starts a walking head-bob on the camera: a figure-8 (side sway at half rate, one downward dip per step). Amplitude is metres, frequency is steps per second. Call while your character moves; Stop Head Bob when they halt.")
## @ace_icon("res://eventsheet_addons/juice_3d/icon.svg")
## @ace_codegen_template("$Juice3DBehavior.start_head_bob({amplitude}, {frequency})")
func start_head_bob(amplitude: float, frequency: float) -> void:
	_bob_amplitude = amplitude
	_bob_frequency = maxf(frequency, 0.01)
	_bob_active = true

## @ace_action
## @ace_name("Stop Head Bob")
## @ace_category("Juice 3D")
## @ace_description("Stops the head bob.")
## @ace_icon("res://eventsheet_addons/juice_3d/icon.svg")
## @ace_codegen_template("$Juice3DBehavior.stop_head_bob()")
func stop_head_bob() -> void:
	_bob_active = false

## @ace_action
## @ace_name("Start Jitter")
## @ace_category("Juice 3D")
## @ace_description("Starts a continuous nervous wobble (position in metres + a touch of roll) that runs until Stop Jitter - unlike Shake it never decays. Engines idling, helicopters, low health, fear.")
## @ace_icon("res://eventsheet_addons/juice_3d/icon.svg")
## @ace_codegen_template("$Juice3DBehavior.start_jitter({position_amount}, {roll_degrees})")
func start_jitter(position_amount: float, roll_degrees: float) -> void:
	_jitter_offset = position_amount
	_jitter_roll = roll_degrees
	_jitter_active = true

## @ace_action
## @ace_name("Stop Jitter")
## @ace_category("Juice 3D")
## @ace_description("Stops the jitter wobble.")
## @ace_icon("res://eventsheet_addons/juice_3d/icon.svg")
## @ace_codegen_template("$Juice3DBehavior.stop_jitter()")
func stop_jitter() -> void:
	_jitter_active = false

## @ace_action
## @ace_name("Lean")
## @ace_category("Juice 3D")
## @ace_description("Eases the camera roll to an angle (degrees) and HOLDS it - lean into a wall ride, peek a corner, bank with a turn. Lean back to 0 to level out. Emits On Lean Finished.")
## @ace_icon("res://eventsheet_addons/juice_3d/icon.svg")
## @ace_codegen_template("$Juice3DBehavior.lean({degrees}, {duration})")
func lean(degrees: float, duration: float) -> void:
	if _lean_tween != null:
		_lean_tween.kill()
	var tw: Tween = create_tween()
	tw.tween_property(self, "_lean_roll", degrees, maxf(duration, 0.001)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.finished.connect(func() -> void: lean_finished.emit())
	_lean_tween = tw

## @ace_action
## @ace_featured
## @ace_name("FOV Punch")
## @ace_category("Juice 3D")
## @ace_description("Kicks the field of view wider (positive, a speed boost / dash) or tighter (negative, an impact) by an amount in degrees, then eases back at the FOV Recovery rate. Fire-and-forget.")
## @ace_icon("res://eventsheet_addons/juice_3d/icon.svg")
## @ace_codegen_template("$Juice3DBehavior.fov_punch({amount})")
func fov_punch(amount: float) -> void:
	_fov_kick += amount

## @ace_action
## @ace_name("Zoom FOV To")
## @ace_category("Juice 3D")
## @ace_description("Smoothly changes the camera's base field of view to a value in degrees and keeps it there (an aim-down-sights zoom is FOV 40, back to 75 to unzoom). Emits On Zoom Finished.")
## @ace_icon("res://eventsheet_addons/juice_3d/icon.svg")
## @ace_codegen_template("$Juice3DBehavior.zoom_fov_to({fov}, {duration})")
func zoom_fov_to(fov: float, duration: float) -> void:
	var cam: Camera3D = _camera()
	if cam == null:
		return
	var tw: Tween = create_tween()
	tw.tween_property(cam, "fov", clampf(fov, 1.0, 179.0) + _applied_fov, maxf(duration, 0.001)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.finished.connect(func() -> void: zoom_finished.emit())

## @ace_action
## @ace_name("Use Camera")
## @ace_category("Juice 3D")
## @ace_description("Pin the effects to a specific Camera3D (by path). Leave it unused to auto-target whichever camera is active.")
## @ace_icon("res://eventsheet_addons/juice_3d/icon.svg")
## @ace_codegen_template("$Juice3DBehavior.use_camera({camera_path})")
func use_camera(camera_path: NodePath) -> void:
	_unapply()
	_camera_override = get_node_or_null(camera_path) as Camera3D

## @ace_action
## @ace_name("Kick Camera Away From Point")
## @ace_category("Juice 3D")
## @ace_description("Shoves the camera AWAY from a world position (an explosion, a hit source) and re-centres at the Kick Recovery rate - Recoil's directional sibling when you know the cause's location. Cosmetic (additive; aim untouched). Composes with Shake.")
## @ace_icon("res://eventsheet_addons/juice_3d/icon.svg")
## @ace_codegen_template("$Juice3DBehavior.kick_away_from({world_position}, {strength})")
func kick_away_from(world_position: Vector3, strength: float) -> void:
	var cam: Camera3D = _camera()
	if cam == null:
		return
	var away: Vector3 = cam.global_position - world_position
	away = away.normalized() if away.length() > 0.001 else Vector3.UP
	_kick_vec += away * strength

## @ace_action
## @ace_name("Start Blinking")
## @ace_category("Juice 3D")
## @ace_description("Strobes the host's visibility - invulnerability frames, respawn grace, a targeted highlight. Runs until Stop Blinking.")
## @ace_icon("res://eventsheet_addons/juice_3d/icon.svg")
## @ace_codegen_template("$Juice3DBehavior.start_blinking({times_per_second})")
func start_blinking(times_per_second: float) -> void:
	_blink_rate = maxf(times_per_second, 0.1)
	_blink_time = 0.0
	_blink_active = true

## @ace_action
## @ace_name("Stop Blinking")
## @ace_category("Juice 3D")
## @ace_description("Stops the blink and makes the host visible again.")
## @ace_icon("res://eventsheet_addons/juice_3d/icon.svg")
## @ace_codegen_template("$Juice3DBehavior.stop_blinking()")
func stop_blinking() -> void:
	_blink_active = false
	if host is Node3D:
		(host as Node3D).visible = true

## @ace_action
## @ace_name("Punch Scale")
## @ace_category("Juice 3D")
## @ace_description("Kicks the host's scale up (or down, negative) and springs it back elastically - pickups, flinches, beat pulses. Emits On Punch Finished.")
## @ace_icon("res://eventsheet_addons/juice_3d/icon.svg")
## @ace_codegen_template("$Juice3DBehavior.punch_scale({strength}, {duration})")
func punch_scale(strength: float, duration: float) -> void:
	var scaled: Node3D = host as Node3D
	if scaled == null:
		return
	scaled.scale = _base_scale3 * (1.0 + clampf(strength, -0.9, 5.0))
	var tw: Tween = create_tween()
	tw.tween_property(scaled, "scale", _base_scale3, maxf(duration, 0.001)).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.finished.connect(func() -> void: punch_finished.emit())

## @ace_action
## @ace_name("Punch Position")
## @ace_category("Juice 3D")
## @ace_description("Kicks the host's position by an offset (metres) and springs it back elastically - knockback reads, impact shoves away from an attacker. Emits On Punch Finished.")
## @ace_icon("res://eventsheet_addons/juice_3d/icon.svg")
## @ace_codegen_template("$Juice3DBehavior.punch_position({offset}, {duration})")
func punch_position(offset: Vector3, duration: float) -> void:
	var shoved: Node3D = host as Node3D
	if shoved == null:
		return
	if _punch_pos_tween != null and _punch_pos_tween.is_valid():
		_punch_pos_tween.kill()
	else:
		_punch_pos_rest = shoved.position
	shoved.position = _punch_pos_rest + offset
	var tw: Tween = create_tween()
	tw.tween_property(shoved, "position", _punch_pos_rest, maxf(duration, 0.001)).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.finished.connect(func() -> void: punch_finished.emit())
	_punch_pos_tween = tw

## @ace_action
## @ace_name("Pulse Vignette")
## @ace_category("Juice 3D")
## @ace_description("Darkens the screen edges to a color at a strength (0..1), then fades back out - taking damage, a near miss, holding your breath. Composes with Fade Screen Tint for last-stand moments.")
## @ace_icon("res://eventsheet_addons/juice_3d/icon.svg")
## @ace_codegen_template("$Juice3DBehavior.pulse_vignette({strength}, {color}, {seconds})")
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
## @ace_featured
## @ace_name("Chromatic Kick")
## @ace_category("Juice 3D")
## @ace_description("Splits the screen's color channels for an instant and settles back - the AAA impact frame. Fire with Shake on explosions and heavy hits.")
## @ace_icon("res://eventsheet_addons/juice_3d/icon.svg")
## @ace_codegen_template("$Juice3DBehavior.chromatic_kick({strength}, {seconds})")
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
## @ace_category("Juice 3D")
## @ace_description("Radial anime-style speed streaks at an intensity (0..1) that HOLD until you set 0 - sprints, dashes, adrenaline modes. Pair with FOV Punch for full sprint feel.")
## @ace_icon("res://eventsheet_addons/juice_3d/icon.svg")
## @ace_codegen_template("$Juice3DBehavior.set_speed_lines({intensity})")
func set_speed_lines(intensity: float) -> void:
	_ensure_fx_overlay()
	if _fx_material == null:
		return
	_fx_material.set_shader_parameter("speed_lines", clampf(intensity, 0.0, 1.0))
	_fx_update_visibility()

## @ace_action
## @ace_name("Play Sound Varied")
## @ace_category("Juice 3D")
## @ace_description("Plays a sound with a random pitch and volume wobble around the base - the #1 trick against repetitive footsteps, hits, and shots. Fire-and-forget (the player frees itself).")
## @ace_icon("res://eventsheet_addons/juice_3d/icon.svg")
## @ace_codegen_template("$Juice3DBehavior.play_sound_varied({path}, {pitch_jitter}, {volume_jitter_db})")
func play_sound_varied(path: String, pitch_jitter: float, volume_jitter_db: float) -> void:
	_spawn_one_shot(path, 1.0 + randf_range(-pitch_jitter, pitch_jitter), randf_range(-absf(volume_jitter_db), 0.0))

## @ace_action
## @ace_name("Play Sound With Intensity")
## @ace_category("Juice 3D")
## @ace_description("Plays a sound scaled by an intensity (0..1): quiet + lower-pitched when light, full + brighter when heavy - drive it, Shake, and Punch Scale from ONE hit-power value so light and heavy hits differ by one number.")
## @ace_icon("res://eventsheet_addons/juice_3d/icon.svg")
## @ace_codegen_template("$Juice3DBehavior.play_sound_intensity({path}, {intensity})")
func play_sound_intensity(path: String, intensity: float) -> void:
	var power: float = clampf(intensity, 0.0, 1.0)
	_spawn_one_shot(path, lerpf(0.85, 1.15, power) * (1.0 + randf_range(-0.03, 0.03)), lerpf(-14.0, 0.0, power))

## @ace_action
## @ace_name("Count To")
## @ace_category("Juice 3D")
## @ace_description("Eases a named display value toward a target over a duration - scores and gold ROLL instead of snapping. Read it with the Ticker Value expression; emits On Ticker Finished (with the name) when it lands.")
## @ace_icon("res://eventsheet_addons/juice_3d/icon.svg")
## @ace_codegen_template("$Juice3DBehavior.count_to({ticker_name}, {target}, {duration})")
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
## @ace_category("Juice 3D")
## @ace_description("Sets a named display value INSTANTLY (cancelling any roll) - initialise a score at 0, or snap on a reset.")
## @ace_icon("res://eventsheet_addons/juice_3d/icon.svg")
## @ace_codegen_template("$Juice3DBehavior.set_ticker({ticker_name}, {value})")
func set_ticker(ticker_name: String, value: float) -> void:
	var old_tween: Tween = _ticker_tweens.get(ticker_name, null)
	if old_tween != null and is_instance_valid(old_tween):
		old_tween.kill()
	_tickers[ticker_name] = value
	_ticker_targets[ticker_name] = value

## @ace_expression
## @ace_name("Ticker Value")
## @ace_description("What a ticker currently SHOWS - the eased value Count To is rolling toward its target. Print or draw this instead of the real variable and scores roll instead of snapping.")
## @ace_icon("res://eventsheet_addons/juice_3d/icon.svg")
## @ace_codegen_template("$Juice3DBehavior.ticker_value({ticker_name})")
func ticker_value(ticker_name: String) -> float:
	return float(_tickers.get(ticker_name, 0.0))

## @ace_hidden
func _finish_ticker(ticker_name: String) -> void:
	_tickers[ticker_name] = _ticker_targets.get(ticker_name, _tickers.get(ticker_name, 0.0))
	ticker_finished.emit(ticker_name)

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

## Removes last frame's additive offsets from whichever camera received them, so this frame
## starts from the pose the camera's OWNER (controller/animation) wrote.
func _unapply() -> void:
	if _last_camera == null or not is_instance_valid(_last_camera):
		_applied_position = Vector3.ZERO
		_applied_rotation = Vector3.ZERO
		_applied_fov = 0.0
		return
	_last_camera.position -= _applied_position
	_last_camera.rotation -= _applied_rotation
	_last_camera.fov = clampf(_last_camera.fov - _applied_fov, 1.0, 179.0)
	_applied_position = Vector3.ZERO
	_applied_rotation = Vector3.ZERO
	_applied_fov = 0.0

## @ace_condition
## @ace_name("Is Shaking")
## @ace_icon("res://eventsheet_addons/juice_3d/icon.svg")
## @ace_codegen_template("$Juice3DBehavior.is_shaking()")
func is_shaking() -> bool:
	return trauma > 0.0

## @ace_expression
## @ace_name("Trauma")
## @ace_icon("res://eventsheet_addons/juice_3d/icon.svg")
## @ace_codegen_template("$Juice3DBehavior.current_trauma()")
func current_trauma() -> float:
	return trauma

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
## @ace_name("Set Screen Tint")
## @ace_description("Washes the WHOLE SCREEN with a color at Strength opacity (0..1) over the 3D view - damage red, poison green, night blue. Call again to retune; strength 0 clears.")
## @ace_icon("res://eventsheet_addons/juice_3d/icon.svg")
## @ace_codegen_template("$Juice3DBehavior.set_screen_tint({color}, {strength})")
func set_screen_tint(color: Color, strength: float) -> void:
	_ensure_tint_overlay()
	if _tint_rect != null:
		_tint_rect.color = Color(color.r, color.g, color.b, clampf(strength, 0.0, 1.0))
		_tint_rect.visible = _tint_rect.color.a > 0.001

## @ace_action
## @ace_name("Fade Screen Tint")
## @ace_description("Fades the screen tint's strength to zero over the given seconds - the damage-flash pattern: Set Screen Tint red 0.4, then Fade Screen Tint 0.3.")
## @ace_icon("res://eventsheet_addons/juice_3d/icon.svg")
## @ace_codegen_template("$Juice3DBehavior.fade_screen_tint({seconds})")
func fade_screen_tint(seconds: float) -> void:
	if _tint_rect == null or not _tint_rect.visible:
		return
	create_tween().tween_property(_tint_rect, "color:a", 0.0, maxf(seconds, 0.01))

## @ace_action
## @ace_name("Clear Screen Tint")
## @ace_description("Removes the screen tint instantly.")
## @ace_icon("res://eventsheet_addons/juice_3d/icon.svg")
## @ace_codegen_template("$Juice3DBehavior.clear_screen_tint()")
func clear_screen_tint() -> void:
	if _tint_rect != null:
		_tint_rect.visible = false

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

# 3D camera game feel: shake, recoil, head bob, jitter, lean, and FOV punch/zoom on the active Camera3D - auto-found, applied as additive offsets so they never fight the controller that owns the camera. Verbs mirror the 2D Juice pack.
