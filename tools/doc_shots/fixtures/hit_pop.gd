extends Sprite2D


func pop() -> void:
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.25).set_trans(Tween.TRANS_SINE)
	t.tween_property(self, "position:y", -8.0, 0.3).set_ease(Tween.EASE_OUT)
	t.set_parallel()
	t.tween_property(self, "scale", Vector2(1, 1), 0.2)
