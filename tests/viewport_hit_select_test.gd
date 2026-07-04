# EventForge - row hit-testing resolves a click to an event row, including the small inter-block gap.
#
# Event blocks are separated by EVENT_BLOCK_GAP, dead space not covered by any row's [top, top+height)
# band. Before the fix, a click there returned -1 → the selection was CLEARED, so the user "couldn't
# select an event block by clicking outside the condition cell" - and with nothing selected, Delete
# fell through to the editor's scene tree. Now a gap click resolves to the preceding event. Pins
# EventSheetViewport._row_index_at_y (static + pure, so no Control instance is needed).
@tool
class_name ViewportHitSelectTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true
	# Two event blocks: row 0 spans y[0,40), a 6px inter-block gap, row 1 spans y[46,86).
	var metrics: Array = [{"top": 0.0, "height": 40.0}, {"top": 46.0, "height": 40.0}]
	ok = _check("click inside row 0 selects row 0", EventSheetViewport._row_index_at_y(metrics, 10.0), 0) and ok
	ok = _check("click inside row 1 selects row 1", EventSheetViewport._row_index_at_y(metrics, 50.0), 1) and ok
	ok = _check("click in the inter-block gap selects the preceding event (not nothing)", EventSheetViewport._row_index_at_y(metrics, 43.0), 0) and ok
	ok = _check("click above the first row selects nothing", EventSheetViewport._row_index_at_y(metrics, -5.0), -1) and ok
	ok = _check("click below the last row selects nothing", EventSheetViewport._row_index_at_y(metrics, 200.0), -1) and ok
	ok = _check("empty metrics select nothing", EventSheetViewport._row_index_at_y([], 10.0), -1) and ok
	return ok


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] viewport_hit_select_test: %s" % label)
		return true
	print("[FAIL] viewport_hit_select_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
