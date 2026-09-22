class_name ShooterBullet
extends Area2D

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	self.rotation = global_position.direction_to(get_global_mouse_position()).angle()
	await get_tree().create_timer(1.5).timeout
	queue_free()

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("family_shooter_monster"):
		area.health += -1
		queue_free()
