# A Vibrate card pulses through the Timing foldout every card has: Repeat and Every. This file holds the
# pieces of that to account:
#
#   * AN OLD CARD BUZZES ONCE. A card with none of the timing keys is one buzz of its For time.
#   * A PATTERN'S LENGTH IS ITS BUZZES. The badge, the list's length and the Hold all read the same sums.
#   * THE MOTORS BELONG TO THE PLAYER. A player stops only the rumbles it started, and keeps that
#     account on itself, so two players sharing one list never stop each other's motors.
@tool
class_name VibratePatternTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const SCHEMA := preload("res://addons/eventsheet/editor/inspector/feedback_card_schema.gd")
const PLAYER_PATH: String = "res://eventsheet_addons/juice/juice_player.gd"


static func _player() -> GDScript:
	return load(PLAYER_PATH) as GDScript


static func run() -> bool:
	var ok: bool = true
	ok = _test_an_old_card_buzzes_once() and ok
	ok = _test_a_pattern_is_the_sum_of_its_buzzes() and ok
	ok = _test_the_card_help_names_the_timing_foldout() and ok
	ok = _test_the_motors_belong_to_the_player() and ok
	return ok


static func _test_an_old_card_buzzes_once() -> bool:
	var old_card: Dictionary = {"verb": "vibrate", "weak": 0.5, "strong": 0.5, "seconds": 0.2}
	return SUPPORT.pins("vibrate_pattern_test", [
		["an old card is one buzz long", SCHEMA.card_seconds(old_card), 0.2],
		["and its span in the player is the same", _player().card_span(old_card), 0.2],
		["and it asks for no timing", SCHEMA.timing_differs(old_card), false]
	])


static func _test_a_pattern_is_the_sum_of_its_buzzes() -> bool:
	var pattern: Dictionary = {"verb": "vibrate", "seconds": 0.2, "repeat": 3, "interval": 0.5}
	var delayed: Dictionary = {"verb": "vibrate", "seconds": 0.2, "repeat": 3, "interval": 0.5, "delay": 1.0}
	var list: Array = [pattern, {"verb": "pause", "seconds": 0.1}, {"verb": "vibrate", "seconds": 0.3}]
	return SUPPORT.pins("vibrate_pattern_test", [
		["three buzzes, one start every half second, last one 0.2 s long", SCHEMA.card_seconds(pattern), 1.2],
		["the player measures the same span", _player().card_span(pattern), 1.2],
		["a delay holds the card up first", SCHEMA.card_seconds(delayed), 2.2],
		["the list is as long as its longest stretch", _player().duration_of(list), 1.2],
		["a pattern is a change from the defaults", SCHEMA.timing_differs(pattern), true]
	])


static func _test_the_card_help_names_the_timing_foldout() -> bool:
	var help: String = ""
	for kind: Dictionary in SCHEMA.sound_control_kinds():
		if str(kind.get("kind", "")) == "vibrate":
			help = str(kind.get("help", ""))
	return SUPPORT.pins("vibrate_pattern_test", [
		["the help points at Repeat and Every", help.contains("Repeat") and help.contains("Every"), true],
		["and no longer sends a reader to the loop words", help.contains("Loop Start"), false]
	])


static func _test_the_motors_belong_to_the_player() -> bool:
	var first: Node = _player().new()
	var second: Node = _player().new()
	first.call("_note_rumble", 0, 30.0)
	var before: Array = (first.get("_rumbling") as Array).duplicate()
	var untouched: Array = (second.get("_rumbling") as Array).duplicate()
	second.call("_stop_rumble")
	var still: Array = (first.get("_rumbling") as Array).duplicate()
	first.call("_stop_rumble")
	var after: Array = (first.get("_rumbling") as Array).duplicate()
	var ends: float = float(first.get("_rumble_ends_at"))
	first.free()
	second.free()
	return SUPPORT.pins("vibrate_pattern_test", [
		["a rumble is written down on the player that started it", before, [0]],
		["another player has nothing written down", untouched, []],
		["stopping the other player leaves the first one's account alone", still, [0]],
		["stopping clears the account", after, []],
		["and the end time", ends, 0.0]
	])
