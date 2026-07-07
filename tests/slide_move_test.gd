# Godot EventSheets - slide_move pack (grid slide-to-wall behavior) logic.
#
# Loads the COMPILED behavior with a bare Node2D host (not in the tree). The wall raycast in
# _scan_target is guarded by is_inside_tree(), so out of the tree a Slide safely reports "hit wall"
# with no move - which lets this prove the grid math and state machine (direction mapping, snap /
# teleport / tile coordinates, the sliding flag) without a physics world; the actual gliding is felt
# by playing.
@tool
class_name SlideMoveTest
extends RefCounted

const PACK := "res://eventsheet_addons/slide_move/slide_move_behavior.gd"


static func run() -> bool:
	var all_passed: bool = true
	var script: GDScript = load(PACK)
	all_passed = _check("slide_move pack loads + parses", script != null, true) and all_passed
	if script == null:
		return all_passed

	var sm: Node = script.new()
	var host: Node2D = Node2D.new()
	sm.host = host

	# Direction word -> unit step (screen axes: down is +Y).
	all_passed = _check("direction words map to grid steps",
		sm._dir_from("left") == Vector2.LEFT and sm._dir_from("right") == Vector2.RIGHT
		and sm._dir_from("up") == Vector2.UP and sm._dir_from("down") == Vector2.DOWN
		and sm._dir_from("nonsense") == Vector2.ZERO, true) and all_passed

	# Teleport to a tile puts it at tile * grid_size, and the tile expressions read it back.
	sm.teleport_to_tile(3, 2)
	all_passed = _check("Teleport To Tile places the node on that tile",
		host.global_position == Vector2(192, 128) and sm.tile_x() == 3 and sm.tile_y() == 2, true) and all_passed

	all_passed = _check("a fresh behavior is not sliding", sm.is_sliding(), false) and all_passed

	# Out of the tree there is no physics world, so a Slide safely reports a wall and does not move.
	var hit: Array = [0]
	sm.on_hit_wall.connect(func() -> void: hit[0] += 1)
	sm.slide("right")
	all_passed = _check("Slide with no reachable tile reports On Hit Wall and does not start sliding",
		hit[0] == 1 and not sm.is_sliding() and sm.slide_direction() == "right", true) and all_passed
	all_passed = _check("Can Slide is false when the way is not open", sm.can_slide("up"), false) and all_passed

	# Snap and grid-size changes.
	host.global_position = Vector2(70, 70)
	sm.snap_to_grid()
	all_passed = _check("Snap To Grid rounds to the nearest intersection", host.global_position, Vector2(64, 64)) and all_passed
	sm.set_grid_size(32.0)
	sm.teleport_to_tile(4, 0)
	all_passed = _check("Set Grid Size changes the tile spacing", host.global_position, Vector2(128, 0)) and all_passed

	sm.free()
	host.free()
	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] slide_move_test: %s" % label)
		return true
	print("[FAIL] slide_move_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
