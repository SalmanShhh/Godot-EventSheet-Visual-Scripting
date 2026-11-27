# Godot EventSheets - the Juice list file, and which controller a Vibrate card rumbles.
#
# THE ONE THING THIS FILE IS ABOUT: a list of juice cards that lives in a file and is shared. A Juice list holds
# every kind of card with every key, a Juice Player plays it from its Moment File slot, and an edit to the file
# reaches every player using it because a play only READS the file. Old moment files and old scenes keep
# playing the same, and a Vibrate card keeps rumbling every controller unless it names one.
@tool
class_name JuiceListFileTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const PLAYER := preload("res://eventsheet_addons/juice/feedback_player.gd")
const LIST_SCRIPT := preload("res://eventsheet_addons/moment_resource/juice_list.gd")
const MOMENT_SCRIPT := preload("res://eventsheet_addons/moment_resource/moment_resource.gd")
const SCHEMA := preload("res://addons/eventsheet/editor/inspector/feedback_card_schema.gd")
const STRIP := preload("res://addons/eventsheet/editor/inspector/feedback_player_strip.gd")
const SHIP_IT := preload("res://addons/eventforge/ship_it_doctor.gd")

const TEST_NAME: String = "juice_list_file"


static func run() -> bool:
	var ok: bool = true
	ok = _every_card_round_trips() and ok
	ok = _two_players_share_one_file() and ok
	ok = _old_files_and_scenes_still_play() and ok
	ok = _save_as_file_leaves_nothing_behind() and ok
	ok = _vibrate_picks_its_controller() and ok
	ok = _the_last_controller_is_heard() and ok
	ok = _the_doctor_reads_the_android_preset() and ok
	return ok


## A Vibrate-style stand-in that records which controller each rumble was sent to, so the choice a card makes is a
## list of words rather than something to listen for.
class Rumbler extends PLAYER:

	var sent: Array = []

	func vibrate_controller(controller: int, weak: float = 0.5, strong: float = 0.5, seconds: float = 0.2) -> void:
		sent.append([controller, snappedf(weak, 0.001), snappedf(strong, 0.001), snappedf(seconds, 0.001)])


## One card of every kind the card editor offers, each with its defaults and a few of the keys any card may carry,
## written to a file and read back: nothing is lost, and nothing is left behind.
static func _every_card_round_trips() -> bool:
	var cards: Array[Dictionary] = []
	var kinds: Array = SCHEMA.schema().get("kinds", [])
	for entry: Variant in kinds:
		var kind: Dictionary = entry as Dictionary
		var card: Dictionary = {"verb": str(kind.get("kind", ""))}
		var defaults: Variant = kind.get("defaults", {})
		if defaults is Dictionary:
			for key: Variant in (defaults as Dictionary):
				card[key] = (defaults as Dictionary)[key]
		card["label"] = "card %d" % cards.size()
		card["delay"] = 0.25
		card["chance"] = 80.0
		if cards.size() % 5 == 0:
			card["active"] = false
		cards.append(card)
	var file: Resource = LIST_SCRIPT.new()
	file.set("steps", cards)
	var path: String = SUPPORT.own_path("juice_list_round_trip.tres")
	var saved: int = ResourceSaver.save(file, path)
	var back: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	var read: Array = (back.get("steps") as Array) if back != null else []
	var lost: PackedStringArray = PackedStringArray()
	for index: int in range(cards.size()):
		if index >= read.size() or var_to_str(cards[index]) != var_to_str(read[index]):
			lost.append(str((cards[index] as Dictionary).get("verb", "")))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return SUPPORT.pins(TEST_NAME, [
		["the card editor has kinds to hold", kinds.size() > 20, true],
		["the file saves", saved, OK],
		["every kind of card comes back the same", lost, PackedStringArray()],
		["and as many cards as went in", read.size(), cards.size()],
		["the class is named for what it is", str(back.get_script().get_global_name()) if back != null else "", "JuiceList"]
	])


## Two players with one file: both play its cards, an edit to the file is seen by both, and a play leaves the
## file exactly as it found it (the loops a play counts down are the player's, never the file's).
static func _two_players_share_one_file() -> bool:
	var file: Resource = LIST_SCRIPT.new()
	file.set("steps", [{"verb": "shake", "amount": 0.4, "seconds": 0.0, "loops": 3}] as Array[Dictionary])
	var before: String = var_to_str(file.get("steps"))
	var one: Node = PLAYER.new()
	var two: Node = PLAYER.new()
	one.moment_file = file
	two.moment_file = file
	var seen_first: float = float(((one._steps_now() as Array)[0] as Dictionary).get("amount", 0.0))
	one.play(1.0)
	two.play(1.0)
	var after: String = var_to_str(file.get("steps"))
	var counted: Array = [one._loops_left.size(), two._loops_left.size()]
	var shared_array: bool = is_same(one._steps_now(), two._steps_now()) and is_same(one._steps_now(), file.get("steps"))
	((file.get("steps") as Array)[0] as Dictionary)["amount"] = 0.9
	var seen_one: float = float(((one._steps_now() as Array)[0] as Dictionary).get("amount", 0.0))
	var seen_two: float = float(((two._steps_now() as Array)[0] as Dictionary).get("amount", 0.0))
	# An edit row on one player is that player's own: it takes a copy and leaves the file, and the other player, alone.
	one.scale_feedback_amounts("", 0.5)
	var file_after_row: float = float(((file.get("steps") as Array)[0] as Dictionary).get("amount", 0.0))
	var other_after_row: float = float(((two._steps_now() as Array)[0] as Dictionary).get("amount", 0.0))
	var own_after_row: float = float(((one._steps_now() as Array)[0] as Dictionary).get("amount", 0.0))
	var ok: bool = SUPPORT.pins(TEST_NAME, [
		["a player plays the file's cards", seen_first, 0.4],
		["two plays leave the file as it was", after, before],
		["each play counts its own loops", counted, [1, 1]],
		["both players read the one array", shared_array, true],
		["an edit to the file reaches the first player", seen_one, 0.9],
		["and the second", seen_two, 0.9],
		["a row on one player does not write into the file", file_after_row, 0.9],
		["or into the other player", other_after_row, 0.9],
		["the player that was edited has its own tuned copy", snappedf(own_after_row, 0.001), 0.45]
	])
	one.free()
	two.free()
	return ok


## An old moment file in the slot plays as it always did, an old scene holding one loads and plays, and a moment
## file's steps are valid cards in a list.
static func _old_files_and_scenes_still_play() -> bool:
	var moment: Resource = MOMENT_SCRIPT.new()
	moment.set("moment_name", "hit")
	moment.set("steps", [{"verb": "shake", "amount": 0.4, "effect": "", "seconds": 0.2}] as Array[Dictionary])
	var holder: Node = PLAYER.new()
	holder.name = "JuicePlayer"
	holder.moment_file = moment
	var scene: PackedScene = PackedScene.new()
	var packed: int = scene.pack(holder)
	var path: String = SUPPORT.own_path("old_scene.tscn")
	var written: int = ResourceSaver.save(scene, path)
	var loaded: PackedScene = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	var revived: Node = loaded.instantiate() if loaded != null else null
	var revived_steps: Array = (revived._steps_now() as Array) if revived != null else []
	var revived_word: String = str((revived_steps[0] as Dictionary).get("verb", "")) if not revived_steps.is_empty() else ""
	var carried: Variant = revived.get("moment_file") if revived != null else null
	var as_list: Resource = LIST_SCRIPT.new()
	as_list.set("steps", moment.get("steps"))
	var from_list: Node = PLAYER.new()
	from_list.moment_file = as_list
	var listed: Array = from_list._steps_now() as Array
	var ok: bool = SUPPORT.pins(TEST_NAME, [
		["a scene packs", packed, OK],
		["and saves", written, OK],
		["the old scene's moment file is still in the slot", carried is Resource and (carried as Resource).get_script() == MOMENT_SCRIPT, true],
		["and plays its step", revived_word, "shake"],
		["a Juice list in the same slot plays the same step", str((listed[0] as Dictionary).get("verb", "")), "shake"],
		["load_moment_file takes a list as well as a moment file", _loads_a_list(), true]
	])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	holder.free()
	from_list.free()
	if revived != null:
		revived.free()
	return ok


static func _loads_a_list() -> bool:
	var file: Resource = LIST_SCRIPT.new()
	file.set("steps", [{"verb": "flash", "amount": 1.0, "seconds": 0.1}] as Array[Dictionary])
	var path: String = SUPPORT.own_path("loadable_list.tres")
	ResourceSaver.save(file, path)
	var player: Node = PLAYER.new()
	player.load_moment_file(path)
	var took: bool = player.steps.size() == 1 and str((player.steps[0] as Dictionary).get("verb", "")) == "flash"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	player.free()
	return took


## Save As File writes every card, deep copies of them, in the order they stood.
static func _save_as_file_leaves_nothing_behind() -> bool:
	var player: Node = PLAYER.new()
	player.steps = [
		{"verb": "shake", "amount": 0.4, "seconds": 0.1},
		{"verb": "flash", "amount": 1.0, "seconds": 0.1, "active": false},
		{"verb": "pause", "seconds": 0.2},
		{"verb": "tween_property", "effect": "rotation", "amount": 2.0, "seconds": 0.1, "ease": "sine"},
		{"verb": "emit_signal", "effect": "hit", "seconds": 0.0},
		{"verb": "play_player", "effect": "Inner", "seconds": 0.0}
	] as Array[Dictionary]
	var written: Array[Dictionary] = STRIP.cards_for_file(STRIP.steps_of(player))
	((written[3] as Dictionary))["ease"] = "linear"
	var words: PackedStringArray = PackedStringArray()
	for card: Dictionary in written:
		words.append(str(card.get("verb", "")))
	var ok: bool = SUPPORT.pins(TEST_NAME, [
		["every card is written, the ones a moment file leaves behind too", words,
			PackedStringArray(["shake", "flash", "pause", "tween_property", "emit_signal", "play_player"])],
		["a switched-off card keeps its switch", (written[1] as Dictionary).get("active"), false],
		["a card keeps the keys a moment file drops", str((written[3] as Dictionary).get("effect", "")), "rotation"],
		["the copy is not the player's card", str((player.steps[3] as Dictionary).get("ease", "")), "sine"]
	])
	player.free()
	return ok


## Which controller a card rumbles: every one when it says nothing (so old cards behave as they did), a number, or
## the one last used. Headless has no controller plugged in, so "last used" falls back to every controller.
static func _vibrate_picks_its_controller() -> bool:
	var rumbler: Rumbler = Rumbler.new()
	rumbler._vibrate({"verb": "vibrate", "weak": 0.4, "strong": 0.8, "seconds": 0.3}, 0.5)
	rumbler._vibrate({"verb": "vibrate", "weak": 0.4, "strong": 0.8, "seconds": 0.3, "controller": "all"}, 1.0)
	rumbler._vibrate({"verb": "vibrate", "weak": 1.0, "strong": 1.0, "seconds": 0.1, "controller": "2"}, 1.0)
	rumbler._vibrate({"verb": "vibrate", "weak": 1.0, "strong": 1.0, "seconds": 0.1, "controller": "last"}, 1.0)
	rumbler.vibrate(0.2, 0.3, 0.4)
	rumbler.vibrate_last_used(0.2, 0.3, 0.4)
	var ok: bool = SUPPORT.pins(TEST_NAME, [
		["a card that names no controller rumbles every one, scaled by the play", rumbler.sent[0], [-1, 0.2, 0.4, 0.3]],
		["the word all is the same", rumbler.sent[1], [-1, 0.4, 0.8, 0.3]],
		["a number rumbles that controller", rumbler.sent[2], [2, 1.0, 1.0, 0.1]],
		["the last used, with none heard, falls back to every controller", rumbler.sent[3], [-1, 1.0, 1.0, 0.1]],
		["the old function still rumbles every controller", rumbler.sent[4], [-1, 0.2, 0.3, 0.4]],
		["and the typed one beside it does the same with none heard", rumbler.sent[5], [-1, 0.2, 0.3, 0.4]]
	])
	rumbler.free()
	return ok


## The listener keeps the number of the controller that spoke last, and ignores stick drift.
static func _the_last_controller_is_heard() -> bool:
	var listener: Node = PLAYER.PadListener.new()
	var before: int = PLAYER.last_controller()
	PLAYER._last_pad = -1
	var button: InputEventJoypadButton = InputEventJoypadButton.new()
	button.device = 3
	listener._input(button)
	var heard: int = PLAYER.last_controller()
	var drift: InputEventJoypadMotion = InputEventJoypadMotion.new()
	drift.device = 5
	drift.axis_value = 0.1
	listener._input(drift)
	var after_drift: int = PLAYER.last_controller()
	var push: InputEventJoypadMotion = InputEventJoypadMotion.new()
	push.device = 5
	push.axis_value = 0.9
	listener._input(push)
	var after_push: int = PLAYER.last_controller()
	var key: InputEventKey = InputEventKey.new()
	listener._input(key)
	var after_key: int = PLAYER.last_controller()
	PLAYER._last_pad = before
	listener.free()
	return SUPPORT.pins(TEST_NAME, [
		["a button press names its controller", heard, 3],
		["stick drift does not", after_drift, 3],
		["a real push does", after_push, 5],
		["a key changes nothing", after_key, 5]
	])


## An Android preset without the Vibrate permission, for a game that vibrates, is said in words; a ticked one, a
## preset for another platform, and a game that never vibrates are quiet.
static func _the_doctor_reads_the_android_preset() -> bool:
	var short_preset: String = "[preset.0]\n\nname=\"Phone\"\nplatform=\"Android\"\n\n[preset.0.options]\n\npermissions/vibrate=false\npermissions/internet=true\n"
	var ticked_preset: String = "[preset.0]\n\nname=\"Phone\"\nplatform=\"Android\"\n\n[preset.0.options]\n\npermissions/vibrate=true\n"
	var silent_preset: String = "[preset.0]\n\nname=\"Phone\"\nplatform=\"Android\"\n\n[preset.0.options]\n\npermissions/internet=true\n"
	var desktop_preset: String = "[preset.0]\n\nname=\"Windows\"\nplatform=\"Windows Desktop\"\n\n[preset.0.options]\n\nbinary_format/embed_pck=false\n"
	var two: String = short_preset + "\n[preset.1]\n\nname=\"Tablet\"\nplatform=\"Android\"\n\n[preset.1.options]\n\npermissions/vibrate=false\n"
	var buzzing: Dictionary = {"res://hero.gd": "func hit() -> void:\n\tInput.vibrate_handheld(100)\n"}
	var found: Array[Dictionary] = SHIP_IT.vibrate_permission_findings(short_preset, buzzing)
	var message: String = str(found[0].get("message", "")) if not found.is_empty() else ""
	return SUPPORT.pins(TEST_NAME, [
		["a preset with the permission off is named", SHIP_IT.android_presets_without_vibrate(short_preset), PackedStringArray(["Phone"])],
		["a ticked preset is not", SHIP_IT.android_presets_without_vibrate(ticked_preset), PackedStringArray()],
		["a preset that never says is off, as Godot has it", SHIP_IT.android_presets_without_vibrate(silent_preset), PackedStringArray(["Phone"])],
		["a desktop preset is not asked", SHIP_IT.android_presets_without_vibrate(desktop_preset), PackedStringArray()],
		["every short Android preset is named", SHIP_IT.android_presets_without_vibrate(two), PackedStringArray(["Phone", "Tablet"])],
		["a game that vibrates gets one warning", found.size(), 1],
		["it is a warning", str(found[0].get("severity", "")) if not found.is_empty() else "", "warning"],
		["it names the file and the fix", message.contains("hero.gd") and message.contains("Project > Export") and message.contains("Vibrate"), true],
		["a ticked preset says nothing", SHIP_IT.vibrate_permission_findings(ticked_preset, buzzing).size(), 0],
		["no export presets says nothing here", SHIP_IT.vibrate_permission_findings("", buzzing).size(), 0],
		["a Juice card is a way to vibrate", SHIP_IT.buzzes_a_phone("{\"verb\": \"vibrate\", \"weak\": 0.5}"), true],
		["a plain script is not", SHIP_IT.buzzes_a_phone("func _ready() -> void:\n\tpass\n"), false]
	])
