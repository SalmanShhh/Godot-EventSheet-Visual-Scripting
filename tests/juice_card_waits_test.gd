# Godot EventSheets - Hold that waits for one card, the cards for sound and device, Autoplay.
#
# THE ONE THING THIS FILE IS ABOUT: the plan the Inspector draws, the length a row can wait for and
# the walk itself read ONE function, so a Hold that waits for a named card moves all three together.
# Autoplay is an ordinary export that is not saved while it is off, so an old scene stays the bytes
# it was.
#
# Play Juice And Wait waiting for the cards to finish needs a running tree and a clock, which the
# suite does not have: it is proven by a scene-tree harness instead (measured before the change:
# a 0.3 s shake returned after 0 ms).
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const SCHEMA_PATH: String = "res://addons/eventsheet/editor/inspector/feedback_card_schema.gd"
const PACK: String = "res://eventsheet_addons/juice/juice_player.gd"

const TEST_NAME: String = "juice_card_waits"


static func run() -> bool:
	var ok: bool = true
	ok = _waits_for_pins() and ok
	return ok


static func _pack() -> Script:
	return load(PACK) as Script


static func _list() -> Array:
	return [
		{"verb": "shake", "amount": 0.4, "seconds": 0.2, "label": "Quick"},
		{"verb": "tween_property", "effect": "rotation", "amount": 1.0, "seconds": 0.5, "label": "Slow"},
		{"verb": "hold_until", "seconds": 0.0, "waits_for": "Quick"},
		{"verb": "flash", "amount": 1.0, "seconds": 0.1, "label": "After"}
	]


## A Hold that names a card waits for that card, not for the slowest one above it.
static func _waits_for_pins() -> bool:
	var list: Array = _list()
	var plan: Array = _pack().call("schedule_of", list)
	var flash_at: float = -1.0
	for entry: Variant in plan:
		if str(((entry as Dictionary).get("card") as Dictionary).get("label", "")) == "After":
			flash_at = snappedf(float((entry as Dictionary).get("at", 0.0)), 0.001)
	var unnamed: Array = _list()
	(unnamed[2] as Dictionary).erase("waits_for")
	var stale: Array = _list()
	(stale[2] as Dictionary)["waits_for"] = "Nothing of that name"
	var delayed: Array = _list()
	(delayed[0] as Dictionary)["label"] = "Quick"
	return SUPPORT.pins(TEST_NAME, [
		["a Hold waiting for Quick lets the card under it start when Quick ends", flash_at, 0.2],
		["the length still counts the slower card that runs on beside it",
			snappedf(float(_pack().call("duration_of", list)), 0.001), 0.5],
		["a Hold that names nothing waits for the slowest card, as before",
			snappedf(float(_pack().call("duration_of", unnamed)), 0.001), 0.6],
		["a name that is no card above waits for the slowest, as before",
			snappedf(float(_pack().call("duration_of", stale)), 0.001), 0.6],
		["what the walk waits for at that Hold is what is left of Quick",
			snappedf(float(_pack().call("left_above", list, 2)), 0.001), 0.2],
		["and with no name, what is left of the slowest",
			snappedf(float(_pack().call("left_above", unnamed, 2)), 0.001), 0.5],
		["the card name a Hold is asked for is the card's label, or its word when it has none",
			[_pack().call("card_label", {"verb": "shake", "label": " Big "}), _pack().call("card_label", {"verb": "shake"})], ["Big", "shake"]]
	])
