# EventForge runtime - retiring a node: back to the pool that made it, or out of the world.
#
# Destroying is `queue_free()` and every destroy row in the language writes it. RETIRING is the
# other answer to the same question, and it is the one a pooled game wants: a node that came out of
# an object pool goes BACK to that pool to be handed out again, and a node that came from anywhere
# else is freed exactly as before. Which of the two a node is, is written on the node - the pool
# stamps every copy it hands out - so nothing has to be remembered by the sheet and nothing has to
# be configured.
#
# WHY THIS IS A FILE AND NOT THREE LINES IN A TEMPLATE. The pool is an autoload, so a template that
# named it would put an identifier into every generated script that only parses in a project which
# installed the pool pack. Resolving it HERE, by path, at run time, is what lets the same row work in
# a project with a pool and in one without: no pool, or no stamp, and the node is freed.
#
# PLAIN GDSCRIPT, NO PLUGIN. Nothing here touches the editor, the sheet format or any EventForge
# class, so a generated game carries this file the way it carries any other runtime script - and the
# emitted line reads exactly like a line somebody would write by hand.
class_name PooledNodes
extends RefCounted

## Where an object pool registers itself. An absolute path, which resolves from any node in the
## tree, so the lookup needs nothing about where the caller sits.
const POOL_AUTOLOAD_PATH: String = "/root/ObjectPool"

## The mark a pool leaves on every copy it hands out - the pool's own name. Reading it is how this
## file knows a node is pooled without asking the pool to search for it.
const POOL_META: StringName = &"__pool__"

## The method a pool takes a node back through.
const POOL_METHOD: StringName = &"despawn"


## Retires a node: hands it back to the pool that made it when there is one, and frees it otherwise.
## Safe to call twice and safe to call on null - a node already on its way out is left alone rather
## than freed a second time.
static func retire(node: Node) -> void:
	retire_into(node, pool_of(node))


## The doing, with the deciding already done. Separated from the question above so that BOTH answers
## can be watched: a pool is something a test can hand in, where "the autoload at /root/ObjectPool"
## is something only a running game has. A null pool is the ordinary case and means destroy.
static func retire_into(node: Node, pool: Node) -> void:
	if node == null or not is_instance_valid(node) or node.is_queued_for_deletion():
		return
	if pool != null and is_instance_valid(pool) and pool.has_method(POOL_METHOD):
		pool.call(POOL_METHOD, node)
		return
	node.queue_free()


## True when this node came out of a pool that is still in the tree - the question Retire asks, made
## available on its own so a sheet can ask it too.
static func is_pooled(node: Node) -> bool:
	return pool_of(node) != null


## The pool a node came out of, or null when it came from anywhere else. Null covers all four ways
## the answer can be no: the node is not in a tree, it carries no pool mark, nothing is registered at
## the autoload path, and whatever is registered there cannot take a node back.
static func pool_of(node: Node) -> Node:
	if node == null or not is_instance_valid(node) or not node.is_inside_tree():
		return null
	if not node.has_meta(POOL_META):
		return null
	var pool: Node = node.get_node_or_null(POOL_AUTOLOAD_PATH)
	if pool == null or not pool.has_method(POOL_METHOD):
		return null
	return pool
