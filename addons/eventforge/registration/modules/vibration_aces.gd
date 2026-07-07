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

	descriptors.append(F.make_descriptor("Core", "VibrationStopJoy", "Stop Gamepad Vibration", ACEDescriptor.ACEType.ACTION, "Input.stop_joy_vibration({device})", "", [F.make_param("device", "int", "0", "Device", "Gamepad number (0 = the first controller).", "expression")], CAT, "stop vibration on gamepad {device}")
		.described("Stops a gamepad rumble that is still running."))
	descriptors.append(F.make_descriptor("Core", "VibrationHandheld", "Vibrate Phone", ACEDescriptor.ACEType.ACTION, "Input.vibrate_handheld({duration_ms})", "", [F.make_param("duration_ms", "int", "200", "Duration (ms)", "How long to buzz, in milliseconds.", "expression")], CAT, "vibrate phone for {duration_ms}ms")
		.described("Buzzes a handheld device (phone / tablet) for a moment. Does nothing on desktop."))
	descriptors.append(F.make_descriptor("Core", "VibrationJoyStrength", "Gamepad Vibration Strength", ACEDescriptor.ACEType.EXPRESSION, "Input.get_joy_vibration_strength({device})", "", [F.make_param("device", "int", "0", "Device", "Gamepad number (0 = the first controller).", "expression")], CAT, "gamepad {device} vibration strength")
		.described("The current rumble strength of a gamepad as a Vector2 (weak, strong motor)."))

	return descriptors


static func section_descriptions() -> Dictionary:
	return {CAT: "Rumble a gamepad or buzz a phone, and stop it again."}
