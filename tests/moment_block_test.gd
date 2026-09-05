# The Moment block: a beat of feedback written as ROWS - a timing word per step on the left, any
# actions on the right - compiling to ONE coroutine on the host, and reading back out of a
# hand-written script as the same block.
#
# What is pinned here, and why each one is a value rather than a count:
#   the emission     the whole coroutine, letter for letter, because the shape IS the public
#                    contract: it is what the lift matches and what a reader of the .gd sees.
#   the Hold         the number a Hold waits, which is the durations the rows above declared
#                    folded into one - the arithmetic no other test can see.
#   the round trip   the block re-opened out of its own emitted text, step for step, and the
#                    file re-emitted byte for byte.
#   the spellings    the same moment written three ways - the emitter's own, one with the commas
#                    tight, one with a space too many - because a wait this reader cannot claim
#                    must refuse the whole block rather than keep the wait as ordinary code.
#   the live block   which block a step is added to after an edit has replaced the sheet's rows
#                    with duplicates: the one in the sheet, never the one the right-click held.
#   the loop         a Loop Back as a `for` around the stretch since the last Hold, and the count.
#   the runner       the strength maths every home of a moment shares: what an amount becomes at a
#                    strength, what it may become while no flashing is on, and how much of it
#                    survives a distance.
@tool
class_name MomentBlockTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const RUNNER := preload("res://eventsheet_addons/juice/moment_runner.gd")
const PREFIX := "moment_block_test"

## Where a game keeps the beats it wrote itself. Named once here, and asked of both the door that
## suggests it and the pack that looks in it, so the two can never drift apart.
const JUICE_PROJECT_MOMENTS: String = "res://moments/"

## The fixture moment, as the file holds it. Written out in full because every other pin in this
## file is measured against it.
const IMPACT_TEXT: String = """func moment_impact(strength: float = 1.0, from: Node = null) -> void:
	shake(0.4 * strength)
	hitstop()
	await MomentRunner.at(self, 0.05, "game")
	play_sound()
	await MomentRunner.hold(self, 0.3, 0.1, "game")
	tween_scale(1.0, 0.2)"""

## The same moment with a place and a range: one line at the top turns the play's strength into
## the strength it really has here, and the distance is measured ONCE per play.
const RANGED_TEXT: String = """func moment_blast(strength: float = 1.0, from: Node = null) -> void:
	strength = MomentRunner.strength_at(self, strength, from, 600.0, "smooth")
	shockwave(strength)"""

## A loop: everything since the last Hold runs again, the count being how many EXTRA passes.
const LOOPED_TEXT: String = """func moment_pulse(strength: float = 1.0, from: Node = null) -> void:
	a()
	for _moment_loop: int in 3:
		await MomentRunner.hold(self, 0.0, 0.0, "game")
		b()
		await MomentRunner.then(self, 0.1, "game")
		c()"""

## A loop whose head is a Hold, over a step above that lasts. The fold the Hold exists for is the
## steps ABOVE the loop, so the first pass waits for them and every pass keeps that pace.
const LOOPED_HOLD_TEXT: String = """func moment_throb(strength: float = 1.0, from: Node = null) -> void:
	a()
	for _moment_loop: int in 2:
		await MomentRunner.hold(self, 0.3, 0.1, "game")
		b()"""

## The two steps a moment FILE holds, in the order and the spelling a file writes them.
const FILE_STEPS: Array = [
	{"amount": 0.45, "effect": "", "seconds": 0.0, "verb": "shake"},
	{"amount": 0.0, "effect": "", "seconds": 0.06, "verb": "hitstop"}
]

## And the block those two steps open as: every step at the start, because that is what a file
## means, each one the single row that plays it.
const FILE_BLOCK_TEXT: String = """func moment_Boss_Hit(strength: float = 1.0, from: Node = null) -> void:
	$JuiceBehavior.moment_step("shake", 0.45, "", 0.0, strength)
	$JuiceBehavior.moment_step("hitstop", 0.0, "", 0.06, strength)"""

## What a moment built by the three authoring gestures compiles to, once its middle step has
## been taken off again: one shake, and the whole stretch three more times. Nothing in the stretch
## waits, so the four passes happen in the one frame - which is what those rows say.
const AUTHORED_TEXT: String = """func moment_Boss_Hit(strength: float = 1.0, from: Node = null) -> void:
	for _moment_loop: int in 4:
		shake(0.4 * strength)"""

## Where the round trip through a real file happens. Taken away again at the end of the section.
const FILE_PATH: String = "user://moment_block_test_boss_hit.tres"

## The pack whose row plays one step of a moment, loaded by path: a test that names a class the
## class cache has not caught up with fails for the wrong reason.
const JUICE_SCRIPT: String = "res://eventsheet_addons/juice/juice_behavior.gd"

## The scripts the compiles and round trips below write. Named once and used at both the
## compile and the clean-up, so the two cannot drift apart.
const COMPILED: Array[String] = [
	"user://moment_block_test.gd", "user://moment_range_test.gd", "user://moment_loop_test.gd",
	"user://moment_bridge_test.gd", "user://moment_authored_test.gd",
	"user://moment_loop_hold_test.gd", "user://moment_spelling_test.gd",
]

## The wait the three spellings below differ in, and the two respellings of it. Each is a whole
## file's one line changed: the emitter's own, the same call with its commas tight, and the same
## call with a space too many. Both respellings are this grammar's own sentence in a spelling the
## reader cannot claim.
const CANONICAL_WAIT: String = "await MomentRunner.at(self, 0.05, \"game\")"
const TIGHT_WAIT: String = "await MomentRunner.at(self,0.05,\"game\")"
const SPACED_WAIT: String = "await MomentRunner.at(self,  0.05, \"game\")"


static func run() -> bool:
	var passed: bool = true
	passed = _pin_the_emission() and passed
	passed = _pin_the_round_trip() and passed
	passed = _pin_the_three_spellings() and passed
	passed = _pin_the_loop() and passed
	passed = _pin_the_hold_that_opens_a_loop() and passed
	passed = _pin_the_strength() and passed
	passed = _pin_the_range() and passed
	passed = _pin_the_file_bridge() and passed
	passed = _pin_the_two_homes() and passed
	passed = _pin_the_block_beats_book() and passed
	passed = _pin_the_authoring() and passed
	passed = _pin_the_live_block_a_step_lands_on() and passed
	_cleanup()
	return passed


## Everything this test wrote. A compile writes to where it is told to compile, so each round trip
## leaves a script in the user folder - and on CI the whole suite runs serially in one process, so
## what one test leaves behind is state the next one sees.
static func _cleanup() -> void:
	for path: String in COMPILED:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


## The coroutine a block compiles to, by value - and the same text twice, because emission being
## deterministic is a contract and not an accident.
static func _pin_the_emission() -> bool:
	var sheet: EventSheetResource = _sheet_with(_impact_block())
	var once: String = _function_text(SUPPORT.compile_output(sheet, "user://moment_block_test.gd"))
	var twice: String = _function_text(SUPPORT.compile_output(sheet, "user://moment_block_test.gd"))
	var ranged: EventSheetResource = _sheet_with(_ranged_block())
	return SUPPORT.pins(PREFIX, [
		["the moment compiles to one coroutine", once, IMPACT_TEXT],
		["emission is deterministic", twice, once],
		["a range is one line at the top", _function_text(SUPPORT.compile_output(ranged, "user://moment_range_test.gd")), RANGED_TEXT],
		# The Hold's first number is the fold: the step above started at 0.05 and lasts 0.3, so
		# 0.3 of it is still to run when the Hold is reached. Its second is the Hold's own delay.
		["the Hold waits for the slowest step above", once.contains("hold(self, 0.3, 0.1, \"game\")"), true],
	])


## The block out of its own emitted text: every step back, and the file byte for byte.
static func _pin_the_round_trip() -> bool:
	var source: String = SUPPORT.compile_output(_sheet_with(_impact_block()), "user://moment_block_test.gd")
	var reopened: EventSheetResource = SUPPORT.reopen(source, true, "user://moment_block_test.gd")
	var block: MomentBlockRow = _first_block(reopened)
	var rows: Array = []
	if block != null:
		for step: MomentStepRow in block.live_steps():
			rows.append("%s|%s" % [step.reading(), _statements(step)])
	return SUPPORT.pins(PREFIX, [
		["the coroutine reads back as a block", block != null, true],
		["the block keeps its name", block.moment_name if block != null else "", "impact"],
		["every step reads back", rows, [
			"At 0 s|shake(0.4 * strength);hitstop()",
			"At 0.05 s|play_sound()",
			"Hold, then 0.1 s|tween_scale(1.0, 0.2)",
		]],
		# The duration the emitter folded into the Hold's line is put back where it came from.
		["the step's duration comes back with it", String.num(block.live_steps()[1].lasts, 4) if block != null else "", "0.3"],
		["the file re-emits byte for byte", SUPPORT.reemit(source, "user://moment_block_test.gd"), source],
	])


## THREE SPELLINGS OF ONE MOMENT, each a whole file through the importer. The emitter's own opens
## as the block it always did. A wait respelled - commas tight, or a space too many - is this
## grammar's own sentence in a form this reader cannot claim, and the whole block is refused: the
## function stays the plain function it reads as, and the file re-emits byte for byte. Before the
## refusal the block lifted anyway, because a statement nobody read is written straight back out:
## the byte gate passed while the sheet showed a step reading "At 0 s" whose actions held a literal
## await line, and the schedule was worked out as though those waits were not there.
static func _pin_the_three_spellings() -> bool:
	var canonical: String = SUPPORT.compile_output(_sheet_with(_impact_block()),
		"user://moment_spelling_test.gd")
	var tight: String = canonical.replace(CANONICAL_WAIT, TIGHT_WAIT)
	var spaced: String = canonical.replace(CANONICAL_WAIT, SPACED_WAIT)
	var opened: EventSheetResource = SUPPORT.reopen(canonical, true, "user://moment_spelling_test.gd")
	var tight_open: EventSheetResource = SUPPORT.reopen(tight, true, "user://moment_spelling_test.gd")
	var spaced_open: EventSheetResource = SUPPORT.reopen(spaced, true, "user://moment_spelling_test.gd")
	var block: MomentBlockRow = _first_block(opened)
	var readings: Array = []
	if block != null:
		for step: MomentStepRow in block.live_steps():
			readings.append(step.reading())
	return SUPPORT.pins(PREFIX, [
		# The respellings are the emitted file with one line changed, so the pins below are three
		# readings of the same moment rather than three different moments.
		["the emitter writes the wait one way", _function_text(canonical).contains(CANONICAL_WAIT), true],
		["the tight spelling is that file with the one line respelled",
			_function_text(tight).contains(TIGHT_WAIT), true],
		["and the spaced spelling likewise", _function_text(spaced).contains(SPACED_WAIT), true],
		["the emitter's own spelling opens as a moment block", _row_kinds(opened),
			["raw", "raw", "moment"]],
		["with the step readings it always had", readings,
			["At 0 s", "At 0.05 s", "Hold, then 0.1 s"]],
		["and the file holds no ordinary function of that name", _plain_function_names(opened), []],
		["a comma-tight wait is no moment block at all", _row_kinds(tight_open), ["raw", "raw"]],
		["it stays the plain function it reads as", _plain_function_names(tight_open),
			["moment_impact"]],
		["and that file re-emits byte for byte",
			SUPPORT.reemit(tight, "user://moment_spelling_test.gd"), tight],
		["a wait with a space too many is no moment block either", _row_kinds(spaced_open),
			["raw", "raw"]],
		["it too stays the plain function it reads as", _plain_function_names(spaced_open),
			["moment_impact"]],
		["and that file re-emits byte for byte too",
			SUPPORT.reemit(spaced, "user://moment_spelling_test.gd"), spaced],
	])


## A Loop Back: the `for` around the stretch since the last Hold, the count on it, and the whole
## thing surviving a round trip as a Loop Back row again.
static func _pin_the_loop() -> bool:
	var source: String = SUPPORT.compile_output(_sheet_with(_looped_block()), "user://moment_loop_test.gd")
	var reopened: EventSheetResource = SUPPORT.reopen(source, true, "user://moment_loop_test.gd")
	var block: MomentBlockRow = _first_block(reopened)
	var readings: Array = []
	if block != null:
		for step: MomentStepRow in block.live_steps():
			readings.append(step.reading())
	return SUPPORT.pins(PREFIX, [
		["a Loop Back is a for around the stretch", _function_text(source), LOOPED_TEXT],
		["the loop reads back with its count", readings, ["At 0 s", "Hold", "Then 0.1 s", "Loop back 2 x"]],
		["a looped moment re-emits byte for byte", SUPPORT.reemit(source, "user://moment_loop_test.gd"), source],
	])


## A Hold at the head of a looped stretch: the step above the loop declares a duration, and the
## Hold waits for it. The number rides the emitted line, so the way back puts it on the step
## OUTSIDE the loop and the file re-emits letter for letter.
static func _pin_the_hold_that_opens_a_loop() -> bool:
	var source: String = SUPPORT.compile_output(_sheet_with(_looped_hold_block()), "user://moment_loop_hold_test.gd")
	var reopened: EventSheetResource = SUPPORT.reopen(source, true, "user://moment_loop_hold_test.gd")
	var block: MomentBlockRow = _first_block(reopened)
	var lasts: String = String.num(block.live_steps()[0].lasts, 4) if block != null else ""
	return SUPPORT.pins(PREFIX, [
		["a Hold opening a loop keeps the wait for the steps above", _function_text(source), LOOPED_HOLD_TEXT],
		["that duration comes back on the step outside the loop", lasts, "0.3"],
		["and the file re-emits byte for byte", SUPPORT.reemit(source, "user://moment_loop_hold_test.gd"), source],
	])


## What an amount becomes: scaled by the play's strength, and held under the ceiling while a
## player has asked for no flashing. The meta this sets is put back exactly as it was found.
static func _pin_the_strength() -> bool:
	var had: bool = Engine.has_meta(RUNNER.NO_FLASHING_META)
	var was: Variant = Engine.get_meta(RUNNER.NO_FLASHING_META, false)
	var quiet: String = ""
	Engine.set_meta(RUNNER.NO_FLASHING_META, true)
	quiet = String.num(RUNNER.scaled(1.0, 1.0), 4)
	if had:
		Engine.set_meta(RUNNER.NO_FLASHING_META, was)
	else:
		Engine.remove_meta(RUNNER.NO_FLASHING_META)
	return SUPPORT.pins(PREFIX, [
		["half strength halves the amount", String.num(RUNNER.scaled(0.4, 0.5), 4), "0.2"],
		["full strength leaves it alone", String.num(RUNNER.scaled(0.4, 1.0), 4), "0.4"],
		["a negative strength cannot invert it", String.num(RUNNER.scaled(0.4, -2.0), 4), "0.0"],
		["no flashing holds it under the ceiling", quiet, "0.3"],
		["and the meta is put back", Engine.has_meta(RUNNER.NO_FLASHING_META), had],
	])


## How much of the strength survives a distance, at three of them plus the edge.
static func _pin_the_range() -> bool:
	return SUPPORT.pins(PREFIX, [
		["at the place itself, all of it", String.num(RUNNER.falloff_factor(0.0, 600.0, "linear"), 4), "1.0"],
		["a quarter out, three quarters left", String.num(RUNNER.falloff_factor(150.0, 600.0, "linear"), 4), "0.75"],
		["half way out, half left", String.num(RUNNER.falloff_factor(300.0, 600.0, "linear"), 4), "0.5"],
		["at the edge, nothing", String.num(RUNNER.falloff_factor(600.0, 600.0, "linear"), 4), "0.0"],
		["past the edge, still nothing", String.num(RUNNER.falloff_factor(900.0, 600.0, "linear"), 4), "0.0"],
		# Smooth rounds the shoulders, so a near impact keeps more of itself than the line gives it.
		["smooth holds the near ground", String.num(RUNNER.falloff_factor(150.0, 600.0, "smooth"), 4), "0.8438"],
		["none holds full strength to the edge", String.num(RUNNER.falloff_factor(599.0, 600.0, "none"), 4), "1.0"],
		["no range at all is no falloff", String.num(RUNNER.falloff_factor(9999.0, 0.0, "linear"), 4), "1.0"],
	])


## THE TWO WRITTEN-DOWN HOMES, in both directions. A file opens as a block whose steps all start
## together and each play one step; a block of exactly that shape saves back as the same steps. And
## a block a file CANNOT hold says which rows it cannot hold, rather than dropping them.
static func _pin_the_file_bridge() -> bool:
	var opened: MomentBlockRow = EventSheetMomentFile.block_of("Boss Hit", FILE_STEPS)
	var text: String = _function_text(SUPPORT.compile_output(_sheet_with(opened),
		"user://moment_bridge_test.gd"))
	var back: Dictionary = EventSheetMomentFile.steps_of(opened)
	var refused: Dictionary = EventSheetMomentFile.steps_of(_impact_block())
	var wrote: Dictionary = EventSheetMomentFileDoor.save_run(opened, FILE_PATH)
	var read: Dictionary = EventSheetMomentFileDoor.open_run(FILE_PATH)
	var reopened: MomentBlockRow = read.get("block") as MomentBlockRow
	var rows: Array = [
		["a file opens as a block whose steps all start together", text, FILE_BLOCK_TEXT],
		["a name with a space in it becomes one a function can carry", opened.moment_name, "Boss_Hit"],
		["the same block saves back as the same steps", str(back.get("steps", [])), str(FILE_STEPS)],
		["and leaves nothing behind", str(back.get("left_behind", PackedStringArray())), "[]"],
		# A file has no timing and no verb outside the ten, so the fixture block's Hold and its
		# hand-written statements are exactly what it cannot hold - named, not dropped.
		["a block a file cannot hold names the rows it cannot", str(refused.get("left_behind", PackedStringArray())),
			str(PackedStringArray(["At 0 s", "At 0.05 s", "Hold, then 0.1 s"]))],
		["and carries none of them", str(refused.get("steps", [])), "[]"],
		["the door writes the file", bool(wrote.get("ok", false)), true],
		["and says what it wrote", str(wrote.get("said", "")), "moment_block_test_boss_hit.tres written - 2 step(s)."],
		["the door reads it back as a block", reopened != null, true],
		["with the steps it went in with", str(EventSheetMomentFile.steps_of(reopened).get("steps", []) if reopened != null else []), str(FILE_STEPS)],
		["a file that is not there is said so rather than guessed at",
			bool(EventSheetMomentFileDoor.open_run("user://no_such_moment.tres").get("ok", true)), false],
		# Where a saved beat is offered: a folder of the GAME's, never the pack folder a rebuild
		# regenerates - and the pack looks in that folder first, so a file saved where the door
		# suggests is found by the name it was saved under.
		["a saved moment is offered a folder of the game's own",
			EventSheetMomentFileDoor.SUGGESTED_DIRECTORY, JUICE_PROJECT_MOMENTS],
		["and the pack looks there before its own",
			(load(JUICE_SCRIPT) as GDScript).get_script_constant_map()["PROJECT_MOMENT_DIRECTORY"],
			JUICE_PROJECT_MOMENTS]
	]
	if FileAccess.file_exists(FILE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(FILE_PATH))
	rows.append(["and the file the test wrote is taken away with it", FileAccess.file_exists(FILE_PATH), false])
	return SUPPORT.pins(PREFIX, rows)


## ONE ROW, EITHER HOME. The Moment row plays a beat written as a block on the host exactly as
## readily as one kept in a file, and the no-flashing ceiling both are held to is one number in one
## place - the runner's - rather than two that can drift.
static func _pin_the_two_homes() -> bool:
	var juice: Node = (load(JUICE_SCRIPT) as GDScript).new()
	var written := GDScript.new()
	written.source_code = ("extends Node2D\n\n\nvar played: Array = []\n\n\n"
		+ "func moment_impact(strength: float = 1.0, from: Node = null) -> void:\n"
		+ "\tplayed.append([strength, from])\n")
	written.reload()
	var host: Node2D = Node2D.new()
	host.set_script(written)
	juice.host = host
	juice.moment("impact", 0.5)
	var rows: Array = [
		["a moment written as rows on the host is played by the Moment row", str(host.played), str([[0.5, null]])],
		["a name the host does not answer to falls through to the file",
			juice._play_moment_block("kill", 1.0), false],
		["a name that is no identifier at all is nobody's block",
			juice._play_moment_block("not a name!", 1.0), false],
		["a moment named with spaces finds the block written with underscores",
			juice._play_moment_block(" impact ", 0.25), true],
		["the ceiling a step is held under is the runner's own number",
			juice.MOMENT_FLASH_CEILING, RUNNER.FLASH_CEILING],
		["and so is the floor its time is held over",
			juice.MOMENT_FLASH_FLOOR_SECONDS, RUNNER.FLASH_FLOOR_SECONDS],
		["one step of a moment is a row of its own", juice.has_method("moment_step"), true]
	]
	juice.moment_step("shake", 0.4, "", 0.0, 0.5)
	rows.append(["and it plays the step at the strength it was given", String.num(juice.trauma, 4), "0.2"])
	host.free()
	juice.free()
	return SUPPORT.pins(PREFIX, rows)


## THE BOOK A BLOCK BEAT OPENS. A moment written as rows is a coroutine on the host, and it used to
## be played without the runner being told - so On Moment Started, On Moment Finished and Moment Is
## Playing were silent for it while they answered for the same beat written as a file. And a Play
## Moment Backwards on a block's name quietly played the FILE of that name instead, which is a
## different beat wearing the right word.
static func _pin_the_block_beats_book() -> bool:
	var juice: Node = (load(JUICE_SCRIPT) as GDScript).new()
	var written := GDScript.new()
	written.source_code = ("extends Node2D


var played: Array = []


"
		+ "func moment_impact(strength: float = 1.0, from: Node = null) -> void:
"
		+ "	played.append([strength, from])
")
	written.reload()
	var host: Node2D = Node2D.new()
	host.set_script(written)
	juice.host = host
	var said: Array = []
	juice.moment_started.connect(func(named: String) -> void: said.append("started " + named))
	juice.moment_finished.connect(func(named: String, cut: bool) -> void: said.append("finished " + named + (" cut" if cut else "")))
	juice.moment("impact", 1.0)
	var backwards: Array = []
	juice.moment_started.connect(func(named: String) -> void: backwards.append(named))
	juice.moment_backwards("impact", 1.0)
	var rows: Array = [
		["a beat written as rows says it started and finished", said, ["started impact", "finished impact"]],
		["and the host played it once", host.played.size(), 1],
		["a backwards play of a block plays no other beat of that name", backwards, []],
		["and the host is not asked to play it forwards instead", host.played.size(), 1],
	]
	host.free()
	juice.free()
	return SUPPORT.pins(PREFIX, rows)


## AUTHORING A MOMENT, which is three gestures and no widget: start one, add a step, take a step
## off. Each is a value here rather than a click, because the door hands the same functions to the
## dock's undo funnel that this pins.
static func _pin_the_authoring() -> bool:
	var block: MomentBlockRow = MomentBlockRow.new()
	block.moment_name = EventSheetMomentFile.identifier_of(" Boss Hit ")
	EventSheetMomentFileDoor.step_added(block, MomentStepRow.TIMING_AT, 0.0, "shake(0.4 * strength)")
	EventSheetMomentFileDoor.step_added(block, MomentStepRow.TIMING_THEN, 0.2, "play_sound()")
	EventSheetMomentFileDoor.step_added(block, MomentStepRow.TIMING_LOOP_BACK, 3.0, "")
	var readings: Array = []
	for step: MomentStepRow in block.live_steps():
		readings.append(step.reading())
	var sheet: EventSheetResource = _sheet_with(block)
	var second: MomentStepRow = block.live_steps()[1]
	var stray: MomentStepRow = MomentStepRow.new()
	var rows: Array = [
		["a name typed with spaces becomes one a function can carry", block.moment_name, "Boss_Hit"],
		["a name that is nothing but punctuation is refused rather than mangled",
			EventSheetMomentFile.identifier_of("!!!"), ""],
		["a digit cannot start one, and does not have to be dropped from the middle",
			EventSheetMomentFile.identifier_of("2nd hit"), "nd_hit"],
		["the three steps read in the words the sheet draws", readings,
			["At 0 s", "Then 0.2 s", "Loop back 3 x"]],
		["a step knows which block it belongs to",
			EventSheetMomentFile.owner_of(sheet, second) == block, true],
		["and a step no block holds belongs to none",
			EventSheetMomentFile.owner_of(sheet, stray) == null, true],
		["taking a step nobody holds off changes nothing",
			EventSheetMomentFileDoor.step_removed(block, stray), false]
	]
	EventSheetMomentFileDoor.step_removed(block, second)
	var left: Array = []
	for step: MomentStepRow in block.live_steps():
		left.append(step.reading())
	rows.append(["and taking a real one off leaves the rest in order", left,
		["At 0 s", "Loop back 3 x"]])
	rows.append(["the moment authored this way compiles like any other",
		_function_text(SUPPORT.compile_output(sheet, "user://moment_authored_test.gd")),
		AUTHORED_TEXT])
	return SUPPORT.pins(PREFIX, rows)


## WHICH BLOCK A STEP LANDS ON. Every committed edit replaces the sheet's resources with snapshot
## duplicates, so the block a right-click handed the step form is an orphan by the time the form is
## confirmed - and a step appended to an orphan is a step nobody ever sees, reported as "Step
## added." The form therefore finds the block again in the LIVE sheet: by the name it was opened
## on, else by its place among the sheet's Moment blocks, and null when neither finds it.
static func _pin_the_live_block_a_step_lands_on() -> bool:
	var dock: Control = _stub_dock()
	var door: EventSheetMomentFileDoor = EventSheetMomentFileDoor.new()
	door.init(dock)
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	var impact: MomentBlockRow = _impact_block()
	var blast: MomentBlockRow = _ranged_block()
	sheet.events.append(impact)
	sheet.events.append(blast)
	dock._current_sheet = sheet
	# What open_step remembers, spelled the way open_step spells it - the block object included,
	# because the point of the pins below is that the object is the one thing that goes stale.
	door._block = impact
	door._step_block_name = impact.moment_name
	door._step_block_place = door._place_of_block(impact)
	var places: Array = [door._place_of_block(impact), door._place_of_block(blast),
		door._place_of_block(MomentBlockRow.new())]
	# The edit: the sheet the dock holds is now a deep duplicate, and every row in it is a new
	# object. The block the form was opened on is an orphan from here on.
	var live: EventSheetResource = sheet.duplicate(true)
	dock._current_sheet = live
	var found: MomentBlockRow = door._live_step_block()
	# The name has moved on since the form was opened, so the place is what is left to go on.
	door._step_block_name = "renamed_since"
	door._step_block_place = 1
	var by_place: MomentBlockRow = door._live_step_block()
	var bare: EventSheetResource = EventSheetResource.new()
	bare.host_class = "Node2D"
	dock._current_sheet = bare
	var gone: MomentBlockRow = door._live_step_block()
	var rows: Array = [
		["a block's place is where it sits among the sheet's Moment blocks", places, [0, 1, -1]],
		["the block found after the snapshot is the one of that name",
			found.moment_name if found != null else "", "impact"],
		["and it is the sheet's own row", found == live.events[0], true],
		["never the orphan the right-click handed over", found == impact, false],
		["a name that no longer matches falls back to the block's place",
			by_place.moment_name if by_place != null else "", "blast"],
		["and that too is the sheet's own row", by_place == live.events[1], true],
		["a sheet with no Moment block left finds none", gone == null, true],
	]
	# The form itself, driven with the fields the dialog would have filled in - and still holding
	# the orphan the right-click gave it.
	dock._current_sheet = live
	door._block = impact
	door._step_block_name = "impact"
	door._step_block_place = 0
	var timing: OptionButton = OptionButton.new()
	for word: String in EventSheetMomentFileDoor.TIMING_WORDS:
		timing.add_item(EventSheetMomentFileDoor.TIMING_WORDS[word])
	timing.select(0)
	var number: LineEdit = LineEdit.new()
	number.text = "0.05"
	var code: LineEdit = LineEdit.new()
	code.text = "play_sound()"
	door._step_timing = timing
	door._step_number = number
	door._step_code = code
	door._apply_step()
	var landed: Array = []
	for step: MomentStepRow in (live.events[0] as MomentBlockRow).live_steps():
		landed.append("%s|%s" % [step.reading(), _statements(step)])
	var orphaned: Array = []
	for step: MomentStepRow in impact.live_steps():
		orphaned.append(step.reading())
	rows.append(["the step lands on the live block", landed, [
		"At 0 s|shake(0.4 * strength);hitstop()",
		"At 0.05 s|play_sound()",
		"Hold, then 0.1 s|tween_scale(1.0, 0.2)",
		"At 0.05 s|play_sound()",
	]])
	rows.append(["and nothing was appended to the orphan", orphaned,
		["At 0 s", "At 0.05 s", "Hold, then 0.1 s"]])
	rows.append(["and the form says so", dock.said, "Step added."])
	rows.append(["without calling it a failure", dock.was_error, false])
	# The block genuinely gone: a failure said out loud, and nothing added anywhere.
	dock._current_sheet = bare
	door._block = impact
	door._step_block_name = "impact"
	door._step_block_place = 0
	door._apply_step()
	rows.append(["a block that is gone is said so rather than appended to", dock.said,
		"That Moment block is no longer in the sheet, so the step was not added."])
	rows.append(["and that is a failure", dock.was_error, true])
	rows.append(["and the sheet gained no block to hold it", _first_block(bare) == null, true])
	timing.free()
	number.free()
	code.free()
	dock.free()
	return SUPPORT.pins(PREFIX, rows)


## A dock the two step-form helpers can be asked their questions through: the sheet they read, the
## funnel they commit through, and the status line they answer on. Built from source rather than
## from the real dock, which needs an editor around it - these two helpers only ever ask the dock
## for its current sheet.
static func _stub_dock() -> Control:
	var script := GDScript.new()
	script.source_code = ("extends Control\n\n\nvar _current_sheet: Resource = null\n"
		+ "var said: String = \"\"\nvar was_error: bool = false\n\n\n"
		+ "func _set_status(text: String, error: bool = false) -> void:\n"
		+ "\tsaid = text\n\twas_error = error\n\n\n"
		+ "func _perform_undoable_sheet_edit(_action_name: String, operation: Callable) -> bool:\n"
		+ "\tif _current_sheet == null:\n\t\treturn false\n\treturn bool(operation.call())\n")
	script.reload()
	var dock: Control = Control.new()
	dock.set_script(script)
	return dock


## The fixture block: three steps, the middle one lasting long enough for the Hold to have
## something to wait for.
static func _impact_block() -> MomentBlockRow:
	var block: MomentBlockRow = MomentBlockRow.new()
	block.moment_name = "impact"
	block.steps.append(_step(MomentStepRow.TIMING_AT, 0.0, 0.0, ["shake(0.4 * strength)", "hitstop()"]))
	block.steps.append(_step(MomentStepRow.TIMING_AT, 0.05, 0.3, ["play_sound()"]))
	block.steps.append(_step(MomentStepRow.TIMING_HOLD, 0.1, 0.0, ["tween_scale(1.0, 0.2)"]))
	return block


## The same idea with somewhere to happen and a distance to fall off over.
static func _ranged_block() -> MomentBlockRow:
	var block: MomentBlockRow = MomentBlockRow.new()
	block.moment_name = "blast"
	block.within = 600.0
	block.falloff = MomentBlockRow.FALLOFF_SMOOTH
	block.steps.append(_step(MomentStepRow.TIMING_AT, 0.0, 0.0, ["shockwave(strength)"]))
	return block


## A stretch that runs three times in all: once, then two more.
static func _looped_block() -> MomentBlockRow:
	var block: MomentBlockRow = MomentBlockRow.new()
	block.moment_name = "pulse"
	block.steps.append(_step(MomentStepRow.TIMING_AT, 0.0, 0.0, ["a()"]))
	block.steps.append(_step(MomentStepRow.TIMING_HOLD, 0.0, 0.0, ["b()"]))
	block.steps.append(_step(MomentStepRow.TIMING_THEN, 0.1, 0.0, ["c()"]))
	var closer: MomentStepRow = MomentStepRow.new()
	closer.timing = MomentStepRow.TIMING_LOOP_BACK
	closer.loop_count = 2
	block.steps.append(closer)
	return block


## A stretch headed by a Hold, over a step that lasts a third of a second.
static func _looped_hold_block() -> MomentBlockRow:
	var block: MomentBlockRow = MomentBlockRow.new()
	block.moment_name = "throb"
	block.steps.append(_step(MomentStepRow.TIMING_AT, 0.0, 0.3, ["a()"]))
	block.steps.append(_step(MomentStepRow.TIMING_HOLD, 0.1, 0.0, ["b()"]))
	var closer: MomentStepRow = MomentStepRow.new()
	closer.timing = MomentStepRow.TIMING_LOOP_BACK
	closer.loop_count = 1
	block.steps.append(closer)
	return block


static func _step(timing: String, seconds: float, lasts: float, code: Array) -> MomentStepRow:
	var step: MomentStepRow = MomentStepRow.new()
	step.timing = timing
	step.seconds = seconds
	step.lasts = lasts
	for line: Variant in code:
		var raw: RawCodeRow = RawCodeRow.new()
		raw.code = str(line)
		step.actions.append(raw)
	return step


static func _sheet_with(block: MomentBlockRow) -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	sheet.events.append(block)
	return sheet


## The moment's coroutine out of a whole compiled file: the header line and everything indented
## under it, so the pin is the block and not the prelude around it.
static func _function_text(output: String) -> String:
	var lines: PackedStringArray = output.split("\n")
	var kept: PackedStringArray = PackedStringArray()
	var inside: bool = false
	for line: String in lines:
		if line.begins_with("func moment_"):
			inside = true
			kept.append(line)
			continue
		if not inside:
			continue
		if line.begins_with("\t"):
			kept.append(line)
			continue
		break
	return "\n".join(kept)


## The first Moment block a reopened sheet holds, or null.
static func _first_block(sheet: EventSheetResource) -> MomentBlockRow:
	if sheet == null:
		return null
	for entry: Variant in sheet.events:
		if entry is MomentBlockRow:
			return entry as MomentBlockRow
	return null


## What a reopened sheet's top-level rows ARE, in order - each row's own kind word, so a pin says
## which shape a file came back as rather than how many rows it made.
static func _row_kinds(sheet: EventSheetResource) -> Array:
	var kinds: Array = []
	if sheet == null:
		return kinds
	for entry: Variant in sheet.events:
		var row: Object = entry as Object
		if row == null:
			kinds.append("null")
		elif row.has_method("get_row_kind"):
			kinds.append(str(row.call("get_row_kind")))
		else:
			kinds.append(row.get_class())
	return kinds


## The ordinary functions a reopened sheet holds, by name. A moment this reader cannot claim is
## refused as a block and stays exactly this: a function of that name, like any other in the file.
static func _plain_function_names(sheet: EventSheetResource) -> Array:
	var names: Array = []
	if sheet == null:
		return names
	for entry: Variant in sheet.functions:
		var written: EventFunction = entry as EventFunction
		if written != null:
			names.append(written.function_name)
	return names


## One step's statements, joined, so a pin can read a whole step on one line.
static func _statements(step: MomentStepRow) -> String:
	var out: PackedStringArray = PackedStringArray()
	for entry: Variant in step.actions:
		if entry is RawCodeRow:
			out.append((entry as RawCodeRow).code)
	return ";".join(out)
