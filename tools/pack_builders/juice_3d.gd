# Pack builder - juice_3d (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## Camera game-feel for 3D: trauma-based SHAKE, weapon RECOIL (pitch kick + side spread that
## recovers), walking HEAD BOB, continuous JITTER, camera LEAN (roll, for wall rides and peeks),
## and FOV punch/zoom. The camera is AUTO-FOUND (get_viewport().get_camera_3d()) and every effect
## is applied as an ADDITIVE offset that is subtracted again next frame - so it composes with
## whatever owns the camera (the FPS Controller's mouse look, an animation, a cutscene) instead
## of fighting it. Attach anywhere; the verbs mirror the 2D Juice pack.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "Node3D"
	sheet.custom_class_name = "Juice3DBehavior"
	sheet.class_description = "3D camera game feel on the active Camera3D: trauma-based shake, weapon recoil, head bob, jitter, a held lean, and FOV punch/zoom. Every effect is an additive offset that is removed and re-applied around whoever owns the camera, so mouse look and animations keep the real pose and your aim is never touched."
	sheet.addon_category = "Juice 3D"
	sheet.ace_expose_all_mode = "node"
	sheet.addon_tags = PackedStringArray(["camera", "juice", "3d"])
	var about: CommentRow = CommentRow.new()
	about.text = "3D camera game feel: shake, recoil, head bob, jitter, lean, and FOV punch/zoom on the active Camera3D - auto-found, applied as additive offsets so they never fight the controller that owns the camera. Verbs mirror the 2D Juice pack."
	sheet.events.append(about)
	var block: RawCodeRow = RawCodeRow.new()
	block.code = "\n".join(PackedStringArray([
		"# --- Designer knobs (tune the FEEL in the Inspector) ---",
		"## Peak shake rotation, in degrees, at full trauma (pitch/yaw; roll uses a third of it).",
		"@export_range(0.0, 30.0, 0.5) var max_shake_degrees: float = 4.0",
		"## Peak positional shake, in metres, at full trauma (0 = rotation-only shake).",
		"@export_range(0.0, 1.0, 0.01) var max_shake_offset: float = 0.05",
		"## Trauma lost per second - higher means shorter, snappier shakes.",
		"@export_range(0.1, 10.0, 0.1) var shake_decay: float = 1.4",
		"## How fast the shake/jitter noise scrolls (the wobble rate).",
		"@export_range(1.0, 60.0, 1.0) var shake_frequency: float = 25.0",
		"## How fast a Recoil kick re-centres, in degrees per second.",
		"@export_range(1.0, 360.0, 1.0) var recoil_recovery: float = 30.0",
		"## How fast an FOV Punch returns to normal, in degrees per second.",
		"@export_range(5.0, 500.0, 5.0) var fov_recovery: float = 60.0",
		"",
		"# --- Internal state ---",
		"var trauma: float = 0.0",
		"var shake_time: float = 0.0",
		"var _shaking: bool = false",
		"var _noise: FastNoiseLite = null",
		"var _camera_override: Camera3D = null",
		"# The camera the offsets were last applied to - offsets are pulled off it before anything",
		"# else, so a camera switch mid-effect can never corrupt the new camera's pose.",
		"var _last_camera: Camera3D = null",
		"# What we added to the camera last frame (subtracted again at the top of every tick).",
		"var _applied_position: Vector3 = Vector3.ZERO",
		"var _applied_rotation: Vector3 = Vector3.ZERO",
		"var _applied_fov: float = 0.0",
		"var _recoil_pitch: float = 0.0",
		"var _recoil_yaw: float = 0.0",
		"var _bob_active: bool = false",
		"var _bob_time: float = 0.0",
		"var _bob_amplitude: float = 0.06",
		"var _bob_frequency: float = 2.2",
		"var _jitter_active: bool = false",
		"var _jitter_time: float = 0.0",
		"var _jitter_offset: float = 0.02",
		"var _jitter_roll: float = 0.5",
		"var _lean_roll: float = 0.0",
		"var _lean_tween: Tween = null",
		"var _fov_kick: float = 0.0",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Shake Stopped\")",
		"signal shake_stopped()",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Lean Finished\")",
		"signal lean_finished()",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Zoom Finished\")",
		"signal zoom_finished()",
		"",
		"## The camera the effects drive: an explicit override (Use Camera), else the active Camera3D.",
		"func _camera() -> Camera3D:",
		"\tif _camera_override != null and is_instance_valid(_camera_override):",
		"\t\treturn _camera_override",
		"\tvar vp: Viewport = get_viewport()",
		"\tif vp == null:",
		"\t\treturn null",
		"\treturn vp.get_camera_3d()",
		"",
		"## Removes last frame's additive offsets from whichever camera received them, so this frame",
		"## starts from the pose the camera's OWNER (controller/animation) wrote.",
		"func _unapply() -> void:",
		"\tif _last_camera == null or not is_instance_valid(_last_camera):",
		"\t\t_applied_position = Vector3.ZERO",
		"\t\t_applied_rotation = Vector3.ZERO",
		"\t\t_applied_fov = 0.0",
		"\t\treturn",
		"\t_last_camera.position -= _applied_position",
		"\t_last_camera.rotation -= _applied_rotation",
		"\t_last_camera.fov = clampf(_last_camera.fov - _applied_fov, 1.0, 179.0)",
		"\t_applied_position = Vector3.ZERO",
		"\t_applied_rotation = Vector3.ZERO",
		"\t_applied_fov = 0.0",
		"",
		"## @ace_condition",
		"## @ace_name(\"Is Shaking\")",
		"func is_shaking() -> bool:",
		"\treturn trauma > 0.0",
		"",
		"## @ace_expression",
		"## @ace_name(\"Trauma\")",
		"func current_trauma() -> float:",
		"\treturn trauma"
	]))
	sheet.events.append(block)
	var on_ready: EventRow = EventRow.new()
	on_ready.trigger_provider_id = "Core"
	on_ready.trigger_id = "OnReady"
	var ready_body: RawCodeRow = RawCodeRow.new()
	ready_body.code = "\n".join(PackedStringArray([
		"_noise = FastNoiseLite.new()",
		"_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH",
		"_noise.frequency = 1.0",
		"_noise.seed = randi()"
	]))
	on_ready.actions.append(ready_body)
	sheet.events.append(on_ready)
	# Leaving the tree mid-effect must hand the camera back clean.
	var teardown: EventRow = EventRow.new()
	teardown.trigger_provider_id = "Core"
	teardown.trigger_id = "OnTreeExiting"
	var teardown_body: RawCodeRow = RawCodeRow.new()
	teardown_body.code = "_unapply()"
	teardown.actions.append(teardown_body)
	sheet.events.append(teardown)
	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"
	tick.trigger_id = "OnProcess"
	var tick_body: RawCodeRow = RawCodeRow.new()
	tick_body.code = "\n".join(PackedStringArray([
		"# Effect STATE advances camera-or-not (headless-safe); only the apply needs a camera.",
		"if trauma > 0.0:",
		"\ttrauma = maxf(trauma - shake_decay * delta, 0.0)",
		"\tshake_time += delta",
		"\t_shaking = true",
		"if trauma <= 0.0 and _shaking:",
		"\t_shaking = false",
		"\tshake_stopped.emit()",
		"_recoil_pitch = move_toward(_recoil_pitch, 0.0, recoil_recovery * delta)",
		"_recoil_yaw = move_toward(_recoil_yaw, 0.0, recoil_recovery * delta)",
		"_fov_kick = move_toward(_fov_kick, 0.0, fov_recovery * delta)",
		"if _bob_active:",
		"\t_bob_time += delta * _bob_frequency",
		"if _jitter_active:",
		"\t_jitter_time += delta * shake_frequency",
		"# Additive apply: pull last frame's offsets off first, so the pose the controller wrote",
		"# this frame is the base - the effects ride on TOP of mouse look, never against it.",
		"_unapply()",
		"var cam: Camera3D = _camera()",
		"if cam == null:",
		"\treturn",
		"_last_camera = cam",
		"var fx_position: Vector3 = Vector3.ZERO",
		"var fx_rotation: Vector3 = Vector3(deg_to_rad(_recoil_pitch), deg_to_rad(_recoil_yaw), deg_to_rad(_lean_roll))",
		"if trauma > 0.0:",
		"\t# Square the trauma so the shake ramps in perceptually (Squirrel Eiserloh's model).",
		"\tvar amount: float = trauma * trauma",
		"\tvar t: float = shake_time * shake_frequency",
		"\tfx_rotation += Vector3(deg_to_rad(max_shake_degrees) * amount * _noise.get_noise_2d(t, 0.0), deg_to_rad(max_shake_degrees) * amount * _noise.get_noise_2d(0.0, t), deg_to_rad(max_shake_degrees) * amount * _noise.get_noise_2d(t, t) / 3.0)",
		"\tfx_position += Vector3(max_shake_offset * amount * _noise.get_noise_2d(t, 50.0), max_shake_offset * amount * _noise.get_noise_2d(50.0, t), 0.0)",
		"if _jitter_active:",
		"\tfx_position += Vector3(_jitter_offset * _noise.get_noise_2d(_jitter_time, 100.0), _jitter_offset * _noise.get_noise_2d(100.0, _jitter_time), 0.0)",
		"\tfx_rotation.z += deg_to_rad(_jitter_roll) * _noise.get_noise_2d(_jitter_time, 200.0)",
		"if _bob_active:",
		"\t# A walking figure-8: side sway at half rate, one vertical dip per step.",
		"\tfx_position += Vector3(sin(_bob_time * TAU * 0.5) * _bob_amplitude * 0.5, -absf(sin(_bob_time * TAU * 0.5)) * _bob_amplitude, 0.0)",
		"cam.position += fx_position",
		"cam.rotation += fx_rotation",
		"cam.fov = clampf(cam.fov + _fov_kick, 1.0, 179.0)",
		"_applied_position = fx_position",
		"_applied_rotation = fx_rotation",
		"_applied_fov = _fov_kick"
	]))
	tick.actions.append(tick_body)
	sheet.events.append(tick)

	# ── Screen tints (a CanvasLayer wash renders over the 3D view), adjustable strength ──
	var tint_block: RawCodeRow = RawCodeRow.new()
	tint_block.code = "\n".join(PackedStringArray([
		"# The tint overlay: a top CanvasLayer ColorRect built on first use - the screen",
		"# wash for damage reds, poison greens, night blues. Strength IS the opacity.",
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
		"## Washes the WHOLE SCREEN with a color at Strength opacity (0..1) over the 3D view -",
		"## damage red, poison green, night blue. Call again to retune; strength 0 clears.",
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

	# --- Actions (fire-and-forget, mirroring the 2D Juice verbs) ---
	Lib.append_function(sheet, "shake", "Shake", "Juice 3D", "Adds screenshake to the active 3D camera (0 = none, 1 = max). Stacks and decays automatically - fire it on every hit or explosion.",
		[["strength", "float"]],
		"trauma = clampf(trauma + strength, 0.0, 1.0)")
	_default(sheet, "strength", "0.4")
	Lib.append_function(sheet, "stop_shake", "Stop Shake", "Juice 3D", "Cancels any shake immediately (other effects keep running).",
		[],
		"trauma = 0.0\nshake_time = 0.0\n_shaking = false")
	Lib.append_function(sheet, "recoil", "Recoil", "Juice 3D", "Weapon recoil: kicks the view UP by a pitch (degrees) plus a random side spread, then re-centres at the Recoil Recovery rate. Fire on every shot - kicks stack, so sustained fire climbs. Cosmetic (rides on top of mouse look; aim is untouched).",
		[["vertical_kick", "float"], ["horizontal_spread", "float"]],
		"_recoil_pitch += vertical_kick\n_recoil_yaw += randf_range(-horizontal_spread, horizontal_spread)")
	_default(sheet, "vertical_kick", "1.5")
	_default(sheet, "horizontal_spread", "0.5")
	Lib.append_function(sheet, "start_head_bob", "Start Head Bob", "Juice 3D", "Starts a walking head-bob on the camera: a figure-8 (side sway at half rate, one downward dip per step). Amplitude is metres, frequency is steps per second. Call while your character moves; Stop Head Bob when they halt.",
		[["amplitude", "float"], ["frequency", "float"]],
		"_bob_amplitude = amplitude\n_bob_frequency = maxf(frequency, 0.01)\n_bob_active = true")
	_default(sheet, "amplitude", "0.06")
	_default(sheet, "frequency", "2.2")
	Lib.append_function(sheet, "stop_head_bob", "Stop Head Bob", "Juice 3D", "Stops the head bob.",
		[],
		"_bob_active = false")
	Lib.append_function(sheet, "start_jitter", "Start Jitter", "Juice 3D", "Starts a continuous nervous wobble (position in metres + a touch of roll) that runs until Stop Jitter - unlike Shake it never decays. Engines idling, helicopters, low health, fear.",
		[["position_amount", "float"], ["roll_degrees", "float"]],
		"_jitter_offset = position_amount\n_jitter_roll = roll_degrees\n_jitter_active = true")
	_default(sheet, "position_amount", "0.02")
	_default(sheet, "roll_degrees", "0.5")
	Lib.append_function(sheet, "stop_jitter", "Stop Jitter", "Juice 3D", "Stops the jitter wobble.",
		[],
		"_jitter_active = false")
	Lib.append_function(sheet, "lean", "Lean", "Juice 3D", "Eases the camera roll to an angle (degrees) and HOLDS it - lean into a wall ride, peek a corner, bank with a turn. Lean back to 0 to level out. Emits On Lean Finished.",
		[["degrees", "float"], ["duration", "float"]],
		"if _lean_tween != null:\n\t_lean_tween.kill()\nvar tw: Tween = create_tween()\ntw.tween_property(self, \"_lean_roll\", degrees, maxf(duration, 0.001)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)\ntw.finished.connect(func() -> void: lean_finished.emit())\n_lean_tween = tw")
	_default(sheet, "degrees", "10")
	_default(sheet, "duration", "0.25")
	Lib.append_function(sheet, "fov_punch", "FOV Punch", "Juice 3D", "Kicks the field of view wider (positive, a speed boost / dash) or tighter (negative, an impact) by an amount in degrees, then eases back at the FOV Recovery rate. Fire-and-forget.",
		[["amount", "float"]],
		"_fov_kick += amount")
	_default(sheet, "amount", "8")
	Lib.append_function(sheet, "zoom_fov_to", "Zoom FOV To", "Juice 3D", "Smoothly changes the camera's base field of view to a value in degrees and keeps it there (an aim-down-sights zoom is FOV 40, back to 75 to unzoom). Emits On Zoom Finished.",
		[["fov", "float"], ["duration", "float"]],
		"var cam: Camera3D = _camera()\nif cam == null:\n\treturn\nvar tw: Tween = create_tween()\ntw.tween_property(cam, \"fov\", clampf(fov, 1.0, 179.0) + _applied_fov, maxf(duration, 0.001)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)\ntw.finished.connect(func() -> void: zoom_finished.emit())")
	_default(sheet, "fov", "40")
	_default(sheet, "duration", "0.15")
	Lib.append_function(sheet, "use_camera", "Use Camera", "Juice 3D", "Pin the effects to a specific Camera3D (by path). Leave it unused to auto-target whichever camera is active.",
		[["camera_path", "NodePath"]],
		"_unapply()\n_camera_override = get_node_or_null(camera_path) as Camera3D")
	return Lib.save_pack(sheet, "res://eventsheet_addons/juice_3d/juice_3d_behavior")


## Pre-fills the last-appended ACE's parameter default, so the dialog opens with a usable value
## (authoring-time metadata only - defaults never appear in the compiled .gd).
static func _default(sheet: EventSheetResource, param_id: String, value: String) -> void:
	var fn: EventFunction = sheet.functions[sheet.functions.size() - 1]
	for parameter: ACEParam in fn.params:
		if parameter.id == param_id:
			parameter.default_value = value
