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
# its own sentence: the oldest goes first, or the spawn is skipped. Neither is a default the other
# hides behind.
#
# WHEN THE LAST ONE GOES, measured rather than assumed. SceneTree.node_removed fires as a node
# leaves, and at that moment the leaving node is STILL registered in its groups - so the crowd being
# down to just the node that is going is precisely "this was the last one". That is what the gate
# condition asks, in one readable line, and it is added to the event as an ordinary condition the
# author can see, edit and delete rather than a wrapper the compiler adds behind the row.
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
const LAST_REMOVED_TRIGGER_ID: String = "OnLastOfCrowdRemoved"
const LAST_REMOVED_GATE_ID: String = "CrowdIsDownToThisOne"

## The gate's template, kept beside the trigger for the same reason: the dock bakes this exact string
## onto the condition it adds, and the descriptor below declares it. One constant, one spelling.
const LAST_REMOVED_GATE_TEMPLATE: String = "{node}.is_in_group({crowd}) and get_tree().get_nodes_in_group({crowd}) == [{node}]"

## The handler argument the gate reads - the node SceneTree.node_removed hands over. A constant
## because the trigger resolver spells the same name in the emitted function's signature.
const REMOVED_NODE_ARGUMENT: String = "node"


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	# ── Joining the crowd ──────────────────────────────────────────────────────────────
	# The spawn sentence with one line more than the plain one: the copy joins a group named after
	# the scene it is a copy of, so every question below has something to ask. Placement stays LAST,
	# for the reason the plain spawn row states: global_position only means anything in a tree.
	descriptors.append(F.make_descriptor("Core", "SpawnIntoCrowd", "Spawn A Copy Into The Crowd", ACEDescriptor.ACEType.ACTION,
		"var {name} = {scene}.instantiate()\n{name}.add_to_group({crowd}, true)\n{parent}.add_child({name})\n{name}.global_position = {at}", "",
		[_scene_param(), _name_param(), _crowd_param(), _at_param(), _parent_param()],
		CATEGORY, "Spawn a copy of [b]{scene}[/b] as [b]{name}[/b] at {at}, under [i]{parent}[/i], into the crowd [b]{crowd}[/b]", "Node2D")
		.described("Spawns a copy the way Spawn A Copy does, and puts it in a group named after the scene, so the rows below can count them, cap them and hear when the last one goes. The group is joined with Godot's persistent flag, which is what keeps it there if the branch is ever packed back into a scene file.")
		.featured())

	# ── The cap, and the two answers to reaching it ────────────────────────────────────
	# One row per policy. The first reads the crowd once into a local, because it needs both the
	# size and the member it is about to remove and asking the tree twice could answer differently.
	# `maxi({cap}, 1)` is the reason index 0 is always safe: the branch only runs when at least one
	# member is there, whatever number the author typed in the cap.
	descriptors.append(F.make_descriptor("Core", "SpawnIntoCrowdOldestFirst", "Spawn A Copy, Oldest Goes First", ACEDescriptor.ACEType.ACTION,
		"var crowd_{name} = get_tree().get_nodes_in_group({crowd})\n"\
		+ "if crowd_{name}.size() >= maxi({cap}, 1):\n\tcrowd_{name}[0].queue_free()\n"\
		+ "var {name} = {scene}.instantiate()\n{name}.add_to_group({crowd}, true)\n"\
		+ "{parent}.add_child({name})\n{name}.global_position = {at}", "",
		[_scene_param(), _name_param(), _crowd_param(), _cap_param(), _at_param(), _parent_param()],
		CATEGORY, "Spawn a copy of [b]{scene}[/b] as [b]{name}[/b] at {at}, under [i]{parent}[/i], at most [b]{cap}[/b] alive in [b]{crowd}[/b] - the oldest goes first", "Node2D")
		.described("Spawns a copy into the crowd, and when the crowd is already full removes one member to make room, so the count never climbs past the cap. The one removed is the member Godot lists first, which under a parent that spawns by adding children is the earliest one still alive. The new copy always appears, which is what a bullet or a footstep wants.")
		.featured())
	# The other policy. The name is declared BEFORE the branch on purpose: a following row can still
	# say it either way, and what it holds when the crowd was full is nothing - which is a thing the
	# sheet can ask about with Is Still Here rather than a silence it has to guess at.
	descriptors.append(F.make_descriptor("Core", "SpawnIntoCrowdUnlessFull", "Spawn A Copy Unless The Crowd Is Full", ACEDescriptor.ACEType.ACTION,
		"var {name}: Node = null\n"\
		+ "if get_tree().get_node_count_in_group({crowd}) < {cap}:\n"\
		+ "\t{name} = {scene}.instantiate()\n\t{name}.add_to_group({crowd}, true)\n"\
		+ "\t{parent}.add_child({name})\n\t{name}.global_position = {at}", "",
		[_scene_param(), _name_param(), _crowd_param(), _cap_param(), _at_param(), _parent_param()],
		CATEGORY, "Spawn a copy of [b]{scene}[/b] as [b]{name}[/b] at {at}, under [i]{parent}[/i], at most [b]{cap}[/b] alive in [b]{crowd}[/b] - skip spawning when full", "Node2D")
		.described("Spawns a copy into the crowd only while there is room, and does nothing at all when the crowd is full - the answer an enemy wave wants, where a spawn that arrives by pushing another one out is worse than no spawn. The name is still there for the rows below, holding nothing when the spawn was skipped, so an Is Still Here row can tell the two apart."))

	# ── Counting them ──────────────────────────────────────────────────────────────────
	# The group's size, which is the whole of what "how many are alive" means when the crowd is a
	# group: a freed member leaves the group as it leaves the tree, so the number is never stale.
	descriptors.append(F.make_descriptor("Core", "CrowdCount", "How Many Alive", ACEDescriptor.ACEType.EXPRESSION,
		"get_tree().get_node_count_in_group({crowd})", "",
		[_crowd_param()],
		CATEGORY, "[b]{crowd}[/b] alive")
		.described("How many of a crowd are alive right now - the size of its group. Nothing counts them for you: a member that is freed leaves the group as it leaves the tree, so this is always the number that is actually in the world.")
		.featured())

	# ── When the last one goes ─────────────────────────────────────────────────────────
	# The trigger, and the gate the dock adds underneath it. The trigger itself is the tree's own
	# node_removed signal, which fires for every node anywhere; the gate is what narrows it to this
	# crowd emptying, and it is a condition row rather than a hidden wrapper.
	descriptors.append(F.make_descriptor("Core", LAST_REMOVED_TRIGGER_ID, "On The Last One Removed", ACEDescriptor.ACEType.TRIGGER,
		"", "", [_crowd_param()],
		CATEGORY, "On the last of [b]{crowd}[/b] removed")
		.described("Runs the moment the last member of a crowd leaves the world, once per emptying - the wave being cleared, the last crate broken. It listens to the scene tree's own node-removed signal and adds the question below as a condition you can see and edit, so nothing about it happens off the row. The On Group Emptied condition asks the same question a different way, on a per-frame trigger, by remembering last tick's count; this one needs neither the tick nor the memory."))
	descriptors.append(F.make_descriptor("Core", LAST_REMOVED_GATE_ID, "Crowd Is Down To This One", ACEDescriptor.ACEType.CONDITION,
		LAST_REMOVED_GATE_TEMPLATE, "",
		[_crowd_param(), F.make_param(REMOVED_NODE_ARGUMENT, "String", REMOVED_NODE_ARGUMENT, "Leaving",
			"The node that is leaving - the one the trigger handed this event. On The Last One Removed fills this in for you.",
			"expression")],
		CATEGORY, "[b]{crowd}[/b] is down to [i]{node}[/i], which is leaving")
		.described("The gate under On The Last One Removed: true when the node that is leaving belongs to the crowd and is the only member left in it. A leaving node is still listed in its groups at that moment, so a crowd of just that one is a crowd that is about to be empty."))

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
