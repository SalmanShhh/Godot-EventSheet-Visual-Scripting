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
	ok = _outer_and_inner_pins() and ok
	ok = _file_pins() and ok
	ok = _boundary_pins() and ok
	return ok


## A player that answers a list rather than a real one, so what the outer play TELLS its children
## can be pinned as words instead of guessed at from their state.
class TellTale extends Node:

	var told: PackedStringArray = PackedStringArray()

	func play(at_strength: float) -> void:
		told.append("play %s" % snappedf(at_strength, 0.001))

	func skip_to_end() -> void:
		told.append("skip_to_end")

	func stop() -> void:
		told.append("stop")


## THE EDGES OF A PLAY: the ceiling that is not this node's to apply, the cards a skip has already
## passed, the children a restart interrupts, and the counters a shared file must not carry.
static func _boundary_pins() -> bool:
	# The no-flashing ceiling belongs to the words a player SEES. A property tween's target is a
	# position, not an amplitude, so 200 stays 200 and the walk keeps the length it was given -
	# under the ceiling it used to arrive as 0.3, taken over four tenths of a second.
	var was_dimmed: bool = bool(Engine.get_meta(&"no_flashing", false))
	Engine.set_meta(&"no_flashing", true)
	var dimmed: Node = PLAYER.new()
	var dimmed_host: Node2D = Node2D.new()
	dimmed.host = dimmed_host
	dimmed_host.rotation = 0.0
	dimmed.steps = [{"verb": "tween_property", "effect": "rotation", "amount": 200.0, "seconds": 0.0}] as Array[Dictionary]
	dimmed.play(1.0)
	var tweened: float = snappedf(dimmed_host.rotation, 0.001)
	var clamped: float = snappedf(MomentRunner.scaled(1.0, 1.0), 0.001)
	var is_seen: bool = MomentRunner.is_amplitude("shake")
	var is_not_seen: bool = MomentRunner.is_amplitude("tween_property")
	if was_dimmed:
		Engine.set_meta(&"no_flashing", true)
	else:
		Engine.remove_meta(&"no_flashing")

	# A Skip To End does the cards the walk has NOT reached. The head is the one card that could be
	# in both, so a walk that has taken it says so and the skip starts under it.
	var skipper: Node = PLAYER.new()
	var skipper_host: Node2D = Node2D.new()
	skipper.host = skipper_host
	var listener: TellTale = TellTale.new()
	listener.name = "Listener"
	skipper.add_child(listener)
	skipper._order = [
		{"verb": "tween_property", "effect": "rotation", "amount": 5.0, "seconds": 0.0},
		{"verb": "play_player", "effect": "Listener", "amount": 1.0, "seconds": 0.0}
	]
	skipper._head = 0
	skipper._head_taken = true
	skipper._head_strength = 1.0
	skipper.playing = true
	skipper._live = [1] as Array[int]
	skipper_host.rotation = 0.0
	skipper.skip_to_end()
	var passed_over: float = snappedf(skipper_host.rotation, 0.001)
	var nested_told: PackedStringArray = listener.told.duplicate()

	# And the head the walk has NOT taken is done by the skip.
	skipper._order = [{"verb": "tween_property", "effect": "rotation", "amount": 5.0, "seconds": 0.0}]
	skipper._head = 0
	skipper._head_taken = false
	skipper.playing = true
	skipper._live = [1] as Array[int]
	skipper.skip_to_end()
	var head_felt: float = snappedf(skipper_host.rotation, 0.001)

	# One roll per card per play: asking twice is the same answer, not a second throw of the dice.
	var chancer: Node = PLAYER.new()
	var chance_card: Dictionary = {"verb": "shake", "chance": 50.0}
	chancer._rolls[0] = 90.0
	var first: String = chancer._why_not(chance_card, 1.0, 0)
	var second: String = chancer._why_not(chance_card, 1.0, 0)

	# A restart ends the play it interrupts the way Stop Feedbacks ends one, children included.
	var restarter: Node = PLAYER.new()
	var interrupted: TellTale = TellTale.new()
	restarter.while_playing = "restart"
	restarter.playing = true
	restarter._live = [1] as Array[int]
	restarter._nested = [interrupted] as Array[Node]
	var may: bool = restarter._may_start()

	# A moment file is ONE resource two players may both be playing, so a loop counter belongs to
	# the play and never to the file: the file comes back from a play exactly as it went in.
	var kind: Script = load("res://eventsheet_addons/moment_resource/moment_resource.gd") as Script
	var shared: Resource = kind.new()
	shared.set("steps", [{"verb": "shake", "amount": 0.4, "seconds": 0.0, "loops": 3}] as Array[Dictionary])
	var one: Node = PLAYER.new()
	var two: Node = PLAYER.new()
	one.moment_file = shared
	two.moment_file = shared
	one.play(1.0)
	var carried: PackedStringArray = PackedStringArray()
	for named: Variant in ((shared.get("steps") as Array)[0] as Dictionary).keys():
		carried.append(str(named))
	carried.sort()

	var ok: bool = SUPPORT.pins(TEST_NAME, [
		["a property tween is no amplitude, so no flashing does not hold it down", tweened, 200.0],
		["and an amount a player sees still is", clamped, 0.3],
		["the words the ceiling is about are the runner's one list", [is_seen, is_not_seen],
			[true, false]],
		["a skip steps over the card the walk already took", passed_over, 0.0],
		["and does the one it had not", head_felt, 5.0],
		["a player a skip starts is skipped too", nested_told,
			PackedStringArray(["play 1.0", "skip_to_end"])],
		["a card's chance is one decision, not one throw per asking", [first, second],
			["chance", "chance"]],
		["a restart tells the players its play started", interrupted.told,
			PackedStringArray(["stop"])],
		["and still lets the new play begin", may, true],
		["a shared moment file carries no play's loop counter", carried,
			PackedStringArray(["amount", "loops", "seconds", "verb"])],
		["the play keeps its own count instead", int(one._loops_left.get(0, -1)), 3],
		["and a player that has not played has none", two._loops_left.is_empty(), true]
	])
	dimmed.free()
	dimmed_host.free()
	skipper.free()
	skipper_host.free()
	chancer.free()
	interrupted.free()
	restarter.free()
	one.free()
	two.free()
	return ok


## WHAT THE OUTER PLAY REACHES. A Play Player card starts another list, and that list is part of the
## beat around it - so the player it started is remembered and told what the outer one is told. And
## the player's own strength scales every kind of card, not only the felt ones: a tween that moves
## the object is exactly what an accessibility setting turning a whole object down has to reach.
static func _outer_and_inner_pins() -> bool:
	var player: Node = PLAYER.new()
	var host: Node2D = Node2D.new()
	player.host = host
	var inner: Node = PLAYER.new()
	inner.name = "Inner"
	inner.steps = [{"verb": "shake", "amount": 1.0, "seconds": 0.0}] as Array[Dictionary]
	player.add_child(inner)
	player.steps = [{"verb": "play_player", "effect": "Inner", "amount": 1.0, "seconds": 0.0}] as Array[Dictionary]
	player.play(1.0)
	var remembered: int = (player._nested as Array).size()
	player._told_nested("stop")
	var let_go: int = (player._nested as Array).size()

	host.rotation = 0.0
	player.strength = 0.5
	player.steps = [{"verb": "tween_property", "effect": "rotation", "amount": 2.0, "seconds": 0.0}] as Array[Dictionary]
	player.play(1.0)
	var moved: float = snappedf(host.rotation, 0.001)

	# The fold a Hold waits for, over cards the walk has already waited the delays of.
	var order: Array = [
		{"verb": "shake", "seconds": 0.2},
		{"verb": "flash", "delay": 0.3, "seconds": 0.05},
		{"verb": "hold_until", "seconds": 0.0}
	]
	var fold: float = snappedf(player._longest_above(order, 2), 0.001)
	var ok: bool = SUPPORT.pins(TEST_NAME, [
		["a nested play is remembered by the list that started it", remembered, 1],
		["and let go of once it has been told", let_go, 0],
		["the player's own strength scales a tween card too", moved, 1.0],
		["a Hold waits for what is LEFT of the cards above it", fold, 0.05],
		["a channel speaks a name of this pack's own",
			player.has_method("play_feedbacks_from_channel"), true]
	])
	player.free()
	host.free()
	return ok


## A moment file holds ten words and no timing, so what a list saves out is the cards a file can
## hold - and the ones it cannot are named rather than written in as playing steps.
static func _file_pins() -> bool:
	var player: Node = PLAYER.new()
	player.steps = [
		{"verb": "shake", "amount": 0.4, "seconds": 0.1},
		{"verb": "flash", "amount": 1.0, "seconds": 0.1, "active": false},
		{"verb": "pause", "seconds": 0.2},
		{"verb": "tween_property", "effect": "rotation", "amount": 2.0, "seconds": 0.1},
		{"verb": "emit_signal", "effect": "hit", "seconds": 0.0},
		{"verb": "play_player", "effect": "Inner", "seconds": 0.0}
	] as Array[Dictionary]
	var path: String = "user://feedback_player_test_moment.tres"
	player.save_moment_file(path)
	var written: Resource = load(path) if ResourceLoader.exists(path) else null
	var kept: Array = (written.get("steps") as Array) if written != null else []
	var words: PackedStringArray = PackedStringArray()
	for card: Variant in kept:
		if card is Dictionary:
			words.append(str((card as Dictionary).get("verb", "")))
	var ok: bool = SUPPORT.pins(TEST_NAME, [
		["only the cards a file can hold are written", words, PackedStringArray(["shake"])]
	])
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	player.free()
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
	var certain: bool = player._card_runs({"verb": "shake", "chance": 100.0}, 1.0, 0)
	var never: bool = player._card_runs({"verb": "shake", "chance": 0.0}, 1.0, 1)
	var unticked: bool = player._card_runs({"verb": "shake", "active": false}, 1.0, 2)
	var window: bool = player._card_runs({"verb": "shake", "min_strength": 0.5}, 0.2, 3)
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
