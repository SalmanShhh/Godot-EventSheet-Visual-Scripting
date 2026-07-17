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
		"\t(_pools[pool_name].free as Array).append(node)",
		"",
		"# Wakes a node into the running scene: reparented to the current scene, shown, processing on.",
		"func _wake(node: Node) -> void:",
		"\tif node.get_parent() != null:",
		"\t\tnode.get_parent().remove_child(node)",
		"\tvar target: Node = get_tree().current_scene if (is_inside_tree() and get_tree() != null and get_tree().current_scene != null) else self",
		"\ttarget.add_child(node)",
		"\tif node is CanvasItem:",
		"\t\t(node as CanvasItem).visible = true",
		"\tnode.set_process(true)",
		"\tnode.set_physics_process(true)"
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
	Lib.append_function(sheet, "despawn", "Despawn", "Object Pool", "Hands a spawned node back to its pool to be reused (hides it and stops its processing) instead of freeing it. Fires On Despawned.",
		[["node", "Node"]],
		"if node == null or not node.has_meta(&\"__pool__\"):\n\treturn\nvar pool_name: String = str(node.get_meta(&\"__pool__\"))\nif not _pools.has(pool_name):\n\treturn\n(_pools[pool_name].active as Array).erase(node)\n_stow(pool_name, node)\n_last_despawned = node\non_despawned.emit()")
	Lib.append_function(sheet, "despawn_all", "Despawn All", "Object Pool", "Hands every active node of a pool back at once (for a level reset).",
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
		"if not _pools.has(pool_name):\n\treturn null\nvar free_list: Array = _pools[pool_name].free\nvar node: Node = null\nif not free_list.is_empty():\n\tnode = free_list.pop_back()\nelif _pools[pool_name].scene != null:\n\tnode = (_pools[pool_name].scene as PackedScene).instantiate()\n\tnode.set_meta(&\"__pool__\", pool_name)\nif node == null:\n\treturn null\n_wake(node)\n(_pools[pool_name].active as Array).append(node)\n_last_spawned = node\non_spawned.emit()\nreturn node")
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

	return Lib.save_pack(sheet, "res://eventsheet_addons/object_pool/object_pool_addon")


## Pre-fills the last-appended ACE's parameter default (authoring-time metadata only).
static func _default(sheet: EventSheetResource, param_id: String, value: String) -> void:
	var fn: EventFunction = sheet.functions[sheet.functions.size() - 1]
	for parameter: ACEParam in fn.params:
		if parameter.id == param_id:
			parameter.default_value = value


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
