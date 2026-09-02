# EventForge - the three lines a menu over the running game has always been written as.
#
# A pause menu, an inventory, a dialogue box: every project that has one wrote it the same way long
# before this plugin existed, and the shape is always these three statements in this order.
#
#     var menu = load("res://pause_menu.tscn").instantiate()
#     menu.name = "PauseMenu"
#     get_tree().root.add_child(menu)
#
# THESE ARE TABLE ENTRIES (see EventForgeLiftTable), written as a RUN: an ordered list of statement
# patterns that share their captures. The engine matches them in order at the indentation each one
# says it is written at, and splices the author's own bytes back into the template exactly as it does
# for a single statement - so the round trip is the mechanism rather than a promise this file keeps.
#
# WHY THE HOLDER IS NOT A VALUE OF THE ROW. The local is named three times and all three have to
# agree for the run to be this row at all. It is therefore a shared capture - matched, agreed on and
# spliced back verbatim - rather than a parameter, the same reasoning the fade-then-remove entry uses
# for the object it names three times. Add Layout On Top's own template calls the local
# `__layout_<row id>`; a lifted row carries the author's own word for it, because the template a lift
# hands back IS the spelling that re-emits the file byte for byte.
#
# THE BOUNDARY WITH SPAWN SCENE INSTANCE, which is the whole point of being strict here. The bare
# one-liner `add_child(load("res://enemy.tscn").instantiate())` is Spawn Scene Instance and stays
# Spawn Scene Instance: it adds a copy under THIS node, so the copy belongs to the layout that
# spawned it and dies with it. That is the right reading for an enemy and the wrong one for a menu.
# What makes the run below a different row is that it adds under the TREE ROOT, which is what lets
# the thing added outlive the layout beneath it. So: no name line, or an add_child onto anything
# other than `get_tree().root`, and no entry here claims the run and the lines keep the reading they
# had.
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
# would leave a second copy nothing could ever find. Both runs are claimed - the guarded one first,
# because the three statements of the written one are inside it - so a file this plugin wrote
# re-opens as the row that wrote it and a file a person wrote opens as the same row.
#
# THE REMOVAL TWIN IS NOT HERE. Remove Layout On Top writes a guarded `get_node_or_null`, a
# `remove_child` and a `queue_free()` under an `if`; a sheet that authored one re-emits it from the
# row, and a hand-written one keeps the reading an `if` already has. Only the add is claimed,
# because only the add is a shape nothing else in a project is written as.
@tool
class_name EventForgeLayoutOnTopLift
extends RefCounted

## The row both runs mean. Frozen with the descriptor it names.
const ACE_ID: String = "AddLayoutOnTop"

## A GDScript name, as every pattern here spells one. The local a run names is a shared CAPTURE, so
## the three mentions of it are compared by the engine rather than spliced into a pattern: a pattern
## carrying somebody's identifier would mint - and hold, for the life of the session - one compiled
## RegEx per distinct local name any opened file ever used, which is unbounded static state keyed by
## another project's words.
const NAME: String = "(?<holder>[A-Za-z_][A-Za-z0-9_]*)"

## The statement that names the copy, whichever spelling the run is written in: the holder, then the
## name the layout is found again by.
const NAMED_PATTERN: String = "^%s\\.name = [ \\t]*(?<layout_name>.+?)[ \\t]*$" % NAME

## The statement that puts the copy under the tree root - what makes this run a layout rather than a
## spawn, and the one line of it that is never spelled two ways.
const ADDED_PATTERN: String = "^get_tree\\(\\)\\.root\\.add_child\\(%s\\)$" % NAME

## Built once for the life of the session: these are tried against every statement of every opened
## file, and each entry's `mark` is what rules almost all of them out before a pattern runs.
static var _entries: Array[Dictionary] = []


## The row a run of statements means, or {} when neither spelling here claims it. `lines` is the
## function body as the lifter holds it, `index` the statement to try, `depth` its indentation.
static func match_run(lines: PackedStringArray, index: int, depth: int) -> Dictionary:
	return EventForgeLiftTable.match_run(lift_entries(), lines, index, depth)


## Both spellings, as table entries. The guarded one is first because the three statements of the
## written one are the last three of it: asked the other way round, the shorter run would claim the
## inside of the longer one and leave its question stranded above.
static func lift_entries() -> Array[Dictionary]:
	if _entries.is_empty():
		_entries = [_guarded_entry(), _written_entry()]
	return _entries


## What the ROW writes: the same three statements, under the question that keeps one name to one
## layout. The name is asked about on the first line and given on the fourth, and the two have to be
## the same words - a run that looks one name up and gives another is somebody else's program, which
## is what sharing the `layout_name` capture across those two statements says.
static func _guarded_entry() -> Dictionary:
	return {
		"id": "layout_on_top_guarded",
		"ace_id": ACE_ID,
		"mark": "get_node_or_null(",
		"statements": [
			{"pattern": "^var[ \\t]+%s[ \\t]*:[ \\t]*Node[ \\t]*=[ \\t]*get_tree\\(\\)\\.root\\.get_node_or_null\\([ \\t]*(?<layout_name>.+?)[ \\t]*\\)$" % NAME},
			{"pattern": "^if %s == null:$" % NAME},
			{"pattern": "^%s[ \\t]*=[ \\t]*\\((?:pre)?load\\([ \\t]*(?<path>.*?)[ \\t]*\\) as PackedScene\\)\\.instantiate\\(\\)$" % NAME,
				"indent": 1},
			{"pattern": NAMED_PATTERN, "indent": 1},
			{"pattern": ADDED_PATTERN, "indent": 1}
		],
		"params": ["path", "layout_name"],
		"shape": "var __layout_menu: Node = get_tree().root.get_node_or_null({layout_name})\n"
			+ "if __layout_menu == null:\n"
			+ "\t__layout_menu = (load({path}) as PackedScene).instantiate()\n"
			+ "\t__layout_menu.name = {layout_name}\n"
			+ "\tget_tree().root.add_child(__layout_menu)",
		"slots": {"path": "\"res://pause_menu.tscn\"", "layout_name": "\"PauseMenu\""}
	}


## The three statements a person writes: make the copy, name it, put it under the root. The head of
## the first line is kept verbatim by the splice, so `=` or `:=` and `load` or `preload` all save
## back as themselves rather than as a canonical spelling the byte gate would then refuse.
static func _written_entry() -> Dictionary:
	return {
		"id": "layout_on_top_written",
		"ace_id": ACE_ID,
		"mark": ".instantiate()",
		"statements": [
			{"pattern": "^var[ \\t]+%s[ \\t]*:?=[ \\t]*(?:pre)?load\\([ \\t]*(?<path>.*?)[ \\t]*\\)\\.instantiate\\(\\)$" % NAME},
			{"pattern": NAMED_PATTERN},
			{"pattern": ADDED_PATTERN}
		],
		"params": ["path", "layout_name"],
		"shape": "var menu = load({path}).instantiate()\n"
			+ "menu.name = {layout_name}\n"
			+ "get_tree().root.add_child(menu)",
		"slots": {"path": "\"res://inventory.tscn\"", "layout_name": "\"Inventory\""}
	}
