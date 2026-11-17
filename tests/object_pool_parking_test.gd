# EventSheets - a node waiting in an Object Pool is disabled, and wakes exactly as it was left.
#
# A parked node used to be hidden with its processing switched off, which left its body in the physics
# space, so a bullet waiting in the pool could still be hit and still collide. It is now disabled (which
# takes a body out of the space), and a node whose own behaviour had parked its tick while idle is woken
# with that tick still parked rather than forced on.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "object_pool_parking_test"
const PACK := "res://eventsheet_addons/object_pool/object_pool_addon.gd"


static func run() -> bool:
	var script: GDScript = load(PACK)
	var pool: Node = script.new()
	var world: Node = Node.new()
	var ticking_script: GDScript = GDScript.new()
	ticking_script.source_code = "extends Node2D\n\nfunc _process(_delta: float) -> void:\n\tpass\n\nfunc _physics_process(_delta: float) -> void:\n\tpass\n"
	ticking_script.reload()
	var active: Node2D = Node2D.new()
	active.set_script(ticking_script)
	var idle: Node2D = Node2D.new()
	idle.set_script(ticking_script)
	idle.process_mode = Node.PROCESS_MODE_ALWAYS
	# Outside a tree a node has not yet switched its ticks on for the functions it defines.
	for ticker: Node2D in [active, idle]:
		ticker.set_process(true)
		ticker.set_physics_process(true)
	pool.create_empty_pool("shots")
	world.add_child(active)
	world.add_child(idle)
	idle.set_process(false)
	var active_before: bool = active.is_processing()
	pool.add_to_pool("shots", active)
	pool.add_to_pool("shots", idle)
	var rows: Array = [
		["a node that ticks has its tick on to begin with", active_before, true],
		["a parked node is disabled", active.process_mode, Node.PROCESS_MODE_DISABLED],
		["and does not process", active.is_processing(), false],
		["and does not process physics", active.is_physics_processing(), false],
	]
	var first: Node = pool.spawn("shots")
	var second: Node = pool.spawn("shots")
	var woke_active: Node = first if first == active else second
	var woke_idle: Node = first if first == idle else second
	rows.append(["a woken node processes again", woke_active.is_processing(), true])
	rows.append(["and processes physics again", woke_active.is_physics_processing(), true])
	rows.append(["and has the process mode it came with", woke_active.process_mode, Node.PROCESS_MODE_INHERIT])
	rows.append(["a node whose tick its own behaviour had parked wakes with it still parked", woke_idle.is_processing(), false])
	rows.append(["while its physics tick, which it had left on, is on", woke_idle.is_physics_processing(), true])
	rows.append(["and it keeps the process mode it had before it was parked", woke_idle.process_mode, Node.PROCESS_MODE_ALWAYS])
	# Handing back lands on the next idle moment; the suite has no message queue, so it is run by hand.
	pool.call("_hand_back_now", "shots", woke_active)
	rows.append(["a node handed back is disabled again", woke_active.process_mode, Node.PROCESS_MODE_DISABLED])
	var again: Node = pool.spawn("shots")
	rows.append(["and wakes as the same node", again, woke_active])
	rows.append(["parked twice, it still remembers how it was first", again.is_processing(), true])
	world.free()
	pool.free()
	return SUPPORT.pins(P, rows)
