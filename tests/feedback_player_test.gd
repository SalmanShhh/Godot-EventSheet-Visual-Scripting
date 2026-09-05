# Godot EventSheets - the Feedback Player: the list of feedbacks an object plays.
#
# THE ONE THING THIS FILE IS ABOUT: three homes, one shape. A moment written as a block of rows, a
# moment kept as a FILE and a list held by a node are the same steps, so the pins here are about the
# stored keys (a card that uses nothing extra IS a file step), the plan a list makes (a stretch runs
# at once, a Hold waits for the slowest card in it), and the walk itself (order, direction, chance,
# cooldown, a nested player, a value put back).
#
# A LIST WITH NO WAIT IN IT RUNS SYNCHRONOUSLY, which is what lets a headless test walk one: every
# await in the runner is a wait a card asked for, so a list of plain steps finishes inside the call.
# The pins that need a clock are the PLAN's - what the schedule says, rather than what a timer did.
@tool
class_name FeedbackPlayerTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const PLAYER := preload("res://eventsheet_addons/juice/feedback_player.gd")
const SCHEMA := preload("res://addons/eventsheet/editor/inspector/feedback_card_schema.gd")

const TEST_NAME: String = "feedback_player"


static func run() -> bool:
	var ok: bool = true
	ok = _schema_pins() and ok
	ok = _stored_shape_pins() and ok
	ok = _plan_pins() and ok
	ok = _walk_pins() and ok
	ok = _gate_pins() and ok
	ok = _preview_pins() and ok
	return ok


## The vocabulary is DERIVED: the ten words come off the Juice pack's Moment Step verb and each
## word's title and help come off the pack verb of that name. Two of them are pinned by value, so a
## pack that renames Shake fails here rather than shipping a card called something else.
static func _schema_pins() -> bool:
	var schema: Dictionary = SCHEMA.schema()
	var shake: Dictionary = _kind(schema, "shake")
	var flash: Dictionary = _kind(schema, "flash")
	return SUPPORT.pins(TEST_NAME, [
		["shake is titled the way the pack titles it", str(shake.get("label", "")), "Shake"],
		["shake is a camera-family card", str(shake.get("category", "")), "camera"],
		["shake offers the two fields a step carries", _field_keys(shake), PackedStringArray(["amount", "seconds"])],
		["flash is titled the way the pack titles it", str(flash.get("label", "")), "Flash"],
		["flash offers the extra word as well", _field_keys(flash), PackedStringArray(["amount", "effect", "seconds"])],
		["the enable box is an absent-means-on key", str(schema.get("enabled_key", "")), "active"],
		["a card may be renamed in place", str(schema.get("label_key", "")), "label"],
		["the screen-effect hold does not collide with the timing Hold",
			[str(_kind(schema, "hold").get("label", "")), str(_kind(schema, "hold_until").get("label", ""))],
			["Hold Effect", "Hold"]]
	])


## A brand-new card of a derived kind holds exactly the keys a moment FILE holds - which is what
## makes the node's list, the file and the block one shape rather than three that resemble each other.
static func _stored_shape_pins() -> bool:
	var schema: Dictionary = SCHEMA.schema()
	var spec: Dictionary = {"kind_key": "verb", "stripe_key": "category"}
	var card: Dictionary = EventSheetCardSchemas.new_card(spec, _kind(schema, "flash"))
	var keys: PackedStringArray = PackedStringArray()
	for key: Variant in card:
		keys.append(str(key))
	keys.sort()
	return SUPPORT.pins(TEST_NAME, [
		["a new card is a moment file's step", keys, EventSheetMomentFile.STEP_KEYS],
		["and the word is under the file's own key", str(card.get("verb", "")), "flash"]
	])


## The plan a list makes: a stretch of cards starts together, a Hold waits for the SLOWEST of them,
## and a Pause pushes everything under it along. The number the head of the Inspector shows and the
## number a row can wait for are this one walk.
static func _plan_pins() -> bool:
	var list: Array = [
		{"verb": "shake", "amount": 0.4, "seconds": 0.2},
		{"verb": "punch", "amount": 1.3, "seconds": 0.3},
		{"verb": "hold_until", "seconds": 0.1},
		{"verb": "flash", "amount": 1.0, "seconds": 0.05}
	]
	var plan: Array = PLAYER.schedule_of(list)
	var starts: Array = []
	for entry: Variant in plan:
		starts.append(snappedf(float((entry as Dictionary).get("at", 0.0)), 0.001))
	var muted: Array = list.duplicate(true)
	(muted[1] as Dictionary)["active"] = false
	return SUPPORT.pins(TEST_NAME, [
		["the hold waits for the slowest card above it", snappedf(PLAYER.duration_of(list), 0.001), 0.45],
		["the stretch starts together and the flash lands after the hold", starts, [0.0, 0.0, 0.4]],
		["an unticked card is out of the plan and out of the length",
			["%d" % PLAYER.schedule_of(muted).size(), "%.3f" % PLAYER.duration_of(muted)], ["2", "0.350"]],
		["a delay before a card pushes only that card", snappedf(PLAYER.duration_of(
			[{"verb": "shake", "seconds": 0.2, "delay": 0.1}]), 0.001), 0.3]
	])


## The walk itself: the order the cards are felt in, the direction reversed, the strength carried
## into a nested player, and a tweened value put back exactly as it was found.
static func _walk_pins() -> bool:
	var player: Node = PLAYER.new()
	var listener: Node = _listener()
	player.add_child(listener)
	var host: Node = Node2D.new()
	player.host = host
	player.play(1.0)
	var forwards: PackedStringArray = listener.get("words")
	listener.set("words", PackedStringArray())
	var three: Array[Dictionary] = [
		{"verb": "shake", "amount": 0.4, "seconds": 0.0},
		{"verb": "flash", "amount": 1.0, "seconds": 0.0},
		{"verb": "punch", "amount": 1.2, "seconds": 0.0}
	]
	player.steps = three
	player.play(1.0)
	var order: PackedStringArray = listener.get("words")
	listener.set("words", PackedStringArray())
	player.direction = "bottom to top"
	player.play(1.0)
	var backwards: PackedStringArray = listener.get("words")
	listener.set("words", PackedStringArray())

	var inner: Node = PLAYER.new()
	inner.name = "Inner"
	var inner_ear: Node = _listener()
	inner.add_child(inner_ear)
	var one: Array[Dictionary] = [{"verb": "shake", "amount": 1.0, "seconds": 0.0}]
	inner.steps = one
	player.add_child(inner)
	player.direction = "top to bottom"
	var nest: Array[Dictionary] = [{"verb": "play_player", "effect": "Inner", "amount": 0.5, "seconds": 0.0}]
	player.steps = nest
	player.play(0.8)
	var nested: float = snappedf(float(inner_ear.get("strengths")[0]) if not (inner_ear.get("strengths") as Array).is_empty() else -1.0, 0.001)

	host.modulate = Color(1, 1, 1, 1)
	var walked: Array[Dictionary] = [{"verb": "tween_property", "effect": "rotation", "amount": 2.0, "seconds": 0.0}]
	player.steps = walked
	player.play(1.0)
	var moved: float = snappedf(host.rotation, 0.001)
	player.restore()
	var put_back: float = snappedf(host.rotation, 0.001)

	var ok: bool = SUPPORT.pins(TEST_NAME, [
		["an empty list is felt as nothing", forwards, PackedStringArray()],
		["the cards are felt top to bottom", order, PackedStringArray(["shake", "flash", "punch"])],
		["and bottom to top when the list says so", backwards, PackedStringArray(["punch", "flash", "shake"])],
		["a nested player obeys the outer strength", nested, 0.4],
		["a tweened value moves and is put back", [moved, put_back], [2.0, 0.0]]
	])
	player.free()
	host.free()
	return ok


## The two gates a play has to get past before anything is felt: the chance on a card, and the
## cooldown on the player.
static func _gate_pins() -> bool:
	var player: Node = PLAYER.new()
	player.cooldown = 60.0
	var first: bool = player._may_start()
	var second: bool = player._may_start()
	var certain: bool = player._card_runs({"verb": "shake", "chance": 100.0}, 1.0)
	var never: bool = player._card_runs({"verb": "shake", "chance": 0.0}, 1.0)
	var unticked: bool = player._card_runs({"verb": "shake", "active": false}, 1.0)
	var window: bool = player._card_runs({"verb": "shake", "min_strength": 0.5}, 0.2)
	var ok: bool = SUPPORT.pins(TEST_NAME, [
		["a cooldown refuses the second play", [first, second], [true, false]],
		["a card at full chance always runs", certain, true],
		["a card at no chance never does", never, false],
		["an unticked card is skipped", unticked, false],
		["and one under its strength window is too", window, false]
	])
	player.free()
	return ok


## The editor's own look at a list: what the object would be doing at one moment of the beat. Pure
## arithmetic, so it is pinnable without a viewport, a camera or a frame.
static func _preview_pins() -> bool:
	var params: Dictionary = {"steps": [{"verb": "tween_property", "effect": "rotation", "amount": 1.0, "seconds": 0.4}],
		"strength": 1.0}
	var base: Dictionary = {"rotation": 0.0}
	var half: Dictionary = PLAYER.editor_preview_sample(params, base, 0.2)
	var past: Dictionary = PLAYER.editor_preview_sample(params, base, 1.0)
	return SUPPORT.pins(TEST_NAME, [
		["half way through, the value is half way there", snappedf(float(half.get("rotation", -1.0)), 0.001), 0.5],
		["and past the end nothing is written at all", past, {}]
	])


## A stand-in for the Juice behaviour beside a player: it answers the step call and writes down what
## it was asked for, which is what makes the walk's order readable without a running game.
static func _listener() -> Node:
	var script: GDScript = GDScript.new()
	script.source_code = "\n".join(PackedStringArray([
		"extends Node",
		"",
		"var words: PackedStringArray = PackedStringArray()",
		"var strengths: Array = []",
		"",
		"func moment_step(word: String, _amount: float, _effect: String, _seconds: float, strength: float) -> void:",
		"\twords.append(word)",
		"\tstrengths.append(strength)"
	]))
	script.reload()
	var node: Node = Node.new()
	node.set_script(script)
	return node


## One kind of the schema, by its word.
static func _kind(schema: Dictionary, word: String) -> Dictionary:
	return EventSheetCardSchemas.kind_entry(schema, word)


## A kind's field keys, in the order the card draws them.
static func _field_keys(entry: Dictionary) -> PackedStringArray:
	var keys: PackedStringArray = PackedStringArray()
	for field: Variant in EventSheetCardSchemas.fields_of(entry):
		keys.append(str((field as Dictionary).get("key", "")))
	return keys
