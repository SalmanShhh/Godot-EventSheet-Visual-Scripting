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

## The fixture moment, as the file holds it. Written out in full because every other pin in this
## file is measured against it.
const IMPACT_TEXT: String = """func moment_impact(strength: float = 1.0, from: Node = null) -> void:
	shake(0.4 * strength)
	hitstop()
	await EventForgeMomentRunner.at(self, 0.05, "game")
	play_sound()
	await EventForgeMomentRunner.hold(self, 0.3, 0.1, "game")
	tween_scale(1.0, 0.2)"""

## The same moment with a place and a range: one line at the top turns the play's strength into
## the strength it really has here, and the distance is measured ONCE per play.
const RANGED_TEXT: String = """func moment_blast(strength: float = 1.0, from: Node = null) -> void:
	strength = EventForgeMomentRunner.strength_at(self, strength, from, 600.0, "smooth")
	shockwave(strength)"""

## A loop: everything since the last Hold runs again, the count being how many EXTRA passes.
const LOOPED_TEXT: String = """func moment_pulse(strength: float = 1.0, from: Node = null) -> void:
	a()
	for _moment_loop: int in 3:
		await EventForgeMomentRunner.hold(self, 0.0, 0.0, "game")
		b()
		await EventForgeMomentRunner.then(self, 0.1, "game")
		c()"""


static func run() -> bool:
	var passed: bool = true
	passed = _pin_the_emission() and passed
	passed = _pin_the_round_trip() and passed
	passed = _pin_the_loop() and passed
	passed = _pin_the_strength() and passed
	passed = _pin_the_range() and passed
	return passed


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


## One step's statements, joined, so a pin can read a whole step on one line.
static func _statements(step: MomentStepRow) -> String:
	var out: PackedStringArray = PackedStringArray()
	for entry: Variant in step.actions:
		if entry is RawCodeRow:
			out.append((entry as RawCodeRow).code)
	return ";".join(out)
