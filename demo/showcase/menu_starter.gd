class_name MenuStarter
extends Control

var time_alive: float = 0.0


func _ready() -> void:
	$HudKit.switch_screen("TitleScreen")
	$HudKit.on_button_pressed.connect(handle_button)


func _process(delta: float) -> void:
	if $HudKit.is_panel_visible("GameScreen"):
		time_alive += delta
		$HudKit.set_text("ScoreLabel", "Time: %0.1fs" % time_alive)


## @ace_hidden
func handle_button() -> void:
	var pressed_button: String = $HudKit.last_button_name_value()
	match pressed_button:
		"StartButton":
			time_alive = 0.0
			$HudKit.switch_screen("GameScreen")
			$HudKit.set_bar("HpBar", 100.0, 100.0)
			$HudKit.show_toast("Good luck!")
		"SettingsButton":
			$HudKit.switch_screen("SettingsScreen")
		"BackButton":
			$HudKit.switch_screen("TitleScreen")
		"PauseButton":
			$HudKit.show_panel("PauseScreen")
		"ResumeButton":
			$HudKit.hide_panel("PauseScreen")
		"MenuButton":
			$HudKit.switch_screen("TitleScreen")
		"QuitButton":
			$HudKit.show_toast("Quit is disabled in the demo.")

# [b]Menu Starter[/b] - a complete menu flow (title / settings / game / pause overlay) driven by [b]one HUD Kit behavior[/b]: screens switch by NAME, bars and labels update by NAME, and every Button reports through the pack's single [b]On Button Pressed[/b] trigger - the scene contains [b]zero connected signals[/b]. Copy this scene as your project's UI starting point.
