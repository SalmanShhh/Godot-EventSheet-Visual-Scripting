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
# THE HANDING BACK WAITS FOR THE FRAME, and that is what makes retiring a safe swap for destroying
# rather than only nearly one. A pool takes a node back by REPARENTING it - out of the running scene
# and under the pool - and Godot refuses a reparent while the physics server is flushing its queries,
# which is the whole of a collision or body callback and exactly where a bullet is retired. Freeing
# has never had this problem, because `queue_free()` already waits for the end of the frame; so the
# pool half waits too, booked on the message queue and done at the next idle moment. Both halves of
# the verb therefore leave the node in the world for the rest of the event, which is the one fact a
# reader has to carry, and neither of them can raise an error from inside a callback.
#
# ONCE, AND ONLY ONCE. A pool's free list is a plain array and a node appended to it twice is handed
# out to two callers, which is the worst thing a pool can do. Two things stop it: a node with a
# handing-back already booked this frame does not book a second one, and a node already parked under
# the pool is left alone. Freeing needs neither - Godot ignores a second `queue_free()` - so the
# guard lives only where it is earned.
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

## The nodes whose handing back is booked and has not happened yet, by instance id. Kept here rather
## than written on the node, because a node that goes back to a pool is handed out again with every
## mark it was carrying still on it, and a mark that outlives the frame it was set in would refuse
## the NEXT retirement of the same node. An entry is dropped by the booked call itself, so the table
## is empty again by the end of the idle moment that emptied it.
static var _booked: Dictionary = {}


## Retires a node: hands it back to the pool that made it when there is one, and frees it otherwise.
## Safe to call twice and safe to call on null - a node already on its way out, or already parked in
## its pool, is left alone rather than handed over a second time.
static func retire(node: Node) -> void:
	retire_into(node, pool_of(node))


## The doing, with the deciding already done. Separated from the question above so that BOTH answers
## can be watched: a pool is something a test can hand in, where "the autoload at /root/ObjectPool"
## is something only a running game has. A null pool is the ordinary case and means destroy.
##
## The pool answer is BOOKED rather than done on this line, for the reason the header states: taking
## a node back is a reparent, and a reparent inside a physics callback is what Godot refuses.
static func retire_into(node: Node, pool: Node) -> void:
	if node == null or not is_instance_valid(node) or node.is_queued_for_deletion():
		return
	if pool != null and is_instance_valid(pool) and pool.has_method(POOL_METHOD):
		if _booked.has(node.get_instance_id()) or node.get_parent() == pool:
			return
		_booked[node.get_instance_id()] = true
		var booked: Callable = hand_back_by_id
		booked.bind(node.get_instance_id(), pool.get_instance_id()).call_deferred()
		return
	node.queue_free()


## The booked half, resolved from ids rather than from the objects themselves: a node can be freed
## between the row that retired it and the idle moment that hands it over, and an id that no longer
## names anything is simply an answer of no.
static func hand_back_by_id(node_id: int, pool_id: int) -> void:
	_booked.erase(node_id)
	if not is_instance_id_valid(node_id) or not is_instance_id_valid(pool_id):
		return
	hand_back(instance_from_id(node_id) as Node, instance_from_id(pool_id) as Node)


## The handing over itself, with nothing deferred and nothing looked up - the one line a pool needs,
## plus the guard that keeps a node out of a free list it is already in. Public because it is the
## half a test can watch: the booking above cannot be seen without a running message queue, and this
## is what the booking does when the queue runs.
static func hand_back(node: Node, pool: Node) -> void:
	if node == null or not is_instance_valid(node) or node.is_queued_for_deletion():
		return
	if pool == null or not is_instance_valid(pool) or not pool.has_method(POOL_METHOD):
		return
	# Already parked. A pool holds the nodes it is keeping as its own children, so this is the
	# question "is it already home" asked of the tree rather than of the pool's private list.
	if node.get_parent() == pool:
		return
	pool.call(POOL_METHOD, node)


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
