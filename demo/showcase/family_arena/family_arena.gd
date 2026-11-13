class_name FamilyArena
extends Node2D

## How many Enemies to spawn.
@export_range(4, 60, 1) var spawn_count: int = 18
var __every_strike_fam: float = 0.0
var __every_hud_fam: float = 0.0

func _ready() -> void:
	var __cols: int = 6
	for __i: int in range(spawn_count):
		var __e: Enemy = load("res://demo/showcase/family_arena/enemy.tscn").instantiate()
		__e.position = Vector2(80.0 + float(__i % __cols) * 90.0, 40.0 + floorf(__i / float(__cols)) * 80.0)
		add_child(__e)

func _process(delta: float) -> void:
	__every_strike_fam += delta
	if __every_strike_fam >= maxf(0.5, 0.001):
		__every_strike_fam = fmod(__every_strike_fam, maxf(0.5, 0.001))
		for enemy: Enemy in get_tree().get_nodes_in_group("family_enemy"):
			enemy.take_damage(1)
	__every_hud_fam += delta
	if __every_hud_fam >= maxf(0.5, 0.001):
		__every_hud_fam = fmod(__every_hud_fam, maxf(0.5, 0.001))
		$Info.text = "%d Enemies · each one falls on its own" % [get_tree().get_node_count_in_group("family_enemy")]

# [b]Family Arena[/b] - each [b]Enemy[/b] owns its own behaviour: its sheet moves it by its own fall_speed, so nothing outside has to. This arena sheet does only what is shared: it spawns the Enemies, and it runs the one rule that is about the whole family - a strike that walks every Enemy (a typed For each over the family) and damages every one through the Enemy: Take Damage ACE. Add a new enemy type and not one rule changes - that's horizontal reuse.
