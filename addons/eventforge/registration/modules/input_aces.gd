# EventForge module - Input management vocabulary (define + rebind + read controls).
#
# The input-management pieces beyond simple "is this action pressed" (which the core vocabulary
# covers): create an action at runtime, rebind an action to a new key in one step, and read movement
# as a vector or axis. They compile to plain Godot (InputMap, Input) with zero plugin references.
# (Binding a raw event, clearing bindings, and mouse mode already live in the input vocabulary.)
# Grouped under "Input".
@tool
class_name EventForgeInputACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

const CAT := "Input"


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	descriptors.append(F.make_descriptor("Core", "InputAddAction", "Add Input Action", ACEDescriptor.ACEType.ACTION, "if not InputMap.has_action({action}):\n\tInputMap.add_action({action})", "", [F.make_param("action", "String", "\"jump\"", "Action", "The action name to create.", "expression")], CAT, "add input action {action}")
		.described("Creates a named input action at runtime if it does not already exist."))
	descriptors.append(F.make_descriptor("Core", "InputRebindToKey", "Rebind Action To Key", ACEDescriptor.ACEType.ACTION, "InputMap.action_erase_events({action})\nvar __key_{uid} = InputEventKey.new()\n__key_{uid}.physical_keycode = {physical_keycode}\nInputMap.action_add_event({action}, __key_{uid})", "", [F.make_param("action", "String", "\"jump\"", "Action", "The action to rebind.", "input_action", F.input_action_options()), F.make_param("physical_keycode", "int", "KEY_SPACE", "Key", "The keyboard key, for example KEY_SPACE or the keycode from a captured key.", "key_capture")], CAT, "rebind {action} to {physical_keycode}")
		.described("Clears an action's keys and binds it to a single key - the whole key-rebinding step in one action.").featured())
	descriptors.append(F.make_descriptor("Core", "InputHasAction", "Has Input Action", ACEDescriptor.ACEType.CONDITION, "InputMap.has_action({action})", "", [F.make_param("action", "String", "\"jump\"", "Action", "The action name to test.", "input_action", F.input_action_options())], CAT, "input action {action} exists")
		.described("True when an input action is registered."))
	descriptors.append(F.make_descriptor("Core", "InputMoveVector", "Move Vector", ACEDescriptor.ACEType.EXPRESSION, "Input.get_vector({left}, {right}, {up}, {down})", "", [F.make_param("left", "String", "\"ui_left\"", "Left", "Action for moving left.", "input_action", F.input_action_options()), F.make_param("right", "String", "\"ui_right\"", "Right", "Action for moving right.", "input_action", F.input_action_options()), F.make_param("up", "String", "\"ui_up\"", "Up", "Action for moving up.", "input_action", F.input_action_options()), F.make_param("down", "String", "\"ui_down\"", "Down", "Action for moving down.", "input_action", F.input_action_options())], CAT, "move vector")
		.described("A ready-made movement direction (a Vector2) from four actions, with analog sticks handled.").featured())
	descriptors.append(F.make_descriptor("Core", "InputMoveAxis", "Move Axis", ACEDescriptor.ACEType.EXPRESSION, "Input.get_axis({negative}, {positive})", "", [F.make_param("negative", "String", "\"ui_left\"", "Negative", "Action for the negative direction.", "input_action", F.input_action_options()), F.make_param("positive", "String", "\"ui_right\"", "Positive", "Action for the positive direction.", "input_action", F.input_action_options())], CAT, "move axis")
		.described("A single -1 to 1 axis from two actions (for left/right or up/down)."))
	descriptors.append(F.make_descriptor("Core", "InputActionStrength", "Action Strength", ACEDescriptor.ACEType.EXPRESSION, "Input.get_action_strength({action})", "", [F.make_param("action", "String", "\"ui_right\"", "Action", "The action to read.", "input_action", F.input_action_options())], CAT, "strength of {action}")
		.described("How hard an action is held, 0 to 1 (a trigger or stick reads in between)."))

	# ── The rest of a rebind screen: remove, rebind-to-any-device, deadzone, readable
	# binding text, enumeration, and the reset button - each one action.
	descriptors.append(F.make_descriptor("Core", "InputRemoveAction", "Remove Input Action", ACEDescriptor.ACEType.ACTION, "if InputMap.has_action({action}):\n\tInputMap.erase_action({action})", "", [F.make_param("action", "String", F.default_input_action(), "Action", "The action to remove.", "input_action", F.input_action_options())], CAT, "remove input action {action}")
		.described("Removes a runtime input action entirely (the partner of Add Input Action)."))
	descriptors.append(F.make_descriptor("Core", "InputRebindToMouseButton", "Rebind Action To Mouse Button", ACEDescriptor.ACEType.ACTION, "InputMap.action_erase_events({action})\nvar __btn_{uid} = InputEventMouseButton.new()\n__btn_{uid}.button_index = {button}\nInputMap.action_add_event({action}, __btn_{uid})", "", [F.make_param("action", "String", F.default_input_action(), "Action", "The action to rebind.", "input_action", F.input_action_options()), F.make_param("button", "String", "MOUSE_BUTTON_LEFT", "Button", "Mouse button.", "", ["MOUSE_BUTTON_LEFT", "MOUSE_BUTTON_RIGHT", "MOUSE_BUTTON_MIDDLE"])], CAT, "rebind {action} to mouse {button}")
		.described("Clears an action's bindings and binds it to a mouse button - the whole rebind step in one action."))
	descriptors.append(F.make_descriptor("Core", "InputRebindToJoyButton", "Rebind Action To Gamepad Button", ACEDescriptor.ACEType.ACTION, "InputMap.action_erase_events({action})\nvar __joy_{uid} = InputEventJoypadButton.new()\n__joy_{uid}.button_index = {button}\nInputMap.action_add_event({action}, __joy_{uid})", "", [F.make_param("action", "String", F.default_input_action(), "Action", "The action to rebind.", "input_action", F.input_action_options()), F.make_param("button", "String", "JOY_BUTTON_A", "Button", "Gamepad button.", "", ["JOY_BUTTON_A", "JOY_BUTTON_B", "JOY_BUTTON_X", "JOY_BUTTON_Y", "JOY_BUTTON_LEFT_SHOULDER", "JOY_BUTTON_RIGHT_SHOULDER", "JOY_BUTTON_START", "JOY_BUTTON_BACK", "JOY_BUTTON_DPAD_UP", "JOY_BUTTON_DPAD_DOWN", "JOY_BUTTON_DPAD_LEFT", "JOY_BUTTON_DPAD_RIGHT"])], CAT, "rebind {action} to gamepad {button}")
		.described("Clears an action's bindings and binds it to a gamepad button - keyboard, mouse, and gamepad rebinding all have a one-step verb."))
	descriptors.append(F.make_descriptor("Core", "InputSetDeadzone", "Set Action Deadzone", ACEDescriptor.ACEType.ACTION, "InputMap.action_set_deadzone({action}, {deadzone})", "", [F.make_param("action", "String", "\"ui_right\"", "Action", "The action to tune.", "input_action", F.input_action_options()), F.make_param("deadzone", "String", "0.2", "Deadzone", "Stick travel ignored before the action registers, 0 to 1.", "expression")], CAT, "set {action} deadzone to {deadzone}")
		.described("How far a stick must move before the action counts - the drift-vs-responsiveness slider every controller options menu needs."))
	descriptors.append(F.make_descriptor("Core", "InputBindingText", "Action Binding As Text", ACEDescriptor.ACEType.EXPRESSION, "(InputMap.action_get_events({action})[0].as_text() if not InputMap.action_get_events({action}).is_empty() else \"unbound\")", "", [F.make_param("action", "String", F.default_input_action(), "Action", "The action to describe.", "input_action", F.input_action_options())], CAT, "binding of {action} as text")
		.described("The action's first binding as readable text (\"Space\", \"Left Mouse Button\") or \"unbound\" - print it next to each row of a rebind screen.").featured())
	descriptors.append(F.make_descriptor("Core", "InputActionsList", "All Input Actions", ACEDescriptor.ACEType.EXPRESSION, "InputMap.get_actions()", "", [], CAT, "all input actions")
		.described("Every registered action name (an Array) - loop it to build a rebind screen instead of hand-listing rows."))
	descriptors.append(F.make_descriptor("Core", "InputLoadDefaults", "Restore Default Bindings", ACEDescriptor.ACEType.ACTION, "InputMap.load_from_project_settings()", "", [], CAT, "restore default bindings")
		.described("Throws away every runtime rebind and reloads the Input Map exactly as set in Project Settings - the Reset to Defaults button.").featured())

	return descriptors


static func section_descriptions() -> Dictionary:
	return {CAT: "Create and rebind controls, and read movement as a vector or axis (beyond the basic is-pressed checks)."}
