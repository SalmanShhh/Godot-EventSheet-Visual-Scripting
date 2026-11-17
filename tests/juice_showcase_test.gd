# Godot EventSheets - the Juice showcase plays its beats from Juice Players.
#
# THE ONE THING THIS FILE IS ABOUT: the Carousel of Juice shows a newcomer every family of juice card
# working, from a list in the Inspector, played by one row. The scene is read as saved (no instancing,
# the suite has no scene tree): a Juice Player sits under the root, under the hero, under one tile (looping)
# and beside a Juice 3D node in a small 3D view; their lists hold at least one card of each family, the
# start key plays the list instead of a moment, and the calm key stops every player, puts back what they
# moved, and still plays a moment file so the showcase keeps showing one.
#
# The showcase is written by `tools/build_examples.gd` and nothing else; this file reads its output. A play
# of the scene was measured on a running tree: every player finished, the time scale, the camera, the hero's
# angle and the light were all back at rest.
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")

const TEST_NAME: String = "juice_showcase"

const SCENE: String = "res://demo/showcase/carousel/showcase_carousel.tscn"
const SHEET: String = "res://demo/showcase/carousel/showcase_carousel.gd"
const PACK: String = "res://eventsheet_addons/juice/juice_player.gd"
const OLD_PACK: String = "res://eventsheet_addons/juice/feedback_player.gd"
const JUICE_3D: String = "res://eventsheet_addons/juice_3d/juice_3d_behavior.gd"

## The families a newcomer should see at least once, by their saved words.
const FAMILIES: PackedStringArray = ["camera", "transform", "screen", "pause", "scene", "audio", "signal"]


static func run() -> bool:
	var ok: bool = true
	ok = _scene_pins() and ok
	ok = _sheet_pins() and ok
	return ok


## Every node in the saved scene that wears a script, by path: its script, and the keys it holds.
static func _scripted() -> Dictionary:
	var found: Dictionary = {}
	var state: SceneState = (load(SCENE) as PackedScene).get_state()
	for index: int in state.get_node_count():
		var held: Dictionary = {}
		for property: int in state.get_node_property_count(index):
			held[str(state.get_node_property_name(index, property))] = state.get_node_property_value(index, property)
		if held.has("script") and held["script"] is Script:
			held["script_path"] = (held["script"] as Script).resource_path
			found[str(state.get_node_path(index))] = held
	return found


static func _scene_pins() -> bool:
	var nodes: Dictionary = _scripted()
	var families: Variant = (load(PACK) as GDScript).get_script_constant_map().get("CATEGORY_OF")
	var table: Dictionary = families if families is Dictionary else {}
	var seen: Dictionary = {}
	var untyped: int = 0
	var players: int = 0
	for path: Variant in nodes.keys():
		var held: Dictionary = nodes[path]
		if str(held["script_path"]) != PACK and str(held["script_path"]) != OLD_PACK:
			continue
		players += 1
		var cards: Array = held.get("steps", [])
		if not cards.is_typed():
			untyped += 1
		for card: Variant in cards:
			var word: String = str((card as Dictionary).get("verb", ""))
			seen[str((card as Dictionary).get("category", table.get(word, "")))] = true
	var missing: PackedStringArray = PackedStringArray()
	for family: String in FAMILIES:
		if not seen.has(family):
			missing.append(family)
	var tile: Dictionary = nodes.get("./Tiles/Tile5/JuicePlayer", {})
	var cube: Dictionary = nodes.get("./Corner/View/World3D/Cube/Juice3DBehavior", {})
	var folders: int = DirAccess.get_directories_at("res://demo/showcase/").size()
	return SUPPORT.pins(TEST_NAME, [
		["a Juice Player under the root", nodes.has("./JuicePlayer"), true],
		["one under the hero", nodes.has("./Hero/JuicePlayer"), true],
		["one that slows time for the calm key", nodes.has("./CalmPlayer"), true],
		["one on a tile that loops by itself", [tile.get("loop", false), tile.get("autoplay", false)], [true, true]],
		["one beside a Juice 3D node in a small 3D view", [nodes.has("./Corner/View/World3D/Cube/JuicePlayer"), str(cube.get("script_path", ""))], [true, JUICE_3D]],
		["there are five players", players, 5],
		["every list is saved as the typed list the export holds", untyped, 0],
		["every family is seen at least once", ",".join(missing), ""],
		["the showcase count does not move", folders, 30],
	])


static func _sheet_pins() -> bool:
	var text: String = FileAccess.get_file_as_string(SHEET)
	return SUPPORT.pins(TEST_NAME, [
		["the start key plays the list", text.contains("$JuicePlayer.play(intensity * 0.6)"), true],
		["instead of the impact moment", text.contains("moment(\"impact\""), false],
		["the calm key still plays a moment file", text.contains("moment(\"calm\", 1.0)"), true],
		["the calm key stops every Juice Player and puts back what they moved", text.contains("stop_all_juice_players(true)"), true],
		["a row hears the party's word and counts it", text.contains("party_heard += 1"), true],
	])
