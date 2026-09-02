@tool
class_name EventForgeUndoableEditLift
extends RefCounted

# EventForge - reading a tool's undoable edits back off the file.
#
# A change made through the editor's undo manager is never one statement. It is a local holding the
# manager, a do half, an undo half, and for the two that move a node a reference so the step can put
# the same node back:
#
#     EditorInterface.get_editor_undo_redo().create_action("On Editor Run")
#     var undo := EditorInterface.get_editor_undo_redo()
#     undo.add_do_property($Sign, &"text", "Open")
#     undo.add_undo_property($Sign, &"text", $Sign.text)
#     EditorInterface.get_editor_undo_redo().commit_action()
#
# WHY THIS IS STILL A HAND-WRITTEN MATCHER. EventForgeLiftTable takes a RUN of statements now - an
# ordered list of patterns sharing their captures - and a family whose run is a fixed list of
# statements is written that way (the layout-on-top one is). This one is not a fixed list: the
# bracket around the edit is found by SCANNING for the commit that closes it, however many statements
# away that is, and the gesture the bracket names is read from the sheet's own vocabulary rather than
# from the lines. A pattern list cannot say "and somewhere below, the line that closes this".
# The one-statement dignities of the same pass ARE table entries, in node_dignity_lift.gd.
#
# THE BRACKET IS NOT A ROW, which is the one thing that makes this family different from its
# neighbours. create_action and commit_action are written by the COMPILER around the undoable rows of
# one event - the one-gesture rule - so there is nothing for them to lift INTO: handing them back as
# rows would put two rows on the sheet that the sheet did not have, and the next save would write the
# bracket twice. They are recognised and consumed instead, and re-appear because the compiler writes
# them again. That is only safe while the bracket the file carries is the bracket the compiler would
# write, so bracket_span checks the NAME as well as the shape and refuses anything else - a tool whose
# author named their own action keeps it, verbatim, exactly as they wrote it.
#
# THE LOCAL NAMES ARE NOT VALUES OF THE ROW. The manager local, the node local and the parent local
# are each named two to four times, and all of those namings have to agree for the run to be this row
# at all. They are matched, checked, and spliced back into the template verbatim rather than becoming
# parameters - the same reasoning the scene-save run uses for the three names it holds - so a lifted
# row carries the author's own words for them and re-emits the file byte for byte.

## The one place the bracket's own spelling lives, by PATH rather than by class name - the importer
## never waits on the editor's class cache, which is the rule every constant in this folder follows.
const UndoableEdits := preload("res://addons/eventforge/undoable_edits.gd")

## The rows these runs mean. Frozen with the descriptors they name.
const SET_PROPERTY: String = "SetPropertyUndoable"
const ADD_NODE: String = "AddNodeUndoable"
const REMOVE_NODE: String = "RemoveNodeUndoable"

## The fragment a run must contain in one of its opening statements before any pattern here is
## compiled. A handful of substring tests that rule out every line in a project but these runs.
const MARK: String = "EditorInterface.get_editor_undo_redo()"

## How far into a run the manager local can be. Fourth line at the latest: the removal run reads the
## node, its parent and its place among its siblings before it asks for the history, which is two
## lines deeper than the property run beside it.
const MARK_WITHIN: int = 4

## How many statements each run is. Each of the two that read something into a local FIRST is claimed
## in both spellings - with that local and without it - because the row writes one and a person
## writing by hand usually writes the other, and both mean this row.
const RUN_SET_PROPERTY: int = 3
const RUN_ADD_NODE: int = 6
const RUN_REMOVE_NODE: int = 7

## A GDScript name, as every pattern here spells one.
const NAME: String = "[A-Za-z_][A-Za-z0-9_]*"

## Compiled patterns, built once for the life of the session: this runs on every statement of every
## opened file.
static var _regexes: Dictionary = {}


## The row a run of statements means, or {} when this family does not claim it. `lines` is the
## function body as the lifter holds it, `index` the statement to try, `depth` its indentation.
## Returns {ace_id, params, template, consumed}.
##
## The removal run is tried FIRST because it and the add run open with the same statement (a local
## holding the node), and the removal is the more specific of the two: its second line asks the node
## for its parent, which the add run has no use for.
static func match_run(lines: PackedStringArray, index: int, depth: int) -> Dictionary:
	if index + 1 >= lines.size():
		return {}
	var marked: bool = false
	for step: int in MARK_WITHIN:
		if index + step < lines.size() and lines[index + step].contains(MARK):
			marked = true
			break
	if not marked:
		return {}
	var claimed: Dictionary = _match_remove(lines, index, depth)
	if claimed.is_empty():
		claimed = _match_add(lines, index, depth)
	if claimed.is_empty():
		claimed = _match_set_property(lines, index, depth)
	return claimed


## Where the gesture opened at `index` is committed, or -1 when this is not a bracket this plugin
## wrote. `gesture` is the name the compiler WOULD write here, which the caller reads off the event's
## own trigger - so a bracket carrying anybody else's name is left exactly as it is.
##
## The scan walks to the commit line at the same indentation, allowing ordinary statements between
## the undoable runs (the compiler brackets from the first undoable row to the last, and a plain row
## may stand between two of them). At least one run has to be claimed, because a bracket around
## nothing this family recognises would be consumed here and never written again.
static func bracket_span(lines: PackedStringArray, index: int, depth: int, gesture: String) -> int:
	if _at(lines, index, depth) != UndoableEdits.create_line(gesture):
		return -1
	var indent: String = "\t".repeat(depth)
	var claimed: int = 0
	var scan: int = index + 1
	while scan < lines.size():
		var line: String = lines[scan]
		if line.strip_edges().is_empty() or not line.begins_with(indent):
			return -1
		var text: String = _at(lines, scan, depth)
		if text.is_empty():
			scan += 1  # a line deeper than this block - part of a statement already being read
			continue
		if text == UndoableEdits.COMMIT_LINE:
			return scan if claimed > 0 else -1
		var run: Dictionary = match_run(lines, scan, depth)
		if run.is_empty():
			scan += 1
			continue
		claimed += 1
		scan += int(run["consumed"])
	return -1


## Set Property (Undoable): the node read into a local, the manager local, the do half, and the undo
## half that reads the value still in place. The undo half is compared against the exact text those
## captures make rather than matched again - the two halves have to name the same node and the same
## property for the run to be this row, and comparing is how that is said without escaping a captured
## expression into a pattern.
##
## THE LOCAL IS OPTIONAL because both spellings are this row. The row itself reads the target once
## into a local, since the expression a field holds may answer something different every time it is
## asked; a tool written by hand usually names the node in all three places instead, and that run is
## claimed too, with the node's own expression riding back out as the row's value.
static func _match_set_property(lines: PackedStringArray, index: int, depth: int) -> Dictionary:
	var held: RegExMatch = _regex("^(var[ \\t]+(%s)[ \\t]*:[ \\t]*Node[ \\t]*=[ \\t]*)(.+)$" % NAME).search(
		_at(lines, index, depth))
	var kept: int = 0 if held == null else 1
	var made: RegExMatch = _regex("^(var[ \\t]+(%s)[ \\t]*:?=[ \\t]*)EditorInterface\\.get_editor_undo_redo\\(\\)$" % NAME).search(
		_at(lines, index + kept, depth))
	if made == null:
		return {}
	var undo_local: String = made.get_string(2)
	var did: RegExMatch = _regex("^(?<undo>%s)\\.add_do_property\\((?<target>.+), &\"(?<property>%s)\", (?<value>.+)\\)$" % [
		NAME, NAME]).search(_at(lines, index + 1 + kept, depth))
	if did == null or did.get_string("undo") != undo_local:
		return {}
	# The receiver the two halves name: the local when the run reads one, and the target expression
	# itself when it does not. When there is a local, the do half has to be written on THAT local -
	# a run that reads one node and then writes another is somebody else's program.
	var receiver: String = did.get_string("target")
	if kept == 1 and receiver != held.get_string(2):
		return {}
	var property: String = did.get_string("property")
	if _at(lines, index + 2 + kept, depth) != "%s.add_undo_property(%s, &\"%s\", %s.%s)" % [
			undo_local, receiver, property, receiver, property]:
		return {}
	var run: PackedStringArray = PackedStringArray()
	if kept == 1:
		run.append("%s{target}" % held.get_string(1))
	run.append("%sEditorInterface.get_editor_undo_redo()" % made.get_string(1))
	var named: String = receiver if kept == 1 else "{target}"
	run.append("%s.add_do_property(%s, &\"{property}\", {value})" % [undo_local, named])
	run.append("%s.add_undo_property(%s, &\"{property}\", %s.{property})" % [
		undo_local, named, named])
	var values: Dictionary = {"target": receiver if kept == 0 else held.get_string(3),
		"property": property, "value": did.get_string("value")}
	return {"ace_id": SET_PROPERTY, "params": values, "template": "\n".join(run),
		"consumed": RUN_SET_PROPERTY + kept}


## Add Node (Undoable): the node local, the manager local, the three do halves (parent it, own it,
## hold it) and the undo half that takes it back out again.
static func _match_add(lines: PackedStringArray, index: int, depth: int) -> Dictionary:
	var held: RegExMatch = _regex("^(var[ \\t]+(%s)(?:[ \\t]*:[ \\t]*Node)?[ \\t]*:?=[ \\t]*)(.+)$" % NAME).search(
		_at(lines, index, depth))
	if held == null:
		return {}
	var node_local: String = held.get_string(2)
	var made: RegExMatch = _regex("^(var[ \\t]+(%s)[ \\t]*:?=[ \\t]*)EditorInterface\\.get_editor_undo_redo\\(\\)$" % NAME).search(
		_at(lines, index + 1, depth))
	if made == null:
		return {}
	var undo_local: String = made.get_string(2)
	var parented: RegExMatch = _regex("^(?<undo>%s)\\.add_do_method\\((?<parent>.+), \"add_child\", (?<node>%s)\\)$" % [
		NAME, NAME]).search(_at(lines, index + 2, depth))
	if parented == null or parented.get_string("undo") != undo_local \
			or parented.get_string("node") != node_local:
		return {}
	var parent: String = parented.get_string("parent")
	if _at(lines, index + 3, depth) != "%s.add_do_method(%s, \"set_owner\", EditorInterface.get_edited_scene_root())" % [
			undo_local, node_local]:
		return {}
	if _at(lines, index + 4, depth) != "%s.add_do_reference(%s)" % [undo_local, node_local]:
		return {}
	if _at(lines, index + 5, depth) != "%s.add_undo_method(%s, \"remove_child\", %s)" % [
			undo_local, parent, node_local]:
		return {}
	return {
		"ace_id": ADD_NODE,
		"params": {"node": held.get_string(3), "parent": parent},
		"template": "\n".join(PackedStringArray([
			"%s{node}" % held.get_string(1),
			"%sEditorInterface.get_editor_undo_redo()" % made.get_string(1),
			"%s.add_do_method({parent}, \"add_child\", %s)" % [undo_local, node_local],
			"%s.add_do_method(%s, \"set_owner\", EditorInterface.get_edited_scene_root())" % [undo_local, node_local],
			"%s.add_do_reference(%s)" % [undo_local, node_local],
			"%s.add_undo_method({parent}, \"remove_child\", %s)" % [undo_local, node_local],
		])),
		"consumed": RUN_ADD_NODE
	}


## Remove Node (Undoable): the node local, the parent read while the node still has one, the manager
## local, the do half that detaches it and the three undo halves that put it back, own it again and
## hold on to it in the meantime.
static func _match_remove(lines: PackedStringArray, index: int, depth: int) -> Dictionary:
	var held: RegExMatch = _regex("^(var[ \\t]+(%s)(?:[ \\t]*:[ \\t]*Node)?[ \\t]*:?=[ \\t]*)(.+)$" % NAME).search(
		_at(lines, index, depth))
	if held == null:
		return {}
	var node_local: String = held.get_string(2)
	var parented: RegExMatch = _regex("^(var[ \\t]+(%s)(?:[ \\t]*:[ \\t]*Node)?[ \\t]*:?=[ \\t]*)(%s)\\.get_parent\\(\\)$" % [
		NAME, NAME]).search(_at(lines, index + 1, depth))
	if parented == null or parented.get_string(3) != node_local:
		return {}
	var parent_local: String = parented.get_string(2)
	# The place among its siblings, read on the way in. Optional for the same reason the property
	# run's local is: the row writes it, and a tool written by hand may not have thought of it.
	var placed: RegExMatch = _regex("^(var[ \\t]+(%s)[ \\t]*:[ \\t]*int[ \\t]*=[ \\t]*)(%s)\\.get_index\\(\\)$" % [
		NAME, NAME]).search(_at(lines, index + 2, depth))
	if placed != null and placed.get_string(3) != node_local:
		placed = null
	var kept: int = 0 if placed == null else 1
	var made: RegExMatch = _regex("^(var[ \\t]+(%s)[ \\t]*:?=[ \\t]*)EditorInterface\\.get_editor_undo_redo\\(\\)$" % NAME).search(
		_at(lines, index + 2 + kept, depth))
	if made == null:
		return {}
	var undo_local: String = made.get_string(2)
	var expected: PackedStringArray = PackedStringArray([
		"%s.add_do_method(%s, \"remove_child\", %s)" % [undo_local, parent_local, node_local],
		"%s.add_undo_method(%s, \"add_child\", %s)" % [undo_local, parent_local, node_local],
	])
	if kept == 1:
		expected.append("%s.add_undo_method(%s, \"move_child\", %s, %s)" % [
			undo_local, parent_local, node_local, placed.get_string(2)])
	expected.append("%s.add_undo_method(%s, \"set_owner\", EditorInterface.get_edited_scene_root())" % [
		undo_local, node_local])
	expected.append("%s.add_undo_reference(%s)" % [undo_local, node_local])
	for step: int in expected.size():
		if _at(lines, index + 3 + kept + step, depth) != expected[step]:
			return {}
	var template: PackedStringArray = PackedStringArray(["%s{node}" % held.get_string(1),
		"%s%s.get_parent()" % [parented.get_string(1), node_local]])
	if kept == 1:
		template.append("%s%s.get_index()" % [placed.get_string(1), node_local])
	template.append("%sEditorInterface.get_editor_undo_redo()" % made.get_string(1))
	template.append_array(expected)
	return {"ace_id": REMOVE_NODE, "params": {"node": held.get_string(3)},
		"template": "\n".join(template), "consumed": RUN_REMOVE_NODE + kept + kept}


## One line of the body at exactly `depth` tabs, or "" when the line is blank, absent, shallower, or
## deeper than that. Every statement of every run here lives at exactly one indentation, so a line
## that is not at it is not part of the run.
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
