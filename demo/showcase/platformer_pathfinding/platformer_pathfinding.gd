class_name PlatformerPathfindingDemo
extends Node2D

func _ready() -> void:
	$Chaser/Pathfinding.build_nav_graph($Level)
	$Chaser/Pathfinding.set_nav_debug_draw(true)
	$Chaser/Pathfinding.find_path_to_node($Player, "nearest")

func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed(&"ui_accept"):
		$Player/Movement.jump()
	if Input.is_action_just_released(&"ui_accept"):
		$Player/Movement.jump_released()

# [b]Platformer Pathfinding[/b] - the smallest chaser the pack can make. On ready the graph is built from the TileMapLayer and Find Path To Node is called ONCE: the follow re-routes itself from then on, so there is no repath timer to write. The Chaser carries no movement code of its own - Platformer Pathfinding steers the sibling Platformer Movement through its ai_move_axis seam, which is why it accelerates, jumps the 3-tile gap and climbs both ledges under exactly the rules you play by. Green line = the route it is walking.
