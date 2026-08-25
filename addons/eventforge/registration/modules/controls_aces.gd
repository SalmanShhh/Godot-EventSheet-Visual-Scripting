# EventForge module - Controls: analog, gamepads by number, touch and gestures,
# rebinding at runtime, simulated input and handheld sensors.
#
# The device vocabulary (device_aces.gd) says whether a key or a button is down. These are the
# sentences the sheet needs for everything AROUND that: how far a stick is pushed on the Gamepad
# object's 0-100 / -100-100 scale, which numbered gamepad a button came from, a finger's drag and
# pinch and pan, the five steps of a rebind screen, an AI pressing a control the way a player would,
# and the sensors a phone has. They compile to plain Godot (Input, InputMap, ConfigFile) with zero
# plugin references.
#
# Every template here is the exact bytes ordinary hand-written Godot writes for the same idea, which
# is what lets an opened script read back as these rows: the importer's reverse index is built from
# these very strings.
#
# Module contract: see ace_factory.gd - ace_ids/templates are API (compatibility
# covenant); this file only changes where the descriptors are AUTHORED.
@tool
class_name EventForgeControlsACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

const GAMEPAD := "Gamepad"
const KEYBOARD := "Keyboard"
const MOUSE := "Mouse"
const TOUCH := "Touch"
const SYSTEM := "General Actions"

## The Gamepad object's own axis names, in the order its picker lists them. The value written is
## Godot's constant; the label is the word the sheet reads.
const AXIS_OPTIONS: Array = [
	{"key": "JOY_AXIS_LEFT_X", "label": "Left analog X"},
	{"key": "JOY_AXIS_LEFT_Y", "label": "Left analog Y"},
	{"key": "JOY_AXIS_RIGHT_X", "label": "Right analog X"},
	{"key": "JOY_AXIS_RIGHT_Y", "label": "Right analog Y"},
	{"key": "JOY_AXIS_TRIGGER_LEFT", "label": "Left trigger"},
	{"key": "JOY_AXIS_TRIGGER_RIGHT", "label": "Right trigger"},
]

## The Gamepad object's button names, same idea.
const BUTTON_OPTIONS: Array = [
	{"key": "JOY_BUTTON_A", "label": "A"},
	{"key": "JOY_BUTTON_B", "label": "B"},
	{"key": "JOY_BUTTON_X", "label": "X"},
	{"key": "JOY_BUTTON_Y", "label": "Y"},
	{"key": "JOY_BUTTON_LEFT_SHOULDER", "label": "Left shoulder"},
	{"key": "JOY_BUTTON_RIGHT_SHOULDER", "label": "Right shoulder"},
	{"key": "JOY_BUTTON_LEFT_STICK", "label": "Left stick"},
	{"key": "JOY_BUTTON_RIGHT_STICK", "label": "Right stick"},
	{"key": "JOY_BUTTON_START", "label": "Start"},
	{"key": "JOY_BUTTON_BACK", "label": "Back"},
	{"key": "JOY_BUTTON_DPAD_UP", "label": "D-pad up"},
	{"key": "JOY_BUTTON_DPAD_DOWN", "label": "D-pad down"},
	{"key": "JOY_BUTTON_DPAD_LEFT", "label": "D-pad left"},
	{"key": "JOY_BUTTON_DPAD_RIGHT", "label": "D-pad right"},
]

## Which component of a sensor reading a tilt check is about.
const SENSOR_AXIS_OPTIONS: Array = [
	{"key": "x", "label": "X"},
	{"key": "y", "label": "Y"},
	{"key": "z", "label": "Z"},
]

## Where saved bindings live. A plain ConfigFile under user://, the same shape Remember Between Runs
## writes, so a player's remapped controls survive a restart and can be deleted by hand.
const BINDINGS_FILE := "\"user://bindings.cfg\""


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []
	_gamepad_analog(descriptors)
	_gamepads_by_number(descriptors)
	_touch_and_gestures(descriptors)
	_rebinding(descriptors)
	_simulated_input(descriptors)
	_sensors(descriptors)
	_gyro_controls(descriptors)
	return descriptors


## Analog in the Gamepad object's words. The sheet has always shown stick travel as a percent
## (0 to 100 for a trigger, -100 to 100 for a stick), so these carry the * 100 rather than making a
## reader learn that Godot counts the same thing from 0 to 1.
static func _gamepad_analog(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.make_descriptor("Core", "GamepadCompareAxis", "Compare Axis", ACEDescriptor.ACEType.CONDITION, "Input.get_joy_axis({device}, {axis}) * 100 {comparison} {value}", "", [F.make_param("axis", "String", "JOY_AXIS_LEFT_X", "Axis", "Which stick or trigger.", "", AXIS_OPTIONS), F.make_param("device", "String", "0", "Gamepad", "Gamepad number (0 = the first one).", "expression"), F.make_param("comparison", "String", ">", "Comparison", "How to compare.", "", F.COMPARISON_OPTIONS), F.make_param("value", "String", "20", "Value", "Stick travel as a percent, -100 to 100.", "expression")], GAMEPAD, "Compare axis {axis} of gamepad {device} {comparison} {value}")
		.described("How far a stick or trigger is pushed, on the -100 to 100 scale the Gamepad object shows.").featured())
	descriptors.append(F.make_descriptor("Core", "GamepadCompareAxisEitherWay", "Compare Axis (either way)", ACEDescriptor.ACEType.CONDITION, "abs(Input.get_joy_axis({device}, {axis})) * 100 {comparison} {value}", "", [F.make_param("axis", "String", "JOY_AXIS_LEFT_X", "Axis", "Which stick or trigger.", "", AXIS_OPTIONS), F.make_param("device", "String", "0", "Gamepad", "Gamepad number (0 = the first one).", "expression"), F.make_param("comparison", "String", ">", "Comparison", "How to compare.", "", F.COMPARISON_OPTIONS), F.make_param("value", "String", "20", "Value", "Stick travel as a percent, ignoring the direction.", "expression")], GAMEPAD, "Compare axis {axis} of gamepad {device} {comparison} {value} (either way)")
		.described("The same check ignoring which way the stick went - pushed this far in either direction."))
	descriptors.append(F.make_descriptor("Core", "GamepadButtonDownExact", "Is Button Down", ACEDescriptor.ACEType.CONDITION, "Input.is_action_pressed({action}, true)", "", [F.make_param("action", "String", F.default_input_action(), "Control", "The control to test.", "input_action", F.input_action_options())], GAMEPAD, "Is button down {action} (exact match)")
		.described("True while the control is held, counting only a binding that matches exactly - the way a menu tells one stick direction from another."))
	descriptors.append(F.make_descriptor("Core", "GamepadAxisPercent", "Axis Of Gamepad", ACEDescriptor.ACEType.EXPRESSION, "(Input.get_joy_axis({device}, {axis}) * 100)", "", [F.make_param("device", "String", "0", "Gamepad", "Gamepad number (0 = the first one).", "expression"), F.make_param("axis", "String", "JOY_AXIS_LEFT_X", "Axis", "Which stick or trigger.", "", AXIS_OPTIONS)], GAMEPAD, "axis {axis} of gamepad {device}")
		.described("How far a stick is pushed, -100 to 100 (Godot counts the same travel from -1 to 1).").featured())
	descriptors.append(F.make_descriptor("Core", "GamepadButtonPercent", "Button Of Gamepad", ACEDescriptor.ACEType.EXPRESSION, "(Input.get_action_strength({action}) * 100)", "", [F.make_param("action", "String", F.default_input_action(), "Control", "The control to read.", "input_action", F.input_action_options())], GAMEPAD, "how hard {action} is held")
		.described("How hard a trigger or a control is held, 0 to 100 (Godot counts the same pull from 0 to 1).").featured())


## Gamepads by number. Godot's `event.device` IS the gamepad number the sheet already counts
## from 0, so a two-player script stops reading as arithmetic.
static func _gamepads_by_number(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.make_descriptor("Core", "GamepadEventButtonPressed", "On Gamepad Button Pressed", ACEDescriptor.ACEType.CONDITION, "(event is InputEventJoypadButton and event.pressed and event.device == {device} and event.button_index == {button})", "", [F.make_param("device", "String", "0", "Gamepad", "Gamepad number (0 = the first one).", "expression"), F.make_param("button", "String", "JOY_BUTTON_A", "Button", "Which button.", "", BUTTON_OPTIONS)], GAMEPAD, "On gamepad {device} button {button} pressed")
		.described("True the moment a named gamepad's button goes down, used inside an input event - the local-multiplayer check."))
	descriptors.append(F.make_descriptor("Core", "GamepadEventButtonReleased", "On Gamepad Button Released", ACEDescriptor.ACEType.CONDITION, "(event is InputEventJoypadButton and not event.pressed and event.device == {device} and event.button_index == {button})", "", [F.make_param("device", "String", "0", "Gamepad", "Gamepad number (0 = the first one).", "expression"), F.make_param("button", "String", "JOY_BUTTON_A", "Button", "Which button.", "", BUTTON_OPTIONS)], GAMEPAD, "On gamepad {device} button {button} released")
		.described("True the moment a named gamepad's button is let go, used inside an input event."))
	descriptors.append(F.make_descriptor("Core", "GamepadHasAny", "Has Gamepads", ACEDescriptor.ACEType.CONDITION, "not Input.get_connected_joypads().is_empty()", "", [], GAMEPAD, "Has gamepads")
		.described("True while at least one gamepad is plugged in - switch the control hints, offer the join screen.").featured())
	descriptors.append(F.make_descriptor("Core", "GamepadVibrateFor", "Vibrate Gamepad For", ACEDescriptor.ACEType.ACTION, "Input.start_joy_vibration({device}, {weak}, {strong}, {seconds})", "", [F.make_param("device", "String", "0", "Gamepad", "Gamepad number (0 = the first one).", "expression"), F.make_param("weak", "String", "0.3", "Weak motor", "Weak motor, 0 to 1.", "expression"), F.make_param("strong", "String", "0.8", "Strong motor", "Strong motor, 0 to 1.", "expression"), F.make_param("seconds", "String", "0.2", "Seconds", "How long the rumble lasts.", "expression")], GAMEPAD, "Vibrate gamepad {device} for {seconds} seconds")
		.described("Rumbles one numbered gamepad for a moment - the sheet's phrasing for the thing every hit and every pickup wants."))


## Touch and gestures. Godot's InputEvent classes carry exactly what the Touch object's
## sentences say; the payload chips are the event's own fields.
static func _touch_and_gestures(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.make_descriptor("Core", "TouchDragEvent", "On Drag", ACEDescriptor.ACEType.CONDITION, "(event is InputEventScreenDrag)", "", [], TOUCH, "On drag")
		.described("True while a finger is moving across the screen, used inside an input event."))
	descriptors.append(F.make_descriptor("Core", "TouchPinchEvent", "On Pinch", ACEDescriptor.ACEType.CONDITION, "(event is InputEventMagnifyGesture)", "", [], TOUCH, "On pinch")
		.described("True on a two-finger pinch or spread, used inside an input event - zoom the map."))
	descriptors.append(F.make_descriptor("Core", "TouchPanEvent", "On Pan", ACEDescriptor.ACEType.CONDITION, "(event is InputEventPanGesture)", "", [], TOUCH, "On pan")
		.described("True on a two-finger pan (or a trackpad scroll), used inside an input event."))
	descriptors.append(F.make_descriptor("Core", "TouchIndexOf", "Touch Index", ACEDescriptor.ACEType.EXPRESSION, "event.index", "", [], TOUCH, "touch index")
		.described("Which finger this touch event is about, counting from 0 - multi-touch controls tell them apart by it."))
	descriptors.append(F.make_descriptor("Core", "TouchPinchFactor", "Pinch Factor", ACEDescriptor.ACEType.EXPRESSION, "event.factor", "", [], TOUCH, "pinch factor")
		.described("How much the pinch grew or shrank this event - multiply the zoom by it."))
	descriptors.append(F.make_descriptor("Core", "TouchPanDelta", "Pan Delta", ACEDescriptor.ACEType.EXPRESSION, "event.delta", "", [], TOUCH, "pan delta")
		.described("How far the two-finger pan moved this event, as a Vector2."))
	descriptors.append(F.make_descriptor("Core", "MouseDoubleClickEvent", "On Double-Click", ACEDescriptor.ACEType.CONDITION, "(event is InputEventMouseButton and event.double_click)", "", [], MOUSE, "On double-click")
		.described("True on the second click of a double-click, used inside an input event - open the item, rename the file."))


## Rebinding at runtime, one action per row: wait for the next key, clear, bind, reset,
## deadzone, save and load. Together they are the whole of a controls screen.
static func _rebinding(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.make_descriptor("Core", "InputWaitForNextKey", "Wait For The Next Key Or Button", ACEDescriptor.ACEType.ACTION, "var {name} = await get_window().window_input", "", [F.make_param("name", "String", "ev", "Into", "The name to remember the key or button under.", "expression")], KEYBOARD, "Wait for the next key or button into {name}")
		.described("Pauses this event until the player presses anything, and remembers what it was - the first step of every rebind screen.").featured())
	descriptors.append(F.make_descriptor("Core", "InputClearBindings", "Clear The Bindings Of", ACEDescriptor.ACEType.ACTION, "InputMap.action_erase_events({action})", "", [F.make_param("action", "String", F.default_input_action(), "Control", "The control to unbind.", "input_action", F.input_action_options())], KEYBOARD, "Clear the bindings of {action}")
		.described("Takes every key and button off a control, so the next Bind is the only one left."))
	descriptors.append(F.make_descriptor("Core", "InputBindTo", "Bind Control To", ACEDescriptor.ACEType.ACTION, "InputMap.action_add_event({action}, {event})", "", [F.make_param("action", "String", F.default_input_action(), "Control", "The control to bind.", "input_action", F.input_action_options()), F.make_param("event", "String", "event", "Key or button", "The key or button to bind, usually the one just waited for.", "expression")], KEYBOARD, "Bind {action} to {event}")
		.described("Binds a key or a button to a control - the second step of a rebind screen.").featured())
	descriptors.append(F.make_descriptor("Core", "InputKeyNameOf", "Key Name", ACEDescriptor.ACEType.EXPRESSION, "{event}.as_text()", "", [F.make_param("event", "String", "event", "Key or button", "The key or button to name.", "expression")], KEYBOARD, "name of {event}")
		.described("The readable name of a key or button (\"Space\", \"A button\") - show it next to each row of a rebind screen.").featured())
	descriptors.append(F.make_descriptor("Core", "InputResetBindings", "Reset All Bindings", ACEDescriptor.ACEType.ACTION, "InputMap.load_from_project_settings()", "", [], KEYBOARD, "Reset all bindings to the project's")
		.described("Throws away every rebind and puts the project's own Input Map back - the Reset button."))
	descriptors.append(F.make_descriptor("Core", "InputHasActionNamed", "Has Action", ACEDescriptor.ACEType.CONDITION, "InputMap.has_action({action})", "", [F.make_param("action", "String", F.default_input_action(), "Control", "The control to look for.", "input_action", F.input_action_options())], KEYBOARD, "Has action {action}")
		.described("True when the Input Map knows this control - guard a row that names one the project might not have."))
	descriptors.append(F.make_descriptor("Core", "GamepadSetDeadzoneOf", "Set Deadzone Of", ACEDescriptor.ACEType.ACTION, "InputMap.action_set_deadzone({action}, {deadzone})", "", [F.make_param("action", "String", F.default_input_action(), "Control", "The control to tune.", "input_action", F.input_action_options()), F.make_param("deadzone", "String", "0.2", "Deadzone", "Stick travel ignored before the control counts, 0 to 1.", "expression")], GAMEPAD, "Set deadzone of {action} to {deadzone}")
		.described("How far a stick must move before the control counts - the drift slider a controller options screen needs."))
	descriptors.append(F.make_descriptor("Core", "InputSaveBindings", "Save Bindings", ACEDescriptor.ACEType.ACTION, "var __bindings_{uid} = ConfigFile.new()\nfor __action_{uid} in InputMap.get_actions():\n\t__bindings_{uid}.set_value(\"bindings\", str(__action_{uid}), InputMap.action_get_events(__action_{uid}))\n__bindings_{uid}.save({path})", "", [F.make_param("path", "String", BINDINGS_FILE, "File", "Where to keep them, under user://.", "expression")], KEYBOARD, "Save bindings")
		.described("Writes every control's bindings to a plain settings file under user://, so a rebind survives a restart.").featured())
	descriptors.append(F.make_descriptor("Core", "InputLoadBindings", "Load Bindings", ACEDescriptor.ACEType.ACTION, "var __bindings_{uid} = ConfigFile.new()\nif __bindings_{uid}.load({path}) == OK:\n\tfor __action_{uid} in __bindings_{uid}.get_section_keys(\"bindings\"):\n\t\tif InputMap.has_action(__action_{uid}):\n\t\t\tInputMap.action_erase_events(__action_{uid})\n\t\t\tfor __event_{uid} in __bindings_{uid}.get_value(\"bindings\", __action_{uid}, []):\n\t\t\t\tInputMap.action_add_event(__action_{uid}, __event_{uid})", "", [F.make_param("path", "String", BINDINGS_FILE, "File", "Where they were kept, under user://.", "expression")], KEYBOARD, "Load bindings")
		.described("Puts saved bindings back on start-up. Does nothing when there is no saved file, so a first run keeps the project's own.").featured())


## Simulated input, the pointer and "stop this input here". One event per idea.
static func _simulated_input(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.make_descriptor("Core", "SimulateControlPressed", "Simulate Control Pressed", ACEDescriptor.ACEType.ACTION, "Input.action_press({action})", "", [F.make_param("action", "String", F.default_input_action(), "Control", "The control to press.", "input_action", F.input_action_options())], SYSTEM, "Simulate control {action} pressed")
		.described("Presses a control as though the player had - how an AI, a replay or a tutorial drives the same code the player does.").featured())
	descriptors.append(F.make_descriptor("Core", "SimulateControlReleased", "Simulate Control Released", ACEDescriptor.ACEType.ACTION, "Input.action_release({action})", "", [F.make_param("action", "String", F.default_input_action(), "Control", "The control to let go.", "input_action", F.input_action_options())], SYSTEM, "Simulate control {action} released")
		.described("Lets go of a control that Simulate Control Pressed is holding."))
	descriptors.append(F.make_descriptor("Core", "SimulateInputEvent", "Simulate Input", ACEDescriptor.ACEType.ACTION, "Input.parse_input_event({event})", "", [F.make_param("event", "String", "event", "Key or button", "The key, button or touch to feed in.", "expression")], SYSTEM, "Simulate input {event}")
		.described("Feeds a whole key, button or touch into the game as if it had just happened."))
	descriptors.append(F.make_descriptor("Core", "StopInputHere", "Stop This Input Here", ACEDescriptor.ACEType.ACTION, "get_viewport().set_input_as_handled()", "", [], SYSTEM, "Stop this input here", "Node")
		.described("Nothing after this event sees the key or the click - the click was for this and nothing else.").featured())
	descriptors.append(F.make_descriptor("Core", "KeyEventIsRepeat", "Key Is A Held-Down Repeat", ACEDescriptor.ACEType.CONDITION, "(event is InputEventKey and event.is_echo())", "", [], KEYBOARD, "key is a held-down repeat")
		.described("True when this key event is the operating system repeating a held key rather than a fresh press."))
	descriptors.append(F.make_descriptor("Core", "MouseRequestPointerLock", "Request Pointer Lock", ACEDescriptor.ACEType.ACTION, "Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)", "", [], MOUSE, "Request pointer lock")
		.described("Hides the cursor and locks it to the window, so mouse motion drives looking around.").featured())
	descriptors.append(F.make_descriptor("Core", "MouseCursorVisible", "Set Cursor Visible", ACEDescriptor.ACEType.ACTION, "Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)", "", [], MOUSE, "Set cursor visible")
		.described("Gives the cursor back - pause menus, dialogs, quitting to the map."))
	descriptors.append(F.make_descriptor("Core", "MouseCursorInvisible", "Set Cursor Invisible", ACEDescriptor.ACEType.ACTION, "Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)", "", [], MOUSE, "Set cursor invisible")
		.described("Hides the cursor while leaving it free to move - a game that draws its own crosshair."))
	descriptors.append(F.make_descriptor("Core", "MouseCursorConfined", "Keep Cursor Inside The Window", ACEDescriptor.ACEType.ACTION, "Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED)", "", [], MOUSE, "Keep cursor inside the window")
		.described("The cursor stays visible but cannot leave the window - strategy games on two monitors."))
	descriptors.append(F.make_descriptor("Core", "MouseMoveCursorTo", "Move Cursor To", ACEDescriptor.ACEType.ACTION, "Input.warp_mouse({position})", "", [F.make_param("position", "String", "Vector2(100, 100)", "Position", "Where in the window to put the pointer.", "expression")], MOUSE, "Move cursor to {position}")
		.described("Teleports the pointer - snap it to a menu item, re-centre it after a cutscene."))


## Handheld sensors. The four Godot exposes, in the Touch object's words. They all report zero
## on a desktop, which is said where it is needed rather than left as a surprise.
static func _sensors(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.make_descriptor("Core", "TouchAcceleration", "Acceleration", ACEDescriptor.ACEType.EXPRESSION, "Input.get_accelerometer()", "", [], TOUCH, "acceleration")
		.described("How the device is being moved right now, gravity included, as x, y, z. Reports 0 on desktop.").featured())
	descriptors.append(F.make_descriptor("Core", "TouchGravity", "Gravity Direction", ACEDescriptor.ACEType.EXPRESSION, "Input.get_gravity()", "", [], TOUCH, "gravity")
		.described("Which way is down for the device, as x, y, z - how it is being held. Reports 0 on desktop."))
	descriptors.append(F.make_descriptor("Core", "TouchRotationRate", "Rotation Rate", ACEDescriptor.ACEType.EXPRESSION, "Input.get_gyroscope()", "", [], TOUCH, "rotation rate")
		.described("How fast the device is being turned, as x, y, z (the gyroscope). Reports 0 on desktop."))
	descriptors.append(F.make_descriptor("Core", "TouchMagneticField", "Magnetic Field", ACEDescriptor.ACEType.EXPRESSION, "Input.get_magnetometer()", "", [], TOUCH, "magnetic field")
		.described("The magnetic field around the device, as x, y, z (the compass). Reports 0 on desktop."))
	descriptors.append(F.make_descriptor("Core", "TouchCompareAcceleration", "Compare Acceleration", ACEDescriptor.ACEType.CONDITION, "Input.get_accelerometer().{sensor_axis} {comparison} {value}", "", [F.make_param("sensor_axis", "String", "x", "Direction", "Which way to measure.", "", SENSOR_AXIS_OPTIONS), F.make_param("comparison", "String", ">", "Comparison", "How to compare.", "", F.COMPARISON_OPTIONS), F.make_param("value", "String", "5", "Value", "How much tilt counts.", "expression")], TOUCH, "Compare acceleration {sensor_axis} {comparison} {value}")
		.described("Tilt as a condition - X above zero is tilted to the right, Y is tilted forward. Reports 0 on desktop.").featured())


## The two SHAPES games make of the raw sensors, beside the sensors they refine. Tilt-to-steer
## is a stored neutral point, the subtraction, and one axis fed into movement; gyro aim is the
## rotation rate fed into yaw and pitch, which is mouse look with a different hand on it. The
## calibration row is first on purpose: without it a tilt game measures from whatever "flat" the
## sensor happened to see at start-up, which is the bug every first tilt game ships with.
static func _gyro_controls(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.make_descriptor("Core", "TouchSetNeutralTilt", "Set Neutral Tilt", ACEDescriptor.ACEType.ACTION, "{neutral} = Input.get_accelerometer()", "", [F.make_param("neutral", "String", "neutral", "Neutral", "The variable that remembers how the device is being held.", "variable_reference")], TOUCH, "Set neutral to Touch.Acceleration")
		.described("Remembers how the device is being held right now as \"flat\", so every tilt after this is measured from there. Offer it as a Calibrate button - it is the difference between a tilt game that works and one that does not.").featured())
	descriptors.append(F.make_descriptor("Core", "TouchSteerByTilt", "Steer By Tilt", ACEDescriptor.ACEType.ACTION, "velocity.{motion_axis} = {tilt}.{sensor_axis} * {strength} * delta", "", [F.make_param("tilt", "String", "tilt", "Tilt", "The value holding the tilt away from neutral (Touch.Acceleration minus your neutral).", "variable_reference"), F.make_param("sensor_axis", "String", "x", "Tilt direction", "Which way of the tilt to steer with.", "", SENSOR_AXIS_OPTIONS), F.make_param("strength", "String", "900.0", "Strength", "How hard a full tilt pushes.", "expression"), F.make_param("motion_axis", "String", "x", "Movement direction", "Which way the object is pushed.", "", SENSOR_AXIS_OPTIONS)], TOUCH, "Steer by tilt {sensor_axis} at {strength}", "CharacterBody3D")
		.described("Feeds one direction of the tilt into movement, so leaning the device steers. Measure the tilt from a neutral point first, or the game only plays flat on a table.").featured())
	descriptors.append(F.make_descriptor("Core", "TouchAimByGyro", "Aim By Gyro", ACEDescriptor.ACEType.ACTION, "rotate_y(-{rate}.y * delta)\n{camera}.rotate_x(-{rate}.x * delta)", "", [F.make_param("rate", "String", "rate", "Rotation rate", "The value holding Touch.RotationRate for this frame.", "variable_reference"), F.make_param("camera", "String", "$Camera3D", "Camera", "The camera that looks up and down.", "expression")], TOUCH, "Aim by gyro", "Node3D")
		.described("Turns the body and pitches the camera by how fast the device is being turned - mouse look with the phone itself. Reports 0 on desktop, so keep a mouse or stick path beside it.").featured())


static func section_descriptions() -> Dictionary:
	return {
		GAMEPAD: "Sticks, triggers and buttons by gamepad number, and the deadzone each control uses.",
		TOUCH: "Fingers, gestures and the sensors a phone has. Sensors report 0 on desktop - test on a device.",
	}
