# Pack builder - platformer (one pack per file; run via tools/build_sample_behaviors.gd).
#
# Rich kinematic platformer for a CharacterBody2D, porting the feel features from the
# author's "Physics Platformer" addon - coyote time, jump buffering, variable jump
# height, multi-jump, wall slide + wall jump, acceleration/deceleration and terminal
# velocity - implemented kinematically (cleaner + more predictable than physics
# integration). The original jump()/set_move_speed()/On Jumped ACEs keep their ids
# (compatibility covenant); everything else is additive.
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "CharacterBody2D"
	sheet.custom_class_name = "PlatformerMovement"
	sheet.addon_tags = PackedStringArray(["movement", "platformer"])
	sheet.variables = {
		# ── Tuning (Inspector) ───────────────────────────────────────────────────────
		"move_speed": {"type": "float", "default": 200.0, "exported": true,
			"attributes": {"tooltip": "Top horizontal run speed (px/s)."}},
		"jump_velocity": {"type": "float", "default": -400.0, "exported": true,
			"attributes": {"tooltip": "Upward velocity of a jump (negative = up)."}},
		"gravity": {"type": "float", "default": 980.0, "exported": true,
			"attributes": {"tooltip": "Downward acceleration (px/s²)."}},
		"acceleration": {"type": "float", "default": 1500.0, "exported": true,
			"attributes": {"tooltip": "How fast you reach top speed when pressing a direction."}},
		"deceleration": {"type": "float", "default": 1800.0, "exported": true,
			"attributes": {"tooltip": "How fast you stop when no direction is pressed."}},
		"max_fall_speed": {"type": "float", "default": 1000.0, "exported": true,
			"attributes": {"tooltip": "Terminal velocity - gravity never pulls you faster than this."}},
		"coyote_time": {"type": "float", "default": 0.1, "exported": true,
			"attributes": {"tooltip": "Grace window (s) to still jump just after walking off a ledge."}},
		"jump_buffer_time": {"type": "float", "default": 0.1, "exported": true,
			"attributes": {"tooltip": "Press jump this many seconds early and it still fires on landing."}},
		"max_jumps": {"type": "int", "default": 1, "exported": true,
			"attributes": {"tooltip": "Total jumps before touching ground (2 = double jump)."}},
		"variable_jump_height": {"type": "bool", "default": true, "exported": true,
			"attributes": {"tooltip": "Releasing jump early cuts the rise (hold = higher)."}},
		"jump_cut_factor": {"type": "float", "default": 0.45, "exported": true,
			"attributes": {"tooltip": "Fraction of upward speed kept when jump is released early.", "range": {"min": "0", "max": "1", "step": "0.05"}}},
		"enable_wall_slide": {"type": "bool", "default": false, "exported": true,
			"attributes": {"tooltip": "Cling and slow your fall when pressing into a wall."}},
		"wall_slide_speed": {"type": "float", "default": 80.0, "exported": true,
			"attributes": {"tooltip": "Max fall speed while wall sliding (px/s)."}},
		"enable_wall_jump": {"type": "bool", "default": false, "exported": true,
			"attributes": {"tooltip": "Jump off walls (kicks away from the wall)."}},
		"wall_jump_push": {"type": "float", "default": 260.0, "exported": true,
			"attributes": {"tooltip": "Horizontal kick away from the wall on a wall jump."}},
		"wall_jump_velocity": {"type": "float", "default": -380.0, "exported": true,
			"attributes": {"tooltip": "Upward velocity of a wall jump (negative = up)."}},
		# ── Internal state (not exported) ────────────────────────────────────────────
		"_coyote_timer": {"type": "float", "default": 0.0, "exported": false},
		"_buffer_timer": {"type": "float", "default": 0.0, "exported": false},
		"_jumps_left": {"type": "int", "default": 0, "exported": false},
		"_air_time": {"type": "float", "default": 0.0, "exported": false},
		"_was_on_floor": {"type": "bool", "default": false, "exported": false},
		"_facing": {"type": "int", "default": 1, "exported": false},
		"_wall_sliding": {"type": "bool", "default": false, "exported": false}
	}

	var about: CommentRow = CommentRow.new()
	about.text = "Platformer movement: attach under a CharacterBody2D. Run with ui_left/ui_right, call Jump (with coyote time + buffering), and turn on wall slide / wall jump / double jump in the Inspector. Call Jump Released when the player lets go of the jump button for variable jump height."
	sheet.events.append(about)

	# Triggers + conditions + expressions + private helpers (class-level annotated block).
	var block: RawCodeRow = RawCodeRow.new()
	block.code = "\n".join(PackedStringArray([
		"## @ace_trigger",
		"## @ace_name(\"On Jumped\")",
		"## @ace_category(\"Platformer\")",
		"signal jumped",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Landed\")",
		"## @ace_category(\"Platformer\")",
		"signal landed",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Double Jumped\")",
		"## @ace_category(\"Platformer\")",
		"signal double_jumped",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Wall Jumped\")",
		"## @ace_category(\"Platformer\")",
		"signal wall_jumped",
		"",
		"## @ace_condition",
		"## @ace_name(\"Is Moving\")",
		"## @ace_category(\"Platformer\")",
		"## @ace_codegen_template(\"$PlatformerMovement.is_moving()\")",
		"func is_moving() -> bool:",
		"\treturn host != null and absf(host.velocity.x) > 1.0",
		"",
		"## @ace_condition",
		"## @ace_name(\"Is Jumping\")",
		"## @ace_category(\"Platformer\")",
		"## @ace_codegen_template(\"$PlatformerMovement.is_jumping()\")",
		"func is_jumping() -> bool:",
		"\treturn host != null and not host.is_on_floor() and host.velocity.y < 0.0",
		"",
		"## @ace_condition",
		"## @ace_name(\"Is Falling\")",
		"## @ace_category(\"Platformer\")",
		"## @ace_codegen_template(\"$PlatformerMovement.is_falling()\")",
		"func is_falling() -> bool:",
		"\treturn host != null and not host.is_on_floor() and host.velocity.y > 0.0",
		"",
		"## @ace_condition",
		"## @ace_name(\"Is Wall Sliding\")",
		"## @ace_category(\"Platformer\")",
		"## @ace_codegen_template(\"$PlatformerMovement.is_wall_sliding()\")",
		"func is_wall_sliding() -> bool:",
		"\treturn _wall_sliding",
		"",
		"## @ace_condition",
		"## @ace_name(\"Can Jump\")",
		"## @ace_category(\"Platformer\")",
		"## @ace_codegen_template(\"$PlatformerMovement.can_jump()\")",
		"func can_jump() -> bool:",
		"\tif host == null:",
		"\t\treturn false",
		"\treturn host.is_on_floor() or _coyote_timer > 0.0 or _jumps_left > 0 or (enable_wall_jump and host.is_on_wall())",
		"",
		"## @ace_expression",
		"## @ace_name(\"Jumps Remaining\")",
		"## @ace_category(\"Platformer\")",
		"func jumps_remaining() -> int:",
		"\treturn _jumps_left",
		"",
		"## @ace_expression",
		"## @ace_name(\"Air Time\")",
		"## @ace_category(\"Platformer\")",
		"func air_time() -> float:",
		"\treturn _air_time",
		"",
		"## @ace_expression",
		"## @ace_name(\"Facing Direction\")",
		"## @ace_category(\"Platformer\")",
		"func facing_direction() -> int:",
		"\treturn _facing",
		"",
		"# Shared jump kernel: set the rise and spend the coyote window. _jumps_left counts",
		"# only AIR jumps (it is decremented by the air-jump branch, not here), so falling off",
		"# a ledge past the coyote window never grants a phantom jump.",
		"func _perform_jump(velocity_y: float) -> void:",
		"\tif host == null:",
		"\t\treturn",
		"\thost.velocity.y = velocity_y",
		"\t_coyote_timer = 0.0"
	]))
	sheet.events.append(block)

	# Core loop: gravity + terminal velocity, accel/decel, wall slide, coyote/buffer
	# timers, landing edge, and firing a buffered jump the instant it becomes possible.
	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"
	tick.trigger_id = "OnPhysicsProcess"
	var movement: RawCodeRow = RawCodeRow.new()
	movement.code = "\n".join(PackedStringArray([
		"if host == null:",
		"\treturn",
		"var was_on_floor := _was_on_floor",
		"var on_floor := host.is_on_floor()",
		"if not on_floor:",
		"\thost.velocity.y = minf(host.velocity.y + gravity * delta, max_fall_speed)",
		"\t_air_time += delta",
		"else:",
		"\t_air_time = 0.0",
		"var direction := Input.get_axis(\"ui_left\", \"ui_right\")",
		"var target_speed := direction * move_speed",
		"var rate := acceleration if not is_zero_approx(direction) else deceleration",
		"host.velocity.x = move_toward(host.velocity.x, target_speed, rate * delta)",
		"if not is_zero_approx(direction):",
		"\t_facing = 1 if direction > 0.0 else -1",
		"_wall_sliding = false",
		"if enable_wall_slide and not on_floor and host.is_on_wall() and host.velocity.y > 0.0 and not is_zero_approx(direction):",
		"\thost.velocity.y = minf(host.velocity.y, wall_slide_speed)",
		"\t_wall_sliding = true",
		"if on_floor:",
		"\t_coyote_timer = coyote_time",
		"\t_jumps_left = maxi(max_jumps - 1, 0)",
		"else:",
		"\t_coyote_timer = maxf(_coyote_timer - delta, 0.0)",
		"_buffer_timer = maxf(_buffer_timer - delta, 0.0)",
		"if on_floor and not was_on_floor:",
		"\tlanded.emit()",
		"_was_on_floor = on_floor",
		"if _buffer_timer > 0.0 and (on_floor or _coyote_timer > 0.0 or _jumps_left > 0 or (enable_wall_jump and host.is_on_wall())):",
		"\t_buffer_timer = 0.0",
		"\tjump()",
		"host.move_and_slide()"
	]))
	tick.actions.append(movement)
	sheet.events.append(tick)

	# ── Exposed actions ─────────────────────────────────────────────────────────────
	Lib.append_function(sheet, "jump", "Jump", "Platformer",
		"Jumps: from the floor or within coyote time, off a wall (if enabled), or a mid-air (double) jump if any remain. If none are available right now, the press is buffered.",
		[],
		"\n".join(PackedStringArray([
			"if host == null:",
			"\treturn",
			"if host.is_on_floor() or _coyote_timer > 0.0:",
			"\t_perform_jump(jump_velocity)",
			"\tjumped.emit()",
			"elif enable_wall_jump and host.is_on_wall():",
			"\thost.velocity.y = wall_jump_velocity",
			"\thost.velocity.x = host.get_wall_normal().x * wall_jump_push",
			"\t_coyote_timer = 0.0",
			"\t_facing = 1 if host.get_wall_normal().x > 0.0 else -1",
			"\twall_jumped.emit()",
			"elif _jumps_left > 0:",
			"\t_perform_jump(jump_velocity)",
			"\t_jumps_left -= 1",
			"\tdouble_jumped.emit()",
			"else:",
			"\t_buffer_timer = jump_buffer_time"
		])))
	Lib.append_function(sheet, "jump_released", "Jump Released", "Platformer",
		"Call when the jump button is released - cuts the rise short for variable jump height (hold = higher).",
		[],
		"if host != null and variable_jump_height and host.velocity.y < 0.0:\n\thost.velocity.y *= jump_cut_factor")
	Lib.append_function(sheet, "set_move_speed", "Set Move Speed", "Platformer",
		"Changes the horizontal move speed.",
		[["speed", "float"]],
		"move_speed = speed")
	Lib.append_function(sheet, "reset_jumps", "Reset Jumps", "Platformer",
		"Refills the air-jump count (e.g. after grabbing a power-up).",
		[],
		"_jumps_left = maxi(max_jumps - 1, 0)")

	return Lib.save_pack(sheet, "res://eventsheet_addons/platformer_movement/platformer_movement_behavior")
