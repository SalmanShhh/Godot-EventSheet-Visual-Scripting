# Godot EventSheets - MomentBlockRow resource
#
# A moment written as ROWS instead of as a list of effect words in a file: a block whose children
# are its steps, each one a timing word on the left and any actions on the right. It compiles to
# ONE coroutine on the host - `func moment_<name>(strength, from)` - so the thing a sheet plays is
# an ordinary function a hand-written script could have held, and a hand-written one of that shape
# opens back as this block.
#
# THE SCHEDULE IS COMPUTED HERE, ONCE. `skeleton()` walks the steps and works out what each one
# waits for, and `build_lines()` is the only place the emitted shape is spelled. The compiler and
# the block kind's byte gate both go through them, so the gate and the output can never disagree
# about what an untouched block looks like on disk.
#
# WHAT A HOLD WAITS FOR. Each step may declare how long what it starts `lasts`. A Hold waits until
# the latest of those has finished and then its own delay, and both halves ride the one emitted
# line, so re-opening the file recovers the same wait without needing the durations written down
# anywhere. A step that declares no duration counts as instant, which is the common case. A Hold
# that opens a looped stretch waits for what was running ABOVE the loop, because the stretch it
# heads has nothing above it yet.
#
# STRENGTH, PLACE AND RANGE. The coroutine's own parameters are `strength` (what every amount in
# the block is written against) and `from` (where the moment happened). A block that names a range
# opens with one line that turns those into the strength this play really has: a far impact is
# quieter, and one outside the range is silent. The distance is measured ONCE per play.
@tool
class_name MomentBlockRow
extends Resource

## How the strength falls off between the place and the range edge. Words, not curve resources:
## a game that wants its own shape writes the number itself in the step's field.
const FALLOFF_LINEAR: String = "linear"
const FALLOFF_SMOOTH: String = "smooth"
const FALLOFF_NONE: String = "none"

## The runtime the emitted coroutine calls: plain GDScript shipped with the Juice pack, in the
## folder the project owns, so an emitted moment goes on parsing with the editor addon deleted.
const RUNNER: String = "MomentRunner"

## The prefix every moment's function name carries, so a moment is findable in a file by eye and
## the lift has one shape to look for.
const FUNCTION_PREFIX: String = "moment_"

## The coroutine's signature, spelled once. Frozen with the block: a file on disk is read back by
## matching it.
const SIGNATURE: String = "(strength: float = 1.0, from: Node = null) -> void:"

@export var enabled: bool = true
## The moment's name, which is also the suffix of its function (`impact` -> `moment_impact`).
@export var moment_name: String = ""
## The steps, in order. Each is a MomentStepRow.
@export var steps: Array[Resource] = []
## How far the moment reaches from `from`, in the host's own units. 0 = everywhere, at full
## strength, which is what a moment with nowhere to be plays at.
@export var within: float = 0.0
## One of the FALLOFF_* words above.
@export var falloff: String = FALLOFF_LINEAR


## Returns the stable row kind identifier.
func get_row_kind() -> String:
	return "moment"


## The function this block compiles to, or "" when the block has no usable name. Validated the
## same way a GDScript identifier is, because that is what it becomes.
func function_name() -> String:
	var word: String = moment_name.strip_edges()
	if word.is_empty() or not word.is_valid_identifier():
		return ""
	return FUNCTION_PREFIX + word


## The falloff word this block really has (an unknown word reads as linear).
func falloff_word() -> String:
	match falloff:
		FALLOFF_SMOOTH:
			return FALLOFF_SMOOTH
		FALLOFF_NONE:
			return FALLOFF_NONE
		_:
			return FALLOFF_LINEAR


## The steps that actually play: enabled, and really steps.
func live_steps() -> Array[MomentStepRow]:
	var kept: Array[MomentStepRow] = []
	for entry: Variant in steps:
		if entry is MomentStepRow and (entry as MomentStepRow).enabled:
			kept.append(entry as MomentStepRow)
	return kept


## THE SCHEDULE, worked out once: one entry per playing step, in emission order.
##
## Each entry is {step, depth, opens_loop, closes_loop, loop_count, wait} where `wait` is the
## whole line the step waits on (or "" when it starts the moment the one above it did). Times are
## measured from the start of the stretch the step is in, so a step inside a loop is timed from
## the top of each pass - which is what a loop back means.
func skeleton() -> Array[Dictionary]:
	var playing: Array[MomentStepRow] = live_steps()
	var loop_starts: Dictionary = _loop_regions(playing)
	var plan: Array[Dictionary] = []
	var cursor: float = 0.0
	var finish: float = 0.0
	# What was still running when a looped stretch opened. A stretch restarts its own clock, but
	# the steps ABOVE the loop are still playing on the way in, so a Hold that opens one has
	# something to wait for even though its stretch has only just begun.
	var carried: float = 0.0
	var depth: int = 0
	for index: int in range(playing.size()):
		var step: MomentStepRow = playing[index]
		var entry: Dictionary = {
			"step": step, "depth": depth, "opens_loop": false, "closes_loop": false,
			"loop_count": 0, "wait": ""
		}
		if loop_starts.has(index):
			# A stretch that is looped back to restarts its own clock on every pass.
			entry["opens_loop"] = true
			entry["loop_count"] = int(loop_starts[index])
			depth = 1
			entry["depth"] = depth
			carried = maxf(finish - cursor, 0.0)
			cursor = 0.0
			finish = 0.0
		var word: String = step.timing_word()
		if word == MomentStepRow.TIMING_LOOP_BACK:
			entry["closes_loop"] = true
			plan.append(entry)
			depth = 0
			cursor = 0.0
			finish = 0.0
			continue
		match word:
			MomentStepRow.TIMING_THEN:
				if step.seconds > 0.0:
					entry["wait"] = "await %s.then(self, %s, \"%s\")" % [
						RUNNER, _seconds_text(step.seconds), step.clock_word()]
					cursor += maxf(step.seconds, 0.0)
			MomentStepRow.TIMING_HOLD:
				# Both halves ride the line: how much of the longest step above is still to run,
				# and the delay the Hold itself asks for after that. A Hold that OPENS a looped
				# stretch waits for what was running above the loop instead: its own stretch has
				# nothing above it yet, and the fold rides every pass, so the beat repeats at the
				# pace it first landed at.
				var longest: float = carried if bool(entry["opens_loop"]) else maxf(finish - cursor, 0.0)
				entry["wait"] = "await %s.hold(self, %s, %s, \"%s\")" % [
					RUNNER, _seconds_text(longest), _seconds_text(maxf(step.seconds, 0.0)),
					step.clock_word()]
				cursor += longest + maxf(step.seconds, 0.0)
			_:
				var gap: float = step.seconds - cursor
				if gap > 0.0005:
					entry["wait"] = "await %s.at(self, %s, \"%s\")" % [
						RUNNER, _seconds_text(gap), step.clock_word()]
					cursor += gap
		finish = maxf(finish, cursor + maxf(step.lasts, 0.0))
		plan.append(entry)
	return plan


## The whole block as GDScript. `action_lines` is asked for one step's statements WITHOUT any
## indent (the caller knows how to turn its own action rows into code; this knows where they go).
## Returns [] when the block cannot be named, so a half-typed block emits nothing rather than a
## parse error.
func build_lines(action_lines: Callable) -> PackedStringArray:
	var name_of: String = function_name()
	if not enabled or name_of.is_empty():
		return PackedStringArray()
	var out: PackedStringArray = PackedStringArray(["func " + name_of + SIGNATURE])
	if within > 0.0:
		out.append("\tstrength = %s.strength_at(self, strength, from, %s, \"%s\")" % [
			RUNNER, _seconds_text(within), falloff_word()])
	for entry: Dictionary in skeleton():
		var depth: int = int(entry["depth"])
		var indent: String = "\t".repeat(depth + 1)
		if bool(entry["opens_loop"]):
			out.append("\tfor _moment_loop: int in %d:" % (int(entry["loop_count"]) + 1))
		var wait_line: String = str(entry["wait"])
		if not wait_line.is_empty():
			out.append(indent + wait_line)
		var body_before: int = out.size()
		for statement: String in (action_lines.call(entry["step"]) as PackedStringArray):
			out.append(indent + statement)
		if bool(entry["opens_loop"]) and wait_line.is_empty() and out.size() == body_before:
			# A looped stretch that opens with a step that says and does nothing still needs a
			# body, or the `for` above it is a parse error.
			out.append(indent + "pass")
	if out.size() == 1 or (out.size() == 2 and within > 0.0):
		out.append("\tpass")
	return out


## Which step index each looped stretch starts at, and how many extra passes it asks for. A Loop
## Back goes to the last Hold above it, or to the top; a second one can never reach back past the
## first, so the stretches never overlap.
func _loop_regions(playing: Array[MomentStepRow]) -> Dictionary:
	var regions: Dictionary = {}
	var floor_index: int = 0
	for index: int in range(playing.size()):
		var word: String = playing[index].timing_word()
		if word == MomentStepRow.TIMING_HOLD:
			floor_index = index
		elif word == MomentStepRow.TIMING_LOOP_BACK:
			if index > floor_index:
				regions[floor_index] = maxi(playing[index].loop_count, 1)
			floor_index = index + 1
	return regions


## A number as the emitter spells it: three decimals at most, and always a float, so 0.35 reads
## "0.35" rather than "0.34999999999999998" and 1 reads "1.0".
static func _seconds_text(value: float) -> String:
	return var_to_str(snappedf(maxf(value, 0.0), 0.001))
