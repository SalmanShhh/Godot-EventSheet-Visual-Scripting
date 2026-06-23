# EventForge — per-pack RawCode budget ratchet (behaviour-as-ACEs parity).
#
# Each bundled behaviour re-authored as code-free ACE rows is pinned to a maximum RawCodeRow count
# (0 = fully code-free). The test FAILS if a pack EXCEEDS its budget — so a GDScript block can never
# silently creep back into a converted pack. As more packs convert, add them here at 0; numeric-kernel
# packs (spring / juice / sine integrators) keep a documented non-zero budget until converted, per the
# spec's honest criterion (continuous math kernels read better as GDScript).
@tool
extends RefCounted
class_name PackRawcodeBudgetTest

const BUDGETS := {
	"res://eventsheet_addons/flash/flash_behavior.tres": 0,
	"res://eventsheet_addons/eight_direction/eight_direction_movement_behavior.tres": 0,
	"res://eventsheet_addons/timer/timer_behavior.tres": 0,
}

static func run() -> bool:
	var ok: bool = true
	for path: String in BUDGETS:
		var budget: int = int(BUDGETS[path])
		var sheet: EventSheetResource = load(path)
		if sheet == null:
			ok = _check("%s loads" % path.get_file(), false, true) and ok
			continue
		var count: int = _count_rawcode(sheet.events)
		for fn: Variant in sheet.functions:
			if fn is EventFunction:
				count += _count_rawcode((fn as EventFunction).events)
		ok = _check("%s within RawCode budget %d (has %d)" % [path.get_file(), budget, count], count <= budget, true) and ok
	return ok

## Counts RawCodeRow rows reachable from a row list: top-level, nested sub-events, and in-flow actions.
static func _count_rawcode(rows: Array) -> int:
	var count: int = 0
	for row: Variant in rows:
		if row is RawCodeRow:
			count += 1
		elif row is EventRow:
			count += _count_rawcode((row as EventRow).sub_events)
			count += _count_rawcode((row as EventRow).actions)
	return count

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] pack_rawcode_budget_test: %s" % label)
		return true
	print("[FAIL] pack_rawcode_budget_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
