# EventForge module - Node manipulation + picking (build, rearrange, and select scene-tree nodes).
#
# The everyday scene-tree operations: parent/reorder/free/rename nodes, and PICK nodes (children,
# by name pattern, or by group) so common tree work never forces a drop to GDScript. Complements
# the Nodes navigation set in dev_aces (Get Parent / Child / Find Child …) and the Groups set.
# Each compiles to the exact native call. Grouped under Nodes / Nodes: Picking.
@tool
class_name EventForgeNodeACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	# ── Nodes: manipulation (build + rearrange the tree at runtime; act on self or a {target}) ──
	descriptors.append(F.make_descriptor("Core", "AddChild", "Add Child", ACEDescriptor.ACEType.ACTION, "add_child({node})", "", [F.make_param("node", "String", "Node.new()", "Node", "Node to add as a child of this node.", "expression")], "Nodes", "add child [i]{node}[/i]")
		.described("Attaches another node as a child of this one at runtime, e.g. spawning a bullet."))
	descriptors.append(F.make_descriptor("Core", "RemoveChild", "Remove Child", ACEDescriptor.ACEType.ACTION, "remove_child({node})", "", [F.make_param("node", "String", "get_child(0)", "Node", "Child to detach (by index here - no hardcoded name; pick one or use a scene-unique node). Not freed.", "expression")], "Nodes", "remove child [i]{node}[/i]")
		.described("Detaches a child node from this one without deleting it, so you can reattach it later."))
	descriptors.append(F.make_descriptor("Core", "MoveChild", "Move Child To Index", ACEDescriptor.ACEType.ACTION, "move_child({node}, {index})", "", [F.make_param("node", "String", "get_child(0)", "Node", "Child to reorder (by index here - no hardcoded name; pick one or use a scene-unique node).", "expression"), F.make_param("index", "String", "0", "Index", "New sibling index (draw / process order).", "expression")], "Nodes", "move [i]{node}[/i] to index [b]{index}[/b]")
		.described("Reorders a child to a new sibling index, changing its draw and process order."))
	descriptors.append(F.make_descriptor("Core", "QueueFreeNode", "Free Node", ACEDescriptor.ACEType.ACTION, "{target}.queue_free()", "", [F.make_param("target", "String", "self", "Target", "Node to free at the end of the frame.", "expression")], "Nodes", "free [i]{target}[/i]")
		.described("Safely deletes a node at the end of the frame, e.g. removing a dead enemy."))
	descriptors.append(F.make_descriptor("Core", "SetNodeName", "Set Node Name", ACEDescriptor.ACEType.ACTION, "{target}.name = {name}", "", [F.make_param("target", "String", "self", "Target", "Node to rename.", "expression"), F.make_param("name", "String", "\"Renamed\"", "Name", "New node name.", "expression")], "Nodes", "rename [i]{target}[/i] to [b]{name}[/b]")
		.described("Renames a node at runtime, handy for tracking or finding it later."))
	descriptors.append(F.make_descriptor("Core", "DuplicateNode", "Duplicate Node", ACEDescriptor.ACEType.EXPRESSION, "{target}.duplicate()", "", [F.make_param("target", "String", "self", "Target", "Node to clone (add the clone with Add Child).", "expression")], "Nodes", "duplicate [i]{target}[/i]")
		.described("Clones a node so you can add the copy elsewhere, e.g. mass-spawning identical objects."))
	descriptors.append(F.make_descriptor("Core", "GetNodeName", "Node Name", ACEDescriptor.ACEType.EXPRESSION, "{target}.name", "", [F.make_param("target", "String", "self", "Target", "Node to read the name of.", "expression")], "Nodes", "[i]{target}[/i] name")
		.described("Returns the node's name as text, useful for labels or matching."))
	descriptors.append(F.make_descriptor("Core", "GetNodePath", "Node Path", ACEDescriptor.ACEType.EXPRESSION, "{target}.get_path()", "", [F.make_param("target", "String", "self", "Target", "Node to read its scene-tree path.", "expression")], "Nodes", "[i]{target}[/i] path")
		.described("Returns the node's full path in the scene tree as a reference."))
	descriptors.append(F.make_descriptor("Core", "GetIndexInParent", "Index In Parent", ACEDescriptor.ACEType.EXPRESSION, "{target}.get_index()", "", [F.make_param("target", "String", "self", "Target", "Node to read its sibling index.", "expression")], "Nodes", "[i]{target}[/i] index")
		.described("Returns the node's position among its siblings as a number."))
	descriptors.append(F.make_descriptor("Core", "IsInsideTree", "Is Inside Tree", ACEDescriptor.ACEType.CONDITION, "{target}.is_inside_tree()", "", [F.make_param("target", "String", "self", "Target", "Node to test for scene-tree membership.", "expression")], "Nodes", "[i]{target}[/i] is inside tree")
		.described("True when the node is currently part of the active scene tree."))
	descriptors.append(F.make_descriptor("Core", "GetSceneRoot", "Current Scene Root", ACEDescriptor.ACEType.EXPRESSION, "get_tree().current_scene", "", [], "Nodes", "current scene root")
		.described("Returns the root node of the currently running scene."))

	# ── Nodes: Picking - find / select nodes (children, by name pattern, by group) ──
	descriptors.append(F.make_descriptor("Core", "GetChildren", "Get Children", ACEDescriptor.ACEType.EXPRESSION, "{target}.get_children()", "", [F.make_param("target", "String", "self", "Target", "Node whose direct children to list.", "expression")], "Nodes: Picking", "[i]{target}[/i] children")
		.described("Returns the list of a node's direct children to loop over or pick from."))
	descriptors.append(F.make_descriptor("Core", "FindChildrenByPattern", "Find Children (by name)", ACEDescriptor.ACEType.EXPRESSION, "{target}.find_children({pattern}, \"\", true, false)", "", [F.make_param("target", "String", "self", "Target", "Node to search beneath.", "expression"), F.make_param("pattern", "String", "\"Enemy*\"", "Pattern", "Name pattern (wildcards allowed).", "expression")], "Nodes: Picking", "find [b]{pattern}[/b] in [i]{target}[/i]")
		.described("Returns all descendant nodes whose name matches a pattern, wildcards allowed."))
	# By TYPE - the answer to Godot's node-heavy objects: reach "the AnimationPlayer / Area2D / Sprite2D of
	# this object" WITHOUT a brittle deep path ($A/B/C/D) or a GDScript block. find_children("*", Type,
	# recursive=true, owned=false) walks the whole subtree by class. Pairs with For Each (Find Children Of
	# Type), With-node / expressions (First Child Of Type), and gating (Has Child Of Type).
	descriptors.append(F.make_descriptor("Core", "FindChildrenOfType", "Find Children Of Type", ACEDescriptor.ACEType.EXPRESSION, "{target}.find_children(\"*\", {type}, true, false)", "", [F.make_param("target", "String", "self", "Target", "Node to search beneath.", "expression"), F.make_param("type", "String", "\"AnimationPlayer\"", "Type", "Node class name to find - AnimationPlayer, Area2D, Sprite2D, … (every descendant of that type).", "expression")], "Nodes: Picking", "[b]{type}[/b] nodes in [i]{target}[/i]")
		.described("Returns all descendant nodes of a given class, e.g. every Area2D beneath this one."))
	descriptors.append(F.make_descriptor("Core", "FirstChildOfType", "First Child Of Type", ACEDescriptor.ACEType.EXPRESSION, "{target}.find_children(\"*\", {type}, true, false).pop_front()", "", [F.make_param("target", "String", "self", "Target", "Node to search beneath.", "expression"), F.make_param("type", "String", "\"AnimationPlayer\"", "Type", "Node class name to find - the first match in the subtree (null if none; pop_front is null-safe on empty).", "expression")], "Nodes: Picking", "first [b]{type}[/b] in [i]{target}[/i]")
		.described("Returns the first descendant node of a given class, or nothing if none exist."))
	descriptors.append(F.make_descriptor("Core", "HasChildOfType", "Has Child Of Type", ACEDescriptor.ACEType.CONDITION, "not {target}.find_children(\"*\", {type}, true, false).is_empty()", "", [F.make_param("target", "String", "self", "Target", "Node to search beneath.", "expression"), F.make_param("type", "String", "\"Area2D\"", "Type", "Node class name to test for anywhere in the subtree.", "expression")], "Nodes: Picking", "[i]{target}[/i] has a [b]{type}[/b]")
		.described("True when at least one descendant node of the given class exists beneath this node."))

	# ── Object-level component verbs (the object-level mental model: act on the OBJECT, not its deep node) ──
	# The animation ACEs above this file's peers are host-scoped to the AnimationPlayer/AnimatedSprite2D, so
	# they force you to TARGET that deep child by path. These take the object and AUTO-RESOLVE its player by
	# type, so "Play Animation walk on Player" needs no path and no GDScript block. Null-safe (guarded) and
	# collision-safe (the {uid}-baked temp var is unique per row, exactly like the audio Play Sound ACEs).
	descriptors.append(F.make_descriptor("Core", "PlayAnimationInObject", "Play Animation (in object)", ACEDescriptor.ACEType.ACTION, "var __ap_{uid} := {target}.find_children(\"*\", \"AnimationPlayer\", true, false).pop_front() as AnimationPlayer\nif __ap_{uid}:\n\t__ap_{uid}.play(&{anim})", "", [F.make_param("target", "String", "self", "Target", "The OBJECT (its AnimationPlayer is found automatically anywhere beneath it).", "expression"), F.make_param("anim", "String", "\"idle\"", "Animation", "Name of the animation to play.")], "Animation", "play animation [b]{anim}[/b] in [i]{target}[/i]")
		.described("Plays a named animation by auto-finding the object's AnimationPlayer for you."))
	descriptors.append(F.make_descriptor("Core", "StopAnimationInObject", "Stop Animation (in object)", ACEDescriptor.ACEType.ACTION, "var __ap_{uid} := {target}.find_children(\"*\", \"AnimationPlayer\", true, false).pop_front() as AnimationPlayer\nif __ap_{uid}:\n\t__ap_{uid}.stop()", "", [F.make_param("target", "String", "self", "Target", "The OBJECT whose AnimationPlayer to stop (found automatically).", "expression")], "Animation", "stop animation in [i]{target}[/i]")
		.described("Stops the object's animation by auto-finding its AnimationPlayer."))
	descriptors.append(F.make_descriptor("Core", "PlaySpriteAnimationInObject", "Play Sprite Animation (in object)", ACEDescriptor.ACEType.ACTION, "var __as_{uid} := {target}.find_children(\"*\", \"AnimatedSprite2D\", true, false).pop_front() as AnimatedSprite2D\nif __as_{uid}:\n\t__as_{uid}.play(&{anim})", "", [F.make_param("target", "String", "self", "Target", "The OBJECT (its AnimatedSprite2D is found automatically).", "expression"), F.make_param("anim", "String", "\"default\"", "Animation", "Animation name.")], "Animation", "play sprite animation [b]{anim}[/b] in [i]{target}[/i]")
		.described("Plays a named sprite animation via the object's AnimatedSprite2D, found automatically."))
	descriptors.append(F.make_descriptor("Core", "IsObjectAnimating", "Is Animating (in object)", ACEDescriptor.ACEType.CONDITION, "{target}.find_children(\"*\", \"AnimationPlayer\", true, false).any(func(__p): return __p.is_playing())", "", [F.make_param("target", "String", "self", "Target", "The OBJECT to test - true if any AnimationPlayer beneath it is playing.", "expression")], "Animation", "[i]{target}[/i] is animating")
		.described("True when any AnimationPlayer beneath the object is currently playing."))
	# More object-level verbs (same auto-resolve-by-type pattern): the everyday sprite/effect ops a designer
	# expects on an object, without targeting the deep child by path or dropping to a GDScript block.
	descriptors.append(F.make_descriptor("Core", "FlipSpriteInObject", "Flip Sprite (in object)", ACEDescriptor.ACEType.ACTION, "var __as_{uid} := {target}.find_children(\"*\", \"AnimatedSprite2D\", true, false).pop_front() as AnimatedSprite2D\nif __as_{uid}:\n\t__as_{uid}.flip_h = {mirrored}", "", [F.make_param("target", "String", "self", "Target", "The OBJECT (its AnimatedSprite2D is found automatically).", "expression"), F.make_param("mirrored", "String", "true", "Mirrored", "Mirror the sprite horizontally (e.g. facing direction).", "", ["true", "false"])], "Animation", "flip sprite [b]{mirrored}[/b] in [i]{target}[/i]")
		.described("Mirrors the object's sprite horizontally, e.g. flipping to face left or right."))
	descriptors.append(F.make_descriptor("Core", "SetSpriteFrameInObject", "Set Sprite Frame (in object)", ACEDescriptor.ACEType.ACTION, "var __as_{uid} := {target}.find_children(\"*\", \"AnimatedSprite2D\", true, false).pop_front() as AnimatedSprite2D\nif __as_{uid}:\n\t__as_{uid}.frame = {frame}", "", [F.make_param("target", "String", "self", "Target", "The OBJECT (its AnimatedSprite2D is found automatically).", "expression"), F.make_param("frame", "String", "0", "Frame", "Frame index to show.", "expression")], "Animation", "set sprite frame [b]{frame}[/b] in [i]{target}[/i]")
		.described("Shows a specific frame on the object's AnimatedSprite2D, found automatically."))
	descriptors.append(F.make_descriptor("Core", "RestartAnimationInObject", "Restart Animation (in object)", ACEDescriptor.ACEType.ACTION, "var __ap_{uid} := {target}.find_children(\"*\", \"AnimationPlayer\", true, false).pop_front() as AnimationPlayer\nif __ap_{uid}:\n\t__ap_{uid}.stop()\n\t__ap_{uid}.play(&{anim})", "", [F.make_param("target", "String", "self", "Target", "The OBJECT (its AnimationPlayer is found automatically).", "expression"), F.make_param("anim", "String", "\"idle\"", "Animation", "Animation to (re)play from the start.")], "Animation", "restart animation [b]{anim}[/b] in [i]{target}[/i]")
		.described("Replays a named animation from the very start, e.g. retriggering an attack."))
	descriptors.append(F.make_descriptor("Core", "EmitParticlesInObject", "Emit Particles (in object)", ACEDescriptor.ACEType.ACTION, "var __pp_{uid} := {target}.find_children(\"*\", \"GPUParticles2D\", true, false).pop_front() as GPUParticles2D\nif __pp_{uid}:\n\t__pp_{uid}.emitting = {emitting}", "", [F.make_param("target", "String", "self", "Target", "The OBJECT (its GPUParticles2D is found automatically).", "expression"), F.make_param("emitting", "String", "true", "Emitting", "Turn the particle emitter on or off.", "", ["true", "false"])], "Effects", "set particles emitting [b]{emitting}[/b] in [i]{target}[/i]")
		.described("Turns the object's particle emitter on or off, found automatically."))
	descriptors.append(F.make_descriptor("Core", "GetNodesInGroup", "Nodes In Group", ACEDescriptor.ACEType.EXPRESSION, "get_tree().get_nodes_in_group({group})", "", [F.make_param("group", "String", "\"enemies\"", "Group", "Group name.", "group_reference")], "Nodes: Picking", "nodes in group {group}")
		.described("Returns every node belonging to a named group to loop over or count."))
	descriptors.append(F.make_descriptor("Core", "GetRandomNodeInGroup", "Random Node In Group", ACEDescriptor.ACEType.EXPRESSION, "get_tree().get_nodes_in_group({group}).pick_random()", "", [F.make_param("group", "String", "\"enemies\"", "Group", "Group to pick a random member from.", "group_reference")], "Nodes: Picking", "random node in group {group}")
		.described("Returns a randomly chosen member of a named group, e.g. a random spawn point."))
	# Nearest / Furthest by distance from THIS node - the auto-attack / targeting primitives. reduce()
	# (Godot 4 Array has no min_by/max_by) over the group, comparing global_position.distance_to: one
	# template needs global_position, so these register for Node2D hosts (a 3D game can paste the same
	# reduce() into a GDScript block). Empty group → null.
	descriptors.append(F.make_descriptor("Core", "NearestInGroup", "Nearest Node In Group", ACEDescriptor.ACEType.EXPRESSION, "get_tree().get_nodes_in_group({group}).reduce(func(__acc, __n): return __n if __acc == null or global_position.distance_to(__n.global_position) < global_position.distance_to(__acc.global_position) else __acc, null)", "", [F.make_param("group", "String", "\"enemies\"", "Group", "Group to pick the closest member of (by distance to this node). Returns null if the group is empty.", "group_reference")], "Nodes: Picking", "nearest node in group {group}", "Node2D")
		.described("Returns the closest member of a group to this node, e.g. the nearest enemy."))
	descriptors.append(F.make_descriptor("Core", "FurthestInGroup", "Furthest Node In Group", ACEDescriptor.ACEType.EXPRESSION, "get_tree().get_nodes_in_group({group}).reduce(func(__acc, __n): return __n if __acc == null or global_position.distance_to(__n.global_position) > global_position.distance_to(__acc.global_position) else __acc, null)", "", [F.make_param("group", "String", "\"enemies\"", "Group", "Group to pick the farthest member of (by distance to this node). Returns null if the group is empty.", "group_reference")], "Nodes: Picking", "furthest node in group {group}", "Node2D")
		.described("Returns the farthest member of a group from this node by distance."))
	# The empty-safe sibling of Random Node In Group: Array.pick_random() ERRORS on an empty array, so
	# this one asks first and hands back nothing instead. Plain Node host - no distance math involved.
	descriptors.append(F.make_descriptor("Core", "RandomInGroup", "Random Node In Group (empty-safe)", ACEDescriptor.ACEType.EXPRESSION, "get_tree().get_nodes_in_group({group}).pick_random() if not get_tree().get_nodes_in_group({group}).is_empty() else null", "", [F.make_param("group", "String", "\"enemies\"", "Group", "Group to pick a random member from. Returns nothing when the group is empty (instead of erroring).", "group_reference")], "Nodes: Picking", "random node in group {group} (or nothing)")
		.described("Returns a random member of a group, or nothing at all when the group is empty."))
	# Pick by a PROPERTY rather than by distance: lowest health, highest score, cheapest item. Same
	# reduce() idiom (Godot 4 Array has no min_by/max_by); get() reads the named property off each
	# member, so any group of nodes that carries it works. Empty group → null.
	descriptors.append(F.make_descriptor("Core", "SmallestInGroup", "Group Member With Smallest Property", ACEDescriptor.ACEType.EXPRESSION, "get_tree().get_nodes_in_group({group}).reduce(func(__acc, __n): return __n if __acc == null or __n.get({property}) < __acc.get({property}) else __acc, null)", "", [F.make_param("group", "String", "\"enemies\"", "Group", "Group to search. Returns nothing if the group is empty.", "group_reference"), F.make_param("property", "String", "\"hp\"", "Property", "Name of the property to compare, e.g. hp or score.")], "Nodes: Picking", "group {group} member with smallest {property}")
		.described("Returns the group member whose named property is lowest, e.g. the weakest enemy."))
	descriptors.append(F.make_descriptor("Core", "LargestInGroup", "Group Member With Largest Property", ACEDescriptor.ACEType.EXPRESSION, "get_tree().get_nodes_in_group({group}).reduce(func(__acc, __n): return __n if __acc == null or __n.get({property}) > __acc.get({property}) else __acc, null)", "", [F.make_param("group", "String", "\"enemies\"", "Group", "Group to search. Returns nothing if the group is empty.", "group_reference"), F.make_param("property", "String", "\"hp\"", "Property", "Name of the property to compare, e.g. hp or score.")], "Nodes: Picking", "group {group} member with largest {property}")
		.described("Returns the group member whose named property is highest, e.g. the toughest enemy."))

	# ── 2D spatial patterns (the everyday distance / aim / screen-wrap / hover verbs) ──
	# Four things a 2D game asks for constantly and that otherwise force a GDScript block: "is that
	# thing close enough?", "aim at it over time", "come back on the other side", "hover in place".
	# All four register for Node2D hosts (they read global_position / position / the viewport rect).
	# The `other` / `target` defaults are get_parent() so the row stands on its own the moment it is
	# dropped - a bare identifier like `player` would not exist on a plain Node2D. The proximity test
	# is NODE-to-node (the point-to-point "Is Within Distance" under Vectors takes two positions).
	descriptors.append(F.make_descriptor("Core", "IsNodeWithinDistance", "Is Within Distance (of a node)", ACEDescriptor.ACEType.CONDITION, "global_position.distance_to({other}.global_position) <= maxf({distance}, 0.0)", "", [F.make_param("other", "String", "get_parent()", "Of", "The other node.", "expression"), F.make_param("distance", "String", "64.0", "Distance", "In pixels.", "expression")], "Movement", "is within {distance} px of {other}", "Node2D")
		.described("True when another node is closer than the given number of pixels. The proximity test behind prompts, pickups and aggro ranges - pick the node, type the pixels, no parentheses-math to write."))
	descriptors.append(F.make_descriptor("Core", "TurnToward", "Turn Toward", ACEDescriptor.ACEType.ACTION, "rotation = rotate_toward(rotation, ({target}.global_position - global_position).angle(), deg_to_rad(maxf({degrees_per_second}, 0.0)) * get_process_delta_time())", "", [F.make_param("target", "String", "get_parent()", "Target", "Node to aim at.", "expression"), F.make_param("degrees_per_second", "String", "180.0", "Turn Speed", "Degrees per second.", "expression")], "Movement", "turn toward {target} at {degrees_per_second} deg/s", "Node2D")
		.described("Aims this node at another one, turning at a real speed instead of snapping - the turret and the chasing enemy. Frame-rate independent; for an instant snap, give it a huge turn speed."))
	# Screen wrap: get_viewport_rect().size read once into a {uid} local (unique per row, baked by the
	# dock at apply time) so both axes share one measurement. The leading `var` line means this
	# template is never given an "On node" prefix - a self-verb, which is exactly right here.
	descriptors.append(F.make_descriptor("Core", "WrapInsideScreen", "Wrap Inside The Screen", ACEDescriptor.ACEType.ACTION, "var __wrap_size_{uid}: Vector2 = get_viewport_rect().size\nposition = Vector2(wrapf(position.x, 0.0, __wrap_size_{uid}.x), wrapf(position.y, 0.0, __wrap_size_{uid}.y))", "", [], "Movement", "wrap inside the screen", "Node2D")
		.described("The Asteroids rule: leave the right edge and come back on the left, off the top and back at the bottom. Nothing ever escapes the screen."))
	# Bob: the resting height is remembered in node metadata on the first run (the stateless-state
	# trick the cooldown ACEs use), so the sine rides the position the node already had - no exported
	# var, no _ready wiring, and dropping the row anywhere just works.
	descriptors.append(F.make_descriptor("Core", "BobUpAndDown", "Bob Up And Down", ACEDescriptor.ACEType.ACTION, "if not has_meta(&\"__bob_base_{uid}\"):\n\tset_meta(&\"__bob_base_{uid}\", position.y)\nposition.y = float(get_meta(&\"__bob_base_{uid}\")) + sin(Time.get_ticks_msec() / 1000.0 * TAU / maxf({period}, 0.01)) * {height}", "", [F.make_param("height", "String", "6.0", "Height", "Pixels above and below the resting point.", "expression"), F.make_param("period", "String", "2.0", "Period", "Seconds for one full bob.", "expression")], "Movement", "bob up and down {height} px every {period}s", "Node2D")
		.described("Floats the node gently up and down around wherever it was resting - pickups, idle hover, a breathing menu icon. No sin() to write; run it under a per-frame trigger."))

	return descriptors
