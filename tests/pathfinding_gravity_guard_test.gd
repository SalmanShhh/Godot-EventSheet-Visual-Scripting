# Godot EventSheets - the pathfinding-vs-rotated-gravity guard
# Platformer Pathfinding plans in a straight-down frame; the movement packs' gravity_angle
# rotates the movement frame. The combination degrades LOUDLY, never silently: the driver
# warns once at runtime when the sibling movement's angle is not 90, and the Doctor flags
# scenes that combine a gravity_angle with Platformer Pathfinding. Pins: the one-shot flag
# fires on a rotated sibling, stays quiet at the default, the Doctor finding fires on a
# fixture scene and is absent from the real repo.
@tool
class_name PathfindingGravityGuardTest
extends RefCounted

const PATHFINDING_PATH := "res://eventsheet_addons/platformer_pathfinding/platformer_pathfinding_behavior.gd"
const MOVEMENT_PATH := "res://eventsheet_addons/platformer_movement/platformer_movement_behavior.gd"
const FIXTURE_SCENE := "res://__rotated_gravity_probe.tscn"


static func run() -> bool:
	var all_passed: bool = true

	# ---- runtime guard: a rotated sibling warns once, a default sibling never does ----
	var host: CharacterBody2D = CharacterBody2D.new()
	var movement: Node = (load(MOVEMENT_PATH) as Script).new() as Node
	movement.set("gravity_angle", 180.0)
	host.add_child(movement)
	var pathfinding: Node = (load(PATHFINDING_PATH) as Script).new() as Node
	host.add_child(pathfinding)
	pathfinding.set("host", host)
	var found: Node = pathfinding.call("_find_movement")
	all_passed = _check("the sibling movement is found", found == movement, true) and all_passed
	all_passed = _check("a rotated gravity_angle trips the one-shot warning", bool(pathfinding.get("_gravity_angle_warned")), true) and all_passed
	host.free()

	var quiet_host: CharacterBody2D = CharacterBody2D.new()
	var quiet_movement: Node = (load(MOVEMENT_PATH) as Script).new() as Node
	quiet_host.add_child(quiet_movement)
	var quiet_pathfinding: Node = (load(PATHFINDING_PATH) as Script).new() as Node
	quiet_host.add_child(quiet_pathfinding)
	quiet_pathfinding.set("host", quiet_host)
	quiet_pathfinding.call("_find_movement")
	all_passed = _check("the default angle stays quiet", bool(quiet_pathfinding.get("_gravity_angle_warned")), false) and all_passed
	quiet_host.free()

	# ---- the Doctor flags scenes combining the two ----
	var scene_file: FileAccess = FileAccess.open(FIXTURE_SCENE, FileAccess.WRITE)
	scene_file.store_string("[gd_scene format=3]\n\n[node name=\"Agent\" type=\"CharacterBody2D\"]\n; platformer_pathfinding_behavior.gd\ngravity_angle = 0.0\n")
	scene_file.close()
	var findings: Array[Dictionary] = []
	EventSheetProjectDoctor.check_rotated_gravity_pathfinding(findings)
	var fixture_findings: Array[Dictionary] = []
	for finding: Dictionary in findings:
		if str(finding.get("path", "")) == FIXTURE_SCENE:
			fixture_findings.append(finding)
	all_passed = _check("a combining scene gets exactly one finding", fixture_findings.size(), 1) and all_passed
	if fixture_findings.size() == 1:
		all_passed = _check("the finding is advisory", str(fixture_findings[0].get("severity", "")), "info") and all_passed
		all_passed = _check("the finding names the check", str(fixture_findings[0].get("check", "")), "rotated-gravity-pathfinding") and all_passed
	DirAccess.remove_absolute(FIXTURE_SCENE)

	# ---- the real repo is clean: no shipped scene combines the two ----
	findings = []
	EventSheetProjectDoctor.check_rotated_gravity_pathfinding(findings)
	all_passed = _check("no shipped scene trips the check", findings.size(), 0) and all_passed

	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		return true
	print("  [FAIL] pathfinding_gravity_guard_test: %s (got %s, expected %s)" % [label, str(actual), str(expected)])
	return false
