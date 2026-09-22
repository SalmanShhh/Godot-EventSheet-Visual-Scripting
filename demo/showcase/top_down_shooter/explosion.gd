class_name ShooterExplosion
extends CPUParticles2D

func _ready() -> void:
	await get_tree().create_timer(0.6).timeout
	queue_free()
