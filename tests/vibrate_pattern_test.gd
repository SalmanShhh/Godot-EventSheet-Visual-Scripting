# A Vibrate card pulses through the Timing foldout every card has: Repeat and Every. This file holds the
# pieces of that to account:
#
#   * AN OLD CARD BUZZES ONCE. A card with none of the timing keys is one buzz of its For time.
#   * A PATTERN'S LENGTH IS ITS BUZZES. The badge, the list's length and the Hold all read the same sums.
#   * A TYPED PATTERN IS THE SAME PASSES. vibrate_pattern times its buzzes with the code the card's Repeat uses; one buzz is vibrate.
#   * THE MOTORS BELONG TO THE PLAYER. A player stops only the rumbles it started, and keeps that
#     account on itself, so two players sharing one list never stop each other's motors.
@tool
class_name VibratePatternTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const SCHEMA := preload("res://addons/eventsheet/editor/inspector/feedback_card_schema.gd")
const PLAYER_PATH: String = "res://eventsheet_addons/juice/juice_player.gd"
const PLAYER_SCRIPT := preload("res://eventsheet_addons/juice/juice_player.gd")
const MOMENTS := preload("res://eventsheet_addons/juice/moment_runner.gd")


static func _player() -> GDScript:
	return load(PLAYER_PATH) as GDScript


static func run() -> bool:
	var ok: bool = true
	ok = _test_an_old_card_buzzes_once() and ok
	ok = _test_a_pattern_is_the_sum_of_its_buzzes() and ok
	ok = _test_the_card_help_names_the_timing_foldout() and ok
	ok = _test_the_motors_belong_to_the_player() and ok
	ok = _test_pulses_start_on_the_stopwatch() and ok
	ok = _test_a_pattern_picks_its_controller() and ok
	ok = _test_one_buzz_is_vibrate() and ok
	ok = _test_a_stop_cancels_a_pattern() and ok
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


## A stand-in that writes down which controller each buzz was sent to, so a pattern is a list of words rather than
## something to listen for.
class Rumbler extends PLAYER_SCRIPT:

	var sent: Array = []

	func vibrate_controller(controller: int, weak: float = 0.5, strong: float = 0.5, seconds: float = 0.2) -> void:
		sent.append([controller, snappedf(weak, 0.001), snappedf(strong, 0.001), snappedf(seconds, 0.001)])


## When each buzz after the first starts, in seconds from the first, for a pattern driven by chosen frames. The
## pattern is the same function the card's Repeat reaches, handed a stopwatch the test ticks itself.
static func _pulse_times(times: int, every: float, cancel_after: float = -1.0) -> Array:
	var player: Node = PLAYER_SCRIPT.new()
	var watch: Object = MOMENTS.Stopwatch.new(null, false)
	var found: Array = []
	(player.get("_pattern_runs") as Array).append(7)
	player.call("_pulse_rest", times, every, 7, watch, func() -> void: found.append(snappedf(watch.elapsed, 0.0001)))
	var frame: float = 0.0625
	for index: int in range(400):
		watch.tick(frame)
		if cancel_after >= 0.0 and watch.elapsed >= cancel_after:
			player.call("_stop_rumble")
			cancel_after = -1.0
	player.free()
	return found


static func _test_pulses_start_on_the_stopwatch() -> bool:
	return SUPPORT.pins("vibrate_pattern_test", [
		["three buzzes every half second start at 0.5 and 1.0 after the first", _pulse_times(3, 0.5), [0.5, 1.0]],
		["one buzz asks for no later start", _pulse_times(1, 0.5), []],
		["no buzzes is one buzz", _pulse_times(0, 0.5), []],
		["every 0 is a frame apart, as a card with Every 0 is", _pulse_times(3, 0.0), [0.0625, 0.125]],
		["a negative every counts as 0", _pulse_times(3, -2.0), [0.0625, 0.125]],
		["a stop between the second and third buzz cancels the rest", _pulse_times(4, 0.5, 0.6), [0.5]]
	])


static func _test_a_pattern_picks_its_controller() -> bool:
	var rumbler: Rumbler = Rumbler.new()
	rumbler.vibrate_pattern(1, 0.0, 0.2, 0.3, 0.4)
	rumbler.vibrate_pattern(1, 0.0, 0.2, 0.3, 0.4, 2)
	rumbler.vibrate_pattern(1, 0.0, 0.2, 0.3, 0.4, rumbler.LAST_USED_CONTROLLER)
	var ok: bool = SUPPORT.pins("vibrate_pattern_test", [
		["the default controller is every controller", rumbler.sent[0], [-1, 0.2, 0.3, 0.4]],
		["a number rumbles that controller", rumbler.sent[1], [2, 0.2, 0.3, 0.4]],
		["the last used, with none heard, falls back to every controller", rumbler.sent[2], [-1, 0.2, 0.3, 0.4]],
		["the constants are distinct", [rumbler.EVERY_CONTROLLER, rumbler.LAST_USED_CONTROLLER], [-1, -2]]
	])
	rumbler.free()
	return ok


static func _test_one_buzz_is_vibrate() -> bool:
	var pattern: Rumbler = Rumbler.new()
	var plain: Rumbler = Rumbler.new()
	pattern.vibrate_pattern(1, 0.5, 0.2, 0.3, 0.4)
	plain.vibrate(0.2, 0.3, 0.4)
	var none: Rumbler = Rumbler.new()
	none.vibrate_pattern(0, 0.5, 0.2, 0.3, 0.4)
	none.vibrate_pattern(-3, 0.5, 0.2, 0.3, 0.4)
	var ok: bool = SUPPORT.pins("vibrate_pattern_test", [
		["times 1 sends what vibrate sends", pattern.sent, plain.sent],
		["times 0 and below are one buzz each", none.sent.size(), 2],
		["and leave nothing waiting", [(pattern.get("_pattern_runs") as Array).size(), (none.get("_pattern_runs") as Array).size()], [0, 0]]
	])
	pattern.free()
	plain.free()
	none.free()
	return ok


static func _test_a_stop_cancels_a_pattern() -> bool:
	var rumbler: Rumbler = Rumbler.new()
	rumbler.vibrate_pattern(3, 0.5, 0.2, 0.3, 0.4)
	rumbler.vibrate_pattern(3, 0.5, 0.2, 0.3, 0.4)
	var waiting: Array = (rumbler.get("_pattern_runs") as Array).duplicate()
	var alive_before: bool = rumbler.call("_alive", waiting[0])
	rumbler.call("_note_rumble", 0, 30.0)
	rumbler.stop()
	var alive_after: bool = rumbler.call("_alive", waiting[0])
	var ok: bool = SUPPORT.pins("vibrate_pattern_test", [
		["each call is a pattern of its own and the first buzz came at once", [waiting.size(), rumbler.sent.size()], [2, 2]],
		["a waiting pattern is alive", alive_before, true],
		["Stop ends every waiting pattern", [alive_after, (rumbler.get("_pattern_runs") as Array).size()], [false, 0]],
		["and quiets the motors it noted", (rumbler.get("_rumbling") as Array).size(), 0]
	])
	rumbler.free()
	return ok
