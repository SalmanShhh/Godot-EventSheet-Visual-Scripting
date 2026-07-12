class_name PathChaseDemo
extends Node2D

var __every_repath: float = 0.0


func _ready() -> void:
	$Chaser/Pathfinding.build_nav_graph($Level)
	$Chaser/Pathfinding.set_nav_debug_draw(true)


func _process(delta: float) -> void:
	__every_repath += delta
	if __every_repath >= maxf(1.0, 0.001):
		__every_repath = fmod(__every_repath, maxf(1.0, 0.001))
		$Chaser/Pathfinding.find_path_to_node($Player, "nearest")
	if Input.is_action_just_pressed("ui_accept"):
		$Player/Movement.jump()
	if Input.is_action_just_released("ui_accept"):
		$Player/Movement.jump_released()

# [b]Path Chase[/b] - Platformer Pathfinding + Platformer Movement on one Chaser: the graph is built from the TileMapLayer once, then Find Path To Node re-routes to the Player every second. The pathfinder derives jump reach from the movement pack and steers it through the ai_move_axis seam - the same movement rules you play with. Green line = the Chaser's live path.
