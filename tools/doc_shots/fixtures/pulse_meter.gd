extends Node2D

@export var speed: float = 200.0
var hp: int = 100:
	set(value):
		hp = clampi(value, 0, 100)
	get:
		return hp


func flash() -> void:
	var t := create_tween()
	t.tween_property(self, "position", Vector2.ZERO, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "modulate:a", 0.0, 0.3)
	t.tween_callback(queue_free)
