# Pack builder - juice (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## Game-feel in one behavior: trauma-based SCREENSHAKE (the idea behind the scroll behavior's
## shake, but additive on the camera's offset/rotation so it composes with Godot's camera follow
## instead of fighting it), smooth ZOOM (by percent, focus-onto-a-point, or anchored mouse-wheel
## style), and volume-preserving SQUASH & STRETCH on the host - which can be a Node2D (sprites) OR a
## Control (UI). The camera is AUTO-FOUND (get_viewport().get_camera_2d()), so Shake / Zoom just work
## from anywhere with no wiring. Every effect is fire-and-forget (Tween-driven) and emits an
## "On X Finished" signal so you can chain the next beat reactively.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	# CanvasItem is the shared base of Node2D and Control, so Squash & Stretch works on sprites AND UI.
	sheet.host_class = "CanvasItem"
	sheet.custom_class_name = "JuiceBehavior"
	sheet.class_description = "Game feel from event rows: screenshake, recoil, head bob, zoom, squash and stretch, slowmo, hitstop, damage flash and blink, punch transforms, ghost trails, screen FX (vignette, chromatic kick, speed lines), varied one-shot audio, and eased score tickers in one behavior. Camera effects find the active Camera2D on their own, and every effect is fire-and-forget with an On Finished trigger so you can chain the next beat."
	sheet.addon_category = "Juice"
	sheet.ace_expose_all_mode = "node"
	sheet.addon_tags = PackedStringArray(["camera", "juice"])
	var about: CommentRow = CommentRow.new()
	about.text = "Game feel, batteries included: screenshake, recoil, head bob, jitter, camera tilt, smooth zoom, and squash & stretch. The camera is found automatically - attach this anywhere and call Shake / Recoil / Zoom; all camera effects compose around one rest pose. Squash & Stretch animates the node it's attached to. (3D camera? Use the Juice 3D pack - same verbs on the active Camera3D.) A whole beat of feedback is one row: Moment plays a file of steps - impact, kill, triumph, danger, calm and cut ship beside this pack as starters to edit."
	sheet.events.append(about)
	var block: RawCodeRow = RawCodeRow.new()
	block.code = "\n".join(PackedStringArray([
		"# --- Designer knobs (tune the FEEL in the Inspector) ---",
		"## Peak camera shake offset, in pixels, at full trauma.",
		"@export var max_offset: Vector2 = Vector2(24, 16)",
		"## Peak camera roll (rotation) in degrees at full trauma.",
		"@export_range(0.0, 30.0, 0.5) var max_roll_degrees: float = 3.0",
		"## Trauma lost per second - higher means shorter, snappier shakes.",
		"@export_range(0.1, 10.0, 0.1) var shake_decay: float = 1.4",
		"## How fast the shake noise scrolls (the jitter rate).",
		"@export_range(1.0, 60.0, 1.0) var shake_frequency: float = 25.0",
		"## Clamp: the most zoomed-OUT the camera may go (smaller = further out).",
		"@export_range(0.05, 1.0, 0.05) var min_zoom: float = 0.2",
		"## Clamp: the most zoomed-IN the camera may go.",
		"@export_range(1.0, 16.0, 0.5) var max_zoom: float = 5.0",
		"## Slowmo: how the slow-down ramps IN (curve + direction).",
		"@export_enum(\"linear\", \"sine\", \"quad\", \"cubic\", \"expo\", \"circ\", \"back\") var slowmo_fade_in_trans: String = \"sine\"",
		"## Slowmo: which direction the fade-IN curve eases (in / out / in-out / out-in).",
		"@export_enum(\"in\", \"out\", \"in_out\", \"out_in\") var slowmo_fade_in_ease: String = \"out\"",
		"## Slowmo: how time ramps back OUT to normal.",
		"@export_enum(\"linear\", \"sine\", \"quad\", \"cubic\", \"expo\", \"circ\", \"back\") var slowmo_fade_out_trans: String = \"sine\"",
		"## Slowmo: which direction the fade-OUT curve eases back to normal speed (in / out / in-out / out-in).",
		"@export_enum(\"in\", \"out\", \"in_out\", \"out_in\") var slowmo_fade_out_ease: String = \"in\"",
		"## Slowmo: seconds spent fading in / out (the ramp lengths, separate from the HOLD).",
		"@export_range(0.0, 2.0, 0.05) var slowmo_fade_in_secs: float = 0.15",
		"## Slowmo: seconds spent easing back OUT to normal speed (separate from the HOLD).",
		"@export_range(0.0, 2.0, 0.05) var slowmo_fade_out_secs: float = 0.35",
		"## Spring Squash: stiffness + damping of the spring-back (lower damping = bouncier).",
		"@export_range(1.0, 1000.0, 1.0) var squash_stiffness: float = 250.0",
		"## Spring Squash: how quickly the spring-back settles (lower = bouncier, higher = calmer).",
		"@export_range(0.0, 1.0, 0.01) var squash_damping: float = 0.6",
		"## How fast a Recoil kick returns to centre, in pixels per second.",
		"@export_range(10.0, 2000.0, 5.0) var recoil_recovery: float = 140.0",
		"",
		"# --- Internal state ---",
		"var trauma: float = 0.0",
		"var shake_time: float = 0.0",
		"var _shaking: bool = false",
		"# True while ANY camera effect is holding the camera away from its captured rest pose.",
		"var _cam_driving: bool = false",
		"var _recoil_vec: Vector2 = Vector2.ZERO",
		"var _bob_active: bool = false",
		"var _bob_time: float = 0.0",
		"var _bob_amplitude: float = 6.0",
		"var _bob_frequency: float = 2.2",
		"var _jitter_active: bool = false",
		"var _jitter_time: float = 0.0",
		"var _jitter_amount: float = 3.0",
		"var _tilt_roll: float = 0.0",
		"var _tilt_tween: Tween = null",
		"var _base_offset: Vector2 = Vector2.ZERO",
		"var _base_rotation: float = 0.0",
		"var _base_scale: Vector2 = Vector2.ONE",
		"var _noise: FastNoiseLite = null",
		"var _camera_override: Camera2D = null",
		"# The camera the rest pose was captured from - if the active camera changes mid-effect, the old",
		"# one is handed back before the new one is driven (so it isn't left shaken, nor the new mis-based).",
		"var _last_camera: Camera2D = null",
		"# Anchored-zoom (Zoom Toward Point) interpolation state.",
		"var _zoom_from: Vector2 = Vector2.ONE",
		"var _zoom_to: Vector2 = Vector2.ONE",
		"var _zoom_anchor: Vector2 = Vector2.ZERO",
		"var _zoom_cam_from: Vector2 = Vector2.ZERO",
		"# Slowmo state (single tween, kill-before-restart).",
		"var _slowmo_tween: Tween = null",
		"# Hitstop state (a brief freeze; driven by a REALTIME timer so it un-freezes even at time_scale 0).",
		"var _hitstop_active: bool = false",
		"var _hitstop_prev_scale: float = 1.0",
		"# Spring-squash state (per-frame integrator springing the scale back to rest).",
		"var _squash_spring_active: bool = false",
		"var _squash_value: Vector2 = Vector2.ONE",
		"var _squash_velocity: Vector2 = Vector2.ZERO",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Shake Stopped\")",
		"signal shake_stopped()",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Zoom Finished\")",
		"signal zoom_finished()",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Squash Finished\")",
		"signal squash_finished()",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Slowmo Finished\")",
		"signal slowmo_finished()",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Hitstop Finished\")",
		"signal hitstop_finished()",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Tilt Finished\")",
		"signal tilt_finished()",
		"",
		"## The camera these effects drive: an explicit override (Use Camera), else the active Camera2D -",
		"## auto-found, so Shake / Zoom just work from anywhere without wiring a path.",
		"func _camera() -> Camera2D:",
		"\tif _camera_override != null and is_instance_valid(_camera_override):",
		"\t\treturn _camera_override",
		"\tvar vp: Viewport = get_viewport()",
		"\tif vp == null:",
		"\t\treturn null",
		"\treturn vp.get_camera_2d()",
		"",
		"## Drives an ANCHORED zoom: keeps _zoom_anchor pinned under the same screen point as the zoom",
		"## interpolates (mouse-wheel-to-cursor feel). Called by Zoom Toward Point's tween each frame.",
		"func _zoom_anchored_step(f: float) -> void:",
		"\tvar cam: Camera2D = _camera()",
		"\tif cam == null:",
		"\t\treturn",
		"\tvar z: Vector2 = _zoom_from.lerp(_zoom_to, f)",
		"\tz.x = maxf(z.x, 0.001)",
		"\tz.y = maxf(z.y, 0.001)",
		"\tcam.zoom = z",
		"\tcam.global_position = _zoom_anchor - (_zoom_anchor - _zoom_cam_from) * (_zoom_from / z)",
		"",
		"## @ace_condition",
		"## @ace_name(\"Is Shaking\")",
		"func is_shaking() -> bool:",
		"\treturn trauma > 0.0",
		"",
		"## @ace_expression",
		"## @ace_name(\"Trauma\")",
		"func current_trauma() -> float:",
		"\treturn trauma",
		"",
		"## @ace_condition",
		"## @ace_name(\"Is Hitstopped\")",
		"func is_hitstopped() -> bool:",
		"\treturn _hitstop_active",
		"",
		"func _set_time_scale(s: float) -> void:",
		"\tEngine.time_scale = s",
		"",
		"## Maps a slowmo easing-curve name (Inspector enum) to a Tween.TransitionType.",
		"func _slowmo_trans(easing_name: String) -> int:",
		"\tmatch easing_name:",
		"\t\t\"linear\": return Tween.TRANS_LINEAR",
		"\t\t\"quad\": return Tween.TRANS_QUAD",
		"\t\t\"cubic\": return Tween.TRANS_CUBIC",
		"\t\t\"expo\": return Tween.TRANS_EXPO",
		"\t\t\"circ\": return Tween.TRANS_CIRC",
		"\t\t\"back\": return Tween.TRANS_BACK",
		"\t\t_: return Tween.TRANS_SINE",
		"",
		"## Maps a slowmo easing-direction name (Inspector enum) to a Tween.EaseType.",
		"func _slowmo_ease(easing_name: String) -> int:",
		"\tmatch easing_name:",
		"\t\t\"in\": return Tween.EASE_IN",
		"\t\t\"in_out\": return Tween.EASE_IN_OUT",
		"\t\t\"out_in\": return Tween.EASE_OUT_IN",
		"\t\t_: return Tween.EASE_OUT",
		"",
		"## Applies a scale to the host whether it's a Node2D or a Control (centring a Control's pivot so",
		"## it scales from the middle). Used by Spring Squash's per-frame integrator.",
		"func _apply_host_scale(s: Vector2) -> void:",
		"\tif host is Node2D:",
		"\t\t(host as Node2D).scale = s",
		"\telif host is Control:",
		"\t\tvar c: Control = host as Control",
		"\t\tc.pivot_offset = c.size / 2.0",
		"\t\tc.scale = s"
	]))
	sheet.events.append(block)
	# Seed the noise + capture the host's resting scale once, after host is wired in _ready.
	var on_ready: EventRow = EventRow.new()
	on_ready.trigger_provider_id = "Core"
	on_ready.trigger_id = "OnReady"
	var ready_body: RawCodeRow = RawCodeRow.new()
	ready_body.code = "\n".join(PackedStringArray([
		"_noise = FastNoiseLite.new()",
		"_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH",
		"_noise.frequency = 1.0",
		"_noise.seed = randi()",
		"if host is Node2D:",
		"\t_base_scale = (host as Node2D).scale",
		"elif host is Control:",
		"\t_base_scale = (host as Control).scale",
		"# Nothing is shaking, bobbing, blinking or springing on the first frame, and every verb that",
		"# starts one of those turns processing back on - so an idle Juice costs nothing per frame.",
		"set_process(false)"
	]))
	on_ready.actions.append(ready_body)
	sheet.events.append(on_ready)
	# Safety: if the host leaves the tree mid-slowmo or mid-hitstop, restore the GLOBAL Engine.time_scale -
	# otherwise a scene change during slow motion (or a freeze) would leave the entire game slowed or frozen.
	# Clearing _hitstop_active makes a still-pending hitstop timer no-op when it fires (see hitstop).
	var teardown: EventRow = EventRow.new()
	teardown.trigger_provider_id = "Core"
	teardown.trigger_id = "OnTreeExiting"
	var teardown_body: RawCodeRow = RawCodeRow.new()
	# Restore the GLOBAL Engine.time_scale ONLY if THIS instance is the one holding it away from 1.0
	# (a running slowmo or an active hitstop). Otherwise an unrelated JuiceBehavior leaving the tree -
	# an enemy freed mid-bullet-time - would snap the player's slowmo (or a game-owned pause) back to 1.
	teardown_body.code = "\n".join(PackedStringArray([
		"var __owned_time := _hitstop_active or (_slowmo_tween != null and is_instance_valid(_slowmo_tween) and _slowmo_tween.is_running())",
		"_hitstop_active = false",
		"if _slowmo_tween != null and is_instance_valid(_slowmo_tween):",
		"\t_slowmo_tween.kill()",
		"_slowmo_tween = null",
		"if __owned_time:",
		"\tEngine.time_scale = 1.0"
	]))
	teardown.actions.append(teardown_body)
	sheet.events.append(teardown)
	# Per-frame: one step of the chromatic shake. It runs BEFORE the camera mixer because the split
	# is drawn on the screen rather than through a lens - it has to go on shaking in a scene with no
	# camera in it at all - and the mixer's own work is camera-shaped.
	var chroma_shake_tick: EventRow = EventRow.new()
	chroma_shake_tick.trigger_provider_id = "Core"
	chroma_shake_tick.trigger_id = "OnProcess"
	var chroma_shake_tick_body: RawCodeRow = RawCodeRow.new()
	chroma_shake_tick_body.code = Lib.JUICE_CHROMA_SHAKE_TICK_BODY
	chroma_shake_tick.actions.append(chroma_shake_tick_body)
	sheet.events.append(chroma_shake_tick)
	# Per-frame: decay trauma and drive the camera offset/roll from squared trauma (perceptual ramp).
	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"
	tick.trigger_id = "OnProcess"
	var tick_body: RawCodeRow = RawCodeRow.new()
	tick_body.code = "\n".join(PackedStringArray([
		"# Effect STATE advances camera-or-not (headless-safe: trauma must decay and recoil must",
		"# recover even when no viewport exists); only the camera write below needs a camera.",
		"if trauma > 0.0:",
		"\ttrauma = maxf(trauma - shake_decay * delta, 0.0)",
		"\tshake_time += delta",
		"\t_shaking = true",
		"if trauma <= 0.0 and _shaking:",
		"\t_shaking = false",
		"\tshake_stopped.emit()",
		"if _recoil_vec != Vector2.ZERO:",
		"\t_recoil_vec = _recoil_vec.move_toward(Vector2.ZERO, recoil_recovery * delta)",
		"if _bob_active:",
		"\t_bob_time += delta * _bob_frequency",
		"if _jitter_active:",
		"\t_jitter_time += delta * shake_frequency",
		"var cam: Camera2D = _camera()",
		"if cam != null:",
		"\t# The active camera changed while we were driving: return the OLD camera to the pose we found",
		"\t# it in, and re-capture from the new one, so neither is left displaced.",
		"\tif _cam_driving and _last_camera != null and is_instance_valid(_last_camera) and _last_camera != cam:",
		"\t\t_last_camera.offset = _base_offset",
		"\t\t_last_camera.rotation = _base_rotation",
		"\t\t_cam_driving = false",
		"\t# One mixer for every camera effect: all contributions sum around ONE captured rest pose,",
		"\t# so shake + recoil + bob + jitter + tilt compose instead of fighting over the offset.",
		"\tvar cam_wants: bool = trauma > 0.0 or _bob_active or _jitter_active or _recoil_vec != Vector2.ZERO or absf(_tilt_roll) > 0.0001",
		"\tif cam_wants:",
		"\t\tif not _cam_driving:",
		"\t\t\t_cam_driving = true",
		"\t\t\t_last_camera = cam",
		"\t\t\t_base_offset = cam.offset",
		"\t\t\t_base_rotation = cam.rotation",
		"\t\tvar fx_offset: Vector2 = _recoil_vec",
		"\t\tvar fx_roll: float = deg_to_rad(_tilt_roll)",
		"\t\tif trauma > 0.0:",
		"\t\t\t# Square the trauma so the shake ramps in perceptually (Squirrel Eiserloh's model).",
		"\t\t\tvar amount: float = trauma * trauma",
		"\t\t\tvar t: float = shake_time * shake_frequency",
		"\t\t\tfx_offset += Vector2(max_offset.x * amount * _noise.get_noise_2d(t, 0.0), max_offset.y * amount * _noise.get_noise_2d(0.0, t))",
		"\t\t\tfx_roll += deg_to_rad(max_roll_degrees) * amount * _noise.get_noise_2d(t, t)",
		"\t\tif _jitter_active:",
		"\t\t\tfx_offset += Vector2(_jitter_amount * _noise.get_noise_2d(_jitter_time, 100.0), _jitter_amount * _noise.get_noise_2d(100.0, _jitter_time))",
		"\t\tif _bob_active:",
		"\t\t\t# A walking figure-8: side sway at half rate, one vertical dip per step.",
		"\t\t\tfx_offset += Vector2(sin(_bob_time * TAU * 0.5) * _bob_amplitude * 0.5, sin(_bob_time * TAU) * _bob_amplitude)",
		"\t\t# One global dial every camera effect is scaled by, so a player who gets motion sick",
		"\t\t# can turn shake, recoil, bob and tilt down (or off) and keep the game. 1 when nobody",
		"\t\t# has set it, so a project that never asks is untouched.",
		"\t\tvar effect_strength: float = float(Engine.get_meta(\"effect_strength\", 1.0))",
		"\t\tcam.offset = _base_offset + fx_offset * effect_strength",
		"\t\tcam.rotation = _base_rotation + fx_roll * effect_strength",
		"\telif _cam_driving:",
		"\t\t# Every effect settled: hand the camera back exactly as we found it.",
		"\t\tcam.offset = _base_offset",
		"\t\tcam.rotation = _base_rotation",
		"\t\t_cam_driving = false",
		"if _squash_spring_active:",
		"\t# Spring the scale back to rest (semi-implicit, framerate-independent - same model as the Spring pack).",
		"\t_squash_velocity += (_base_scale - _squash_value) * squash_stiffness * delta",
		"\t_squash_velocity *= pow(1.0 - squash_damping, delta)",
		"\t_squash_value += _squash_velocity * delta",
		"\tif (_base_scale - _squash_value).length() < 0.001 and _squash_velocity.length() < 0.001:",
		"\t\t_squash_value = _base_scale",
		"\t\t_squash_velocity = Vector2.ZERO",
		"\t\t_squash_spring_active = false",
		"\t\t_apply_host_scale(_base_scale)",
		"\t\tsquash_finished.emit()",
		"\telse:",
		"\t\t_apply_host_scale(_squash_value)"
	]))
	tick.actions.append(tick_body)
	sheet.events.append(tick)

	# ── Color tints (object + screen), adjustable strength ─────────────────────────
	var tint_block: RawCodeRow = RawCodeRow.new()
	tint_block.code = "\n".join(PackedStringArray([
		"# The tint overlay: a top CanvasLayer ColorRect built on first use - the screen",
		"# wash for damage reds, poison greens, flashback sepias. Strength IS the opacity.",
		"var _tint_overlay: CanvasLayer = null",
		"var _tint_rect: ColorRect = null",
		"",
		"## @ace_hidden",
		"func _ensure_tint_overlay() -> void:",
		"\tif _tint_overlay != null or not is_inside_tree():",
		"\t\treturn",
		"\t_tint_overlay = CanvasLayer.new()",
		"\t_tint_overlay.layer = 90",
		"\tadd_child(_tint_overlay)",
		"\t_tint_rect = ColorRect.new()",
		"\t_tint_rect.color = Color(0.0, 0.0, 0.0, 0.0)",
		"\t_tint_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE",
		"\t_tint_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)",
		"\t_tint_overlay.add_child(_tint_rect)",
		"",
		"## Tints the HOST object: blends its color toward the tint by Strength (0 = its own",
		"## colors untouched, 1 = fully the tint color) - the classic object tint, with the",
		"## strength as your opacity dial. Children inherit (modulate).",
		"## @ace_action",
		"## @ace_name(\"Set Host Tint\")",
		"func set_host_tint(color: Color, strength: float) -> void:",
		"\tif host is CanvasItem:",
		"\t\t(host as CanvasItem).modulate = Color.WHITE.lerp(Color(color.r, color.g, color.b, 1.0), clampf(strength, 0.0, 1.0))",
		"",
		"## Removes the host tint (back to its own colors).",
		"## @ace_action",
		"## @ace_name(\"Clear Host Tint\")",
		"func clear_host_tint() -> void:",
		"\tif host is CanvasItem:",
		"\t\t(host as CanvasItem).modulate = Color.WHITE",
		"",
		"## Washes the WHOLE SCREEN with a color at Strength opacity (0..1) - damage red,",
		"## poison green, night blue, flashback sepia. Call again to retune; strength 0 clears.",
		"## @ace_action",
		"## @ace_name(\"Set Screen Tint\")",
		"func set_screen_tint(color: Color, strength: float) -> void:",
		"\t_ensure_tint_overlay()",
		"\tif _tint_rect != null:",
		"\t\t_tint_rect.color = Color(color.r, color.g, color.b, clampf(strength, 0.0, 1.0))",
		"\t\t_tint_rect.visible = _tint_rect.color.a > 0.001",
		"",
		"## Fades the screen tint's strength to zero over the given seconds - the damage-flash",
		"## pattern: Set Screen Tint red 0.4, then Fade Screen Tint 0.3.",
		"## @ace_action",
		"## @ace_name(\"Fade Screen Tint\")",
		"func fade_screen_tint(seconds: float) -> void:",
		"\tif _tint_rect == null or not _tint_rect.visible:",
		"\t\treturn",
		"\tcreate_tween().tween_property(_tint_rect, \"color:a\", 0.0, maxf(seconds, 0.01))",
		"",
		"## Removes the screen tint instantly.",
		"## @ace_action",
		"## @ace_name(\"Clear Screen Tint\")",
		"func clear_screen_tint() -> void:",
		"\tif _tint_rect != null:",
		"\t\t_tint_rect.visible = false"
	]))
	sheet.events.append(tint_block)

	# ── Flash / blink / punches / ghost trail / tickers - shared state + helpers ──────
	var extras_block: RawCodeRow = RawCodeRow.new()
	extras_block.code = "\n".join(PackedStringArray([
		"# Flash / blink state (modulate-based, so both compose with Set Host Tint).",
		"var _flash_tween: Tween = null",
		"var _flash_restore: Color = Color.WHITE",
		"var _blink_active: bool = false",
		"var _blink_time: float = 0.0",
		"var _blink_rate: float = 8.0",
		"var _blink_min_alpha: float = 0.15",
		"var _blink_base_alpha: float = 1.0",
		"# Punch state (kick out, spring back; rest captured per gesture so repeats never drift).",
		"var _punch_rot_tween: Tween = null",
		"var _punch_rot_rest: float = 0.0",
		"var _punch_pos_tween: Tween = null",
		"var _punch_pos_rest: Vector2 = Vector2.ZERO",
		"# Ghost-trail state (stamped fading sprite copies).",
		"var _trail_active: bool = false",
		"var _trail_interval: float = 0.05",
		"var _trail_fade: float = 0.4",
		"var _trail_tint: Color = Color.WHITE",
		"var _trail_timer: float = 0.0",
		"# The sprite to copy, resolved ONCE at Start (not re-scanned every stamp), and the live ghosts,",
		"# capped so a high stamp rate with a long fade can't pile up thousands of nodes.",
		"var _ghost_sprite: Node2D = null",
		"var _ghosts: Array = []",
		"const _MAX_GHOSTS: int = 48",
		"# Eased tickers (Count To): name -> displayed value / target / driving tween.",
		"var _tickers: Dictionary = {}",
		"var _ticker_targets: Dictionary = {}",
		"var _ticker_tweens: Dictionary = {}",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Flash Finished\")",
		"signal flash_finished()",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Punch Finished\")",
		"signal punch_finished()",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Ticker Finished\")",
		"signal ticker_finished(ticker_name: String)",
		"",
		"## What a ticker currently SHOWS - the eased value Count To is rolling toward its target.",
		"## Print or draw this instead of the real variable and scores roll instead of snapping.",
		"## @ace_expression",
		"## @ace_name(\"Ticker Value\")",
		"func ticker_value(ticker_name: String) -> float:",
		"\treturn float(_tickers.get(ticker_name, 0.0))",
		"",
		"## @ace_hidden",
		"func _finish_ticker(ticker_name: String) -> void:",
		"\t_tickers[ticker_name] = _ticker_targets.get(ticker_name, _tickers.get(ticker_name, 0.0))",
		"\tticker_finished.emit(ticker_name)",
		"",
		"## Resolves the sprite the trail copies (host if it IS a sprite, else its first Sprite2D child),",
		"## cached at Start so it is not re-scanned every stamp. Null when the host has no sprite to trail.",
		"## @ace_hidden",
		"func _resolve_ghost_sprite() -> Node2D:",
		"\tif host is Sprite2D or host is AnimatedSprite2D:",
		"\t\treturn host as Node2D",
		"\tif host is Node2D:",
		"\t\tfor child in (host as Node2D).get_children():",
		"\t\t\tif child is Sprite2D:",
		"\t\t\t\treturn child as Node2D",
		"\treturn null",
		"",
		"## Stamps one fading copy of the cached sprite behind it - the trail's per-tick brush. Live",
		"## ghosts are capped (oldest freed) so a high stamp rate with a long fade can't pile up.",
		"## @ace_hidden",
		"func _stamp_ghost() -> void:",
		"\tvar trail_host: Node2D = host as Node2D",
		"\tif _ghost_sprite == null or not is_instance_valid(_ghost_sprite) or trail_host == null or not trail_host.is_inside_tree() or trail_host.get_parent() == null:",
		"\t\treturn",
		"\t# Drop freed ghosts, then cap: free the oldest until there is room for one more.",
		"\t_ghosts = _ghosts.filter(func(g: Variant) -> bool: return is_instance_valid(g))",
		"\twhile _ghosts.size() >= _MAX_GHOSTS:",
		"\t\tvar oldest: Node = _ghosts.pop_front()",
		"\t\tif is_instance_valid(oldest):",
		"\t\t\toldest.queue_free()",
		"\tvar ghost: Sprite2D = Sprite2D.new()",
		"\tif _ghost_sprite is Sprite2D:",
		"\t\tvar sprite: Sprite2D = _ghost_sprite as Sprite2D",
		"\t\tghost.texture = sprite.texture",
		"\t\tghost.hframes = sprite.hframes",
		"\t\tghost.vframes = sprite.vframes",
		"\t\tghost.frame = sprite.frame",
		"\t\tghost.region_enabled = sprite.region_enabled",
		"\t\tghost.region_rect = sprite.region_rect",
		"\t\tghost.flip_h = sprite.flip_h",
		"\t\tghost.flip_v = sprite.flip_v",
		"\t\tghost.centered = sprite.centered",
		"\t\tghost.offset = sprite.offset",
		"\telif _ghost_sprite is AnimatedSprite2D:",
		"\t\tvar animated: AnimatedSprite2D = _ghost_sprite as AnimatedSprite2D",
		"\t\tif animated.sprite_frames == null:",
		"\t\t\tghost.queue_free()",
		"\t\t\treturn",
		"\t\tghost.texture = animated.sprite_frames.get_frame_texture(animated.animation, animated.frame)",
		"\t\tghost.flip_h = animated.flip_h",
		"\t\tghost.flip_v = animated.flip_v",
		"\t\tghost.centered = animated.centered",
		"\t\tghost.offset = animated.offset",
		"\tif ghost.texture == null:",
		"\t\tghost.queue_free()",
		"\t\treturn",
		"\tghost.modulate = _trail_tint",
		"\tghost.z_index = _ghost_sprite.z_index - 1",
		"\t# Parent to the host's parent (a sibling), NOT the sprite, so a ghost STAYS PUT as the host",
		"\t# moves on - a trail behind it, positioned at the sprite's current world transform.",
		"\ttrail_host.get_parent().add_child(ghost)",
		"\tghost.global_transform = _ghost_sprite.global_transform",
		"\t_ghosts.append(ghost)",
		"\tvar tw: Tween = ghost.create_tween()",
		"\ttw.tween_property(ghost, \"modulate:a\", 0.0, maxf(_trail_fade, 0.05))",
		"\ttw.finished.connect(ghost.queue_free)",
		"",
		"## Spawns a throwaway one-shot AudioStreamPlayer (frees itself when done).",
		"## @ace_hidden",
		"func _spawn_one_shot(path: String, pitch: float, volume_db: float) -> void:",
		"\tvar stream: AudioStream = load(path) as AudioStream",
		"\tif stream == null:",
		"\t\treturn",
		"\tvar player: AudioStreamPlayer = AudioStreamPlayer.new()",
		"\tplayer.stream = stream",
		"\tplayer.pitch_scale = maxf(pitch, 0.05)",
		"\tplayer.volume_db = volume_db",
		"\tadd_child(player)",
		"\tplayer.finished.connect(player.queue_free)",
		"\tplayer.play()"
	]))
	sheet.events.append(extras_block)

	# ── Screen FX overlay: one bundled shader (vignette + chromatic + speed lines) ────
	var fx_block: RawCodeRow = RawCodeRow.new()
	fx_block.code = "\n".join(Lib.juice_fx_overlay_lines())
	sheet.events.append(fx_block)

	# ── Chromatic shake: the camera Shake's twin, on the screen instead of the lens ───
	var chroma_shake_block: RawCodeRow = RawCodeRow.new()
	chroma_shake_block.code = "\n".join(Lib.juice_chroma_shake_lines())
	sheet.events.append(chroma_shake_block)

	# ── Moments: a hit, a kill, a win, a danger, a calm - each one a file of steps ────
	var moment_block: RawCodeRow = RawCodeRow.new()
	moment_block.code = "\n".join(_moment_lines())
	sheet.events.append(moment_block)

	# Per-frame: blink strobe + ghost-trail stamping (a second _process event; the compiler
	# appends it after the camera mixer above).
	var tick_extras: EventRow = EventRow.new()
	tick_extras.trigger_provider_id = "Core"
	tick_extras.trigger_id = "OnProcess"
	var tick_extras_body: RawCodeRow = RawCodeRow.new()
	tick_extras_body.code = "\n".join(PackedStringArray([
		"if _blink_active and host is CanvasItem:",
		"\t_blink_time += delta * _blink_rate",
		"\tvar blink_item: CanvasItem = host as CanvasItem",
		"\tvar blink_color: Color = blink_item.modulate",
		"\tblink_color.a = _blink_base_alpha if fmod(_blink_time, 1.0) < 0.5 else _blink_min_alpha",
		"\tblink_item.modulate = blink_color",
		"if _trail_active:",
		"\t_trail_timer -= delta",
		"\tif _trail_timer <= 0.0:",
		"\t\t_trail_timer = maxf(_trail_interval, 0.01)",
		"\t\t_stamp_ghost()",
		"# A beat in the air is counted down here, and a channel shake is drawn here, so both are one",
		"# call in a tick this behaviour was already paying for rather than a timer of their own.",
		"_moment_tick(delta)",
		"_channel_tick(delta)",
		"# The frame ended with nothing left to animate: stop paying for the tick until a verb starts",
		"# another effect. A held camera counts as work - _cam_driving stays true until the mixer above",
		"# has handed the camera back to the pose it was found in - and so does a running Tilt tween,",
		"# which writes _tilt_roll for the mixer to apply rather than touching the camera itself.",
		"var camera_busy: bool = _cam_driving or trauma > 0.0 or _bob_active or _jitter_active or _recoil_vec != Vector2.ZERO or absf(_tilt_roll) > 0.0001",
		"var tilt_running: bool = _tilt_tween != null and is_instance_valid(_tilt_tween) and _tilt_tween.is_running()",
		"if not (camera_busy or tilt_running or _squash_spring_active or _blink_active or _trail_active",
		"\t\tor _chroma_shake_active or _moment_busy() or _channel_busy()):",
		"\tset_process(false)"
	]))
	tick_extras.actions.append(tick_extras_body)
	sheet.events.append(tick_extras)

	# --- Actions (fire-and-forget) ---
	Lib.append_function(sheet, "shake", "Shake", "Juice", "Adds screenshake to the active camera (0 = none, 1 = max). Stacks and decays automatically - fire it on every hit.",
		[["strength", "float"]],
		"trauma = clampf(trauma + strength, 0.0, 1.0)\nset_process(true)")
	_default(sheet, "strength", "0.4")
	Lib.append_function(sheet, "stop_shake", "Stop Shake", "Juice", "Cancels any shake immediately (the camera returns to rest unless another effect - recoil, bob, jitter, tilt - is still holding it).",
		[],
		"trauma = 0.0\nshake_time = 0.0\n_shaking = false\nvar cam: Camera2D = _camera()\nif cam != null and _cam_driving and not (_bob_active or _jitter_active or _recoil_vec != Vector2.ZERO or absf(_tilt_roll) > 0.0001):\n\tcam.offset = _base_offset\n\tcam.rotation = _base_rotation\n\t_cam_driving = false")
	Lib.append_function(sheet, "use_camera", "Use Camera", "Juice", "Pin the effects to a specific Camera2D (by path). Leave it unused to auto-target whichever camera is active.",
		[["camera_path", "NodePath"]],
		"_camera_override = get_node_or_null(camera_path) as Camera2D")
	Lib.append_function(sheet, "recoil", "Recoil", "Juice", "Kicks the camera a distance (pixels) in a direction (degrees: -90 = up, 0 = right) and springs it back at the Recoil Recovery rate. Fire on every shot - kicks stack, so rapid fire climbs. Composes with Shake/Bob/Jitter.",
		[["angle_degrees", "float"], ["strength", "float"]],
		"_recoil_vec += Vector2.from_angle(deg_to_rad(angle_degrees)) * strength\nset_process(true)")
	_default(sheet, "angle_degrees", "-90")
	_default(sheet, "strength", "12")
	Lib.append_function(sheet, "start_head_bob", "Start Head Bob", "Juice", "Starts a walking head-bob on the camera: a figure-8 sway (side at half rate, one vertical dip per step). Amplitude is pixels, frequency is steps per second. Call while your character moves; Stop Head Bob when they halt.",
		[["amplitude", "float"], ["frequency", "float"]],
		"_bob_amplitude = amplitude\n_bob_frequency = maxf(frequency, 0.01)\n_bob_active = true\nset_process(true)")
	_default(sheet, "amplitude", "6")
	_default(sheet, "frequency", "2.2")
	Lib.append_function(sheet, "stop_head_bob", "Stop Head Bob", "Juice", "Stops the head bob (the camera returns to rest once every other effect settles too).",
		[],
		"_bob_active = false")
	Lib.append_function(sheet, "start_jitter", "Start Jitter", "Juice", "Starts a continuous nervous wobble on the camera (pixels) that runs until Stop Jitter - unlike Shake it never decays. Great for engines idling, drunk vision, earthquakes building, low-health unease.",
		[["amount", "float"]],
		"_jitter_amount = amount\n_jitter_active = true\nset_process(true)")
	_default(sheet, "amount", "3")
	Lib.append_function(sheet, "stop_jitter", "Stop Jitter", "Juice", "Stops the jitter wobble.",
		[],
		"_jitter_active = false")
	Lib.append_function(sheet, "tilt_to", "Tilt To", "Juice", "Eases the camera roll to an angle (degrees) and HOLDS it - lean into a drift, a hill, or a dramatic dutch angle. Tilt back to 0 to level out. Emits On Tilt Finished.",
		[["degrees", "float"], ["duration", "float"]],
		"if _tilt_tween != null:\n\t_tilt_tween.kill()\nvar tw: Tween = create_tween()\ntw.tween_property(self, \"_tilt_roll\", degrees, maxf(duration, 0.001)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)\ntw.finished.connect(func() -> void: tilt_finished.emit())\n_tilt_tween = tw\nset_process(true)")
	_default(sheet, "degrees", "6")
	_default(sheet, "duration", "0.3")
	Lib.append_function(sheet, "zoom_by_percent", "Zoom By Percent", "Juice", "Smoothly zooms the camera (100 = no change, 150 = zoom in 1.5x, 50 = zoom out). Clamped to the min/max zoom knobs.",
		[["percent", "float"], ["duration", "float"]],
		"var cam: Camera2D = _camera()\nif cam == null:\n\treturn\nvar target_zoom: Vector2 = cam.zoom * (percent / 100.0)\ntarget_zoom = Vector2(clampf(target_zoom.x, min_zoom, max_zoom), clampf(target_zoom.y, min_zoom, max_zoom))\nvar tw: Tween = create_tween()\ntw.tween_property(cam, \"zoom\", target_zoom, maxf(duration, 0.001)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)\ntw.finished.connect(func() -> void: zoom_finished.emit())")
	_default(sheet, "percent", "150")
	_default(sheet, "duration", "0.4")
	Lib.append_function(sheet, "zoom_to_position", "Zoom To Position", "Juice", "Zooms in while gliding the camera so a world position becomes the screen CENTRE - frame a spot in one action.",
		[["world_position", "Vector2"], ["percent", "float"], ["duration", "float"]],
		"var cam: Camera2D = _camera()\nif cam == null:\n\treturn\nvar target_zoom: Vector2 = cam.zoom * (percent / 100.0)\ntarget_zoom = Vector2(clampf(target_zoom.x, min_zoom, max_zoom), clampf(target_zoom.y, min_zoom, max_zoom))\nvar seconds: float = maxf(duration, 0.001)\nvar tw: Tween = create_tween().set_parallel(true)\ntw.tween_property(cam, \"zoom\", target_zoom, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)\ntw.tween_property(cam, \"global_position\", world_position, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)\ntw.finished.connect(func() -> void: zoom_finished.emit())")
	_default(sheet, "percent", "150")
	_default(sheet, "duration", "0.4")
	Lib.append_function(sheet, "zoom_toward_point", "Zoom Toward Point", "Juice", "Zooms while keeping a world position pinned under the same screen spot (mouse-wheel-to-cursor style) - great for strategy/map zoom.",
		[["world_position", "Vector2"], ["percent", "float"], ["duration", "float"]],
		"var cam: Camera2D = _camera()\nif cam == null:\n\treturn\n_zoom_cam_from = cam.global_position\n_zoom_from = cam.zoom\nvar target_zoom: Vector2 = cam.zoom * (percent / 100.0)\n_zoom_to = Vector2(clampf(target_zoom.x, min_zoom, max_zoom), clampf(target_zoom.y, min_zoom, max_zoom))\n_zoom_anchor = world_position\nvar tw: Tween = create_tween()\ntw.tween_method(_zoom_anchored_step, 0.0, 1.0, maxf(duration, 0.001)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)\ntw.finished.connect(func() -> void: zoom_finished.emit())")
	_default(sheet, "percent", "150")
	_default(sheet, "duration", "0.4")
	Lib.append_function(sheet, "squash_and_stretch", "Squash & Stretch", "Juice", "Pops the host (Node2D or Control) with a volume-preserving stretch that springs back elastically. Positive = stretch tall (a jump), negative = squash wide (a landing).",
		[["stretch", "float"], ["duration", "float"]],
		"if host == null:\n\treturn\nvar s: float = clampf(stretch, -0.9, 5.0)\nvar stretched: Vector2 = Vector2(_base_scale.x / (1.0 + s), _base_scale.y * (1.0 + s))\nif host is Node2D:\n\t(host as Node2D).scale = stretched\nelif host is Control:\n\tvar c: Control = host as Control\n\t# Control scales from its top-left by default; centre the pivot so the pop reads right.\n\tc.pivot_offset = c.size / 2.0\n\tc.scale = stretched\nelse:\n\treturn\nvar tw: Tween = create_tween()\ntw.tween_property(host, \"scale\", _base_scale, maxf(duration, 0.001)).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)\ntw.finished.connect(func() -> void: squash_finished.emit())")
	_default(sheet, "stretch", "0.3")
	_default(sheet, "duration", "0.4")
	Lib.append_function(sheet, "spring_squash", "Spring Squash", "Juice", "Pops the host (Node2D or Control) with a volume-preserving stretch that springs back via a real spring (the stiffness/damping knobs) - bouncier + more organic than the tween Squash & Stretch. Positive = stretch tall (a jump), negative = squash wide (a landing).",
		[["stretch", "float"]],
		"if host == null:\n\treturn\nvar s: float = clampf(stretch, -0.9, 5.0)\n_squash_value = Vector2(_base_scale.x / (1.0 + s), _base_scale.y * (1.0 + s))\n_squash_velocity = Vector2.ZERO\n_squash_spring_active = true\n_apply_host_scale(_squash_value)\nset_process(true)")
	_default(sheet, "stretch", "0.3")
	Lib.append_function(sheet, "slowmo", "Slowmo", "Juice", "Briefly slows Engine.time_scale to the target, HOLDS for a duration, then eases back to normal. Fade curves are Inspector knobs; pick whether the hold counts in realtime or scaled game time. Emits On Slowmo Finished.",
		[["target_scale", "float"], ["hold_duration", "float"], ["duration_clock", "String"]],
		"if _slowmo_tween != null:\n\t_slowmo_tween.kill()\nvar ts: float = clampf(target_scale, 0.0, 1.0)\nvar tw: Tween = create_tween()\ntw.set_ignore_time_scale(duration_clock == \"realtime\")\ntw.tween_method(_set_time_scale, Engine.time_scale, ts, maxf(slowmo_fade_in_secs, 0.0001)).set_trans(_slowmo_trans(slowmo_fade_in_trans)).set_ease(_slowmo_ease(slowmo_fade_in_ease))\ntw.tween_interval(maxf(hold_duration, 0.0))\ntw.tween_method(_set_time_scale, ts, 1.0, maxf(slowmo_fade_out_secs, 0.0001)).set_trans(_slowmo_trans(slowmo_fade_out_trans)).set_ease(_slowmo_ease(slowmo_fade_out_ease))\ntw.finished.connect(func() -> void: slowmo_finished.emit())\n_slowmo_tween = tw")
	_default(sheet, "target_scale", "0.15")
	_default(sheet, "hold_duration", "0.25")
	_default(sheet, "duration_clock", "realtime")
	_param_options(sheet, "duration_clock", ["realtime", "gametime"])
	_quoted_argument(sheet, "slowmo({target_scale}, {hold_duration}, \"{duration_clock}\")")
	Lib.append_function(sheet, "clear_slowmo", "Clear Slowmo", "Juice", "Cancels any slowmo and snaps Engine.time_scale back to 1.0 immediately (call on scene exit if a slowmo might still be running).",
		[],
		"if _slowmo_tween != null:\n\t_slowmo_tween.kill()\n\t_slowmo_tween = null\nEngine.time_scale = 1.0")
	Lib.append_function(sheet, "hitstop", "Hitstop", "Juice", "The punchy hit-pause you feel on a connecting blow: freezes Engine.time_scale (0 = full stop) for a few frames, then snaps back to what it was. Uses a realtime timer so it un-freezes even at a full stop, ignores repeat hits already mid-freeze, pauses any active Slowmo for the duration, and emits On Hitstop Finished. Fire it the instant a hit lands.",
		[["freeze_duration", "float"], ["freeze_scale", "float"]],
		"if _hitstop_active:\n\treturn\n_hitstop_active = true\n_hitstop_prev_scale = Engine.time_scale\nif _slowmo_tween != null and is_instance_valid(_slowmo_tween) and _slowmo_tween.is_running():\n\t_slowmo_tween.pause()\nEngine.time_scale = maxf(freeze_scale, 0.0)\nawait get_tree().create_timer(maxf(freeze_duration, 0.0), true, false, true).timeout\nif not _hitstop_active:\n\treturn\n_hitstop_active = false\nEngine.time_scale = _hitstop_prev_scale\nif _slowmo_tween != null and is_instance_valid(_slowmo_tween):\n\t_slowmo_tween.play()\nhitstop_finished.emit()")
	_default(sheet, "freeze_duration", "0.06")
	_default(sheet, "freeze_scale", "0.0")

	# ── Flash & blink ──
	Lib.append_function(sheet, "flash", "Flash", "Juice", "Pops the host to a solid color, then fades back to how it looked (tints included) - THE damage-hit read. Fire with Hitstop + Shake for a complete hit-confirm. Emits On Flash Finished.",
		[["color", "Color"], ["seconds", "float"]],
		"var flash_item: CanvasItem = host as CanvasItem\nif flash_item == null:\n\treturn\nif _flash_tween != null and _flash_tween.is_valid():\n\t_flash_tween.kill()\nelse:\n\t_flash_restore = flash_item.modulate\nflash_item.modulate = Color(color.r, color.g, color.b, _flash_restore.a)\nvar tw: Tween = create_tween()\ntw.tween_property(flash_item, \"modulate\", _flash_restore, maxf(seconds, 0.01)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)\ntw.finished.connect(func() -> void: flash_finished.emit())\n_flash_tween = tw")
	_default(sheet, "color", "Color.WHITE")
	_default(sheet, "seconds", "0.12")
	Lib.append_function(sheet, "start_blinking", "Start Blinking", "Juice", "Strobes the host's opacity (full / faint) - the invulnerability-frames look, a low-health warning, an interactable highlight. Runs until Stop Blinking.",
		[["times_per_second", "float"], ["min_alpha", "float"]],
		"if host is CanvasItem and not _blink_active:\n\t_blink_base_alpha = (host as CanvasItem).modulate.a\n_blink_rate = maxf(times_per_second, 0.1)\n_blink_min_alpha = clampf(min_alpha, 0.0, 1.0)\n_blink_time = 0.0\n_blink_active = true\nset_process(true)")
	_default(sheet, "times_per_second", "8")
	_default(sheet, "min_alpha", "0.15")
	Lib.append_function(sheet, "stop_blinking", "Stop Blinking", "Juice", "Stops the blink and restores the host's opacity.",
		[],
		"_blink_active = false\nif host is CanvasItem:\n\tvar restored: Color = (host as CanvasItem).modulate\n\trestored.a = _blink_base_alpha\n\t(host as CanvasItem).modulate = restored")

	# ── Punch transforms (kick out, spring back) ──
	Lib.append_function(sheet, "punch_scale", "Punch Scale", "Juice", "Kicks the host's scale up (or down, negative) and springs it back elastically - button pops, pickups, flinches, beat pulses. Composes with Flash + Hitstop for melee hits. Emits On Punch Finished.",
		[["strength", "float"], ["duration", "float"]],
		"if host == null:\n\treturn\n_apply_host_scale(_base_scale * (1.0 + clampf(strength, -0.9, 5.0)))\nvar tw: Tween = create_tween()\ntw.tween_property(host, \"scale\", _base_scale, maxf(duration, 0.001)).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)\ntw.finished.connect(func() -> void: punch_finished.emit())")
	_default(sheet, "strength", "0.25")
	_default(sheet, "duration", "0.35")
	Lib.append_function(sheet, "punch_rotation", "Punch Rotation", "Juice", "Kicks the host's rotation by an angle (degrees) and springs it back elastically - wobbling signs, chest-opening jolts, portrait reactions. Emits On Punch Finished.",
		[["degrees", "float"], ["duration", "float"]],
		"if not (host is CanvasItem):\n\treturn\nif host is Control:\n\t(host as Control).pivot_offset = (host as Control).size / 2.0\nif _punch_rot_tween != null and _punch_rot_tween.is_valid():\n\t_punch_rot_tween.kill()\nelse:\n\t_punch_rot_rest = (host as CanvasItem).rotation\n(host as CanvasItem).rotation = _punch_rot_rest + deg_to_rad(degrees)\nvar tw: Tween = create_tween()\ntw.tween_property(host, \"rotation\", _punch_rot_rest, maxf(duration, 0.001)).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)\ntw.finished.connect(func() -> void: punch_finished.emit())\n_punch_rot_tween = tw")
	_default(sheet, "degrees", "8")
	_default(sheet, "duration", "0.35")
	Lib.append_function(sheet, "punch_position", "Punch Position", "Juice", "Kicks the host's position by an offset (pixels) and springs it back elastically - knockback reads, UI nudges, impact shoves away from an attacker. Emits On Punch Finished.",
		[["offset", "Vector2"], ["duration", "float"]],
		"if not (host is Node2D or host is Control):\n\treturn\nif _punch_pos_tween != null and _punch_pos_tween.is_valid():\n\t_punch_pos_tween.kill()\nelse:\n\t_punch_pos_rest = host.position\nhost.position = _punch_pos_rest + offset\nvar tw: Tween = create_tween()\ntw.tween_property(host, \"position\", _punch_pos_rest, maxf(duration, 0.001)).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)\ntw.finished.connect(func() -> void: punch_finished.emit())\n_punch_pos_tween = tw")
	_default(sheet, "offset", "Vector2(6, 0)")
	_default(sheet, "duration", "0.35")

	# ── Directional camera kick from a world point ──
	Lib.append_function(sheet, "kick_away_from", "Kick Camera Away From Point", "Juice", "Kicks the camera AWAY from a world position (an explosion, a hit source) and springs back - Recoil's directional sibling when you know the cause's location, so the kick always reads as pushback. Composes with Shake.",
		[["world_position", "Vector2"], ["strength", "float"]],
		"var cam: Camera2D = _camera()\nif cam == null:\n\treturn\nvar away: Vector2 = cam.get_screen_center_position() - world_position\naway = away.normalized() if away.length() > 0.001 else Vector2.UP\n_recoil_vec += away * strength\nset_process(true)")
	_default(sheet, "strength", "14")

	# ── Ghost trail ──
	Lib.append_function(sheet, "start_ghost_trail", "Start Ghost Trail", "Juice", "Starts stamping fading afterimages of the host's sprite behind it - dashes, teleports, speed power-ups, bullet-time evades. Works on a Sprite2D/AnimatedSprite2D host or the host's first Sprite2D child. Runs until Stop Ghost Trail.",
		[["stamps_per_second", "float"], ["fade_seconds", "float"], ["tint", "Color"]],
		"_ghost_sprite = _resolve_ghost_sprite()\n_trail_interval = 1.0 / maxf(stamps_per_second, 0.1)\n_trail_fade = maxf(fade_seconds, 0.05)\n_trail_tint = tint\n_trail_timer = 0.0\n_trail_active = true\nset_process(true)")
	_default(sheet, "stamps_per_second", "20")
	_default(sheet, "fade_seconds", "0.4")
	_default(sheet, "tint", "Color(1, 1, 1, 0.6)")
	Lib.append_function(sheet, "stop_ghost_trail", "Stop Ghost Trail", "Juice", "Stops stamping afterimages (the ones already out finish fading on their own).",
		[],
		"_trail_active = false")

	# ── Screen FX (one bundled shader: vignette + chromatic aberration + speed lines) ──
	Lib.append_function(sheet, "pulse_vignette", "Pulse Vignette", "Juice", "Darkens the screen edges to a color at a strength (0..1), then fades back out - taking damage, a near miss, holding your breath. Composes with Slowmo + Fade Screen Tint for last-stand moments.",
		[["strength", "float"], ["color", "Color"], ["seconds", "float"]],
		Lib.JUICE_PULSE_VIGNETTE_BODY)
	_default(sheet, "strength", "0.6")
	_default(sheet, "color", "Color(0.4, 0, 0)")
	_default(sheet, "seconds", "0.5")
	Lib.append_function(sheet, "chromatic_kick", "Chromatic Kick", "Juice", "Splits the screen's color channels for an instant and settles back - the AAA impact frame. Fire with Shake + Hitstop on explosions and heavy hits.",
		[["strength", "float"], ["seconds", "float"]],
		Lib.JUICE_CHROMATIC_KICK_BODY)
	_default(sheet, "strength", "0.5")
	_default(sheet, "seconds", "0.25")
	Lib.append_function(sheet, "chromatic_shake", "Chromatic Shake", "Juice", "Shakes the screen's color channels apart along a direction that moves - the Shake you feel, on the screen instead of the camera. Magnitude is how far they split in pixels, and a reducing shake falls to nothing over the duration while a constant one holds and then stops dead. Leave the angle below zero and the split wanders with the same noise the camera shake uses (so the two read as one hit); give it an angle and the split stays on that line and only breathes. Firing again restarts it. Slow motion glides it, a hitstop freezes it.",
		[["magnitude", "float"], ["duration", "float"], ["mode", "String"], ["angle_degrees", "float"]],
		Lib.JUICE_CHROMATIC_SHAKE_BODY,
		"Chromatic shake [b]{magnitude}[/b] px for [b]{duration}[/b] s")
	_default(sheet, "magnitude", "12")
	_default(sheet, "duration", "0.3")
	_default(sheet, "mode", "reducing")
	_param_options(sheet, "mode", ["reducing", "constant"])
	_default(sheet, "angle_degrees", "-1")
	_quoted_argument(sheet, "chromatic_shake({magnitude}, {duration}, \"{mode}\", {angle_degrees})")
	Lib.append_function(sheet, "stop_chromatic_shake", "Stop Chromatic Shake", "Juice", "Takes the chromatic shake off the screen at once - the way out of a constant one, and the way to end a reducing one early (a hit interrupted by a cutscene). The overlay hides itself unless a vignette, a kick or speed lines are still on it.",
		[],
		Lib.JUICE_STOP_CHROMATIC_SHAKE_BODY)
	Lib.append_function(sheet, "set_speed_lines", "Set Speed Lines", "Juice", "Radial anime-style speed streaks at an intensity (0..1) that HOLD until you set 0 - sprints, dashes, adrenaline modes. Pair with Zoom By Percent or FOV punches for full sprint feel.",
		[["intensity", "float"]],
		Lib.JUICE_SET_SPEED_LINES_BODY)
	_default(sheet, "intensity", "0.5")

	# ── Audio juice ──
	Lib.append_function(sheet, "play_sound_varied", "Play Sound Varied", "Juice", "Plays a sound with a random pitch and volume wobble around the base - the #1 trick against repetitive footsteps, hits, coins, and clicks. Fire-and-forget (the player frees itself).",
		[["path", "String"], ["pitch_jitter", "float"], ["volume_jitter_db", "float"]],
		Lib.JUICE_PLAY_SOUND_VARIED_BODY)
	_default(sheet, "path", "res://sfx/hit.ogg")
	_default(sheet, "pitch_jitter", "0.08")
	_default(sheet, "volume_jitter_db", "2")
	Lib.append_function(sheet, "play_sound_intensity", "Play Sound With Intensity", "Juice", "Plays a sound scaled by an intensity (0..1): quiet + lower-pitched when light, full + brighter when heavy - drive it, Shake, and Punch Scale from ONE hit-power value so light and heavy hits differ by one number.",
		[["path", "String"], ["intensity", "float"]],
		Lib.JUICE_PLAY_SOUND_INTENSITY_BODY)
	_default(sheet, "path", "res://sfx/hit.ogg")
	_default(sheet, "intensity", "0.5")

	# ── Eased tickers (score roll-ups) ──
	Lib.append_function(sheet, "count_to", "Count To", "Juice", "Eases a named display value toward a target over a duration - scores and gold ROLL instead of snapping. Read it with the Ticker Value expression; emits On Ticker Finished (with the name) when it lands.",
		[["ticker_name", "String"], ["target", "float"], ["duration", "float"]],
		Lib.JUICE_COUNT_TO_BODY)
	_default(sheet, "ticker_name", "score")
	_default(sheet, "target", "100")
	_default(sheet, "duration", "0.6")
	Lib.append_function(sheet, "set_ticker", "Set Ticker", "Juice", "Sets a named display value INSTANTLY (cancelling any roll) - initialise a score at 0, or snap on a reset.",
		[["ticker_name", "String"], ["value", "float"]],
		Lib.JUICE_SET_TICKER_BODY)
	_default(sheet, "ticker_name", "score")
	_default(sheet, "value", "0")

	# ── Moments (one row for a whole beat of feedback) ──
	Lib.append_function(sheet, "moment", "Moment", "Juice", "Plays a moment - a whole beat of feedback written down as a file: a hit's shake and freeze and flash, a win's swell, danger draining the colour out. The strength scales every amount in it, so a light hit and a heavy one are one moment at two numbers. Six starters ship beside the pack (impact, kill, triumph, danger, calm, cut); edit them, or name your own with Define Moment.",
		[["moment_name", "String"], ["strength", "float"]],
		"if _play_moment_block(moment_name, strength):\n\treturn\nvar played: Resource = _moment_named(moment_name)\nif played == null:\n\tpush_warning(\"Moment: nothing is called \\\"%s\\\" - define it with Define Moment, or put a moment file of that name in %s.\" % [moment_name, MOMENT_DIRECTORY])\n\treturn\n_moment_walk(_moment_key(moment_name), _moment_steps(played), strength, false)",
		"Moment [b]{moment_name}[/b] at [b]{strength}[/b]")
	_default(sheet, "moment_name", "impact")
	_param_desc(sheet, "moment_name", "Which moment to play. The six that ship are impact, kill, triumph, danger, calm and cut; Define Moment adds your own.")
	_default(sheet, "strength", "1")
	_param_desc(sheet, "strength", "Scales every amount in the moment. 1 is the moment as written, 0.5 a lighter version of the same beat.")
	Lib.append_function(sheet, "define_moment", "Define Moment", "Juice", "Points a name at a moment file, for the whole game: every Juice node's Moment row finds it afterwards. Use it to play a moment you keep somewhere else in the project, or to swap which file a name means (a boss fight that hits harder). An empty slot takes the name away again.",
		[["moment_name", "String"], ["moment", "Resource"]],
		"var word: String = moment_name.strip_edges().to_lower()\nif word.is_empty():\n\treturn\nif moment == null:\n\t_moments.erase(word)\n\treturn\n_moments[word] = moment",
		"Define moment [b]{moment_name}[/b] as [b]{moment}[/b]")
	_default(sheet, "moment_name", "impact")
	_param_desc(sheet, "moment_name", "The name every Moment row will use for this file afterwards.")
	_param_hint(sheet, "moment", "resource_path")
	_param_desc(sheet, "moment", "The moment file. Pick one with the browse button, or leave it empty to take the name away again.")
	_default(sheet, "moment", "preload(\"res://eventsheet_addons/juice/impact.tres\")")
	Lib.append_function(sheet, "play_moment_at", "Play Moment At", "Juice", "Plays a moment WHERE it happened, so a far explosion is felt less than a near one. The strength falls off between that place and the edge of the range, and a moment that happened outside the range does not play at all. Leave the range at 0 and it plays everywhere at full strength, exactly as Moment does. Whatever is left is scaled by Set Moment Strength before anything is felt.",
		[["moment_name", "String"], ["strength", "float"], ["from", "Node"], ["within", "float"], ["falloff", "String"]],
		"var here: float = MomentRunner.strength_at(host, strength * _moment_strength, from, within, falloff)
if here <= 0.0:
	return
moment(moment_name, here)",
		"Moment [b]{moment_name}[/b] at [b]{strength}[/b] from [i]{from}[/i] within [b]{within}[/b]")
	_default(sheet, "moment_name", "impact")
	_param_desc(sheet, "moment_name", "Which moment to play - the same name Moment takes.")
	_default(sheet, "strength", "1")
	_param_desc(sheet, "strength", "The strength before the distance is paid for. 1 is the moment as written.")
	_param_desc(sheet, "from", "Where it happened: the node the moment belongs to. Empty means everywhere, at full strength.")
	_default(sheet, "within", "600")
	_param_desc(sheet, "within", "How far the moment reaches, in the same units the game measures in. 0 = everywhere.")
	_param_options(sheet, "falloff", ["linear", "smooth", "none"])
	_default(sheet, "falloff", "linear")
	_param_desc(sheet, "falloff", "How the strength fades across the range: linear is a straight line, smooth rounds the shoulders, none holds full strength right up to the edge.")
	_quoted_argument(sheet, "play_moment_at({moment_name}, {strength}, {from}, {within}, \"{falloff}\")")
	Lib.append_function(sheet, "set_moment_strength", "Set Moment Strength", "Juice", "Turns every moment this node plays up or down by one number - a quiet scene at 0.4, a boss fight at 1.5, an accessibility setting at whatever the player chose. It scales what Play Moment At feels; the moments themselves are untouched.",
		[["value", "float"]],
		"_moment_strength = maxf(value, 0.0)",
		"Set moment strength to [b]{value}[/b]")
	_default(sheet, "value", "1")
	_param_desc(sheet, "value", "1 is the moments as written, 0.5 half as much of everything, 0 nothing felt at all.")
	Lib.number(sheet, "moment_strength", "Moment Strength", "Juice", "The number every moment this node plays is scaled by - what Set Moment Strength last wrote, and 1 until it has been written.",
		[], "return _moment_strength", TYPE_FLOAT)
	Lib.append_function(sheet, "moment_step", "Moment Step", "Juice", "Plays ONE step of a moment - a shake, a hitstop, a flash - with no file behind it. It is the same step a moment file holds, played by the same code, so a beat written as rows and a beat kept as a file do exactly the same thing. Use it to write a beat straight into a sheet, or as the step of a Moment block. The strength scales the amounts a player sees, exactly as it does inside a moment.",
		[["verb", "String"], ["amount", "float"], ["effect", "String"], ["seconds", "float"], ["strength", "float"]],
		"_play_moment_step({\"verb\": verb, \"amount\": amount, \"effect\": effect, \"seconds\": seconds}, strength)",
		"Moment step [b]{verb}[/b] at [b]{amount}[/b] for [b]{seconds}[/b] s")
	_param_options(sheet, "verb", ["shake", "hitstop", "slowmo", "flash", "punch", "zoom", "shockwave", "chromatic", "pulse", "hold"])
	_default(sheet, "verb", "shake")
	_param_desc(sheet, "verb", "What this step does - the same ten words a moment file's steps are made of.")
	_default(sheet, "amount", "0.4")
	_param_desc(sheet, "amount", "How much of it: a shake's amplitude, a flash's distance towards the colour, a zoom's percentage, and for a hitstop how hard the freeze is between 0 and 1.")
	_param_desc(sheet, "effect", "The extra word two steps need: the colour a flash goes to, and the name of the post effect a pulse or a hold reaches for. Leave it empty for the rest.")
	_default(sheet, "seconds", "0")
	_param_desc(sheet, "seconds", "How long it lasts. 0 lets the step use its own natural length.")
	_default(sheet, "strength", "1")
	_param_desc(sheet, "strength", "Scales what a player sees, exactly as a moment's own strength does. 1 is the step as written.")
	_quoted_argument(sheet, "moment_step(\"{verb}\", {amount}, \"{effect}\", {seconds}, {strength})")

	# ── A beat played the other way, turned around, jumped to the end, or put back ──
	Lib.append_function(sheet, "moment_backwards", "Play Moment Backwards", "Juice", "Plays a moment from its LAST step to its first. A hover-out is the hover-in read the other way, a door closing is the door opening backwards, and neither needs a second moment kept in step with the first by hand. Every step is played either way - a beat in reverse is still the whole beat - and the amounts are scaled and held to the no-flashing ceiling exactly as they are forwards.",
		[["moment_name", "String"], ["strength", "float"]],
		"var written: String = _moment_block_method(moment_name, \"_backwards\")\nif not written.is_empty():\n\thost.call(written, strength, null)\n\treturn\nvar played: Resource = _moment_named(moment_name)\nif played == null:\n\tpush_warning(\"Moment: nothing is called \\\"%s\\\" - define it with Define Moment, or put a moment file of that name in %s.\" % [moment_name, MOMENT_DIRECTORY])\n\treturn\n_moment_walk(_moment_key(moment_name), _moment_steps(played), strength, true)",
		"Play moment [b]{moment_name}[/b] backwards at [b]{strength}[/b]")
	_default(sheet, "moment_name", "hover")
	_param_desc(sheet, "moment_name", "Which moment to play in reverse - the same name Moment takes.")
	_default(sheet, "strength", "1")
	_param_desc(sheet, "strength", "Scales every amount in the moment, exactly as playing it forwards does.")
	Lib.append_function(sheet, "moment_revert", "Revert Moment", "Juice", "Turns a moment that is still playing around from WHERE IT IS: every value its steps wrote walks home to what it was when the beat began, over the beat's own length, and the steps that cannot be undone - a shake already felt, a hitstop already let go - are stepped over rather than fired again. This is the hover-out that does not have to know how far the hover-in got.",
		[["moment_name", "String"]],
		"var key: String = _moment_key(moment_name)\nif not _moment_plays.has(key):\n\treturn\nvar play: Dictionary = _moment_plays[key]\nvar from: Dictionary = {}\nfor touched: String in (play[\"start\"] as Dictionary).keys():\n\tvar now: Variant = _moment_value_of(touched)\n\tif now != null:\n\t\tfrom[touched] = now\nplay[\"from\"] = from\nplay[\"reverting\"] = true\nplay[\"revert_span\"] = maxf(float(play[\"span\"]), 0.001)\nplay[\"revert_left\"] = float(play[\"revert_span\"])\nfor at: int in MomentRunner.revert_order(play[\"steps\"]):\n\tvar step: Variant = (play[\"steps\"] as Array)[at]\n\tif step is Dictionary:\n\t\t_moment_stepping(key, MomentRunner.step_label(step as Dictionary, at))\nset_process(true)",
		"Revert moment [b]{moment_name}[/b]")
	_default(sheet, "moment_name", "hover")
	_param_desc(sheet, "moment_name", "Which moment to turn around. A moment that is not playing is left alone.")
	Lib.append_function(sheet, "moment_skip_to_end", "Skip Moment To End", "Juice", "Ends a moment NOW, on the values it would have finished on: a held effect lands at its full strength, a freeze lets time go, a shake settles. The way out of an intro somebody has seen twenty times, and the way a cutscene skip leaves nothing half-played. It fires On Moment Skipped, then On Moment Finished with Moment Was Cut Short true.",
		[["moment_name", "String"]],
		"var key: String = _moment_key(moment_name)\nif not _moment_plays.has(key):\n\treturn\nvar play: Dictionary = _moment_plays[key]\nvar ends: Dictionary = play[\"end\"]\nfor touched: String in ends.keys():\n\t_moment_write_value(touched, ends[touched])\nfor step: Variant in (play[\"steps\"] as Array):\n\tif step is Dictionary and str((step as Dictionary).get(\"verb\", \"\")).strip_edges().to_lower() == \"shake\":\n\t\tstop_shake()\n\t\tbreak\nmoment_skipped.emit(key)\n_moment_end(key, true)",
		"Skip moment [b]{moment_name}[/b] to the end")
	_default(sheet, "moment_name", "intro")
	_param_desc(sheet, "moment_name", "Which moment to jump to the end of. A moment that is not playing is left alone.")
	Lib.append_function(sheet, "moment_restore_values", "Restore Moment Values", "Juice", "Puts back every value a moment moved, to what it was the first time that moment touched it - the tint, the scale, the zoom, the time scale, the effects held on the screen. Leave the name empty and every moment this node has played is put back, which is what a scene wants on the way out. It plays nothing and undoes nothing that was not a moment's doing.",
		[["moment_name", "String"]],
		"var key: String = _moment_key(moment_name)\nif key.is_empty():\n\tfor named: Variant in _moment_ledger.keys():\n\t\t_moment_put_back(str(named))\n\treturn\n_moment_put_back(key)",
		"Restore what moment [b]{moment_name}[/b] changed")
	_param_desc(sheet, "moment_name", "Which moment's values to put back. Leave it empty for every moment this node has played.")
	Lib.condition(sheet, "moment_is_playing", "Moment Is Playing", "Juice", "True while a moment is still in the air on this node - between its first step and the end of its longest one. Leave the name empty to ask about any moment at all.",
		[["moment_name", "String"]],
		"var key: String = _moment_key(moment_name)\nif key.is_empty():\n\treturn not _moment_plays.is_empty()\nreturn _moment_plays.has(key)")
	_param_desc(sheet, "moment_name", "Which moment to ask about. Empty asks whether any moment is playing.")
	Lib.condition(sheet, "moment_is_reverting", "Moment Is Reverting", "Juice", "True while a moment is walking back to where it started, rather than playing forwards - so a hover-in row can refuse to fire again while the hover-out is still on its way home.",
		[["moment_name", "String"]],
		"var key: String = _moment_key(moment_name)\nif key.is_empty():\n\tfor play: Variant in _moment_plays.values():\n\t\tif play is Dictionary and bool((play as Dictionary)[\"reverting\"]):\n\t\t\treturn true\n\treturn false\nif not _moment_plays.has(key):\n\treturn false\nreturn bool((_moment_plays[key] as Dictionary)[\"reverting\"])")
	_param_desc(sheet, "moment_name", "Which moment to ask about. Empty asks whether any moment is reverting.")
	Lib.condition(sheet, "moment_was_cut_short", "Moment Was Cut Short", "Juice", "True when the LAST play of this moment did not run its course - it was skipped to the end, or reverted - and false when it played all the way through. Ask it inside On Moment Finished to tell the beat that landed from the beat somebody walked out of.",
		[["moment_name", "String"]],
		"return bool(_moment_cut.get(_moment_key(moment_name), false))")
	_default(sheet, "moment_name", "intro")
	_param_desc(sheet, "moment_name", "Which moment's last play to ask about.")
	Lib.number(sheet, "moment_progress", "Moment Progress", "Juice", "How far through a moment this node is, from 0 at its first frame to 1 at its last. A moment that is not playing answers 0, and a beat of instant steps is over the moment it begins.",
		[["moment_name", "String"]],
		"var key: String = _moment_key(moment_name)\nif not _moment_plays.has(key):\n\treturn 0.0\nvar play: Dictionary = _moment_plays[key]\nreturn MomentRunner.progress_of(float(play[\"span\"]) - float(play[\"left\"]), float(play[\"span\"]))", TYPE_FLOAT)
	_default(sheet, "moment_name", "intro")
	_param_desc(sheet, "moment_name", "Which moment to measure.")
	Lib.number(sheet, "moment_elapsed", "Moment Elapsed", "Juice", "How many seconds a moment has been playing. A moment that is not playing answers 0. Use it to draw a bar over a long beat, or to hold a row back until a beat is a certain way in.",
		[["moment_name", "String"]],
		"var key: String = _moment_key(moment_name)\nif not _moment_plays.has(key):\n\treturn 0.0\nvar play: Dictionary = _moment_plays[key]\nreturn maxf(float(play[\"span\"]) - float(play[\"left\"]), 0.0)", TYPE_FLOAT)
	_default(sheet, "moment_name", "intro")
	_param_desc(sheet, "moment_name", "Which moment to measure.")
	Lib.number(sheet, "moment_step_name", "Moment Step Name", "Juice", "What the LAST step of a moment was called - its own label when it was given one, else the word it is made of. It is the same name On Moment Step carries, so a debug line and a trigger say the same thing about the same step.",
		[["moment_name", "String"]],
		"var key: String = _moment_key(moment_name)\nif not _moment_plays.has(key):\n\treturn \"\"\nreturn str((_moment_plays[key] as Dictionary)[\"step\"])", TYPE_STRING)
	_default(sheet, "moment_name", "intro")
	_param_desc(sheet, "moment_name", "Which moment to ask about.")

	# ── Channels: a shake said once, and heard by everything listening ──
	Lib.append_function(sheet, "shake_channel", "Shake Channel", "Juice", "Says one shake to a whole CHANNEL: everything listening on it shakes, and nothing else in the game hears a thing. A channel is a GROUP - the same groups the Node dock shows - so a passing truck reaches the props, a hit reaches the HUD panels, and neither side needs a reference to the other. Each listener decides what it shakes: the camera, itself, or the screen.",
		[["channel", "String"], ["magnitude", "float"], ["seconds", "float"]],
		"if not is_inside_tree():\n\treturn\nget_tree().call_group(StringName(channel), \"shake_from_channel\", magnitude, seconds)",
		"Shake channel [b]{channel}[/b] with [b]{magnitude}[/b] for [b]{seconds}[/b] s")
	_default(sheet, "channel", "props")
	_param_desc(sheet, "channel", "Which channel to shake - a group name. Everything listening on it hears this; everything else does not.")
	_default(sheet, "magnitude", "0.5")
	_param_desc(sheet, "magnitude", "How hard: 0 to 1 for a listener shaking the camera, pixels for one shaking itself or the screen.")
	_default(sheet, "seconds", "0.6")
	_param_desc(sheet, "seconds", "How long the shake lasts before it has faded to nothing.")
	Lib.append_function(sheet, "listen_on_channel", "Listen On Channel", "Juice", "Makes this node a LISTENER: whenever that channel is shaken, this node shakes too. The channel is a group, so this row is the group the Node dock shows, joined from the sheet. The second field is what this node shakes, and it is its answer on every channel it listens on - a listener has one way of shaking, and a second row on another channel does not give it a second one.",
		[["channel", "String"], ["shakes", "String"]],
		"add_to_group(StringName(channel), true)\n_channel_shakes = shakes",
		"Listen on channel [b]{channel}[/b] and shake [b]{shakes}[/b]")
	_default(sheet, "channel", "props")
	_param_desc(sheet, "channel", "Which channel to listen on - a group name. Say it once, at the start of the scene.")
	_param_options(sheet, "shakes", ["the camera", "this node", "the screen"])
	_default(sheet, "shakes", "this node")
	_param_desc(sheet, "shakes", "What this node moves when the channel speaks: the camera the player looks through, this node itself, or the screen's colour channels.")
	_quoted_argument(sheet, "listen_on_channel({channel}, \"{shakes}\")")
	Lib.append_function(sheet, "stop_listening_on_channel", "Stop Listening On Channel", "Juice", "Takes this node off a channel: it stops hearing that channel's shakes and settles back to the pose it was found in. Every other channel it listens on is left alone.",
		[["channel", "String"]],
		"if is_in_group(StringName(channel)):\n\tremove_from_group(StringName(channel))\n_channel_put_back()",
		"Stop listening on channel [b]{channel}[/b]")
	_default(sheet, "channel", "props")
	_param_desc(sheet, "channel", "Which channel to stop hearing.")

	# The pack's hero verbs: starred + bold at the top of their picker section.
	Lib.verb_sentences(sheet, {
		"flash": "Flash [b]{color}[/b] for [b]{seconds}[/b] s",
		"hitstop": "Hitstop for [b]{freeze_duration}[/b] s at scale [b]{freeze_scale}[/b]",
		"shake": "Shake at [b]{strength}[/b]",
	})
	Lib.feature_verbs(sheet, ["shake", "hitstop", "flash", "moment"])
	if not Lib.save_pack(sheet, "res://eventsheet_addons/juice/juice_behavior"):
		return false
	# The six starter moments ship beside the pack, because Moment "impact" looks for impact.tres
	# there. They are files a game is meant to OPEN: retune them in the Inspector, duplicate one
	# into a moment of its own, delete the ones it does not want. Nothing in the plugin depends on
	# any of them existing.
	return Lib.ship_files("juice", "res://eventsheet_addons/juice/juice_behavior",
		PackedStringArray(["tres"]))


## Pre-fills the last-appended ACE's parameter default, so the dialog opens with a usable value
## (authoring-time metadata only - defaults never appear in the compiled .gd).
static func _default(sheet: EventSheetResource, param_id: String, value: String) -> void:
	var fn: EventFunction = sheet.functions[sheet.functions.size() - 1]
	for parameter: ACEParam in fn.params:
		if parameter.id == param_id:
			parameter.default_value = value


## The MOMENTS half of the pack: what a moment is made of, where a name is looked up, and the
## one clamp every step goes through. Split out so build() reads as the shape of the pack.
##
## A moment is a FILE - a list of steps, each one a word plus how much and how long - and this is
## the player for it. Nothing here knows the name of any moment: the six that ship beside the pack
## are starters a game edits, duplicates or deletes, and Define Moment points a name at any file.
static func _moment_lines() -> PackedStringArray:
	return PackedStringArray([
		"# --- Moments: one felt beat of the game, played from a file ---",
		"",
		"## Where the starter moments ship: beside the pack itself, so Moment \"impact\" finds impact.tres with",
		"## nothing set up at all. They are ordinary files - retune them in the Inspector, rename them,",
		"## duplicate them, delete them, or leave them where they are and point Define Moment at your own.",
		"const MOMENT_DIRECTORY: String = \"res://eventsheet_addons/juice/\"",
		"",
		"## THE ACCESSIBILITY CEILING, the same one the post stack holds itself to. A player who has asked for",
		"## no flashing gets the SAME moments - the hit still hits, the win still lands - with every amount",
		"## they see held under this and every time held over the floor, so nothing a moment plays can strobe.",
		"## The clamp lives HERE, in the layer that was added, and never inside the verbs this pack shipped",
		"## first: their bytes are a promise.",
		"##",
		"## The two numbers are the moment runner's, beside this file, because a beat written as rows in a",
		"## sheet is held to the same ceiling as one kept in a file and a game that changes its mind about",
		"## the number should change it once. They are still named here so a game reading this pack finds",
		"## them where it always did.",
		"const MOMENT_FLASH_CEILING: float = MomentRunner.FLASH_CEILING",
		"const MOMENT_FLASH_FLOOR_SECONDS: float = MomentRunner.FLASH_FLOOR_SECONDS",
		"",
		"# The Engine meta the whole project keeps that answer in is NO_FLASHING_META, declared once with",
		"# the chromatic shake above and read by both: one meta, one name for it.",
		"",
		"## Every word a step may be, in the order a reader meets them: this pack's own effects first, then",
		"## the two that reach the screen, then the two that drive the post stack.",
		"const MOMENT_VERBS: PackedStringArray = [\"shake\", \"hitstop\", \"slowmo\", \"flash\", \"punch\", \"zoom\",",
		"\t\"shockwave\", \"chromatic\", \"pulse\", \"hold\"]",
		"",
		"## The step words whose amount is an AMPLITUDE - how much of something a player sees, 0 to 1. Only",
		"## these are scaled by the strength on the row and held under the ceiling: a hitstop's freeze scale,",
		"## a slowmo's time scale and a zoom's percentage are numbers of a different kind, and doubling one of",
		"## those would not mean twice as much of anything.",
		"const MOMENT_AMPLITUDE_VERBS: PackedStringArray = [\"shake\", \"flash\", \"punch\", \"shockwave\",",
		"\t\"chromatic\", \"pulse\", \"hold\"]",
		"",
		"## Moments defined by name, shared by every Juice node in the game, because a moment is a fact about",
		"## the game rather than about one object: Define Moment once at startup and every node's Moment row",
		"## finds it. A name nothing was defined under falls through to the file of that name beside the pack.",
		"static var _moments: Dictionary = {}",
		"",
		"## The group the Screen FX layer puts itself in, which is how a moment finds it: one name, spelled",
		"## the same in both packs and joined by that layer as it enters the tree. Asking a group is a",
		"## dictionary read, so a game that has no post stack at all pays nothing to be told so again.",
		"const POST_STACK_GROUP: StringName = &\"screen_fx_post_stack\"",
		"",
		"## The Screen FX layer this game has, once one has been FOUND. Only a found layer is remembered:",
		"## a game whose post stack arrives after the first beat has played - a level that adds its own",
		"## effects, a pause screen built on demand - would otherwise be missed for ever, and every later",
		"## moment would quietly fall back to this pack's own overlay.",
		"var _moment_screen: CanvasLayer = null",
		"",
		"## Whether this behaviour has already said that a step wanted the post stack and this game has none,",
		"## and WHICH SCENE it said it in. Once per scene rather than once per step: a moment that plays on",
		"## every hit would otherwise write the same sentence sixty times a second, which is how a warning",
		"## stops being read at all.",
		"var _moment_told_screen: bool = false",
		"var _moment_told_scene: Node = null",
		"",
		"## The strength every moment this node plays is scaled by, and the one Moment Strength answers.",
		"## Set Moment Strength writes it, and Play Moment At multiplies by it before the distance is paid",
		"## for - so a scene that wants its feel turned down, or a boss fight that wants it turned up, has",
		"## ONE number to set rather than a strength on every row. It starts at 1, which is the moment as",
		"## its file was written.",
		"var _moment_strength: float = 1.0",
		"",
		"## The moment a name stands for: one a row defined, or the starter file of that name beside the pack.",
		"## A name that answers to neither plays nothing and says so.",
		"## @ace_hidden",
		"func _moment_named(called: String) -> Resource:",
		"\tvar word: String = called.strip_edges().to_lower()",
		"\tif word.is_empty():",
		"\t\treturn null",
		"\tif _moments.has(word):",
		"\t\treturn _moments[word] as Resource",
		"\tvar path: String = MOMENT_DIRECTORY + word.replace(\" \", \"_\") + \".tres\"",
		"\tif ResourceLoader.exists(path):",
		"\t\tvar found: Resource = load(path)",
		"\t\t_moments[word] = found",
		"\t\treturn found",
		"\treturn null",
		"",
		"## A moment written as ROWS rather than as a file. A Moment block compiles to one coroutine on the",
		"## host - `func moment_<name>(strength, from)` - so a name the host answers to that way is played by",
		"## the very same rows that play a file, and a game can keep some of its beats in files and write the",
		"## rest down in the sheet without either row knowing the difference.",
		"##",
		"## The beat is STARTED and not waited for, which is what a Moment row has always done: it runs on its",
		"## own clock while the event that fired it carries on. Nothing is handed to the block as a place,",
		"## because a row that has a place of its own has already paid for the distance and paying twice would",
		"## quieten a near hit for being near.",
		"## @ace_hidden",
		"func _play_moment_block(moment_name: String, strength: float) -> bool:",
		"\tvar word: String = moment_name.strip_edges().replace(\" \", \"_\")",
		"\tif host == null or not word.is_valid_identifier():",
		"\t\treturn false",
		"\tvar written: String = \"moment_\" + word",
		"\tif not host.has_method(written):",
		"\t\treturn false",
		"\thost.call(written, strength, null)",
		"\treturn true",
		"",
		"## A moment's steps, whatever it was made of - the moment resource class, or anything else carrying a",
		"## `steps` array of the same shape. Read through `get` so this pack never has to name that class, and",
		"## goes on working in a game that only installed Juice.",
		"## @ace_hidden",
		"func _moment_steps(played: Resource) -> Array:",
		"\tif played == null:",
		"\t\treturn []",
		"\tvar steps: Variant = played.get(\"steps\")",
		"\tif steps is Array:",
		"\t\treturn steps as Array",
		"\treturn []",
		"",
		"## One step of a moment. Every arm is one of this pack's own verbs or one row of the post stack, so a",
		"## moment can do nothing a sheet could not have done by hand - it is those same rows, written down.",
		"## @ace_hidden",
		"func _play_moment_step(step: Dictionary, strength: float) -> void:",
		"\tvar word: String = str(step.get(\"verb\", \"\")).strip_edges().to_lower()",
		"\tvar effect: String = str(step.get(\"effect\", \"\")).strip_edges().to_lower()",
		"\tvar amount: float = float(step.get(\"amount\", 1.0))",
		"\tvar seconds: float = maxf(float(step.get(\"seconds\", 0.0)), 0.0)",
		"	amount = _moment_amount(word, amount, strength)",
		"	seconds = _moment_seconds(word, seconds)",
		"\tvar screen: CanvasLayer = _moment_screen_fx()",
		"\tmatch word:",
		"\t\t\"shake\":",
		"\t\t\tshake(amount)",
		"\t\t\"hitstop\":",
		"\t\t\thitstop(seconds, clampf(amount, 0.0, 1.0))",
		"\t\t\"slowmo\":",
		"\t\t\tslowmo(clampf(amount, 0.0, 1.0), seconds, \"realtime\")",
		"\t\t\"flash\":",
		"\t\t\t# The amount is how far the host goes towards the flash colour, so a light hit tints and",
		"\t\t\t# a heavy one washes out - and the ceiling above means a player who asked for no",
		"\t\t\t# flashing gets the tint rather than the wash.",
		"\t\t\tvar tint: Color = Color.from_string(effect, Color.WHITE)",
		"\t\t\tif host is CanvasItem:",
		"\t\t\t\ttint = (host as CanvasItem).modulate.lerp(tint, clampf(amount, 0.0, 1.0))",
		"\t\t\tflash(tint, maxf(seconds, 0.05))",
		"\t\t\"punch\":",
		"\t\t\tpunch_scale(amount, maxf(seconds, 0.05))",
		"\t\t\"zoom\":",
		"\t\t\tzoom_by_percent(amount, maxf(seconds, 0.05))",
		"\t\t\"shockwave\":",
		"\t\t\tif screen != null:",
		"\t\t\t\tscreen.call(\"shockwave\", _moment_here(), amount)",
		"\t\t\telse:",
		"\t\t\t\t_moment_wants_screen(word)",
		"\t\t\"chromatic\":",
		"\t\t\tif screen != null:",
		"\t\t\t\tscreen.call(\"chromatic_pulse\", amount, maxf(seconds, 0.05))",
		"\t\t\telse:",
		"\t\t\t\tchromatic_kick(amount, maxf(seconds, 0.05))",
		"\t\t\"pulse\":",
		"\t\t\tif screen != null:",
		"\t\t\t\tscreen.call(\"pulse_post_effect\", effect, amount, maxf(seconds, 0.05))",
		"\t\t\telif effect == \"vignette\":",
		"\t\t\t\tpulse_vignette(amount, Color.BLACK, maxf(seconds, 0.05))",
		"\t\t\telse:",
		"\t\t\t\t_moment_wants_screen(word)",
		"\t\t\"hold\":",
		"\t\t\tif screen == null:",
		"\t\t\t\t_moment_wants_screen(word)",
		"\t\t\telse:",
		"\t\t\t\t# An effect the stack is not holding yet is added at nothing first, so the walk has",
		"\t\t\t\t# somewhere to start from; one it already holds keeps its place in the order.",
		"\t\t\t\tif float(screen.call(\"post_strength\", effect)) <= 0.0001:",
		"\t\t\t\t\tscreen.call(\"add_post_effect\", effect, effect, 0.0)",
		"\t\t\t\tscreen.call(\"fade_post_strength\", effect, amount, seconds, 0.0)",
		"\t\t_:",
		"\t\t\tpush_warning(\"Moment: no step word is called \\\"%s\\\" - the words are %s.\" % [",
		"\t\t\t\tword, \", \".join(MOMENT_VERBS)])",
		"",
		"## What one step's amount really becomes: the strength on the row scales the amounts a PLAYER",
		"## SEES, and only those - a hitstop's freeze, a slowmo's time scale and a zoom's percentage are",
		"## numbers of another kind - and the ceiling then holds down what is left. Its own function",
		"## because it is the fact a reader can check without a screen, a camera or a frame.",
		"## @ace_hidden",
		"func _moment_amount(word: String, amount: float, strength: float) -> float:",
		"	if not MOMENT_AMPLITUDE_VERBS.has(word):",
		"		return amount",
		"	return _moment_allowed(amount * maxf(strength, 0.0))",
		"",
		"## And what one step's time really becomes: the floor under the same words, for the same reason.",
		"## @ace_hidden",
		"func _moment_seconds(word: String, seconds: float) -> float:",
		"	if not MOMENT_AMPLITUDE_VERBS.has(word):",
		"		return maxf(seconds, 0.0)",
		"	return _moment_slowed(seconds)",
		"",
		"## Where the moment happened: the object this behaviour is attached to, in world coordinates, so a",
		"## shockwave rides the thing that caused it instead of the middle of the screen.",
		"## @ace_hidden",
		"func _moment_here() -> Vector2:",
		"\tif host is Node2D:",
		"\t\treturn (host as Node2D).global_position",
		"\tif host is Control:",
		"\t\treturn (host as Control).global_position",
		"\treturn Vector2.ZERO",
		"",
		"## The Screen FX layer this game has, or null. THE POINT OF LOOKING is that a moment must not build a",
		"## second full-screen rectangle of its own: a hit that reads the whole screen twice costs twice as",
		"## much and looks wrong wherever the two overlap. A game with no Screen FX layer falls back to this",
		"## pack's own overlay for the two effects it can draw.",
		"##",
		"## ONLY A FOUND LAYER IS KEPT, and a layer that has left the tree is asked for again: a miss costs",
		"## one group lookup, so re-asking on the next beat is cheaper than the mistake of never asking",
		"## again. The layer must be in the group above, which the Screen FX pack's own layer joins as it",
		"## enters the tree - a hand-built post layer joins it in one line to be found the same way.",
		"## @ace_hidden",
		"func _moment_screen_fx() -> CanvasLayer:",
		"\tif _moment_screen != null and is_instance_valid(_moment_screen) and _moment_screen.is_inside_tree():",
		"\t\treturn _moment_screen",
		"\t_moment_screen = null",
		"\tif not is_inside_tree():",
		"\t\treturn null",
		"\tvar found: Node = get_tree().get_first_node_in_group(POST_STACK_GROUP)",
		"\tif found is CanvasLayer and found.has_method(\"pulse_post_effect\"):",
		"\t\t_moment_screen = found as CanvasLayer",
		"\treturn _moment_screen",
		"",
		"## Says, ONCE PER SCENE, that a step asked for the post stack and this game has none. The three",
		"## steps that reach the screen are the only ones that can want it, and without it a shockwave and a",
		"## hold do nothing at all while a pulse draws only its vignette - each of them silently, which is a",
		"## moment that looks broken and says nothing about why. The sentence names the step and the way out.",
		"## @ace_hidden",
		"func _moment_wants_screen(word: String) -> void:",
		"\tif not _first_time_without_a_screen():",
		"\t\treturn",
		"\tpush_warning((\"Moment: the \\\"%s\\\" step needs a post stack and this scene has none - add the \"",
		"\t\t+ \"Screen FX pack's screen_fx.tscn to the scene, or take the step out of the moment.\") % word)",
		"",
		"## Whether this is the FIRST time in this scene that a step has gone without the post stack -",
		"## true once, then false until the scene changes. Its own function so the once-ness is a value",
		"## that can be asked for, rather than a line in a log somebody has to notice.",
		"## @ace_hidden",
		"func _first_time_without_a_screen() -> bool:",
		"\tvar here: Node = null",
		"\tif is_inside_tree():",
		"\t\there = get_tree().current_scene",
		"\tif _moment_told_screen and _moment_told_scene == here:",
		"\t\treturn false",
		"\t_moment_told_screen = true",
		"\t_moment_told_scene = here",
		"\treturn true",
		"",
		"## What a step's amount really becomes: held under the ceiling while no flashing is on. ONE function,",
		"## so no step can be the one that forgot. The effect-strength dial is deliberately NOT applied here -",
		"## whichever layer draws applies it (the camera mixer for a shake, the post stack for the screen),",
		"## and applying it twice over would square it.",
		"##",
		"## The arithmetic is the moment runner's, beside this file - the same call a moment written as",
		"## rows makes - so the ceiling is one number in one place and a beat is held to it whichever of",
		"## its homes it was written in.",
		"## @ace_hidden",
		"func _moment_allowed(amount: float) -> float:",
		"\treturn MomentRunner.scaled(amount, 1.0)",
		"",
		"## And what a step's TIME really becomes: never quicker than the floor while no flashing is on,",
		"## because a small amplitude arriving ten times a second is still a strobe. The same runner",
		"## answers it, for the same reason.",
		"## @ace_hidden",
		"func _moment_slowed(seconds: float) -> float:",
		"\treturn MomentRunner.seconds_of(seconds)",
		"",
		"# --- A moment that talks back: what is in the air, what it wrote down, and how it is ended ---",
		"#",
		"# A beat used to be a list of calls and nothing else: it happened, and the sheet heard nothing.",
		"# These four signals and the little book below are what let a sheet wait for a beat, draw a bar",
		"# over it, turn it around half way through, or put back everything it moved. Nothing here plays",
		"# a step - the steps are still the pack's own verbs, played by the one function above.",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Moment Started\")",
		"signal moment_started(moment_name: String)",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Moment Step\")",
		"signal moment_stepped(moment_name: String, step_label: String)",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Moment Skipped\")",
		"signal moment_skipped(moment_name: String)",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Moment Finished\")",
		"signal moment_finished(moment_name: String, cut_short: bool)",
		"",
		"## Every moment this node has IN THE AIR, by the name it was played under. A play is a small",
		"## dictionary: the steps it was made of, how long it has left, whether it is walking backwards,",
		"## the values it found and the values it will settle on. Empty for a node that has never played",
		"## one, which is what makes the tick free until a beat starts.",
		"var _moment_plays: Dictionary = {}",
		"",
		"## What every moment this node has played found its values at, the FIRST time it touched each",
		"## one. It outlives the play on purpose: Restore Moment Values is asked on the way out of a",
		"## level, long after the beat that moved something has ended.",
		"var _moment_ledger: Dictionary = {}",
		"",
		"## Whether the LAST play of each name ran its course or was ended early, so a row inside On",
		"## Moment Finished can tell the beat that landed from the beat somebody walked out of.",
		"var _moment_cut: Dictionary = {}",
		"",
		"## The name a play is filed under: the moment's own name, tidied the same way the lookup tidies",
		"## it, so \"Impact\" and \"impact \" are one beat rather than two.",
		"## @ace_hidden",
		"func _moment_key(moment_name: String) -> String:",
		"\treturn moment_name.strip_edges().to_lower()",
		"",
		"## The method on the host a moment written as ROWS compiled to, or an empty string when this",
		"## game wrote that beat as a file instead. The suffix is how a variant is asked for - a block",
		"## that compiled a backwards walk of itself answers to its own name with \"_backwards\" on it.",
		"## @ace_hidden",
		"func _moment_block_method(moment_name: String, suffix: String) -> String:",
		"\tvar word: String = moment_name.strip_edges().replace(\" \", \"_\")",
		"\tif host == null or not word.is_valid_identifier():",
		"\t\treturn \"\"",
		"\tvar written: String = \"moment_\" + word + suffix",
		"\treturn written if host.has_method(written) else \"\"",
		"",
		"## One whole play, forwards or backwards: open the book, take each step in the order the runner",
		"## gives, and then either finish at once or hold the beat open for as long as its longest step.",
		"## ONE function, so Moment and Play Moment Backwards can only differ in the order they walk.",
		"## @ace_hidden",
		"func _moment_walk(key: String, steps: Array, strength: float, backwards: bool) -> void:",
		"\t_moment_begin(key, steps, strength, backwards)",
		"\tfor at: int in MomentRunner.walk_order(steps, backwards):",
		"\t\tvar step: Variant = steps[at]",
		"\t\tif step is Dictionary:",
		"\t\t\t_moment_stepping(key, MomentRunner.step_label(step as Dictionary, at))",
		"\t\t\t_play_moment_step(step as Dictionary, strength)",
		"\t_moment_launched(key)",
		"",
		"## Opens a play: what it is made of, how long it lasts, and - before a single step has run -",
		"## what every value it is about to write was worth. Recording FIRST is the whole of Restore:",
		"## a value read after the beat has touched it is the beat's own doing, not the game's.",
		"## @ace_hidden",
		"func _moment_begin(key: String, steps: Array, strength: float, backwards: bool) -> void:",
		"\tvar play: Dictionary = {",
		"\t\t\"steps\": steps,",
		"\t\t\"strength\": strength,",
		"\t\t\"backwards\": backwards,",
		"\t\t\"span\": MomentRunner.length_of(steps),",
		"\t\t\"left\": MomentRunner.length_of(steps),",
		"\t\t\"step\": \"\",",
		"\t\t\"reverting\": false,",
		"\t\t\"revert_span\": 0.0,",
		"\t\t\"revert_left\": 0.0,",
		"\t\t\"start\": {},",
		"\t\t\"end\": {},",
		"\t\t\"from\": {}",
		"\t}",
		"\t_moment_remember(key, play, steps)",
		"\t_moment_plays[key] = play",
		"\t_moment_cut[key] = false",
		"\tmoment_started.emit(key)",
		"",
		"## The book a Restore reads from: for every value this beat will write, what it is worth now.",
		"## The play keeps its own copy (that is what a Revert walks home to) and the node keeps the",
		"## FIRST one it ever saw under that name, because a beat played twice must still put back what",
		"## the game had before the first play, not what the first play left behind.",
		"## @ace_hidden",
		"func _moment_remember(key: String, play: Dictionary, steps: Array) -> void:",
		"\tvar start: Dictionary = play[\"start\"]",
		"\tvar ends: Dictionary = play[\"end\"]",
		"\tvar kept: Dictionary = _moment_ledger.get(key, {})",
		"\tfor touched: String in MomentRunner.touched_by_steps(steps):",
		"\t\tvar was: Variant = _moment_value_of(touched)",
		"\t\tif was == null:",
		"\t\t\tcontinue",
		"\t\tstart[touched] = was",
		"\t\tends[touched] = _moment_settled(touched, was, steps)",
		"\t\tif not kept.has(touched):",
		"\t\t\tkept[touched] = was",
		"\t_moment_ledger[key] = kept",
		"",
		"## What one recorded value is worth right now. Every reach a moment has is here and nowhere",
		"## else, so the layer that records a value, the one that walks it home and the one that puts it",
		"## back are reading the same five answers. A value this game has no way to reach - a camera zoom",
		"## with no camera, a post effect with no stack - answers null and is simply not recorded.",
		"## @ace_hidden",
		"func _moment_value_of(key: String) -> Variant:",
		"\tif key == MomentRunner.TOUCH_HOST_TINT:",
		"\t\treturn (host as CanvasItem).modulate if host is CanvasItem else null",
		"\tif key == MomentRunner.TOUCH_HOST_SCALE:",
		"\t\tif host is Node2D:",
		"\t\t\treturn (host as Node2D).scale",
		"\t\tif host is Control:",
		"\t\t\treturn (host as Control).scale",
		"\t\treturn null",
		"\tif key == MomentRunner.TOUCH_TIME_SCALE:",
		"\t\treturn Engine.time_scale",
		"\tif key == MomentRunner.TOUCH_CAMERA_ZOOM:",
		"\t\tvar cam: Camera2D = _camera()",
		"\t\treturn cam.zoom if cam != null else null",
		"\tif key.begins_with(MomentRunner.TOUCH_POST_PREFIX):",
		"\t\tvar screen: CanvasLayer = _moment_screen_fx()",
		"\t\tif screen == null:",
		"\t\t\treturn null",
		"\t\treturn float(screen.call(\"post_strength\", key.substr(MomentRunner.TOUCH_POST_PREFIX.length())))",
		"\treturn null",
		"",
		"## And the way back: one recorded value, written where it came from. The mirror of the reader",
		"## above, arm for arm, and it goes through the pack's own writers where there is one so a",
		"## restored scale lands on the host the same way a squash does.",
		"## @ace_hidden",
		"func _moment_write_value(key: String, value: Variant) -> void:",
		"\tif value == null:",
		"\t\treturn",
		"\tif key == MomentRunner.TOUCH_HOST_TINT:",
		"\t\tif host is CanvasItem:",
		"\t\t\t(host as CanvasItem).modulate = value",
		"\t\treturn",
		"\tif key == MomentRunner.TOUCH_HOST_SCALE:",
		"\t\t_apply_host_scale(value)",
		"\t\treturn",
		"\tif key == MomentRunner.TOUCH_TIME_SCALE:",
		"\t\t_set_time_scale(float(value))",
		"\t\treturn",
		"\tif key == MomentRunner.TOUCH_CAMERA_ZOOM:",
		"\t\tvar cam: Camera2D = _camera()",
		"\t\tif cam != null:",
		"\t\t\tcam.zoom = value",
		"\t\treturn",
		"\tif key.begins_with(MomentRunner.TOUCH_POST_PREFIX):",
		"\t\tvar screen: CanvasLayer = _moment_screen_fx()",
		"\t\tif screen != null:",
		"\t\t\tscreen.call(\"fade_post_strength\", key.substr(MomentRunner.TOUCH_POST_PREFIX.length()), float(value), 0.0, 0.0)",
		"",
		"## What one recorded value will be worth once the beat has run its course - which is where a",
		"## Skip To End lands. Time always ends unfrozen; a held effect ends at the strength the step",
		"## asked for; a zoom ends where the percentage took it; everything else comes back by itself,",
		"## so it ends where it started.",
		"## @ace_hidden",
		"func _moment_settled(key: String, was: Variant, steps: Array) -> Variant:",
		"\tif key == MomentRunner.TOUCH_TIME_SCALE:",
		"\t\treturn 1.0",
		"\tfor step: Variant in steps:",
		"\t\tif not (step is Dictionary):",
		"\t\t\tcontinue",
		"\t\tvar card: Dictionary = step as Dictionary",
		"\t\tvar word: String = str(card.get(\"verb\", \"\")).strip_edges().to_lower()",
		"\t\tif MomentRunner.touched_by(word, str(card.get(\"effect\", \"\"))) != key:",
		"\t\t\tcontinue",
		"\t\tif word == \"hold\":",
		"\t\t\treturn _moment_amount(word, float(card.get(\"amount\", 1.0)), 1.0)",
		"\t\tif word == \"zoom\" and was is Vector2:",
		"\t\t\tvar wanted: Vector2 = (was as Vector2) * (float(card.get(\"amount\", 100.0)) / 100.0)",
		"\t\t\treturn Vector2(clampf(wanted.x, min_zoom, max_zoom), clampf(wanted.y, min_zoom, max_zoom))",
		"\treturn was",
		"",
		"## Says that one step of a play has just been taken, and remembers which - the name Moment Step",
		"## Name answers with and On Moment Step carries.",
		"## @ace_hidden",
		"func _moment_stepping(key: String, label: String) -> void:",
		"\tif not _moment_plays.has(key):",
		"\t\treturn",
		"\t(_moment_plays[key] as Dictionary)[\"step\"] = label",
		"\tmoment_stepped.emit(key, label)",
		"",
		"## The end of the opening frame: a beat whose steps are all instant is already over and says so,",
		"## and one with a length holds the tick open until it has run out.",
		"## @ace_hidden",
		"func _moment_launched(key: String) -> void:",
		"\tif not _moment_plays.has(key):",
		"\t\treturn",
		"\tif float((_moment_plays[key] as Dictionary)[\"span\"]) <= 0.0:",
		"\t\t_moment_end(key, false)",
		"\t\treturn",
		"\tset_process(true)",
		"",
		"## Closes a play and says so, with the one fact a sheet cannot work out for itself: whether the",
		"## beat ran its course or was ended early.",
		"## @ace_hidden",
		"func _moment_end(key: String, cut_short: bool) -> void:",
		"\tif not _moment_plays.has(key):",
		"\t\treturn",
		"\t_moment_plays.erase(key)",
		"\t_moment_cut[key] = cut_short",
		"\tmoment_finished.emit(key, cut_short)",
		"",
		"## Puts back everything one moment moved, and forgets it - so a second Restore of the same name",
		"## does nothing rather than writing a stale value over whatever the game has since done.",
		"## @ace_hidden",
		"func _moment_put_back(key: String) -> void:",
		"\tif not _moment_ledger.has(key):",
		"\t\treturn",
		"\tvar kept: Dictionary = _moment_ledger[key]",
		"\tfor touched: String in kept.keys():",
		"\t\t_moment_write_value(touched, kept[touched])",
		"\t_moment_ledger.erase(key)",
		"",
		"## One frame of every beat in the air. A forward play only has to count down; a reverting one",
		"## walks each value it recorded from where the beat left it back to where the game had it, over",
		"## the beat's own length, which is what makes a revert read as the same path travelled home.",
		"## Keys are copied before the walk because ending a play erases it from the book.",
		"## @ace_hidden",
		"func _moment_tick(delta: float) -> void:",
		"\tif _moment_plays.is_empty():",
		"\t\treturn",
		"\tfor key: Variant in _moment_plays.keys():",
		"\t\tvar named: String = str(key)",
		"\t\tif not _moment_plays.has(named):",
		"\t\t\tcontinue",
		"\t\tvar play: Dictionary = _moment_plays[named]",
		"\t\tif bool(play[\"reverting\"]):",
		"\t\t\tplay[\"revert_left\"] = maxf(float(play[\"revert_left\"]) - delta, 0.0)",
		"\t\t\tvar span: float = maxf(float(play[\"revert_span\"]), 0.0001)",
		"\t\t\tvar walked: float = clampf(1.0 - float(play[\"revert_left\"]) / span, 0.0, 1.0)",
		"\t\t\tvar from: Dictionary = play[\"from\"]",
		"\t\t\tvar start: Dictionary = play[\"start\"]",
		"\t\t\tfor touched: String in from.keys():",
		"\t\t\t\tif start.has(touched):",
		"\t\t\t\t\t_moment_write_value(touched, lerp(from[touched], start[touched], walked))",
		"\t\t\tif float(play[\"revert_left\"]) <= 0.0:",
		"\t\t\t\t_moment_end(named, true)",
		"\t\t\tcontinue",
		"\t\tplay[\"left\"] = maxf(float(play[\"left\"]) - delta, 0.0)",
		"\t\tif float(play[\"left\"]) <= 0.0:",
		"\t\t\t_moment_end(named, false)",
		"",
		"## Whether any beat is still in the air - the one thing the tick's parking check has to ask.",
		"## @ace_hidden",
		"func _moment_busy() -> bool:",
		"\treturn not _moment_plays.is_empty()",
		"",
		"# --- Channels: a shake said once, and heard by everything listening ---",
		"#",
		"# A CHANNEL IS A GROUP. Nothing is invented here: Shake Channel is one call_group, a listener is",
		"# a node in that group, and the Node dock already shows which groups a node is in. That is why a",
		"# quake can reach every prop in a level without a single reference between them, and why a game",
		"# that has never opened this pack's docs can still read what the row does.",
		"",
		"## What a listener moves when its channel speaks. The camera the player looks through, the node",
		"## itself (a HUD panel, a lamp, a sign), or the screen's own colour channels.",
		"const CHANNEL_SHAKE_CAMERA: String = \"the camera\"",
		"const CHANNEL_SHAKE_NODE: String = \"this node\"",
		"const CHANNEL_SHAKE_SCREEN: String = \"the screen\"",
		"",
		"## This listener's answer, for every channel it is in. One answer per node rather than one per",
		"## channel: a lamp that rattles for the quake channel and the truck channel rattles the same way,",
		"## and a node that wants to do two different things is two nodes.",
		"var _channel_shakes: String = CHANNEL_SHAKE_CAMERA",
		"",
		"## The shake a channel last asked this node for: how much, how long it lasts, how much is left,",
		"## and the pose the node was found in so it can be handed back exactly as it was.",
		"var _channel_amount: float = 0.0",
		"var _channel_span: float = 0.0",
		"var _channel_left: float = 0.0",
		"var _channel_rest: Vector2 = Vector2.ZERO",
		"var _channel_driving: bool = false",
		"",
		"## What a broadcast arrives as. call_group reaches this by name, so the method's NAME is the",
		"## contract between a Shake Channel row and every listener - which is why it is spelled out here",
		"## rather than hidden behind a signal nobody could connect to without a reference.",
		"##",
		"## The accessibility dial is applied HERE for the two shakes this node draws itself, and NOT for",
		"## the camera: the camera mixer applies it once already, and applying it twice would square it.",
		"## @ace_hidden",
		"func shake_from_channel(magnitude: float, seconds: float) -> void:",
		"\tif _channel_shakes == CHANNEL_SHAKE_SCREEN:",
		"\t\tchromatic_shake(magnitude * maxf(float(Engine.get_meta(\"effect_strength\", 1.0)), 0.0), seconds, \"reducing\", -1.0)",
		"\t\treturn",
		"\tif _channel_shakes == CHANNEL_SHAKE_CAMERA:",
		"\t\t_channel_amount = maxf(magnitude, 0.0)",
		"\telse:",
		"\t\t_channel_amount = maxf(magnitude, 0.0) * maxf(float(Engine.get_meta(\"effect_strength\", 1.0)), 0.0)",
		"\t_channel_span = maxf(seconds, 0.0001)",
		"\t_channel_left = _channel_span",
		"\tset_process(true)",
		"",
		"## One frame of a channel shake. A camera listener holds the trauma the mixer already reads up",
		"## to what the channel asked for, so the two never draw two shakes over each other; a node",
		"## listener rides the same noise around the pose it was found in. Both fade to nothing over the",
		"## time the broadcast named, and the node is put back the frame it runs out.",
		"## @ace_hidden",
		"func _channel_tick(delta: float) -> void:",
		"\tif _channel_left <= 0.0:",
		"\t\tif _channel_driving:",
		"\t\t\t_channel_put_back()",
		"\t\treturn",
		"\t_channel_left = maxf(_channel_left - delta, 0.0)",
		"\tvar fade: float = clampf(_channel_left / maxf(_channel_span, 0.0001), 0.0, 1.0)",
		"\tif _channel_shakes == CHANNEL_SHAKE_CAMERA:",
		"\t\ttrauma = maxf(trauma, clampf(_channel_amount * fade, 0.0, 1.0))",
		"\t\treturn",
		"\tif host == null:",
		"\t\t_channel_left = 0.0",
		"\t\treturn",
		"\tif _noise == null:",
		"\t\t_noise = FastNoiseLite.new()",
		"\t\t_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH",
		"\t\t_noise.frequency = 1.0",
		"\t\t_noise.seed = randi()",
		"\tif not _channel_driving:",
		"\t\t_channel_driving = true",
		"\t\t_channel_rest = _channel_place()",
		"\tvar t: float = (_channel_span - _channel_left) * shake_frequency",
		"\t_channel_move(_channel_rest + Vector2(_noise.get_noise_2d(t, 300.0), _noise.get_noise_2d(300.0, t)) * _channel_amount * fade)",
		"\tif _channel_left <= 0.0:",
		"\t\t_channel_put_back()",
		"",
		"## Where the node is resting, and where a shaken frame writes it.",
		"## @ace_hidden",
		"func _channel_place() -> Vector2:",
		"\tif host is Node2D:",
		"\t\treturn (host as Node2D).position",
		"\tif host is Control:",
		"\t\treturn (host as Control).position",
		"\treturn Vector2.ZERO",
		"",
		"## @ace_hidden",
		"func _channel_move(to: Vector2) -> void:",
		"\tif host is Node2D:",
		"\t\t(host as Node2D).position = to",
		"\telif host is Control:",
		"\t\t(host as Control).position = to",
		"",
		"## Hands the node back exactly as it was found, and forgets the shake. Called when a shake runs",
		"## out and when a listener leaves the channel, so nothing is ever left displaced.",
		"## @ace_hidden",
		"func _channel_put_back() -> void:",
		"\tif _channel_driving:",
		"\t\t_channel_move(_channel_rest)",
		"\t_channel_driving = false",
		"\t_channel_amount = 0.0",
		"\t_channel_span = 0.0",
		"\t_channel_left = 0.0",
		"",
		"## Whether a channel shake is still costing anything - the second thing the parking check asks.",
		"## @ace_hidden",
		"func _channel_busy() -> bool:",
		"\treturn _channel_left > 0.0 or _channel_driving"
	])


## Sets the dropdown options[] on the last-appended ACE's parameter (append_function only sets id+type),
## so e.g. duration_clock becomes a realtime/gametime picker instead of a free-text field.
static func _param_options(sheet: EventSheetResource, param_id: String, choices: Array) -> void:
	var typed: Array[String] = []
	for choice: Variant in choices:
		typed.append(str(choice))
	var fn: EventFunction = sheet.functions[sheet.functions.size() - 1]
	for parameter: ACEParam in fn.params:
		if parameter.id == param_id:
			parameter.options = typed


## Sets the help text on the last-appended ACE's parameter - the line the params dialog shows under
## the field. It is also what CARRIES the starting value into the shipped pack: the emitter writes a
## parameter's default only on the one-line @ace_param form, and only a parameter that has something
## to say gets that form. So a row whose default matters says what the field is for.
static func _param_desc(sheet: EventSheetResource, param_id: String, help: String) -> void:
	var fn: EventFunction = sheet.functions[sheet.functions.size() - 1]
	for parameter: ACEParam in fn.params:
		if parameter.id == param_id:
			parameter.description = help
			parameter.desc = help


## Sets a UI hint on the last-appended ACE's parameter - what the dialog offers instead of a plain
## text field. "resource_path" is the file picker a moment file is chosen with.
static func _param_hint(sheet: EventSheetResource, param_id: String, hint: String) -> void:
	var fn: EventFunction = sheet.functions[sheet.functions.size() - 1]
	for parameter: ACEParam in fn.params:
		if parameter.id == param_id:
			parameter.hint = hint


## A dropdown key is inserted into the call verbatim, so a String argument picked from a list of words
## has to carry its own quotes in the TEMPLATE - a quoted key does not survive the annotation round
## trip (the emitter wraps it again and the scanner strips one pair back off). The call prefix is the
## pack's own class name, the same one the automatic template uses.
static func _quoted_argument(sheet: EventSheetResource, call: String) -> void:
	var fn: EventFunction = sheet.functions[sheet.functions.size() - 1]
	fn.codegen_template_override = "$%s.%s" % [sheet.custom_class_name, call]
