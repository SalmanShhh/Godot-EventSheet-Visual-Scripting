# Godot EventSheets - the quiet amber lines that say a loop has nothing in it that takes time.
#
# THE ONE THING THIS FILE IS ABOUT: a loop that runs out of steps is said at edit time, where the list
# shows it, and only when it is true. A Loop Back over cards that take no time and ask for so many
# passes that the play reaches its step limit says so under itself; a node whose Loop is ticked over a
# list with no time says so under the list; a loop with a Pause in it, a small count, or nowhere to
# go back to says nothing.
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")

const TEST_NAME: String = "juice_loop_findings"

const KINDS: String = "res://addons/eventsheet/editor/inspector/juice_card_kinds.gd"
const STRIP: String = "res://addons/eventsheet/editor/inspector/feedback_player_strip.gd"


static func run() -> bool:
	var kinds: GDScript = load(KINDS) as GDScript
	var strip: GDScript = load(STRIP) as GDScript
	var start: Dictionary = {"verb": "loop_start"}
	var say: Dictionary = {"verb": "emit_signal", "effect": "tick", "seconds": 0.0}
	var wait: Dictionary = {"verb": "pause", "seconds": 0.1}
	var back: Dictionary = {"verb": "loop_back", "seconds": 0.0, "loops": 100000}
	var small: Dictionary = {"verb": "loop_back", "seconds": 0.0, "loops": 3}
	var breathing: Dictionary = {"verb": "loop_back", "seconds": 0.25, "loops": 100000}
	var no_start: Dictionary = {"verb": "loop_back", "seconds": 0.0, "loops": 100000, "to_hold": false, "to_loop_start": false}
	var long_card: Dictionary = {"verb": "tween_property", "effect": "rotation", "amount": 1.0, "seconds": 0.5}
	return SUPPORT.pins(TEST_NAME, [
		["a loop of cards with no time and a huge count is found", kinds.call("loop_has_no_time", back, [start, say, back], 2), true],
		["its line says it gives up after 4096 steps", str(kinds.call("loop_note", back, [start, say, back], 2, null)).contains("4096"), true],
		["a Pause inside the loop gives it room", kinds.call("loop_has_no_time", back, [start, wait, back], 2), false],
		["a card with a length inside the loop gives it room", kinds.call("loop_has_no_time", back, [start, long_card, back], 2), false],
		["a pause on the Loop Back itself gives it room", kinds.call("loop_has_no_time", breathing, [start, say, breathing], 2), false],
		["a small count ends long before the limit", kinds.call("loop_has_no_time", small, [start, say, small], 2), false],
		["a Loop Back with nowhere to go back to loops nowhere, so it says nothing", kinds.call("loop_has_no_time", no_start, [say, no_start], 1), false],
		["a loop with room says nothing at all", str(kinds.call("loop_note", back, [start, wait, back], 2, null)), ""],
		["Loop ticked on a list with no time is said under the list", str(strip.call("loop_note_text", true, 0.0)).is_empty(), false],
		["Loop ticked on a list with a length says nothing", str(strip.call("loop_note_text", true, 0.4)), ""],
		["Loop off says nothing", str(strip.call("loop_note_text", false, 0.0)), ""],
	])
