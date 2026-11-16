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
const SCHEMA: String = "res://addons/eventsheet/editor/inspector/feedback_card_schema.gd"
const GUIDE: String = "res://docs/GUIDE-COMPOSING-JUICE.md"

## What the fold shows for a key the card does not hold: the number the runtime uses.
const SHOWN_WHEN_ABSENT: Dictionary = {"delay": 0.0, "repeat": 1, "interval": 0.0, "clock": "game",
	"chance": 100.0, "min_strength": 0.0, "max_strength": 0.0}

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
	ok = _fold_pins() and ok
	ok = _drawer_pins() and ok
	ok = _guide_pins() and ok
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


## The Timing fold: on every kind of card, writing nothing until it is touched, showing the numbers the
## runtime uses for a key that is not there, and saying in words what the numbers do.
static func _fold_pins() -> bool:
	var schema_script: GDScript = load(SCHEMA)
	var schema: Dictionary = schema_script.call("schema")
	var missing: PackedStringArray = PackedStringArray()
	var seeded: PackedStringArray = PackedStringArray()
	var shown_wrong: PackedStringArray = PackedStringArray()
	var not_folded: PackedStringArray = PackedStringArray()
	var twice: PackedStringArray = PackedStringArray()
	var spec: Dictionary = {"kind_key": "verb", "stripe_key": "category"}
	var walked: int = 0
	for kind: Variant in schema.get("kinds", []):
		var entry: Dictionary = kind as Dictionary
		var name: String = str(entry.get("kind", ""))
		var fields: Dictionary = {}
		var seen: Dictionary = {}
		for field: Variant in EventSheetCardSchemas.all_fields(schema, entry):
			var key: String = str((field as Dictionary).get("key", ""))
			if seen.has(key):
				twice.append("%s.%s" % [name, key])
			seen[key] = true
			fields[key] = field
		for key: String in TIMING_KEYS:
			if not fields.has(key):
				missing.append("%s.%s" % [name, key])
				continue
			var field: Dictionary = fields[key] as Dictionary
			if not field.has("unset") or field.get("unset") != SHOWN_WHEN_ABSENT[key]:
				shown_wrong.append("%s.%s" % [name, key])
			if EventSheetCardSchemas.field_fold(field) != "Timing":
				not_folded.append("%s.%s" % [name, key])
		var fresh: Dictionary = EventSheetCardSchemas.new_card(spec, entry)
		for key: String in TIMING_KEYS:
			if fresh.has(key):
				seeded.append("%s.%s" % [name, key])
		walked += 1
	var sentences: Array = []
	var marked: Array = []
	for card: Dictionary in [
			{"verb": "shake", "delay": 0.05, "repeat": 3, "interval": 0.08},
			{"verb": "shake"},
			{"verb": "shake", "repeat": 2},
			{"verb": "shake", "chance": 50.0, "clock": "real"},
			{"verb": "shake", "delay": 0.2},
			{"verb": "shake", "min_strength": 0.5, "max_strength": 2.0},
			{"verb": "shake", "min_strength": 0.5}]:
		sentences.append(schema_script.call("timing_sentence", card))
		marked.append(schema_script.call("timing_differs", card))
	return SUPPORT.pins(TEST_NAME, [
		["the walk reached every kind the schema holds", walked > 40, true],
		["every kind of card has every Timing field", missing, PackedStringArray()],
		["and none twice", twice, PackedStringArray()],
		["each in the Timing fold", not_folded, PackedStringArray()],
		["a new card stores no Timing key", seeded, PackedStringArray()],
		["a Timing field shows the runtime's own number while its key is absent", shown_wrong, PackedStringArray()],
		["the grey line says in words what the numbers do", sentences, [
			"Waits 0.05 s, then is felt 3 times, 0.08 s apart.",
			"Plays as soon as the list reaches it, once.",
			"Plays as soon as the list reaches it, then is felt 2 times.",
			"Plays as soon as the list reaches it, once. Felt 50% of the time, counts real time.",
			"Waits 0.2 s, then plays once.",
			"Plays as soon as the list reaches it, once. Only at strength 0.5 to 2.",
			"Plays as soon as the list reaches it, once. Only at strength 0.5 and up."]],
		["only a card whose timing differs from the defaults wears the clock mark", marked,
			[true, false, true, true, true, true, true]],
	])


## The guide describes the fold the product has: no cooldown on a card, no skip on stop.
static func _guide_pins() -> bool:
	var text: String = FileAccess.get_file_as_string(GUIDE) if FileAccess.file_exists(GUIDE) else ""
	var timing_line: String = ""
	for paragraph: String in text.split("

"):
		if paragraph.contains("**Timing**"):
			timing_line = paragraph
	return SUPPORT.pins(TEST_NAME, [
		["the guide still describes the Timing fold", timing_line.is_empty(), false],
		["and promises no cooldown on a card", timing_line.contains("cooldown"), false],
		["and no skip on stop", timing_line.contains("skip on stop"), false],
	])


## The drawer: the fold is Godot's own foldable container, closed until it is opened, it writes nothing by being
## drawn, a number typed into it writes the key the rows write (a whole number for the repeat), the strength
## window sits on one row, and the clock mark on the head lights when a number differs.
static func _drawer_pins() -> bool:
	var schema: Dictionary = (load(SCHEMA) as GDScript).call("schema")
	var drawer: EventSheetCardListDrawer = EventSheetCardListDrawer.new({"schema_dict": schema, "kind_key": "verb"})
	var card: Dictionary = {"verb": "shake", "amount": 0.4, "effect": "", "seconds": 0.2}
	drawer.set_value([card])
	drawer._unfolded[0] = true
	drawer._rebuild()
	var before: Array = drawer.get_value()
	var fold: FoldableContainer = _first_fold(drawer)
	var has_fold: bool = fold != null
	var closed: bool = has_fold and fold.folded
	var title: String = fold.title if fold != null else ""
	var mark: Control = drawer._timing_marks.get(0) as Control
	var mark_before: bool = mark != null and mark.visible
	var spins: Array = fold.find_children("*", "SpinBox", true, false) if fold != null else []
	var limit_rows: int = 0
	var edits: Array = fold.find_children("*", "LineEdit", true, false) if fold != null else []
	for row: Node in fold.find_children("*", "HBoxContainer", true, false) if fold != null else []:
		if row.get_children().filter(func(child: Node) -> bool: return child is SpinBox or (child is LineEdit and not (child.get_parent() is SpinBox))).size() >= 2:
			limit_rows += 1
	# Typing into the Repeat box (the second number box) writes a whole number under the key the row writes.
	var repeat_box: SpinBox = spins[1] as SpinBox if spins.size() > 1 else null
	if repeat_box != null:
		repeat_box.value = 3.0
		repeat_box.value_changed.emit(3.0)
	var written: Dictionary = (drawer.get_value()[0] as Dictionary)
	var mark_after: bool = mark != null and mark.visible
	var repeat_type: int = typeof(written.get("repeat"))
	drawer.free()
	return SUPPORT.pins(TEST_NAME, [
		["the Timing fold is drawn inside an open card and starts closed", [has_fold, closed, title], [true, true, "Timing"]],
		["drawing a card writes nothing to it", before, [card]],
		["the clock mark is out while the timing is the default", mark_before, false],
		["a number typed in the fold writes the key the rows write, as a whole number for a count", [written.get("repeat"), repeat_type], [3, TYPE_INT]],
		["and the clock mark lights", mark_after, true],
		["the strength window is one row holding its two boxes", limit_rows >= 1, true],
	])


static func _first_fold(root: Node) -> FoldableContainer:
	for node: Node in root.find_children("*", "FoldableContainer", true, false):
		return node as FoldableContainer
	return null
