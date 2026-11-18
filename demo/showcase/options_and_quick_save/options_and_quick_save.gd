class_name OptionsAndQuickSaveDemo
extends Control
## [b]Options and Quick Save[/b] - three kinds of thing a game keeps, each in its own file. Master volume and fullscreen are options (Settings, user://settings.cfg); the controls, F5 and F9 among them, are saved bindings (the same file, section [bindings]); and coins, player_spot and picked_coins are the game itself, set to Manually in Save Studio, Saving your game, What gets saved, so F5 (Save Game) writes them to user://save_0.cfg and F9 (Load Game) brings them back. Tab opens the options. In your own project the Game Settings and Save System packs are the Settings and SaveSystem autoloads, so the rows read Settings.save_all_settings() and SaveSystem.save_game(); here they are child nodes of the same names, so they read $Settings. and $SaveSystem.

var coins: int = 0
var player_spot: Vector2 = Vector2(200.0, 300.0)
var picked_coins: Array = []


func _ready() -> void:
	$Settings.setting_changed.connect(_on_settings_setting_changed)
	$Settings.binding_changed.connect(_on_settings_binding_changed)
	$HudKit.on_button_pressed.connect(_on_hudkit_on_button_pressed)
	$SaveSystem.before_save.connect(_on_savesystem_before_save)
	$SaveSystem.after_load.connect(_on_savesystem_after_load)
	$SaveSystem.save_written.connect(_on_savesystem_save_written)
	$SaveSystem.load_failed.connect(_on_savesystem_load_failed)
	$Settings.declare_setting("master_volume", 80, "percent", "", "", "")
	$Settings.declare_setting("fullscreen", false, "toggle", "", "", "")
	define_controls()
	$Settings.load_all_settings()
	$Settings.load_bindings()
	$Settings.bind_control($OptionsPanel/Box/VolumeRow/master_volume, "master_volume")
	$Settings.bind_control($OptionsPanel/Box/fullscreen, "fullscreen")
	$Settings.build_controls_page($OptionsPanel/Box/Controls)
	$Settings.apply_all_settings()
	refresh_hints()


func _on_settings_setting_changed(_setting_name: String, value: Variant) -> void:
	if $Settings.changed_setting_is("master_volume"):
		AudioServer.set_bus_volume_db(0, linear_to_db(clampf(float(value) / 100.0, 0.0, 1.0)))
	if $Settings.changed_setting_is("fullscreen"):
		if value:
			get_window().mode = Window.MODE_FULLSCREEN
		else:
			get_window().mode = Window.MODE_WINDOWED


func _on_settings_binding_changed(_action: String) -> void:
	refresh_hints()


func _on_hudkit_on_button_pressed() -> void:
	if $HudKit.button_is("BackButton"):
		$Settings.save_all_settings()
		$Settings.save_bindings()
		$HudKit.hide_panel("OptionsPanel")


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"quick_save"):
		$SaveSystem.save_game()
	if event.is_action_pressed(&"quick_load"):
		$SaveSystem.load_game()
	if event.is_action_pressed(&"open_options"):
		$HudKit.show_panel("OptionsPanel")


func _on_savesystem_before_save(_slot_index: int) -> void:
	player_spot = $GameScreen/Player.position


func _on_savesystem_after_load(slot_index: int) -> void:
	$GameScreen/Player.position = player_spot
	hide_picked_coins()
	$HudKit.set_text("CoinsLabel", "Coins: %d" % coins)
	$HudKit.show_toast("Loaded (slot %d)" % slot_index)


func _on_savesystem_save_written(slot_index: int) -> void:
	$HudKit.show_toast("Saved (slot %d)" % slot_index)
	refresh_hints()


func _on_savesystem_load_failed(_slot_index: int, reason: String) -> void:
	$HudKit.show_toast(reason)


func _process(delta: float) -> void:
	if not $OptionsPanel.visible:
		$GameScreen/Player.position += Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down") * 240.0 * delta
		collect_coins()


# @ace_hidden
func define_control(action_name: String, key_code: int, pad_button: int) -> void:
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = key_code as Key
	var button: InputEventJoypadButton = InputEventJoypadButton.new()
	button.button_index = pad_button as JoyButton
	ProjectSettings.set_setting("input/" + action_name, {"deadzone": 0.2, "events": [key, button]})


# @ace_hidden
func define_controls() -> void:
	define_control("quick_save", KEY_F5, JOY_BUTTON_BACK)
	define_control("quick_load", KEY_F9, JOY_BUTTON_START)
	define_control("open_options", KEY_TAB, JOY_BUTTON_Y)
	InputMap.load_from_project_settings()


# @ace_hidden
func refresh_hints() -> void:
	var load_hint: String = "%s Quick load" % $Settings.key_binding_of("quick_load")
	if not $SaveSystem.slot_exists(0):
		load_hint += " (no quick save yet)"
	$HudKit.set_text("HintLabel", "%s Quick save   |   %s   |   %s Options" % [$Settings.key_binding_of("quick_save"), load_hint, $Settings.key_binding_of("open_options")])


# @ace_hidden
func collect_coins() -> void:
	for child: Node in $GameScreen/Coins.get_children():
		var coin: ColorRect = child as ColorRect
		if coin.visible and $GameScreen/Player.position.distance_to(coin.position) < 30.0:
			coin.visible = false
			coins += 1
			picked_coins.append(str(coin.name))
			$HudKit.set_text("CoinsLabel", "Coins: %d" % coins)


# @ace_hidden
func hide_picked_coins() -> void:
	for child: Node in $GameScreen/Coins.get_children():
		(child as ColorRect).visible = not picked_coins.has(str(child.name))

## Saved by each variable's Save choice (Save Studio > What gets saved) - change the choice, not these lines.
@warning_ignore("unused_private_class_variable")
@onready var __ef_save_boot: bool = _ef_load_saved()


func _ef_load_saved() -> bool:
	add_to_group("persist")
	return true


func save_state() -> Dictionary:
	return {
		"coins": coins,
		"player_spot": player_spot,
		"picked_coins": picked_coins.duplicate(true)
	}


func load_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	coins = int(state.get("coins", coins))
	player_spot = state.get("player_spot", player_spot)
	picked_coins = (state.get("picked_coins", []) as Array).duplicate(true)
