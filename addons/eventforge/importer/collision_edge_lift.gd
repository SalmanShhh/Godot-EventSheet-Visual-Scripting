# EventForge - the landing check every platformer already contains, read back as the row it is.
#
# Long before this plugin exists, a project that wants to know the STEP its character landed has
# written the same three parts: a variable that remembers last step's footing, an `if` that compares
# this step's answer against it, and a line after the `if` that brings the memory up to date.
#
#     var was_on_floor: bool = false
#
#     func _physics_process(delta: float) -> void:
#         if is_on_floor() and not was_on_floor:
#             land()
#         was_on_floor = is_on_floor()
#
# The variable and the update line are ordinary rows already - a declaration and an assignment, both
# of which this plugin has read since it could read anything. What is claimed HERE is the middle
# part, the comparison, because it is the only one of the three whose meaning is not in its own
# spelling: `is_on_floor() and not was_on_floor` reads to the splitter as two unrelated questions
# ("is on the floor" AND "not some variable"), and two rows that separately mean nothing are worse
# than one raw line. Claimed whole, it is the sentence a reader would say out loud: JUST LANDED.
#
# THE MEMORY'S NAME IS NOT A VALUE, so it is not a param of the row: it is the author's own spelling,
# it belongs to their variable declaration two rows up, and leaving it out of `params` is precisely
# what makes it ride back out untouched - `grounded_last_frame`, `was_grounded`, `_was_on_floor`,
# whatever they called it, comes back exactly as it went in.
#
# WHAT IS CLAIMED AND WHAT IS LEFT ALONE. Four spellings name the floor outright, in both orders the
# two halves can be written in, and those are claimed on the strength of the call in them. Two more
# are the TWO-VARIABLE form, where this step's footing was put in a local first - and there the line
# says nothing about floors on its own, so the claim rests on the two names: one that reads as
# footing NOW, one that reads as footing BEFORE. A line whose names do not read that way is left to
# the general index, which is the honest answer: this family knows the pattern it knows, and an
# `a and not b` it cannot say anything about is not a landing check just because it has the shape of
# one.
@tool
class_name EventForgeCollisionEdgeLift
extends RefCounted

## The two fragments a line must carry before any pattern here is worth compiling: every claimed
## spelling joins two halves and negates one of them, which rules out almost every expression in a
## project first. Both orders are claimed, so the negation is looked for on its own rather than as
## part of the join.
const JOIN_MARK: String = " and "
const NEGATION_MARK: String = "not "

## One identifier, as the author may have spelled it.
const NAME: String = "[A-Za-z_][A-Za-z0-9_]*"

## The words a name reads as "the footing THIS step" by. A local a physics step put `is_on_floor()`
## into is called one of these in nearly every project that makes one at all.
const NOW_WORDS: PackedStringArray = ["floor", "ground", "grounded", "footing"]

## The prefixes and suffixes a name reads as "the footing LAST step" by. Checked before the words
## above, so `was_on_floor` is a memory and never mistaken for the present.
const BEFORE_MARKS: PackedStringArray = ["was_", "were_", "prev_", "previous_", "last_", "old_"]
const BEFORE_TAILS: PackedStringArray = ["_was", "_prev", "_previous", "_last", "_before",
	"_last_frame", "_last_step", "_last_tick"]

static var _conditions: Array[Dictionary] = []


## The condition this line is, or {} when the line is not one of the claimed spellings. Asked of a
## whole `if` expression rather than of one term of it, because both halves together are the row.
static func match_whole_condition(line: String) -> Dictionary:
	var text: String = line.strip_edges()
	if not (text.contains(JOIN_MARK) and text.contains(NEGATION_MARK)):
		return {}
	return EventForgeLiftTable.match_line(condition_entries(), text)


## The six spellings, built once for the life of the session: these run on every `if` of every opened
## file, and the table compiles each pattern once.
static func condition_entries() -> Array[Dictionary]:
	if _conditions.is_empty():
		_conditions = [
			{
				"id": "just_landed_asked_then_remembered",
				"ace_id": "JustLanded",
				"pattern": "^is_on_floor\\(\\) and not (?<was>%s)$" % NAME,
				"guard": Callable(EventForgeCollisionEdgeLift, "_was_names_a_memory"),
				"shape": "is_on_floor() and not was_on_floor",
				"slots": {}
			},
			{
				"id": "just_landed_remembered_then_asked",
				"ace_id": "JustLanded",
				"pattern": "^not (?<was>%s) and is_on_floor\\(\\)$" % NAME,
				"guard": Callable(EventForgeCollisionEdgeLift, "_was_names_a_memory"),
				"shape": "not was_on_floor and is_on_floor()",
				"slots": {}
			},
			{
				"id": "just_left_the_ground_remembered_then_asked",
				"ace_id": "JustLeftTheGround",
				"pattern": "^(?<was>%s) and not is_on_floor\\(\\)$" % NAME,
				"guard": Callable(EventForgeCollisionEdgeLift, "_was_names_a_memory"),
				"shape": "was_on_floor and not is_on_floor()",
				"slots": {}
			},
			{
				"id": "just_left_the_ground_asked_then_remembered",
				"ace_id": "JustLeftTheGround",
				"pattern": "^not is_on_floor\\(\\) and (?<was>%s)$" % NAME,
				"guard": Callable(EventForgeCollisionEdgeLift, "_was_names_a_memory"),
				# `not is_on_floor() and was_on_floor` is the same question the entry above asks; a
				# file that wrote it this way round gets its own bytes back.
				"shape": "not is_on_floor() and was_on_floor",
				"slots": {}
			},
			{
				# THE TWO-VARIABLE FORM. Both halves are names, so the shape alone says nothing - the
				# guard is the whole claim, and it asks that one name read as the footing now and the
				# other as the footing before.
				"id": "just_landed_two_variables",
				"ace_id": "JustLanded",
				"pattern": "^(?<now>%s) and not (?<was>%s)$" % [NAME, NAME],
				"guard": Callable(EventForgeCollisionEdgeLift, "_reads_as_now_then_before"),
				"shape": "on_floor and not was_on_floor",
				"slots": {}
			},
			{
				"id": "just_left_the_ground_two_variables",
				"ace_id": "JustLeftTheGround",
				"pattern": "^(?<was>%s) and not (?<now>%s)$" % [NAME, NAME],
				"guard": Callable(EventForgeCollisionEdgeLift, "_reads_as_before_then_now"),
				"shape": "was_on_floor and not on_floor",
				"slots": {}
			}
		]
	return _conditions


## True when the captured name reads as a REMEMBERED footing. The four spellings above already name
## the floor in their call, so all this has to rule out is a line that asks about the floor and then
## about something unrelated - `is_on_floor() and not dead` is two questions, not a landing.
static func _was_names_a_memory(captures: Dictionary) -> bool:
	return reads_as_before(str(captures.get("was", "")))


## The two-variable landing: footing now, then footing before.
static func _reads_as_now_then_before(captures: Dictionary) -> bool:
	return reads_as_now(str(captures.get("now", ""))) and reads_as_before(str(captures.get("was", "")))


## The two-variable departure: footing before, then footing now.
static func _reads_as_before_then_now(captures: Dictionary) -> bool:
	return reads_as_before(str(captures.get("was", ""))) and reads_as_now(str(captures.get("now", "")))


## True when a name reads as "the footing LAST step": it wears one of the remembering marks AND names
## the floor. Both halves are required, so `last_score` is not a memory of footing and `on_floor` is
## not a memory at all.
static func reads_as_before(name: String) -> bool:
	var bare: String = name.strip_edges().lstrip("_").to_lower()
	if not _names_the_floor(bare):
		return false
	for mark: String in BEFORE_MARKS:
		if bare.begins_with(mark):
			return true
	for tail: String in BEFORE_TAILS:
		if bare.ends_with(tail):
			return true
	return false


## True when a name reads as "the footing THIS step": it names the floor and wears none of the
## remembering marks.
static func reads_as_now(name: String) -> bool:
	var bare: String = name.strip_edges().lstrip("_").to_lower()
	return _names_the_floor(bare) and not reads_as_before(name)


## True when a name is MADE OF one of the floor words, rather than merely containing one. Matched on
## the parts of the name, because a substring test claims words that are not there: `underground`
## contains "ground", so `if underground and not was_grounded:` read as a landing and the sheet said
## a sentence about floors over code that means nothing of the kind. Bytes were never at risk - the
## entry keeps the author's own spelling - but a mis-read is still a sentence asserted about somebody
## else's code, which is the one thing this family cannot afford to get wrong.
static func _names_the_floor(bare: String) -> bool:
	for part: String in bare.split("_", false):
		if NOW_WORDS.has(part):
			return true
	return false
