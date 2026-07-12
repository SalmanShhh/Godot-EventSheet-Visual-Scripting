extends Node3D

var __every_stalk: float = 0.0

func _ready() -> void:
	print("FPS Arena - WASD/arrows move, mouse looks, Shift sprints, Space jumps, Tab flips the camera, Esc frees the mouse.")
	$Stalker/Navigator.bake_navigation_region($NavRegion)

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_focus_next"):
		$Player/FPSController.toggle_camera_mode()
	__every_stalk += delta
	if __every_stalk >= maxf(1.0, 0.001):
		__every_stalk = fmod(__every_stalk, maxf(1.0, 0.001))
		$Stalker/Navigator.find_path_to_node($Player, "nearest")

# FPS Arena: the FPSController behavior does all the work - this sheet only prints the controls and flips the camera mode on Tab.
