## The root script of the scene fixture. Its `_ready` wires three signals to functions that live on
## OTHER objects - a plain callable, a bound one, and the Callable() spelling with a one-shot flag -
## which is the shape the wired-up-call reading is about. Its own handler is wired in the .tscn.
class_name OpenedSceneLevel
extends Node2D

@onready var player: OpenedScenePlayer = $Player
@onready var hud: OpenedSceneHud = $HUD


func _ready() -> void:
	$StartButton.pressed.connect(player.reset)
	$WaveTimer.timeout.connect(hud.show_wave.bind(3))
	$WaveTimer.timeout.connect(Callable(hud, "show_wave").bind(9), CONNECT_ONE_SHOT)


func _on_start_button_pressed() -> void:
	player.reset()
