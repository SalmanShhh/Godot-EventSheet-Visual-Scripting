class_name OptionsAndQuickSaveDemo
extends Control
## [b]Options and Quick Save[/b] - three kinds of thing a game keeps, each in its own file. Master volume and fullscreen are options (Settings, user://settings.cfg); the controls, F5 and F9 among them, are saved bindings (the same file, section [bindings]); and coins, player_spot and picked_coins are the game itself, set to Manually in Save Studio, Saving your game, What gets saved, so F5 (Save Game) writes them to user://save_0.cfg and F9 (Load Game) brings them back. picked_coins is there so a coin you picked up stays gone after a relaunch and a load: without it the player would load onto a coin that had come back and pick it up twice. Tab opens the options. In your own project the Game Settings and Save System packs are the Settings and SaveSystem autoloads, so the rows read Settings.save_all_settings() and SaveSystem.save_game(); here they sit under a plain Services node, standing in for the autoloads, so they read $Services/Settings. and $Services/SaveSystem. They are not children of the saved object on purpose: Save Game snapshots the behaviours that sit directly on a saved node, and the options are kept in their own file.

@onready var settings: GameSettingsAddon = $Services/Settings
@onready var save_system: SaveSystemAddon = $Services/SaveSystem
@onready var hud_kit: HudKitBehavior = $HudKit

## Coins picked up in this run.
var coins: int = 0
## Where the player stands, kept for a quick save.
var player_spot: Vector2 = Vector2(200.0, 300.0)
## Names of the coins already picked up, so a coin stays gone after a quick load.
var picked_coins: Array = []


func _ready() -> void:
	settings.setting_changed.connect(_on_services_settings_setting_changed)
	settings.binding_changed.connect(_on_services_settings_binding_changed)
	$OptionsPanel/Box/BackButton.pressed.connect(_on_optionspanel_box_backbutton_pressed)
	save_system.before_save.connect(_on_services_savesystem_before_save)
	save_system.after_load.connect(_on_services_savesystem_after_load)
	save_system.save_written.connect(_on_services_savesystem_save_written)
	save_system.load_failed.connect(_on_services_savesystem_load_failed)
	settings.declare_setting("master_volume", 80, "percent")
	settings.declare_setting("fullscreen", false, "toggle")
	define_controls()
	settings.load_all_settings()
	settings.load_bindings()
	settings.apply_all_settings()
	settings.bind_control($OptionsPanel/Box/VolumeRow/master_volume, "master_volume")
	settings.bind_control($OptionsPanel/Box/fullscreen, "fullscreen")
	settings.build_controls_page($OptionsPanel/Box/Controls)
	if save_system.slot_exists(0):
		hud_kit.set_text("QuickLoadHint", settings.key_binding_of("quick_load") + " Quick load")
	else:
		hud_kit.set_text("QuickLoadHint", settings.key_binding_of("quick_load") + " Quick load (no quick save yet)")


func _on_services_settings_setting_changed(_setting_name: String, value: Variant) -> void:
	if settings.changed_setting_is("master_volume"):
		AudioServer.set_bus_volume_db(0, linear_to_db(clampf(value / 100.0, 0.0, 1.0)))
		hud_kit.set_text("VolumeValue", str(int(value)))
	if settings.changed_setting_is("fullscreen"):
		if value:
			get_window().mode = Window.MODE_FULLSCREEN
		else:
			get_window().mode = Window.MODE_WINDOWED


func _on_services_settings_binding_changed(_action: String) -> void:
	settings.save_bindings()
	hud_kit.set_text("QuickLoadHint", settings.key_binding_of("quick_load") + " Quick load")


func _on_optionspanel_box_backbutton_pressed() -> void:
	settings.save_all_settings()
	settings.save_bindings()
	hud_kit.switch_screen("GameScreen")


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"quick_save"):
		save_system.save_game()
	if event.is_action_pressed(&"quick_load"):
		save_system.load_game()
	if event.is_action_pressed(&"ui_focus_next"):
		hud_kit.switch_screen("OptionsPanel")


func _on_services_savesystem_before_save(_slot_index: int) -> void:
	player_spot = $GameScreen/Player.position


func _on_services_savesystem_after_load(_slot_index: int) -> void:
	$GameScreen/Player.position = player_spot
	hide_picked_coins()
	hud_kit.set_text("CoinsLabel", "Coins: " + str(coins))
	hud_kit.show_toast("Loaded")


func _on_services_savesystem_save_written(_slot_index: int) -> void:
	hud_kit.show_toast("Saved (slot 0)")
	hud_kit.set_text("QuickLoadHint", settings.key_binding_of("quick_load") + " Quick load")


func _on_services_savesystem_load_failed(_slot_index: int, reason: String) -> void:
	hud_kit.show_toast(reason)


func _process(delta: float) -> void:
	if hud_kit.is_panel_visible("GameScreen"):
		$GameScreen/Player.position += Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down") * 240.0 * delta
	for coin: Node in get_tree().get_nodes_in_group("coins"):
		if coin.visible and $GameScreen/Player.overlaps_area(coin):
			coins += 1
			picked_coins.append(str(coin.name))
			coin.hide()
			hud_kit.set_text("CoinsLabel", "Coins: " + str(coins))


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
func define_controls() -> void:
	define_control("jump", KEY_SPACE, JOY_BUTTON_A)
	define_control("quick_save", KEY_F5)
	define_control("quick_load", KEY_F9)
	InputMap.load_from_project_settings()


# @ace_hidden
func hide_picked_coins() -> void:
	for child: Node in $GameScreen/Coins.get_children():
		(child as CanvasItem).visible = not picked_coins.has(str(child.name))

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
