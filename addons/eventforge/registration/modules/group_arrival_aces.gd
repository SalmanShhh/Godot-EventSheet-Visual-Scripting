# EventForge module - Group arrivals (the moment a node joins or leaves a group)
#
# There is no registry here and there is nothing to keep in step. The scene tree already announces
# every node that enters and leaves it, through its own `node_added` and `node_removed` signals, and
# these two triggers are those signals with the question the sheet actually asks put underneath them
# as an ordinary condition: is the node that just arrived in the group I care about?
#
#     func _ready() -> void:
#         get_tree().node_added.connect(_on_node_joined_group)
#
#     func _on_node_joined_group(node: Node) -> void:
#         if node.is_in_group("minimap"):
#             ...
#
# THE FILTER IS A ROW, NOT A WRAPPER. Picking the trigger puts the shipped Is In Group condition in
# the sheet with the group the trigger names already filled in, so the guard is visible, editable and
# deletable, and it is a plain `if` on disk. Nothing new was minted for it: `{target}.is_in_group(
# {group})` is a row this vocabulary already had, and re-saying it here would have been two rows for
# one line. Setting the group to *Any group* leaves the guard off entirely, which is the firehose an
# editor tool or a debug overlay wants.
#
# HOW THIS RELATES TO THE THREE NEIGHBOURS IT IS EASY TO CONFUSE IT WITH:
#   - Connect Group Signal wires a listener to every CURRENT member of a group. That is its stated
#     limit, and this trigger is how it stops being one: hear the join, wire the one node that just
#     arrived, and a group that grows all game long stays wired without re-running the loop.
#   - On Group Emptied / On Group Gains First Member answer the group as a WHOLE, by comparing this
#     tick's count with last tick's on a per-frame trigger. They say "the wave is over" and "combat
#     started"; these two say WHICH node, and say it at the moment it happens rather than at the next
#     frame. Use those for the aggregate, these for the member.
#   - On The Last One Destroyed (the Crowd module) is the same `node_removed` signal, narrowed to the
#     one moment a crowd empties, and it asks two further questions this trigger deliberately does
#     not: whether the node is really being destroyed rather than reparented, and whether it was the
#     last one. On Node Leaves Group fires for every departure, including a reparent.
#
# THE COST IS REAL AND IS MEASURED. The guard runs for EVERY node entering or leaving the world, not
# only for members of the group named. Measured on one desktop machine, 1000 `add_child` calls with
# one `node_added` handler doing one `is_in_group`: 546 us cold, 887 us wired - about +62% on the
# cost of add_child itself, or 0.34 us per node. Both readings of that are true and both belong on
# the row: a 1000-node scene load pays about a third of a millisecond, which is nothing, and it is
# still most of the cost of adding a node, which is why an emitter adding hundreds of nodes a frame
# is the wrong place for it. A figure stated is worth more than "nothing worth measuring", which is
# the sentence a reader quotes back after a spawn path gets slower.
#
# AND THE TIMING IS STATED TOO, because it is the thing that surprises people, and `_ready` is where
# it surprises them. `node_added` is emitted BEFORE `_ready` runs, so a group joined in `_ready` -
# the single commonest place a project joins one - is not there when the guard asks, and that node's
# membership is then never announced at all: no later join is about it. Measured: a node whose
# `_ready` calls `add_to_group("minimap")` gave one announced join, zero matches, and `is_in_group`
# true afterwards. Groups written in a scene file ARE set when the node enters the tree, so those the
# guard sees. Add the group before the node enters the tree (or on the row that spawns it, which is
# what Spawn A Copy Into The Crowd does) and the two agree.
#
# AND SO IS TEARDOWN, which is the other half of the same surprise. `node_removed` fires for every
# descendant of a branch being freed, and on quit for the whole tree, with the departing nodes still
# listed in their groups - which is what the leaving trigger relies on. Measured: freeing a branch of
# 1001 nodes announced 1000 departures. So a leaving body ("remove the marker", "drop the
# connection", "decrement the count") runs once per member against a tree that is mid-destruction,
# and it has to be written so that is harmless.
#
# Module contract: see ace_factory.gd - ace_ids/templates are API (compatibility covenant); this file
# only changes where the descriptors are AUTHORED.
@tool
class_name EventForgeGroupArrivalACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

## The category these two rows group under - the same one the aggregate cousins (On Group Emptied,
## On Group Gains First Member) are filed in, because a reader looking for "when did this happen"
## should find all four in one place.
const CATEGORY: String = "Run Context"

## The two triggers, and the shipped condition that goes under them. Named here because the dock's
## apply step reads all three to build the gate (ace_apply.gd), and a set of loose strings in two
## files is how the two halves drift apart.
const JOINS_TRIGGER_ID: String = "OnNodeJoinsGroup"
const LEAVES_TRIGGER_ID: String = "OnNodeLeavesGroup"

## The group the trigger watches, and the node the signal hands over. Constants because the trigger
## resolver spells the argument name in the emitted handler's signature and the gate reads it.
const GROUP_PARAM: String = "group"
const ARRIVING_NODE_ARGUMENT: String = "node"

## The shipped condition the gate is built from, and its template. Not a new row: this is Is In Group,
## which this vocabulary has had all along, and the gate is that row with the trigger's own values in
## it.
const GATE_ACE_ID: String = "IsInGroup"
const GATE_TEMPLATE: String = "{target}.is_in_group({group})"

## The value the group field holds when the event wants EVERY node, filtered by nothing: the empty
## string literal, which names no group and is therefore visibly not one. It is a stated choice the
## group picker offers rather than a blank somebody has to guess the meaning of, and the dock reads
## it as "add no gate" - the handler then runs its body for every node entering or leaving the world,
## which is the firehose a debug overlay or an editor tool wants.
const ANY_GROUP: String = "\"\""

## The line the group picker shows beside that choice, so the firehose says what it costs at the
## moment it is chosen.
const ANY_GROUP_NOTE: String = "Any group - every node entering or leaving the world"


## True when a group value means "no filter" - the Any group choice, or a field left blank. One
## question, asked by the dock when it decides whether to add the gate and by anything else that
## needs to know whether this event is the firehose.
static func is_any_group(group_value: String) -> bool:
	var trimmed: String = group_value.strip_edges()
	return trimmed.is_empty() or trimmed == ANY_GROUP


## True when this trigger is one of the two arrivals - what the params dialog asks before it offers
## the Any group choice, so no other group field grows a choice that would be nonsense in it.
static func is_arrival_trigger(ace_id: String) -> bool:
	return ace_id == JOINS_TRIGGER_ID or ace_id == LEAVES_TRIGGER_ID


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	descriptors.append(F.make_descriptor("Core", JOINS_TRIGGER_ID, "On Node Joins Group", ACEDescriptor.ACEType.TRIGGER,
		"", "", [_group_param()],
		CATEGORY, "On a node joining {group}")
		.described("Runs the moment a node that belongs to a group enters the world - a spawned enemy that should get a minimap marker, a pickup that should be counted, a door that should be wired up. It listens to the scene tree's own node-added signal and adds the group question below as a condition you can see and edit, so nothing about it happens off the row. The guard runs for every node entering the world: measured, one handler asking one group question costs about 0.34 microseconds per node added, which is a third of a millisecond on a 1000-node scene load and still most of the cost of adding a node - so it is the wrong tool inside a particle storm. A group set in the scene file is already there when the node arrives, but a group joined in _ready is joined too late: node-added is emitted first, so that node is never matched by this trigger at all. Join the group before the node enters the tree, or on the row that spawns it.")
		.featured())
	descriptors.append(F.make_descriptor("Core", LEAVES_TRIGGER_ID, "On Node Leaves Group", ACEDescriptor.ACEType.TRIGGER,
		"", "", [_group_param()],
		CATEGORY, "On a node leaving {group}")
		.described("Runs the moment a node that belongs to a group leaves the world - the marker to take off the minimap, the entry to remove from a list, the connection to drop. A leaving node is still listed in its groups at that moment, which is what lets the question be asked at all. It fires for every departure, a move to another parent included: when what you mean is the crowd being emptied by a destroy, On The Last One Destroyed asks those further questions and this one deliberately does not. TEARDOWN IS A DEPARTURE TOO: every member of the group leaves when the branch holding it is freed and when the game quits, so this body runs once per member against a tree that is being taken apart - write it so that is harmless, or ask whether the tree is quitting first."))

	return descriptors


## The group the trigger watches - a plain Godot group name, offered from the groups the project
## already uses, with the unfiltered choice stated in the list rather than left as a blank.
static func _group_param() -> ACEParam:
	return F.make_param(GROUP_PARAM, "String", "\"enemies\"", "Group",
		"The group whose members this event answers. It is an ordinary Godot group, so anything else in the project that uses groups sees the same members. Choose Any group to answer every node entering or leaving the world, which is what a debug overlay or an editor tool wants.",
		"group_reference")
