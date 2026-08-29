# EventForge - THE UNIT RIDES THE VALUE: what an angle field holds, and how the row reads it back.
#
# Godot thinks in radians, people think in degrees, and every angle bug lives in the seam. The rule
# here is one sentence: a plain number is degrees, and anything a reader wrote in radians stays in
# radians, emitted exactly as they wrote it.
#
#     45          ->  deg_to_rad(45.0)     the row reads "45°"
#     PI/4        ->  PI/4                 the row reads "PI/4 rad" - no deg_to_rad around your PI
#     1.2 rad     ->  1.2                  the reader said the unit; the field believes them
#     90 deg      ->  deg_to_rad(90.0)     the same as typing 90, said out loud
#
# There is NO unit picker. A picker is one more thing to get wrong, and the unit is already in what
# was typed. What the row always does is SHOW which unit it ended up meaning, so the sentence and the
# code can never quietly disagree.
#
# A per-project setting flips what a bare number means, for teams that think in radians. It changes
# the WRITING only: a value already stored is read back by what it says, never by the setting, so
# turning the setting on cannot silently re-interpret a sheet somebody else wrote.
@tool
class_name EventForgeAngleUnits
extends RefCounted

## The parameter hint that makes a field an angle field - and, through the lens table, the name of
## the reading that says which unit its value means.
const LENS_HINT: String = "angle"

## The project setting, and the two answers it takes. Degrees unless a project says otherwise.
const SETTING: String = "eventsheets/angles/default_unit"
const DEGREES: String = "degrees"
const RADIANS: String = "radians"

## The two calls a value is converted through, and the suffixes a reader can say a unit with.
const TO_RADIANS: String = "deg_to_rad"
const TO_DEGREES: String = "rad_to_deg"
const RADIAN_SUFFIX: String = "rad"
const DEGREE_SUFFIX: String = "deg"

## The degree sign the row reads a degree value with. Formatting, never a unit picker.
const DEGREE_SIGN: String = "°"

## The names that make an expression radian-shaped on sight. A reader who wrote PI meant PI.
const RADIAN_WORDS: Array[String] = ["PI", "TAU"]

## The compiled test for those names, built once. Every angle row of an opened sheet asks it while
## its text is composed, so the pattern is compiled for the session rather than for the question.
static var _radian_words_regex: RegEx = null


## What the project means by a bare number, "degrees" unless it says otherwise.
static func default_unit() -> String:
	var declared: String = str(ProjectSettings.get_setting(SETTING, DEGREES)).strip_edges().to_lower()
	return RADIANS if declared == RADIANS else DEGREES


## What an angle field STORES for what a reader typed. `wants` is the unit the SLOT needs - radians
## for a template that takes the angle whole, degrees for one that writes the `deg_to_rad` itself -
## and the answer is the reader's own expression with exactly the conversion that makes it true, or
## none at all when none is needed. An empty answer stays empty.
##
## So `45` in a radian slot is written `deg_to_rad(45)` and `PI/4` is written `PI/4`: nothing is ever
## wrapped round somebody's PI. In a DEGREE slot it is the other way about, and `PI/4` is written
## `rad_to_deg(PI/4)` - a conversion, and the honest one, because the template's own `deg_to_rad`
## would otherwise read those radians as degrees, which is the exact bug this rule exists to stop.
static func stored(typed: String, wants: String = RADIANS) -> String:
	var text: String = typed.strip_edges()
	if text.is_empty():
		return text
	var said: String = said_unit(text)
	if not said.is_empty():
		text = text.left(text.length() - said.length()).strip_edges()
	var is_radians: bool = said == RADIAN_SUFFIX \
		or (said.is_empty() and (is_radian_spelling(text) or default_unit() == RADIANS))
	if is_radians == (wants == RADIANS):
		return text
	return "%s(%s)" % [TO_RADIANS if wants == RADIANS else TO_DEGREES, text]


## The unit a reader said out loud at the end of what they typed, "" when they said none.
##
## Said OUT LOUD means the word stands on its own: after a space ("45 deg") or straight after the
## number it belongs to ("1.2rad"). A name that merely ends in those three letters - `angle_deg`,
## `aim_rad`, `turn_grad` - said nothing, and reading a unit off it would chop the tail off the
## identifier and emit a variable the game does not have.
static func said_unit(typed: String) -> String:
	var lowered: String = typed.strip_edges().to_lower()
	for suffix: String in [RADIAN_SUFFIX, DEGREE_SUFFIX]:
		if not lowered.ends_with(suffix) or lowered.length() == suffix.length():
			continue
		var before: String = lowered[lowered.length() - suffix.length() - 1]
		if before == " " or before == "\t" or before == "." or before.is_valid_int():
			return suffix
	return ""


## What the ROW says the value is: the number with its unit, always, whichever way it was written.
## A value nothing can be said about (a variable, a call) reads as itself - the row would rather say
## nothing than claim a unit it cannot know.
##
## The project setting is NOT consulted here, and that is the point of the whole file: what is stored
## already says which unit it is, so a bare number is degrees whichever way the project thinks. A
## reader who thinks in radians has their typing converted on the way IN (a plain number they type
## is written `rad_to_deg(…)` into a slot the template converts back), so a bare number never means
## radians in a stored sheet - and turning the setting on cannot re-read somebody else's file.
static func reading(value: String) -> String:
	var text: String = value.strip_edges()
	if text.is_empty():
		return text
	var degrees: String = inside(text, TO_RADIANS)
	if not degrees.is_empty():
		return degrees + DEGREE_SIGN
	var radians: String = inside(text, TO_DEGREES)
	if not radians.is_empty():
		return "%s %s" % [radians, RADIAN_SUFFIX]
	if is_radian_spelling(text):
		return "%s %s" % [text, RADIAN_SUFFIX]
	if text.is_valid_float():
		return text + DEGREE_SIGN
	return text


## What one conversion call is wrapped around, "" when the value is not that call - which is how a
## reading gets back to the number the author typed, whichever way round it was converted.
static func inside(value: String, call_name: String) -> String:
	var text: String = value.strip_edges()
	var opening: String = call_name + "("
	if not (text.begins_with(opening) and text.ends_with(")")):
		return ""
	return text.substr(opening.length(), text.length() - opening.length() - 1).strip_edges()


## True when an expression is written in radians on its own evidence - it names PI or TAU. A bare
## number is NOT one of these: what a bare number means is what the project setting says.
##
## The name has to stand alone to count, which is what the word boundaries are for: `spin_speed * PI`
## and `x * TAU` name the constant wherever in the expression they sit, while `SPIN`, `TAUNT` and
## `my_PI_value` do not name it at all. An expression that ends in the constant is the common
## spelling and was the one this missed, so a reader's own PI came back wrapped in `deg_to_rad`.
static func is_radian_spelling(value: String) -> bool:
	return _radian_words().search(value.strip_edges()) != null


static func _radian_words() -> RegEx:
	if _radian_words_regex == null:
		_radian_words_regex = RegEx.new()
		_radian_words_regex.compile("\\b(%s)\\b" % "|".join(PackedStringArray(RADIAN_WORDS)))
	return _radian_words_regex
