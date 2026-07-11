class_name InputRebindDemo
extends Control

var rebinding_action: String = ""


func _ready() -> void:
	setup_default_bindings()
	$HudKit.on_button_pressed.connect(handle_button)
	$HudKit.set_text("StatusLabel", "Click a Rebind button, then press any input.")


func _input(event: InputEvent) -> void:
	if rebinding_action == "":
		return
	if (event is InputEventKey and event.pressed) or (event is InputEventMouseButton and event.pressed) or (event is InputEventJoypadButton and event.pressed):
		InputMap.action_erase_events(rebinding_action)
		InputMap.action_add_event(rebinding_action, event)
		$HudKit.set_text("StatusLabel", "%s bound to %s" % [rebinding_action.capitalize(), event.as_text()])
		rebinding_action = ""
		refresh_binding_labels()


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("demo_jump"):
		$HudKit.show_toast("Jump!")
	if Input.is_action_just_pressed("demo_dash"):
		$HudKit.show_toast("Dash!")
	var pads: Array = Input.get_connected_joypads()
	if pads.is_empty():
		$HudKit.set_text("GamepadLabel", "No gamepad connected - plug one in")
	else:
		$HudKit.set_text("GamepadLabel", "%d gamepad(s) - %s" % [pads.size(), Input.get_joy_name(pads[0])])


## @ace_hidden
func handle_button() -> void:
	var pressed_button: String = $HudKit.last_button_name_value()
	match pressed_button:
		"RebindJumpButton":
			rebinding_action = "demo_jump"
			$HudKit.set_text("StatusLabel", "Press any key, mouse or gamepad button to bind Jump…")
		"RebindDashButton":
			rebinding_action = "demo_dash"
			$HudKit.set_text("StatusLabel", "Press any key, mouse or gamepad button to bind Dash…")
		"ResetButton":
			setup_default_bindings()
			$HudKit.set_text("StatusLabel", "Bindings restored to the demo defaults.")
		"VibrateButton":
			Input.start_joy_vibration(0, 0.5, 0.5, 0.4)
			$HudKit.set_text("StatusLabel", "Vibrating gamepad 0 (if one is connected).")


## @ace_hidden
func setup_default_bindings() -> void:
	if not InputMap.has_action("demo_jump"):
		InputMap.add_action("demo_jump")
	if not InputMap.has_action("demo_dash"):
		InputMap.add_action("demo_dash")
	InputMap.action_erase_events("demo_jump")
	var jump_key: InputEventKey = InputEventKey.new()
	jump_key.physical_keycode = KEY_SPACE
	InputMap.action_add_event("demo_jump", jump_key)
	InputMap.action_erase_events("demo_dash")
	var dash_key: InputEventKey = InputEventKey.new()
	dash_key.physical_keycode = KEY_C
	InputMap.action_add_event("demo_dash", dash_key)
	refresh_binding_labels()


## @ace_hidden
func refresh_binding_labels() -> void:
	$HudKit.set_text("JumpLabel", "Jump: %s" % binding_text("demo_jump"))
	$HudKit.set_text("DashLabel", "Dash: %s" % binding_text("demo_dash"))


## @ace_hidden
func binding_text(action_name: String) -> String:
	var events: Array = InputMap.action_get_events(action_name)
	return events[0].as_text() if not events.is_empty() else "unbound"

# [b]Input Rebind[/b] - a working rebind screen built from the Input/InputMap/Gamepad vocabulary: click Rebind, then press ANY key, mouse button, or gamepad button (the captured event binds verbatim). Binding labels read InputMap.action_get_events(...).as_text() - the Action Binding As Text pattern. Actions are created at runtime, so the demo leaves your project's Input Map alone.
