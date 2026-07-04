class_name FamilyArena
extends Node2D

## How many Enemies to spawn.
@export_range(4, 60, 1) var spawn_count: int = 18
var __every_strike_fam: float = 0.0


func _ready() -> void:
	var __cols: int = 6
	for __i: int in range(spawn_count):
		var __e: Sprite2D = load("res://demo/showcase/enemy.tscn").instantiate()
		__e.position = Vector2(80.0 + float(__i % __cols) * 90.0, 40.0 + float(__i / __cols) * 80.0)
		add_child(__e)


func _process(delta: float) -> void:
	for enemy in get_tree().get_nodes_in_group("family_enemy"):
		enemy.position.y += enemy.fall_speed * delta
		if enemy.position.y > 560.0:
			enemy.position.y = -20.0
	__every_strike_fam += delta
	if __every_strike_fam >= maxf(0.5, 0.001):
		__every_strike_fam = fmod(__every_strike_fam, maxf(0.5, 0.001))
		var __e = get_tree().get_nodes_in_group("family_enemy").pick_random()
		if __e != null:
			__e.take_damage(1)
		$Info.text = "%d Enemies · one family For Each moves them all" % [get_tree().get_node_count_in_group("family_enemy")]

# [b]Family Arena[/b] - the Families trio in one screen. [b]Enemy[/b] is a Family: a Sprite2D whose instances auto-join the family_enemy group, each carrying its own health + fall_speed. This sheet writes ONE rule per behaviour over ALL of them - a family For Each makes every Enemy fall by its own speed and recycle at the bottom, and a timer damages a random one through the Enemy: Take Damage ACE. Add a new enemy type and not one rule changes - that's horizontal reuse, the thing event sheets were missing.
