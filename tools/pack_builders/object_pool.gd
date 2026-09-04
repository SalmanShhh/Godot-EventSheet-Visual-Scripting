# Pack builder - object_pool (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## ObjectPool: reuse nodes instead of creating and freeing them. Spawning a bullet or an enemy every
## frame and freeing it a moment later makes the game hitch; a pool keeps a stash of ready-made nodes,
## hands one out on Spawn, and takes it back on Despawn - so the heavy work happens once. Register as
## the ObjectPool autoload. Two ways to pool: the EASY way, Create Pool from a scene (.tscn) with an
## optional prewarm; and the CUSTOM way, Create Empty Pool then Add To Pool your own nodes. Despawned
## nodes are parked (hidden, processing off) under the ObjectPool and reused on the next Spawn.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.autoload_mode = true
	sheet.autoload_name = "ObjectPool"
	sheet.host_class = "Node"
	sheet.custom_class_name = "ObjectPoolAddon"
	sheet.class_description = "The ObjectPool autoload singleton: reuses nodes instead of creating and freeing them, so spawn-heavy games stop hitching. Create Pool from a scene (with optional prewarm), Spawn hands out a ready-made node, and Despawn parks it hidden with processing off until the next Spawn."
	sheet.addon_category = "Object Pool"
	sheet.addon_tags = PackedStringArray(["performance", "spawning"])
	var about: CommentRow = CommentRow.new()
	about.text = "ObjectPool: register as the ObjectPool autoload. Create Pool from a scene (or Create Empty Pool + Add To Pool your own nodes), then Spawn to get a ready node and Despawn to hand it back. Reusing nodes keeps heavy scenes smooth. This pack is an event sheet - extend it by editing it."
	sheet.events.append(about)
	var block: RawCodeRow = RawCodeRow.new()
	block.code = "\n".join(PackedStringArray([
		"## @ace_trigger",
		"## @ace_name(\"On Spawned\")",
		"## @ace_category(\"Object Pool\")",
		"signal on_spawned()",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Despawned\")",
		"## @ace_category(\"Object Pool\")",
		"signal on_despawned()",
		"",
		"# pool name -> {scene:PackedScene (or null for a custom pool), free:Array[Node], active:Array[Node]}.",
		"var _pools: Dictionary = {}",
		"# Last-event context, read via the getter expressions inside On Spawned / On Despawned.",
		"var _last_spawned: Node = null",
		"var _last_despawned: Node = null",
		"",
		"# THE HANDING BACK WAITS FOR THE FRAME. A pool takes a node back by REPARENTING it - out of the",
		"# running scene and under the pool - and Godot refuses a reparent while the physics server is",
		"# flushing its queries, which is the whole of a collision or area callback and exactly where a",
		"# bullet is despawned. So Despawn BOOKS the handing back on the message queue and it lands at the",
		"# next idle moment: the node is still in the world for the rest of the event, and no row can raise",
		"# \"can't change this state while flushing queries\" from inside a callback.",
		"#",
		"# ONCE, AND ONLY ONCE. A free list is a plain array, and a node in it twice is handed out to two",
		"# callers. A node with a handing back already booked does not book a second one, and a node already",
		"# in a free list is turned back, so Despawn stays safe to run twice.",
		"# The nodes whose handing back is booked and has not happened yet, by instance id. Kept here rather",
		"# than written on the node, because a node handed out again carries every mark it was parked with.",
		"var _booked: Dictionary = {}",
		"",
		"# The retire runtime, when the project ships it: the file the Retire rows call, which marks a node",
		"# as retiring for the length of the handing over so On Retired can tell a retirement from every",
		"# other exit from the tree. Found BY PATH rather than named, exactly as that file finds this pool",
		"# by path, so the pack still parses in a project that installed the pool and nothing else.",
		"const RETIRE_RUNTIME_PATH: String = \"res://eventsheet_addons/pooled_nodes.gd\"",
		"var _retire_runtime: Script = null",
		"var _retire_runtime_looked_up: bool = false",
		"",
		"# Parks a node in a pool's free list: reparented under the ObjectPool, hidden, processing off.",
		"# A pooled node never sits in the running scene while it waits to be reused.",
		"func _stow(pool_name: String, node: Node) -> void:",
		"\tif node == null or not _pools.has(pool_name):",
		"\t\treturn",
		"\tnode.set_meta(&\"__pool__\", pool_name)",
		"\tif node.get_parent() != null:",
		"\t\tnode.get_parent().remove_child(node)",
		"\tadd_child(node)",
		"\tif node is CanvasItem:",
		"\t\t(node as CanvasItem).visible = false",
		"\tnode.set_process(false)",
		"\tnode.set_physics_process(false)",
		"\t# A recycled node carries no credit from its last life: the ownership key a spawn row",
		"\t# claimed it with comes off here, so the next Claim is the only one that counts and a",
		"\t# reused bullet can never be credited to whoever fired the one before it.",
		"\tif node.has_meta(&\"owner\"):",
		"\t\tnode.remove_meta(&\"owner\")",
		"\t(_pools[pool_name].free as Array).append(node)",
		"",
		"# Where a spawned copy belongs: the running scene when there is one, and this pool itself when",
		"# there is not - a headless run, or a pool used before the first scene is up.",
		"func _world_parent() -> Node:",
		"\tif is_inside_tree() and get_tree() != null and get_tree().current_scene != null:",
		"\t\treturn get_tree().current_scene",
		"\treturn self",
		"",
		"# The half of waking that is NOT a reparent: shown, processing on, and the pooled scene's own",
		"# reset(). Split out because Spawn Safely does exactly this half on the line and books the other,",
		"# and because reset() has to run before the row hands the node back to the sheet - a reset after",
		"# the following rows configured the copy would wipe what they just wrote.",
		"func _ready_for_use(node: Node) -> void:",
		"\tif node is CanvasItem:",
		"\t\t(node as CanvasItem).visible = true",
		"\tnode.set_process(true)",
		"\tnode.set_physics_process(true)",
		"\t# The reset seam: a pooled scene that defines reset() gets it called on every",
		"\t# spawn, so velocity/hp/timers clear without the pool knowing any of them.",
		"\tif node.has_method(&\"reset\"):",
		"\t\tnode.call(&\"reset\")",
		"",
		"# Wakes a node into the running scene: reparented to the current scene, shown, processing on.",
		"func _wake(node: Node) -> void:",
		"\tif node.get_parent() != null:",
		"\t\tnode.get_parent().remove_child(node)",
		"\t_world_parent().add_child(node)",
		"\t_ready_for_use(node)",
		"",
		"# One node out of a pool's free list, or a fresh copy of the pool's scene when the stash is empty.",
		"# Null when there is no pool by that name, and null when an empty custom pool has no scene of its",
		"# own to make one from. The node is NOT counted active here: each spawn row does that at the",
		"# moment it means it.",
		"func _take_from_pool(pool_name: String) -> Node:",
		"\tif not _pools.has(pool_name):",
		"\t\treturn null",
		"\tvar free_list: Array = _pools[pool_name].free",
		"\tif not free_list.is_empty():",
		"\t\treturn free_list.pop_back()",
		"\tif _pools[pool_name].scene == null:",
		"\t\treturn null",
		"\tvar node: Node = (_pools[pool_name].scene as PackedScene).instantiate()",
		"\tnode.set_meta(&\"__pool__\", pool_name)",
		"\treturn node",
		"",
		"# Puts a copy where the row said, in whichever dimension the copy lives in. The place is set",
		"# BEFORE the copy joins the world, so it is a place relative to its parent - and a pool has no",
		"# transform of its own, so the number a row writes is the number the copy lands on. A value of the",
		"# wrong shape for the node (a Vector2 for a Node3D) is left alone rather than raising.",
		"func _place(node: Node, at: Variant) -> void:",
		"\tif node is Node2D and at is Vector2:",
		"\t\t(node as Node2D).position = at as Vector2",
		"\telif node is Node3D and at is Vector3:",
		"\t\t(node as Node3D).position = at as Vector3",
		"\telif node is Control and at is Vector2:",
		"\t\t(node as Control).position = at as Vector2",
		"",
		"# THE JOINING WAITS FOR THE FRAME TOO, for Spawn Safely and for that row only. Handing a copy out",
		"# is a reparent exactly as handing one back is, and Godot refuses a reparent while the physics",
		"# server is flushing its queries - the whole of a collision or area callback. So Spawn Safely does",
		"# everything but the reparent on the line and books this, and On Spawned is raised HERE, with the",
		"# copy already in the world, so a row under that trigger can read the copy's parent.",
		"# Resolved from an id rather than from the node, because a row can free the copy again before this",
		"# lands, and an id that no longer names anything is simply an answer of no. A copy a Despawn row",
		"# already took back is no longer counted active, and is left parked where it is.",
		"func _join_world_by_id(node_id: int) -> void:",
		"\tif not is_instance_id_valid(node_id):",
		"\t\treturn",
		"\tvar node: Node = instance_from_id(node_id) as Node",
		"\tif node == null or not is_instance_valid(node) or node.is_queued_for_deletion():",
		"\t\treturn",
		"\tif not node.has_meta(&\"__pool__\"):",
		"\t\treturn",
		"\tvar pool_name: String = str(node.get_meta(&\"__pool__\"))",
		"\tif not _pools.has(pool_name) or not (_pools[pool_name].active as Array).has(node):",
		"\t\treturn",
		"\tif node.get_parent() != null:",
		"\t\tnode.get_parent().remove_child(node)",
		"\t_world_parent().add_child(node)",
		"\t_last_spawned = node",
		"\ton_spawned.emit()",
		"",
		"# The retire runtime if the project has it, found once and remembered - null when it does not, in",
		"# which case this pool hands nodes back on its own and marks nothing.",
		"func _retire_runtime_script() -> Script:",
		"\tif _retire_runtime_looked_up:",
		"\t\treturn _retire_runtime",
		"\t_retire_runtime_looked_up = true",
		"\tif ResourceLoader.exists(RETIRE_RUNTIME_PATH):",
		"\t\t_retire_runtime = load(RETIRE_RUNTIME_PATH) as Script",
		"\treturn _retire_runtime",
		"",
		"# Whether this node is inside a handing over the retire runtime has already marked - which is to",
		"# say a Retire row booked the idle moment we are standing in, so the reparent is safe on this line.",
		"# Asked after Despawn's queued-for-deletion guard, so the answer is the mark and nothing else.",
		"func _already_retiring(node: Node) -> bool:",
		"\tvar runtime: Script = _retire_runtime_script()",
		"\treturn runtime != null and bool(runtime.call(&\"is_retiring\", node))",
		"",
		"# The booked half, resolved from an id rather than from the node itself: a node can be freed between",
		"# the Despawn row and the idle moment that hands it over, and an id that no longer names anything is",
		"# simply an answer of no.",
		"func _hand_back_by_id(node_id: int) -> void:",
		"\t_booked.erase(node_id)",
		"\tif not is_instance_id_valid(node_id):",
		"\t\treturn",
		"\tvar node: Node = instance_from_id(node_id) as Node",
		"\tif node == null or not is_instance_valid(node) or node.is_queued_for_deletion():",
		"\t\treturn",
		"\tvar runtime: Script = _retire_runtime_script()",
		"\tif runtime != null:",
		"\t\t# Out through the runtime and straight back in, so the handing over is MARKED while it happens:",
		"\t\t# that mark is what On Retired's guard reads, so a Despawn row raises that trigger exactly once,",
		"\t\t# exactly as a Retire row does.",
		"\t\truntime.call(&\"hand_back\", node, self)",
		"\t\treturn",
		"\t_hand_back_now(str(node.get_meta(&\"__pool__\")), node)",
		"",
		"# The handing over itself, with the waiting already done: out of the active list, parked under the",
		"# pool, and the pack's own signal to say it happened - once, because a node already in the free list",
		"# is turned back here.",
		"func _hand_back_now(pool_name: String, node: Node) -> void:",
		"\tif not _pools.has(pool_name) or (_pools[pool_name].free as Array).has(node):",
		"\t\treturn",
		"\t(_pools[pool_name].active as Array).erase(node)",
		"\t_stow(pool_name, node)",
		"\t_last_despawned = node",
		"\ton_despawned.emit()"
	]))
	sheet.events.append(block)

	# --- Create pools ---
	Lib.append_function(sheet, "create_pool", "Create Pool", "Object Pool", "The easy way: makes a pool that spawns copies of a scene (a .tscn path), optionally pre-making some now so the first spawns never hitch.",
		[["pool_name", "String"], ["scene_path", "String"], ["prewarm", "int"]],
		"var scene: PackedScene = load(scene_path) as PackedScene\n_pools[pool_name] = {\"scene\": scene, \"free\": [], \"active\": []}\nif scene == null:\n\treturn\nfor _i: int in maxi(prewarm, 0):\n\t_stow(pool_name, scene.instantiate())")
	_default(sheet, "prewarm", "8")
	Lib.append_function(sheet, "create_empty_pool", "Create Empty Pool", "Object Pool", "The custom way: makes a pool with no scene of its own. Fill it with Add To Pool (your own nodes), and Spawn hands those back out.",
		[["pool_name", "String"]],
		"_pools[pool_name] = {\"scene\": null, \"free\": [], \"active\": []}")
	Lib.append_function(sheet, "add_to_pool", "Add To Pool", "Object Pool", "Puts one of your own existing nodes into a pool as a ready-to-reuse instance (for custom pools). The node is hidden and parked until spawned.",
		[["pool_name", "String"], ["node", "Node"]],
		"_stow(pool_name, node)")
	Lib.append_function(sheet, "prewarm", "Prewarm", "Object Pool", "Pre-makes more copies for a scene pool (so a burst of spawns stays smooth).",
		[["pool_name", "String"], ["count", "int"]],
		"if not _pools.has(pool_name) or _pools[pool_name].scene == null:\n\treturn\nfor _i: int in maxi(count, 0):\n\t_stow(pool_name, (_pools[pool_name].scene as PackedScene).instantiate())")

	# --- Spawn + despawn ---
	Lib.append_function(sheet, "despawn", "Despawn", "Object Pool", "Hands a spawned node back to its pool to be reused (hides it and stops its processing) instead of freeing it. Fires On Despawned. The handing back lands at the next idle moment rather than on this line, exactly as a destroy does, so the node is still in the world for the rest of the event and the row is safe inside a collision or area callback. Safe to run twice - a node already booked, or already back in its pool, is left alone.",
		[["node", "Node"]],
		"if node == null or not is_instance_valid(node) or node.is_queued_for_deletion():\n\treturn\nif not node.has_meta(&\"__pool__\"):\n\treturn\nvar pool_name: String = str(node.get_meta(&\"__pool__\"))\nif not _pools.has(pool_name) or (_pools[pool_name].free as Array).has(node):\n\treturn\nif _already_retiring(node):\n\t_hand_back_now(pool_name, node)\n\treturn\nif _booked.has(node.get_instance_id()):\n\treturn\n_booked[node.get_instance_id()] = true\ncall_deferred(&\"_hand_back_by_id\", node.get_instance_id())")
	Lib.append_function(sheet, "despawn_all", "Despawn All", "Object Pool", "Hands every active node of a pool back at once (for a level reset). Like Despawn, each handing back lands at the next idle moment.",
		[["pool_name", "String"]],
		"if not _pools.has(pool_name):\n\treturn\nfor node: Node in (_pools[pool_name].active as Array).duplicate():\n\tdespawn(node)")
	Lib.append_function(sheet, "clear_pool", "Clear Pool", "Object Pool", "Frees (deletes) every node in a pool and removes the pool. Use it when the pool is truly done.",
		[["pool_name", "String"]],
		"if not _pools.has(pool_name):\n\treturn\nfor node: Node in (_pools[pool_name].free as Array) + (_pools[pool_name].active as Array):\n\tif is_instance_valid(node):\n\t\tnode.queue_free()\n_pools.erase(pool_name)")

	# --- Conditions ---
	_condition(sheet, "has_pool", "Has Pool", "Object Pool", "Whether a pool with this name exists.", [["pool_name", "String"]],
		"return _pools.has(pool_name)")

	# --- Expressions ---
	_expr_node(sheet, "spawn", "Spawn", "Object Pool", "Hands out a ready node from a pool (reusing a free one, or making a new copy from the pool's scene) - added to the current scene, shown, and returned so you can position it. Fires On Spawned. Returns nothing if the pool is empty and has no scene.",
		[["pool_name", "String"]],
		"var node: Node = _take_from_pool(pool_name)\nif node == null:\n\treturn null\n_wake(node)\n(_pools[pool_name].active as Array).append(node)\n_last_spawned = node\non_spawned.emit()\nreturn node")
	_expr_node(sheet, "spawn_safely", "Spawn Safely", "Object Pool", "The same spawn, with the copy joining the world on the next idle moment instead of on this line. Use it inside a collision or area callback: Godot refuses to reparent a node while the physics server is flushing its queries, and this row waits for that to finish rather than erroring. You get the node back straight away, reset, shown and put where you say, so the rows after it can configure it - it is still parked under the pool for the rest of the event, and under the running scene from the next frame. On Spawned fires at that later moment, with the copy already in the world, so a row under it can read the copy's parent. Outside a callback prefer plain Spawn, whose copy is in the world on the line. Returns nothing if the pool is empty and has no scene.",
		[["pool_name", "String"], ["at", "Variant"]],
		"var node: Node = _take_from_pool(pool_name)\nif node == null:\n\treturn null\n_ready_for_use(node)\n_place(node, at)\n(_pools[pool_name].active as Array).append(node)\ncall_deferred(&\"_join_world_by_id\", node.get_instance_id())\nreturn node")
	_field(sheet, "at", "Vector2.ZERO", "Where the copy goes, set before it joins the world - so it is a place relative to the parent it is about to get, and a pool has no transform of its own. A Vector3 places a 3D copy; a value of the wrong shape for the copy is left alone.")
	_expr_node(sheet, "last_spawned", "Last Spawned", "Object Pool", "The node most recently spawned (handy inside On Spawned).", [],
		"return _last_spawned")
	_expr_node(sheet, "last_despawned", "Last Despawned", "Object Pool", "The node most recently despawned (handy inside On Despawned).", [],
		"return _last_despawned")
	_expr(sheet, "free_count", "Free Count", "Object Pool", "How many ready (unused) nodes a pool holds.", [["pool_name", "String"]],
		"return (_pools[pool_name].free as Array).size() if _pools.has(pool_name) else 0", TYPE_INT)
	_expr(sheet, "active_count", "Active Count", "Object Pool", "How many of a pool's nodes are currently spawned and in use.", [["pool_name", "String"]],
		"return (_pools[pool_name].active as Array).size() if _pools.has(pool_name) else 0", TYPE_INT)
	_expr(sheet, "pool_size", "Pool Size", "Object Pool", "A pool's total nodes (free plus active).", [["pool_name", "String"]],
		"return ((_pools[pool_name].free as Array).size() + (_pools[pool_name].active as Array).size()) if _pools.has(pool_name) else 0", TYPE_INT)

	# The pack's hero verbs: starred + bold at the top of their picker section.
	Lib.verb_sentences(sheet, {
		"create_pool": "Create pool [b]{pool_name}[/b] of [b]{scene_path}[/b], prewarm [b]{prewarm}[/b]",
		"despawn": "Despawn [i]{node}[/i]",
	})
	Lib.feature_verbs(sheet, ["create_pool", "despawn"])
	return Lib.save_pack(sheet, "res://eventsheet_addons/object_pool/object_pool_addon")


## Pre-fills the last-appended ACE's parameter default (authoring-time metadata only).
static func _default(sheet: EventSheetResource, param_id: String, value: String) -> void:
	var fn: EventFunction = sheet.functions[sheet.functions.size() - 1]
	for parameter: ACEParam in fn.params:
		if parameter.id == param_id:
			parameter.default_value = value


## The starting value AND the line the params dialog shows under the field, set together because
## only the combined `@ace_param` form carries a default into the shipped pack: a parameter with
## nothing to say is written as the older hint-only spelling, which has nowhere to put one, so a
## default set on its own never reaches the emitted file and the row opens on an empty field.
static func _field(sheet: EventSheetResource, param_id: String, value: String, description: String) -> void:
	var fn: EventFunction = sheet.functions[sheet.functions.size() - 1]
	for parameter: ACEParam in fn.params:
		if parameter.id == param_id:
			parameter.default_value = value
			parameter.description = description


static func _condition(sheet: EventSheetResource, function_name: String, display_name: String, category: String, description: String, params: Array, body: String) -> void:
	var fn: EventFunction = Lib.exposed_function(function_name, display_name, category, description, params, body)
	fn.return_type = TYPE_BOOL
	sheet.functions.append(fn)


static func _expr(sheet: EventSheetResource, function_name: String, display_name: String, category: String, description: String, params: Array, body: String, ret: int) -> void:
	var fn: EventFunction = Lib.exposed_function(function_name, display_name, category, description, params, body)
	fn.return_type = ret
	sheet.functions.append(fn)


## An expression ACE that returns a Node (sets the return type NAME so the compiled function reads
## `-> Node`, which is what a node-returning helper needs to round-trip).
static func _expr_node(sheet: EventSheetResource, function_name: String, display_name: String, category: String, description: String, params: Array, body: String) -> void:
	var fn: EventFunction = Lib.exposed_function(function_name, display_name, category, description, params, body)
	fn.return_type = TYPE_OBJECT
	fn.return_type_name = "Node"
	sheet.functions.append(fn)
