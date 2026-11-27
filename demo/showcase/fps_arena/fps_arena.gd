extends Node3D
## [b]FPS Arena[/b] - A first-person controller with a weapon and targets. The FPSController behavior does all the work, and this sheet only prints the controls and flips the camera mode on Tab.

# Nodes this sheet calls, declared once with their type.
@onready var navigator: NavAgent3D = $Stalker/Navigator
@onready var fps_controller: FPSController = $Player/FPSController

var __every_stalk: float = 0.0

func _ready() -> void:
	print("FPS Arena - WASD/arrows move, mouse looks, Shift sprints, Space jumps, Tab flips the camera, Esc frees the mouse.")
	navigator.bake_navigation_region($NavRegion)

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_focus_next"):
		fps_controller.toggle_camera_mode()
	__every_stalk += delta
	if __every_stalk >= 1.0:
		__every_stalk = fmod(__every_stalk, 1.0)
		navigator.find_path_to_node($Player, "nearest")
