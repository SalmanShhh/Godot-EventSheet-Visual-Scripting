class_name PlatformerPathfindingDemo
extends Node2D
## [b]Platformer Pathfinding[/b] - the smallest chaser the pack can make. On ready the graph is built from the TileMapLayer and Find Path To Node is called ONCE: the follow re-routes itself from then on, so there is no repath timer to write. The Chaser carries no movement code of its own - Platformer Pathfinding steers the sibling Platformer Movement through its ai_move_axis seam, which is why it accelerates, jumps the 3-tile gap and climbs both ledges under exactly the rules you play by. Green line = the route it is walking.

# Nodes this sheet calls, declared once with their type.
@onready var pathfinding: PlatformerPathfinding = $Chaser/Pathfinding
@onready var movement: PlatformerMovement = $Player/Movement

func _ready() -> void:
	pathfinding.build_nav_graph($Level)
	pathfinding.set_nav_debug_draw(true)
	pathfinding.find_path_to_node($Player, "nearest")

func _physics_process(_delta: float) -> void:
	if Input.is_action_just_pressed(&"ui_accept"):
		movement.jump()
	if Input.is_action_just_released(&"ui_accept"):
		movement.jump_released()
