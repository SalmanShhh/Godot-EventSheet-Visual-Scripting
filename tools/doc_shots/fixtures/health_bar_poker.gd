extends Node2D


func _ready() -> void:
	$Sprite.visible = false
	%HealthBar.modulate = Color(1, 0.4, 0.4, 1)
	position = Vector2(0, 0)
