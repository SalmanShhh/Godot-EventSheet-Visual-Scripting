# Godot EventSheets - a moment played the other way, turned around, jumped to the end, put back.
#
# THE ONE THING THIS FILE IS ABOUT: a beat is no longer a list of calls that happens and is gone.
# It has an order (which reverses), a book of the values it found before it touched them (which a
# Restore reads), an end it can be jumped to, and four signals a sheet can hang rows off. The pins
# here are the ORDER, the BOOK and the SIGNALS - the three facts everything else is built on.
#
# WHY IT CAN RUN HEADLESS: the ordering and the labelling live in the moment runner, which is pure
# arithmetic over an Array of step dictionaries, and the book lives on the behaviour but reads
# values a detached node still has - its own host's tint and scale, and the engine's time scale. A
# camera zoom and a post effect answer null with no camera and no post stack, so they are simply
# not recorded, which is the same path a game with neither takes.
#
# THE ENGINE LEDGER IS BALANCED: this test writes Engine.time_scale and the no-flashing meta and
# puts both back exactly as it found them, because the suite runs serially on CI and a leaked time
# scale is a later test's mystery.
@tool
class_name MomentPlaybackTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const PACK := preload("res://eventsheet_addons/juice/juice_behavior.gd")
const RUNNER := preload("res://eventsheet_addons/juice/moment_runner.gd")

const TEST_NAME: String = "moment_playback"

## The no-flashing meta, spelled the way the runner spells it, so the clamp pin asks the real question.
const NO_FLASHING: StringName = &"no_flashing"


static func run() -> bool:
	var ok: bool = true
	ok = _order_pins() and ok
	ok = _label_and_length_pins() and ok
	ok = _touched_pins() and ok
	ok = _restore_pins() and ok
	ok = _skip_pins() and ok
	ok = _revert_pins() and ok
	ok = _signal_pins() and ok
	ok = _clamp_pins() and ok
	return ok


## The order a play walks. Forwards is the list; backwards is the list read from the bottom, with
## every step still in it - a beat in reverse is the whole beat. The way HOME is different: the
## words that cannot be undone are stepped over, because firing a shake again on the way back would
## be a second shake rather than the first one un-happening.
static func _order_pins() -> bool:
	var steps: Array = [
		{"verb": "flash", "amount": 0.5, "effect": "white", "seconds": 0.2},
		{"verb": "shake", "amount": 0.4, "seconds": 0.1},
		{"verb": "punch", "amount": 0.3, "seconds": 0.2},
		{"verb": "hold", "amount": 0.6, "effect": "vignette", "seconds": 0.3}
	]
	return SUPPORT.pins(TEST_NAME, [
		["forwards is the list in order", RUNNER.walk_order(steps, false), PackedInt32Array([0, 1, 2, 3])],
		["backwards is the list from the bottom", RUNNER.walk_order(steps, true), PackedInt32Array([3, 2, 1, 0])],
		["the way home leaves out the words that cannot be undone", RUNNER.revert_order(steps), PackedInt32Array([3, 0])],
		["a shake is one-way", RUNNER.is_one_way("shake"), true],
		["a held effect is not", RUNNER.is_one_way("hold"), false],
		["an empty moment walks nowhere", RUNNER.walk_order([], true), PackedInt32Array([])]
	])


## What a step is CALLED and how long a beat lasts. A step with a label of its own answers with it;
## one without answers with the word it is made of; one that is neither answers with its place, so
## a trigger always carries something a reader can find in the list.
static func _label_and_length_pins() -> bool:
	var steps: Array = [
		{"verb": "shake", "amount": 0.4, "seconds": 0.1},
		{"verb": "flash", "label": "the white one", "seconds": 0.5},
		{"amount": 1.0}
	]
	return SUPPORT.pins(TEST_NAME, [
		["a step with no label is called by its word", RUNNER.step_label(steps[0], 0), "shake"],
		["a labelled step is called by its label", RUNNER.step_label(steps[1], 1), "the white one"],
		["a step that is neither is called by its place", RUNNER.step_label(steps[2], 2), "step 3"],
		["a beat lasts as long as its slowest step", RUNNER.length_of(steps), 0.5],
		["a beat of instant steps has no length", RUNNER.length_of([{"verb": "shake"}]), 0.0],
		["progress runs from nothing to all of it", [RUNNER.progress_of(0.0, 0.5), RUNNER.progress_of(0.25, 0.5), RUNNER.progress_of(9.0, 0.5)], [0.0, 0.5, 1.0]],
		["a beat with no length is over the moment it begins", RUNNER.progress_of(0.0, 0.0), 1.0]
	])


## Which values a beat writes. This is the whole first-touch rule in one table: a Restore can only
## put back what this says a step touched, so a step word that starts moving something new has to
## be named here before the book can hold it.
static func _touched_pins() -> bool:
	var steps: Array = [
		{"verb": "flash", "amount": 0.5, "effect": "white"},
		{"verb": "punch", "amount": 0.3},
		{"verb": "slowmo", "amount": 0.4},
		{"verb": "shake", "amount": 0.4},
		{"verb": "hold", "amount": 0.6, "effect": "vignette"}
	]
	return SUPPORT.pins(TEST_NAME, [
		["a flash writes the host's tint", RUNNER.touched_by("flash"), RUNNER.TOUCH_HOST_TINT],
		["a punch writes the host's scale", RUNNER.touched_by("punch"), RUNNER.TOUCH_HOST_SCALE],
		["a slowmo and a hitstop both write the time scale", [RUNNER.touched_by("slowmo"), RUNNER.touched_by("hitstop")], [RUNNER.TOUCH_TIME_SCALE, RUNNER.TOUCH_TIME_SCALE]],
		["a held effect writes that effect", RUNNER.touched_by("hold", "vignette"), "post vignette"],
		["a shake leaves nothing behind", RUNNER.touched_by("shake"), ""],
		["a held effect with no name leaves nothing behind either", RUNNER.touched_by("hold", ""), ""],
		["a whole beat names each value once, in the order it meets them", RUNNER.touched_by_steps(steps),
			PackedStringArray([RUNNER.TOUCH_HOST_TINT, RUNNER.TOUCH_HOST_SCALE, RUNNER.TOUCH_TIME_SCALE, "post vignette"])]
	])


## The book, and the row that reads it back. Three values are moved after the beat recorded them,
## and Restore Moment Values puts all three where the game had them - which is what a level exiting
## asks for, long after the beat that moved them ended.
static func _restore_pins() -> bool:
	var was_scale: float = Engine.time_scale
	var behavior: Node = PACK.new()
	var stage: ColorRect = ColorRect.new()
	behavior.host = stage
	var steps: Array = [
		{"verb": "flash", "amount": 0.5, "effect": "white", "seconds": 0.0},
		{"verb": "punch", "amount": 0.3, "seconds": 0.0},
		{"verb": "slowmo", "amount": 0.4, "seconds": 0.0}
	]
	stage.modulate = Color(0.2, 0.4, 0.6, 1.0)
	stage.scale = Vector2(1.5, 1.5)
	Engine.time_scale = 1.0
	var play: Dictionary = _opened(behavior, "impact", steps)
	var recorded: PackedStringArray = PackedStringArray()
	for key: Variant in (play["start"] as Dictionary).keys():
		recorded.append(str(key))
	recorded.sort()
	# The beat has been felt: the three values are somewhere else now.
	stage.modulate = Color.WHITE
	stage.scale = Vector2(2.5, 2.5)
	Engine.time_scale = 0.25
	behavior.moment_restore_values("impact")
	var back: Array = [stage.modulate, stage.scale, Engine.time_scale]
	# And a second Restore of a name already put back does nothing rather than writing it twice.
	stage.modulate = Color.RED
	behavior.moment_restore_values("impact")
	var after_twice: Color = stage.modulate
	Engine.time_scale = was_scale
	behavior.free()
	stage.free()
	return SUPPORT.pins(TEST_NAME, [
		["the beat recorded the three values it was about to write", recorded,
			PackedStringArray([RUNNER.TOUCH_HOST_SCALE, RUNNER.TOUCH_HOST_TINT, RUNNER.TOUCH_TIME_SCALE])],
		["restore puts back the three it touched", back, [Color(0.2, 0.4, 0.6, 1.0), Vector2(1.5, 1.5), 1.0]],
		["a name already put back is not written over a second time", after_twice, Color.RED]
	])


## Skip To End lands on the values the beat would have finished on: time always ends unfrozen, and
## the things that come back by themselves end where they started. It says so twice - once as a
## skip, once as a finish - and the finish carries the flag a sheet asks with Moment Was Cut Short.
static func _skip_pins() -> bool:
	var was_scale: float = Engine.time_scale
	var behavior: Node = PACK.new()
	var stage: ColorRect = ColorRect.new()
	behavior.host = stage
	stage.modulate = Color(0.1, 0.2, 0.3, 1.0)
	Engine.time_scale = 1.0
	var steps: Array = [
		{"verb": "flash", "amount": 0.5, "effect": "white", "seconds": 0.4},
		{"verb": "slowmo", "amount": 0.4, "seconds": 0.4}
	]
	_opened(behavior, "intro", steps)
	var playing_before: bool = behavior.moment_is_playing("intro")
	stage.modulate = Color.WHITE
	Engine.time_scale = 0.3
	var said: Array = []
	behavior.moment_skipped.connect(func(named: String) -> void: said.append(["skipped", named]))
	behavior.moment_finished.connect(func(named: String, cut: bool) -> void: said.append(["finished", named, cut]))
	behavior.moment_skip_to_end("intro")
	var landed: Array = [stage.modulate, Engine.time_scale]
	var cut_short: bool = behavior.moment_was_cut_short("intro")
	var playing_after: bool = behavior.moment_is_playing("intro")
	Engine.time_scale = was_scale
	behavior.free()
	stage.free()
	return SUPPORT.pins(TEST_NAME, [
		["the beat was in the air before the skip", playing_before, true],
		["skip lands on the end values", landed, [Color(0.1, 0.2, 0.3, 1.0), 1.0]],
		["it says it was skipped, then that it finished cut short", said, [["skipped", "intro"], ["finished", "intro", true]]],
		["and the flag stays askable afterwards", cut_short, true],
		["the beat is no longer in the air", playing_after, false]
	])


## A revert walks each recorded value home over the beat's own length, and says it is reverting
## while it does. The frames are driven by hand, which is what a headless suite can do: the tick is
## arithmetic over a delta, so a whole revert is four calls rather than a clock.
static func _revert_pins() -> bool:
	var behavior: Node = PACK.new()
	var stage: ColorRect = ColorRect.new()
	behavior.host = stage
	stage.modulate = Color(0.0, 0.0, 0.0, 1.0)
	var steps: Array = [{"verb": "flash", "amount": 1.0, "effect": "white", "seconds": 0.4}]
	_opened(behavior, "hover", steps)
	# The beat has taken the tint somewhere else; the revert has to bring it back from THERE.
	stage.modulate = Color(1.0, 1.0, 1.0, 1.0)
	behavior.moment_revert("hover")
	var reverting: bool = behavior.moment_is_reverting("hover")
	behavior._process(0.2)
	var half_way: Color = stage.modulate
	behavior._process(0.2)
	var home: Color = stage.modulate
	var still_reverting: bool = behavior.moment_is_reverting("hover")
	var cut_short: bool = behavior.moment_was_cut_short("hover")
	var parked: bool = behavior.is_processing()
	behavior.free()
	stage.free()
	return SUPPORT.pins(TEST_NAME, [
		["a reverting beat says so", reverting, true],
		["half way home is half way back", half_way, Color(0.5, 0.5, 0.5, 1.0)],
		["revert returns to the start value", home, Color(0.0, 0.0, 0.0, 1.0)],
		["and it is not reverting once it is home", still_reverting, false],
		["a reverted beat finished cut short", cut_short, true],
		["the tick parks once nothing is left in the air", parked, false]
	])


## The four signals, in the order a play says them, with the step labels a sheet reads. Backwards
## is the same beat said from the bottom, which is the whole of Play Moment Backwards.
static func _signal_pins() -> bool:
	var behavior: Node = PACK.new()
	var stage: ColorRect = ColorRect.new()
	behavior.host = stage
	var steps: Array = [
		{"verb": "shake", "label": "first", "amount": 0.2, "seconds": 0.0},
		{"verb": "shake", "label": "second", "amount": 0.2, "seconds": 0.0},
		{"verb": "shake", "label": "third", "amount": 0.2, "seconds": 0.0}
	]
	behavior.define_moment("cue", _moment_file("cue", steps))
	var said: Array = []
	behavior.moment_started.connect(func(named: String) -> void: said.append("started %s" % named))
	behavior.moment_stepped.connect(func(named: String, label: String) -> void: said.append(label))
	behavior.moment_finished.connect(func(named: String, cut: bool) -> void: said.append("finished %s" % str(cut)))
	behavior.moment("cue", 1.0)
	var forwards: Array = said.duplicate()
	said.clear()
	behavior.moment_backwards("cue", 1.0)
	var backwards: Array = said.duplicate()
	var named_step: String = behavior.moment_step_name("cue")
	# A beat that HAS a length stays in the air, so firing it again has a play to close: the sheet
	# must hear the first one finish, cut short, before it hears the second one start.
	said.clear()
	behavior.define_moment("held", _moment_file("held", [{"verb": "shake", "label": "one", "amount": 0.2, "seconds": 0.5}]))
	behavior.moment("held", 1.0)
	behavior.moment("held", 1.0)
	var retriggered: Array = said.duplicate()
	# The name book a Define Moment writes is shared by every Juice node in the process, so a test
	# that defines one takes it away again rather than leaving it for the next test to find.
	behavior.define_moment("cue", null)
	behavior.define_moment("held", null)
	behavior.free()
	stage.free()
	return SUPPORT.pins(TEST_NAME, [
		["a beat says it started, names each step, then says it finished whole",
			forwards, ["started cue", "first", "second", "third", "finished false"]],
		["backwards is the same beat said from the bottom",
			backwards, ["started cue", "third", "second", "first", "finished false"]],
		["a beat that is over names no step", named_step, ""],
		["a beat fired again closes the one still in the air, cut short",
			retriggered, ["started held", "one", "finished true", "started held", "one"]]
	])


## THE CLAMP HOLDS ON EVERY PATH. A player who asked for no flashing gets the same beat backwards
## as forwards: the amounts a step feeds the pack are held under the ceiling and the times over the
## floor, because both walks go through the one function that applies them.
static func _clamp_pins() -> bool:
	var had: bool = Engine.has_meta(NO_FLASHING)
	var was: Variant = Engine.get_meta(NO_FLASHING) if had else null
	var behavior: Node = PACK.new()
	var stage: ColorRect = ColorRect.new()
	behavior.host = stage
	var steps: Array = [{"verb": "shake", "amount": 1.0, "seconds": 0.01}]
	behavior.define_moment("hit", _moment_file("hit", steps))
	Engine.set_meta(NO_FLASHING, true)
	behavior.moment_backwards("hit", 1.0)
	var backwards_trauma: float = behavior.current_trauma()
	behavior.stop_shake()
	behavior.moment("hit", 1.0)
	var forwards_trauma: float = behavior.current_trauma()
	if had:
		Engine.set_meta(NO_FLASHING, was)
	else:
		Engine.remove_meta(NO_FLASHING)
	behavior.define_moment("hit", null)
	behavior.free()
	stage.free()
	return SUPPORT.pins(TEST_NAME, [
		["a backwards beat is held to the ceiling", is_equal_approx(backwards_trauma, RUNNER.FLASH_CEILING), true],
		["and a forwards one to the same ceiling", is_equal_approx(forwards_trauma, RUNNER.FLASH_CEILING), true]
	])


## Opens a play on the behaviour and hands back the book it wrote. It opens the beat WITHOUT
## letting the steps fire, because a flash and a punch drive a Tween and a Tween needs a live
## scene tree - and what these pins are about is the book, the end values and the walk home, all
## of which are written before a single step has run.
static func _opened(behavior: Node, named: String, steps: Array) -> Dictionary:
	behavior._moment_begin(named, steps, 1.0, false)
	return behavior._moment_plays.get(named, {})


## A moment FILE holding these steps - the shape Moment reads, built here rather than loaded so a
## test never depends on the six starters a game is meant to edit.
static func _moment_file(named: String, steps: Array) -> Resource:
	var file: MomentResource = MomentResource.new()
	file.moment_name = named
	var typed: Array[Dictionary] = []
	for step: Variant in steps:
		typed.append(step as Dictionary)
	file.steps = typed
	return file
