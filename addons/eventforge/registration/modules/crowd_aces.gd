# EventForge module - Crowd (the copies a sheet spawned, counted, capped, and missed when they go)
#
# There is no crowd system here either. A crowd is a Godot GROUP, and every row in this module is
# `add_to_group`, `get_nodes_in_group` or a count of one - said as a sentence. Nothing is registered,
# nothing is remembered, and a project that deletes this plugin keeps every line these rows wrote.
#
# WHY A GROUP AND NOT A LIST. The sheet does not have to hold the copies for the engine to know
# where they are: a group is the tree's own index, it survives a node being reparented, and it
# empties itself when a member is freed - which is exactly the bookkeeping a hand-written spawner
# gets wrong. So the crowd rows below join the group and then ask the tree, and there is no third
# place for the two to disagree.
#
# THE SECOND ARGUMENT TO add_to_group IS NOT OPTIONAL HERE. `add_to_group(name)` is not persistent:
# PackedScene.pack() saves persistent groups ONLY, so a group added without the flag vanishes the
# moment the branch is packed back into a .tscn - and every group-based question then silently
# answers zero. The rows below pass `true`, which costs nothing at runtime and is the difference
# between a crowd that survives being saved into a scene and one that does not.
#
# THE CAP IS ON THE ROW, AND SO IS THE POLICY. "At most twelve alive" is two different games
# depending on what happens at twelve, so there is a row per answer and each one says which it is in
# its own sentence: the first in the crowd makes room, or the spawn is skipped. Neither is a default
# the other hides behind.
#
# AND A MEMBER ON ITS WAY OUT IS NOT ONE OF THE TWELVE. `queue_free()` marks a node and leaves it in
# the tree - and therefore in its group - until the end of the frame. A cap that read the group
# straight would count those ghosts, and worse, a second spawn in the same frame would read the same
# crowd, free the SAME member again and add one: three spawns in one frame under a cap of twelve
# leave fourteen alive, and the next such frame leaves sixteen. So both cap rows read the members
# that are STAYING - `filter(... not is_queued_for_deletion())` - which makes the count mean what the
# row says and makes the member chosen a different one each time. How Many Alive below is
# deliberately not filtered: it is the group's own size, and a member is in the group until the end
# of the frame it was removed in.
#
# WHEN THE LAST ONE GOES, measured rather than assumed. SceneTree.node_removed fires as a node
# leaves, and at that moment the leaving node is STILL registered in its groups - so the crowd being
# down to just the node that is going is precisely "this was the last one". That is what the gate
# condition asks, in one readable line, and it is added to the event as an ordinary condition the
# author can see, edit and delete rather than a wrapper the compiler adds behind the row.
#
# AND LEAVING A PARENT IS NOT LEAVING THE WORLD. node_removed fires for ANY exit from the tree, a
# Node.reparent() included - and a reparented node is still alive, still in its groups and, for the
# instant the signal is emitted, the only member the group lists. Without a third question the
# trigger announces the wave cleared, opens the door and pays the reward while the enemy is alive
# under another parent. `is_queued_for_deletion()` is that question and is the only one Godot answers
# from the node itself: it is true for every destroy this language writes, all three of which are a
# queue_free, and false for a move. A member taken out some other way - its whole branch freed at
# once, or a bare free() - is not seen by this trigger, and the shipped On Group Emptied condition,
# which compares this tick's count with last tick's, is the row for that.
#
# AND IT IS NOT THE PLAIN ARRIVAL TRIGGER EITHER. On Node Leaves Group rides the same node_removed
# signal and asks ONE question - is this node in that group - so it fires for every departure, a
# reparent included, and says WHICH node. This trigger narrows the same signal to the single moment a
# crowd empties, which is why its gate asks the two further questions above. Different handlers,
# different questions, one signal.
#
# Module contract: see ace_factory.gd - ace_ids/templates are API (compatibility covenant); this file
# only changes where the descriptors are AUTHORED.
@tool
class_name EventForgeCrowdACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")
## The spawn module, for its placement starters - the "where" suggestions are one list, offered by
## the plain spawn row and the crowd rows alike. Preloaded by PATH rather than named by class, so a
## module added before the editor's class cache is regenerated still loads.
const SPAWN := preload("res://addons/eventforge/registration/modules/spawn_aces.gd")

## The one category these rows group under in the picker.
const CATEGORY: String = "Crowd"

## The trigger that answers a crowd emptying, and the condition applying it adds underneath. Named
## here because the dock's apply step reads both to build the gate (ace_apply.gd), and a pair of
## loose strings in two files is how the two halves drift apart.
const LAST_REMOVED_TRIGGER_ID: String = "OnLastOfCrowdDestroyed"
const LAST_REMOVED_GATE_ID: String = "CrowdIsDownToThisOne"

## The gate's template, kept beside the trigger for the same reason: the dock bakes this exact string
## onto the condition it adds, and the descriptor below declares it. One constant, one spelling.
const LAST_REMOVED_GATE_TEMPLATE: String = "{node}.is_in_group({crowd}) and {node}.is_queued_for_deletion() and get_tree().get_nodes_in_group({crowd}) == [{node}]"

## The handler argument the gate reads - the node SceneTree.node_removed hands over. A constant
## because the trigger resolver spells the same name in the emitted function's signature.
const REMOVED_NODE_ARGUMENT: String = "node"


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	# ── Joining the crowd ──────────────────────────────────────────────────────────────
	# The spawn sentence with one line more than the plain one: the copy joins a group named after
	# the scene it is a copy of, so every question below has something to ask. Placement stays LAST,
	# for the reason the plain spawn row states: global_position only means anything in a tree.
	descriptors.append(F.act("SpawnIntoCrowd", "Spawn A Copy Into The Crowd", "var {name} = {scene}.instantiate()\n{name}.add_to_group({crowd}, true)\n{parent}.add_child({name})\n{name}.global_position = {at}", CATEGORY, "Spawn a copy of [b]{scene}[/b] as [b]{name}[/b] at {at}, under [i]{parent}[/i], into the crowd [b]{crowd}[/b]", "Spawns a copy the way Spawn A Copy does, and puts it in a group named after the scene, so the rows below can count them, cap them and hear when the last one goes. The group is joined with Godot's persistent flag, which is what keeps it there if the branch is ever packed back into a scene file.", "Node2D").param_built(_scene_param()).param_built(_name_param()).param_built(_crowd_param()).param_built(_at_param()).param_built(_parent_param()).featured())

	# ── The cap, and the two answers to reaching it ────────────────────────────────────
	# One row per policy. Both read the crowd once into a local, because both need the count and one
	# of them needs the member it is about to remove, and asking the tree twice could answer
	# differently. The read SKIPS the members already on their way out, for the reason the header
	# states: those are ghosts, and counting or freeing one again is how a cap stops capping.
	# `maxi({cap}, 1)` is the reason `pop_front()` is always safe: the loop only runs when at least
	# one member is staying, whatever number the author typed in the cap. It is a `while` rather than
	# an `if` so the row's sentence is true the moment the line has run, even on a crowd that was
	# already over its cap when the frame began.
	descriptors.append(F.act("SpawnIntoCrowdOldestFirst", "Spawn A Copy, The First Makes Room", "var crowd_{name} = get_tree().get_nodes_in_group({crowd}).filter(func(member: Variant) -> bool: return not member.is_queued_for_deletion())\n" + "while crowd_{name}.size() >= maxi({cap}, 1):\n\tcrowd_{name}.pop_front().queue_free()\n" + "var {name} = {scene}.instantiate()\n{name}.add_to_group({crowd}, true)\n" + "{parent}.add_child({name})\n{name}.global_position = {at}", CATEGORY, "Spawn a copy of [b]{scene}[/b] as [b]{name}[/b] at {at}, under [i]{parent}[/i], at most [b]{cap}[/b] alive in [b]{crowd}[/b] - the first in the crowd makes room", "Spawns a copy into the crowd, and when the crowd is already full destroys members to make room, so the count never climbs past the cap - not even when the same event spawns several times in one frame. The ones destroyed are taken from the front of the crowd, which is the order Godot lists a group in: under a parent that spawns by adding children that is the earliest one still alive, and after a move_child or a second parent it is the tree's order rather than the spawn's. Members already on their way out are skipped, so no member is ever freed twice and the new copy always appears - which is what a bullet or a footstep wants.", "Node2D").param_built(_scene_param()).param_built(_name_param()).param_built(_crowd_param()).param_built(_cap_param()).param_built(_at_param()).param_built(_parent_param()).featured())
	# The other policy, reading the crowd the same way so that "alive" means one thing in both rows.
	# The name is declared BEFORE the branch on purpose: a following row can still say it either way,
	# and what it holds when the crowd was full is nothing - which is a thing the sheet can ask about
	# with Is Still Here rather than a silence it has to guess at.
	descriptors.append(F.act("SpawnIntoCrowdUnlessFull", "Spawn A Copy Unless The Crowd Is Full", "var crowd_{name} = get_tree().get_nodes_in_group({crowd}).filter(func(member: Variant) -> bool: return not member.is_queued_for_deletion())\n" + "var {name}: Node = null\n" + "if crowd_{name}.size() < {cap}:\n" + "\t{name} = {scene}.instantiate()\n\t{name}.add_to_group({crowd}, true)\n" + "\t{parent}.add_child({name})\n\t{name}.global_position = {at}", CATEGORY, "Spawn a copy of [b]{scene}[/b] as [b]{name}[/b] at {at}, under [i]{parent}[/i], at most [b]{cap}[/b] alive in [b]{crowd}[/b] - skip spawning when full", "Spawns a copy into the crowd only while there is room, and does nothing at all when the crowd is full - the answer an enemy wave wants, where a spawn that arrives by pushing another one out is worse than no spawn. A member already on its way out has stopped counting against the cap, so a spawn in the same frame something died in still happens. The name is still there for the rows below, holding nothing when the spawn was skipped, so an Is Still Here row can tell the two apart.", "Node2D").param_built(_scene_param()).param_built(_name_param()).param_built(_crowd_param()).param_built(_cap_param()).param_built(_at_param()).param_built(_parent_param()))

	# ── Counting them ──────────────────────────────────────────────────────────────────
	# The group's size, which is the whole of what "how many are alive" means when the crowd is a
	# group: a freed member leaves the group as it leaves the tree, so nothing has to be kept in step.
	# Left UNFILTERED on purpose - this is the group's own size, and paying for an array and a lambda
	# on a line a HUD reads every frame to shave off a member that has one frame left would be a worse
	# trade than saying so.
	descriptors.append(F.expr("CrowdCount", "How Many Alive", "get_tree().get_node_count_in_group({crowd})", CATEGORY, "[b]{crowd}[/b] alive", "How many of a crowd are alive right now - the size of its group. Nothing counts them for you: a member that is freed leaves the group as it leaves the tree, so the number can never drift out of step with the world. A member destroyed this frame is still counted until the end of it, which is what queue_free means everywhere else too.").param_built(_crowd_param()).featured())

	# ── When the last one goes ─────────────────────────────────────────────────────────
	# The trigger, and the gate the dock adds underneath it. The trigger itself is the tree's own
	# node_removed signal, which fires for every node anywhere; the gate is what narrows it to this
	# crowd emptying, and it is a condition row rather than a hidden wrapper.
	descriptors.append(F.trig(LAST_REMOVED_TRIGGER_ID, "On The Last One Destroyed", "", CATEGORY, "On the last of [b]{crowd}[/b] destroyed", "Runs the moment the last member of a crowd is destroyed, once per emptying - the wave being cleared, the last crate broken. It listens to the scene tree's own node-removed signal and adds the question below as a condition you can see and edit, so nothing about it happens off the row. That question also asks whether the member is really going, because moving a node to another parent leaves the tree too and is not the crowd emptying. A member taken out some other way - its whole branch freed at once - is not seen here; the On Group Emptied condition asks the same thing a different way, on a per-frame trigger, by remembering last tick's count.").param_built(_crowd_param()))
	descriptors.append(F.cond(LAST_REMOVED_GATE_ID, "Crowd Is Down To This One", LAST_REMOVED_GATE_TEMPLATE, CATEGORY, "[b]{crowd}[/b] is down to [i]{node}[/i], which is being destroyed", "The gate under On The Last One Destroyed: true when the node that is leaving belongs to the crowd, is really being destroyed rather than moved to another parent, and is the only member left in it. A leaving node is still listed in its groups at that moment, so a crowd of just that one is a crowd that is about to be empty.").param_built(_crowd_param()).param_typed("String", REMOVED_NODE_ARGUMENT, REMOVED_NODE_ARGUMENT, "Leaving", "The node that is leaving - the one the trigger handed this event. On The Last One Destroyed fills this in for you.", "expression"))

	return descriptors


## The picker's own words for the section, so selecting the header says what the rows underneath are
## for rather than leaving the reader to infer it from six names.
static func section_descriptions() -> Dictionary:
	return {
		CATEGORY: "The copies a sheet spawned, held as a Godot group: joined on the way in, counted, capped with the policy said out loud, and answered when the last one goes."
	}


## The scene a crowd's copies are made from. Same field, same reasoning and same default as the plain
## spawn row's, so the two sentences read as one language.
static func _scene_param() -> ACEParam:
	return F.make_param("scene", "String", "load(\"res://enemy.tscn\")", "Scene",
		"The scene to copy - one of this sheet's declared scenes by name, or a load() of a scene path.",
		"expression")


## The name the copy answers to, exactly as the plain spawn row mints it.
static func _name_param() -> ACEParam:
	return F.make_param("name", "String", "new_enemy", "Called",
		"What to call the new copy. Following rows in this event say this name, and it is the variable name the emitted code uses.",
		"")


## The crowd itself - a plain Godot group name, offered from the groups the project already uses. The
## default is the scene's own name in the plural, which is the convention the rows read best in.
static func _crowd_param() -> ACEParam:
	return F.make_param("crowd", "String", "\"enemies\"", "Crowd",
		"The group the copies belong to, named after the scene they are copies of. It is an ordinary Godot group, so anything else in the project that uses groups can see these too.",
		"group_reference")


## How many of the crowd may be alive at once.
static func _cap_param() -> ACEParam:
	return F.make_param("cap", "String", "12", "At Most",
		"How many of this crowd may be alive at once. What happens when that many already are is the rest of the row's sentence, not a setting.",
		"expression")


## Where the copy lands, with the plain spawn row's own starters offered.
static func _at_param() -> ACEParam:
	return F.make_param("at", "String", "global_position", "At",
		"Where the copy lands, as a position. Leave it as global_position to spawn where this node is.",
		"expression", [], SPAWN.PLACEMENT_STARTERS)


## The node the copy is added under, stated on the row even when it is this one.
static func _parent_param() -> ACEParam:
	return F.make_param("parent", "String", "self", "Under",
		"The node the copy is added under. Leave it as self to add it under this one, or name a layer to keep spawns together.",
		"expression")
