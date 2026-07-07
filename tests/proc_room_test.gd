# Godot EventSheets - proc_room pack (seeded room-graph generator autoload) smoke + rules.
#
# Loads the COMPILED pack and generates from a fixed seed string (pure logic + signals; no tree
# needed). Proves reproducibility, start/boss placement, full reachability (every room has a parent,
# so start connects through to boss), and the enter/block/lock traversal rules.
@tool
class_name ProcRoomTest
extends RefCounted

const PACK := "res://eventsheet_addons/proc_room/proc_room_addon.gd"


static func run() -> bool:
	var all_passed: bool = true
	var script: GDScript = load(PACK)
	all_passed = _check("proc_room pack loads + parses", script != null, true) and all_passed
	if script == null:
		return all_passed

	var pr: Node = script.new()
	var generated: Array = [0]
	var entered: Array = [0]
	var blocked: Array = [0]
	pr.on_graph_generated.connect(func() -> void: generated[0] += 1)
	pr.on_room_entered.connect(func() -> void: entered[0] += 1)
	pr.on_traversal_blocked.connect(func() -> void: blocked[0] += 1)

	pr.register_room_type("combat", 10.0, 1, -1, -1)
	pr.register_room_type("shop", 3.0, 2, -1, 1)
	pr.register_room_type("elite", 2.0, 3, -1, -1)
	pr.generate("run-1", 6, 3)
	all_passed = _check("Generate builds a ready graph and fires On Graph Generated",
		pr.is_graph_ready() and generated[0] == 1 and pr.total_depths() == 6 and pr.total_rooms() >= 6, true) and all_passed
	all_passed = _check("the map starts at the start room",
		pr.current_room() == "d0_0" and pr.current_room_type() == "start" and pr.graph_seed() == "run-1", true) and all_passed
	all_passed = _check("depth 0 is start and the last depth is boss",
		pr.room_type("d0_0") == "start" and pr.room_type(pr.room_at_depth(5, 0)) == "boss", true) and all_passed

	# Reproducibility: same seed + settings = same map.
	var rooms_a: int = pr.total_rooms()
	var type_a: String = pr.room_type("d2_0")
	pr.generate("run-1", 6, 3)
	all_passed = _check("the same seed reproduces the same map", pr.total_rooms() == rooms_a and pr.room_type("d2_0") == type_a, true) and all_passed

	# Full reachability: every non-start room has at least one parent.
	var orphans: int = 0
	for id: String in pr._rooms:
		if id != "d0_0" and (pr._rooms[id].from as Array).is_empty():
			orphans += 1
	all_passed = _check("every room is reachable (no orphan rooms; start connects through to boss)", orphans, 0) and all_passed

	# Traversal: enter a connected room; visited + On Room Entered fire.
	all_passed = _check("the start room has at least one forward connection", pr.connections_from("d0_0") >= 1, true) and all_passed
	var first_hop: String = pr.connection_from("d0_0", 0)
	pr.enter_room(first_hop)
	all_passed = _check("entering a connected room moves the player and marks it visited",
		entered[0] == 1 and pr.current_room() == first_hop and pr.is_room_visited(first_hop)
		and pr.previous_room() == "d0_0" and pr.entered_id() == first_hop, true) and all_passed

	# Blocked: a far, unconnected room reports "unreachable".
	pr.enter_room("d3_0")
	all_passed = _check("entering an unreachable room is blocked with a reason",
		blocked[0] == 1 and pr.blocked_id() == "d3_0" and pr.block_reason() == "unreachable", true) and all_passed

	# Locked: locking a reachable neighbour blocks it with reason "locked".
	pr.reset_traversal()
	var hop: String = pr.connection_from("d0_0", 0)
	pr.lock_room(hop)
	pr.enter_room(hop)
	all_passed = _check("a locked room blocks entry with reason locked",
		pr.block_reason() == "locked" and not pr.is_room_visited(hop) and pr.is_room_locked(hop), true) and all_passed
	pr.unlock_room(hop)
	pr.enter_room(hop)
	all_passed = _check("unlocking lets the player through", pr.current_room() == hop, true) and all_passed

	# Reset returns to the start with only it visited.
	pr.reset_traversal()
	all_passed = _check("Reset Traversal returns to start with a fresh visited set",
		pr.current_room() == "d0_0" and pr.visited_count() == 1, true) and all_passed

	pr.free()
	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] proc_room_test: %s" % label)
		return true
	print("[FAIL] proc_room_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
