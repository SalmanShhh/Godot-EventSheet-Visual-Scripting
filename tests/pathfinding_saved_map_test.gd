# Godot EventSheets - Platformer Pathfinding: an obstacle map saved by an older version still loads.
#
# The route, link, portal, hazard and platform records inside the behaviour are small typed classes,
# but the only text the behaviour saves is the obstacle map JSON, and that stays exactly what it was.
# This loads a map written in the old form as plain text, pins what the behaviour reads out of it
# (tile states, graph nodes, link kinds) and pins that saving it again gives the same text.
@tool
class_name PathfindingSavedMapTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const NAME: String = "pathfinding_saved_map_test"
const PACK: String = "res://eventsheet_addons/platformer_pathfinding/platformer_pathfinding_behavior.gd"

## A map exactly as the behaviour wrote it before its records became classes.
const OLD_FORM: String = "{\"cell_size\":16.0,\"cells\":[[0,3,\"solid\"],[1,3,\"solid\"],[2,3,\"solid\"],[3,3,\"jump_thru\"],[4,3,\"solid\"],[5,3,\"solid\"]],\"origin\":[0.0,0.0],\"size\":[6,4],\"version\":1}"


static func run() -> bool:
	var script: GDScript = load(PACK) as GDScript
	var nav: Node = script.new() as Node
	nav.call("load_obstacle_map_json", OLD_FORM)
	var resaved: String = str(nav.call("obstacle_map_json"))
	var rows: Array = [
		["the old map reads as a custom grid", nav.call("obstacle_map_source"), "custom"],
		["its tile states are read", [nav.call("tile_state", 0, 3), nav.call("tile_state", 3, 3), nav.call("tile_state", 0, 2)], ["solid", "jump_thru", "clear"]],
		["its standing cells become graph nodes", nav.call("graph_node_count"), 6],
		["a walk link joins two neighbours", nav.call("graph_node_connection_kind", 0, 2, 0), "walk"],
		["saving it again gives the same map", JSON.parse_string(resaved), JSON.parse_string(OLD_FORM)],
		["and the same text once a second pass has written it", str(_reload(script, resaved)), resaved],
	]
	nav.free()
	return SUPPORT.pins(NAME, rows)


## Loads a map text into a fresh behaviour and writes it out again.
static func _reload(script: GDScript, text: String) -> String:
	var copy: Node = script.new() as Node
	copy.call("load_obstacle_map_json", text)
	var again: String = str(copy.call("obstacle_map_json"))
	copy.free()
	return again
