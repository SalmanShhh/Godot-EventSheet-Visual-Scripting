# Godot EventSheets - the Sound card, the family a card belongs to, and what a new card starts with.
#
# THE ONE THING THIS FILE IS ABOUT: a card added in the Inspector must do something the moment it
# is played, and must belong to the same family in the Inspector and in the game. A new Hitstop card
# used to freeze nothing (its amount is the time scale it freezes to, and it started at 1), a family
# switch that muted the waits shortened the whole beat, and there was no card for a sound.
#
# The pack is reached by path, the new file first: the code lives in `juice_player.gd` and the old
# `feedback_player.gd` only extends it, so a pin written against either file asks the same code.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const SCHEMA_PATH: String = "res://addons/eventsheet/editor/inspector/feedback_card_schema.gd"
const NEW_PACK: String = "res://eventsheet_addons/juice/juice_player.gd"
const OLD_PACK: String = "res://eventsheet_addons/juice/feedback_player.gd"

const TEST_NAME: String = "juice_sound_card"

## The two grounds a family tile sits on: the card line (a LineEdit's normal box) in Godot's own
## dark and light editor themes, read from the 4.7 default presets.
const DARK_CARD_LINE: Color = Color("#1c1c1c")
const LIGHT_CARD_LINE: Color = Color("#f5f5f5")


static func run() -> bool:
	var ok: bool = true
	ok = _storage_pins() and ok
	ok = _family_pins() and ok
	return ok


static func _pack() -> Script:
	return load(NEW_PACK if ResourceLoader.exists(NEW_PACK) else OLD_PACK) as Script


static func _schema() -> Dictionary:
	return load(SCHEMA_PATH).call("schema")


static func _kind(word: String) -> Dictionary:
	return EventSheetCardSchemas.kind_entry(_schema(), word)


static func _new_card(word: String) -> Dictionary:
	return EventSheetCardSchemas.new_card({"kind_key": "verb", "stripe_key": "category"}, _kind(word))


static func _constant(constant_name: String) -> Variant:
	var script: Script = _pack()
	while script != null:
		var map: Dictionary = script.get_script_constant_map()
		if map.has(constant_name):
			return map[constant_name]
		script = script.get_base_script()
	return null


## How the list is saved never moves: the type, the hint, and what an old card reads back as.
static func _storage_pins() -> bool:
	var player: Node = _pack().new()
	var hint: String = ""
	var typed: int = -1
	for property: Dictionary in player.get_property_list():
		if str(property.get("name")) == "steps":
			hint = str(property.get("hint_string"))
			typed = int(property.get("type"))
	player.free()
	return SUPPORT.pins(TEST_NAME, [
		["the list is still a typed array of dictionaries", typed, TYPE_ARRAY],
		["the list keeps its marker, word for word", hint, "eventsheet:cards:kind=verb,schema=feedback_steps,stripes=category"]
	])


## One family per word, the same in the Inspector and in the game, and a muted family never takes a
## wait out of the beat.
static func _family_pins() -> bool:
	var families: Variant = _constant("CATEGORY_OF")
	var table: Dictionary = families if families is Dictionary else {}
	var player: Node = _pack().new()
	player.call("mute_feedback_category", "pause", true)
	var pause_refused: String = str(player.call("_why_not", {"verb": "pause", "seconds": 0.2}, 1.0, 0))
	var hold_refused: String = str(player.call("_why_not", {"verb": "hold_until", "seconds": 0.0}, 1.0, 1))
	var hitstop_refused: String = str(player.call("_why_not", {"verb": "hitstop", "amount": 0.0, "seconds": 0.08}, 1.0, 2))
	player.free()
	return SUPPORT.pins(TEST_NAME, [
		["a muted pause family still waits on a Pause card", pause_refused, ""],
		["and on a Hold card", hold_refused, ""],
		["while the hitstop it holds is still muted", hitstop_refused, "muted"],
		["Tween Property is an Object-family card in the game", str(table.get("tween_property", "")), "transform"],
		["and in the Inspector", str(_kind("tween_property").get("category", "")), "transform"],
		["the card that plays another player is a Flow-family card in the Inspector too",
			str(_kind("play_player").get("category", "")), str(table.get("play_player", "?"))]

	])
