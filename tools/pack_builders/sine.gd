# Pack builder - sine (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## Saves the editable sheet (.tres) and the compiled addon script (.gd) side by side.
## Sine behavior (event-sheet parity)
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "Node2D"
	sheet.custom_class_name = "SineBehavior"
	sheet.addon_category = "Sine"
	sheet.ace_expose_all_mode = "node"
	sheet.variables = {
		"movement": {"type": "String", "default": "horizontal", "exported": true, "options": ["horizontal", "vertical", "forwards-backwards", "size", "angle", "opacity", "value-only"], "description": "Which host property the wave drives - position, size, angle, opacity, or value-only."},
		"wave": {"type": "String", "default": "sine", "exported": true, "options": ["sine", "triangle", "sawtooth", "reverse-sawtooth", "square"], "description": "Waveform shape of the oscillation - sine, triangle, sawtooth, reverse-sawtooth, or square."},
		"period": {"type": "float", "default": 4.0, "exported": true, "description": "Seconds for one full wave cycle."},
		"magnitude": {"type": "float", "default": 50.0, "exported": true, "description": "Peak strength of the oscillation (pixels, degrees, or scale/opacity factor by movement)."},
		"phase_degrees": {"type": "float", "default": 0.0, "exported": true, "description": "Phase offset in degrees - shifts where in the cycle the wave starts."},
		"active": {"type": "bool", "default": true, "exported": true, "description": "When off, pauses the oscillation and leaves the host in place."},
		"wave_value": {"type": "float", "default": 0.0, "exported": false},
		"time": {"type": "float", "default": 0.0, "exported": false},
		"base_x": {"type": "float", "default": 0.0, "exported": false},
		"base_y": {"type": "float", "default": 0.0, "exported": false},
		"base_rotation": {"type": "float", "default": 0.0, "exported": false},
		"base_scale_x": {"type": "float", "default": 1.0, "exported": false},
		"base_scale_y": {"type": "float", "default": 1.0, "exported": false},
		"base_alpha": {"type": "float", "default": 1.0, "exported": false},
		"base_captured": {"type": "bool", "default": false, "exported": false}
	}
	var about: CommentRow = CommentRow.new()
	about.text = "Sine behavior (event-sheet parity): wave-driven oscillation. movement: horizontal, vertical, forwards-backwards, size, angle, opacity, value-only. wave: sine, triangle, sawtooth, reverse-sawtooth, square. Read the current wave via $SineBehavior.wave_value."
	sheet.events.append(about)
	var extra_block_0: RawCodeRow = RawCodeRow.new()
	extra_block_0.code = "\n".join(PackedStringArray([
		"## @ace_hidden",
		"func _wave(t: float) -> float:",
		"\tvar cycle := fposmod(t, 1.0)",
		"\tmatch wave:",
		"\t\t\"triangle\":",
		"\t\t\treturn 1.0 - 4.0 * absf(cycle - 0.5)",
		"\t\t\"sawtooth\":",
		"\t\t\treturn 2.0 * cycle - 1.0",
		"\t\t\"reverse-sawtooth\":",
		"\t\t\treturn 1.0 - 2.0 * cycle",
		"\t\t\"square\":",
		"\t\t\treturn 1.0 if cycle < 0.5 else -1.0",
		"\treturn sin(cycle * TAU)"
	]))
	sheet.events.append(extra_block_0)
	var extra_block_1: RawCodeRow = RawCodeRow.new()
	extra_block_1.code = "\n".join(PackedStringArray([
		"## @ace_hidden",
		"static func editor_preview_sample(params: Dictionary, base: Dictionary, time: float) -> Dictionary:",
		"\t# Editor-preview contract (Tools > Preview Behaviors on Selected Node): pure wave math over",
		"\t# the Inspector values, so the editor can animate the host without running the behavior.",
		"\tif not bool(params.get(\"active\", true)):",
		"\t\treturn {}",
		"\tvar t := time / maxf(float(params.get(\"period\", 4.0)), 0.001) + float(params.get(\"phase_degrees\", 0.0)) / 360.0",
		"\tvar cycle := fposmod(t, 1.0)",
		"\tvar value := sin(cycle * TAU)",
		"\tmatch str(params.get(\"wave\", \"sine\")):",
		"\t\t\"triangle\":",
		"\t\t\tvalue = 1.0 - 4.0 * absf(cycle - 0.5)",
		"\t\t\"sawtooth\":",
		"\t\t\tvalue = 2.0 * cycle - 1.0",
		"\t\t\"reverse-sawtooth\":",
		"\t\t\tvalue = 1.0 - 2.0 * cycle",
		"\t\t\"square\":",
		"\t\t\tvalue = 1.0 if cycle < 0.5 else -1.0",
		"\tvar magnitude := float(params.get(\"magnitude\", 50.0))",
		"\tvar offset := value * magnitude",
		"\tvar base_position: Vector2 = base.get(\"position\", Vector2.ZERO)",
		"\tvar base_rot := float(base.get(\"rotation\", 0.0))",
		"\tmatch str(params.get(\"movement\", \"horizontal\")):",
		"\t\t\"horizontal\":",
		"\t\t\treturn {\"position\": base_position + Vector2(offset, 0.0)}",
		"\t\t\"vertical\":",
		"\t\t\treturn {\"position\": base_position + Vector2(0.0, offset)}",
		"\t\t\"forwards-backwards\":",
		"\t\t\treturn {\"position\": base_position + Vector2.from_angle(base_rot) * offset}",
		"\t\t\"size\":",
		"\t\t\tvar base_scale: Vector2 = base.get(\"scale\", Vector2.ONE)",
		"\t\t\treturn {\"scale\": base_scale * (1.0 + value * magnitude * 0.01)}",
		"\t\t\"angle\":",
		"\t\t\treturn {\"rotation\": base_rot + offset * 0.0174533}",
		"\t\t\"opacity\":",
		"\t\t\tvar color: Color = base.get(\"modulate\", Color.WHITE)",
		"\t\t\tcolor.a = clampf(color.a + value * magnitude * 0.01, 0.0, 1.0)",
		"\t\t\treturn {\"modulate\": color}",
		"\treturn {}"
	]))
	sheet.events.append(extra_block_1)
	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"
	tick.trigger_id = "OnProcess"
	var tick_body: RawCodeRow = RawCodeRow.new()
	tick_body.code = "\n".join(PackedStringArray([
		"if not active or host == null:",
		"\treturn",
		"if not base_captured:",
		"\tupdate_initial_state()",
		"time += delta",
		"var t := time / maxf(period, 0.001) + phase_degrees / 360.0",
		"wave_value = _wave(t)",
		"var offset := wave_value * magnitude",
		"if movement == \"horizontal\":",
		"\thost.position.x = base_x + offset",
		"elif movement == \"vertical\":",
		"\thost.position.y = base_y + offset",
		"elif movement == \"forwards-backwards\":",
		"\thost.position = Vector2(base_x, base_y) + Vector2.from_angle(base_rotation) * offset",
		"elif movement == \"size\":",
		"\thost.scale = Vector2(base_scale_x, base_scale_y) * (1.0 + wave_value * magnitude * 0.01)",
		"elif movement == \"angle\":",
		"\thost.rotation = base_rotation + offset * 0.0174533",
		"elif movement == \"opacity\":",
		"\thost.modulate.a = clampf(base_alpha + wave_value * magnitude * 0.01, 0.0, 1.0)"
	]))
	tick.actions.append(tick_body)
	sheet.events.append(tick)

	var set_sine_active_fn: EventFunction = EventFunction.new()
	set_sine_active_fn.function_name = "set_sine_active"
	set_sine_active_fn.expose_as_ace = true
	set_sine_active_fn.ace_display_name = "Set Sine Active"
	set_sine_active_fn.ace_category = "Sine"
	set_sine_active_fn.description = "Pauses or resumes the oscillation."
	var set_sine_active_fn_is_active: ACEParam = ACEParam.new()
	set_sine_active_fn_is_active.id = "is_active"
	set_sine_active_fn_is_active.type_name = "bool"
	set_sine_active_fn.params.append(set_sine_active_fn_is_active)
	var set_sine_active_fn_body: RawCodeRow = RawCodeRow.new()
	set_sine_active_fn_body.code = "\n".join(PackedStringArray([
		"active = is_active"
	]))
	set_sine_active_fn.events.append(set_sine_active_fn_body)
	sheet.functions.append(set_sine_active_fn)

	var update_initial_state_fn: EventFunction = EventFunction.new()
	update_initial_state_fn.function_name = "update_initial_state"
	update_initial_state_fn.expose_as_ace = true
	update_initial_state_fn.ace_display_name = "Update Initial State"
	update_initial_state_fn.ace_category = "Sine"
	update_initial_state_fn.description = "Re-captures the host's current position/scale/angle/opacity as the wave's base (updateInitialState)."
	var update_initial_state_fn_body: RawCodeRow = RawCodeRow.new()
	update_initial_state_fn_body.code = "\n".join(PackedStringArray([
		"if host == null:",
		"\treturn",
		"base_x = host.position.x",
		"base_y = host.position.y",
		"base_rotation = host.rotation",
		"base_scale_x = host.scale.x",
		"base_scale_y = host.scale.y",
		"base_alpha = host.modulate.a",
		"base_captured = true"
	]))
	update_initial_state_fn.events.append(update_initial_state_fn_body)
	sheet.functions.append(update_initial_state_fn)

	var set_sine_phase_fn: EventFunction = EventFunction.new()
	set_sine_phase_fn.function_name = "set_sine_phase"
	set_sine_phase_fn.expose_as_ace = true
	set_sine_phase_fn.ace_display_name = "Set Phase"
	set_sine_phase_fn.ace_category = "Sine"
	set_sine_phase_fn.description = "Phase offset in degrees."
	var set_sine_phase_fn_degrees: ACEParam = ACEParam.new()
	set_sine_phase_fn_degrees.id = "degrees"
	set_sine_phase_fn_degrees.type_name = "float"
	set_sine_phase_fn.params.append(set_sine_phase_fn_degrees)
	var set_sine_phase_fn_body: RawCodeRow = RawCodeRow.new()
	set_sine_phase_fn_body.code = "\n".join(PackedStringArray([
		"phase_degrees = degrees"
	]))
	set_sine_phase_fn.events.append(set_sine_phase_fn_body)
	sheet.functions.append(set_sine_phase_fn)

	var reset_sine_fn: EventFunction = EventFunction.new()
	reset_sine_fn.function_name = "reset_sine"
	reset_sine_fn.expose_as_ace = true
	reset_sine_fn.ace_display_name = "Reset Sine"
	reset_sine_fn.ace_category = "Sine"
	reset_sine_fn.description = "Restarts the wave from the current state."
	var reset_sine_fn_body: RawCodeRow = RawCodeRow.new()
	reset_sine_fn_body.code = "\n".join(PackedStringArray([
		"time = 0.0",
		"base_captured = false"
	]))
	reset_sine_fn.events.append(reset_sine_fn_body)
	sheet.functions.append(reset_sine_fn)

	return Lib.save_pack(sheet, "res://eventsheet_addons/sine/sine_behavior")
