extends Node2D


class Stats:
	var hp := 10
	var atk := 2


var target: Node2D = null
var facing: Vector2 = Vector2(1, 0)
var enemy: Node2D = null


func _process(delta: float) -> void:
	var dir = (target.position - position).normalized()
	var dist = velocity.length()
	var dot = facing.dot(dir)
	var side = dir.rotated(PI / 2)
	var stats := Stats.new()
	var hud = find_child("HUD")
	var boss = get_tree().current_scene.get_node("Boss")
	var path = enemy.get_path()
	modulate = Color.RED.darkened(0.2)
	modulate = modulate.lerp(Color.WHITE, 5 * delta)
	var copy = enemy.duplicate()
	get_parent().add_child(copy)
	print(dir, dist, dot, side, stats, hud, boss, path)
