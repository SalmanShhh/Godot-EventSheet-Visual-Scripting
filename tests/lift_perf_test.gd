# Godot EventSheets - opening a .gd as a sheet stays fast.
#
# The lift matches every line of a file against the reverse-template index, and BUILDING that index
# compiles one RegEx per reversible descriptor template (894 of them on a stock install). The
# per-function lift path used to rebuild it once per function, so a file with N functions paid N
# full index builds: measured 2026-08-19 on this tree, that one line was ~80% of the time an open
# took (fps_controller_behavior.gd 6769 ms, save_system_addon.gd 11714 ms). Memoized, the same two
# files lift in 1143 ms and 2014 ms.
#
# This pins the win two ways, because a millisecond budget alone would either flap on a loaded
# machine or be set so loose it catches nothing:
#   1. A STRUCTURAL pin: the index is handed out by reference, so two calls return the SAME Array.
#      A future edit that goes back to composing a fresh index per caller fails here immediately,
#      on any machine, at any load - this is the invariant that actually made it fast.
#   2. A generous wall budget on a real pack open, as the backstop for a regression that keeps the
#      sharing but makes the matching itself slow. Set ~3.5x over the measured time so ordinary
#      machine load cannot trip it, while the pre-fix 6769 ms is caught with room to spare.
@tool
class_name LiftPerfTest
extends RefCounted

## A real shipped pack with many functions - the shape that exposed the per-function rebuild.
const SAMPLE_PACK: String = "res://eventsheet_addons/fps_controller/fps_controller_behavior.gd"
## Measured 1143 ms after the fix; 6769 ms before it. Generous enough not to flap under load.
const LIFT_BUDGET_MS: int = 4000


static func run() -> bool:
	var all_passed: bool = true

	# 1. The index is shared, not recomposed. Identity, not equality: two Arrays with equal
	# contents would still mean every caller paid a full rebuild.
	var first: Array = EventSheetACELifter._build_reverse_entries()
	var second: Array = EventSheetACELifter._build_reverse_entries()
	all_passed = _check("reverse index is composed once and shared by reference",
		is_same(first, second), true) and all_passed
	all_passed = _check("reverse index is not empty (a shared empty one would pass vacuously)",
		first.is_empty(), false) and all_passed

	# 2. The wall backstop, on a real pack opened the way the dock opens it.
	if not FileAccess.file_exists(SAMPLE_PACK):
		return _check("sample pack exists: %s" % SAMPLE_PACK.get_file(), false, true) and all_passed
	var source: String = FileAccess.get_file_as_string(SAMPLE_PACK)
	var importer: GDScriptImporter = GDScriptImporter.new()
	var sheet: EventSheetResource = importer.import_external(SAMPLE_PACK, false)
	all_passed = _check("sample pack imports", sheet == null, false) and all_passed
	if sheet == null:
		return false
	var start_usec: int = Time.get_ticks_usec()
	EventSheetACELifter.attempt_lift(sheet, source)
	var elapsed_ms: float = float(Time.get_ticks_usec() - start_usec) / 1000.0
	all_passed = _check("lifting %s under %d ms (took %.1f ms)" % [SAMPLE_PACK.get_file(), LIFT_BUDGET_MS, elapsed_ms],
		elapsed_ms <= float(LIFT_BUDGET_MS), true) and all_passed

	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] lift_perf_test: %s" % label)
		return true
	print("[FAIL] lift_perf_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
