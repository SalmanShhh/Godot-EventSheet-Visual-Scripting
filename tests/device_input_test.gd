# Godot EventSheets — Device input vocabulary (Keyboard/Mouse/Gamepad/Touch) +
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

	# scene_path + animation_reference hints (the last two param-type gaps).
	var hint_dialog: ACEParamsDialog = ACEParamsDialog.new()
	var scene_field: Control = hint_dialog._create_scene_path_field("path", "\"res://x.tscn\"")
	var scene_edit: LineEdit = null
	for child in scene_field.get_children():
		if child is LineEdit:
			scene_edit = child
	all_passed = _check("scene_path field round-trips the path",
		scene_edit != null and hint_dialog._extract_value(scene_edit) == "\"res://x.tscn\"", true) and all_passed
	var anim_root: Node = Node.new()
	var anim_player: AnimationPlayer = AnimationPlayer.new()
	var library: AnimationLibrary = AnimationLibrary.new()
	library.add_animation("idle", Animation.new())
	library.add_animation("run", Animation.new())
	anim_player.add_animation_library("", library)
	anim_root.add_child(anim_player)
	all_passed = _check("animation options scan the scene's players",
		ACEParamsDialog.animation_options_from(anim_root), PackedStringArray(["idle", "run"])) and all_passed
	hint_dialog.animation_scene_root_override = anim_root
	var anim_field: Control = hint_dialog._create_animation_field("anim_name", "\"idle\"")
	var anim_picker: OptionButton = null
	for child in anim_field.get_children():
		if child is OptionButton:
			anim_picker = child
	all_passed = _check("animation field offers the dropdown when players exist",
		anim_picker != null and anim_picker.item_count == 3, true) and all_passed
	all_passed = _check("dropdown entries are metadata-tagged, placeholder is not",
		anim_picker.get_item_metadata(0) == null and str(anim_picker.get_item_metadata(1)) == "idle", true) and all_passed
	scene_field.free()
	anim_field.free()
	anim_root.free()
	# Review-fix regressions: shared quoting helper; drag payloads land on the new
	# fields exactly like expression fields (same converter); dropdown entries are
	# metadata-tagged (position-proof).
	all_passed = _check("quoted-literal helper is the single source",
		ACEParamsDialog.format_quoted_literal("res://a.tscn"), "\"res://a.tscn\"") and all_passed
	var drop_payload: Dictionary = {"type": "files", "files": ["res://level.tscn"]}
	all_passed = _check("file drops convert identically for line edits",
		ACEParamsDialog.drop_data_to_expression(drop_payload), "\"res://level.tscn\"") and all_passed
	hint_dialog.animation_scene_root_override = null
	# Descriptor hints flipped (UX-only; templates untouched).
	all_passed = _check("Spawn Scene At browses scenes",
		str((by_id["SpawnSceneAt"].params[0] as ACEParam).hint), "scene_path") and all_passed
	all_passed = _check("Play Animation offers the animation dropdown",
		str((by_id["PlayAnimation"].params[0] as ACEParam).hint), "animation_reference") and all_passed

	return all_passed

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] device_input_test: %s" % label)
		return true
	print("[FAIL] device_input_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
