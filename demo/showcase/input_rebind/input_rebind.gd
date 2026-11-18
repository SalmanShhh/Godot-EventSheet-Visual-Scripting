class_name InputRebindDemo
extends Control
## [b]Input Rebind[/b] - a rebinding screen on the Game Settings rows. Click a key, press another, and a clash asks Swap, Take it anyway or Pick another key; Esc cancels; the keyboard and pad columns are kept side by side; and Save Bindings keeps the choice for the next launch (user://settings.cfg, section [bindings]). In your own project the Game Settings pack is the Settings autoload, so the rows read Settings.save_bindings(); here the same pack is a child node named Settings, so they read $Settings.save_bindings(). The two demo controls are declared the way Project Settings declares them, so Reset works exactly as in a real project, and project.godot is left alone.


func _ready() -> void:
	$Settings.binding_changed.connect(_on_settings_binding_changed)
	$Settings.binding_conflict.connect(_on_settings_binding_conflict)
	$HudKit.on_button_pressed.connect(_on_hudkit_on_button_pressed)
	$Settings.binding_cancelled.connect(_on_settings_binding_cancelled)
	define_demo_controls()
	$Settings.load_bindings()
	$Settings.build_controls_page($Column/Controls)
	$HudKit.set_text("StatusLabel", "Click a key to change it. Esc cancels.")


func _on_settings_binding_changed(action: String) -> void:
	$Settings.save_bindings()
	$HudKit.set_text("StatusLabel", "%s changed - saved for next time." % action.capitalize())


func _on_settings_binding_conflict(_action: String, taken_by: String) -> void:
	$HudKit.show_panel("ConflictPanel")
	$HudKit.set_text("ConflictLabel", "%s is already used by %s." % [$Settings.pending_binding_words(), taken_by.capitalize()])


func _on_hudkit_on_button_pressed() -> void:
	if $HudKit.button_is("SwapButton"):
		$Settings.swap_the_binding()
		$HudKit.hide_panel("ConflictPanel")
	if $HudKit.button_is("TakeButton"):
		$Settings.take_the_binding_anyway()
		$HudKit.hide_panel("ConflictPanel")
	if $HudKit.button_is("PickAnotherButton"):
		$Settings.pick_another_key()
		$HudKit.hide_panel("ConflictPanel")
	if $HudKit.button_is("ResetAllButton"):
		$Settings.reset_all_bindings()
		$Settings.save_bindings()
		$HudKit.set_text("StatusLabel", "Every control is back to its first key.")
	if $HudKit.button_is("VibrateButton"):
		Input.start_joy_vibration(0, 0.5, 0.5, 0.4)
		$HudKit.set_text("StatusLabel", "Vibrating gamepad 0 (if one is connected).")


func _on_settings_binding_cancelled(_action: String) -> void:
	$HudKit.hide_panel("ConflictPanel")
	$HudKit.set_text("StatusLabel", "Kept the old key.")


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed(&"demo_jump"):
		$HudKit.show_toast("Jump!")
	if Input.is_action_just_pressed(&"demo_dash"):
		$HudKit.show_toast("Dash!")
	if not Input.get_connected_joypads().is_empty():
		$HudKit.set_text("GamepadLabel", gamepad_words())
	else:
		$HudKit.set_text("GamepadLabel", "No gamepad connected - plug one in")


# @ace_hidden
func define_control(action_name: String, key_code: int, pad_button: int) -> void:
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = key_code as Key
	var button: InputEventJoypadButton = InputEventJoypadButton.new()
	button.button_index = pad_button as JoyButton
	ProjectSettings.set_setting("input/" + action_name, {"deadzone": 0.2, "events": [key, button]})


# @ace_hidden
func gamepad_words() -> String:
	var pads: Array = Input.get_connected_joypads()
	var pad_name: String = Input.get_joy_name(pads[0])
	return "%d gamepad(s) - %s" % [pads.size(), pad_name]


# @ace_hidden
func define_demo_controls() -> void:
	define_control("demo_jump", KEY_SPACE, JOY_BUTTON_A)
	define_control("demo_dash", KEY_C, JOY_BUTTON_X)
	InputMap.load_from_project_settings()
