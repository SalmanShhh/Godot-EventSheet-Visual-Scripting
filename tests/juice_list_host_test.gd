# Godot EventSheets - a Juice list opened on its own finds the Juice Player that plays it.
#
# A Juice list is a file, so opened by itself it has no object to play on. The editor looks in the scene being
# edited for the Juice Players whose Moment File slot holds this file: one is the host, several are offered as
# a "Play on" choice (remembered for the session, never saved), none leaves one plain line. A node field's path
# is stored relative to the host, so a player that holds the same file but stands somewhere else is named in a
# note under the field. The answers are pure over a tree the test builds; the live-editor half (the picture,
# Play + Restore leaving the scene's bytes alone) is proved in the real editor.
@tool
class_name JuiceListHostTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const PLAYER := preload("res://eventsheet_addons/juice/feedback_player.gd")
const LIST_SCRIPT := preload("res://eventsheet_addons/moment_resource/juice_list.gd")
const HOST := preload("res://addons/eventsheet/editor/inspector/juice_list_host.gd")
const FIELDS := preload("res://addons/eventsheet/editor/inspector/juice_card_fields.gd")
const STRIP := preload("res://addons/eventsheet/editor/inspector/feedback_player_strip.gd")


static func run() -> bool:
	var ok: bool = true
	ok = _players_are_found_in_tree_order() and ok
	ok = _the_host_is_chosen() and ok
	ok = _the_choice_is_remembered_for_the_session_only() and ok
	ok = _a_picked_path_is_relative_to_the_host() and ok
	ok = _another_player_that_cannot_reach_the_node_is_named() and ok
	ok = _the_strip_without_a_host_says_how_to_get_one() and ok
	ok = _nothing_is_stored_in_the_file() and ok
	return ok


static func _scene(list: Resource, shared: int) -> Dictionary:
	var root: Node2D = Node2D.new()
	root.name = "Level"
	var made: Array[Node] = []
	for index: int in range(3):
		var body: Node2D = Node2D.new()
		body.name = "Body%d" % index
		root.add_child(body)
		var player: Node = PLAYER.new()
		player.name = "Juice"
		body.add_child(player)
		if index < shared:
			player.set("moment_file", list)
		made.append(player)
	return {"root": root, "players": made}


static func _a_list() -> Resource:
	var list: Resource = LIST_SCRIPT.new()
	var steps: Array[Dictionary] = [{"verb": "shake", "amount": 0.4, "effect": "", "seconds": 0.0}]
	list.set("steps", steps)
	return list


static func _players_are_found_in_tree_order() -> bool:
	HOST.forget()
	var list: Resource = _a_list()
	var other: Resource = _a_list()
	var none: Dictionary = _scene(list, 0)
	var one: Dictionary = _scene(list, 1)
	var several: Dictionary = _scene(list, 3)
	(several["players"][1] as Node).set("moment_file", other)
	var found_none: Array[Node] = HOST.players_in(none["root"], list)
	var found_one: Array[Node] = HOST.players_in(one["root"], list)
	var found_several: Array[Node] = HOST.players_in(several["root"], list)
	var names: PackedStringArray = PackedStringArray()
	for node: Node in found_several:
		names.append(str(HOST.label_of(several["root"], node)))
	var answer: bool = SUPPORT.pins("juice list host found", [
		["no player holds the file", found_none.size(), 0],
		["one player holds the file", found_one.size(), 1],
		["a player holding another file is not counted", found_several.size(), 2],
		["they come in the order the Scene dock shows them", ", ".join(names), "Body0/Juice, Body2/Juice"],
		["a player with no script is never a candidate", HOST.players_in(Node.new(), list).size(), 0],
	])
	for scene: Dictionary in [none, one, several]:
		(scene["root"] as Node).free()
	return answer


static func _the_host_is_chosen() -> bool:
	HOST.forget()
	var list: Resource = _a_list()
	var one: Dictionary = _scene(list, 1)
	var several: Dictionary = _scene(list, 3)
	var none: Dictionary = _scene(list, 0)
	var picked: Array = several["players"]
	var answer: bool = SUPPORT.pins("juice list host chosen", [
		["one player is the host without being asked", HOST.pick_host(list, HOST.players_in(one["root"], list), [], true, one["root"]), (one["players"] as Array)[0]],
		["several: the first in tree order", HOST.pick_host(list, HOST.players_in(several["root"], list), [], true, several["root"]), picked[0]],
		["none: no host", HOST.pick_host(list, HOST.players_in(none["root"], list), [], true, none["root"]), null],
		["shown inside a selected player's slot, that player is the host", HOST.pick_host(list, HOST.players_in(several["root"], list), [picked[2]], false, several["root"]), picked[2]],
		["opened on its own, a selection does not decide", HOST.pick_host(list, HOST.players_in(several["root"], list), [picked[2]], true, several["root"]), picked[0]],
		["a selected node that does not hold the file does not count", HOST.pick_host(list, HOST.players_in(none["root"], list), [(none["players"] as Array)[0]], false, none["root"]), null],
	])
	for scene: Dictionary in [one, several, none]:
		(scene["root"] as Node).free()
	return answer


static func _the_choice_is_remembered_for_the_session_only() -> bool:
	HOST.forget()
	var list: Resource = _a_list()
	var several: Dictionary = _scene(list, 3)
	var root: Node = several["root"]
	var players: Array = several["players"]
	HOST.remember(list, root, players[1])
	var users: Array[Node] = HOST.players_in(root, list)
	var remembered: Node = HOST.pick_host(list, users, [], true, root)
	var steps_before: Array = list.get("steps").duplicate(true)
	var properties: Array = []
	for property: Dictionary in list.get_property_list():
		if int(property.get("usage", 0)) & PROPERTY_USAGE_STORAGE:
			properties.append(str(property.get("name")))
	HOST.forget()
	var forgotten: Node = HOST.pick_host(list, users, [], true, root)
	var answer: bool = SUPPORT.pins("juice list host remembered", [
		["the chosen player is the host", remembered, players[1]],
		["a new session starts at the first again", forgotten, players[0]],
		["the file is untouched by the choice", list.get("steps"), steps_before],
		["the file still stores only its steps", properties.has("steps") and not properties.has("host") and not properties.has("play_on"), true],
	])
	root.free()
	return answer


static func _a_picked_path_is_relative_to_the_host() -> bool:
	HOST.forget()
	var list: Resource = _a_list()
	var scene: Dictionary = _scene(list, 3)
	var root: Node = scene["root"]
	var players: Array = scene["players"]
	var host: Node = players[1]
	var target: Node2D = Node2D.new()
	target.name = "Sprite"
	(host.get_parent() as Node).add_child(target)
	var stored: NodePath = host.get_path_to(target)
	var answer: bool = SUPPORT.pins("juice list host pick path", [
		["the stored path is written from the host, as the slot writes it", str(stored), "../Sprite"],
		["it is not the path from the scene root", str(stored) != str(root.get_path_to(target)), true],
		["the host finds the node by it", FIELDS.resolve(host, stored), target],
		["from another player's place the same words do not find this node", FIELDS.resolve(players[0], stored) != target, true],
	])
	root.free()
	return answer


static func _another_player_that_cannot_reach_the_node_is_named() -> bool:
	HOST.forget()
	var list: Resource = _a_list()
	var scene: Dictionary = _scene(list, 3)
	var root: Node = scene["root"]
	var players: Array = scene["players"]
	var host: Node = players[1]
	var target: Node2D = Node2D.new()
	target.name = "Sprite"
	(host.get_parent() as Node).add_child(target)
	var stored: NodePath = host.get_path_to(target)
	var users: Array[Node] = HOST.players_in(root, list)
	var both: String = str(HOST.unresolved_note(users, host, root, stored))
	# Give the first player a sprite too: now only the third one lacks it.
	var twin: Node2D = Node2D.new()
	twin.name = "Sprite"
	(players[0] as Node).get_parent().add_child(twin)
	var one_left: String = str(HOST.unresolved_note(users, host, root, stored))
	var third: Node2D = Node2D.new()
	third.name = "Sprite"
	(players[2] as Node).get_parent().add_child(third)
	var all_reach: String = str(HOST.unresolved_note(users, host, root, stored))
	var answer: bool = SUPPORT.pins("juice list host unresolved note", [
		["two players cannot find it: both are named", both, "Body0/Juice, Body2/Juice also play this file and do not find this node from where they stand."],
		["one cannot: only that one is named", one_left, "Body2/Juice also plays this file and does not find this node from where it stands."],
		["every one finds it: no note", all_reach, ""],
		["an empty path never needs a note", str(HOST.unresolved_note(users, host, root, NodePath())), ""],
		["the host itself is never named", str(HOST.unresolved_note([host] as Array, host, root, stored)), ""],
		["the path is only read, never rewritten", str(stored), "../Sprite"],
	])
	root.free()
	return answer


static func _the_strip_without_a_host_says_how_to_get_one() -> bool:
	HOST.forget()
	var list: Resource = _a_list()
	var strip: VBoxContainer = STRIP.new(list)
	var doors: Array = strip.get("_play_doors")
	var note: Label = strip.get("_no_host_note")
	var shown_without: Array = [note.visible, strip.get("_try_rows").visible]
	for door: Variant in doors:
		shown_without.append((door as Button).visible)
	# A player found: the doors come back and the line goes.
	var scene: Dictionary = _scene(list, 1)
	strip.set("_player", (scene["players"] as Array)[0])
	strip.call("_apply_host")
	var shown_with: Array = [note.visible, strip.get("_try_rows").visible]
	for door: Variant in doors:
		shown_with.append((door as Button).visible)
	var own: VBoxContainer = STRIP.new((scene["players"] as Array)[0])
	var own_note: Label = own.get("_no_host_note")
	var answer: bool = SUPPORT.pins("juice list host strip", [
		["the four playing doors are there to be shown", doors.size(), 4],
		["with no player: the line is shown, the doors and the try rows are not", shown_without, [true, false, false, false, false, false]],
		["with a player: the line is gone and the doors are back", shown_with, [false, true, true, true, true, true]],
		["a player's own strip never shows the line", own_note.visible, false],
		["the line says what to do", note.text.contains("Moment File slot"), true],
	])
	strip.free()
	own.free()
	(scene["root"] as Node).free()
	return answer


static func _nothing_is_stored_in_the_file() -> bool:
	HOST.forget()
	var list: Resource = _a_list()
	var path: String = SUPPORT.own_path("juice_list_host.tres")
	var before_error: int = ResourceSaver.save(list, path)
	var before: String = FileAccess.get_file_as_string(path)
	var scene: Dictionary = _scene(list, 3)
	HOST.remember(list, scene["root"], (scene["players"] as Array)[2])
	var users: Array[Node] = HOST.players_in(scene["root"], list)
	HOST.pick_host(list, users, [], true, scene["root"])
	HOST.unresolved_note(users, users[0], scene["root"], NodePath("../Sprite"))
	var save_error: int = ResourceSaver.save(list, path)
	var after: String = FileAccess.get_file_as_string(path)
	(scene["root"] as Node).free()
	return SUPPORT.pins("juice list host stores nothing", [
		["the file saved", before_error, OK],
		["saved again after the host work", save_error, OK],
		["the bytes are the same", after, before],
	])
