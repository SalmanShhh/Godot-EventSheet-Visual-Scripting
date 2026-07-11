extends Node3D

func _ready() -> void:
	print("FPS Arena - WASD/arrows move, mouse looks, Shift sprints, Space jumps, Tab flips the camera, Esc frees the mouse.")

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_focus_next"):
		$Player/FPSController.toggle_camera_mode()

# FPS Arena: the FPSController behavior does all the work - this sheet only prints the controls and flips the camera mode on Tab.
