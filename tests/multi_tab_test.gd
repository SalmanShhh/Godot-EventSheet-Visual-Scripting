# EventForge — Multiple EventSheet tabs
#
# Drives the dock's tab API: opening sheets adds/activates tabs, re-opening the same sheet
# reuses its tab, per-tab dirty state is independent, and closing activates a neighbour.
# Headless-safe.
@tool
extends RefCounted
class_name MultiTabTest

static func run() -> bool:
	var all_passed: bool = true
	var editor: EventSheetEditor = EventSheetEditor.new()
	var sheet_a: EventSheetResource = EventSheetResource.new()
	sheet_a.host_class = "Alpha"
	var sheet_b: EventSheetResource = EventSheetResource.new()
	sheet_b.host_class = "Beta"

	editor.setup(sheet_a)
	all_passed = _check("one tab after first open", editor.get_open_tab_count(), 1) and all_passed
	all_passed = _check("active is tab 0", editor.get_active_tab_index(), 0) and all_passed
	all_passed = _check("current sheet is A", editor.get_current_sheet() == sheet_a, true) and all_passed

	editor.setup(sheet_b)
	all_passed = _check("two tabs after second open", editor.get_open_tab_count(), 2) and all_passed
	all_passed = _check("active is tab 1", editor.get_active_tab_index(), 1) and all_passed
	all_passed = _check("current sheet is B", editor.get_current_sheet() == sheet_b, true) and all_passed

	# Re-opening A reuses its tab (no duplicate).
	editor.setup(sheet_a)
	all_passed = _check("re-open A keeps two tabs", editor.get_open_tab_count(), 2) and all_passed
	all_passed = _check("active back to tab 0", editor.get_active_tab_index(), 0) and all_passed
	all_passed = _check("current sheet is A again", editor.get_current_sheet() == sheet_a, true) and all_passed

	# Per-tab dirty state is independent.
	editor.activate_tab(1)
	editor._mark_dirty("edit B")
	all_passed = _check("B tab is dirty", editor.is_tab_dirty(1), true) and all_passed
	all_passed = _check("A tab is not dirty", editor.is_tab_dirty(0), false) and all_passed
	editor.activate_tab(0)
	all_passed = _check("A stays clean after switching", editor.is_tab_dirty(0), false) and all_passed
	editor.activate_tab(1)
	all_passed = _check("B stays dirty after switching", editor.is_tab_dirty(1), true) and all_passed
	all_passed = _check("switching restores B's sheet", editor.get_current_sheet() == sheet_b, true) and all_passed

	# Closing the active tab activates a neighbour.
	editor._close_tab(1)
	all_passed = _check("one tab after close", editor.get_open_tab_count(), 1) and all_passed
	all_passed = _check("A is active after close", editor.get_current_sheet() == sheet_a, true) and all_passed

	editor.free()
	return all_passed

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] multi_tab_test: %s" % label)
		return true
	print("[FAIL] multi_tab_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
