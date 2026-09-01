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
# TWO SPELLINGS OF ONE ROW, because the row and the reader write it differently. The three
# statements above are what a person types. What the ROW emits asks the name first:
#
#     var __layout_a1: Node = get_tree().root.get_node_or_null("PauseMenu")
#     if __layout_a1 == null:
#         __layout_a1 = (load("res://pause_menu.tscn") as PackedScene).instantiate()
#         __layout_a1.name = "PauseMenu"
#         get_tree().root.add_child(__layout_a1)
#
# because `add_child` refuses a name a sibling already has and renames the newcomer instead, which
# would leave a second copy nothing could ever find. Both runs are claimed, so a file this plugin
# wrote re-opens as the row that wrote it and a file a person wrote opens as the same row.
#
# THE REMOVAL TWIN IS NOT HERE. Remove Layout On Top writes a guarded `get_node_or_null`, a
# `remove_child` and a `queue_free()` under an `if`; a sheet that authored one re-emits it from the
# row, and a hand-written one keeps the reading an `if` already has. Only the add is claimed,
# because only the add is a shape nothing else in a project is written as.

## The fragment a statement must contain before any pattern here is compiled - one word that rules
## out almost every line in a project first. The guarded spelling carries it on its third line, so
## the run is entered on either.
const MARK: String = ".instantiate()"

## The row both runs below mean. Frozen with the descriptor it names.
const ACE_ID: String = "AddLayoutOnTop"

## How many statements each spelling is: the three a person writes, and the five the row emits.
const RUN_LENGTH: int = 3
const GUARDED_LENGTH: int = 5

## Compiled patterns, built once for the life of the session: this runs on every statement of every
## opened file.
static var _regexes: Dictionary = {}


## The row a run of statements means, or {} when this family does not claim it. `lines` is the
## function body as the lifter holds it, `index` the statement to try, `depth` its indentation.
## Returns {ace_id, params, template, consumed}.
static func match_run(lines: PackedStringArray, index: int, depth: int) -> Dictionary:
	var guarded: Dictionary = _guarded_run(lines, index, depth)
	return guarded if not guarded.is_empty() else _plain_run(lines, index, depth)


## The three statements a person writes: make the copy, name it, put it under the root.
static func _plain_run(lines: PackedStringArray, index: int, depth: int) -> Dictionary:
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
	var named: RegExMatch = _regex(NAMED_PATTERN).search(_statement_at(lines, index + 1, depth))
	if named == null or named.get_string(1) != holder:
		return {}
	if _statement_at(lines, index + 2, depth) != _added(holder):
		return {}
	var run: PackedStringArray = PackedStringArray(["%s({path}).instantiate()" % made.get_string(1),
		"%s.name = {layout_name}" % holder, _added(holder)])
	return _claim(made.get_string(3), named.get_string(2), run, RUN_LENGTH)


## What the ROW writes: the same three statements, under the question that keeps one name to one
## layout. The name is asked about on the first line and given on the fourth, and the two have to be
## the same words - a run that looks one name up and gives another is somebody else's program.
static func _guarded_run(lines: PackedStringArray, index: int, depth: int) -> Dictionary:
	var looked: RegExMatch = _regex("^var[ \\t]+([A-Za-z_][A-Za-z0-9_]*)[ \\t]*:[ \\t]*Node[ \\t]*=[ \\t]*get_tree\\(\\)\\.root\\.get_node_or_null\\((.+)\\)$").search(
		_statement_at(lines, index, depth))
	if looked == null:
		return {}
	var holder: String = looked.get_string(1)
	if _statement_at(lines, index + 1, depth) != "if %s == null:" % holder:
		return {}
	var opener: String = _inside_at(lines, index + 2, depth)
	if not opener.contains(MARK):
		return {}
	var made: RegExMatch = _regex("^(%s[ \\t]*=[ \\t]*\\((?:pre)?load)\\((.*)\\)( as PackedScene\\))\\.instantiate\\(\\)$" % holder).search(opener)
	if made == null:
		return {}
	var named: RegExMatch = _regex(NAMED_PATTERN).search(_inside_at(lines, index + 3, depth))
	if named == null or named.get_string(1) != holder:
		return {}
	if named.get_string(2).strip_edges() != looked.get_string(2).strip_edges():
		return {}
	if _inside_at(lines, index + 4, depth) != _added(holder):
		return {}
	var run: PackedStringArray = PackedStringArray([
		"var %s: Node = get_tree().root.get_node_or_null({layout_name})" % holder,
		"if %s == null:" % holder,
		"\t%s({path})%s.instantiate()" % [made.get_string(1), made.get_string(3)],
		"\t%s.name = {layout_name}" % holder, "\t" + _added(holder)])
	return _claim(made.get_string(2), named.get_string(2), run, GUARDED_LENGTH)


## The statement that names the copy, whichever spelling it is written in: the holder, then the name.
const NAMED_PATTERN: String = "^([A-Za-z_][A-Za-z0-9_]*)\\.name = (.+)$"


## The line that puts one copy under the tree root - what makes this run a layout rather than a
## spawn, and the one line of it that is never spelled two ways.
static func _added(holder: String) -> String:
	return "get_tree().root.add_child(%s)" % holder


## One matched run as the lifter takes it: the row, its two values, the template that re-emits the
## author's own spelling of it, and how many statements it swallowed.
static func _claim(path: String, layout_name: String, run: PackedStringArray,
		consumed: int) -> Dictionary:
	var values: Dictionary = {"path": path.strip_edges(), "layout_name": layout_name.strip_edges()}
	return {"ace_id": ACE_ID, "params": values, "template": "\n".join(run), "consumed": consumed}


## One statement of the body at the given indentation, or "" when the line is blank, absent, or
## deeper than the run being matched (a deeper line is inside a block, not the next statement).
static func _statement_at(lines: PackedStringArray, index: int, depth: int) -> String:
	return _at(lines, index, depth)


## One statement INSIDE the guarded run's block - one tab further in, and no further than that.
static func _inside_at(lines: PackedStringArray, index: int, depth: int) -> String:
	return _at(lines, index, depth + 1)


static func _at(lines: PackedStringArray, index: int, depth: int) -> String:
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
