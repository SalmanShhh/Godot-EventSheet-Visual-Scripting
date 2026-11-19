extends Node

var enemies_alive: int = 0
var wave_number: int = 1


func _ready() -> void:
	if Performance.has_custom_monitor("Game/Enemies"):
		Performance.remove_custom_monitor("Game/Enemies")
	Performance.add_custom_monitor("Game/Enemies", func(): return enemies_alive)
	tree_exiting.connect(func(): if Performance.has_custom_monitor("Game/Enemies"): Performance.remove_custom_monitor("Game/Enemies"))
	if Performance.has_custom_monitor("Game/Nodes"):
		Performance.remove_custom_monitor("Game/Nodes")
	Performance.add_custom_monitor("Game/Nodes", func(): return get_tree().get_node_count())
	tree_exiting.connect(func(): if Performance.has_custom_monitor("Game/Nodes"): Performance.remove_custom_monitor("Game/Nodes"))
