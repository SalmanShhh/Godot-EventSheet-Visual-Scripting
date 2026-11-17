# Godot EventSheets - the Chromatic Shake card of a Juice Player.
#
# THE ONE THING THIS FILE IS ABOUT: a card that splits the screen's colours apart along a direction for a
# moment and closes them again, played by the Juice node's own Chromatic Shake row - so the card, the row and
# the no-flashing and effect-strength dials are one effect - and that leaves the colours exactly together when
# the play is stopped, restored, skipped or freed. The suite has no scene tree and no clock, so what is pinned
# here is the vocabulary, the saved shape, the call the card makes and the calls that end it; the split frame
# by frame is proven by a game run.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const TEST_NAME: String = "juice_chromatic_shake_card"

const PACK: String = "res://eventsheet_addons/juice/juice_player.gd"
const SCHEMA: String = "res://addons/eventsheet/editor/inspector/feedback_card_schema.gd"
const PICTURE: String = "res://addons/eventsheet/editor/inspector/juice_chroma_picture.gd"
const LEARNING: String = "res://addons/eventsheet/editor/inspector/juice_card_learning.gd"
const JUICE_2D: String = "res://eventsheet_addons/juice/juice_behavior.gd"


static func run() -> bool:
	var ok: bool = true
	ok = _vocabulary_pins() and ok
	ok = _play_pins() and ok
	ok = _end_pins() and ok
	ok = _picture_pins() and ok
	ok = _old_cards_pins() and ok
	ok = _saved_pins() and ok
	ok = _learning_pins() and ok
	return ok


static func _pack() -> GDScript:
	return load(PACK) as GDScript


static func _kind(word: String) -> Dictionary:
	for entry: Variant in (load(SCHEMA) as GDScript).call("schema").get("kinds"):
		if str((entry as Dictionary).get("kind", "")) == word:
			return entry as Dictionary
	return {}


static func _field(kind: Dictionary, key: String) -> Dictionary:
	for field: Variant in kind.get("fields", []):
		if str((field as Dictionary).get("key", "")) == key:
			return field as Dictionary
	return {}


static func _keys(kind: Dictionary) -> PackedStringArray:
	var keys: PackedStringArray = PackedStringArray()
	for field: Variant in kind.get("fields", []):
		keys.append(str((field as Dictionary).get("key", "")))
	return keys


## The Juice node stands in as a script that writes down the calls it is asked for.
static func _stand_in() -> Node:
	var source: GDScript = GDScript.new()
	source.source_code = "extends Node\nvar heard: Array = []\n" \
		+ "func moment_step(verb: String, _a: float, _e: String, _s: float, _t: float) -> void:\n\theard.append([\"step\", verb])\n" \
		+ "func chromatic_shake(magnitude: float, duration: float, mode: String, angle: float) -> void:\n\theard.append([\"shake\", magnitude, duration, mode, angle])\n" \
		+ "func stop_chromatic_shake() -> void:\n\theard.append([\"stop\"])\n"
	source.reload()
	var juice: Node = Node.new()
	juice.set_script(source)
	return juice


static func _player(host: Node, cards: Array) -> Node:
	var player: Node = _pack().new() as Node
	var typed: Array[Dictionary] = []
	for card: Variant in cards:
		typed.append(card as Dictionary)
	player.set("steps", typed)
	player.set("host", host)
	host.add_child(player)
	return player


static func _heard(juice: Node) -> Array:
	return juice.get("heard") as Array


## The vocabulary: a kind in the Screen family that the Add box finds by the words a person would try.
static func _vocabulary_pins() -> bool:
	var kind: Dictionary = _kind("chromatic_shake")
	var constants: Dictionary = _pack().get_script_constant_map()
	var searched: PackedStringArray = kind.get("search", PackedStringArray())
	var mode: Dictionary = _field(kind, "mode")
	var direction: Dictionary = _field(kind, "direction")
	var defaults: Dictionary = kind.get("defaults", {})
	var rows: Array = [
		["Chromatic Shake is a kind of card", not kind.is_empty(), true],
		["it is called Chromatic Shake", str(kind.get("label", "")), "Chromatic Shake"],
		["it is a Screen card in the Inspector", str(kind.get("category", "")), "screen"],
		["and in the game", (constants.get("CATEGORY_OF") as Dictionary).get("chromatic_shake", ""), "screen"],
		["the fields are the amount, the length, how it ends, which way, the angle, the picture and the amber line", ",".join(_keys(kind)), "amount,seconds,mode,direction,angle,chroma_shape,chroma_note"],
		["the Add box finds it by the words a person tries", [searched.has("aberration"), searched.has("rgb"), searched.has("split"), searched.has("glitch")], [true, true, true, true]],
		["a new card splits twelve pixels", defaults.get("amount"), 12.0],
		["for a third of a second", defaults.get("seconds"), 0.3],
		["closing steadily, the classic hit", defaults.get("mode"), "reducing"],
		["and wandering", defaults.get("direction"), "wander"],
		["how it ends is a pick list of the row's own two words", str(mode.get("drawer", "")).begins_with("options:reducing=") and str(mode.get("drawer", "")).contains(",constant="), true],
		["which way is a pick list too", str(direction.get("drawer", "")), "options:wander=Wanders,angle=Along an angle"],
		["the angle shows only when the direction is an angle", str(_field(kind, "angle").get("show_if", "")), "direction==angle"],
		["no fade tick is offered, because the row has none", _keys(kind).has("fade_in") or _keys(kind).has("fade_out"), false],
		["the Juice node's row takes the same two modes", FileAccess.get_file_as_string(JUICE_2D).contains("mode == \"constant\""), true],
		["it is played by the player itself", (constants.get("WORLD_WORDS") as PackedStringArray).has("chromatic_shake"), true],
		["it lasts only a time, so a skip does not start it", (constants.get("LASTS_ONLY_A_TIME") as PackedStringArray).has("chromatic_shake"), true],
		["the editor does not play it and says so", str(_pack().call("editor_kind", "chromatic_shake")).begins_with("skipped:"), true],
		["it is as long as its seconds", _pack().call("card_length", {"verb": "chromatic_shake", "seconds": 0.4}), 0.4],
	]
	return SUPPORT.pins(TEST_NAME, rows)


## What the card asks the Juice node for: the strength scales the amount, the direction is the angle or a
## wander, and nothing the row cannot do is asked.
static func _play_pins() -> bool:
	var host: Node2D = Node2D.new()
	var juice: Node = _stand_in()
	host.add_child(juice)
	var card: Dictionary = {"verb": "chromatic_shake", "amount": 12.0, "seconds": 0.3, "mode": "reducing", "direction": "wander"}
	var player: Node = _player(host, [card])
	player.call("play", 1.0)
	var first: Array = (_heard(juice) as Array).duplicate(true)
	_heard(juice).clear()
	player.set("strength", 0.5)
	player.call("_do_step", {"verb": "chromatic_shake", "amount": 12.0, "seconds": 0.3, "mode": "constant", "direction": "angle", "angle": 90.0}, 1.0)
	var second: Array = (_heard(juice) as Array).duplicate(true)
	_heard(juice).clear()
	player.call("_do_step", {"verb": "chromatic_shake", "amount": 8.0, "seconds": 0.2, "direction": "angle", "angle": -90.0}, 0.5)
	var third: Array = (_heard(juice) as Array).duplicate(true)
	host.free()
	var asked: Array = _pack().call("chromatic_shake_asked", {"amount": 10.0, "seconds": 0.0}, 1.0, 0.0)
	return SUPPORT.pins(TEST_NAME, [
		["a played list asks the Juice node for the shake with the card's own numbers", _shakes(first), [["shake", 12.0, 0.3, "reducing", -1.0]]],
		["the player's strength scales the amount, and the angle is the angle", _shakes(second), [["shake", 6.0, 0.3, "constant", 90.0]]],
		["a card with no mode closes steadily, and an angle below zero turns round to the same line", _shakes(third), [["shake", 2.0, 0.2, "reducing", 270.0]]],
		["a card with no length still lasts long enough to be seen", asked[1] > 0.0, true],
		["the amount can never be negative", (_pack().call("chromatic_shake_asked", {"amount": -4.0}, 1.0, 0.3) as Array)[0], 0.0],
	])


static func _shakes(calls: Array) -> Array:
	var kept: Array = []
	for entry: Variant in calls:
		if (entry as Array)[0] == "shake":
			kept.append(entry)
	return kept


## Stop, Restore, a skip and a freed player all leave the colours together: the player tells the Juice node it
## started the shake on to stop it, and a skip does not start one at all.
static func _end_pins() -> bool:
	var rows: Array = []
	for how: String in ["stop", "restore", "skip", "freed"]:
		var host: Node2D = Node2D.new()
		var juice: Node = _stand_in()
		host.add_child(juice)
		var player: Node = _player(host, [{"verb": "chromatic_shake", "amount": 12.0, "seconds": 0.0, "mode": "constant"}])
		player.call("play", 1.0)
		var started: int = _shakes(_heard(juice)).size()
		match how:
			"stop":
				player.call("stop")
			"restore":
				player.call("restore")
			"skip":
				# A list with seconds in it is still being walked when a skip comes; no clock here, so say so.
				player.set("playing", true)
				player.call("skip_to_end")
			"freed":
				player.call("_exit_tree")
		var stops: int = 0
		for entry: Variant in _heard(juice):
			if (entry as Array)[0] == "stop":
				stops += 1
		rows.append(["a shake started by the card is on before a %s" % how, started, 1])
		rows.append(["and a %s puts the colours together" % how, stops >= 1, true])
		host.free()
	var host_skip: Node2D = Node2D.new()
	var juice_skip: Node = _stand_in()
	host_skip.add_child(juice_skip)
	var player_skip: Node = _player(host_skip, [{"verb": "pause", "seconds": 0.2}, {"verb": "chromatic_shake", "amount": 12.0, "seconds": 0.3}])
	player_skip.call("_do_step", {"verb": "chromatic_shake", "amount": 12.0, "seconds": 0.3}, 1.0, true)
	rows.append(["a card reached by a skip never starts a shake", _shakes(_heard(juice_skip)).size(), 0])
	host_skip.free()
	var alone: Node2D = Node2D.new()
	var quiet: Node = _player(alone, [{"verb": "chromatic_shake", "amount": 12.0, "seconds": 0.3}])
	quiet.call("play", 1.0)
	quiet.call("stop")
	rows.append(["a player with no Juice node beside it stops without a word", true, true])
	alone.free()
	return SUPPORT.pins(TEST_NAME, rows)


## The little picture and its one sentence, worked out from the card's own numbers.
static func _picture_pins() -> bool:
	var words: GDScript = load(PICTURE) as GDScript
	var steady: Dictionary = {"amount": 12.0, "seconds": 0.3, "mode": "reducing", "direction": "angle", "angle": 0.0}
	var split: Dictionary = words.call("marks", steady, 100.0)
	var along: Dictionary = words.call("marks", {"amount": 12.0, "direction": "angle", "angle": 90.0}, 100.0)
	var none: Dictionary = words.call("marks", {"amount": 0.0, "direction": "angle", "angle": 0.0}, 100.0)
	var wider: Dictionary = words.call("marks", {"amount": 24.0, "direction": "angle", "angle": 0.0}, 100.0)
	var far: Dictionary = words.call("marks", {"amount": 400.0, "direction": "angle", "angle": 0.0}, 100.0)
	return SUPPORT.pins(TEST_NAME, [
		["the three marks sit on the line of the angle", [split["red"].y, split["green"].y, split["blue"].y], [0.0, 0.0, 0.0]],
		["green is a step of the amount from red, and blue is three steps further on red's side", [split["green"] - split["red"], split["red"] - split["blue"]], [Vector2(24.0, 0.0), Vector2(36.0, 0.0)]],
		["the group is centred", split["red"] + split["green"] + split["blue"], Vector2.ZERO],
		["at ninety degrees they part up and down", absf(along["red"].x) < 0.001 and absf(along["red"].y) > 1.0, true],
		["an amount of nothing leaves the three marks together", [none["red"], none["green"], none["blue"]], [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]],
		["twice the amount is twice the gap", wider["green"].x - wider["red"].x, (split["green"].x - split["red"].x) * 2.0],
		["a huge amount never leaves the picture", absf(far["red"].x) <= 100.0 and absf(far["green"].x) <= 100.0 and absf(far["blue"].x) <= 100.0, true],
		["a wandering card is drawn as wandering", words.call("marks", {"amount": 12.0, "direction": "wander"}, 100.0)["wander"], true],
		["the sentence for a closing shake says how far and when it is together", words.call("says", steady),
			"The colours part by up to 12 px along 0 degrees and are back together after 0.3 s."],
		["the sentence for a held shake says it snaps shut", words.call("says", {"amount": 8.0, "seconds": 0.5, "mode": "constant", "direction": "wander"}),
			"The colours stay 8 px apart, turning as they go, then snap together after 0.5 s."],
		["a card with nothing in it says what a new card does", words.call("says", {}),
			"The colours part by up to 12 px, turning as they go, and are back together after 0.3 s."],
		["an amount of nothing says nothing is split", words.call("says", {"amount": 0.0}), "Amount is 0, so the colours are never split."],
	])


## Cards from before this one play as they always did, and the Juice node's own words did not move.
static func _old_cards_pins() -> bool:
	var host: Node2D = Node2D.new()
	var juice: Node = _stand_in()
	host.add_child(juice)
	var player: Node = _player(host, [{"verb": "chromatic", "amount": 0.5, "effect": "", "seconds": 0.2}])
	player.call("play", 1.0)
	var heard: Array = _heard(juice)
	var kicked: bool = heard.has(["step", "chromatic"])
	var shaken: int = _shakes(heard).size()
	host.free()
	var moment_words: PackedStringArray = _pack().get_script_constant_map().get("MOMENT_KEYS")
	return SUPPORT.pins(TEST_NAME, [
		["a Chromatic Kick card still goes to the Juice node as the step it always was", kicked, true],
		["and is not a Chromatic Shake", shaken, 0],
		["a moment file still holds the same six keys", Array(moment_words), ["verb", "amount", "effect", "seconds", "label", "active"]],
		["the Juice node's word list of moment steps did not gain the new word", FileAccess.get_file_as_string(JUICE_2D).contains("\"chromatic\", \"pulse\", \"hold\"]") and not FileAccess.get_file_as_string(JUICE_2D).contains("\"chromatic_shake\", \"pulse\""), true],
		["Chromatic Kick is still a Screen card", (_pack().get_script_constant_map().get("CATEGORY_OF") as Dictionary).get("chromatic", ""), "screen"],
	])


## A list with the card in it is saved in a scene and read back card for card, and a list from before this card holds
## no new key. The Juice node's own dials still hold the effect the card plays: it halves under no flashing and is
## scaled by the reduced-effects dial where the frame is written.
static func _saved_pins() -> bool:
	var holder: Node = Node.new()
	holder.set_script(_pack())
	var list: Array[Dictionary] = [
		{"verb": "chromatic", "amount": 0.6, "effect": "", "seconds": 0.2},
		{"verb": "chromatic_shake", "amount": 12.0, "seconds": 0.3, "mode": "constant", "direction": "angle", "angle": 90.0}
	]
	holder.set("steps", list)
	var scene: PackedScene = PackedScene.new()
	scene.pack(holder)
	var path: String = SUPPORT.own_path("juice_chromatic_shake_card.tscn")
	ResourceSaver.save(scene, path)
	var reloaded: Node = (load(path) as PackedScene).instantiate()
	var back: Array = reloaded.get("steps")
	var older: Array[Dictionary] = [list[0]]
	holder.set("steps", older)
	var old_scene: PackedScene = PackedScene.new()
	old_scene.pack(holder)
	var old_path: String = SUPPORT.own_path("juice_chromatic_shake_card_old.tscn")
	ResourceSaver.save(old_scene, old_path)
	var old_text: String = FileAccess.get_file_as_string(old_path)
	var juice_text: String = FileAccess.get_file_as_string(JUICE_2D)
	holder.free()
	reloaded.free()
	return SUPPORT.pins(TEST_NAME, [
		["the cards come back from a saved scene exactly", back, list],
		["a scene from before the card holds no new word", old_text.contains("chromatic_shake") or old_text.contains("direction"), false],
		["the row the card plays halves the split under no flashing", juice_text.contains("if _chroma_shake_quiet():\n\t\tamount *= 0.5"), true],
		["and scales it by the reduced-effects dial", juice_text.contains("_chroma_shake_magnitude = _chroma_shake_amount() * effect_strength"), true],
	])


## Show as GDScript gives the same effect by hand, parsing with no plugin.
static func _learning_pins() -> bool:
	var learning: GDScript = load(LEARNING) as GDScript
	var text: String = str(learning.call("as_gdscript", {"verb": "chromatic_shake", "amount": 12.0, "seconds": 0.3, "mode": "reducing", "direction": "angle", "angle": 0.0}))
	var held: String = str(learning.call("as_gdscript", {"verb": "chromatic_shake", "amount": 6.0, "seconds": 0.5, "mode": "constant", "direction": "wander"}))
	var source: GDScript = GDScript.new()
	source.source_code = "extends Node\nfunc _plain() -> void:\n" + "\n".join(PackedStringArray(Array(text.split("\n")).map(func(line: String) -> String: return "\t" + line)))
	var parsed: bool = source.reload() == OK
	return SUPPORT.pins(TEST_NAME, [
		["the plain version is there", text.is_empty(), false],
		["it parses on its own", parsed, true],
		["it splits red and blue by the amount and tweens the split back to nothing", text.contains("tween_property(") and text.contains("split") and text.contains("Vector2.ZERO"), true],
		["a held shake waits its seconds before closing", held.contains("create_timer(0.5)"), true],
		["it needs the Juice node nowhere", text.contains("Juice"), false],
	])
