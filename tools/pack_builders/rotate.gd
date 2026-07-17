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
	sheet.host_class = "Node"
	sheet.custom_class_name = "RotateBehavior"
	sheet.class_description = "Constant rotation for the host node: spins at Speed in degrees per second, optionally ramping by Acceleration, with one Rotation Type knob covering a 2D node's rotation and a 3D node's X, Y, or Z axis. Previewable in the editor via Tools > Preview Behaviors on Selected Node, no game run needed."
	sheet.addon_category = "Rotate"
	sheet.addon_tags = PackedStringArray(["movement", "visual"])
	var about: CommentRow = CommentRow.new()
	about.text = "Rotate behavior (event-sheet parity): spins the host at Speed degrees/second, ramping by Acceleration. Rotation Type covers a 2D node's rotation and a 3D node's X, Y, or Z axis - one pack for pickups, fans, planets, and drills. Set Rotation Enabled toggles it; Reverse flips direction. Previewable in the editor (Tools > Preview Behaviors on Selected Node). This pack is an event sheet - extend it by editing it."
	sheet.events.append(about)
	var block: RawCodeRow = RawCodeRow.new()
	block.code = "\n".join(PackedStringArray([
		"# --- Designer knobs (tune in the Inspector) ---",
		"## Spin on/off - Set Rotation Enabled flips it at runtime.",
		"@export var rotate_enabled: bool = true",
		"## Rotation speed in degrees per second (negative = the other way).",
		"@export var speed: float = 90.0",
		"## Speed change in degrees per second, per second (0 = constant speed).",
		"@export var acceleration: float = 0.0",
		"## What to spin: a Node2D's rotation, or a Node3D's X / Y / Z axis.",
		"@export_enum(\"2d\", \"x\", \"y\", \"z\") var rotation_type: String = \"2d\"",
		"",
		"# --- Internal state ---",
		"# The live speed (deg/s) - starts at the Speed knob, then Acceleration ramps it.",
		"var _current_speed: float = 0.0",
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
		"## @ace_param_options(type 2d, x, y, z)",
		"func set_rotation_type(type: String) -> void:",
		"\tif type in [\"2d\", \"x\", \"y\", \"z\"]:",
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
		"\tspeed = _current_speed",
		"",
		"# Editor-preview contract (Tools > Preview Behaviors on Selected Node): pure angle math",
		"# over the Inspector values - angle(t) = speed*t + accel*t^2/2 - so the editor animates",
		"# the spin without running the behavior. Handles a Node2D's float rotation AND a",
		"# Node3D's Vector3 rotation from the same sample.",
		"static func editor_preview_sample(params: Dictionary, base: Dictionary, time: float) -> Dictionary:",
		"\tif not bool(params.get(\"rotate_enabled\", true)):",
		"\t\treturn {}",
		"\tvar angle: float = deg_to_rad(float(params.get(\"speed\", 90.0)) * time + 0.5 * float(params.get(\"acceleration\", 0.0)) * time * time)",
		"\tvar base_rotation: Variant = base.get(\"rotation\", 0.0)",
		"\tvar type: String = str(params.get(\"rotation_type\", \"2d\"))",
		"\tif type == \"2d\" and (base_rotation is float or base_rotation is int):",
		"\t\treturn {\"rotation\": float(base_rotation) + angle}",
		"\tif base_rotation is Vector3:",
		"\t\tvar euler: Vector3 = base_rotation",
		"\t\tmatch type:",
		"\t\t\t\"x\":",
		"\t\t\t\treturn {\"rotation\": euler + Vector3(angle, 0.0, 0.0)}",
		"\t\t\t\"y\":",
		"\t\t\t\treturn {\"rotation\": euler + Vector3(0.0, angle, 0.0)}",
		"\t\t\t\"z\":",
		"\t\t\t\treturn {\"rotation\": euler + Vector3(0.0, 0.0, angle)}",
		"\treturn {}"
	]))
	sheet.events.append(block)
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
		"if rotation_type == \"2d\" and host is Node2D:",
		"\t(host as Node2D).rotation += step",
		"elif host is Node3D:",
		"\tmatch rotation_type:",
		"\t\t\"x\":",
		"\t\t\t(host as Node3D).rotation.x += step",
		"\t\t\"y\":",
		"\t\t\t(host as Node3D).rotation.y += step",
		"\t\t\"z\":",
		"\t\t\t(host as Node3D).rotation.z += step"
	]))
	tick.actions.append(tick_body)
	sheet.events.append(tick)

	return Lib.save_pack(sheet, "res://eventsheet_addons/rotate/rotate_behavior")
