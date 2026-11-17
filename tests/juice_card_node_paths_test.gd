# Godot EventSheets - the node box of Set Juice Card Field offers a node's path the way a card stores it.
#
# THE ONE THING THIS FILE IS ABOUT: a card keeps a node as a path measured from the Juice Player that plays the
# card, so a scene can be moved or copied and the card still finds its node. The box of the row that writes one
# value on a card used to suggest paths measured from the scene's root, which the card would then look up from the
# wrong place. The suggestions are measured from the player the row names, and stay the scene's own only when that
# player cannot be found.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const FINDER: String = "res://addons/eventsheet/editor/dock/juice_card_field_names.gd"
const TEST_NAME: String = "juice_card_node_paths"


static func run() -> bool:
	var finder: GDScript = load(FINDER) as GDScript
	var main: Node = Node.new()
	main.name = "Main"
	var hero: Node2D = Node2D.new()
	hero.name = "Hero"
	main.add_child(hero)
	hero.owner = main
	var player: Node = Node.new()
	player.name = "HitJuice"
	hero.add_child(player)
	player.owner = main
	var lamp: Node2D = Node2D.new()
	lamp.name = "Lamp"
	main.add_child(lamp)
	lamp.owner = main
	var bulb: Node2D = Node2D.new()
	bulb.name = "Bulb"
	lamp.add_child(bulb)
	bulb.owner = main
	var from_player: PackedStringArray = finder.call("paths_for_player", main, hero, "$HitJuice")
	var unknown: PackedStringArray = finder.call("paths_for_player", main, hero, "$Nobody")
	var found_node: Node = finder.call("player_node", main, hero, "$HitJuice")
	var found: String = str(found_node.name) if found_node != null else ""
	var quoted_node: Node = finder.call("player_node", main, hero, "$\"HitJuice\"")
	var quoted: String = str(quoted_node.name) if quoted_node != null else ""
	var from_nothing: PackedStringArray = finder.call("paths_for_player", null, null, "$HitJuice")
	var resolved: String = str(player.get_node_or_null(NodePath("../../Lamp/Bulb")).name) if player.get_node_or_null(NodePath("../../Lamp/Bulb")) != null else ""
	main.free()
	return SUPPORT.pins(TEST_NAME, [
		["the player the row names is found from the node the sheet runs on", found, "HitJuice"],
		["a quoted name is found the same", quoted, "HitJuice"],
		["a node beside the player's parent is reached by going up", from_player.has("../../Lamp"), true],
		["a node below it is reached by going up and down", from_player.has("../../Lamp/Bulb"), true],
		["the player's own parent is one step up", from_player.has(".."), true],
		["the paths are not the scene root's own", from_player.has("Lamp"), false],
		["a player that cannot be found leaves the scene's own paths", unknown.has("Lamp"), true],
		["no scene, no suggestions", from_nothing.size(), 0],
		["a stored path looked up from the player finds the node", resolved, "Bulb"],
	])
