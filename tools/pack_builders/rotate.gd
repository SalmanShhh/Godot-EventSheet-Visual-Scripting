# Pack builder - rotate (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## Rotate: the event-sheet-parity constant-rotation behavior - attach and the host spins at
## Speed (degrees/second), optionally ramping by Acceleration. One Rotation Type knob covers
## 2D nodes and all three 3D axes, one action toggles it, and the editor preview animates the
## spin without running the game.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.previews = true
	sheet.host_class = "Node"
	sheet.custom_class_name = "RotateBehavior"
	sheet.class_description = "Constant rotation for the host node: spins at Speed in degrees per second, optionally ramping by Acceleration, with one Rotation Type knob covering a 2D node's rotation and a 3D node's X, Y, or Z axis. Previewable in the editor with the Preview button in the Inspector, no game run needed."
	sheet.addon_category = "Rotate"
	sheet.addon_tags = PackedStringArray(["movement", "visual"])
	var about: CommentRow = CommentRow.new()
	about.text = "Rotate behavior (event-sheet parity): spins the host at Speed degrees/second, ramping by Acceleration. Rotation Type covers a 2D node's rotation and a 3D node's X, Y, or Z axis - one pack for pickups, fans, planets, and drills. Set Rotation Enabled toggles it; Reverse flips direction. Previewable in the editor with the Preview button in the Inspector. This pack is an event sheet - extend it by editing it."
	sheet.events.append(about)
	var block: RawCodeRow = RawCodeRow.new()
	block.code = "\n".join(PackedStringArray([
		"# --- Choices (the stored words are the promise: saved scenes keep them) ---",
		"## rotation_type: spin a Node2D by its rotation.",
		"const ROTATION_TYPE_2D := \"2d\"",
		"## rotation_type: spin a Node3D about its x axis.",
		"const ROTATION_TYPE_X := \"x\"",
		"## rotation_type: spin a Node3D about its y axis.",
		"const ROTATION_TYPE_Y := \"y\"",
		"## rotation_type: spin a Node3D about its z axis.",
		"const ROTATION_TYPE_Z := \"z\"",
		"",
		"# --- Designer knobs (tune in the Inspector) ---",
		"## Spin on/off - Set Rotation Enabled flips it at runtime.",
		"@export var rotate_enabled: bool = true:",
		"\tset(value):",
		"\t\trotate_enabled = value",
		"\t\t# Every write lands here - a sheet's Set Rotate Enabled action, the Inspector, another",
		"\t\t# script - so the physics frame follows the spin whoever switched it, not just the",
		"\t\t# Set Rotation Enabled row.",
		"\t\tset_physics_process(value)",
		"## Rotation speed in degrees per second (negative = the other way).",
		"@export var speed: float = 90.0",
		"## Speed change in degrees per second, per second (0 = constant speed).",
		"@export var acceleration: float = 0.0",
		"## What to spin: a Node2D's rotation, or a Node3D's X / Y / Z axis.",
		"@export_enum(\"2d\", \"x\", \"y\", \"z\") var rotation_type: String = \"2d\"",
		"",
		"# --- Internal state ---",
		"# The live speed (deg/s) - starts at the Speed knob, then Acceleration ramps it.",
		"## Rotation speed now, in degrees per second, easing toward the target speed.",
		"var _current_speed: float = 0.0",
		"## True once the current speed has been set from the Inspector.",
		"var _speed_primed: bool = false",
		"",
		"## @ace_condition",
		"## @ace_name(\"Is Rotating\")",
		"func is_rotating() -> bool:",
		"\treturn rotate_enabled and absf(_current_speed if _speed_primed else speed) > 0.001",
		"",
		"## @ace_expression",
		"## @ace_name(\"Rotation Speed\")",
		"func rotation_speed() -> float:",
		"\treturn _current_speed if _speed_primed else speed",
		"",
		"## Turns the spin on or off - the pause/resume toggle.",
		"## @ace_action",
		"## @ace_name(\"Set Rotation Enabled\")",
		"func set_rotation_enabled(enabled: bool) -> void:",
		"\trotate_enabled = enabled",
		"\t# A stopped spin costs nothing per physics frame; turning it back on restores the tick.",
		"\tset_physics_process(enabled)",
		"",
		"## Sets the live rotation speed in degrees per second (negative = the other way).",
		"## @ace_action",
		"## @ace_name(\"Set Rotation Speed\")",
		"func set_rotation_speed(degrees_per_second: float) -> void:",
		"\tspeed = degrees_per_second",
		"\t_current_speed = degrees_per_second",
		"\t_speed_primed = true",
		"",
		"## Sets the acceleration in degrees per second, per second (0 = constant).",
		"## @ace_action",
		"## @ace_name(\"Set Rotation Acceleration\")",
		"func set_rotation_acceleration(degrees_per_second_squared: float) -> void:",
		"\tacceleration = degrees_per_second_squared",
		"",
		"## Switches what spins: a Node2D's rotation, or a Node3D's X / Y / Z axis.",
		"## @ace_action",
		"## @ace_name(\"Set Rotation Type\")",
		"## @ace_param_options(type 2d=2D rotation, x=3D X axis, y=3D Y axis, z=3D Z axis)",
		# The type is a WORD picked off the dropdown above, and a dropdown key is inserted into the
		# call verbatim - so the quotes belong in the TEMPLATE, never in the key (a quoted key does
		# not survive the annotation round trip). Without them a row picking 3D Y axis asked
		# `set_rotation_type(y)`, an undefined identifier, and the game did not parse - and picking
		# 2D rotation asked it with `2d`, which is not even a name GDScript could resolve.
		"## @ace_codegen_template(\"$RotateBehavior.set_rotation_type(\"{type}\")\")",
		"func set_rotation_type(type: String) -> void:",
		"\tif type in [ROTATION_TYPE_2D, ROTATION_TYPE_X, ROTATION_TYPE_Y, ROTATION_TYPE_Z]:",
		"\t\trotation_type = type",
		"",
		"## Flips the spin direction (negates the live speed).",
		"## @ace_action",
		"## @ace_name(\"Reverse Rotation\")",
		"func reverse_rotation() -> void:",
		"\tif not _speed_primed:",
		"\t\t_current_speed = speed",
		"\t\t_speed_primed = true",
		"\t_current_speed = -_current_speed",
		"\tspeed = _current_speed"
	]))
	sheet.events.append(block)
	var ready_row: EventRow = EventRow.new()
	ready_row.trigger_provider_id = "Core"
	ready_row.trigger_id = "OnReady"
	var ready_body: RawCodeRow = RawCodeRow.new()
	ready_body.code = "\n".join(PackedStringArray([
		"# Physics processing runs only while the spin does - a host authored with Spin off costs",
		"# nothing per frame until Set Rotation Enabled turns it on. Speed is deliberately not part",
		"# of this test: Acceleration can ramp a spin up from a standing start.",
		"set_physics_process(rotate_enabled)"
	]))
	ready_row.actions.append(ready_body)
	sheet.events.append(ready_row)
	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"
	tick.trigger_id = "OnPhysicsProcess"
	var tick_body: RawCodeRow = RawCodeRow.new()
	tick_body.code = "\n".join(PackedStringArray([
		"if not rotate_enabled or host == null:",
		"\treturn",
		"if not _speed_primed:",
		"\t_current_speed = speed",
		"\t_speed_primed = true",
		"_current_speed += acceleration * delta",
		"var step: float = deg_to_rad(_current_speed * delta)",
		"# Type-safe spin: a mismatched host (rotation_type \"2d\" on a Node3D) is a no-op,",
		"# never an error - swap the knob or the parent freely.",
		"if rotation_type == ROTATION_TYPE_2D and host is Node2D:",
		"\t(host as Node2D).rotation += step",
		"elif host is Node3D:",
		"\tmatch rotation_type:",
		"\t\tROTATION_TYPE_X:",
		"\t\t\t(host as Node3D).rotation.x += step",
		"\t\tROTATION_TYPE_Y:",
		"\t\t\t(host as Node3D).rotation.y += step",
		"\t\tROTATION_TYPE_Z:",
		"\t\t\t(host as Node3D).rotation.z += step"
	]))
	tick.actions.append(tick_body)
	sheet.events.append(tick)

	return Lib.save_pack(sheet, "res://eventsheet_addons/rotate/rotate_behavior")
