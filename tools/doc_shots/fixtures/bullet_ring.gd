extends Node2D

@export var bullet_scene: PackedScene
var total: int = 0


func fire_ring(n: int, radius: float) -> void:
	for i in n:
		var angle := TAU * float(i) / float(n)
		var b = bullet_scene.instantiate()
		add_child(b)
		b.position = position + Vector2(cos(angle), sin(angle)) * radius


func count_shots(n: int) -> void:
	for i in n:
		total += i
