extends Control

var stroke: PackedVector2Array = PackedVector2Array()
var down_at: Vector2 = Vector2.ZERO
var down_time: float = 0.0


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			stroke.clear()
			down_at = event.position
			down_time = Time.get_ticks_msec() / 1000.0
			stroke.append(event.position)
		else:
			print(stroke.size())
	elif event is InputEventScreenDrag:
		stroke.append(event.position)
