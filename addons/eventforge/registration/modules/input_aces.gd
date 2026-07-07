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
	descriptors.append(F.make_descriptor("Core", "InputRebindToKey", "Rebind Action To Key", ACEDescriptor.ACEType.ACTION, "InputMap.action_erase_events({action})\nvar __key_{uid} = InputEventKey.new()\n__key_{uid}.physical_keycode = {physical_keycode}\nInputMap.action_add_event({action}, __key_{uid})", "", [F.make_param("action", "String", "\"jump\"", "Action", "The action to rebind.", "expression"), F.make_param("physical_keycode", "int", "KEY_SPACE", "Key", "The keyboard key, for example KEY_SPACE or the keycode from a captured key.", "key_capture")], CAT, "rebind {action} to {physical_keycode}")
		.described("Clears an action's keys and binds it to a single key - the whole key-rebinding step in one action.").featured())
	descriptors.append(F.make_descriptor("Core", "InputHasAction", "Has Input Action", ACEDescriptor.ACEType.CONDITION, "InputMap.has_action({action})", "", [F.make_param("action", "String", "\"jump\"", "Action", "The action name to test.", "expression")], CAT, "input action {action} exists")
		.described("True when an input action is registered."))
	descriptors.append(F.make_descriptor("Core", "InputMoveVector", "Move Vector", ACEDescriptor.ACEType.EXPRESSION, "Input.get_vector({left}, {right}, {up}, {down})", "", [F.make_param("left", "String", "\"ui_left\"", "Left", "Action for moving left.", "expression"), F.make_param("right", "String", "\"ui_right\"", "Right", "Action for moving right.", "expression"), F.make_param("up", "String", "\"ui_up\"", "Up", "Action for moving up.", "expression"), F.make_param("down", "String", "\"ui_down\"", "Down", "Action for moving down.", "expression")], CAT, "move vector")
		.described("A ready-made movement direction (a Vector2) from four actions, with analog sticks handled.").featured())
	descriptors.append(F.make_descriptor("Core", "InputMoveAxis", "Move Axis", ACEDescriptor.ACEType.EXPRESSION, "Input.get_axis({negative}, {positive})", "", [F.make_param("negative", "String", "\"ui_left\"", "Negative", "Action for the negative direction.", "expression"), F.make_param("positive", "String", "\"ui_right\"", "Positive", "Action for the positive direction.", "expression")], CAT, "move axis")
		.described("A single -1 to 1 axis from two actions (for left/right or up/down)."))
	descriptors.append(F.make_descriptor("Core", "InputActionStrength", "Action Strength", ACEDescriptor.ACEType.EXPRESSION, "Input.get_action_strength({action})", "", [F.make_param("action", "String", "\"ui_right\"", "Action", "The action to read.", "expression")], CAT, "strength of {action}")
		.described("How hard an action is held, 0 to 1 (a trigger or stick reads in between)."))

	return descriptors


static func section_descriptions() -> Dictionary:
	return {CAT: "Create and rebind controls, and read movement as a vector or axis (beyond the basic is-pressed checks)."}
