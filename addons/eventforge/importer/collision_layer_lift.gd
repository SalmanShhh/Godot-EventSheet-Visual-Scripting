# EventForge - the collision-layer lines people wrote before this plugin existed.
#
# `set_collision_mask_value(2, true)` is in every project that has ever had a bullet stop hitting
# its own shooter or a player drop through a platform, and until now it opened as the bit-verb row
# it literally is: "Set mask 2 = true". The project already said what layer 2 is, in Project
# Settings, so the row can say it too - and these five spellings open as the named-layer sentences:
#
#     set_collision_mask_value(2, true)     Collide with Enemies
#     set_collision_mask_value(2, false)    Stop colliding with Enemies
#     set_collision_layer_value(3, true)    Be on layer Player
#     set_collision_layer_value(3, false)   Leave layer Player
#     get_collision_mask_value(2)           is set to collide with Enemies
#
# THE NUMBER IS WHAT IS STORED, ALWAYS. The row carries the author's own `2`; the name is resolved
# when the row is DRAWN, so a layer renamed tomorrow renames the sentence and the file never moves.
# A number the project never named, or one outside 1-32, reads as the number - honest, and exactly
# what the sentence grammar has always done with these two calls.
#
# WHICH LIST OF NAMES, THOUGH. Godot keeps 2D and 3D layer names apart, and the two calls are spelled
# identically on `CollisionObject2D` and `CollisionObject3D` - so the spelling alone cannot say which
# list a line belongs to. The FILE says: a script that extends a 3D body means 3D layers. That is why
# the table below is written once, for the 2D rows, and the file's own `extends` decides whether the
# row handed back is that row or its 3D twin. One set of spellings, one harness, two rows.
#
# The raw bit arithmetic beside these (`collision_mask |= 4`, `collision_layer = 0`) is deliberately
# NOT here: it says something about a set of layers rather than about one, and it keeps the frozen
# bit verbs and the readings the sentence grammar already gives it.
@tool
class_name EventForgeCollisionLayerLift
extends RefCounted

## The fragment a line must contain for any entry here to be worth trying - one word that rules out
## almost every statement in a project before a pattern is compiled at all.
const MARK: String = "collision_"

## What the row's receiver is when the line names no node: blank, which is what "this node" reads as
## on every node-scoped row in the plugin.
const BLANK_TARGET: Dictionary = {"target": ""}

## The layer the generated fixtures point at. Any layer would do; a number past the first keeps the
## fixture from reading as a default nobody chose.
const FIXTURE_LAYER: String = "2"
const FIXTURE_TARGET: String = "$Enemy"

## The ace_id suffix the 3D twin of each row carries, matching the module's own convention
## (`IsOnWall` / `IsOnWall3D`).
const SUFFIX_3D: String = "3D"

## Which list of layer names the file being lifted belongs to. Set by `note_source` from the script's
## own `extends`, and 2D until something says otherwise - which is what a 2D project wants and the
## honest answer for a file this cannot place.
static var dimension: String = EventForgePhysicsLayers.DIMENSION_2D

## Built once for the life of the session: these run on every statement of every opened file.
static var _actions: Array[Dictionary] = []
static var _conditions: Array[Dictionary] = []


## Remembers which dimension the file being opened is about. Called once per open, before any line is
## matched, exactly as the lighting and effect families are told about their scene.
static func note_source(source: String, _script_path: String) -> void:
	dimension = EventForgePhysicsLayers.dimension_for_class(extended_class(source))


## The class a script extends, or "" when it extends nothing this can read. Read off the text rather
## than by loading the script: the file is being opened precisely because it has not been compiled
## into anything yet.
static func extended_class(source: String) -> String:
	for line: String in source.split("\n"):
		var text: String = line.strip_edges()
		if not text.begins_with("extends "):
			continue
		var named: String = text.substr(8).strip_edges()
		# `extends "res://thing.gd"` names a file rather than a class, and a file cannot answer the
		# question this is asking.
		return "" if named.begins_with("\"") else named.split(" ")[0]
	return ""


## The row one ACTION statement means, or {} when no spelling here claims it.
static func match_line(line: String) -> Dictionary:
	return _matched(action_entries(), line)


## The row one CONDITION term means, or {} when no spelling here claims it. Separate from the
## actions because a condition's spelling is an expression, and an expression standing alone as a
## statement is not this row - it is a value somebody computed and threw away.
static func match_condition(line: String) -> Dictionary:
	return _matched(condition_entries(), line)


## Every entry, for the harness and the validator. The two lists joined rather than a third copy, so
## an entry cannot exist in one place and be tested in another.
static func lift_entries() -> Array[Dictionary]:
	var all: Array[Dictionary] = []
	all.append_array(action_entries())
	all.append_array(condition_entries())
	return all


static func action_entries() -> Array[Dictionary]:
	if _actions.is_empty():
		_actions = [
			_switch_entry("collide_with_layer", "CollideWithLayer", "mask", "true"),
			_switch_entry("stop_colliding_with_layer", "StopCollidingWithLayer", "mask", "false"),
			_switch_entry("be_on_layer", "BeOnLayer", "layer", "true"),
			_switch_entry("leave_layer", "LeaveLayer", "layer", "false"),
		]
	return _actions


static func condition_entries() -> Array[Dictionary]:
	if _conditions.is_empty():
		_conditions = [{
			"id": "is_set_to_collide_with_layer",
			"ace_id": "IsSetToCollideWithLayer",
			"pattern": "^%sget_collision_mask_value\\((?<layer>[^)]+)\\)$"\
				% EventForgeLiftTable.receiver("target"),
			"params": ["target", "layer"],
			"defaults": BLANK_TARGET,
			"shape": "%sget_collision_mask_value({layer})"\
				% EventForgeLiftTable.optional_prefix_slot("target"),
			"slots": {"target": FIXTURE_TARGET, "layer": FIXTURE_LAYER}
		}]
	return _conditions


## One of the four switch spellings: which knob (`mask` or `layer`), and which way it is being
## thrown. The four differ by exactly those two words, so writing them out four times would be four
## places for one pattern to drift.
static func _switch_entry(id: String, ace_id: String, knob: String, switch: String) -> Dictionary:
	return {
		"id": id,
		"ace_id": ace_id,
		"pattern": "^%sset_collision_%s_value\\((?<layer>[^,]+), %s\\)$" % [
			EventForgeLiftTable.receiver("target"), knob, switch],
		"params": ["target", "layer"],
		"defaults": BLANK_TARGET,
		"shape": "%sset_collision_%s_value({layer}, %s)" % [
			EventForgeLiftTable.optional_prefix_slot("target"), knob, switch],
		"slots": {"target": FIXTURE_TARGET, "layer": FIXTURE_LAYER}
	}


## The match, with the row named for the dimension the FILE is about. The table recognises the
## spelling; this says which of the two rows that spelling means here.
static func _matched(entries: Array[Dictionary], line: String) -> Dictionary:
	var text: String = line.strip_edges()
	if not text.contains(MARK):
		return {}
	var hit: Dictionary = EventForgeLiftTable.match_line(entries, text)
	if hit.is_empty() or dimension != EventForgePhysicsLayers.DIMENSION_3D:
		return hit
	hit["ace_id"] = "%s%s" % [str(hit.get("ace_id", "")), SUFFIX_3D]
	return hit


## The dimension a GENERATED fixture is lifted under: the 2D one the table is written for. Called
## once per family before its entries are probed, so a suite run after a 3D file was opened still
## probes the rows the table names.
static func lift_fixture_context() -> void:
	dimension = EventForgePhysicsLayers.DIMENSION_2D
