# Godot EventSheets - object_pool pack (node reuse autoload) smoke + rules.
#
# Loads the COMPILED pack and drives it directly. It never enters the tree, but Spawn's _wake is guarded
# by is_inside_tree() (falling back to parenting under the pool itself), so the whole spawn / despawn /
# reuse cycle works headless. Covers both paths: a CUSTOM pool (Add To Pool your own nodes) and a SCENE
# pool (Create Pool + Prewarm from a saved .tscn), plus the counts and reuse.
#
# And the one rule that is not a count: DESPAWN WAITS FOR THE FRAME. Handing a node back is a reparent,
# and Godot refuses a reparent while the physics server is flushing its queries - which is the whole of
# a collision or area callback, and exactly where a bullet is despawned. So the row books the handing
# back and it lands at the next idle moment. A suite has no message queue, so the booked moment is run
# by hand here, exactly as the retire gate runs the runtime's.
#
# And the same rule from the other end: SPAWN SAFELY books its joining. Handing a copy out is a reparent
# too, so the row places, shows and counts the copy on the line and books only the joining - which is
# where On Spawned is raised, with the copy already in the world. The shipped Spawn is unchanged and its
# pins above still say so: its copy is in the world on the line.
@tool
class_name ObjectPoolTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
## The retire runtime, by path rather than by class name - the same way the pack finds it, and the
## file whose retiring mark On Retired's guard reads.
const RETIRE_RUNTIME := preload("res://eventsheet_addons/pooled_nodes.gd")
const PACK := "res://eventsheet_addons/object_pool/object_pool_addon.gd"
const SCENE_PATH := "user://__objpool_test.tscn"


static func run() -> bool:
	var all_passed: bool = true
	var script: GDScript = load(PACK)
	all_passed = _check("object_pool pack loads + parses", script != null, true) and all_passed
	if script == null:
		return all_passed

	var op: Node = script.new()
	# Stands in for the running scene a spawned copy is parented to. Without a scene tree the pool
	# parks a woken copy under itself, which is not where a game leaves it.
	var world: Node = Node.new()
	var spawned: Array = [0]
	var despawned: Array = [0]
	# What On Retired's guard would see at the moment the pack says a node went back: the handing
	# over raises tree_exiting, and the pack's own signal is emitted from inside the same call.
	var retiring_while_handed_back: Array[bool] = []
	op.on_spawned.connect(func() -> void: spawned[0] += 1)
	op.on_despawned.connect(func() -> void: despawned[0] += 1)
	op.on_despawned.connect(func() -> void: retiring_while_handed_back.append(RETIRE_RUNTIME.is_retiring(op.last_despawned())))

	# Custom pool: add your own node, spawn it, despawn it, reuse it.
	op.create_empty_pool("bullets")
	all_passed = _check("Create Empty Pool makes an empty pool", op.has_pool("bullets") and op.free_count("bullets") == 0, true) and all_passed
	var bullet: Node2D = Node2D.new()
	op.add_to_pool("bullets", bullet)
	all_passed = _check("Add To Pool parks a node as ready and hidden",
		op.free_count("bullets") == 1 and not bullet.visible, true) and all_passed
	var got: Node = op.spawn("bullets")
	all_passed = _check("Spawn hands out the pooled node, shown and counted active",
		got == bullet and bullet.visible and op.free_count("bullets") == 0 and op.active_count("bullets") == 1 and spawned[0] == 1 and op.last_spawned() == bullet, true) and all_passed
	_into_the_world(world, bullet)

	# The line itself moves nothing: that is what makes a Despawn row safe inside a collision or area
	# callback, where a reparent is the one thing Godot refuses.
	op.despawn(bullet)
	all_passed = _check("Despawn hands nothing over on the line itself",
		bullet.get_parent() == world and op.free_count("bullets") == 0 and op.active_count("bullets") == 1 and despawned[0] == 0, true) and all_passed
	# Twice in one frame books one handing back, not two - a node in a free list twice is handed out
	# to two callers, which is the worst thing a pool can do.
	op.despawn(bullet)
	op._hand_back_by_id(bullet.get_instance_id())
	all_passed = _check("the booked moment parks it back, hidden, and counts it free again",
		bullet.get_parent() == op and not bullet.visible and op.free_count("bullets") == 1 and op.active_count("bullets") == 0 and despawned[0] == 1 and op.last_despawned() == bullet, true) and all_passed
	all_passed = _check("and On Retired's guard sees a retirement while it happens",
		retiring_while_handed_back, [true] as Array[bool]) and all_passed
	# The booked moment run a second time, and a Despawn row on a node already back home: neither
	# puts it in the free list twice, and neither fires the signal again.
	op._hand_back_by_id(bullet.get_instance_id())
	op.despawn(bullet)
	all_passed = _check("running the booked moment again changes nothing",
		op.free_count("bullets") == 1 and op.pool_size("bullets") == 1 and despawned[0] == 1, true) and all_passed

	var again: Node = op.spawn("bullets")
	all_passed = _check("Spawn reuses the same freed node (no new instance)", again == bullet and op.free_count("bullets") == 0, true) and all_passed
	_into_the_world(world, bullet)
	op.despawn_all("bullets")
	op._hand_back_by_id(bullet.get_instance_id())
	all_passed = _check("Despawn All returns every active node", op.active_count("bullets") == 0 and op.free_count("bullets") == 1, true) and all_passed

	# A node freed between the Despawn row and the booked moment: the booking holds an id, not the
	# node, so an id that names nothing any more is simply an answer of no.
	op.create_empty_pool("sparks")
	var spark: Node2D = Node2D.new()
	op.add_to_pool("sparks", spark)
	var doomed: Node = op.spawn("sparks")
	_into_the_world(world, doomed)
	var doomed_id: int = doomed.get_instance_id()
	var despawns_so_far: int = despawned[0]
	op.despawn(doomed)
	doomed.free()
	op._hand_back_by_id(doomed_id)
	all_passed = _check("a node freed before the booked moment is skipped quietly",
		op.free_count("sparks") == 0 and despawned[0] == despawns_so_far, true) and all_passed

	# Scene pool: prewarm copies of a .tscn, then spawn from the stash.
	var proto: Node2D = Node2D.new()
	var packed: PackedScene = PackedScene.new()
	packed.pack(proto)
	proto.free()
	ResourceSaver.save(packed, SCENE_PATH)
	op.create_pool("fx", SCENE_PATH, 3)
	all_passed = _check("Create Pool with prewarm pre-makes copies",
		op.free_count("fx") == 3 and op.pool_size("fx") == 3, true) and all_passed
	var fx: Node = op.spawn("fx")
	all_passed = _check("Spawn from a scene pool pulls a prewarmed copy",
		fx != null and op.free_count("fx") == 2 and op.active_count("fx") == 1, true) and all_passed
	op.prewarm("fx", 2)
	all_passed = _check("Prewarm adds more ready copies", op.free_count("fx") == 4, true) and all_passed

	# SPAWN SAFELY: the twin that books its reparent. Handing a copy OUT is a reparent exactly as handing
	# one back is, so the row does everything but that on the line - out of the free list, placed, shown,
	# counted active, returned - and books the joining for the next idle moment. On Spawned is raised
	# there rather than here, with the copy already in the world, so a row under it can read its parent.
	op.create_empty_pool("safe")
	var ready_made: Node2D = Node2D.new()
	op.add_to_pool("safe", ready_made)
	var spawns_so_far: int = spawned[0]
	var safely: Node = op.spawn_safely("safe", Vector2(40, 12))
	all_passed = _check("Spawn Safely hands the copy out placed, shown and active, still parked under the pool",
		safely == ready_made and ready_made.position == Vector2(40, 12) and ready_made.visible and ready_made.get_parent() == op and op.free_count("safe") == 0 and op.active_count("safe") == 1 and spawned[0] == spawns_so_far, true) and all_passed
	op._join_world_by_id(ready_made.get_instance_id())
	all_passed = _check("the booked moment raises On Spawned once, on the copy it was booked for",
		spawned[0] == spawns_so_far + 1 and op.last_spawned() == ready_made and ready_made.position == Vector2(40, 12), true) and all_passed

	# A fresh copy from a scene pool has no parent at all until the booking lands, which is how the
	# joining is visible in a suite with no scene tree: nothing before it, the pool's own fallback
	# world parent after it.
	op.create_pool("safe_fx", SCENE_PATH, 0)
	var fresh: Node = op.spawn_safely("safe_fx", Vector2(7, 9))
	all_passed = _check("a fresh copy is not in the world yet on the line",
		fresh != null and fresh.get_parent() == null and op.active_count("safe_fx") == 1, true) and all_passed
	op._join_world_by_id(fresh.get_instance_id())
	all_passed = _check("and the booked moment adds it under the target parent",
		fresh.get_parent() == op._world_parent(), true) and all_passed

	# A copy freed between the Spawn Safely row and the booked moment: the booking holds an id, not the
	# node, so an id that names nothing any more is simply an answer of no.
	var lost: Node = op.spawn_safely("safe_fx", Vector2.ZERO)
	var lost_id: int = lost.get_instance_id()
	var spawns_before_loss: int = spawned[0]
	lost.free()
	op._join_world_by_id(lost_id)
	all_passed = _check("a copy freed before the booked moment is skipped quietly",
		spawned[0] == spawns_before_loss, true) and all_passed

	all_passed = _check("Has Pool is false for an unknown pool", op.has_pool("nope"), false) and all_passed

	world.free()
	op.free()
	return all_passed


## What _wake does in a running game: a spawned copy is parented to the current scene. This suite has
## no scene tree, so the pool falls back to parenting it under itself - which is where a node that has
## already gone home sits, so the handing back would have nothing to do.
static func _into_the_world(world: Node, node: Node) -> void:
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	world.add_child(node)


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("object_pool_test", label, actual, expected)
