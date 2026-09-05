# EventForge - the question a project puts to the physics world DIRECTLY, in the shape the engine's
# own pages spell it.
#
# A ray asked of the space state is three statements, and it has been those three statements in every
# Godot project since 4.0, because it is the shape the manual prints:
#
#     var space_state := get_world_2d().direct_space_state
#     var query := PhysicsRayQueryParameters2D.create(global_position, target.global_position)
#     var sight := space_state.intersect_ray(query)
#
# Until this file existed a sheet read those as three declarations - "Set Local Variable" three times
# over, each of them true and none of them the sentence. The row they mean has shipped since the
# raycasting wave: Cast Ray Into, whose own spelling of the same job hoists the query into a `__rq_`
# local. Both are the row; this is the half that recognises the one a person writes.
#
# WHAT IS AND IS NOT A VALUE OF THE ROW. The two locals - the space state and the query - are named
# twice each and both mentions have to agree for the run to be this row at all, so they are SHARED
# CAPTURES: matched, agreed on, and spliced back verbatim, never parameters. `from`, `to` and the
# variable the hit lands in are the row's, and the collision mask is too when the run sets one.
#
# THE PARAMETERS THE LINE DOES NOT SPELL ARE LEFT UNSAID rather than given a blank. Godot's own
# defaults for a bare `create(from, to)` are every layer, nothing excluded and areas ignored, which
# is exactly what the descriptor's own defaults say - so a lifted row that has never been edited
# holds three values fewer than a picked one, and the moment somebody opens it the dialog offers the
# descriptor's defaults, which describe the line that is already there.
#
# THE ONE-LINE SPELLING IS ITS OWN ENTRY, because a choice is the thing a table cannot check: the
# compact form nests the query inside the call and names no locals at all, so it shares no pattern
# with the run and is written out separately, exactly as the hand-written tables already write two
# spellings as two entries.
#
# WHAT IS DELIBERATELY LEFT AS CODE. A SHAPE query (`PhysicsShapeQueryParameters2D.new()`, a shape
# built beside it, `intersect_shape`) and a POINT query have no shipped row that means the same job:
# the vocabulary's Query Bodies rows build their own shape and loop the results, which is a different
# program from a hand-written sweep that hands the array back. Nothing here claims them, so they stay
# the honest code they are and are counted out loud - a table that guessed a near-enough row would
# cost the reader more than the sentence gained.
@tool
class_name EventForgePhysicsQueryLift
extends RefCounted

## The row a 2D cast means, and its 3D twin. Frozen with the descriptors they name.
const ACE_ID_2D: String = "CastRayInto2D"
const ACE_ID_3D: String = "CastRayInto3D"

## The fragment every statement here contains. One `contains` rules out all but a handful of lines in
## a project before any pattern of this file runs, which is what the run seam is asked for per
## statement of every opened file.
const MARK: String = "direct_space_state"

## A local's name, as this file spells one. Shared captures rather than pattern text: a pattern
## carrying somebody's identifier would mint one compiled RegEx per distinct local name any opened
## file ever used, which is unbounded static state keyed by another project's words.
const NAME: String = EventForgeLiftGrammar.IDENTIFIER

## The head of a local declaration, from just after the name to the value: the three spellings Godot
## takes (`x = v`, `x := v`, `x: Type = v`) as one optional-type-then-assign run. THE SHARED
## GRAMMAR'S, not this family's own: five families were spelling the same run by hand at a dozen
## sites, and the day one of them widens which types the colon may carry the others must widen with
## it. Named here so the four patterns below still read as sentences.
const ASSIGN: String = EventForgeLiftGrammar.DECLARATION_HEAD

## The two ends of a ray, as the `create` call carries them. `to` is the EXPRESSION that runs to the
## closing bracket - the wide span, so `global_position + Vector2(0, 100)` is one value and not two -
## and `from` is the plain one in front of it.
##
## PLAIN MEANS NO BRACKET OF ANY KIND, not merely no comma. The shared grammar's argument span stops
## at a comma or a closing bracket, which reads `create(Vector2(0, 0), b)` as a `from` of `Vector2(0`
## and a `to` of `0), b`: two chips that are not expressions, spliced back into a line that still
## saves byte for byte, so nothing downstream would ever have said the split was wrong. A span that
## refuses brackets outright cannot make that mistake - a `from` with a call in it is simply not
## claimed, and the run keeps the reading it had.
const ENDS: String = "(?<from>[^,()\\[\\]]+)" + EventForgeLiftGrammar.SEPARATOR + "(?<to>.+)"

static var _entries: Array[Dictionary] = []


## The row one statement means, or {} when no spelling here claims it - the compact one-line cast.
static func match_line(line: String) -> Dictionary:
	var text: String = line.strip_edges()
	if not text.contains(MARK):
		return {}
	return EventForgeLiftTable.match_line(lift_entries(), text)


## The row a RUN of statements means, or {} when none of the spellings here claims it.
static func match_run(lines: PackedStringArray, index: int, depth: int) -> Dictionary:
	return EventForgeLiftTable.match_run(lift_entries(), lines, index, depth)


## Every spelling, built once for the life of the session.
##
## ORDER IS MEANING: the run that sets a mask is asked before the run that does not, because the
## three statements of the plain run are not the first three of the masked one and a reader meeting
## this list should still find the narrower spelling above the wider one. The one-line form sits last
## because it opens on a shape neither run can match.
static func lift_entries() -> Array[Dictionary]:
	if _entries.is_empty():
		_entries = [
			_masked_run(ACE_ID_2D, "2D", "ray_query_masked_run_2d"),
			_masked_run(ACE_ID_3D, "3D", "ray_query_masked_run_3d"),
			_plain_run(ACE_ID_2D, "2D", "ray_query_run_2d"),
			_plain_run(ACE_ID_3D, "3D", "ray_query_run_3d"),
			_one_line(ACE_ID_2D, "2D", "ray_query_line_2d"),
			_one_line(ACE_ID_3D, "3D", "ray_query_line_3d")
		]
	return _entries


# ── the spellings ───────────────────────────────────────────────────────────────


## The three statements the manual prints: reach for the space state, describe the ray, ask it.
static func _plain_run(ace_id: String, dimension: String, id: String) -> Dictionary:
	return {
		"id": id,
		"ace_id": ace_id,
		"mark": MARK,
		"statements": [_space_statement(dimension), _query_statement(dimension), _cast_statement()],
		"params": ["into", "from", "to"],
		"shape": _run_shape(dimension, false),
		"slots": _slots(false)
	}


## The same run with the one line almost every real cast grows: the layers it is allowed to hit.
static func _masked_run(ace_id: String, dimension: String, id: String) -> Dictionary:
	return {
		"id": id,
		"ace_id": ace_id,
		"mark": MARK,
		"statements": [_space_statement(dimension), _query_statement(dimension),
			{"pattern": "^(?<query>%s)\\.collision_mask = (?<mask>.+)$" % NAME}, _cast_statement()],
		"params": ["into", "from", "to", "mask"],
		"shape": _run_shape(dimension, true),
		"slots": _slots(true)
	}


## The compact spelling: the query nested inside the call, no locals at all.
static func _one_line(ace_id: String, dimension: String, id: String) -> Dictionary:
	return {
		"id": id,
		"ace_id": ace_id,
		"mark": MARK,
		"pattern": "^var[ \\t]+(?<into>%s)%s%s\\.intersect_ray\\(%s\\.create\\(%s\\)\\)$" % [
			NAME, ASSIGN, _space_pattern(dimension), _query_class(dimension), ENDS],
		"params": ["into", "from", "to"],
		"shape": "var {into} := %s.intersect_ray(%s.create({from}, {to}))" % [
			_space_call(dimension), _query_class(dimension)],
		"slots": _slots(false)
	}


## `var space_state := get_world_2d().direct_space_state` - the local the cast is asked of.
static func _space_statement(dimension: String) -> Dictionary:
	return {"pattern": "^var[ \\t]+(?<space>%s)%s%s$" % [NAME, ASSIGN, _space_pattern(dimension)]}


## `var query := PhysicsRayQueryParameters2D.create(from, to)` - the ray, described.
static func _query_statement(dimension: String) -> Dictionary:
	return {"pattern": "^var[ \\t]+(?<query>%s)%s%s\\.create\\(%s\\)$" % [
		NAME, ASSIGN, _query_class(dimension), ENDS]}


## `var sight := space_state.intersect_ray(query)` - the question, and where the answer lands.
static func _cast_statement() -> Dictionary:
	return {"pattern": "^var[ \\t]+(?<into>%s)%s(?<space>%s)\\.intersect_ray\\((?<query>%s)\\)$" % [
		NAME, ASSIGN, NAME, NAME]}


## The whole run as one canonical text - what the harness generates this entry's fixture from.
static func _run_shape(dimension: String, masked: bool) -> String:
	var written: PackedStringArray = PackedStringArray([
		"var space_state := %s" % _space_call(dimension),
		"var query := %s.create({from}, {to})" % _query_class(dimension)])
	if masked:
		written.append("query.collision_mask = {mask}")
	written.append("var {into} := space_state.intersect_ray(query)")
	return "\n".join(written)


## The sample values the fixture line is written with. Both dimensions share them: the words are a
## test's, not a coordinate's, and a Vector literal here would put a comma inside `from`, which is
## the one thing these patterns decline to take apart.
static func _slots(masked: bool) -> Dictionary:
	var slots: Dictionary = {"from": "global_position", "to": "target.global_position",
		"into": "sight"}
	if masked:
		slots["mask"] = "2"
	return slots


## `get_world_2d().direct_space_state` as a shape spells it - the text the emitter writes back.
static func _space_call(dimension: String) -> String:
	return "get_world_%s().direct_space_state" % dimension.to_lower()


## The same call as a PATTERN matches it, through the one escaper every family shares: the brackets
## and the dot are the author's characters, not instructions to the engine.
static func _space_pattern(dimension: String) -> String:
	return EventForgeLiftGrammar.escaped_run(_space_call(dimension))


## The parameters class the ray is described with, per dimension.
static func _query_class(dimension: String) -> String:
	return "PhysicsRayQueryParameters%s" % dimension
