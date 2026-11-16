# Godot EventSheets - the field box of Set Juice Card Field offers the keys the named card really holds.
#
# THE ONE THING THIS FILE IS ABOUT: the eight shipped names are only the keys every card may hold. When the
# scene a sheet runs in is saved, the box reads the player and the card the row names out of its bytes and
# offers THAT card's keys, with the word the Inspector shows beside each; a card of your own offers its
# exports; `verb` and `card_script` are never offered; and when nothing can be found the eight are offered
# and a typed key is still taken. A real scene is written to a file the test owns.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const NEW_PACK: String = "res://eventsheet_addons/juice/juice_player.gd"
const OLD_PACK: String = "res://eventsheet_addons/juice/feedback_player.gd"
const FINDER_PATH: String = "res://addons/eventsheet/editor/dock/juice_card_field_names.gd"
const EXAMPLE_PATH: String = "res://eventsheet_addons/juice/screen_flash_card.gd"

const TEST_NAME: String = "juice_card_field_names"


static func run() -> bool:
	var finder: Script = load(FINDER_PATH) as Script
	var scene_path: String = _scene()
	var sound_words: Array = finder.call("in_scene", scene_path, "$HitJuice", "Boom")
	var sound: Array = _keys(sound_words)
	var own: Array = _keys(finder.call("in_scene", scene_path, "$HitJuice", "Flash"))
	var by_position: Array = _keys(finder.call("in_scene", scene_path, "%HitJuice", "1"))
	var only_player: Array = _keys(finder.call("in_scene", scene_path, "$SomeOtherName", "Boom"))
	var no_card: Array = finder.call("in_scene", scene_path, "$HitJuice", "Nothing")
	var no_scene: Array = finder.call("in_scene", "res://no_such_scene.tscn", "$HitJuice", "Boom")
	var fallback: Array = _keys(finder.call("for_sheet", "", "$HitJuice", "Boom"))
	var volume_word: String = ""
	for entry: Variant in sound_words:
		if str((entry as Dictionary).get("key")) == "volume_db":
			volume_word = str((entry as Dictionary).get("word"))
	return SUPPORT.pins(TEST_NAME, [
		["a Sound card offers the keys it holds, in the order the saved card lists them", sound, ["label", "stream", "volume_db"]],
		["each key carries the word the Inspector shows for it", volume_word.is_empty() or volume_word == "volume_db", false],
		["a card of your own offers its exports", own, ["colour", "label", "seconds"]],
		["a card can be named by its position", by_position, ["label", "stream", "volume_db"]],
		["a row whose player is not in the scene finds the only player there is", only_player, ["label", "stream", "volume_db"]],
		["a card the player does not hold finds nothing", no_card, []],
		["a scene that is not there finds nothing", no_scene, []],
		["and then the eight every card may hold are offered", fallback, ["amount", "effect", "seconds", "delay", "interval", "repeat", "chance", "loops"]],
		["verb and card_script are never offered", [sound.has("verb"), own.has("card_script"), own.has("verb")], [false, false, false]]
	])


static func _keys(entries: Array) -> Array:
	var keys: Array = []
	for entry: Variant in entries:
		keys.append(str((entry as Dictionary).get("key")))
	return keys


## A scene with a player holding a Sound card and a card of your own, written to a file the test owns.
static func _scene() -> String:
	var root: Node2D = Node2D.new()
	root.name = "Crate"
	var player: Node = (load(NEW_PACK if ResourceLoader.exists(NEW_PACK) else OLD_PACK) as Script).new()
	player.name = "HitJuice"
	root.add_child(player)
	player.owner = root
	var address: String = ResourceUID.id_to_text(ResourceLoader.get_resource_uid(EXAMPLE_PATH))
	var steps: Array[Dictionary] = [
		{"verb": "sound", "stream": "uid://bnosuchsound", "volume_db": -3.0, "label": "Boom"},
		{"verb": "ScreenFlashCard", "card_script": address, "colour": Color.WHITE, "seconds": 0.1, "label": "Flash"}
	]
	player.set("steps", steps)
	var packed: PackedScene = PackedScene.new()
	packed.pack(root)
	root.free()
	var path: String = SUPPORT.own_path("juice_card_field_names_scene.tscn")
	ResourceSaver.save(packed, path)
	return path
