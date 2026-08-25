# The controls reading: a stick, a gamepad and a sensor in the words the Gamepad
# and Touch objects already use, and the exact-match check spelled out.
#
# Every check pins the exact TEXT a row shows.
@tool
class_name ControlsReadingTest
extends RefCounted


static func run() -> bool:
	var passed: bool = true
	passed = _check_analog_values() and passed
	passed = _check_sensor_values() and passed
	passed = _check_value_objects() and passed
	passed = _check_exact_match_condition() and passed
	return passed


## The stick, the gamepad's name, and how many are plugged in.
static func _check_analog_values() -> bool:
	var passed: bool = _pin("a stick read names its axis the way the Gamepad object does",
		EventSheetSentence.expression_text("Input.get_joy_axis(0, JOY_AXIS_LEFT_X)"),
		"axis Left analog X of gamepad 0")
	passed = _pin("a trigger read says trigger",
		EventSheetSentence.expression_text("Input.get_joy_axis(1, JOY_AXIS_TRIGGER_RIGHT)"),
		"axis Right trigger of gamepad 1") and passed
	passed = _pin("a gamepad's name reads as its number",
		EventSheetSentence.expression_text("Input.get_joy_name(0)"), "name of gamepad 0") and passed
	passed = _pin("how many gamepads are plugged in",
		EventSheetSentence.expression_text("Input.get_connected_joypads().size()"),
		"gamepad count") and passed
	passed = _pin("a computed axis keeps its code, because it has no word to print",
		EventSheetSentence.expression_text("Input.get_joy_axis(0, chosen_axis)"),
		"Input.get_joy_axis(0, chosen_axis)") and passed
	return passed


## The four sensors.
static func _check_sensor_values() -> bool:
	var passed: bool = _pin("the accelerometer reads as acceleration",
		EventSheetSentence.expression_text("Input.get_accelerometer()"), "acceleration")
	passed = _pin("gravity reads as gravity",
		EventSheetSentence.expression_text("Input.get_gravity()"), "gravity") and passed
	passed = _pin("the gyroscope reads as a rotation rate",
		EventSheetSentence.expression_text("Input.get_gyroscope()"), "rotation rate") and passed
	passed = _pin("the magnetometer reads as a magnetic field",
		EventSheetSentence.expression_text("Input.get_magnetometer()"), "magnetic field") and passed
	return passed


## Which object each of these values belongs to - the column a reader scans.
static func _check_value_objects() -> bool:
	var passed: bool = _pin("a sensor is the Touch object's",
		EventSheetSentence.value_object("Input.get_accelerometer()"), "Touch")
	passed = _pin("a stick is the Gamepad object's",
		EventSheetSentence.value_object("Input.get_joy_axis(0, JOY_AXIS_LEFT_X)"), "Gamepad") and passed
	passed = _pin("the connected pads are the Gamepad object's",
		EventSheetSentence.value_object("Input.get_connected_joypads().size()"), "Gamepad") and passed
	passed = _pin("a key read is still the Keyboard's",
		EventSheetSentence.value_object("Input.is_key_pressed(KEY_SPACE)"), "Keyboard") and passed
	return passed


## `Input.is_action_pressed("accelerate", true)`. The bare `true` is the one flag in this
## vocabulary that means nothing to a reader until it is spelled out.
static func _check_exact_match_condition() -> bool:
	var reading: Dictionary = EventSheetSentence.condition("Input.is_action_pressed(\"accelerate\", true)")
	var passed: bool = _pin("the exact-match check says so, on the Gamepad object",
		"%s ▸ %s" % [str(reading.get("object", "")), _segments_text(reading)],
		"Gamepad ▸ Is button down \"accelerate\" (exact match)")
	var plain: Dictionary = EventSheetSentence.condition("Input.is_action_pressed(\"jump\")")
	passed = _pin("the ordinary check is untouched",
		_segments_text(plain), "\"jump\" is down") and passed
	return passed


static func _segments_text(reading: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for entry: Variant in reading.get("segments", []):
		parts.append(str((entry as Dictionary).get("text", "")))
	return "".join(parts)


static func _pin(label: String, actual: String, expected: String) -> bool:
	if actual == expected:
		print("[PASS] controls_reading_test: %s" % label)
		return true
	print("[FAIL] controls_reading_test: %s -> %s (expected %s)" % [label, actual, expected])
	return false
