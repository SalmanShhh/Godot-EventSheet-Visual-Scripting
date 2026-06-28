# EventForge module — Device input (Keyboard/Mouse/Gamepad/Touch)
#
# Polling + event-scoped conditions; key params use the press-a-key capture hint.
# Module contract: see ace_factory.gd — ace_ids/templates are API (compatibility
# covenant); this file only changes where the descriptors are AUTHORED.
@tool
extends RefCounted
class_name EventForgeDeviceACEs

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	# ── Device input (Keyboard/Mouse/Gamepad/Touch, Godot-style). Key params use
	# the press-a-key capture workflow (hint key_capture). Event-scoped conditions are
	# for On Input events, where `event` exists.
	descriptors.append(F.make_descriptor("Core", "KeyIsDown", "Key Is Down", ACEDescriptor.ACEType.CONDITION, "Input.is_physical_key_pressed({key})", "", [F.make_param("key", "String", "KEY_SPACE", "Key", "Press a key to capture it.", "key_capture")], "Keyboard", "Key {key} is down")
		.described("True while the given keyboard key is being held down."))
	descriptors.append(F.make_descriptor("Core", "KeyEventPressed", "On Key Pressed (event)", ACEDescriptor.ACEType.CONDITION, "(event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == {key})", "", [F.make_param("key", "String", "KEY_SPACE", "Key", "Use inside an On Input event.", "key_capture")], "Keyboard", "On {key} pressed")
		.described("True the moment a key is pressed, used inside an input event."))
	descriptors.append(F.make_descriptor("Core", "KeyEventReleased", "On Key Released (event)", ACEDescriptor.ACEType.CONDITION, "(event is InputEventKey and not event.pressed and event.physical_keycode == {key})", "", [F.make_param("key", "String", "KEY_SPACE", "Key", "Use inside an On Input event.", "key_capture")], "Keyboard", "On {key} released")
		.described("True the moment a key is released, used inside an input event."))
	descriptors.append(F.make_descriptor("Core", "MouseButtonDown", "Mouse Button Is Down", ACEDescriptor.ACEType.CONDITION, "Input.is_mouse_button_pressed({button})", "", [F.make_param("button", "String", "MOUSE_BUTTON_LEFT", "Button", "Mouse button.", "", ["MOUSE_BUTTON_LEFT", "MOUSE_BUTTON_RIGHT", "MOUSE_BUTTON_MIDDLE"])], "Mouse", "{button} is down")
		.described("True while the given mouse button is being held down."))
	descriptors.append(F.make_descriptor("Core", "GetMouseWorldPosition", "Mouse Position (world)", ACEDescriptor.ACEType.EXPRESSION, "get_global_mouse_position()", "", [], "Mouse", "mouse position", "Node2D")
		.described("Returns the mouse position in world coordinates, matching where things sit in the level."))
	descriptors.append(F.make_descriptor("Core", "GetMouseScreenPosition", "Mouse Position (screen)", ACEDescriptor.ACEType.EXPRESSION, "get_viewport().get_mouse_position()", "", [], "Mouse", "mouse screen position")
		.described("Returns the mouse position in screen pixels relative to the window."))
	descriptors.append(F.make_descriptor("Core", "SetMouseMode", "Set Mouse Mode", ACEDescriptor.ACEType.ACTION, "Input.mouse_mode = {mode}", "", [F.make_param("mode", "String", "Input.MOUSE_MODE_VISIBLE", "Mode", "Cursor visibility/capture.", "", ["Input.MOUSE_MODE_VISIBLE", "Input.MOUSE_MODE_HIDDEN", "Input.MOUSE_MODE_CAPTURED", "Input.MOUSE_MODE_CONFINED"])], "Mouse", "Set mouse mode {mode}")
		.described("Changes whether the cursor is visible, hidden, or locked to the window."))
	descriptors.append(F.make_descriptor("Core", "JoyButtonDown", "Gamepad Button Is Down", ACEDescriptor.ACEType.CONDITION, "Input.is_joy_button_pressed({device}, {button})", "", [F.make_param("device", "String", "0", "Gamepad", "Device index (0 = first).", "expression"), F.make_param("button", "String", "JOY_BUTTON_A", "Button", "Gamepad button.", "", ["JOY_BUTTON_A", "JOY_BUTTON_B", "JOY_BUTTON_X", "JOY_BUTTON_Y", "JOY_BUTTON_LEFT_SHOULDER", "JOY_BUTTON_RIGHT_SHOULDER", "JOY_BUTTON_START", "JOY_BUTTON_BACK", "JOY_BUTTON_DPAD_UP", "JOY_BUTTON_DPAD_DOWN", "JOY_BUTTON_DPAD_LEFT", "JOY_BUTTON_DPAD_RIGHT"])], "Gamepad", "Gamepad {button} is down")
		.described("True while the given gamepad button is being held down."))
	descriptors.append(F.make_descriptor("Core", "GetJoyAxis", "Gamepad Axis", ACEDescriptor.ACEType.EXPRESSION, "Input.get_joy_axis({device}, {axis})", "", [F.make_param("device", "String", "0", "Gamepad", "Device index.", "expression"), F.make_param("axis", "String", "JOY_AXIS_LEFT_X", "Axis", "Stick/trigger axis.", "", ["JOY_AXIS_LEFT_X", "JOY_AXIS_LEFT_Y", "JOY_AXIS_RIGHT_X", "JOY_AXIS_RIGHT_Y", "JOY_AXIS_TRIGGER_LEFT", "JOY_AXIS_TRIGGER_RIGHT"])], "Gamepad", "gamepad axis {axis}")
		.described("Returns how far a gamepad stick or trigger is pushed, from -1 to 1."))
	descriptors.append(F.make_descriptor("Core", "GamepadConnected", "Gamepad Is Connected", ACEDescriptor.ACEType.CONDITION, "Input.get_connected_joypads().has({device})", "", [F.make_param("device", "String", "0", "Gamepad", "Device index.", "expression")], "Gamepad", "gamepad {device} connected")
		.described("True when a gamepad at the given device slot is plugged in."))
	descriptors.append(F.make_descriptor("Core", "StartJoyVibration", "Vibrate Gamepad", ACEDescriptor.ACEType.ACTION, "Input.start_joy_vibration({device}, {weak}, {strong}, {duration})", "", [F.make_param("device", "String", "0", "Gamepad", "Device index.", "expression"), F.make_param("weak", "String", "0.5", "Weak", "Weak motor 0..1.", "expression"), F.make_param("strong", "String", "0.5", "Strong", "Strong motor 0..1.", "expression"), F.make_param("duration", "String", "0.3", "Seconds", "Duration.", "expression")], "Gamepad", "Vibrate gamepad {duration}s")
		.described("Rumbles a connected gamepad at chosen strength for a set duration."))
	descriptors.append(F.make_descriptor("Core", "IsTouchscreen", "Touchscreen Available", ACEDescriptor.ACEType.CONDITION, "DisplayServer.is_touchscreen_available()", "", [], "Touch", "device has a touchscreen")
		.described("True when the device running the game has a touchscreen."))
	descriptors.append(F.make_descriptor("Core", "TouchEventPressed", "On Touch (event)", ACEDescriptor.ACEType.CONDITION, "(event is InputEventScreenTouch and event.pressed)", "", [], "Touch", "On touch")
		.described("True the moment a finger touches the screen, used inside an input event."))
	descriptors.append(F.make_descriptor("Core", "TouchEventReleased", "On Touch Released (event)", ACEDescriptor.ACEType.CONDITION, "(event is InputEventScreenTouch and not event.pressed)", "", [], "Touch", "On touch released")
		.described("True the moment a finger lifts off the screen, used inside an input event."))
	descriptors.append(F.make_descriptor("Core", "GetTouchPosition", "Touch Position (event)", ACEDescriptor.ACEType.EXPRESSION, "event.position", "", [], "Touch", "touch position")
		.described("Returns the screen position of a touch from the current input event."))

	# Runtime input remapping (settings-menu rebinding). Capture an event in On Input (the
	# in-scope `event`), Erase then Add to rebind — two visual steps, no multi-statement
	# template. The action param reuses the InputMap dropdown like the polling ACEs above.
	descriptors.append(F.make_descriptor("Core", "ActionAddEvent", "Bind Event To Action", ACEDescriptor.ACEType.ACTION, "InputMap.action_add_event(&{action}, {event})", "", [F.make_param("action", "String", F.default_input_action(), "Action", "Input action to bind to.", "", F.input_action_options()), F.make_param("event", "String", "event", "Event", "InputEvent to add (e.g. the captured `event`).", "expression")], "InputMap", "Bind {event} to {action}")
		.described("Binds a new key, button, or input to a named action at runtime, for remapping."))
	descriptors.append(F.make_descriptor("Core", "ActionEraseEvents", "Clear Action Bindings", ACEDescriptor.ACEType.ACTION, "InputMap.action_erase_events(&{action})", "", [F.make_param("action", "String", F.default_input_action(), "Action", "Input action to clear.", "", F.input_action_options())], "InputMap", "Clear bindings for {action}")
		.described("Removes all key and button bindings from a named input action."))
	descriptors.append(F.make_descriptor("Core", "ActionHasEvents", "Action Is Bound", ACEDescriptor.ACEType.CONDITION, "not InputMap.action_get_events(&{action}).is_empty()", "", [F.make_param("action", "String", F.default_input_action(), "Action", "Input action to test.", "", F.input_action_options())], "InputMap", "{action} is bound")
		.described("True when the named input action has at least one key or button bound."))
	descriptors.append(F.make_descriptor("Core", "ActionEventCount", "Action Binding Count", ACEDescriptor.ACEType.EXPRESSION, "InputMap.action_get_events(&{action}).size()", "", [F.make_param("action", "String", F.default_input_action(), "Action", "Input action.", "", F.input_action_options())], "InputMap", "{action} binding count")
		.described("Returns how many keys or buttons are bound to a named action."))
	descriptors.append(F.make_descriptor("Core", "EventMatchesAction", "Event Matches Action", ACEDescriptor.ACEType.CONDITION, "{event}.is_action(&{action})", "", [F.make_param("event", "String", "event", "Event", "InputEvent to test.", "expression"), F.make_param("action", "String", F.default_input_action(), "Action", "Input action.", "", F.input_action_options())], "InputMap", "{event} matches {action}")
		.described("True when an input event matches the named action, like checking for jump."))
	descriptors.append(F.make_descriptor("Core", "EventAsText", "Event As Text", ACEDescriptor.ACEType.EXPRESSION, "{event}.as_text()", "", [F.make_param("event", "String", "event", "Event", "InputEvent to describe.", "expression")], "InputMap", "{event} as text")
		.described("Returns a readable label for an input event, like Space or Left Mouse."))

	return descriptors
