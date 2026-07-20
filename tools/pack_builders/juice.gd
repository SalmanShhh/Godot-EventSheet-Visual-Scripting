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
	about.text = "Game feel, batteries included: screenshake, recoil, head bob, jitter, camera tilt, smooth zoom, and squash & stretch. The camera is found automatically - attach this anywhere and call Shake / Recoil / Zoom; all camera effects compose around one rest pose. Squash & Stretch animates the node it's attached to. (3D camera? Use the Juice 3D pack - same verbs on the active Camera3D.)"
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
		"\t_base_scale = (host as Control).scale"
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
		"\t\tcam.offset = _base_offset + fx_offset",
		"\t\tcam.rotation = _base_rotation + fx_roll",
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
		"\t\t_stamp_ghost()"
	]))
	tick_extras.actions.append(tick_extras_body)
	sheet.events.append(tick_extras)

	# --- Actions (fire-and-forget) ---
	Lib.append_function(sheet, "shake", "Shake", "Juice", "Adds screenshake to the active camera (0 = none, 1 = max). Stacks and decays automatically - fire it on every hit.",
		[["strength", "float"]],
		"trauma = clampf(trauma + strength, 0.0, 1.0)")
	_default(sheet, "strength", "0.4")
	Lib.append_function(sheet, "stop_shake", "Stop Shake", "Juice", "Cancels any shake immediately (the camera returns to rest unless another effect - recoil, bob, jitter, tilt - is still holding it).",
		[],
		"trauma = 0.0\nshake_time = 0.0\n_shaking = false\nvar cam: Camera2D = _camera()\nif cam != null and _cam_driving and not (_bob_active or _jitter_active or _recoil_vec != Vector2.ZERO or absf(_tilt_roll) > 0.0001):\n\tcam.offset = _base_offset\n\tcam.rotation = _base_rotation\n\t_cam_driving = false")
	Lib.append_function(sheet, "use_camera", "Use Camera", "Juice", "Pin the effects to a specific Camera2D (by path). Leave it unused to auto-target whichever camera is active.",
		[["camera_path", "NodePath"]],
		"_camera_override = get_node_or_null(camera_path) as Camera2D")
	Lib.append_function(sheet, "recoil", "Recoil", "Juice", "Kicks the camera a distance (pixels) in a direction (degrees: -90 = up, 0 = right) and springs it back at the Recoil Recovery rate. Fire on every shot - kicks stack, so rapid fire climbs. Composes with Shake/Bob/Jitter.",
		[["angle_degrees", "float"], ["strength", "float"]],
		"_recoil_vec += Vector2.from_angle(deg_to_rad(angle_degrees)) * strength")
	_default(sheet, "angle_degrees", "-90")
	_default(sheet, "strength", "12")
	Lib.append_function(sheet, "start_head_bob", "Start Head Bob", "Juice", "Starts a walking head-bob on the camera: a figure-8 sway (side at half rate, one vertical dip per step). Amplitude is pixels, frequency is steps per second. Call while your character moves; Stop Head Bob when they halt.",
		[["amplitude", "float"], ["frequency", "float"]],
		"_bob_amplitude = amplitude\n_bob_frequency = maxf(frequency, 0.01)\n_bob_active = true")
	_default(sheet, "amplitude", "6")
	_default(sheet, "frequency", "2.2")
	Lib.append_function(sheet, "stop_head_bob", "Stop Head Bob", "Juice", "Stops the head bob (the camera returns to rest once every other effect settles too).",
		[],
		"_bob_active = false")
	Lib.append_function(sheet, "start_jitter", "Start Jitter", "Juice", "Starts a continuous nervous wobble on the camera (pixels) that runs until Stop Jitter - unlike Shake it never decays. Great for engines idling, drunk vision, earthquakes building, low-health unease.",
		[["amount", "float"]],
		"_jitter_amount = amount\n_jitter_active = true")
	_default(sheet, "amount", "3")
	Lib.append_function(sheet, "stop_jitter", "Stop Jitter", "Juice", "Stops the jitter wobble.",
		[],
		"_jitter_active = false")
	Lib.append_function(sheet, "tilt_to", "Tilt To", "Juice", "Eases the camera roll to an angle (degrees) and HOLDS it - lean into a drift, a hill, or a dramatic dutch angle. Tilt back to 0 to level out. Emits On Tilt Finished.",
		[["degrees", "float"], ["duration", "float"]],
		"if _tilt_tween != null:\n\t_tilt_tween.kill()\nvar tw: Tween = create_tween()\ntw.tween_property(self, \"_tilt_roll\", degrees, maxf(duration, 0.001)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)\ntw.finished.connect(func() -> void: tilt_finished.emit())\n_tilt_tween = tw")
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
		"if host == null:\n\treturn\nvar s: float = clampf(stretch, -0.9, 5.0)\n_squash_value = Vector2(_base_scale.x / (1.0 + s), _base_scale.y * (1.0 + s))\n_squash_velocity = Vector2.ZERO\n_squash_spring_active = true\n_apply_host_scale(_squash_value)")
	_default(sheet, "stretch", "0.3")
	Lib.append_function(sheet, "slowmo", "Slowmo", "Juice", "Briefly slows Engine.time_scale to the target, HOLDS for a duration, then eases back to normal. Fade curves are Inspector knobs; pick whether the hold counts in realtime or scaled game time. Emits On Slowmo Finished.",
		[["target_scale", "float"], ["hold_duration", "float"], ["duration_clock", "String"]],
		"if _slowmo_tween != null:\n\t_slowmo_tween.kill()\nvar ts: float = clampf(target_scale, 0.0, 1.0)\nvar tw: Tween = create_tween()\ntw.set_ignore_time_scale(duration_clock == \"realtime\")\ntw.tween_method(_set_time_scale, Engine.time_scale, ts, maxf(slowmo_fade_in_secs, 0.0001)).set_trans(_slowmo_trans(slowmo_fade_in_trans)).set_ease(_slowmo_ease(slowmo_fade_in_ease))\ntw.tween_interval(maxf(hold_duration, 0.0))\ntw.tween_method(_set_time_scale, ts, 1.0, maxf(slowmo_fade_out_secs, 0.0001)).set_trans(_slowmo_trans(slowmo_fade_out_trans)).set_ease(_slowmo_ease(slowmo_fade_out_ease))\ntw.finished.connect(func() -> void: slowmo_finished.emit())\n_slowmo_tween = tw")
	_default(sheet, "target_scale", "0.15")
	_default(sheet, "hold_duration", "0.25")
	_default(sheet, "duration_clock", "realtime")
	_param_options(sheet, "duration_clock", ["realtime", "gametime"])
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
		"if host is CanvasItem and not _blink_active:\n\t_blink_base_alpha = (host as CanvasItem).modulate.a\n_blink_rate = maxf(times_per_second, 0.1)\n_blink_min_alpha = clampf(min_alpha, 0.0, 1.0)\n_blink_time = 0.0\n_blink_active = true")
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
		"var cam: Camera2D = _camera()\nif cam == null:\n\treturn\nvar away: Vector2 = cam.get_screen_center_position() - world_position\naway = away.normalized() if away.length() > 0.001 else Vector2.UP\n_recoil_vec += away * strength")
	_default(sheet, "strength", "14")

	# ── Ghost trail ──
	Lib.append_function(sheet, "start_ghost_trail", "Start Ghost Trail", "Juice", "Starts stamping fading afterimages of the host's sprite behind it - dashes, teleports, speed power-ups, bullet-time evades. Works on a Sprite2D/AnimatedSprite2D host or the host's first Sprite2D child. Runs until Stop Ghost Trail.",
		[["stamps_per_second", "float"], ["fade_seconds", "float"], ["tint", "Color"]],
		"_ghost_sprite = _resolve_ghost_sprite()\n_trail_interval = 1.0 / maxf(stamps_per_second, 0.1)\n_trail_fade = maxf(fade_seconds, 0.05)\n_trail_tint = tint\n_trail_timer = 0.0\n_trail_active = true")
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

	# The pack's hero verbs: starred + bold at the top of their picker section.
	Lib.feature_verbs(sheet, ["shake", "hitstop", "flash"])
	return Lib.save_pack(sheet, "res://eventsheet_addons/juice/juice_behavior")


## Pre-fills the last-appended ACE's parameter default, so the dialog opens with a usable value
## (authoring-time metadata only - defaults never appear in the compiled .gd).
static func _default(sheet: EventSheetResource, param_id: String, value: String) -> void:
	var fn: EventFunction = sheet.functions[sheet.functions.size() - 1]
	for parameter: ACEParam in fn.params:
		if parameter.id == param_id:
			parameter.default_value = value


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
