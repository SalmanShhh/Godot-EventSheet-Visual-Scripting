@tool
class_name EventForgeSceneSaveLift
extends RefCounted

# EventForge - the owner walk that turns a branch of the running game into a scene file.
#
# Saving what a player built is three ideas, and everybody who has done it has written the same run:
#
#     var branch := $Level
#     for part: Node in branch.find_children("*", "", true, false):
#         if part.owner == null:
#             part.owner = branch
#     var scene := PackedScene.new()
#     scene.pack(branch)
#     ResourceSaver.save(scene, "user://built_level.tscn")
#
# WHY THIS IS A HAND-WRITTEN MATCHER AND NOT A TABLE ENTRY. EventForgeLiftTable takes ONE statement:
# a pattern, the row it means, and the captures that are values. This is a run of statements that
# only mean something together - a local made on the first line, walked over on the second, written
# through on the fourth, packed on the sixth - and the table's own header says that is exactly where
# a family stops being a pattern and becomes a matcher. The layout-on-top run beside it is entered on
# the same seam for the same reason.
#
# WHY THE WALK IS REQUIRED, which is the whole boundary this file draws. `PackedScene.pack` writes
# out the root plus every node the ROOT OWNS, and a node added while the game runs owns nothing and
# is owned by nothing - so a bare pack-and-save is a DIFFERENT program: it saves a scene holding one
# node, reports OK twice, and loads back empty. Reading it as Save Branch As Scene File would be
# claiming that a line does something it does not do, so a run with no walk in front of it is left
# exactly as it was - honest code, read as honest code.
#
# WHY THE THREE NAMES ARE NOT VALUES OF THE ROW. The branch local, the walked part and the packed
# scene are each named two or three times, and all of those namings have to agree for the run to be
# this row at all. They are therefore matched, checked, and spliced back into the template verbatim
# rather than becoming parameters - the same reasoning the layout run uses for the local it names
# three times. Save Branch As Scene File's own template calls them `__branch_<row id>`,
# `__part_<row id>` and `__scene_<row id>`; a lifted row carries the author's own words for them,
# because the template a matcher hands back IS the spelling that re-emits the file byte for byte.
#
# TWO TAILS, because the row emits one and people write the other. The row's own tail keeps both
# error answers (a pack can refuse, a write can fail); the tail a person writes by hand is usually
# the plain pack and the plain save. Both are claimed, and each rides back out in its own spelling.

## The fragment the SECOND statement of the run must contain before any pattern here is compiled.
## One substring test that rules out every line in a project but the walk itself - and it is the walk
## being spelled exactly this way that makes the run this row rather than a similar one.
const MARK: String = "find_children(\"*\", \"\", true, false)"

## The row the run means. Frozen with the descriptor it names.
const ACE_ID: String = "SaveBranchAsSceneFile"

## How many lines each tail makes the run, counting the walk in front of it.
const RUN_WITH_ANSWERS: int = 10
const RUN_PLAIN: int = 7

## The two sentences the row's own tail reports a failure with, as the emitted line spells them.
## Matched exactly rather than loosely: a run whose error answers say something else is somebody's
## own code, and re-emitting it through this row would change what their game prints.
const PACK_FAILURE: String = "\tpush_error(\"Save Branch As Scene File: %s could not be packed (error %d).\" % [{branch_local}.name, {packed_local}])"
const WRITE_FAILURE: String = "\tpush_error(\"Save Branch As Scene File: nothing was written to %s.\" % {path})"

## Compiled patterns, built once for the life of the session: this runs on every statement of every
## opened file.
static var _regexes: Dictionary = {}


## The row a run of statements means, or {} when this family does not claim it. `lines` is the
## function body as the lifter holds it, `index` the statement to try, `depth` its indentation.
## Returns {ace_id, params, template, consumed}.
static func match_run(lines: PackedStringArray, index: int, depth: int) -> Dictionary:
	if index + 1 >= lines.size() or not lines[index + 1].contains(MARK):
		return {}
	# Group 1 is the whole head of the line - `var branch := ` - kept verbatim so the template
	# re-emits the author's own spelling of it (`=`, `:=`, or a written-out `: Node =`) rather than a
	# canonical one the byte gate would then refuse.
	var made: RegExMatch = _regex("^(var[ \\t]+([A-Za-z_][A-Za-z0-9_]*)(?:[ \\t]*:[ \\t]*Node)?[ \\t]*:?=[ \\t]*)(.+)$").search(
		_at(lines, index, depth, 0))
	if made == null:
		return {}
	var branch_local: String = made.get_string(2)
	var walked: RegExMatch = _regex("^for[ \\t]+([A-Za-z_][A-Za-z0-9_]*)(?:[ \\t]*:[ \\t]*Node)?[ \\t]+in[ \\t]+%s\\.find_children\\(\"\\*\", \"\", true, false\\):$" % branch_local).search(
		_at(lines, index + 1, depth, 0))
	if walked == null:
		return {}
	var part_local: String = walked.get_string(1)
	if _at(lines, index + 2, depth, 1) != "if %s.owner == null:" % part_local:
		return {}
	if _at(lines, index + 3, depth, 2) != "%s.owner = %s" % [part_local, branch_local]:
		return {}
	var scene: RegExMatch = _regex("^var[ \\t]+([A-Za-z_][A-Za-z0-9_]*)[ \\t]*:?=[ \\t]*PackedScene\\.new\\(\\)$").search(
		_at(lines, index + 4, depth, 0))
	if scene == null:
		return {}
	var head: PackedStringArray = PackedStringArray([
		"%s{branch}" % made.get_string(1),
		_at(lines, index + 1, depth, 0),
		"\t" + _at(lines, index + 2, depth, 1),
		"\t\t" + _at(lines, index + 3, depth, 2),
		_at(lines, index + 4, depth, 0),
	])
	var claimed: Dictionary = _with_answers(lines, index, depth, branch_local, scene.get_string(1))
	if claimed.is_empty():
		claimed = _plain(lines, index, depth, branch_local, scene.get_string(1))
	if claimed.is_empty():
		return {}
	var tail: PackedStringArray = claimed["lines"]
	head.append_array(tail)
	return {
		"ace_id": ACE_ID,
		"params": {"branch": made.get_string(3).strip_edges(), "path": str(claimed["path"])},
		"template": "\n".join(head),
		"consumed": int(claimed["consumed"])
	}


## The tail the ROW itself writes: the pack held in a local, and the two failures answered. Every
## line but the write is compared against the exact text the row emits, so a run that reports
## something else of its own is not claimed.
static func _with_answers(lines: PackedStringArray, index: int, depth: int, branch_local: String,
		scene_local: String) -> Dictionary:
	var packed: RegExMatch = _regex("^var[ \\t]+([A-Za-z_][A-Za-z0-9_]*)[ \\t]*:?=[ \\t]*%s\\.pack\\(%s\\)$" % [
		scene_local, branch_local]).search(_at(lines, index + 5, depth, 0))
	if packed == null:
		return {}
	var packed_local: String = packed.get_string(1)
	if _at(lines, index + 6, depth, 0) != "if %s != OK:" % packed_local:
		return {}
	if "\t" + _at(lines, index + 7, depth, 1) != _pack_failure(branch_local, packed_local):
		return {}
	var written: RegExMatch = _regex("^elif ResourceSaver\\.save\\(%s, (.+)\\) != OK:$" % scene_local).search(
		_at(lines, index + 8, depth, 0))
	if written == null:
		return {}
	var path: String = written.get_string(1).strip_edges()
	if "\t" + _at(lines, index + 9, depth, 1) != WRITE_FAILURE.replace("{path}", path):
		return {}
	return {
		"path": path,
		"consumed": RUN_WITH_ANSWERS,
		"lines": PackedStringArray([
			_at(lines, index + 5, depth, 0),
			_at(lines, index + 6, depth, 0),
			_pack_failure(branch_local, packed_local),
			"elif ResourceSaver.save(%s, {path}) != OK:" % scene_local,
			WRITE_FAILURE,
		])
	}


## The tail a person writes by hand: pack it, save it, and let the engine's own console say so if
## either refuses.
static func _plain(lines: PackedStringArray, index: int, depth: int, branch_local: String,
		scene_local: String) -> Dictionary:
	if _at(lines, index + 5, depth, 0) != "%s.pack(%s)" % [scene_local, branch_local]:
		return {}
	var written: RegExMatch = _regex("^ResourceSaver\\.save\\(%s, (.+)\\)$" % scene_local).search(
		_at(lines, index + 6, depth, 0))
	if written == null:
		return {}
	return {
		"path": written.get_string(1).strip_edges(),
		"consumed": RUN_PLAIN,
		"lines": PackedStringArray([
			_at(lines, index + 5, depth, 0),
			"ResourceSaver.save(%s, {path})" % scene_local,
		])
	}


## The pack failure as this run spells it, with the two locals filled in.
static func _pack_failure(branch_local: String, packed_local: String) -> String:
	return PACK_FAILURE.replace("{branch_local}", branch_local).replace("{packed_local}", packed_local)


## One line of the body at exactly `depth + extra` tabs, or "" when the line is blank, absent,
## shallower, or deeper than that. Deeper matters here in a way it does not for a run of plain
## statements: the walk has a block inside it, and each of those lines is claimed at the one
## indentation it is allowed to be at.
static func _at(lines: PackedStringArray, index: int, depth: int, extra: int) -> String:
	if index < 0 or index >= lines.size():
		return ""
	var line: String = lines[index]
	var indent: int = depth + extra
	if not line.begins_with("\t".repeat(indent)):
		return ""
	var rest: String = line.substr(indent)
	if rest.begins_with("\t") or rest.strip_edges().is_empty():
		return ""
	return rest


## A pattern, compiled once and held.
static func _regex(pattern: String) -> RegEx:
	if not _regexes.has(pattern):
		_regexes[pattern] = RegEx.create_from_string(pattern)
	return _regexes[pattern]
