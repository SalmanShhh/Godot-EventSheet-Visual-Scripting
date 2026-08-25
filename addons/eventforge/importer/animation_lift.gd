# EventForge - the animation spellings people wrote before this plugin existed.
#
# The shipped rows write one spelling each - `play(&"attack")`, `queue("idle")` - and a project full
# of animation code is full of the OTHER one. Godot takes a StringName or a plain String in both
# calls and everybody picks by habit, so half the `play` lines in the world stayed raw blocks for
# want of an ampersand.
#
#     $Anim.play("attack")        the plain-string play, which the shipped template's `&` misses
#     queue(&"idle")              the StringName queue, which the shipped template's bare name misses
#
# Both are TABLE entries, so the harness generates a fixture line per entry and asserts the byte
# round-trip: whichever spelling the author used is the spelling the file gets back.
#
# THE VALUE IS THE WHOLE LITERAL, quotes and ampersand included, exactly as the picked rows hold it.
# That is what lets a lifted row and an authored row be edited by the same field, and what keeps the
# author's own `&` in the file after a round trip through the dialog.
@tool
class_name EventForgeAnimationLift
extends RefCounted

## The fragment a line must hold for any entry here to be worth trying - one substring test rules out
## almost every line in a project before a pattern is compiled at all.
const MARK: String = "("

## The two calls this family knows, and the row each one means.
const PLAY_ACE: String = "PlayAnimation"
const QUEUE_ACE: String = "QueueAnimation"


## The row one statement means, or {} when nothing here claims it.
static func match_line(line: String) -> Dictionary:
	var text: String = line.strip_edges()
	if not text.contains(MARK):
		return {}
	return EventForgeLiftTable.match_line(lift_entries(), text)


## The table. `play` and `queue` each take one animation, optionally through a node reference, and
## the receiver is the author's own text rather than a value - which is why it rides back out
## untouched and is not part of any sentence.
static func lift_entries() -> Array[Dictionary]:
	return [
		{
			"id": "play_a_plain_string_animation",
			"ace_id": PLAY_ACE,
			"pattern": "^%splay\\((?<anim_name>\"[^\"]*\")\\)$" % EventForgeLiftTable.receiver(),
			"params": ["anim_name", "target"],
			"shape": "{target.}play({anim_name})",
			"slots": {"anim_name": "\"attack\"", "target": "$Anim"}
		},
		{
			"id": "queue_a_string_name_animation",
			"ace_id": QUEUE_ACE,
			"pattern": "^%squeue\\((?<animation>&\"[^\"]*\")\\)$" % EventForgeLiftTable.receiver(),
			"params": ["animation", "target"],
			"shape": "{target.}queue({animation})",
			"slots": {"animation": "&\"idle\"", "target": "$Anim"}
		},
	]
