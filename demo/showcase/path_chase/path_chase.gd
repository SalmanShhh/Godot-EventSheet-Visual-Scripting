class_name PathChaseDemo
extends Node2D

var bridge_on: bool = false
var __every_repath: float = 0.0
var __every_bridge: float = 0.0


func _ready() -> void:
	$Chaser/Pathfinding.build_nav_graph($Level)
	$Chaser/Pathfinding.add_portal(976.0, 528.0, 176.0, 304.0, true)
	$Chaser/Pathfinding.set_nav_debug_draw(true)


func _process(delta: float) -> void:
	__every_repath += delta
	if __every_repath >= maxf(1.0, 0.001):
		__every_repath = fmod(__every_repath, maxf(1.0, 0.001))
		$Chaser/Pathfinding.find_path_to_node($Player, "nearest")
	__every_bridge += delta
	if __every_bridge >= maxf(3.0, 0.001):
		__every_bridge = fmod(__every_bridge, maxf(3.0, 0.001))
		toggle_bridge()
	if Input.is_action_just_pressed("ui_accept"):
		$Player/Movement.jump()
	if Input.is_action_just_released("ui_accept"):
		$Player/Movement.jump_released()


## @ace_hidden
func toggle_bridge() -> void:
	bridge_on = not bridge_on
	for x in range(15, 18):
		if bridge_on:
			$Level.set_cell(Vector2i(x, 17), 0, Vector2i.ZERO)
		else:
			$Level.erase_cell(Vector2i(x, 17))
	$Chaser/Pathfinding.regenerate_nav_graph()

# [b]Path Chase[/b] - Platformer Pathfinding + Platformer Movement on one Chaser: the graph is built from the TileMapLayer once, then Find Path To Node re-routes to the Player every second. The pathfinder derives jump reach from the movement pack and steers it through the ai_move_axis seam - the same movement rules you play with, variable jump included. The purple PORTAL pair links the ground to the floating platform (blink on arrival), and the tile BRIDGE over the gap toggles every 3 seconds + Regenerate Nav Graph, so the route flips between walking it and jumping the gap live. Green line = the Chaser's path.
