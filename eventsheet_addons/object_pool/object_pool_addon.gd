## @ace_tags(performance, spawning)
## @ace_category("Object Pool")
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/object_pool/icon.svg")
class_name ObjectPoolAddon
extends Node
## The ObjectPool autoload singleton: reuses nodes instead of creating and freeing them, so spawn-heavy games stop hitching. Create Pool from a scene (with optional prewarm), Spawn hands out a ready-made node, and Despawn parks it hidden with processing off until the next Spawn.

## @ace_trigger
## @ace_name("On Spawned")
## @ace_category("Object Pool")
signal on_spawned
## @ace_trigger
## @ace_name("On Despawned")
## @ace_category("Object Pool")
signal on_despawned

# pool name -> {scene:PackedScene (or null for a custom pool), free:Array[Node], active:Array[Node]}.
var _pools: Dictionary = {}
# Last-event context, read via the getter expressions inside On Spawned / On Despawned.
var _last_spawned: Node = null
var _last_despawned: Node = null

# THE HANDING BACK WAITS FOR THE FRAME. A pool takes a node back by REPARENTING it - out of the
# running scene and under the pool - and Godot refuses a reparent while the physics server is
# flushing its queries, which is the whole of a collision or area callback and exactly where a
# bullet is despawned. So Despawn BOOKS the handing back on the message queue and it lands at the
# next idle moment: the node is still in the world for the rest of the event, and no row can raise
# "can't change this state while flushing queries" from inside a callback.
#
# ONCE, AND ONLY ONCE. A free list is a plain array, and a node in it twice is handed out to two
# callers. A node with a handing back already booked does not book a second one, and a node already
# in a free list is turned back, so Despawn stays safe to run twice.
# The nodes whose handing back is booked and has not happened yet, by instance id. Kept here rather
# than written on the node, because a node handed out again carries every mark it was parked with.
var _booked: Dictionary = {}

# The retire runtime, when the project ships it: the file the Retire rows call, which marks a node
# as retiring for the length of the handing over so On Retired can tell a retirement from every
# other exit from the tree. Found BY PATH rather than named, exactly as that file finds this pool
# by path, so the pack still parses in a project that installed the pool and nothing else.
const RETIRE_RUNTIME_PATH: String = "res://eventsheet_addons/pooled_nodes.gd"
var _retire_runtime: Script = null
var _retire_runtime_looked_up: bool = false
# Where a spawned copy belongs: the running scene when there is one, and this pool itself when
# there is not - a headless run, or a pool used before the first scene is up.
func _world_parent() -> Node:
	if is_inside_tree() and get_tree() != null and get_tree().current_scene != null:
		return get_tree().current_scene
	return self
# One node out of a pool's free list, or a fresh copy of the pool's scene when the stash is empty.
# Null when there is no pool by that name, and null when an empty custom pool has no scene of its
# own to make one from. The node is NOT counted active here: each spawn row does that at the
# moment it means it.
func _take_from_pool(pool_name: String) -> Node:
	if not _pools.has(pool_name):
		return null
	var free_list: Array = _pools[pool_name].free
	if not free_list.is_empty():
		return free_list.pop_back()
	if _pools[pool_name].scene == null:
		return null
	var node: Node = (_pools[pool_name].scene as PackedScene).instantiate()
	node.set_meta(&"__pool__", pool_name)
	return node
# The retire runtime if the project has it, found once and remembered - null when it does not, in
# which case this pool hands nodes back on its own and marks nothing.
func _retire_runtime_script() -> Script:
	if _retire_runtime_looked_up:
		return _retire_runtime
	_retire_runtime_looked_up = true
	if ResourceLoader.exists(RETIRE_RUNTIME_PATH):
		_retire_runtime = load(RETIRE_RUNTIME_PATH) as Script
	return _retire_runtime

## @ace_action
## @ace_featured
## @ace_name("Create Pool")
## @ace_category("Object Pool")
## @ace_description("The easy way: makes a pool that spawns copies of a scene (a .tscn path), optionally pre-making some now so the first spawns never hitch.")
## @ace_display_template("Create pool [b]{pool_name}[/b] of [b]{scene_path}[/b], prewarm [b]{prewarm}[/b]")
## @ace_icon("res://eventsheet_addons/object_pool/icon.svg")
## @ace_codegen_template("ObjectPool.create_pool({pool_name}, {scene_path}, {prewarm})")
func create_pool(pool_name: String, scene_path: String, prewarm: int) -> void:
	var scene: PackedScene = load(scene_path) as PackedScene
	_pools[pool_name] = {"scene": scene, "free": [], "active": []}
	if scene == null:
		return
	for _i: int in maxi(prewarm, 0):
		_stow(pool_name, scene.instantiate())

## @ace_action
## @ace_name("Create Empty Pool")
## @ace_category("Object Pool")
## @ace_description("The custom way: makes a pool with no scene of its own. Fill it with Add To Pool (your own nodes), and Spawn hands those back out.")
## @ace_icon("res://eventsheet_addons/object_pool/icon.svg")
## @ace_codegen_template("ObjectPool.create_empty_pool({pool_name})")
func create_empty_pool(pool_name: String) -> void:
	_pools[pool_name] = {"scene": null, "free": [], "active": []}

## @ace_action
## @ace_name("Add To Pool")
## @ace_category("Object Pool")
## @ace_description("Puts one of your own existing nodes into a pool as a ready-to-reuse instance (for custom pools). The node is hidden and parked until spawned.")
## @ace_icon("res://eventsheet_addons/object_pool/icon.svg")
## @ace_codegen_template("ObjectPool.add_to_pool({pool_name}, {node})")
func add_to_pool(pool_name: String, node: Node) -> void:
	_stow(pool_name, node)

## @ace_action
## @ace_name("Prewarm")
## @ace_category("Object Pool")
## @ace_description("Pre-makes more copies for a scene pool (so a burst of spawns stays smooth).")
## @ace_icon("res://eventsheet_addons/object_pool/icon.svg")
## @ace_codegen_template("ObjectPool.prewarm({pool_name}, {count})")
func prewarm(pool_name: String, count: int) -> void:
	if not _pools.has(pool_name) or _pools[pool_name].scene == null:
		return
	for _i: int in maxi(count, 0):
		_stow(pool_name, (_pools[pool_name].scene as PackedScene).instantiate())

## @ace_action
## @ace_featured
## @ace_name("Despawn")
## @ace_category("Object Pool")
## @ace_description("Hands a spawned node back to its pool to be reused (hides it and stops its processing) instead of freeing it. Fires On Despawned. The handing back lands at the next idle moment rather than on this line, exactly as a destroy does, so the node is still in the world for the rest of the event and the row is safe inside a collision or area callback. Safe to run twice - a node already booked, or already back in its pool, is left alone.")
## @ace_display_template("Despawn [i]{node}[/i]")
## @ace_icon("res://eventsheet_addons/object_pool/icon.svg")
## @ace_codegen_template("ObjectPool.despawn({node})")
func despawn(node: Node) -> void:
	if node == null or not is_instance_valid(node) or node.is_queued_for_deletion():
		return
	if not node.has_meta(&"__pool__"):
		return
	var pool_name: String = str(node.get_meta(&"__pool__"))
	if not _pools.has(pool_name) or (_pools[pool_name].free as Array).has(node):
		return
	if _already_retiring(node):
		_hand_back_now(pool_name, node)
		return
	if _booked.has(node.get_instance_id()):
		return
	_booked[node.get_instance_id()] = true
	call_deferred(&"_hand_back_by_id", node.get_instance_id())

## @ace_action
## @ace_name("Despawn All")
## @ace_category("Object Pool")
## @ace_description("Hands every active node of a pool back at once (for a level reset). Like Despawn, each handing back lands at the next idle moment.")
## @ace_icon("res://eventsheet_addons/object_pool/icon.svg")
## @ace_codegen_template("ObjectPool.despawn_all({pool_name})")
func despawn_all(pool_name: String) -> void:
	if not _pools.has(pool_name):
		return
	for node: Node in (_pools[pool_name].active as Array).duplicate():
		despawn(node)

## @ace_action
## @ace_name("Clear Pool")
## @ace_category("Object Pool")
## @ace_description("Frees (deletes) every node in a pool and removes the pool. Use it when the pool is truly done.")
## @ace_icon("res://eventsheet_addons/object_pool/icon.svg")
## @ace_codegen_template("ObjectPool.clear_pool({pool_name})")
func clear_pool(pool_name: String) -> void:
	if not _pools.has(pool_name):
		return
	for node: Node in (_pools[pool_name].free as Array) + (_pools[pool_name].active as Array):
		if is_instance_valid(node):
			node.queue_free()
	_pools.erase(pool_name)

## @ace_condition
## @ace_name("Has Pool")
## @ace_category("Object Pool")
## @ace_description("Whether a pool with this name exists.")
## @ace_icon("res://eventsheet_addons/object_pool/icon.svg")
## @ace_codegen_template("ObjectPool.has_pool({pool_name})")
func has_pool(pool_name: String) -> bool:
	return _pools.has(pool_name)

## @ace_expression
## @ace_name("Spawn")
## @ace_category("Object Pool")
## @ace_description("Hands out a ready node from a pool (reusing a free one, or making a new copy from the pool's scene) - added to the current scene, shown, and returned so you can position it. Fires On Spawned. Returns nothing if the pool is empty and has no scene.")
## @ace_icon("res://eventsheet_addons/object_pool/icon.svg")
## @ace_codegen_template("ObjectPool.spawn({pool_name})")
func spawn(pool_name: String) -> Node:
	var node: Node = _take_from_pool(pool_name)
	if node == null:
		return null
	_wake(node)
	(_pools[pool_name].active as Array).append(node)
	_last_spawned = node
	on_spawned.emit()
	return node

## @ace_expression
## @ace_name("Spawn Safely")
## @ace_category("Object Pool")
## @ace_description("The same spawn, with the copy joining the world on the next idle moment instead of on this line. Use it inside a collision or area callback: Godot refuses to reparent a node while the physics server is flushing its queries, and this row waits for that to finish rather than erroring. You get the node back straight away, reset, shown and put where you say, so the rows after it can configure it - it is still parked under the pool for the rest of the event, and under the running scene from the next frame. On Spawned fires at that later moment, with the copy already in the world, so a row under it can read the copy's parent. Outside a callback prefer plain Spawn, whose copy is in the world on the line. Returns nothing if the pool is empty and has no scene.")
## @ace_param(at, default: Vector2.ZERO, desc: "Where the copy goes, set before it joins the world - so it is a place relative to the parent it is about to get, and a pool has no transform of its own. A Vector3 places a 3D copy; a value of the wrong shape for the copy is left alone.")
## @ace_icon("res://eventsheet_addons/object_pool/icon.svg")
## @ace_codegen_template("ObjectPool.spawn_safely({pool_name}, {at})")
func spawn_safely(pool_name: String, at: Variant) -> Node:
	var node: Node = _take_from_pool(pool_name)
	if node == null:
		return null
	_ready_for_use(node)
	_place(node, at)
	(_pools[pool_name].active as Array).append(node)
	call_deferred(&"_join_world_by_id", node.get_instance_id())
	return node

## @ace_expression
## @ace_name("Last Spawned")
## @ace_category("Object Pool")
## @ace_description("The node most recently spawned (handy inside On Spawned).")
## @ace_icon("res://eventsheet_addons/object_pool/icon.svg")
## @ace_codegen_template("ObjectPool.last_spawned()")
func last_spawned() -> Node:
	return _last_spawned

## @ace_expression
## @ace_name("Last Despawned")
## @ace_category("Object Pool")
## @ace_description("The node most recently despawned (handy inside On Despawned).")
## @ace_icon("res://eventsheet_addons/object_pool/icon.svg")
## @ace_codegen_template("ObjectPool.last_despawned()")
func last_despawned() -> Node:
	return _last_despawned

## @ace_expression
## @ace_name("Free Count")
## @ace_category("Object Pool")
## @ace_description("How many ready (unused) nodes a pool holds.")
## @ace_icon("res://eventsheet_addons/object_pool/icon.svg")
## @ace_codegen_template("ObjectPool.free_count({pool_name})")
func free_count(pool_name: String) -> int:
	return (_pools[pool_name].free as Array).size() if _pools.has(pool_name) else 0

## @ace_expression
## @ace_name("Active Count")
## @ace_category("Object Pool")
## @ace_description("How many of a pool's nodes are currently spawned and in use.")
## @ace_icon("res://eventsheet_addons/object_pool/icon.svg")
## @ace_codegen_template("ObjectPool.active_count({pool_name})")
func active_count(pool_name: String) -> int:
	return (_pools[pool_name].active as Array).size() if _pools.has(pool_name) else 0

## @ace_expression
## @ace_name("Pool Size")
## @ace_category("Object Pool")
## @ace_description("A pool's total nodes (free plus active).")
## @ace_icon("res://eventsheet_addons/object_pool/icon.svg")
## @ace_codegen_template("ObjectPool.pool_size({pool_name})")
func pool_size(pool_name: String) -> int:
	return ((_pools[pool_name].free as Array).size() + (_pools[pool_name].active as Array).size()) if _pools.has(pool_name) else 0

func _stow(pool_name: String, node: Node) -> void:
	# Parks a node in a pool's free list: reparented under the ObjectPool, hidden, processing off.
	# A pooled node never sits in the running scene while it waits to be reused.
	if node == null or not _pools.has(pool_name):
		return
	node.set_meta(&"__pool__", pool_name)
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	add_child(node)
	if node is CanvasItem:
		(node as CanvasItem).visible = false
	node.set_process(false)
	node.set_physics_process(false)
	# A recycled node carries no credit from its last life: the ownership key a spawn row
	# claimed it with comes off here, so the next Claim is the only one that counts and a
	# reused bullet can never be credited to whoever fired the one before it.
	if node.has_meta(&"owner"):
		node.remove_meta(&"owner")
	(_pools[pool_name].free as Array).append(node)

func _ready_for_use(node: Node) -> void:
	# The half of waking that is NOT a reparent: shown, processing on, and the pooled scene's own
	# reset(). Split out because Spawn Safely does exactly this half on the line and books the other,
	# and because reset() has to run before the row hands the node back to the sheet - a reset after
	# the following rows configured the copy would wipe what they just wrote.
	if node is CanvasItem:
		(node as CanvasItem).visible = true
	node.set_process(true)
	node.set_physics_process(true)
	# The reset seam: a pooled scene that defines reset() gets it called on every
	# spawn, so velocity/hp/timers clear without the pool knowing any of them.
	if node.has_method(&"reset"):
		node.call(&"reset")

func _wake(node: Node) -> void:
	# Wakes a node into the running scene: reparented to the current scene, shown, processing on.
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	_world_parent().add_child(node)
	_ready_for_use(node)

func _place(node: Node, at: Variant) -> void:
	# Puts a copy where the row said, in whichever dimension the copy lives in. The place is set
	# BEFORE the copy joins the world, so it is a place relative to its parent - and a pool has no
	# transform of its own, so the number a row writes is the number the copy lands on. A value of the
	# wrong shape for the node (a Vector2 for a Node3D) is left alone rather than raising.
	if node is Node2D and at is Vector2:
		(node as Node2D).position = at as Vector2
	elif node is Node3D and at is Vector3:
		(node as Node3D).position = at as Vector3
	elif node is Control and at is Vector2:
		(node as Control).position = at as Vector2

func _join_world_by_id(node_id: int) -> void:
	# THE JOINING WAITS FOR THE FRAME TOO, for Spawn Safely and for that row only. Handing a copy out
	# is a reparent exactly as handing one back is, and Godot refuses a reparent while the physics
	# server is flushing its queries - the whole of a collision or area callback. So Spawn Safely does
	# everything but the reparent on the line and books this, and On Spawned is raised HERE, with the
	# copy already in the world, so a row under that trigger can read the copy's parent.
	# Resolved from an id rather than from the node, because a row can free the copy again before this
	# lands, and an id that no longer names anything is simply an answer of no. A copy a Despawn row
	# already took back is no longer counted active, and is left parked where it is.
	if not is_instance_id_valid(node_id):
		return
	var node: Node = instance_from_id(node_id) as Node
	if node == null or not is_instance_valid(node) or node.is_queued_for_deletion():
		return
	if not node.has_meta(&"__pool__"):
		return
	var pool_name: String = str(node.get_meta(&"__pool__"))
	if not _pools.has(pool_name) or not (_pools[pool_name].active as Array).has(node):
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	_world_parent().add_child(node)
	_last_spawned = node
	on_spawned.emit()

func _already_retiring(node: Node) -> bool:
	# Whether this node is inside a handing over the retire runtime has already marked - which is to
	# say a Retire row booked the idle moment we are standing in, so the reparent is safe on this line.
	# Asked after Despawn's queued-for-deletion guard, so the answer is the mark and nothing else.
	var runtime: Script = _retire_runtime_script()
	return runtime != null and bool(runtime.call(&"is_retiring", node))

func _hand_back_by_id(node_id: int) -> void:
	# The booked half, resolved from an id rather than from the node itself: a node can be freed between
	# the Despawn row and the idle moment that hands it over, and an id that no longer names anything is
	# simply an answer of no.
	_booked.erase(node_id)
	if not is_instance_id_valid(node_id):
		return
	var node: Node = instance_from_id(node_id) as Node
	if node == null or not is_instance_valid(node) or node.is_queued_for_deletion():
		return
	var runtime: Script = _retire_runtime_script()
	if runtime != null:
		# Out through the runtime and straight back in, so the handing over is MARKED while it happens:
		# that mark is what On Retired's guard reads, so a Despawn row raises that trigger exactly once,
		# exactly as a Retire row does.
		runtime.call(&"hand_back", node, self)
		return
	_hand_back_now(str(node.get_meta(&"__pool__")), node)

func _hand_back_now(pool_name: String, node: Node) -> void:
	# The handing over itself, with the waiting already done: out of the active list, parked under the
	# pool, and the pack's own signal to say it happened - once, because a node already in the free list
	# is turned back here.
	if not _pools.has(pool_name) or (_pools[pool_name].free as Array).has(node):
		return
	(_pools[pool_name].active as Array).erase(node)
	_stow(pool_name, node)
	_last_despawned = node
	on_despawned.emit()

# ObjectPool: register as the ObjectPool autoload. Create Pool from a scene (or Create Empty Pool + Add To Pool your own nodes), then Spawn to get a ready node and Despawn to hand it back. Reusing nodes keeps heavy scenes smooth. This pack is an event sheet - extend it by editing it.
