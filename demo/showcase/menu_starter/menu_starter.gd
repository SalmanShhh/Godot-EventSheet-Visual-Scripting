class_name MenuStarter
extends Control
## [b]Menu Starter[/b] - a complete menu flow (title / settings / game / pause overlay) driven by [b]one HUD Kit behavior[/b]: screens switch by NAME, bars and labels update by NAME, and every Button reports through the pack's single [b]On Button Pressed[/b] trigger - the scene contains [b]zero connected signals[/b]. Copy this scene as your project's UI starting point.

# Nodes this sheet calls, declared once with their type.
@onready var hud_kit: HudKitBehavior = $HudKit

var time_alive: float = 0.0


func _ready() -> void:
	hud_kit.switch_screen("TitleScreen")
	hud_kit.on_button_pressed.connect(handle_button)


func _process(delta: float) -> void:
	if hud_kit.is_panel_visible("GameScreen"):
		time_alive += delta
		hud_kit.set_text("ScoreLabel", "Time: %0.1fs" % time_alive)


# @ace_hidden
func handle_button() -> void:
	var pressed_button: String = hud_kit.last_button_name_value()
	match pressed_button:
		"StartButton":
			time_alive = 0.0
			hud_kit.switch_screen("GameScreen")
			hud_kit.set_bar("HpBar", 100.0, 100.0)
			hud_kit.show_toast("Good luck!")
		"SettingsButton":
			hud_kit.switch_screen("SettingsScreen")
		"BackButton":
			hud_kit.switch_screen("TitleScreen")
		"PauseButton":
			hud_kit.show_panel("PauseScreen")
		"ResumeButton":
			hud_kit.hide_panel("PauseScreen")
		"MenuButton":
			hud_kit.switch_screen("TitleScreen")
		"QuitButton":
			hud_kit.show_toast("Quit is disabled in the demo.")
