# EventForge - the filtered-overlap questions people wrote before this plugin existed.
#
# "Is anything from this group inside my area right now?" has two spellings in the wild, and both of
# them open as the same one row - Is touching <Group>:
#
#     get_overlapping_bodies().any(func(b: Node) -> bool: return b.is_in_group("enemies"))
#     get_tree().get_nodes_in_group("enemies").any(overlaps_body)
#
# The first asks the area what is inside it and filters; the second asks the group and filters by
# overlap. They are the same question from the two ends, so both hand back the same row - and each
# hands back the exact template it matched, so a file re-emits the author's own bytes: their lambda
# parameter's name, their type hint or its absence, their spacing.
#
# THE LAMBDA'S PARAMETER IS NOT A VALUE, so it is not a param of the row: it is the author's own
# spelling, it appears twice in the line, and leaving it out of `params` is precisely what makes it
# ride back out untouched. The GROUP is the one thing the row shows, and the one thing it stores.
#
# The `overlaps_body` half is left to the general reverse index where the line is spelled exactly as
# the shipped template spells it; what is here is the widening - the spellings a person writes that
# the shipped template does not spell character for character.
@tool
class_name EventForgeCollisionFilterLift
extends RefCounted

## The fragment a line must contain before any pattern here is worth compiling. Both spellings ask
## an array whether ANY of it answers, which rules out almost every statement in a project first.
const MARK: String = ".any("

## What the row's receiver is when the line names no node: blank, which is what "this node" reads as
## on every node-scoped row in the plugin.
const BLANK_TARGET: Dictionary = {"target": ""}

## The group the generated fixtures ask about. A name rather than a bare variable, because a quoted
## name is what the field itself opens on.
const FIXTURE_GROUP: String = "\"enemies\""

## One lambda parameter, as the author may have spelled it: a name, optionally typed. Written once
## because both mentions of it in the line have to be allowed the same freedom.
const LAMBDA_NAME: String = "[A-Za-z_][A-Za-z0-9_]*"

static var _conditions: Array[Dictionary] = []


## The condition this line is, or {} when the line is not one of the two spellings.
static func match_condition(line: String) -> Dictionary:
	var text: String = line.strip_edges()
	if not text.contains(MARK):
		return {}
	return EventForgeLiftTable.match_line(condition_entries(), text)


## The two spellings, built once for the life of the session: these run on every statement of every
## opened file, and the table compiles each pattern once.
static func condition_entries() -> Array[Dictionary]:
	if _conditions.is_empty():
		_conditions = [
			{
				"id": "is_touching_group_by_overlaps",
				"ace_id": "IsTouchingGroup",
				# The lambda's parameter is captured once and BACK-REFERENCED, so a line that names one
				# thing and then asks about another is not claimed - it is doing something this row
				# does not say.
				"pattern": "^%sget_overlapping_bodies\\(\\)\\.any\\(func\\((?<lambda>%s)(?:: *[A-Za-z_][A-Za-z0-9_]*)?\\)(?: *-> *bool)?: *return \\k<lambda>\\.is_in_group\\((?<group>[^()]+)\\)\\)$" % [
					EventForgeLiftTable.receiver("target"), LAMBDA_NAME],
				"params": ["target", "group"],
				"defaults": BLANK_TARGET,
				"shape": "%sget_overlapping_bodies().any(func(__body: Node) -> bool: return __body.is_in_group({group}))"\
					% EventForgeLiftTable.optional_prefix_slot("target"),
				"slots": {"target": "$Trigger", "group": FIXTURE_GROUP}
			},
			{
				"id": "is_touching_group_by_group",
				"ace_id": "IsTouchingGroup",
				"pattern": "^get_tree\\(\\)\\.get_nodes_in_group\\((?<group>[^()]+)\\)\\.any\\(overlaps_body\\)$",
				"params": ["group"],
				"defaults": BLANK_TARGET,
				"shape": "get_tree().get_nodes_in_group({group}).any(overlaps_body)",
				"slots": {"group": FIXTURE_GROUP}
			}
		]
	return _conditions
