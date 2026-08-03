# EventSheet - the sticky group breadcrumb's enclosure map + chain (pure derivation).
# Pins VALUES: nesting, sibling-group reset, exiting a group, the group-bar-at-top rule (a group
# maps to its PARENT, so the visible bar is never repeated in its own crumb), and top level.
@tool
class_name GroupBreadcrumbTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true
	# Flat shape: 0 Gameplay(g,0) / 1 row(1) / 2 Combat(g,1) / 3 row(2) / 4 row(2)
	#             5 Audio(g,1) / 6 row(2) / 7 top row(0) / 8 UI(g,0) / 9 row(1)
	var rows: Array = [
		{"group": true, "indent": 0},
		{"group": false, "indent": 1},
		{"group": true, "indent": 1},
		{"group": false, "indent": 2},
		{"group": false, "indent": 2},
		{"group": true, "indent": 1},
		{"group": false, "indent": 2},
		{"group": false, "indent": 0},
		{"group": true, "indent": 0},
		{"group": false, "indent": 1},
	]
	var map: PackedInt32Array = ViewportGroupBreadcrumb.enclosing_map(rows)
	all_passed = _check("row inside one group maps to it", map[1], 0) and all_passed
	all_passed = _check("a nested group maps to its PARENT, not itself", map[2], 0) and all_passed
	all_passed = _check("row inside nested groups maps to the innermost", map[3], 2) and all_passed
	all_passed = _check("a sibling group replaces its sibling in the stack", map[6], 5) and all_passed
	all_passed = _check("a row after the groups end is top level", map[7], -1) and all_passed
	all_passed = _check("a later top-level group starts fresh", map[9], 8) and all_passed

	all_passed = _check("chain reads outermost first",
		ViewportGroupBreadcrumb.chain_for(map, 3), PackedInt32Array([0, 2])) and all_passed
	all_passed = _check("chain for a visible group bar shows only what scrolled away",
		ViewportGroupBreadcrumb.chain_for(map, 2), PackedInt32Array([0])) and all_passed
	all_passed = _check("top level has no chain",
		ViewportGroupBreadcrumb.chain_for(map, 7), PackedInt32Array()) and all_passed
	all_passed = _check("out-of-range index fails closed",
		ViewportGroupBreadcrumb.chain_for(map, 99), PackedInt32Array()) and all_passed
	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		return true
	print("[FAIL] group_breadcrumb_test: %s - expected %s, got %s" % [label, str(expected), str(actual)])
	return false
