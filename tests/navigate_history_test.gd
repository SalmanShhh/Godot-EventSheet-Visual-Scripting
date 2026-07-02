# EventForge — the jump history behind Alt+Left / Alt+Right. Every jump-away records the current
# file-backed sheet; Back/Forward move it between two stacks like a browser, a new jump clears the
# forward branch, unsaved sheets are skipped, and vanished files are dropped rather than wedging the
# walk. Driven headlessly on a real dock across two real pack sheets.
@tool
extends RefCounted
class_name NavigateHistoryTest

const CAR := "res://eventsheet_addons/car/car_behavior.gd"
const TIMER := "res://eventsheet_addons/timer/timer_behavior.gd"

static func run() -> bool:
	var ok: bool = true

	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(EventSheetResource.new())

	# The starting sheet is unsaved (no path) — jumping away from it records nothing.
	dock._navigate.record_current()
	ok = _check("an unsaved sheet is never recorded", dock._navigate._back_stack.size(), 0) and ok

	# Open car, jump to timer (recording), walk back and forward.
	dock._load_sheet_from_path(CAR)
	dock._navigate.record_current()
	dock._load_sheet_from_path(TIMER)
	ok = _check("the jump-away recorded car", dock._navigate._back_stack.size(), 1) and ok
	var tabs_before_back: int = dock._open_tabs.size()
	dock._navigate.go_back()
	ok = _check("Alt+Left returns to car", dock.get_current_sheet().external_source_path, CAR) and ok
	ok = _check("Back RE-FOCUSES car's tab (no duplicate)", dock._open_tabs.size(), tabs_before_back) and ok
	ok = _check("the forward stack now holds timer", dock._navigate._forward_stack.size(), 1) and ok
	dock._navigate.go_forward()
	ok = _check("Alt+Right returns to timer", dock.get_current_sheet().external_source_path, TIMER) and ok

	# A NEW jump clears the forward branch (browser semantics).
	dock._navigate.go_back()  # back on car; timer sits ahead
	dock._navigate.record_current()
	dock._load_sheet_from_path(TIMER)
	ok = _check("a new jump clears the forward branch", dock._navigate._forward_stack.size(), 0) and ok

	# Consecutive duplicates collapse; vanished files are skipped, and an empty walk reports politely.
	dock._navigate.record_current()
	dock._navigate.record_current()
	ok = _check("consecutive duplicates collapse", dock._navigate._back_stack.count(TIMER), 1) and ok
	dock._navigate._back_stack = PackedStringArray(["res://no_such_sheet.gd"])
	dock._navigate.go_back()
	ok = _check("a vanished file is dropped, not loaded", dock.get_current_sheet().external_source_path, TIMER) and ok
	ok = _check("the vanished entry is gone", dock._navigate._back_stack.size(), 0) and ok
	dock._navigate.go_back()  # empty stack → a status message, never a crash
	ok = _check("an empty walk is a safe no-op", dock.get_current_sheet().external_source_path, TIMER) and ok

	dock.free()
	return ok

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] navigate_history_test: %s" % label)
		return true
	print("[FAIL] navigate_history_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
