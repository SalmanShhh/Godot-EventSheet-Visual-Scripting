# Godot EventSheets - when a card goes wrong, the message says which player, which card and why.
#
# THE ONE THING THIS FILE IS ABOUT: a warning from a running Juice Player names the player, the card's label
# and the reason, so a reader can find the card without guessing; the Doctor finds a card that points at a
# node or a file that is not there, read from the scene's saved bytes without instancing it; and the two
# doors between a player's rows and its cards (the row's menu entry and the strip's button) read the names
# the same way.
#
# Warnings are caught with an engine Logger added for the length of one play and taken away again.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const NEW_PACK: String = "res://eventsheet_addons/juice/juice_player.gd"
const OLD_PACK: String = "res://eventsheet_addons/juice/feedback_player.gd"
const TARGETS_PATH: String = "res://addons/eventsheet/editor/interaction/juice_card_targets.gd"
const ROW_MENU_PATH: String = "res://addons/eventsheet/editor/dock/juice_row_menu.gd"
const BASE_PATH: String = "res://eventsheet_addons/juice/juice_card.gd"

const TEST_NAME: String = "juice_card_findings"


## An engine logger that keeps what the project says through push_warning, for the length of one play.
class Heard extends Logger:

	var lines: PackedStringArray = PackedStringArray()

	func _log_error(_function: String, _file: String, _line: int, code: String, rationale: String, _editor_notify: bool, _error_type: int, _script_backtrace: Array[ScriptBacktrace]) -> void:
		lines.append(rationale if not rationale.is_empty() else code)

	func _log_message(_message: String, _error: bool) -> void:
		pass


static func run() -> bool:
	var ok: bool = true
	ok = _message_pins() and ok
	ok = _scene_pins() and ok
	ok = _doctor_pins() and ok
	ok = _door_pins() and ok
	return ok


static func _pack() -> Script:
	return load(NEW_PACK if ResourceLoader.exists(NEW_PACK) else OLD_PACK) as Script


static func _typed(list: Array) -> Array[Dictionary]:
	var typed: Array[Dictionary] = []
	for entry: Variant in list:
		typed.append(entry as Dictionary)
	return typed


## What a player says while it plays one card, caught: the words and nothing else.
static func _said_by(player: Node, door: Callable) -> String:
	var heard: Heard = Heard.new()
	OS.add_logger(heard)
	door.call()
	OS.remove_logger(heard)
	return " | ".join(heard.lines)


static func _message_pins() -> bool:
	var host: Node2D = Node2D.new()
	host.name = "Crate"
	var player: Node = _pack().new()
	player.name = "HitJuice"
	host.add_child(player)
	player.set("host", host)
	player.set("steps", _typed([
		{"verb": "tween_property", "effect": "wobble", "amount": 1.0, "seconds": 0.0, "label": "Spin"},
		{"verb": "fade_bus", "effect": "NoSuchBus", "amount": -6.0, "seconds": 0.0, "label": "Duck"},
		{"verb": "sound", "stream": "res://no_such_sound.wav", "label": "Boom"},
		{"verb": "particles", "label": "Burst"}
	]))
	var said: String = _said_by(player, func() -> void: player.call("play", 1.0))
	var field_said: String = _said_by(player, func() -> void: player.call("set_feedback_field", "Spin", "no_such_field", 1))
	var copy_said: String = _said_by(player, func() -> void: player.call("copy_feedbacks_from", host))
	host.free()
	return SUPPORT.pins(TEST_NAME, [
		["a warning was said for each card that could not do its work", said.count("did nothing") + said.count("stayed silent"), 4],
		["a property the object has not names the player", said.contains("HitJuice"), true],
		["and the card by its label", said.contains("\"Spin\""), true],
		["and says why", said.contains("wobble"), true],
		["a bus the project does not have names the card and the bus", said.contains("\"Duck\"") and said.contains("NoSuchBus"), true],
		["a sound that is not there names the card", said.contains("\"Boom\""), true],
		["a card that points at no node names the card", said.contains("\"Burst\""), true],
		["a row that writes a field no card holds names the player and the card", field_said.contains("HitJuice") and field_said.contains("\"Spin\"") and field_said.contains("no_such_field"), true],
		["a row that copies from a node that is not a player names this player", copy_said.contains("HitJuice"), true]
	])


## A scene written to a file the test owns: a Crate with a Sparks node, a player holding five cards, and a
## second scene instanced inside it.
static func _scene_path() -> String:
	var root: Node2D = Node2D.new()
	root.name = "Crate"
	var sparks: Node2D = Node2D.new()
	sparks.name = "Sparks"
	root.add_child(sparks)
	sparks.owner = root
	var holder: Node2D = Node2D.new()
	holder.name = "Holder"
	root.add_child(holder)
	holder.owner = root
	var player: Node = _pack().new()
	player.name = "HitJuice"
	root.add_child(player)
	player.owner = root
	player.set("steps", _typed([
		{"verb": "particles", "node": NodePath("../Sparks"), "label": "Here"},
		{"verb": "particles", "node": NodePath("../Gone"), "label": "Lost"},
		{"verb": "sound", "stream": "uid://bnotafileatall", "label": "Silent"},
		{"verb": "Custom", "card_script": "res://no_such_card.gd", "label": "Yours"},
		{"verb": "particles", "node": NodePath("../Holder/Inside"), "label": "Deep"}
	]))
	var packed: PackedScene = PackedScene.new()
	packed.pack(root)
	root.free()
	var path: String = SUPPORT.own_path("juice_card_findings_scene.tscn")
	ResourceSaver.save(packed, path)
	return path


## The reader finds the lost node, the node under a holder that is not there, the missing sound and the missing
## script, and nothing else: a card whose node is there is fine.
static func _scene_pins() -> bool:
	var path: String = _scene_path()
	var found: Array = Array(load(TARGETS_PATH).call("missing_targets_in_scene", path))
	var labels: PackedStringArray = PackedStringArray()
	var kinds: PackedStringArray = PackedStringArray()
	var first: String = ""
	for entry: Variant in found:
		labels.append(str((entry as Dictionary).get("subject", "")))
		kinds.append(str((entry as Dictionary).get("kind", "")))
		if first.is_empty():
			first = str((entry as Dictionary).get("message", ""))
	var sentences: int = first.count(". ") + 1
	return SUPPORT.pins(TEST_NAME, [
		["the lost node, the missing file and the missing script are found, the card that is fine is not", labels, PackedStringArray(["Lost", "Silent", "Yours", "Deep"])],
		["each says whether it was a node or a file", kinds, PackedStringArray(["node", "file", "file", "node"])],
		["a finding names the card, the player and what it points at", first.contains("\"Lost\"") and first.contains("HitJuice") and first.contains("../Gone"), true],
		["in two short sentences at most", sentences <= 2, true],
		["the players a scene holds are read the same way", Array(load(TARGETS_PATH).call("players_in_scene", path)), ["HitJuice"]],
		["a scene with no such card is clean", Array(load(TARGETS_PATH).call("missing_targets_in_scene", "res://no_such_scene.tscn")), []]
	])


## The Doctor files each as a warning under its own check, with the file in front of the sentence, and a project
## that holds no card pays nothing.
static func _doctor_pins() -> bool:
	var path: String = _scene_path()
	var doctor: Script = load("res://addons/eventforge/feedback_doctor.gd") as Script
	var findings: Array = Array(doctor.call("card_findings", PackedStringArray([path])))
	var first: Dictionary = findings[0] as Dictionary if not findings.is_empty() else {}
	var none: Array = Array(doctor.call("card_findings", PackedStringArray()))
	return SUPPORT.pins(TEST_NAME, [
		["every card that points at nothing is one finding", findings.size(), 4],
		["filed as a warning under its own check", [first.get("severity"), first.get("check")], ["warning", "juice-card-target-missing"]],
		["with the scene's file in front of the sentence", str(first.get("message", "")).begins_with("juice_card_findings_scene.tscn: "), true],
		["a project with no cards has nothing to say", none, []]
	])


## The two doors: the row's menu entry names the node the row plays, and the strip's button finds the sheets.
static func _door_pins() -> bool:
	var menu: Script = load(ROW_MENU_PATH) as Script
	var plays: ACEAction = ACEAction.new()
	plays.provider_id = "JuicePlayer"
	plays.ace_id = "play"
	plays.codegen_template = "$HitJuice.play({at_strength})"
	var waits: ACEAction = ACEAction.new()
	waits.provider_id = "JuicePlayer"
	waits.ace_id = "play_and_wait"
	waits.codegen_template = "await $HitJuice.play_and_wait({at_strength})"
	var other_provider: ACEAction = ACEAction.new()
	other_provider.provider_id = "Core"
	other_provider.ace_id = "play"
	other_provider.codegen_template = "$HitJuice.play()"
	var stops: ACEAction = ACEAction.new()
	stops.provider_id = "JuicePlayer"
	stops.ace_id = "stop"
	stops.codegen_template = "$HitJuice.stop()"
	var sheet_path: String = SUPPORT.own_path("juice_card_findings_plays.gd")
	var file: FileAccess = FileAccess.open(sheet_path, FileAccess.WRITE)
	file.store_string("extends Node\n\n\nfunc _on_hit() -> void:\n\t$HitJuice.play(1.0)\n")
	file.close()
	var other_path: String = SUPPORT.own_path("juice_card_findings_quiet.gd")
	file = FileAccess.open(other_path, FileAccess.WRITE)
	file.store_string("extends Node\n\n\nfunc _on_hit() -> void:\n\t$OtherJuice.play(1.0)\n")
	file.close()
	var by_hand: ACEAction = ACEAction.new()
	by_hand.provider_id = "Core"
	by_hand.ace_id = "AudioPlay"
	by_hand.params = {"from": "1.0", "target": "$HitJuice"}
	var by_hand_waiting: ACEAction = ACEAction.new()
	by_hand_waiting.provider_id = "Core"
	by_hand_waiting.ace_id = "AwaitSignal"
	by_hand_waiting.params = {"signal_expression": "$HitJuice.play_and_wait(0.5)"}
	var music: ACEAction = ACEAction.new()
	music.provider_id = "Core"
	music.ace_id = "AudioPlay"
	music.params = {"from": "0.0", "target": "$Music"}
	var players: PackedStringArray = PackedStringArray(["HitJuice"])
	return SUPPORT.pins(TEST_NAME, [
		["a line written by hand reopens as a plainer row, and counts when the scene holds a player of that name",
			[menu.call("player_name_of", by_hand, players), menu.call("player_name_of", by_hand_waiting, players), menu.call("player_name_of", by_hand, PackedStringArray())], ["HitJuice", "HitJuice", ""]],
		["a row that plays something that is not a Juice Player offers nothing", menu.call("player_name_of", music, players), ""],
		["the lines of a block of code name the players it plays, once each, and not the music",
			menu.call("names_in_code", "func _ready() -> void:
	$HitJuice.play(1.0)
	await $HitJuice.play_and_wait(0.5)
	$Music.stop()
	$Other.play_backwards(1.0)
"), PackedStringArray(["HitJuice", "Other"])],
		["a Play Juice row names the player it plays", menu.call("player_name_of", plays), "HitJuice"],
		["and so does Play Juice And Wait, whose call waits", menu.call("player_name_of", waits), "HitJuice"],
		["a row of another pack, or another verb of the player, offers nothing", [menu.call("player_name_of", other_provider), menu.call("player_name_of", stops), menu.call("player_name_of", null)], ["", "", ""]],
		["the sheets that play a player are the ones that call it", menu.call("sheets_in", PackedStringArray([sheet_path, other_path]), "HitJuice"), PackedStringArray([sheet_path])],
		["and a player nobody plays has none", menu.call("sheets_in", PackedStringArray([sheet_path, other_path]), "NobodysJuice"), PackedStringArray()]
	])
