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

	descriptors.append(F.act("InputAddAction", "Add Input Action", "if not InputMap.has_action({action}):\n\tInputMap.add_action({action})", CAT, "add input action {action}", "Creates a named input action at runtime if it does not already exist.").param("action", "\"jump\"", "Action", "The action name to create.", "expression"))
	descriptors.append(F.act("InputRebindToKey", "Rebind Action To Key", "InputMap.action_erase_events({action})\nvar __key_{uid} = InputEventKey.new()\n__key_{uid}.physical_keycode = {physical_keycode}\nInputMap.action_add_event({action}, __key_{uid})", CAT, "rebind {action} to {physical_keycode}", "Clears an action's keys and binds it to a single key - the whole key-rebinding step in one action.").param_choice("action", "\"jump\"", "Action", "The action to rebind.", F.input_action_options(), "input_action").param_typed("int", "physical_keycode", "KEY_SPACE", "Key", "The keyboard key, for example KEY_SPACE or the keycode from a captured key.", "key_capture").featured())
	descriptors.append(F.cond("InputHasAction", "Has Input Action", "InputMap.has_action({action})", CAT, "input action {action} exists", "True when an input action is registered.").param_choice("action", "\"jump\"", "Action", "The action name to test.", F.input_action_options(), "input_action"))
	descriptors.append(F.expr("InputMoveVector", "Move Vector", "Input.get_vector({left}, {right}, {up}, {down})", CAT, "move vector", "A ready-made movement direction (a Vector2) from four actions, with analog sticks handled.").param_choice("left", "\"ui_left\"", "Left", "Action for moving left.", F.input_action_options(), "input_action").param_choice("right", "\"ui_right\"", "Right", "Action for moving right.", F.input_action_options(), "input_action").param_choice("up", "\"ui_up\"", "Up", "Action for moving up.", F.input_action_options(), "input_action").param_choice("down", "\"ui_down\"", "Down", "Action for moving down.", F.input_action_options(), "input_action").featured())
	descriptors.append(F.expr("InputMoveAxis", "Move Axis", "Input.get_axis({negative}, {positive})", CAT, "move axis", "A single -1 to 1 axis from two actions (for left/right or up/down).").param_choice("negative", "\"ui_left\"", "Negative", "Action for the negative direction.", F.input_action_options(), "input_action").param_choice("positive", "\"ui_right\"", "Positive", "Action for the positive direction.", F.input_action_options(), "input_action"))
	descriptors.append(F.expr("InputActionStrength", "Action Strength", "Input.get_action_strength({action})", CAT, "strength of {action}", "How hard an action is held, 0 to 1 (a trigger or stick reads in between).").param_choice("action", "\"ui_right\"", "Action", "The action to read.", F.input_action_options(), "input_action"))

	# ── The rest of a rebind screen: remove, rebind-to-any-device, deadzone, readable
	# binding text, enumeration, and the reset button - each one action.
	descriptors.append(F.act("InputRemoveAction", "Remove Input Action", "if InputMap.has_action({action}):\n\tInputMap.erase_action({action})", CAT, "remove input action {action}", "Removes a runtime input action entirely (the partner of Add Input Action).").param_built(F.make_param("action", "String", F.default_input_action(), "Action", "The action to remove.", "input_action", F.input_action_options())))
	descriptors.append(F.act("InputRebindToMouseButton", "Rebind Action To Mouse Button", "InputMap.action_erase_events({action})\nvar __btn_{uid} = InputEventMouseButton.new()\n__btn_{uid}.button_index = {button}\nInputMap.action_add_event({action}, __btn_{uid})", CAT, "rebind {action} to mouse {button}", "Clears an action's bindings and binds it to a mouse button - the whole rebind step in one action.").param_built(F.make_param("action", "String", F.default_input_action(), "Action", "The action to rebind.", "input_action", F.input_action_options())).param_choice("button", "MOUSE_BUTTON_LEFT", "Button", "Mouse button.", ["MOUSE_BUTTON_LEFT", "MOUSE_BUTTON_RIGHT", "MOUSE_BUTTON_MIDDLE"]))
	descriptors.append(F.act("InputRebindToJoyButton", "Rebind Action To Gamepad Button", "InputMap.action_erase_events({action})\nvar __joy_{uid} = InputEventJoypadButton.new()\n__joy_{uid}.button_index = {button}\nInputMap.action_add_event({action}, __joy_{uid})", CAT, "rebind {action} to gamepad {button}", "Clears an action's bindings and binds it to a gamepad button - keyboard, mouse, and gamepad rebinding all have a one-step action.").param_built(F.make_param("action", "String", F.default_input_action(), "Action", "The action to rebind.", "input_action", F.input_action_options())).param_choice("button", "JOY_BUTTON_A", "Button", "Gamepad button.", ["JOY_BUTTON_A", "JOY_BUTTON_B", "JOY_BUTTON_X", "JOY_BUTTON_Y", "JOY_BUTTON_LEFT_SHOULDER", "JOY_BUTTON_RIGHT_SHOULDER", "JOY_BUTTON_START", "JOY_BUTTON_BACK", "JOY_BUTTON_DPAD_UP", "JOY_BUTTON_DPAD_DOWN", "JOY_BUTTON_DPAD_LEFT", "JOY_BUTTON_DPAD_RIGHT"]))
	descriptors.append(F.act("InputSetDeadzone", "Set Action Deadzone", "InputMap.action_set_deadzone({action}, {deadzone})", CAT, "set {action} deadzone to {deadzone}", "How far a stick must move before the action counts - the drift-vs-responsiveness slider every controller options menu needs.").param_choice("action", "\"ui_right\"", "Action", "The action to tune.", F.input_action_options(), "input_action").param("deadzone", "0.2", "Deadzone", "Stick travel ignored before the action registers, 0 to 1.", "expression"))
	descriptors.append(F.expr("InputBindingText", "Action Binding As Text", "(InputMap.action_get_events({action})[0].as_text() if not InputMap.action_get_events({action}).is_empty() else \"unbound\")", CAT, "binding of {action} as text", "The action's first binding as readable text (\"Space\", \"Left Mouse Button\") or \"unbound\" - print it next to each row of a rebind screen.").param_built(F.make_param("action", "String", F.default_input_action(), "Action", "The action to describe.", "input_action", F.input_action_options())).featured())
	descriptors.append(F.expr("InputActionsList", "All Input Actions", "InputMap.get_actions()", CAT, "all input actions", "Every registered action name (an Array) - loop it to build a rebind screen instead of hand-listing rows."))
	descriptors.append(F.act("InputLoadDefaults", "Restore Default Bindings", "InputMap.load_from_project_settings()", CAT, "restore default bindings", "Throws away every runtime rebind and reloads the Input Map exactly as set in Project Settings - the Reset to Defaults button.").featured())

	return descriptors


static func section_descriptions() -> Dictionary:
	return {CAT: "Create and rebind controls, and read movement as a vector or axis (beyond the basic is-pressed checks)."}
