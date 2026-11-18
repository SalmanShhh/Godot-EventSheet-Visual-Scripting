class_name InputRebindDemo
extends Control
## [b]Input Rebind[/b] - a rebinding screen on the Game Settings rows. Click a key, press another, and a clash asks Swap, Take it anyway or Pick another key; Esc cancels; the keyboard and pad columns are kept side by side; and Save Bindings keeps the choice for the next launch (user://settings.cfg, section [bindings]). In your own project the Game Settings pack is the Settings autoload, so the rows read Settings.save_bindings(); here the same pack is a child node named Settings, so they read $Settings.save_bindings(). The two demo controls are declared the way Project Settings declares them, so Reset works exactly as in a real project, and project.godot is left alone.


func _ready() -> void:
	$Settings.binding_changed.connect(_on_settings_binding_changed)
	$Settings.binding_conflict.connect(_on_settings_binding_conflict)
	$Column/ConflictPanel/Box/Answers/SwapButton.pressed.connect(_on_column_conflictpanel_box_answers_swapbutton_pressed)
	$Column/ConflictPanel/Box/Answers/TakeButton.pressed.connect(_on_column_conflictpanel_box_answers_takebutton_pressed)
	$Column/ConflictPanel/Box/Answers/PickAnotherButton.pressed.connect(_on_column_conflictpanel_box_answers_pickanotherbutton_pressed)
	$Settings.binding_cancelled.connect(_on_settings_binding_cancelled)
	$Column/ResetAllButton.pressed.connect(_on_column_resetallbutton_pressed)
	$Column/VibrateButton.pressed.connect(_on_column_vibratebutton_pressed)
	define_demo_controls()
	$Settings.load_bindings()
	$Settings.build_controls_page($Column/Controls)


func _on_settings_binding_changed(action: String) -> void:
	$Settings.save_bindings()
	$HudKit.set_text("StatusLabel", action + " is now " + $Settings.key_binding_of(action))


func _on_settings_binding_conflict(_action: String, taken_by: String) -> void:
	$HudKit.show_panel("ConflictPanel")
	$HudKit.set_text("ConflictLabel", $Settings.pending_binding_words() + " is already used by " + taken_by)


func _on_column_conflictpanel_box_answers_swapbutton_pressed() -> void:
	$Settings.swap_the_binding()
	$HudKit.hide_panel("ConflictPanel")


func _on_column_conflictpanel_box_answers_takebutton_pressed() -> void:
	$Settings.take_the_binding_anyway()
	$HudKit.hide_panel("ConflictPanel")


func _on_column_conflictpanel_box_answers_pickanotherbutton_pressed() -> void:
	$Settings.pick_another_key()
	$HudKit.hide_panel("ConflictPanel")


func _on_settings_binding_cancelled(_action: String) -> void:
	$HudKit.hide_panel("ConflictPanel")
	$HudKit.set_text("StatusLabel", "Kept the old key.")


func _on_column_resetallbutton_pressed() -> void:
	$Settings.reset_all_bindings()
	$Settings.save_bindings()


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed(&"demo_jump"):
		$HudKit.show_toast("Jump!")
	if Input.is_action_just_pressed(&"demo_dash"):
		$HudKit.show_toast("Dash!")
	if not Input.get_connected_joypads().is_empty():
		$HudKit.set_text("GamepadLabel", gamepad_words())
	else:
		$HudKit.set_text("GamepadLabel", "Pad: none connected")


func _on_column_vibratebutton_pressed() -> void:
	Input.start_joy_vibration(0, 0.5, 0.5, 0.4)


# @ace_hidden
func define_control(action_name: String, key_code: int, pad_button: int = -1) -> void:
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = key_code as Key
	var events: Array = [key]
	if pad_button >= 0:
		var button: InputEventJoypadButton = InputEventJoypadButton.new()
		button.button_index = pad_button as JoyButton
		events.append(button)
	ProjectSettings.set_setting("input/" + action_name, {"deadzone": 0.2, "events": events})


# @ace_hidden
func gamepad_words() -> String:
	var pads: Array = Input.get_connected_joypads()
	var pad_name: String = Input.get_joy_name(pads[0])
	return "Pad: %s" % pad_name


# @ace_hidden
func define_demo_controls() -> void:
	define_control("demo_jump", KEY_SPACE, JOY_BUTTON_A)
	define_control("demo_dash", KEY_C, JOY_BUTTON_X)
	InputMap.load_from_project_settings()
