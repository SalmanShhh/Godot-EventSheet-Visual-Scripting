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
	descriptors.append(F.cond("GamepadCompareAxis", "Compare Axis", "Input.get_joy_axis({device}, {axis}) * 100 {comparison} {value}", GAMEPAD, "Compare axis {axis} of gamepad {device} {comparison} {value}", "How far a stick or trigger is pushed, on the -100 to 100 scale the Gamepad object shows.").param_choice("axis", "JOY_AXIS_LEFT_X", "Axis", "Which stick or trigger.", AXIS_OPTIONS).param("device", "0", "Gamepad", "Gamepad number (0 = the first one).", "expression").param_choice("comparison", ">", "Comparison", "How to compare.", F.COMPARISON_OPTIONS).param("value", "20", "Value", "Stick travel as a percent, -100 to 100.", "expression").featured())
	descriptors.append(F.cond("GamepadCompareAxisEitherWay", "Compare Axis (either way)", "abs(Input.get_joy_axis({device}, {axis})) * 100 {comparison} {value}", GAMEPAD, "Compare axis {axis} of gamepad {device} {comparison} {value} (either way)", "The same check ignoring which way the stick went - pushed this far in either direction.").param_choice("axis", "JOY_AXIS_LEFT_X", "Axis", "Which stick or trigger.", AXIS_OPTIONS).param("device", "0", "Gamepad", "Gamepad number (0 = the first one).", "expression").param_choice("comparison", ">", "Comparison", "How to compare.", F.COMPARISON_OPTIONS).param("value", "20", "Value", "Stick travel as a percent, ignoring the direction.", "expression"))
	descriptors.append(F.cond("GamepadButtonDownExact", "Is Button Down", "Input.is_action_pressed({action}, true)", GAMEPAD, "Is button down {action} (exact match)", "True while the control is held, counting only a binding that matches exactly - the way a menu tells one stick direction from another.").param_built(F.make_param("action", "String", F.default_input_action(), "Control", "The control to test.", "input_action", F.input_action_options())))
	descriptors.append(F.expr("GamepadAxisPercent", "Axis Of Gamepad", "(Input.get_joy_axis({device}, {axis}) * 100)", GAMEPAD, "axis {axis} of gamepad {device}", "How far a stick is pushed, -100 to 100 (Godot counts the same travel from -1 to 1).").param("device", "0", "Gamepad", "Gamepad number (0 = the first one).", "expression").param_choice("axis", "JOY_AXIS_LEFT_X", "Axis", "Which stick or trigger.", AXIS_OPTIONS).featured())
	descriptors.append(F.expr("GamepadButtonPercent", "Button Of Gamepad", "(Input.get_action_strength({action}) * 100)", GAMEPAD, "how hard {action} is held", "How hard a trigger or a control is held, 0 to 100 (Godot counts the same pull from 0 to 1).").param_built(F.make_param("action", "String", F.default_input_action(), "Control", "The control to read.", "input_action", F.input_action_options())).featured())


## Gamepads by number. Godot's `event.device` IS the gamepad number the sheet already counts
## from 0, so a two-player script stops reading as arithmetic.
static func _gamepads_by_number(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.cond("GamepadEventButtonPressed", "On Gamepad Button Pressed", "(event is InputEventJoypadButton and event.pressed and event.device == {device} and event.button_index == {button})", GAMEPAD, "On gamepad {device} button {button} pressed", "True the moment a named gamepad's button goes down, used inside an input event - the local-multiplayer check.").param("device", "0", "Gamepad", "Gamepad number (0 = the first one).", "expression").param_choice("button", "JOY_BUTTON_A", "Button", "Which button.", BUTTON_OPTIONS))
	descriptors.append(F.cond("GamepadEventButtonReleased", "On Gamepad Button Released", "(event is InputEventJoypadButton and not event.pressed and event.device == {device} and event.button_index == {button})", GAMEPAD, "On gamepad {device} button {button} released", "True the moment a named gamepad's button is let go, used inside an input event.").param("device", "0", "Gamepad", "Gamepad number (0 = the first one).", "expression").param_choice("button", "JOY_BUTTON_A", "Button", "Which button.", BUTTON_OPTIONS))
	descriptors.append(F.cond("GamepadHasAny", "Has Gamepads", "not Input.get_connected_joypads().is_empty()", GAMEPAD, "Has gamepads", "True while at least one gamepad is plugged in - switch the control hints, offer the join screen.").featured())
	descriptors.append(F.act("GamepadVibrateFor", "Vibrate Gamepad For", "Input.start_joy_vibration({device}, {weak}, {strong}, {seconds})", GAMEPAD, "Vibrate gamepad {device} for {seconds} seconds", "Rumbles one numbered gamepad for a moment - the sheet's phrasing for the thing every hit and every pickup wants.").param("device", "0", "Gamepad", "Gamepad number (0 = the first one).", "expression").param("weak", "0.3", "Weak motor", "Weak motor, 0 to 1.", "expression").param("strong", "0.8", "Strong motor", "Strong motor, 0 to 1.", "expression").param("seconds", "0.2", "Seconds", "How long the rumble lasts.", "expression"))


## Touch and gestures. Godot's InputEvent classes carry exactly what the Touch object's
## sentences say; the payload chips are the event's own fields.
static func _touch_and_gestures(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.cond("TouchDragEvent", "On Drag", "(event is InputEventScreenDrag)", TOUCH, "On drag", "True while a finger is moving across the screen, used inside an input event."))
	descriptors.append(F.cond("TouchPinchEvent", "On Pinch", "(event is InputEventMagnifyGesture)", TOUCH, "On pinch", "True on a two-finger pinch or spread, used inside an input event - zoom the map."))
	descriptors.append(F.cond("TouchPanEvent", "On Pan", "(event is InputEventPanGesture)", TOUCH, "On pan", "True on a two-finger pan (or a trackpad scroll), used inside an input event."))
	descriptors.append(F.expr("TouchIndexOf", "Touch Index", "event.index", TOUCH, "touch index", "Which finger this touch event is about, counting from 0 - multi-touch controls tell them apart by it."))
	descriptors.append(F.expr("TouchPinchFactor", "Pinch Factor", "event.factor", TOUCH, "pinch factor", "How much the pinch grew or shrank this event - multiply the zoom by it."))
	descriptors.append(F.expr("TouchPanDelta", "Pan Delta", "event.delta", TOUCH, "pan delta", "How far the two-finger pan moved this event, as a Vector2."))
	descriptors.append(F.cond("MouseDoubleClickEvent", "On Double-Click", "(event is InputEventMouseButton and event.double_click)", MOUSE, "On double-click", "True on the second click of a double-click, used inside an input event - open the item, rename the file."))


## Rebinding at runtime, one action per row: wait for the next key, clear, bind, reset,
## deadzone, save and load. Together they are the whole of a controls screen.
static func _rebinding(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.act("InputWaitForNextKey", "Wait For The Next Key Or Button", "var {name} = await get_window().window_input", KEYBOARD, "Wait for the next key or button into {name}", "Pauses this event until the player presses anything, and remembers what it was - the first step of every rebind screen.").param("name", "ev", "Into", "The name to remember the key or button under.", "expression").featured())
	descriptors.append(F.act("InputClearBindings", "Clear The Bindings Of", "InputMap.action_erase_events({action})", KEYBOARD, "Clear the bindings of {action}", "Takes every key and button off a control, so the next Bind is the only one left.").param_built(F.make_param("action", "String", F.default_input_action(), "Control", "The control to unbind.", "input_action", F.input_action_options())))
	descriptors.append(F.act("InputBindTo", "Bind Control To", "InputMap.action_add_event({action}, {event})", KEYBOARD, "Bind {action} to {event}", "Binds a key or a button to a control - the second step of a rebind screen.").param_built(F.make_param("action", "String", F.default_input_action(), "Control", "The control to bind.", "input_action", F.input_action_options())).param("event", "event", "Key or button", "The key or button to bind, usually the one just waited for.", "expression").featured())
	descriptors.append(F.expr("InputKeyNameOf", "Key Name", "{event}.as_text()", KEYBOARD, "name of {event}", "The readable name of a key or button (\"Space\", \"A button\") - show it next to each row of a rebind screen.").param("event", "event", "Key or button", "The key or button to name.", "expression").featured())
	descriptors.append(F.act("InputResetBindings", "Reset All Bindings", "InputMap.load_from_project_settings()", KEYBOARD, "Reset all bindings to the project's", "Throws away every rebind and puts the project's own Input Map back - the Reset button."))
	descriptors.append(F.cond("InputHasActionNamed", "Has Action", "InputMap.has_action({action})", KEYBOARD, "Has action {action}", "True when the Input Map knows this control - guard a row that names one the project might not have.").param_built(F.make_param("action", "String", F.default_input_action(), "Control", "The control to look for.", "input_action", F.input_action_options())))
	descriptors.append(F.act("GamepadSetDeadzoneOf", "Set Deadzone Of", "InputMap.action_set_deadzone({action}, {deadzone})", GAMEPAD, "Set deadzone of {action} to {deadzone}", "How far a stick must move before the control counts - the drift slider a controller options screen needs.").param_built(F.make_param("action", "String", F.default_input_action(), "Control", "The control to tune.", "input_action", F.input_action_options())).param("deadzone", "0.2", "Deadzone", "Stick travel ignored before the control counts, 0 to 1.", "expression"))
	descriptors.append(F.act("InputSaveBindings", "Save Bindings", "var __bindings_{uid} = ConfigFile.new()\nfor __action_{uid} in InputMap.get_actions():\n\t__bindings_{uid}.set_value(\"bindings\", str(__action_{uid}), InputMap.action_get_events(__action_{uid}))\n__bindings_{uid}.save({path})", KEYBOARD, "Save bindings", "Writes every control's bindings to a plain settings file under user://, so a rebind survives a restart.").param_typed("String", "path", BINDINGS_FILE, "File", "Where to keep them, under user://.", "expression").featured())
	descriptors.append(F.act("InputLoadBindings", "Load Bindings", "var __bindings_{uid} = ConfigFile.new()\nif __bindings_{uid}.load({path}) == OK:\n\tfor __action_{uid} in __bindings_{uid}.get_section_keys(\"bindings\"):\n\t\tif InputMap.has_action(__action_{uid}):\n\t\t\tInputMap.action_erase_events(__action_{uid})\n\t\t\tfor __event_{uid} in __bindings_{uid}.get_value(\"bindings\", __action_{uid}, []):\n\t\t\t\tInputMap.action_add_event(__action_{uid}, __event_{uid})", KEYBOARD, "Load bindings", "Puts saved bindings back on start-up. Does nothing when there is no saved file, so a first run keeps the project's own.").param_typed("String", "path", BINDINGS_FILE, "File", "Where they were kept, under user://.", "expression").featured())


## Simulated input, the pointer and "stop this input here". One event per idea.
static func _simulated_input(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.act("SimulateControlPressed", "Simulate Control Pressed", "Input.action_press({action})", SYSTEM, "Simulate control {action} pressed", "Presses a control as though the player had - how an AI, a replay or a tutorial drives the same code the player does.").param_built(F.make_param("action", "String", F.default_input_action(), "Control", "The control to press.", "input_action", F.input_action_options())).featured())
	descriptors.append(F.act("SimulateControlReleased", "Simulate Control Released", "Input.action_release({action})", SYSTEM, "Simulate control {action} released", "Lets go of a control that Simulate Control Pressed is holding.").param_built(F.make_param("action", "String", F.default_input_action(), "Control", "The control to let go.", "input_action", F.input_action_options())))
	descriptors.append(F.act("SimulateInputEvent", "Simulate Input", "Input.parse_input_event({event})", SYSTEM, "Simulate input {event}", "Feeds a whole key, button or touch into the game as if it had just happened.").param("event", "event", "Key or button", "The key, button or touch to feed in.", "expression"))
	descriptors.append(F.act("StopInputHere", "Stop This Input Here", "get_viewport().set_input_as_handled()", SYSTEM, "Stop this input here", "Nothing after this event sees the key or the click - the click was for this and nothing else.", "Node").featured())
	descriptors.append(F.cond("KeyEventIsRepeat", "Key Is A Held-Down Repeat", "(event is InputEventKey and event.is_echo())", KEYBOARD, "key is a held-down repeat", "True when this key event is the operating system repeating a held key rather than a fresh press."))
	descriptors.append(F.act("MouseRequestPointerLock", "Request Pointer Lock", "Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)", MOUSE, "Request pointer lock", "Hides the cursor and locks it to the window, so mouse motion drives looking around.").featured())
	descriptors.append(F.act("MouseCursorVisible", "Set Cursor Visible", "Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)", MOUSE, "Set cursor visible", "Gives the cursor back - pause menus, dialogs, quitting to the map."))
	descriptors.append(F.act("MouseCursorInvisible", "Set Cursor Invisible", "Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)", MOUSE, "Set cursor invisible", "Hides the cursor while leaving it free to move - a game that draws its own crosshair."))
	descriptors.append(F.act("MouseCursorConfined", "Keep Cursor Inside The Window", "Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED)", MOUSE, "Keep cursor inside the window", "The cursor stays visible but cannot leave the window - strategy games on two monitors."))
	descriptors.append(F.act("MouseMoveCursorTo", "Move Cursor To", "Input.warp_mouse({position})", MOUSE, "Move cursor to {position}", "Teleports the pointer - snap it to a menu item, re-centre it after a cutscene.").param("position", "Vector2(100, 100)", "Position", "Where in the window to put the pointer.", "expression"))


## Handheld sensors. The four Godot exposes, in the Touch object's words. They all report zero
## on a desktop, which is said where it is needed rather than left as a surprise.
static func _sensors(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.expr("TouchAcceleration", "Acceleration", "Input.get_accelerometer()", TOUCH, "acceleration", "How the device is being moved right now, gravity included, as x, y, z. Reports 0 on desktop.").featured())
	descriptors.append(F.expr("TouchGravity", "Gravity Direction", "Input.get_gravity()", TOUCH, "gravity", "Which way is down for the device, as x, y, z - how it is being held. Reports 0 on desktop."))
	descriptors.append(F.expr("TouchRotationRate", "Rotation Rate", "Input.get_gyroscope()", TOUCH, "rotation rate", "How fast the device is being turned, as x, y, z (the gyroscope). Reports 0 on desktop."))
	descriptors.append(F.expr("TouchMagneticField", "Magnetic Field", "Input.get_magnetometer()", TOUCH, "magnetic field", "The magnetic field around the device, as x, y, z (the compass). Reports 0 on desktop."))
	descriptors.append(F.cond("TouchCompareAcceleration", "Compare Acceleration", "Input.get_accelerometer().{sensor_axis} {comparison} {value}", TOUCH, "Compare acceleration {sensor_axis} {comparison} {value}", "Tilt as a condition - X above zero is tilted to the right, Y is tilted forward. Reports 0 on desktop.").param_choice("sensor_axis", "x", "Direction", "Which way to measure.", SENSOR_AXIS_OPTIONS).param_choice("comparison", ">", "Comparison", "How to compare.", F.COMPARISON_OPTIONS).param("value", "5", "Value", "How much tilt counts.", "expression").featured())


## The two SHAPES games make of the raw sensors, beside the sensors they refine. Tilt-to-steer
## is a stored neutral point, the subtraction, and one axis fed into movement; gyro aim is the
## rotation rate fed into yaw and pitch, which is mouse look with a different hand on it. The
## calibration row is first on purpose: without it a tilt game measures from whatever "flat" the
## sensor happened to see at start-up, which is the bug every first tilt game ships with.
static func _gyro_controls(descriptors: Array[ACEDescriptor]) -> void:
	descriptors.append(F.act("TouchSetNeutralTilt", "Set Neutral Tilt", "{neutral} = Input.get_accelerometer()", TOUCH, "Set neutral to Touch.Acceleration", "Remembers how the device is being held right now as \"flat\", so every tilt after this is measured from there. Offer it as a Calibrate button - it is the difference between a tilt game that works and one that does not.").param("neutral", "neutral", "Neutral", "The variable that remembers how the device is being held.", "variable_reference").featured())
	descriptors.append(F.act("TouchSteerByTilt", "Steer By Tilt", "velocity.{motion_axis} = {tilt}.{sensor_axis} * {strength} * delta", TOUCH, "Steer by tilt {sensor_axis} at {strength}", "Feeds one direction of the tilt into movement, so leaning the device steers. Measure the tilt from a neutral point first, or the game only plays flat on a table.", "CharacterBody3D").param("tilt", "tilt", "Tilt", "The value holding the tilt away from neutral (Touch.Acceleration minus your neutral).", "variable_reference").param_choice("sensor_axis", "x", "Tilt direction", "Which way of the tilt to steer with.", SENSOR_AXIS_OPTIONS).param("strength", "900.0", "Strength", "How hard a full tilt pushes.", "expression").param_choice("motion_axis", "x", "Movement direction", "Which way the object is pushed.", SENSOR_AXIS_OPTIONS).featured())
	descriptors.append(F.act("TouchAimByGyro", "Aim By Gyro", "rotate_y(-{rate}.y * delta)\n{camera}.rotate_x(-{rate}.x * delta)", TOUCH, "Aim by gyro", "Turns the body and pitches the camera by how fast the device is being turned - mouse look with the phone itself. Reports 0 on desktop, so keep a mouse or stick path beside it.", "Node3D").param("rate", "rate", "Rotation rate", "The value holding Touch.RotationRate for this frame.", "variable_reference").param("camera", "$Camera3D", "Camera", "The camera that looks up and down.", "expression").featured())


static func section_descriptions() -> Dictionary:
	return {
		GAMEPAD: "Sticks, triggers and buttons by gamepad number, and the deadzone each control uses.",
		TOUCH: "Fingers, gestures and the sensors a phone has. Sensors report 0 on desktop - test on a device.",
	}
