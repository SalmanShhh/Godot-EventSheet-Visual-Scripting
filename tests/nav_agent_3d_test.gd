# Godot EventSheets - Nav Agent 3D pack (the navmesh wrapper, spec P3).
#
# Loads the COMPILED pack and pins: the zero-wiring promise (_ensure_agent inserts and tunes a
# NavigationAgent3D child), the universal-AI-seam driver discovery + release, and VERB SYMMETRY
# with the 2D Platformer Pathfinding pack (a sheet author who learned one knows the other).
# Actual navmesh pathing needs a baked region + stepped physics - verified live in the FPS
# Arena showcase (the smoke asserts the Stalker closes distance on the Player).
@tool
class_name NavAgent3DTest
extends RefCounted

const PACK := "res://eventsheet_addons/nav_agent_3d/nav_agent_3d_behavior.gd"
const PACK_2D := "res://eventsheet_addons/platformer_pathfinding/platformer_pathfinding_behavior.gd"
const FPS := "res://eventsheet_addons/fps_controller/fps_controller_behavior.gd"


static func run() -> bool:
	var all_passed: bool = true
	var script: GDScript = load(PACK)
	all_passed = _check("nav agent 3d pack loads + parses", script != null, true) and all_passed
	if script == null:
		return all_passed

	var host: CharacterBody3D = CharacterBody3D.new()
	var behavior: Node = script.new()
	host.add_child(behavior)
	behavior.set("host", host)

	# ── Zero wiring: the agent child is inserted and tuned on first use ────────────
	behavior.set("agent_radius", 0.7)
	behavior.set("target_desired_distance", 1.5)
	var agent: NavigationAgent3D = behavior._ensure_agent()
	all_passed = _check("a NavigationAgent3D child is auto-inserted", agent != null and agent.get_parent() == host and agent.name == "NavAgent", true) and all_passed
	all_passed = _check("the agent is tuned from the knobs (radius)", is_equal_approx(agent.radius, 0.7), true) and all_passed
	all_passed = _check("the agent is tuned from the knobs (arrive distance)", is_equal_approx(agent.target_desired_distance, 1.5), true) and all_passed
	all_passed = _check("calling again reuses the same agent", behavior._ensure_agent() == agent, true) and all_passed

	# ── Driver discovery on the universal AI seam + release on stop ────────────────
	var driver: Node = (load(FPS) as GDScript).new()
	host.add_child(driver)
	all_passed = _check("the FPS Controller is discovered as the driver (ai_move_x/z seam)", behavior._find_driver() == driver, true) and all_passed
	driver.set("ai_controlled", true)
	driver.set("ai_move_x", 0.4)
	behavior.stop_pathfinding()
	all_passed = _check("Stop Pathfinding releases the driver back to the player", driver.get("ai_controlled"), false) and all_passed
	all_passed = _check("Stop Pathfinding zeroes the driver's intent", is_equal_approx(float(driver.get("ai_move_x")), 0.0), true) and all_passed
	all_passed = _check("Has Path is false after stopping", behavior.has_path(), false) and all_passed

	# ── Verb symmetry with the 2D pack ─────────────────────────────────────────────
	var flat: Node = (load(PACK_2D) as GDScript).new()
	for shared_method: String in ["find_path_to", "find_path_to_node", "stop_pathfinding", "set_auto_control", "has_path"]:
		all_passed = _check("both packs share the verb %s" % shared_method, behavior.has_method(shared_method) and flat.has_method(shared_method), true) and all_passed
	for shared_signal: String in ["path_found", "path_failed", "path_complete", "waypoint_reached"]:
		all_passed = _check("both packs share the trigger %s" % shared_signal, behavior.has_signal(shared_signal) and flat.has_signal(shared_signal), true) and all_passed
	for own_method: String in ["set_avoidance", "bake_navigation_region", "target_is_reachable", "path_move_x", "path_move_z", "current_waypoint_x", "current_waypoint_y", "current_waypoint_z", "distance_to_target"]:
		all_passed = _check("3D-specific method %s exists" % own_method, behavior.has_method(own_method), true) and all_passed
	flat.free()

	host.free()
	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] nav_agent_3d_test: %s" % label)
		return true
	print("[FAIL] nav_agent_3d_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
