# Godot EventSheets — Device input vocabulary (C3 Keyboard/Mouse/Gamepad/Touch) +
# the press-a-key capture workflow + dialog-width hygiene.
@tool
extends RefCounted
class_name DeviceInputTest

static func run() -> bool:
	var all_passed: bool = true

	var by_id: Dictionary = {}
	for descriptor in EventForgeBuiltinACEs.get_descriptors():
		by_id[descriptor.ace_id] = descriptor
	all_passed = _check("keyboard group registered",
		by_id.has("KeyIsDown") and by_id.has("KeyEventPressed") and by_id.has("KeyEventReleased"), true) and all_passed
	all_passed = _check("mouse group registered",
		by_id.has("MouseButtonDown") and by_id.has("GetMouseWorldPosition") and by_id.has("SetMouseMode"), true) and all_passed
	all_passed = _check("gamepad group registered",
		by_id.has("JoyButtonDown") and by_id.has("GetJoyAxis") and by_id.has("GamepadConnected") and by_id.has("StartJoyVibration"), true) and all_passed
	all_passed = _check("touch group registered",
		by_id.has("IsTouchscreen") and by_id.has("TouchEventPressed") and by_id.has("GetTouchPosition"), true) and all_passed
	all_passed = _check("key params use the capture workflow",
		str((by_id["KeyIsDown"].params[0] as ACEParam).hint), "key_capture") and all_passed

	# Press-a-key: keycodes map to KEY_* constants.
	all_passed = _check("F8 maps to its constant", ACEParamsDialog.key_constant_for(KEY_F8), "KEY_F8") and all_passed
	all_passed = _check("PageUp maps without spaces", ACEParamsDialog.key_constant_for(KEY_PAGEUP), "KEY_PAGEUP") and all_passed
	all_passed = _check("Space maps", ACEParamsDialog.key_constant_for(KEY_SPACE), "KEY_SPACE") and all_passed
	var dialog: ACEParamsDialog = ACEParamsDialog.new()
	var field: Control = dialog._create_key_capture_field("key", "KEY_SPACE")
	var capture: Button = null
	for child in field.get_children():
		if child is Button and not (child is OptionButton):
			capture = child
	all_passed = _check("capture field is a button + fallback dropdown",
		capture != null and field.get_child_count() == 2, true) and all_passed
	all_passed = _check("capture round-trips the constant", dialog._extract_value(capture), "KEY_SPACE") and all_passed
	field.free()

	# Compile: a key condition + gamepad axis + touch event-condition all parse.
	var sheet: EventSheetResource = EventSheetResource.new()
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnInput"
	var key_cond: ACECondition = ACECondition.new()
	key_cond.provider_id = "Core"
	key_cond.ace_id = "KeyEventPressed"
	key_cond.codegen_template = str(by_id["KeyEventPressed"].codegen_template)
	key_cond.params = {"key": "KEY_F8"}
	event.conditions.append(key_cond)
	var act: ACEAction = ACEAction.new()
	act.provider_id = "Core"
	act.ace_id = "SetVar"
	act.codegen_template = "rotation = Input.get_joy_axis(0, JOY_AXIS_LEFT_X)"
	event.actions.append(act)
	sheet.events.append(event)
	sheet.host_class = "Node2D"
	var output: String = str(SheetCompiler.compile(sheet, "user://eventsheets_devices.gd").get("output", ""))
	all_passed = _check("key event condition compiles",
		output.contains("event.physical_keycode == KEY_F8"), true) and all_passed
	var generated: GDScript = GDScript.new()
	generated.source_code = output
	all_passed = _check("device output parses", generated.reload(true) == OK, true) and all_passed

	# Dialog-width hygiene: long helper labels wrap instead of widening the window.
	var vd: VariableDialog = VariableDialog.new()
	var host: Node = Node.new()
	vd.init_dialog(host)
	all_passed = _check("variable-dialog helps autowrap",
		vd._default_help.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART and vd._const_help.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART, true) and all_passed
	host.free()

	return all_passed

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] device_input_test: %s" % label)
		return true
	print("[FAIL] device_input_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
