@tool
class_name EventForgeLayoutOnTopLift
extends RefCounted

# EventForge - the three lines a menu over the running game has always been written as.
#
# A pause menu, an inventory, a dialogue box: every project that has one wrote it the same way long
# before this plugin existed, and the shape is always these three statements in this order.
#
#     var menu = load("res://pause_menu.tscn").instantiate()
#     menu.name = "PauseMenu"
#     get_tree().root.add_child(menu)
#
# WHY THIS IS A HAND-WRITTEN MATCHER AND NOT A TABLE ENTRY. EventForgeLiftTable takes ONE statement:
# a pattern, the row it means, and the captures that are values. This family is three statements that
# only mean something together - a local made on the first line, named on the second and placed on
# the third - and the table's own header says that is where a family stops being a pattern. The
# networking runs beside it (EventForgeMultiplayerLift.match_run) are hand-written for exactly this
# reason, and this matcher is entered the same way, on the same seam, one line after them.
#
# WHY THE HOLDER IS NOT A VALUE OF THE ROW. The local is named three times and all three have to
# agree for the run to be this row at all. It is therefore matched, checked, and spliced back into
# the template verbatim rather than becoming a parameter - the same reasoning the fade-then-remove
# entry uses for the object it names three times. Add Layout On Top's own template calls the local
# `__layout_<row id>`; a lifted row carries the author's own word for it, because the template a
# matcher hands back IS the spelling that re-emits the file byte for byte.
#
# THE BOUNDARY WITH SPAWN SCENE INSTANCE, which is the whole point of being strict here. The bare
# one-liner `add_child(load("res://enemy.tscn").instantiate())` is Spawn Scene Instance and stays
# Spawn Scene Instance: it adds a copy under THIS node, so the copy belongs to the layout that
# spawned it and dies with it. That is the right reading for an enemy and the wrong one for a menu.
# What makes the run below a different row is that it adds under the TREE ROOT, which is what lets
# the thing added outlive the layout beneath it. So: no name line, or an add_child onto anything
# other than `get_tree().root`, and this matcher refuses and the lines keep the reading they had.
#
# THE REMOVAL TWIN IS NOT HERE. Remove Layout On Top writes a guarded `get_node_or_null` and a
# `queue_free()` under an `if`, which is a BLOCK rather than a run of statements; a sheet that
# authored one re-emits it from the row, and a hand-written one keeps the reading an `if` already
# has. Only the add is claimed, because only the add is an unambiguous three-statement shape.

## The fragment a statement must contain before any pattern here is compiled - one word that rules
## out almost every line in a project first.
const MARK: String = ".instantiate()"

## The row the run below means. Frozen with the descriptor it names.
const ACE_ID: String = "AddLayoutOnTop"

## How many statements the run is, when it matches at all.
const RUN_LENGTH: int = 3

## Compiled patterns, built once for the life of the session: this runs on every statement of every
## opened file.
static var _regexes: Dictionary = {}


## The row a run of statements means, or {} when this family does not claim it. `lines` is the
## function body as the lifter holds it, `index` the statement to try, `depth` its indentation.
## Returns {ace_id, params, template, consumed}.
static func match_run(lines: PackedStringArray, index: int, depth: int) -> Dictionary:
	var opener: String = _statement_at(lines, index, depth)
	if not opener.contains(MARK):
		return {}
	# Group 1 is the whole head of the line - `var menu = load` - kept verbatim so the template
	# re-emits the author's own spelling of it (`=` or `:=`, `load` or `preload`) rather than a
	# canonical one the byte gate would then refuse.
	var made: RegExMatch = _regex("^(var[ \\t]+([A-Za-z_][A-Za-z0-9_]*)[ \\t]*:?=[ \\t]*(?:pre)?load)\\((.*)\\)\\.instantiate\\(\\)$").search(opener)
	if made == null:
		return {}
	var holder: String = made.get_string(2)
	var named: RegExMatch = _regex("^%s\\.name = (.+)$" % holder).search(_statement_at(lines, index + 1, depth))
	if named == null:
		return {}
	if _statement_at(lines, index + 2, depth) != "get_tree().root.add_child(%s)" % holder:
		return {}
	return {
		"ace_id": ACE_ID,
		"params": {
			"path": made.get_string(3).strip_edges(),
			"layout_name": named.get_string(1).strip_edges()
		},
		"template": "\n".join(PackedStringArray([
			"%s({path}).instantiate()" % made.get_string(1),
			"%s.name = {layout_name}" % holder,
			"get_tree().root.add_child(%s)" % holder
		])),
		"consumed": RUN_LENGTH
	}


## One statement of the body at the given indentation, or "" when the line is blank, absent, or
## deeper than the run being matched (a deeper line is inside a block, not the next statement).
static func _statement_at(lines: PackedStringArray, index: int, depth: int) -> String:
	if index < 0 or index >= lines.size():
		return ""
	var line: String = lines[index]
	if not line.begins_with("\t".repeat(depth)):
		return ""
	var rest: String = line.substr(depth)
	if rest.begins_with("\t") or rest.strip_edges().is_empty():
		return ""
	return rest


## A pattern, compiled once and held.
static func _regex(pattern: String) -> RegEx:
	if not _regexes.has(pattern):
		_regexes[pattern] = RegEx.create_from_string(pattern)
	return _regexes[pattern]
