extends CharacterBody3D

@onready var cam: Camera3D = $Camera3D
@export var tilt_strength := 900.0
var neutral := Vector3.ZERO


func calibrate() -> void:
	neutral = Input.get_accelerometer()


func steer_by_tilt(delta: float) -> void:
	var tilt := Input.get_accelerometer() - neutral
	velocity.x = tilt.x * tilt_strength * delta


func aim_by_gyro(delta: float) -> void:
	var rate := Input.get_gyroscope()
	rotate_y(-rate.y * delta)
	cam.rotate_x(-rate.x * delta)
