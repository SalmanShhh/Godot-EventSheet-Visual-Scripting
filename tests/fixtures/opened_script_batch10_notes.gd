extends Node2D

signal died

var event: Array = []
var hp: int = 100
var target: Vector2 = Vector2.ZERO

## Moves the player toward the cursor.
func chase() -> void:
	position = position.move_toward(target, 100.0)  # TODO tweak
	hp -= 1  # ouch
	# FIXME: this double-fires on respawn
	died.emit()

func handle(delta: float) -> void:
	match event:
		["move", var x, var y]:
			position = Vector2(x, y)
		{"type": "hit", "amount": var a}:
			hp -= a
		var other when other is String:
			print(other)
		_:
			pass
	for i in range(10, 0, -1):
		print(i)
	for i in range(0, 100, 10):
		print(i, delta)
