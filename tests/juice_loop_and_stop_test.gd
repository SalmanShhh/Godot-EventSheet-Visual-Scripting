# Godot EventSheets - a Juice Player that loops its whole list, stops everything it started, and
# puts back exactly what it found.
#
# THE ONE THING THIS FILE IS ABOUT: when a list ends early (Stop Juice, Restore Initial Values, the
# node leaving the scene, or every player stopped at once), nothing a card started is left running
# and nothing a card moved is left at a value in the middle. Restore writes the FIRST value each
# property had, Stop ends the effects the cards set going even after the list itself has been walked,
# and a list can loop on the node without ever locking a frame.
#
# WHY SO LITTLE IS PLAYED HERE. The suite runs before any scene tree exists, so a tween, a timer and
# a frame never happen in it. A list of instant cards walks without waiting, which is what the first
# pins use; everything about frames (a loop waits one frame a pass, a pooled player stops changing
# the time scale, a shake ends at the camera's rest) was measured on a running tree, frame by frame.
#
# The pack is reached by path, the new file first: the code lives in `juice_player.gd` once the
# rename has landed and `feedback_player.gd` only extends it, so a pin written against either file
# asks the same code. Method names, keys and the card word below are proposals until they ship.
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")

const TEST_NAME: String = "juice_loop_and_stop"

const NEW_PACK: String = "res://eventsheet_addons/juice/juice_player.gd"
const OLD_PACK: String = "res://eventsheet_addons/juice/feedback_player.gd"
const SCHEMA: String = "res://addons/eventsheet/editor/inspector/feedback_card_schema.gd"

## Where the saved-scene pin writes its scene. Removed again at the end.
const SCENE_PATH: String = "user://juice_loop_and_stop_test.tscn"


static func run() -> bool:
	var ok: bool = true
	ok = _restore_pins() and ok
	ok = _stop_pins() and ok
	ok = _switch_pins() and ok
	ok = _row_pins() and ok
	ok = _loop_pins() and ok
	ok = _card_pins() and ok
	return ok


static func _pack_path() -> String:
	return NEW_PACK if ResourceLoader.exists(NEW_PACK) else OLD_PACK


## A player that has never been in a tree, aimed at a host by hand (the tree is what sets it).
static func _player(host: Node, cards: Array) -> Node:
	var player: Node = (load(_pack_path()) as GDScript).new()
	var typed: Array[Dictionary] = []
	for card: Variant in cards:
		typed.append(card as Dictionary)
	player.set("steps", typed)
	player.set("host", host)
	host.add_child(player)
	return player


## A stand-in for the Juice node: it answers the one call a player makes, and writes down the calls
## a stop and a restore make, so the pins can see what a player asked for.
static func _stand_in() -> Node:
	var source: GDScript = GDScript.new()
	source.source_code = "extends Node\nvar heard: PackedStringArray = PackedStringArray()\n" \
		+ "func moment_step(verb: String, _a: float, _e: String, _s: float, _t: float) -> void:\n\theard.append(\"step \" + verb)\n" \
		+ "func juice_player_began(_key: String, _steps: Array) -> void:\n\theard.append(\"began\")\n" \
		+ "func juice_player_ended(_key: String, put_back: bool) -> void:\n\theard.append(\"put back\" if put_back else \"ended\")\n"
	source.reload()
	var juice: Node = Node.new()
	juice.set_script(source)
	return juice


## Two cards moved the same property; Restore must write what the property was BEFORE the first one.
## Measured today: rotation 0, card one to 1.0, card two to 2.0, Restore gave 1.0.
static func _restore_pins() -> bool:
	var host: Node2D = Node2D.new()
	var player: Node = _player(host, [
		{"verb": "tween_property", "effect": "rotation", "amount": 1.0, "seconds": 0.0},
		{"verb": "tween_property", "effect": "rotation", "amount": 2.0, "seconds": 0.0}])
	player.call("play", 1.0)
	var moved: float = host.rotation
	player.call("restore")
	var restored: float = host.rotation
	host.rotation = 0.0
	player.call("play", 1.0)
	player.call("revert")
	var reverted: float = host.rotation
	host.free()
	return SUPPORT.pins(TEST_NAME, [
		["two instant cards moved the rotation to the second card's value", moved, 2.0],
		["Restore puts back the value from before the first card", restored, 0.0],
		["Revert lands on the same value", reverted, 0.0],
	])


## A list of instant cards is walked the moment it is played, so the effects it started outlive the
## walk. Stop and Restore must still reach them through the Juice node beside the player.
static func _stop_pins() -> bool:
	var host: Node2D = Node2D.new()
	var juice: Node = _stand_in()
	host.add_child(juice)
	var player: Node = _player(host, [{"verb": "shake", "amount": 0.6, "effect": "", "seconds": 0.0}])
	player.call("play", 1.0)
	var walked: bool = bool(player.get("playing"))
	player.call("stop")
	var after_stop: PackedStringArray = (juice.get("heard") as PackedStringArray).duplicate()
	player.call("restore")
	var after_restore: PackedStringArray = juice.get("heard") as PackedStringArray
	var script: GDScript = load(_pack_path())
	host.free()
	return SUPPORT.pins(TEST_NAME, [
		["a list of one Shake card is walked before Play returns", walked, false],
		["the Juice node was told the play began", after_stop.has("began"), true],
		["Stop ends what the cards started, though the walk was already over", after_stop.has("ended"), true],
		["Restore asks the Juice node to put its values back too", after_restore.has("put back"), true],
		["the player stops its play when it leaves the scene", _has(script, "_exit_tree"), true],
	])


## The one switch for the whole game: while it is off, a Play does nothing.
static func _switch_pins() -> bool:
	var host: Node2D = Node2D.new()
	var player: Node = _player(host, [{"verb": "tween_property", "effect": "rotation", "amount": 1.0, "seconds": 0.0}])
	var has_switch: bool = player.has_method("set_all_juice_players_enabled")
	var moved_while_off: float = -1.0
	if has_switch:
		player.call("set_all_juice_players_enabled", false)
		player.call("play", 1.0)
		moved_while_off = host.rotation
		player.call("set_all_juice_players_enabled", true)
		player.call("play", 1.0)
	var moved_when_on: float = host.rotation
	host.free()
	return SUPPORT.pins(TEST_NAME, [
		["the pack has the whole-game switch", has_switch, true],
		["while it is off a Play moves nothing", moved_while_off, 0.0],
		["switched back on, a Play plays", moved_when_on, 1.0],
	])


## The new rows are real typed methods; every player joins one group of the pack's own.
static func _row_pins() -> bool:
	var script: GDScript = load(_pack_path())
	var constants: Dictionary = script.get_script_constant_map()
	return SUPPORT.pins(TEST_NAME, [
		["Stop All Juice Players, with or without restoring", _signature(script, "stop_all_juice_players"), "and_restore: bool"],
		["Set All Juice Players Enabled", _signature(script, "set_all_juice_players_enabled"), "enabled: bool"],
		["Toggle Juice Paused", _signature(script, "toggle_juice_paused"), ""],
		["Set Looping", _signature(script, "set_looping"), "on: bool"],
		["the group every player joins is named once, and is not the default channel", str(constants.get("PLAYERS_GROUP", "")), "every_juice_player"],
		["what the group is told is a name of the pack's own, never the bare word stop", _has(script, "stop_juice_from_group"), true],
	])


## Loop on the node: three exports, each described, none written into a scene that leaves them alone.
static func _loop_pins() -> bool:
	var script: GDScript = load(_pack_path())
	var found: Dictionary = {}
	for entry: Dictionary in script.get_script_property_list():
		found[str(entry.get("name", ""))] = type_string(int(entry.get("type", 0)))
	var text: String = FileAccess.get_file_as_string(_pack_path())
	var host: Node2D = Node2D.new()
	host.name = "Host"
	var player: Node = (load(_pack_path()) as GDScript).new()
	player.name = "JuicePlayer"
	host.add_child(player)
	player.owner = host
	var packed: PackedScene = PackedScene.new()
	packed.pack(host)
	ResourceSaver.save(packed, SCENE_PATH)
	var saved: String = FileAccess.get_file_as_string(SCENE_PATH)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SCENE_PATH))
	host.free()
	return SUPPORT.pins(TEST_NAME, [
		["Loop is a bool on the node", str(found.get("loop", "")), "bool"],
		["Times is an int (0 plays until stopped)", str(found.get("loop_times", "")), "int"],
		["Wait between is a float of seconds", str(found.get("loop_wait", "")), "float"],
		["each of the three carries a description", _described(text, "var loop: bool") and _described(text, "var loop_times: int") and _described(text, "var loop_wait: float"), true],
		["a player left at its defaults saves no loop key", saved.contains("loop"), false],
	])


## The card that pauses or resumes a player: its own word, never the Wait card's `pause`.
static func _card_pins() -> bool:
	var card: Dictionary = _kind("pause_player")
	var keys: PackedStringArray = PackedStringArray()
	for field: Variant in card.get("fields", []):
		keys.append(str((field as Dictionary).get("key", "")))
	var families: Variant = (load(_pack_path()) as GDScript).get_script_constant_map().get("CATEGORY_OF")
	return SUPPORT.pins(TEST_NAME, [
		["the card is in the Add box", str(card.get("label", "")), "Pause Or Resume A Juice Player"],
		["it names a player and what to do", ",".join(keys), "player,mode"],
		["a new card resumes nothing and pauses its target", str((card.get("defaults", {}) as Dictionary).get("mode", "")), "pause"],
		["it is a Flow card in the game too", str((families as Dictionary).get("pause_player", "")) if families is Dictionary else "", "signal"],
	])


static func _kind(word: String) -> Dictionary:
	var schema: Dictionary = (load(SCHEMA) as GDScript).call("schema")
	for kind: Variant in schema.get("kinds", []):
		if str((kind as Dictionary).get("kind", "")) == word:
			return kind as Dictionary
	return {}


static func _signature(script: GDScript, method: String) -> String:
	for info: Dictionary in script.get_script_method_list():
		if str(info.get("name", "")) != method:
			continue
		var parts: PackedStringArray = PackedStringArray()
		for argument: Dictionary in info.get("args", []):
			parts.append("%s: %s" % [argument.get("name", ""), type_string(int(argument.get("type", 0)))])
		return ", ".join(parts)
	return "(missing)"


static func _described(text: String, declaration: String) -> bool:
	var lines: PackedStringArray = text.split("\n")
	for index: int in range(1, lines.size()):
		if lines[index].contains(declaration):
			var above: String = lines[index - 1].strip_edges()
			return above.begins_with("##") and not above.begins_with("## @")
	return false


## Whether a script declares a function (a GDScript resource's own has_method asks about the resource).
static func _has(script: GDScript, method: String) -> bool:
	for info: Dictionary in script.get_script_method_list():
		if str(info.get("name", "")) == method:
			return true
	return false
