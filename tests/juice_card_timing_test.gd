# Godot EventSheets - a juice card's Timing: its delay and its repeats belong to that card alone.
#
# THE ONE THING THIS FILE IS ABOUT: a card's Delay, Repeat and Every move THAT card and nothing else.
# The cards under it start when they would have started without it, a Hold waits for the slowest card
# above it (its delay and its repeats included), and a Pause still pushes everything under it along.
# The Inspector's timeline, the time on a card's head, Juice Duration and the running game read one
# plan, so the plan is what is pinned here.
#
# WHY THE PLAN AND NOT A PLAY. The suite runs before any scene tree exists, and every wait in the
# player is a timer on the tree: a play of a card with a delay or a repeat cannot be timed here. The
# play itself is measured frame by frame on a running tree by a harness outside the suite.
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")

const TEST_NAME: String = "juice_card_timing"

const PACK: String = "res://eventsheet_addons/juice/juice_player.gd"

## The keys the runtime reads on every card, in the order the fold draws them.
const TIMING_KEYS: PackedStringArray = ["delay", "repeat", "interval", "clock", "chance",
	"min_strength", "max_strength"]

## A card with a delay and three repeats between two plain cards.
const MIDDLE_DELAYED: Array = [
	{"verb": "shake", "label": "A", "amount": 0.11, "effect": "", "seconds": 0.2},
	{"verb": "shake", "label": "B", "amount": 0.22, "effect": "", "seconds": 0.1, "delay": 0.3, "repeat": 3, "interval": 0.2},
	{"verb": "flash", "label": "C", "amount": 0.33, "effect": "", "seconds": 0.1}]

## A Pause inside a stretch, then a Hold: the card above the Pause has ended before the Hold is reached.
const PAUSE_IN_A_STRETCH: Array = [
	{"verb": "shake", "label": "A", "amount": 0.11, "effect": "", "seconds": 0.2},
	{"verb": "pause", "seconds": 0.25},
	{"verb": "flash", "label": "B", "amount": 0.22, "effect": "", "seconds": 0.1},
	{"verb": "hold_until", "seconds": 0.1},
	{"verb": "punch", "label": "C", "amount": 0.33, "effect": "", "seconds": 0.1}]

## Repeats above a Pause: the Pause no longer waits for them.
const REPEATS_ABOVE_A_PAUSE: Array = [
	{"verb": "shake", "label": "A", "amount": 0.11, "effect": "", "seconds": 0.1, "repeat": 3, "interval": 0.2},
	{"verb": "pause", "seconds": 0.1},
	{"verb": "flash", "label": "C", "amount": 0.33, "effect": "", "seconds": 0.1}]

## A delay on a Pause card is part of the wait: it still pushes everything under it.
const DELAYED_PAUSE: Array = [
	{"verb": "shake", "label": "A", "amount": 0.11, "effect": "", "seconds": 0.1},
	{"verb": "pause", "seconds": 0.1, "delay": 0.2},
	{"verb": "flash", "label": "C", "amount": 0.33, "effect": "", "seconds": 0.1}]

## A delayed card above a Hold: the Hold still waits for it.
const DELAYED_ABOVE_A_HOLD: Array = [
	{"verb": "shake", "label": "A", "amount": 0.11, "effect": "", "seconds": 0.2, "delay": 0.3},
	{"verb": "flash", "label": "B", "amount": 0.22, "effect": "", "seconds": 0.1},
	{"verb": "hold_until", "seconds": 0.0},
	{"verb": "punch", "label": "C", "amount": 0.33, "effect": "", "seconds": 0.1}]


static func run() -> bool:
	var pack: GDScript = load(PACK) as GDScript
	var ok: bool = SUPPORT.check(TEST_NAME, "the Juice Player script loads", pack != null, true)
	if pack == null:
		return false
	ok = _plan_pins(pack) and ok
	ok = _length_pins(pack) and ok
	ok = _hold_pins(pack) and ok
	ok = _row_pins(pack) and ok
	return ok


## Where each card starts. Measured on a running tree before the change, the card under the delayed
## one started 0.3 s late and the card under the repeats waited for all three; the plan has always
## said they start at once, and now the game does too.
static func _plan_pins(pack: GDScript) -> bool:
	return SUPPORT.pins(TEST_NAME, [
		["a delayed card starts after its own delay, and the cards round it at once",
			_starts(pack, MIDDLE_DELAYED), ["A@0.0", "B@0.3", "C@0.0"]],
		["a Hold waits from where the slowest card above it ended, not from the Pause",
			_starts(pack, PAUSE_IN_A_STRETCH), ["A@0.0", "B@0.25", "C@0.45"]],
		["a Pause under a repeating card does not wait for the repeats",
			_starts(pack, REPEATS_ABOVE_A_PAUSE), ["A@0.0", "C@0.1"]],
		["a delay on a Pause card still pushes the cards under it",
			_starts(pack, DELAYED_PAUSE), ["A@0.0", "C@0.3"]],
		["a Hold under a delayed card still waits for it",
			_starts(pack, DELAYED_ABOVE_A_HOLD), ["A@0.3", "B@0.0", "C@0.5"]],
	])


## How long a card and a list last: a card's own delay plus its length plus the gaps of its repeats.
static func _length_pins(pack: GDScript) -> bool:
	var player: Node = pack.new()
	var typed: Array[Dictionary] = []
	for card: Variant in MIDDLE_DELAYED:
		typed.append((card as Dictionary).duplicate(true))
	player.set("steps", typed)
	var card_b: float = snappedf(float(player.call("feedback_duration", "B")), 0.001)
	player.free()
	return SUPPORT.pins(TEST_NAME, [
		["one card lasts its delay, its length and the gaps of its repeats", card_b, 0.8],
		["a list lasts as long as its slowest card, repeats counted",
			snappedf(float(pack.call("duration_of", MIDDLE_DELAYED)), 0.001), 0.8],
		["a Hold ends where the slowest card above it ends, plus its own wait",
			snappedf(float(pack.call("duration_of", PAUSE_IN_A_STRETCH)), 0.001), 0.55],
		["a list of repeats above a Pause lasts until the last repeat ends",
			snappedf(float(pack.call("duration_of", REPEATS_ABOVE_A_PAUSE)), 0.001), 0.5],
	])


## What a Hold waits for is what is left of the cards above it when the head arrives.
static func _hold_pins(pack: GDScript) -> bool:
	var hold_at: int = 2
	return SUPPORT.pins(TEST_NAME, [
		["a Hold waits for what is left of a delayed card above it",
			snappedf(float(pack.call("left_above", DELAYED_ABOVE_A_HOLD, hold_at)), 0.001), 0.5],
		["a Hold after a Pause waits only for what the Pause has not already covered",
			snappedf(float(pack.call("left_above", PAUSE_IN_A_STRETCH, 3)), 0.001), 0.1],
	])


## The fold and the shipped rows write the same keys, so a card retimed by a row opens retimed.
static func _row_pins(pack: GDScript) -> bool:
	var player: Node = pack.new()
	var typed: Array[Dictionary] = [{"verb": "shake", "label": "kick", "amount": 0.4, "effect": "", "seconds": 0.2}]
	player.set("steps", typed)
	player.call("set_feedback_timing", "kick", 0.05, 3, 0.08, "real")
	player.call("set_feedback_chance", "kick", 50.0)
	var written: PackedStringArray = PackedStringArray()
	for key: Variant in (player.get("steps") as Array)[0] as Dictionary:
		if not ["verb", "label", "amount", "effect", "seconds"].has(str(key)):
			written.append(str(key))
	written.sort()
	var outside: PackedStringArray = PackedStringArray()
	for key: String in written:
		if not TIMING_KEYS.has(key):
			outside.append(key)
	player.free()
	return SUPPORT.pins(TEST_NAME, [
		["Set Juice Card Timing and Set Juice Card Chance write fold keys", written,
			PackedStringArray(["chance", "clock", "delay", "interval", "repeat"])],
		["and nothing the fold does not draw", outside, PackedStringArray()],
	])


## Each planned card as "label@start", rounded to a hundredth.
static func _starts(pack: GDScript, list: Array) -> Array:
	var starts: Array = []
	for entry: Variant in pack.call("schedule_of", list):
		var plan: Dictionary = entry as Dictionary
		starts.append("%s@%s" % [str((plan.get("card") as Dictionary).get("label", "?")),
			str(snappedf(float(plan.get("at", 0.0)), 0.01))])
	return starts
