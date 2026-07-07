# Godot EventSheets - object_pool pack (node reuse autoload) smoke + rules.
#
# Loads the COMPILED pack and drives it directly. It never enters the tree, but Spawn's _wake is guarded
# by is_inside_tree() (falling back to parenting under the pool itself), so the whole spawn / despawn /
# reuse cycle works headless. Covers both paths: a CUSTOM pool (Add To Pool your own nodes) and a SCENE
# pool (Create Pool + Prewarm from a saved .tscn), plus the counts and reuse.
@tool
class_name ObjectPoolTest
extends RefCounted

const PACK := "res://eventsheet_addons/object_pool/object_pool_addon.gd"
const SCENE_PATH := "user://__objpool_test.tscn"


static func run() -> bool:
	var all_passed: bool = true
	var script: GDScript = load(PACK)
	all_passed = _check("object_pool pack loads + parses", script != null, true) and all_passed
	if script == null:
		return all_passed

	var op: Node = script.new()
	var spawned: Array = [0]
	var despawned: Array = [0]
	op.on_spawned.connect(func() -> void: spawned[0] += 1)
	op.on_despawned.connect(func() -> void: despawned[0] += 1)

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
	op.despawn(bullet)
	all_passed = _check("Despawn parks it back, hidden, and counts it free again",
		not bullet.visible and op.free_count("bullets") == 1 and op.active_count("bullets") == 0 and despawned[0] == 1 and op.last_despawned() == bullet, true) and all_passed
	var again: Node = op.spawn("bullets")
	all_passed = _check("Spawn reuses the same freed node (no new instance)", again == bullet and op.free_count("bullets") == 0, true) and all_passed
	op.despawn_all("bullets")
	all_passed = _check("Despawn All returns every active node", op.active_count("bullets") == 0 and op.free_count("bullets") == 1, true) and all_passed

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

	all_passed = _check("Has Pool is false for an unknown pool", op.has_pool("nope"), false) and all_passed

	op.free()
	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] object_pool_test: %s" % label)
		return true
	print("[FAIL] object_pool_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
