# Godot EventSheets - time_slicer pack (frame-spreading Solution 1) behavior.
#
# A managed work queue that drains within a per-frame budget. This loads the COMPILED pack and drives
# the real drain loop in COUNT mode (deterministic; ms mode is wall-clock and timing-dependent) to prove
# the budget cap, the per-item On Process Item signal, the On Drained edge, and the queue accounting.
@tool
class_name TimeSlicerPackTest
extends RefCounted

const PACK := "res://eventsheet_addons/time_slicer/time_slicer_behavior.gd"


static func run() -> bool:
	var all_passed: bool = true
	var script: GDScript = load(PACK)
	all_passed = _check("time_slicer pack loads + parses", script != null, true) and all_passed
	if script == null:
		return all_passed

	var ts: Node = script.new()
	ts.mode = "count"
	ts.max_items_per_frame = 10

	var processed: Array = []
	ts.process_item.connect(func(item: Variant) -> void: processed.append(item))
	var drained_fired: Array = [false]
	ts.drained.connect(func() -> void: drained_fired[0] = true)

	for i in 100:
		ts.enqueue_item(i)
	all_passed = _check("queue holds the enqueued items", ts.items_remaining(), 100) and all_passed
	all_passed = _check("a non-empty slicer is busy", ts.is_busy(), true) and all_passed

	# One frame processes exactly the count budget.
	ts._process(0.016)
	all_passed = _check("a frame processes the count budget", processed.size(), 10) and all_passed
	all_passed = _check("last frame item count reports it", ts.last_frame_item_count(), 10) and all_passed
	all_passed = _check("the rest stay queued", ts.items_remaining(), 90) and all_passed
	all_passed = _check("not drained yet", drained_fired[0], false) and all_passed

	# Nine more frames drain the remaining 90; On Drained fires the frame it empties.
	for _f in 9:
		ts._process(0.016)
	all_passed = _check("every item is eventually processed", processed.size(), 100) and all_passed
	all_passed = _check("queue empties", ts.items_remaining(), 0) and all_passed
	all_passed = _check("On Drained fires at empty", drained_fired[0], true) and all_passed
	all_passed = _check("an empty slicer is not busy", ts.is_busy(), false) and all_passed

	# Pause halts draining even with items queued.
	ts.enqueue_items([1, 2, 3])
	ts.pause_slicer()
	ts._process(0.016)
	all_passed = _check("pause halts draining", ts.items_remaining(), 3) and all_passed
	ts.resume_slicer()
	ts._process(0.016)
	all_passed = _check("resume drains again", ts.items_remaining(), 0) and all_passed

	ts.free()
	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] time_slicer_pack_test: %s" % label)
		return true
	print("[FAIL] time_slicer_pack_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
