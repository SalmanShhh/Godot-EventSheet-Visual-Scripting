class_name TopDownShooter
extends Node2D

## Monsters blown up.
@export var score: int = 0
var __every_monster_arrives: float = 0.0

func _process(delta: float) -> void:
	$Player.rotation = $Player.global_position.direction_to(get_global_mouse_position()).angle()
	__every_monster_arrives += delta
	if __every_monster_arrives >= maxf(1.2, 0.001):
		__every_monster_arrives = fmod(__every_monster_arrives, maxf(1.2, 0.001))
		var __spawn_monster = load("res://demo/showcase/top_down_shooter/monster.tscn").instantiate()
		__spawn_monster.position = [Vector2(randf_range(0.0, 1152.0), -30.0), Vector2(randf_range(0.0, 1152.0), 680.0)].pick_random()
		add_child(__spawn_monster)
	for shooter_monster in get_tree().get_nodes_in_group("family_shooter_monster"):
		if not (shooter_monster.health <= 0):
			continue
		var __spawn_boom = load("res://demo/showcase/top_down_shooter/explosion.tscn").instantiate()
		__spawn_boom.position = shooter_monster.position
		add_child(__spawn_boom)
		score += 1
		shooter_monster.queue_free()
	$Hud.text = "Score %d    arrows move, click to fire" % [score]

func _input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		var __spawn_bullet = load("res://demo/showcase/top_down_shooter/bullet.tscn").instantiate()
		__spawn_bullet.position = $Player.position
		add_child(__spawn_bullet)

# [b]Top-Down Shooter[/b] - the first game most event-sheet users make, built here in four small sheets: the player faces the mouse and fires where it points, monsters walk in from the edges, and one picking row - For each Monster where health <= 0 - blows up every monster that has run out of health.
