# Godot EventSheets - MomentStepRow resource
#
# One step of a Moment block. The left lane says WHEN (a timing word plus a number), the right
# lane holds the actions that say WHAT - any action the sheet has, not a fixed list of effect
# words: a pack verb, a tween, a spawn, an emitted signal.
#
# THE FOUR TIMING WORDS, and what each one means to the compiler:
#   At        this many seconds after the block started. Steps default to At 0, so a first draft
#             plays everything at once, which is what most hits want.
#   Then      this many seconds after the PREVIOUS step started.
#   Hold      wait until every step above has finished, then this many seconds. What "finished"
#             means is each step's own `lasts` - a step that declares none counts as instant.
#   Loop Back go back to the last Hold above (or to the top) and run that stretch again,
#             `loop_count` more times.
#
# `lasts` is the step's DURATION - how long the thing it starts goes on for - and it exists so a
# Hold below can know how long to wait. It is never emitted on its own: the compiler folds every
# declared duration into the one number the Hold's own line carries.
@tool
class_name MomentStepRow
extends Resource

## The timing words, as stored. Public shape once shipped - a saved sheet holds these strings.
const TIMING_AT: String = "at"
const TIMING_THEN: String = "then"
const TIMING_HOLD: String = "hold"
const TIMING_LOOP_BACK: String = "loop_back"

## Which clock a step's wait is measured on. "game" follows time_scale (so a slowmo stretches the
## beat with everything else); "real" ignores it, which is what a step after a hitstop wants.
const CLOCK_GAME: String = "game"
const CLOCK_REAL: String = "real"

@export var enabled: bool = true
## One of the four TIMING_* words above. Anything else reads (and compiles) as At.
@export var timing: String = TIMING_AT
## The step's own number: seconds from the block's start (At), from the previous step (Then),
## or after everything above has finished (Hold). Ignored by Loop Back.
@export var seconds: float = 0.0
## How long what this step starts goes on for. Only a Hold below ever reads it; 0 = instant.
@export var lasts: float = 0.0
## How many EXTRA times a Loop Back runs its stretch (1 = the stretch runs twice in all).
@export var loop_count: int = 1
## CLOCK_GAME or CLOCK_REAL - which clock this step's wait is measured on.
@export var clock: String = CLOCK_GAME
## The actions this step runs: ACEAction rows, verbatim RawCodeRow blocks, comment rows.
@export var actions: Array[Resource] = []


## Returns the stable row kind identifier.
func get_row_kind() -> String:
	return "moment_step"


## The timing word this step really has - an unknown or empty word reads as At, so a sheet saved
## by a newer version with a word this one has never heard of still opens and still plays.
func timing_word() -> String:
	match timing:
		TIMING_THEN:
			return TIMING_THEN
		TIMING_HOLD:
			return TIMING_HOLD
		TIMING_LOOP_BACK:
			return TIMING_LOOP_BACK
		_:
			return TIMING_AT


## The clock word this step really has ("real" only when it says so).
func clock_word() -> String:
	return CLOCK_REAL if clock == CLOCK_REAL else CLOCK_GAME


## The step's one-line reading - the words the condition lane draws. Short on purpose: the number
## is the point, and the sentence around it is three words at most.
func reading() -> String:
	match timing_word():
		TIMING_THEN:
			return "Then %s s" % _number(seconds)
		TIMING_HOLD:
			if seconds > 0.0:
				return "Hold, then %s s" % _number(seconds)
			return "Hold"
		TIMING_LOOP_BACK:
			return "Loop back %d x" % maxi(loop_count, 1)
		_:
			return "At %s s" % _number(seconds)


## A number as short as it can be said: "0.05", not "0.050000". Display only.
func _number(value: float) -> String:
	return String.num(snappedf(value, 0.001), 3).rstrip("0").rstrip(".") if value != 0.0 else "0"
