# Pack builder — juice (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")

## Game-feel in one behavior: trauma-based SCREENSHAKE (the idea behind the scroll behavior's
## shake, but additive on the camera's offset/rotation so it composes with Godot's camera follow
## instead of fighting it), smooth ZOOM (by percent, focus-onto-a-point, or anchored mouse-wheel
## style), and volume-preserving SQUASH & STRETCH on the host — which can be a Node2D (sprites) OR a
## Control (UI). The camera is AUTO-FOUND (get_viewport().get_camera_2d()), so Shake / Zoom just work
## from anywhere with no wiring. Every effect is fire-and-forget (Tween-driven) and emits an
## "On X Finished" signal so you can chain the next beat reactively.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	# CanvasItem is the shared base of Node2D and Control, so Squash & Stretch works on sprites AND UI.
	sheet.host_class = "CanvasItem"
	sheet.custom_class_name = "JuiceBehavior"
	sheet.addon_tags = PackedStringArray(["camera", "juice"])
	var about: CommentRow = CommentRow.new()
	about.text = "Game feel, batteries included: screenshake, smooth zoom, and squash & stretch. The camera is found automatically — attach this anywhere and call Shake / Zoom; Squash & Stretch animates the node it's attached to."
	sheet.events.append(about)
	var block: RawCodeRow = RawCodeRow.new()
	block.code = "\n".join(PackedStringArray([
		"# --- Designer knobs (tune the FEEL in the Inspector) ---",
		"## Peak camera shake offset, in pixels, at full trauma.",
		"@export var max_offset: Vector2 = Vector2(24, 16)",
		"## Peak camera roll (rotation) in degrees at full trauma.",
		"@export_range(0.0, 30.0, 0.5) var max_roll_degrees: float = 3.0",
		"## Trauma lost per second — higher means shorter, snappier shakes.",
		"@export_range(0.1, 10.0, 0.1) var shake_decay: float = 1.4",
		"## How fast the shake noise scrolls (the jitter rate).",
		"@export_range(1.0, 60.0, 1.0) var shake_frequency: float = 25.0",
		"## Clamp: the most zoomed-OUT the camera may go (smaller = further out).",
		"@export_range(0.05, 1.0, 0.05) var min_zoom: float = 0.2",
		"## Clamp: the most zoomed-IN the camera may go.",
		"@export_range(1.0, 16.0, 0.5) var max_zoom: float = 5.0",
		"## Slowmo: how the slow-down ramps IN (curve + direction).",
		"@export_enum(\"linear\", \"sine\", \"quad\", \"cubic\", \"expo\", \"circ\", \"back\") var slowmo_fade_in_trans: String = \"sine\"",
		"@export_enum(\"in\", \"out\", \"in_out\", \"out_in\") var slowmo_fade_in_ease: String = \"out\"",
		"## Slowmo: how time ramps back OUT to normal.",
		"@export_enum(\"linear\", \"sine\", \"quad\", \"cubic\", \"expo\", \"circ\", \"back\") var slowmo_fade_out_trans: String = \"sine\"",
		"@export_enum(\"in\", \"out\", \"in_out\", \"out_in\") var slowmo_fade_out_ease: String = \"in\"",
		"## Slowmo: seconds spent fading in / out (the ramp lengths, separate from the HOLD).",
		"@export_range(0.0, 2.0, 0.05) var slowmo_fade_in_secs: float = 0.15",
		"@export_range(0.0, 2.0, 0.05) var slowmo_fade_out_secs: float = 0.35",
		"## Spring Squash: stiffness + damping of the spring-back (lower damping = bouncier).",
		"@export_range(1.0, 1000.0, 1.0) var squash_stiffness: float = 250.0",
		"@export_range(0.0, 1.0, 0.01) var squash_damping: float = 0.6",
		"",
		"# --- Internal state ---",
		"var trauma: float = 0.0",
		"var shake_time: float = 0.0",
		"var _shaking: bool = false",
		"var _base_offset: Vector2 = Vector2.ZERO",
		"var _base_rotation: float = 0.0",
		"var _base_scale: Vector2 = Vector2.ONE",
		"var _noise: FastNoiseLite = null",
		"var _camera_override: Camera2D = null",
		"# Anchored-zoom (Zoom Toward Point) interpolation state.",
		"var _zoom_from: Vector2 = Vector2.ONE",
		"var _zoom_to: Vector2 = Vector2.ONE",
		"var _zoom_anchor: Vector2 = Vector2.ZERO",
		"var _zoom_cam_from: Vector2 = Vector2.ZERO",
		"# Slowmo state (single tween, kill-before-restart).",
		"var _slowmo_tween: Tween = null",
		"# Spring-squash state (per-frame integrator springing the scale back to rest).",
		"var _squash_spring_active: bool = false",
		"var _squash_value: Vector2 = Vector2.ONE",
		"var _squash_velocity: Vector2 = Vector2.ZERO",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Shake Stopped\")",
		"## @ace_category(\"Juice\")",
		"signal shake_stopped()",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Zoom Finished\")",
		"## @ace_category(\"Juice\")",
		"signal zoom_finished()",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Squash Finished\")",
		"## @ace_category(\"Juice\")",
		"signal squash_finished()",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Slowmo Finished\")",
		"## @ace_category(\"Juice\")",
		"signal slowmo_finished()",
		"",
		"## The camera these effects drive: an explicit override (Use Camera), else the active Camera2D —",
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
		"## @ace_category(\"Juice\")",
		"func is_shaking() -> bool:",
		"\treturn trauma > 0.0",
		"",
		"## @ace_expression",
		"## @ace_name(\"Trauma\")",
		"## @ace_category(\"Juice\")",
		"func current_trauma() -> float:",
		"\treturn trauma",
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
	# Safety: if the host leaves the tree mid-slowmo, restore the GLOBAL Engine.time_scale — otherwise a
	# scene change during slow motion would leave the entire game running in slow motion.
	var teardown: EventRow = EventRow.new()
	teardown.trigger_provider_id = "Core"
	teardown.trigger_id = "OnTreeExiting"
	var teardown_body: RawCodeRow = RawCodeRow.new()
	teardown_body.code = "clear_slowmo()"
	teardown.actions.append(teardown_body)
	sheet.events.append(teardown)
	# Per-frame: decay trauma and drive the camera offset/roll from squared trauma (perceptual ramp).
	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"
	tick.trigger_id = "OnProcess"
	var tick_body: RawCodeRow = RawCodeRow.new()
	tick_body.code = "\n".join(PackedStringArray([
		"if trauma > 0.0:",
		"\ttrauma = maxf(trauma - shake_decay * delta, 0.0)",
		"\tvar cam: Camera2D = _camera()",
		"\tif cam != null:",
		"\t\tif not _shaking:",
		"\t\t\t_shaking = true",
		"\t\t\t_base_offset = cam.offset",
		"\t\t\t_base_rotation = cam.rotation",
		"\t\tif trauma > 0.0:",
		"\t\t\tshake_time += delta",
		"\t\t\t# Square the trauma so the shake ramps in perceptually (Squirrel Eiserloh's model).",
		"\t\t\tvar amount: float = trauma * trauma",
		"\t\t\tvar t: float = shake_time * shake_frequency",
		"\t\t\tcam.offset = _base_offset + Vector2(max_offset.x * amount * _noise.get_noise_2d(t, 0.0), max_offset.y * amount * _noise.get_noise_2d(0.0, t))",
		"\t\t\tcam.rotation = _base_rotation + deg_to_rad(max_roll_degrees) * amount * _noise.get_noise_2d(t, t)",
		"\t\telse:",
		"\t\t\t# Settled this frame: restore the camera's resting offset/roll.",
		"\t\t\tcam.offset = _base_offset",
		"\t\t\tcam.rotation = _base_rotation",
		"\tif trauma <= 0.0 and _shaking:",
		"\t\t_shaking = false",
		"\t\tshake_stopped.emit()",
		"if _squash_spring_active:",
		"\t# Spring the scale back to rest (semi-implicit, framerate-independent — same model as the Spring pack).",
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
	# --- Actions (fire-and-forget) ---
	Lib.append_function(sheet, "shake", "Shake", "Juice", "Adds screenshake to the active camera (0 = none, 1 = max). Stacks and decays automatically — fire it on every hit.",
		[["strength", "float"]],
		"trauma = clampf(trauma + strength, 0.0, 1.0)")
	_default(sheet, "strength", "0.4")
	Lib.append_function(sheet, "stop_shake", "Stop Shake", "Juice", "Cancels any shake and restores the camera to rest immediately.",
		[],
		"trauma = 0.0\nshake_time = 0.0\nvar cam: Camera2D = _camera()\nif cam != null and _shaking:\n\tcam.offset = _base_offset\n\tcam.rotation = _base_rotation\n_shaking = false")
	Lib.append_function(sheet, "use_camera", "Use Camera", "Juice", "Pin the effects to a specific Camera2D (by path). Leave it unused to auto-target whichever camera is active.",
		[["camera_path", "NodePath"]],
		"_camera_override = get_node_or_null(camera_path) as Camera2D")
	Lib.append_function(sheet, "zoom_by_percent", "Zoom By Percent", "Juice", "Smoothly zooms the camera (100 = no change, 150 = zoom in 1.5x, 50 = zoom out). Clamped to the min/max zoom knobs.",
		[["percent", "float"], ["duration", "float"]],
		"var cam: Camera2D = _camera()\nif cam == null:\n\treturn\nvar target_zoom: Vector2 = cam.zoom * (percent / 100.0)\ntarget_zoom = Vector2(clampf(target_zoom.x, min_zoom, max_zoom), clampf(target_zoom.y, min_zoom, max_zoom))\nvar tw: Tween = create_tween()\ntw.tween_property(cam, \"zoom\", target_zoom, maxf(duration, 0.001)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)\ntw.finished.connect(func() -> void: zoom_finished.emit())")
	_default(sheet, "percent", "150")
	_default(sheet, "duration", "0.4")
	Lib.append_function(sheet, "zoom_to_position", "Zoom To Position", "Juice", "Zooms in while gliding the camera so a world position becomes the screen CENTRE — frame a spot in one action.",
		[["world_position", "Vector2"], ["percent", "float"], ["duration", "float"]],
		"var cam: Camera2D = _camera()\nif cam == null:\n\treturn\nvar target_zoom: Vector2 = cam.zoom * (percent / 100.0)\ntarget_zoom = Vector2(clampf(target_zoom.x, min_zoom, max_zoom), clampf(target_zoom.y, min_zoom, max_zoom))\nvar seconds: float = maxf(duration, 0.001)\nvar tw: Tween = create_tween().set_parallel(true)\ntw.tween_property(cam, \"zoom\", target_zoom, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)\ntw.tween_property(cam, \"global_position\", world_position, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)\ntw.finished.connect(func() -> void: zoom_finished.emit())")
	_default(sheet, "percent", "150")
	_default(sheet, "duration", "0.4")
	Lib.append_function(sheet, "zoom_toward_point", "Zoom Toward Point", "Juice", "Zooms while keeping a world position pinned under the same screen spot (mouse-wheel-to-cursor style) — great for strategy/map zoom.",
		[["world_position", "Vector2"], ["percent", "float"], ["duration", "float"]],
		"var cam: Camera2D = _camera()\nif cam == null:\n\treturn\n_zoom_cam_from = cam.global_position\n_zoom_from = cam.zoom\nvar target_zoom: Vector2 = cam.zoom * (percent / 100.0)\n_zoom_to = Vector2(clampf(target_zoom.x, min_zoom, max_zoom), clampf(target_zoom.y, min_zoom, max_zoom))\n_zoom_anchor = world_position\nvar tw: Tween = create_tween()\ntw.tween_method(_zoom_anchored_step, 0.0, 1.0, maxf(duration, 0.001)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)\ntw.finished.connect(func() -> void: zoom_finished.emit())")
	_default(sheet, "percent", "150")
	_default(sheet, "duration", "0.4")
	Lib.append_function(sheet, "squash_and_stretch", "Squash & Stretch", "Juice", "Pops the host (Node2D or Control) with a volume-preserving stretch that springs back elastically. Positive = stretch tall (a jump), negative = squash wide (a landing).",
		[["stretch", "float"], ["duration", "float"]],
		"if host == null:\n\treturn\nvar s: float = clampf(stretch, -0.9, 5.0)\nvar stretched: Vector2 = Vector2(_base_scale.x / (1.0 + s), _base_scale.y * (1.0 + s))\nif host is Node2D:\n\t(host as Node2D).scale = stretched\nelif host is Control:\n\tvar c: Control = host as Control\n\t# Control scales from its top-left by default; centre the pivot so the pop reads right.\n\tc.pivot_offset = c.size / 2.0\n\tc.scale = stretched\nelse:\n\treturn\nvar tw: Tween = create_tween()\ntw.tween_property(host, \"scale\", _base_scale, maxf(duration, 0.001)).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)\ntw.finished.connect(func() -> void: squash_finished.emit())")
	_default(sheet, "stretch", "0.3")
	_default(sheet, "duration", "0.4")
	Lib.append_function(sheet, "spring_squash", "Spring Squash", "Juice", "Pops the host (Node2D or Control) with a volume-preserving stretch that springs back via a real spring (the stiffness/damping knobs) — bouncier + more organic than the tween Squash & Stretch. Positive = stretch tall (a jump), negative = squash wide (a landing).",
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
	return Lib.save_pack(sheet, "res://eventsheet_addons/juice/juice_behavior")


## Pre-fills the last-appended ACE's parameter default, so the dialog opens with a usable value
## (authoring-time metadata only — defaults never appear in the compiled .gd).
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
