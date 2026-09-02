# EventForge module - Vibration vocabulary (rumble a gamepad, buzz a phone).
#
# The vibration pieces beyond starting a gamepad rumble (which the input vocabulary covers as Vibrate
# Gamepad): stop it, buzz a handheld device, and read the current rumble strength. They compile to
# plain Godot (Input) with zero plugin references. Grouped under "Vibration".
@tool
class_name EventForgeVibrationACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

const CAT := "Vibration"


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	descriptors.append(F.act("VibrationStopJoy", "Stop Gamepad Vibration", "Input.stop_joy_vibration({device})", CAT, "stop vibration on gamepad {device}", "Stops a gamepad rumble that is still running.").param_typed("int", "device", "0", "Device", "Gamepad number (0 = the first controller).", "expression"))
	descriptors.append(F.act("VibrationHandheld", "Vibrate Phone", "Input.vibrate_handheld({duration_ms})", CAT, "vibrate phone for {duration_ms}ms", "Buzzes a handheld device (phone / tablet) for a moment. Does nothing on desktop.").param_typed("int", "duration_ms", "200", "Duration (ms)", "How long to buzz, in milliseconds.", "expression"))
	descriptors.append(F.expr("VibrationJoyStrength", "Gamepad Vibration Strength", "Input.get_joy_vibration_strength({device})", CAT, "gamepad {device} vibration strength", "The current rumble strength of a gamepad as a Vector2 (weak, strong motor).").param_typed("int", "device", "0", "Device", "Gamepad number (0 = the first controller).", "expression"))

	return descriptors


static func section_descriptions() -> Dictionary:
	return {CAT: "Rumble a gamepad or buzz a phone, and stop it again."}
