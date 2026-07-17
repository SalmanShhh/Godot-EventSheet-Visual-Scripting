# Pack builder - fps_controller (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## First/third-person character controller behavior: mouse look (yaw on the host, pitch on a
## child named "Head"), WASD/arrows movement relative to where you look, sprint, jump with
## gravity, and a camera mode switch that drives a SpringArm3D named "Arm" under the Head
## (spring length ~0 = first person, camera_distance = third person). Attach under a
## CharacterBody3D whose scene has Head/Arm/Camera3D children - the bundled FPS Arena showcase
## is the reference rig.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "CharacterBody3D"
	sheet.custom_class_name = "FPSController"
	sheet.class_description = "A complete first / third person character controller you attach under a CharacterBody3D: mouse look, WASD movement, sprint, jump, crouch, crouch slide, wall ride, and wall jump. Each move fires its own triggers, so a camera lean or a sound is one event row away."
	sheet.addon_category = "FPS Controller"
	sheet.ace_expose_all_mode = "node"
	sheet.variables = {
		"move_speed": {"type": "float", "default": 5.0, "exported": true, "description": "Base walking speed in metres per second."},
		"sprint_multiplier": {"type": "float", "default": 1.6, "exported": true, "description": "Multiplies move speed while the sprint key (Shift) is held."},
		"jump_velocity": {"type": "float", "default": 4.5, "exported": true, "description": "Upward velocity applied on a jump (and on a wall jump)."},
		"gravity": {"type": "float", "default": 9.8, "exported": true, "description": "Downward acceleration pulling the host to the floor, in metres per second squared."},
		"mouse_sensitivity": {"type": "float", "default": 0.12, "exported": true, "description": "Look sensitivity in degrees turned per mouse pixel moved."},
		"pitch_min": {"type": "float", "default": -80.0, "exported": true, "description": "Lowest look angle in degrees (how far you can look down)."},
		"pitch_max": {"type": "float", "default": 80.0, "exported": true, "description": "Highest look angle in degrees (how far you can look up)."},
		"third_person": {"type": "bool", "default": false, "exported": true, "description": "Starts in third-person camera when on, first-person when off."},
		"camera_distance": {"type": "float", "default": 3.5, "exported": true, "description": "How far the camera pulls back in third person (the SpringArm3D length)."},
		"capture_mouse_on_ready": {"type": "bool", "default": true, "exported": true, "description": "Locks the mouse to the window for looking as soon as the scene starts."},
		"crouch_height": {"type": "float", "default": 0.9, "exported": true, "description": "Capsule height while crouched (the feet stay planted)."},
		"crouch_speed_multiplier": {"type": "float", "default": 0.5, "exported": true, "description": "Multiplies move speed while crouched."},
		"slide_enabled": {"type": "bool", "default": true, "exported": true, "description": "Allows a crouch slide when crouching at speed."},
		"slide_boost_speed": {"type": "float", "default": 9.0, "exported": true, "description": "Starting speed of a crouch slide, decaying to crouch-walk pace."},
		"slide_min_speed": {"type": "float", "default": 6.5, "exported": true, "description": "Minimum horizontal speed needed to start a crouch slide."},
		"slide_duration": {"type": "float", "default": 0.9, "exported": true, "description": "How long a crouch slide lasts, in seconds."},
		"wall_ride_enabled": {"type": "bool", "default": true, "exported": true, "description": "Allows riding a wall when airborne and pushing into it."},
		"wall_ride_gravity_scale": {"type": "float", "default": 0.25, "exported": true, "description": "Scales gravity while wall riding (lower means a slower slide down)."},
		"wall_ride_max_time": {"type": "float", "default": 1.5, "exported": true, "description": "Longest a single wall ride can last, in seconds."},
		"wall_ride_min_speed": {"type": "float", "default": 3.0, "exported": true, "description": "Minimum horizontal speed needed to start or keep a wall ride."},
		"wall_jump_enabled": {"type": "bool", "default": true, "exported": true, "description": "Allows jumping off a wall while airborne."},
		"wall_jump_push": {"type": "float", "default": 6.0, "exported": true, "description": "How hard a wall jump pushes away from the wall (the kick fades over about half a second)."},
		"ai_controlled": {"type": "bool", "default": false, "exported": true, "description": "Reads the ai_move_x/z intents instead of the keyboard when on (for AI or cutscene drivers)."},
		"ai_move_x": {"type": "float", "default": 0.0, "exported": false},
		"ai_move_z": {"type": "float", "default": 0.0, "exported": false},
		"yaw": {"type": "float", "default": 0.0, "exported": false},
		"pitch": {"type": "float", "default": 0.0, "exported": false},
		"sprint_held": {"type": "bool", "default": false, "exported": false},
		"was_on_floor": {"type": "bool", "default": true, "exported": false},
		"crouching": {"type": "bool", "default": false, "exported": false},
		"sliding": {"type": "bool", "default": false, "exported": false},
		"slide_time": {"type": "float", "default": 0.0, "exported": false},
		"slide_dir_x": {"type": "float", "default": 0.0, "exported": false},
		"slide_dir_z": {"type": "float", "default": 0.0, "exported": false},
		"wall_riding": {"type": "bool", "default": false, "exported": false},
		"wall_ride_time": {"type": "float", "default": 0.0, "exported": false},
		"standing_height": {"type": "float", "default": 0.0, "exported": false},
		"standing_radius": {"type": "float", "default": 0.0, "exported": false},
		"shape_base_y": {"type": "float", "default": 0.0, "exported": false},
		"head_base_y": {"type": "float", "default": 0.0, "exported": false},
		"push_x": {"type": "float", "default": 0.0, "exported": false},
		"push_z": {"type": "float", "default": 0.0, "exported": false},
	}
	var about: CommentRow = CommentRow.new()
	about.text = "FPS/TPS controller behavior: mouse look + WASD move + sprint + jump on the host CharacterBody3D; a SpringArm3D named Arm under a Head child switches first/third person. Movement tech included: crouch (hold Ctrl, capsule shrinks, ceiling-checked stand), crouch slide (crouch while sprinting), wall ride (hold forward against a wall mid-air), and wall jump (jump off any wall mid-air)."
	sheet.events.append(about)

	var jumped_signal: SignalRow = SignalRow.new()
	jumped_signal.signal_name = "jumped"
	jumped_signal.trigger = true
	jumped_signal.ace_name = "On Jumped"
	jumped_signal.ace_category = "FPS Controller"
	sheet.events.append(jumped_signal)
	var landed_signal: SignalRow = SignalRow.new()
	landed_signal.signal_name = "landed"
	landed_signal.trigger = true
	landed_signal.ace_name = "On Landed"
	landed_signal.ace_category = "FPS Controller"
	sheet.events.append(landed_signal)
	var camera_signal: SignalRow = SignalRow.new()
	camera_signal.signal_name = "camera_mode_changed"
	camera_signal.trigger = true
	camera_signal.ace_name = "On Camera Mode Changed"
	camera_signal.ace_category = "FPS Controller"
	sheet.events.append(camera_signal)
	for tech_signal: Array in [
		["crouched", "On Crouched"],
		["stood_up", "On Stood Up"],
		["slide_started", "On Slide Started"],
		["slide_ended", "On Slide Ended"],
		["wall_ride_started", "On Wall Ride Started"],
		["wall_ride_ended", "On Wall Ride Ended"],
		["wall_jumped", "On Wall Jumped"],
	]:
		var signal_row: SignalRow = SignalRow.new()
		signal_row.signal_name = str(tech_signal[0])
		signal_row.trigger = true
		signal_row.ace_name = str(tech_signal[1])
		signal_row.ace_category = "FPS Controller"
		sheet.events.append(signal_row)

	# Mouse look + the Esc escape hatch live in _unhandled_input (no per-frame polling), and the
	# Head lookup is one shared helper - both are plain class-level GDScript blocks.
	var input_block: RawCodeRow = RawCodeRow.new()
	input_block.code = "\n".join(PackedStringArray([
		"func _head() -> Node3D:",
		"\treturn (host.get_node_or_null(\"Head\") as Node3D) if host != null else null",
		"",
		"",
		"func _unhandled_input(event: InputEvent) -> void:",
		"\tif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:",
		"\t\tadd_look((event as InputEventMouseMotion).relative.x, (event as InputEventMouseMotion).relative.y)",
		"\telif event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode == KEY_ESCAPE:",
		"\t\trelease_mouse()",
		"",
		"",
		"## The host's capsule collider (first CollisionShape3D child holding a CapsuleShape3D).",
		"## @ace_hidden",
		"func _capsule() -> CollisionShape3D:",
		"\tif host == null:",
		"\t\treturn null",
		"\tfor child in host.get_children():",
		"\t\tif child is CollisionShape3D and (child as CollisionShape3D).shape is CapsuleShape3D:",
		"\t\t\treturn child as CollisionShape3D",
		"\treturn null",
		"",
		"",
		"## Shrinks/restores the capsule + drops/raises the Head so crouching physically lowers the",
		"## body. The capsule shortens toward the FLOOR (the shape node shifts down by half the lost",
		"## height) so the feet stay planted. The shape resource is duplicated on first use - capsule",
		"## resources are commonly shared across scenes, and crouching one character must not shrink",
		"## every other user of that resource.",
		"## @ace_hidden",
		"func _apply_crouch_shape(low: bool) -> void:",
		"\tvar shape_node := _capsule()",
		"\tif shape_node != null:",
		"\t\tvar capsule := shape_node.shape as CapsuleShape3D",
		"\t\tif standing_height <= 0.0:",
		"\t\t\tstanding_height = capsule.height",
		"\t\t\tstanding_radius = capsule.radius",
		"\t\t\tshape_base_y = shape_node.position.y",
		"\t\t\tvar head_node := _head()",
		"\t\t\thead_base_y = head_node.position.y if head_node != null else 0.0",
		"\t\t\tshape_node.shape = capsule.duplicate()",
		"\t\t\tcapsule = shape_node.shape as CapsuleShape3D",
		"\t\tvar low_height: float = minf(crouch_height, standing_height)",
		"\t\tcapsule.height = low_height if low else standing_height",
		"\t\t# A crouch below capsule-diameter auto-shrinks the radius; put it back on stand.",
		"\t\tif not low:",
		"\t\t\tcapsule.radius = standing_radius",
		"\t\tshape_node.position.y = shape_base_y - ((standing_height - low_height) * 0.5 if low else 0.0)",
		"\tvar head := _head()",
		"\tif head != null and standing_height > 0.0:",
		"\t\thead.position.y = head_base_y - ((standing_height - minf(crouch_height, standing_height)) if low else 0.0)",
		"",
		"",
		"## Headroom test for standing up: sweeps the (crouched) body upward by the height it would",
		"## regain; any hit means a ceiling is in the way and the crouch holds. The sweep needs a",
		"## live physics space - outside the tree (headless tools/tests) standing is always allowed.",
		"## @ace_hidden",
		"func _can_stand_up() -> bool:",
		"\tif host == null or standing_height <= 0.0 or not host.is_inside_tree():",
		"\t\treturn true",
		"\tvar params := PhysicsTestMotionParameters3D.new()",
		"\tparams.from = host.global_transform",
		"\tparams.motion = Vector3.UP * (standing_height - minf(crouch_height, standing_height))",
		"\treturn not PhysicsServer3D.body_test_motion(host.get_rid(), params)",
		"",
		"",
		"## @ace_hidden",
		"func _start_wall_ride() -> void:",
		"\twall_riding = true",
		"\twall_ride_time = 0.0",
		"\tif host != null and host.velocity.y < 0.0:",
		"\t\thost.velocity.y *= 0.25",
		"\twall_ride_started.emit()"
	]))
	sheet.events.append(input_block)

	var ready_event: EventRow = EventRow.new()
	ready_event.trigger_provider_id = "Core"
	ready_event.trigger_id = "OnReady"
	var ready_body: RawCodeRow = RawCodeRow.new()
	ready_body.code = "\n".join(PackedStringArray([
		"if capture_mouse_on_ready:",
		"\tcapture_mouse()",
		"apply_camera_mode()"
	]))
	ready_event.actions.append(ready_body)
	sheet.events.append(ready_event)

	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"
	tick.trigger_id = "OnPhysicsProcess"
	var tick_body: RawCodeRow = RawCodeRow.new()
	tick_body.code = "\n".join(PackedStringArray([
		"if host == null:",
		"\treturn",
		"var on_floor := host.is_on_floor()",
		"# Gravity, softened while riding a wall so the slide down reads as a glide.",
		"if not on_floor:",
		"\thost.velocity.y -= gravity * (wall_ride_gravity_scale if wall_riding else 1.0) * delta",
		"sprint_held = Input.is_key_pressed(KEY_SHIFT) and not crouching",
		"# Crouch is hold-to-crouch (Ctrl); standing back up is ceiling-checked and retries",
		"# every frame the key is up, so releasing under a low tunnel pops you up at the exit.",
		"if Input.is_key_pressed(KEY_CTRL):",
		"\tif not crouching:",
		"\t\tdo_crouch()",
		"elif crouching:",
		"\tstand_up()",
		"# The standard AI drive seam: a driver (a 3D navigator, a cutscene) writes ai_move_x/z",
		"# and flips ai_controlled on; off (the default) this is exactly the keyboard read.",
		"var input_vec := Vector2(ai_move_x, ai_move_z).limit_length(1.0) if ai_controlled else Input.get_vector(\"ui_left\", \"ui_right\", \"ui_up\", \"ui_down\")",
		"var direction := host.transform.basis * Vector3(input_vec.x, 0.0, input_vec.y)",
		"if direction.length() > 1.0:",
		"\tdirection = direction.normalized()",
		"if sliding:",
		"\t# Crouch slide: locked direction, speed decaying from the boost down to crouch-walk pace.",
		"\tslide_time += delta",
		"\tvar slide_fraction := clampf(slide_time / maxf(slide_duration, 0.001), 0.0, 1.0)",
		"\tvar slide_now := lerpf(slide_boost_speed, move_speed * crouch_speed_multiplier, slide_fraction)",
		"\thost.velocity.x = slide_dir_x * slide_now",
		"\thost.velocity.z = slide_dir_z * slide_now",
		"\tif slide_fraction >= 1.0 or not on_floor:",
		"\t\tstop_sliding()",
		"else:",
		"\tvar speed := move_speed * (sprint_multiplier if sprint_held else 1.0) * (crouch_speed_multiplier if crouching else 1.0)",
		"\t# push_x/z is the decaying wall-jump kick - without it the every-frame velocity",
		"\t# assignment would erase the push after a single physics tick.",
		"\thost.velocity.x = direction.x * speed + push_x",
		"\thost.velocity.z = direction.z * speed + push_z",
		"var push_fade := wall_jump_push * 2.0 * delta",
		"push_x = move_toward(push_x, 0.0, push_fade)",
		"push_z = move_toward(push_z, 0.0, push_fade)",
		"if wall_riding:",
		"\twall_ride_time += delta",
		"\tif on_floor or not host.is_on_wall() or wall_ride_time >= wall_ride_max_time or Vector2(host.velocity.x, host.velocity.z).length() < wall_ride_min_speed:",
		"\t\tstop_wall_ride()",
		"\telse:",
		"\t\t# Glue: a slight into-wall push keeps contact; move_and_slide discards it against the wall.",
		"\t\tvar wall_normal := host.get_wall_normal()",
		"\t\thost.velocity.x -= wall_normal.x * 1.5",
		"\t\thost.velocity.z -= wall_normal.z * 1.5",
		"elif wall_ride_enabled and not on_floor and host.is_on_wall() and input_vec.y < -0.2 and Vector2(host.velocity.x, host.velocity.z).length() >= wall_ride_min_speed:",
		"\t_start_wall_ride()",
		"if Input.is_action_just_pressed(\"ui_accept\"):",
		"\tif on_floor:",
		"\t\tif sliding:",
		"\t\t\tstop_sliding()",
		"\t\tdo_jump()",
		"\telif wall_jump_enabled and host.is_on_wall():",
		"\t\tdo_wall_jump()",
		"host.move_and_slide()",
		"if host.is_on_floor() and not was_on_floor:",
		"\tlanded.emit()",
		"was_on_floor = host.is_on_floor()"
	]))
	tick.actions.append(tick_body)
	sheet.events.append(tick)

	var jump_fn: EventFunction = EventFunction.new()
	jump_fn.function_name = "do_jump"
	jump_fn.expose_as_ace = true
	jump_fn.ace_display_name = "Jump"
	jump_fn.ace_category = "FPS Controller"
	jump_fn.description = "Launches the host upward with Jump Velocity and fires On Jumped."
	var jump_body: RawCodeRow = RawCodeRow.new()
	jump_body.code = "\n".join(PackedStringArray([
		"if host == null:",
		"\treturn",
		"host.velocity.y = jump_velocity",
		"jumped.emit()"
	]))
	jump_fn.events.append(jump_body)
	sheet.functions.append(jump_fn)

	var look_fn: EventFunction = EventFunction.new()
	look_fn.function_name = "add_look"
	look_fn.expose_as_ace = true
	look_fn.ace_display_name = "Add Look"
	look_fn.ace_category = "FPS Controller"
	look_fn.description = "Turns the view by a mouse delta (pixels): yaw rotates the host, pitch tilts the Head child, clamped to Pitch Min/Max."
	var look_x: ACEParam = ACEParam.new()
	look_x.id = "x"
	look_x.type_name = "float"
	look_fn.params.append(look_x)
	var look_y: ACEParam = ACEParam.new()
	look_y.id = "y"
	look_y.type_name = "float"
	look_fn.params.append(look_y)
	var look_body: RawCodeRow = RawCodeRow.new()
	look_body.code = "\n".join(PackedStringArray([
		"yaw = wrapf(yaw - x * mouse_sensitivity, -180.0, 180.0)",
		"pitch = clampf(pitch - y * mouse_sensitivity, pitch_min, pitch_max)",
		"if host != null:",
		"\thost.rotation_degrees.y = yaw",
		"var head := _head()",
		"if head != null:",
		"\thead.rotation_degrees.x = pitch"
	]))
	look_fn.events.append(look_body)
	sheet.functions.append(look_fn)

	var camera_fn: EventFunction = EventFunction.new()
	camera_fn.function_name = "set_third_person"
	camera_fn.expose_as_ace = true
	camera_fn.ace_display_name = "Set Third Person"
	camera_fn.ace_category = "FPS Controller"
	camera_fn.description = "Switches between first person (off) and third person (on) and fires On Camera Mode Changed."
	var camera_enabled: ACEParam = ACEParam.new()
	camera_enabled.id = "enabled"
	camera_enabled.type_name = "bool"
	camera_fn.params.append(camera_enabled)
	var camera_body: RawCodeRow = RawCodeRow.new()
	camera_body.code = "\n".join(PackedStringArray([
		"third_person = enabled",
		"apply_camera_mode()",
		"camera_mode_changed.emit()"
	]))
	camera_fn.events.append(camera_body)
	sheet.functions.append(camera_fn)

	var toggle_fn: EventFunction = EventFunction.new()
	toggle_fn.function_name = "toggle_camera_mode"
	toggle_fn.expose_as_ace = true
	toggle_fn.ace_display_name = "Toggle Camera Mode"
	toggle_fn.ace_category = "FPS Controller"
	toggle_fn.description = "Flips between first and third person."
	var toggle_body: RawCodeRow = RawCodeRow.new()
	toggle_body.code = "set_third_person(not third_person)"
	toggle_fn.events.append(toggle_body)
	sheet.functions.append(toggle_fn)

	var apply_fn: EventFunction = EventFunction.new()
	apply_fn.function_name = "apply_camera_mode"
	apply_fn.expose_as_ace = true
	apply_fn.ace_display_name = "Apply Camera Mode"
	apply_fn.ace_category = "FPS Controller"
	apply_fn.description = "Re-applies the current camera mode to the Head's SpringArm3D (named Arm): ~0 length in first person, Camera Distance in third."
	var apply_body: RawCodeRow = RawCodeRow.new()
	apply_body.code = "\n".join(PackedStringArray([
		"var head := _head()",
		"if head == null:",
		"\treturn",
		"var arm := head.get_node_or_null(\"Arm\") as SpringArm3D",
		"if arm != null:",
		"\tarm.spring_length = camera_distance if third_person else 0.05"
	]))
	apply_fn.events.append(apply_body)
	sheet.functions.append(apply_fn)

	var capture_fn: EventFunction = EventFunction.new()
	capture_fn.function_name = "capture_mouse"
	capture_fn.expose_as_ace = true
	capture_fn.ace_display_name = "Capture Mouse"
	capture_fn.ace_category = "FPS Controller"
	capture_fn.description = "Locks the mouse to the window for looking around (Esc releases it)."
	var capture_body: RawCodeRow = RawCodeRow.new()
	capture_body.code = "Input.mouse_mode = Input.MOUSE_MODE_CAPTURED"
	capture_fn.events.append(capture_body)
	sheet.functions.append(capture_fn)

	var release_fn: EventFunction = EventFunction.new()
	release_fn.function_name = "release_mouse"
	release_fn.expose_as_ace = true
	release_fn.ace_display_name = "Release Mouse"
	release_fn.ace_category = "FPS Controller"
	release_fn.description = "Frees the mouse cursor."
	var release_body: RawCodeRow = RawCodeRow.new()
	release_body.code = "Input.mouse_mode = Input.MOUSE_MODE_VISIBLE"
	release_fn.events.append(release_body)
	sheet.functions.append(release_fn)

	var speed_fn: EventFunction = EventFunction.new()
	speed_fn.function_name = "set_move_speed"
	speed_fn.expose_as_ace = true
	speed_fn.ace_display_name = "Set Move Speed"
	speed_fn.ace_category = "FPS Controller"
	speed_fn.description = "Changes the base walking speed."
	var speed_value: ACEParam = ACEParam.new()
	speed_value.id = "value"
	speed_value.type_name = "float"
	speed_fn.params.append(speed_value)
	var speed_body: RawCodeRow = RawCodeRow.new()
	speed_body.code = "move_speed = value"
	speed_fn.events.append(speed_body)
	sheet.functions.append(speed_fn)

	var sensitivity_fn: EventFunction = EventFunction.new()
	sensitivity_fn.function_name = "set_mouse_sensitivity"
	sensitivity_fn.expose_as_ace = true
	sensitivity_fn.ace_display_name = "Set Mouse Sensitivity"
	sensitivity_fn.ace_category = "FPS Controller"
	sensitivity_fn.description = "Changes look sensitivity (degrees per mouse pixel)."
	var sensitivity_value: ACEParam = ACEParam.new()
	sensitivity_value.id = "value"
	sensitivity_value.type_name = "float"
	sensitivity_fn.params.append(sensitivity_value)
	var sensitivity_body: RawCodeRow = RawCodeRow.new()
	sensitivity_body.code = "mouse_sensitivity = value"
	sensitivity_fn.events.append(sensitivity_body)
	sheet.functions.append(sensitivity_fn)

	var sprinting_fn: EventFunction = EventFunction.new()
	sprinting_fn.function_name = "is_sprinting"
	sprinting_fn.expose_as_ace = true
	sprinting_fn.ace_display_name = "Is Sprinting"
	sprinting_fn.ace_category = "FPS Controller"
	sprinting_fn.return_type = TYPE_BOOL
	sprinting_fn.description = "True while the sprint key (Shift) is held."
	var sprinting_body: RawCodeRow = RawCodeRow.new()
	sprinting_body.code = "return sprint_held"
	sprinting_fn.events.append(sprinting_body)
	sheet.functions.append(sprinting_fn)

	var first_person_fn: EventFunction = EventFunction.new()
	first_person_fn.function_name = "is_first_person"
	first_person_fn.expose_as_ace = true
	first_person_fn.ace_display_name = "Is First Person"
	first_person_fn.ace_category = "FPS Controller"
	first_person_fn.return_type = TYPE_BOOL
	first_person_fn.description = "True in first-person camera mode."
	var first_person_body: RawCodeRow = RawCodeRow.new()
	first_person_body.code = "return not third_person"
	first_person_fn.events.append(first_person_body)
	sheet.functions.append(first_person_fn)

	var current_speed_fn: EventFunction = EventFunction.new()
	current_speed_fn.function_name = "current_speed"
	current_speed_fn.expose_as_ace = true
	current_speed_fn.ace_display_name = "Current Speed"
	current_speed_fn.ace_category = "FPS Controller"
	current_speed_fn.return_type = TYPE_FLOAT
	current_speed_fn.description = "The host's horizontal speed right now (metres per second)."
	var current_speed_body: RawCodeRow = RawCodeRow.new()
	current_speed_body.code = "return Vector2(host.velocity.x, host.velocity.z).length() if host != null else 0.0"
	current_speed_fn.events.append(current_speed_body)
	sheet.functions.append(current_speed_fn)

	var look_yaw_fn: EventFunction = EventFunction.new()
	look_yaw_fn.function_name = "look_yaw"
	look_yaw_fn.expose_as_ace = true
	look_yaw_fn.ace_display_name = "Look Yaw"
	look_yaw_fn.ace_category = "FPS Controller"
	look_yaw_fn.return_type = TYPE_FLOAT
	look_yaw_fn.description = "The current horizontal look angle in degrees (-180..180)."
	var look_yaw_body: RawCodeRow = RawCodeRow.new()
	look_yaw_body.code = "return yaw"
	look_yaw_fn.events.append(look_yaw_body)
	sheet.functions.append(look_yaw_fn)

	var look_pitch_fn: EventFunction = EventFunction.new()
	look_pitch_fn.function_name = "look_pitch"
	look_pitch_fn.expose_as_ace = true
	look_pitch_fn.ace_display_name = "Look Pitch"
	look_pitch_fn.ace_category = "FPS Controller"
	look_pitch_fn.return_type = TYPE_FLOAT
	look_pitch_fn.description = "The current vertical look angle in degrees (clamped to Pitch Min/Max)."
	var look_pitch_body: RawCodeRow = RawCodeRow.new()
	look_pitch_body.code = "return pitch"
	look_pitch_fn.events.append(look_pitch_body)
	sheet.functions.append(look_pitch_fn)

	Lib.append_function(sheet, "do_crouch", "Crouch", "FPS Controller",
		"Crouches: the capsule shrinks to Crouch Height (feet stay planted), the Head drops, and movement slows to the crouch multiplier. Crouching at sprint speed starts a crouch slide (see Slide knobs). Fires On Crouched. Held Ctrl does this automatically.",
		[],
		"\n".join(PackedStringArray([
			"if crouching or host == null:",
			"\treturn",
			"crouching = true",
			"_apply_crouch_shape(true)",
			"if slide_enabled and host.is_on_floor():",
			"\tvar horizontal := Vector3(host.velocity.x, 0.0, host.velocity.z)",
			"\tif horizontal.length() >= slide_min_speed:",
			"\t\tsliding = true",
			"\t\tslide_time = 0.0",
			"\t\tvar slide_direction := horizontal.normalized()",
			"\t\tslide_dir_x = slide_direction.x",
			"\t\tslide_dir_z = slide_direction.z",
			"\t\tslide_started.emit()",
			"crouched.emit()"
		])))
	Lib.append_function(sheet, "stand_up", "Stand Up", "FPS Controller",
		"Stands back up from a crouch - unless a ceiling is in the way, in which case the crouch holds (re-check by calling again, or use the Can Stand Up condition). Ends any slide. Fires On Stood Up.",
		[],
		"\n".join(PackedStringArray([
			"if not crouching:",
			"\treturn",
			"if not _can_stand_up():",
			"\treturn",
			"if sliding:",
			"\tstop_sliding()",
			"crouching = false",
			"_apply_crouch_shape(false)",
			"stood_up.emit()"
		])))
	Lib.append_function(sheet, "set_crouching", "Set Crouching", "FPS Controller",
		"Crouches (on) or stands (off) - the scripted version of holding/releasing Ctrl.",
		[["enabled", "bool"]],
		"if enabled:\n\tdo_crouch()\nelse:\n\tstand_up()")
	Lib.append_function(sheet, "stop_sliding", "Stop Sliding", "FPS Controller",
		"Ends a crouch slide early (you stay crouched). Fires On Slide Ended.",
		[],
		"if not sliding:\n\treturn\nsliding = false\nslide_ended.emit()")
	Lib.append_function(sheet, "do_wall_jump", "Wall Jump", "FPS Controller",
		"Kicks off the wall the host is touching: Jump Velocity upward plus Wall Jump Push away from the wall (the push fades over about half a second). Ends any wall ride. Fires On Wall Jumped. Pressing jump mid-air against a wall does this automatically.",
		[],
		"\n".join(PackedStringArray([
			"if host == null or not host.is_on_wall():",
			"\treturn",
			"var wall_normal := host.get_wall_normal()",
			"if wall_riding:",
			"\tstop_wall_ride()",
			"push_x = wall_normal.x * wall_jump_push",
			"push_z = wall_normal.z * wall_jump_push",
			"host.velocity.y = jump_velocity",
			"wall_jumped.emit()"
		])))
	Lib.append_function(sheet, "stop_wall_ride", "Stop Wall Ride", "FPS Controller",
		"Detaches from the wall immediately (full gravity resumes). Fires On Wall Ride Ended.",
		[],
		"if not wall_riding:\n\treturn\nwall_riding = false\nwall_ride_ended.emit()")
	Lib.append_function(sheet, "is_crouching", "Is Crouching", "FPS Controller",
		"True while crouched (including during a crouch slide).",
		[],
		"return crouching")
	_last_returns(sheet, TYPE_BOOL)
	Lib.append_function(sheet, "is_sliding", "Is Sliding", "FPS Controller",
		"True during a crouch slide.",
		[],
		"return sliding")
	_last_returns(sheet, TYPE_BOOL)
	Lib.append_function(sheet, "is_wall_riding", "Is Wall Riding", "FPS Controller",
		"True while riding a wall (airborne, glued to it, gravity softened).",
		[],
		"return wall_riding")
	_last_returns(sheet, TYPE_BOOL)
	Lib.append_function(sheet, "can_stand_up", "Can Stand Up", "FPS Controller",
		"True when there is headroom to stand from the current crouch (no ceiling in the way).",
		[],
		"return _can_stand_up()")
	_last_returns(sheet, TYPE_BOOL)
	Lib.append_function(sheet, "wall_normal_x", "Wall Normal X", "FPS Controller",
		"The touched wall's outward normal, X component (zero when not on a wall) - with Z, the direction a wall jump pushes; feed it to camera lean.",
		[],
		"return host.get_wall_normal().x if host != null and host.is_on_wall() else 0.0")
	_last_returns(sheet, TYPE_FLOAT)
	Lib.append_function(sheet, "wall_normal_z", "Wall Normal Z", "FPS Controller",
		"The touched wall's outward normal, Z component (zero when not on a wall).",
		[],
		"return host.get_wall_normal().z if host != null and host.is_on_wall() else 0.0")
	_last_returns(sheet, TYPE_FLOAT)
	# The pack's hero verbs: starred + bold at the top of their picker section.
	Lib.feature_verbs(sheet, ["do_crouch", "do_wall_jump"])
	return Lib.save_pack(sheet, "res://eventsheet_addons/fps_controller/fps_controller_behavior")


## Marks the last-appended function's return type, which is what flips its ACE kind from action
## to condition (bool) or expression (float/int/String) in the picker.
static func _last_returns(sheet: EventSheetResource, return_type: int) -> void:
	sheet.functions[sheet.functions.size() - 1].return_type = return_type
