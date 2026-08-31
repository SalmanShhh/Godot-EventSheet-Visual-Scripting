@tool
class_name EventForgeNodeDignityLift
extends RefCounted

# EventForge - the three small node dignities, read back off the file.
#
# Two of them are one statement each, so they are TABLE entries rather than matchers: the owner a
# node is written out as part of, and a reparent that says which of the two things should happen to
# where the node is. The table engine takes the pattern, the row it means and the captures that are
# values, generates the entry's own fixture line from its shape, and asserts the byte round trip -
# which is why an entry here cannot exist untested and there is no fixture written down by hand.
#
# WHY THESE TWO SPELLINGS GET AN ENTRY AT ALL, when the general reverse index would already claim
# them. It would - and it would claim them as the WRONG row. `x.owner = y` matches the Set Property
# catch-all, so a file saying which scene a node belongs to used to read as a property being poked;
# and `reparent(x, true)` matches the frozen Reparent To template (whose one slot happily swallows
# `x, true` whole), so a file that said which behaviour it meant read as one that had not said. Both
# re-emitted their own bytes, so nothing was ever lost - but a reading that is byte-safe and wrong is
# still wrong, and the table is asked before the index precisely so that a family can say which of
# two identically-shaped lines a file means.
#
# THE THIRD DIGNITY HAS NO ENTRY, and the reason is the table's own boundary rather than an oversight.
# Duplicate Node (choosing) is an EXPRESSION - it hands back a copy for another row to use - and an
# expression is never a statement of its own, so there is no line for a pattern to anchor to. Its
# spelling is gated the other way instead, by compiling a sheet that uses it and reading the file
# back (tests/undoable_tool_edits_test.gd), which is the same byte question asked at the file level.

## The rows these spellings mean. Frozen with the descriptors they name.
const SET_SCENE_OWNER: String = "SetSceneOwner"
const REPARENT_CHOOSING: String = "ReparentToChoosing"

## Built once for the life of the session: the table is walked for every statement of every opened
## file, and building the dictionaries per line was the whole cost of the hand-written matchers.
static var _entries: Array[Dictionary] = []


## The spellings this family claims, for the lifter and for the harness that byte-tests each one.
static func lift_entries() -> Array[Dictionary]:
	if _entries.is_empty():
		_entries = [
			{
				"id": "owner_assignment",
				"ace_id": SET_SCENE_OWNER,
				# The receiver is a param here rather than part of the spelling, because the row
				# genuinely has one: Set Scene Owner names the node it is about. The value side is
				# left wide open - it is any expression naming the top of a scene.
				"pattern": "^(?<target>%s)\\.owner[ \\t]*=[ \\t]*(?<root>.+)$" % EventForgeLiftTable.NODE_REFERENCE,
				"params": ["target", "root"],
				"shape": "{target}.owner = {root}",
				"slots": {"target": "$Crate", "root": "get_tree().current_scene"}
			},
			{
				"id": "reparent_saying_which",
				"ace_id": REPARENT_CHOOSING,
				# `reparent` with no receiver: the row is about THIS node, exactly as the frozen
				# Reparent To beside it is. The second argument is what separates the two rows, so it
				# is matched as the two words Godot accepts rather than as any expression - a computed
				# flag is a line that has not said which it meant, and it keeps the frozen row.
				"pattern": "^reparent\\((?<new_parent>.+), (?<keep>true|false)\\)$",
				"params": ["new_parent", "keep"],
				"shape": "reparent({new_parent}, {keep})",
				"slots": {"new_parent": "get_tree().current_scene", "keep": "true"}
			},
		]
	return _entries


## The row one statement means, or {} when this family does not claim it.
static func match_line(line: String) -> Dictionary:
	return EventForgeLiftTable.match_line(lift_entries(), line)
