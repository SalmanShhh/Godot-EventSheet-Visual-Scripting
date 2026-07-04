# Pack builder - sine_3d (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## Sine 3D behavior (event-sheet-style)
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "Node3D"
	sheet.custom_class_name = "Sine3DBehavior"
	sheet.addon_category = "Sine 3D"
	sheet.ace_expose_all_mode = "node"
	sheet.variables = {
		"movement": {"type": "String", "default": "y", "exported": true, "options": ["x", "y", "z", "rotation-y"]},
		"wave": {"type": "String", "default": "sine", "exported": true, "options": ["sine", "triangle", "sawtooth", "reverse-sawtooth", "square"]},
		"period": {"type": "float", "default": 4.0, "exported": true},
		"magnitude": {"type": "float", "default": 2.0, "exported": true},
		"phase_degrees": {"type": "float", "default": 0.0, "exported": true},
		"active": {"type": "bool", "default": true, "exported": true},
		"time": {"type": "float", "default": 0.0, "exported": false},
		"base_x": {"type": "float", "default": 0.0, "exported": false},
		"base_y": {"type": "float", "default": 0.0, "exported": false},
		"base_z": {"type": "float", "default": 0.0, "exported": false},
		"base_rot_y": {"type": "float", "default": 0.0, "exported": false},
		"base_captured": {"type": "bool", "default": false, "exported": false}
	}
	var about: CommentRow = CommentRow.new()
	about.text = "Sine 3D behavior (event-sheet-style): oscillates the host along an axis (x, y, z) or around the Y axis (rotation-y), with the full wave set."
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
	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"
	tick.trigger_id = "OnProcess"
	var tick_body: RawCodeRow = RawCodeRow.new()
	tick_body.code = "\n".join(PackedStringArray([
		"if not active or host == null:",
		"\treturn",
		"if not base_captured:",
		"\tbase_x = host.position.x",
		"\tbase_y = host.position.y",
		"\tbase_z = host.position.z",
		"\tbase_rot_y = host.rotation.y",
		"\tbase_captured = true",
		"time += delta",
		"var t := time / maxf(period, 0.001) + phase_degrees / 360.0",
		"var offset := _wave(t) * magnitude",
		"if movement == \"x\":",
		"\thost.position.x = base_x + offset",
		"elif movement == \"y\":",
		"\thost.position.y = base_y + offset",
		"elif movement == \"z\":",
		"\thost.position.z = base_z + offset",
		"elif movement == \"rotation-y\":",
		"\thost.rotation.y = base_rot_y + offset * 0.0174533"
	]))
	tick.actions.append(tick_body)
	sheet.events.append(tick)

	var set_sine3d_active_fn: EventFunction = EventFunction.new()
	set_sine3d_active_fn.function_name = "set_sine3d_active"
	set_sine3d_active_fn.expose_as_ace = true
	set_sine3d_active_fn.ace_display_name = "Set Sine 3D Active"
	set_sine3d_active_fn.ace_category = "Sine 3D"
	set_sine3d_active_fn.description = "Pauses or resumes the oscillation."
	var set_sine3d_active_fn_is_active: ACEParam = ACEParam.new()
	set_sine3d_active_fn_is_active.id = "is_active"
	set_sine3d_active_fn_is_active.type_name = "bool"
	set_sine3d_active_fn.params.append(set_sine3d_active_fn_is_active)
	var set_sine3d_active_fn_body: RawCodeRow = RawCodeRow.new()
	set_sine3d_active_fn_body.code = "\n".join(PackedStringArray([
		"active = is_active"
	]))
	set_sine3d_active_fn.events.append(set_sine3d_active_fn_body)
	sheet.functions.append(set_sine3d_active_fn)

	var set_sine3d_phase_fn: EventFunction = EventFunction.new()
	set_sine3d_phase_fn.function_name = "set_sine3d_phase"
	set_sine3d_phase_fn.expose_as_ace = true
	set_sine3d_phase_fn.ace_display_name = "Set Phase"
	set_sine3d_phase_fn.ace_category = "Sine 3D"
	set_sine3d_phase_fn.description = "Phase offset in degrees."
	var set_sine3d_phase_fn_degrees: ACEParam = ACEParam.new()
	set_sine3d_phase_fn_degrees.id = "degrees"
	set_sine3d_phase_fn_degrees.type_name = "float"
	set_sine3d_phase_fn.params.append(set_sine3d_phase_fn_degrees)
	var set_sine3d_phase_fn_body: RawCodeRow = RawCodeRow.new()
	set_sine3d_phase_fn_body.code = "\n".join(PackedStringArray([
		"phase_degrees = degrees"
	]))
	set_sine3d_phase_fn.events.append(set_sine3d_phase_fn_body)
	sheet.functions.append(set_sine3d_phase_fn)

	var reset_sine3d_fn: EventFunction = EventFunction.new()
	reset_sine3d_fn.function_name = "reset_sine3d"
	reset_sine3d_fn.expose_as_ace = true
	reset_sine3d_fn.ace_display_name = "Reset Sine 3D"
	reset_sine3d_fn.ace_category = "Sine 3D"
	reset_sine3d_fn.description = "Restarts the wave from the current state."
	var reset_sine3d_fn_body: RawCodeRow = RawCodeRow.new()
	reset_sine3d_fn_body.code = "\n".join(PackedStringArray([
		"time = 0.0",
		"base_captured = false"
	]))
	reset_sine3d_fn.events.append(reset_sine3d_fn_body)
	sheet.functions.append(reset_sine3d_fn)

	return Lib.save_pack(sheet, "res://eventsheet_addons/sine_3d/sine_3d_behavior")
