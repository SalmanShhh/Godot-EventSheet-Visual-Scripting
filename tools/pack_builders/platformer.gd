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
	sheet.class_description = "Full jump-and-run movement for a CharacterBody2D in one drop: acceleration and friction, gravity with a terminal velocity, coyote time, jump buffering, variable jump height, multi-jump, wall slide, and wall jump. You only fire Jump on the button press, tune the feel in the Inspector, and react to triggers like On Jumped and On Landed."
	sheet.addon_category = "Platformer"
	sheet.ace_expose_all_mode = "node"
	sheet.addon_tags = PackedStringArray(["movement", "platformer"])
	sheet.variables = {
		# ── Tuning (Inspector) ───────────────────────────────────────────────────────
		"move_speed": {"type": "float", "default": 200.0, "exported": true,
			"attributes": {"tooltip": "Top horizontal run speed (px/s)."}},
		"jump_velocity": {"type": "float", "default": -400.0, "exported": true,
			"attributes": {"tooltip": "Upward velocity of a jump (negative = up)."}},
		"gravity": {"type": "float", "default": 980.0, "exported": true,
			"attributes": {"tooltip": "Downward acceleration (px/s²)."}},
		"gravity_angle": {"type": "float", "default": 90.0, "exported": true,
			"attributes": {"tooltip": "Direction gravity pulls, in degrees (90 = down, 270 = up, 0 = right). Rotates the whole movement frame: floor detection, running, and jumps follow.", "range": {"min": "0", "max": "360", "step": "1"}}},
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
		"ai_controlled": {"type": "bool", "default": false, "exported": true,
			"attributes": {"tooltip": "AI drive: read ai_move_axis instead of the keyboard (the Platformer Pathfinding behavior flips this on to steer)."}},
		"ai_move_axis": {"type": "float", "default": 0.0, "exported": false},
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
		"signal jumped",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Landed\")",
		"signal landed",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Double Jumped\")",
		"signal double_jumped",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Wall Jumped\")",
		"signal wall_jumped",
		"",
		"## @ace_condition",
		"## @ace_name(\"Is Moving\")",
		"func is_moving() -> bool:",
		"\treturn host != null and absf(host.velocity.dot(_gravity_right())) > 1.0",
		"",
		"## @ace_condition",
		"## @ace_name(\"Is Jumping\")",
		"func is_jumping() -> bool:",
		"\treturn host != null and not host.is_on_floor() and host.velocity.dot(_gravity_down()) < 0.0",
		"",
		"## @ace_condition",
		"## @ace_name(\"Is Falling\")",
		"func is_falling() -> bool:",
		"\treturn host != null and not host.is_on_floor() and host.velocity.dot(_gravity_down()) > 0.0",
		"",
		"## @ace_expression",
		"## @ace_name(\"Gravity Angle\")",
		"func get_gravity_angle() -> float:",
		"\treturn gravity_angle",
		"",
		"## @ace_condition",
		"## @ace_name(\"Is Wall Sliding\")",
		"func is_wall_sliding() -> bool:",
		"\treturn _wall_sliding",
		"",
		"## @ace_condition",
		"## @ace_name(\"Can Jump\")",
		"func can_jump() -> bool:",
		"\tif host == null:",
		"\t\treturn false",
		"\treturn host.is_on_floor() or _coyote_timer > 0.0 or _jumps_left > 0 or (enable_wall_jump and host.is_on_wall())",
		"",
		"## @ace_expression",
		"## @ace_name(\"Jumps Remaining\")",
		"func jumps_remaining() -> int:",
		"\treturn _jumps_left",
		"",
		"## @ace_expression",
		"## @ace_name(\"Air Time\")",
		"func air_time() -> float:",
		"\treturn _air_time",
		"",
		"## @ace_expression",
		"## @ace_name(\"Facing Direction\")",
		"func facing_direction() -> int:",
		"\treturn _facing",
		"",
		"# The gravity frame: every velocity read/write goes through these two axes, so one",
		"# angle knob rotates running, falling, jumping and floor detection together. Built",
		"# from Vector2.DOWN.rotated so the default 90 degrees is EXACTLY (0, 1) - zero float",
		"# noise, identical behavior to the fixed-down code it replaced.",
		"func _gravity_down() -> Vector2:",
		"\treturn Vector2.DOWN.rotated(deg_to_rad(gravity_angle - 90.0))",
		"",
		"# The frame's \"right\": gravity-down rotated a quarter turn counter-clockwise, so at",
		"# the default angle it is exactly (1, 0) and running stays screen-horizontal.",
		"func _gravity_right() -> Vector2:",
		"\tvar down: Vector2 = _gravity_down()",
		"\treturn Vector2(down.y, -down.x)",
		"",
		"# Replaces the velocity component along gravity while preserving the run component -",
		"# the frame-aware version of writing velocity.y.",
		"func _set_down_velocity(speed_along_down: float) -> void:",
		"\tvar down: Vector2 = _gravity_down()",
		"\tvar right: Vector2 = _gravity_right()",
		"\thost.velocity = right * host.velocity.dot(right) + down * speed_along_down",
		"",
		"# Shared jump kernel: set the rise (negative = against gravity) and spend the coyote",
		"# window. _jumps_left counts only AIR jumps (it is decremented by the air-jump branch,",
		"# not here), so falling off a ledge past the coyote window never grants a phantom jump.",
		"func _perform_jump(velocity_y: float) -> void:",
		"\tif host == null:",
		"\t\treturn",
		"\t_set_down_velocity(velocity_y)",
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
		"# One frame to rule the tick: velocity is split into its along-gravity and run",
		"# components, updated, then recomposed - at the default 90 degrees this is exactly",
		"# the old velocity.y / velocity.x math. up_direction keeps is_on_floor() honest.",
		"var down := _gravity_down()",
		"var right := _gravity_right()",
		"host.up_direction = -down",
		"var v_down := host.velocity.dot(down)",
		"var v_right := host.velocity.dot(right)",
		"var was_on_floor := _was_on_floor",
		"var on_floor := host.is_on_floor()",
		"if not on_floor:",
		"\tv_down = minf(v_down + gravity * delta, max_fall_speed)",
		"\t_air_time += delta",
		"else:",
		"\t_air_time = 0.0",
		"# The AI seam: a sibling driver (Platformer Pathfinding) writes ai_move_axis and flips",
		"# ai_controlled on; off (the default) this is exactly the keyboard read it always was.",
		"var direction := ai_move_axis if ai_controlled else Input.get_axis(\"ui_left\", \"ui_right\")",
		"var target_speed := direction * move_speed",
		"var rate := acceleration if not is_zero_approx(direction) else deceleration",
		"v_right = move_toward(v_right, target_speed, rate * delta)",
		"if not is_zero_approx(direction):",
		"\t_facing = 1 if direction > 0.0 else -1",
		"_wall_sliding = false",
		"if enable_wall_slide and not on_floor and host.is_on_wall() and v_down > 0.0 and not is_zero_approx(direction):",
		"\tv_down = minf(v_down, wall_slide_speed)",
		"\t_wall_sliding = true",
		"host.velocity = right * v_right + down * v_down",
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
			"\tvar wall_push := host.get_wall_normal().dot(_gravity_right())",
			"\thost.velocity = _gravity_right() * wall_push * wall_jump_push + _gravity_down() * wall_jump_velocity",
			"\t_coyote_timer = 0.0",
			"\t_facing = 1 if wall_push > 0.0 else -1",
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
		"if host != null and variable_jump_height:\n\tvar rise := host.velocity.dot(_gravity_down())\n\tif rise < 0.0:\n\t\t_set_down_velocity(rise * jump_cut_factor)")
	Lib.append_function(sheet, "set_gravity_angle", "Set Gravity Angle", "Platformer",
		"Points gravity in a new direction, in degrees (90 = down, 270 = up, 0 = right) - the whole movement frame rotates with it: floor detection, running, and jumps follow. Flip a level upside down or run on walls with one action.",
		[["angle", "float"]],
		"gravity_angle = wrapf(angle, 0.0, 360.0)")
	Lib.append_function(sheet, "set_move_speed", "Set Move Speed", "Platformer",
		"Changes the horizontal move speed.",
		[["speed", "float"]],
		"move_speed = speed")
	Lib.append_function(sheet, "reset_jumps", "Reset Jumps", "Platformer",
		"Refills the air-jump count (e.g. after grabbing a power-up).",
		[],
		"_jumps_left = maxi(max_jumps - 1, 0)")

	# The pack's hero verbs: starred + bold at the top of their picker section.
	Lib.feature_verbs(sheet, ["jump"])
	return Lib.save_pack(sheet, "res://eventsheet_addons/platformer_movement/platformer_movement_behavior")
