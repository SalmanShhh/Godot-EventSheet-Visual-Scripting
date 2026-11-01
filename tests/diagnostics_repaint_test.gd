# Godot EventSheets - saving a clean sheet does not rebuild every row to paint nothing.
#
# `_run_diagnostics` runs after every save and hands the viewport the sheet's problem list.
# `set_row_diagnostics` used to rebuild every row on each call, even when the list was empty and had
# been empty before: 13 s of a 14.4 s save on the 1,492-row pathfinding pack. It now rebuilds only
# when the list CHANGED.
#
# Pinned three ways:
#   * STRUCTURAL: `row_builds()` does not move across `_run_diagnostics` on a clean sheet, nor across
#     an equal non-empty list, nor across an equal empty one.
#   * BEHAVIOUR: a CHANGED list still rebuilds (empty -> one flag -> a different flag -> empty), so a
#     marker still appears, moves and clears.
#   * WALL: the repeat `_run_diagnostics` of a 346-row pack, at three times the measured figure. The
#     whole call is the analysis plus the repaint, and the repaint is what this pins.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "diagnostics_repaint_test"
const SAMPLE_PACK: String = "res://eventsheet_addons/fps_controller/fps_controller_behavior.gd"
## Measured 178 ms on the 346-row sample (the rebuild alone is over 1,000 ms there), set at about 3x.
const REPEAT_DIAGNOSTICS_BUDGET_MS: float = 600.0


static func run() -> bool:
	var passed: bool = true
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(SAMPLE_PACK, false)
	passed = SUPPORT.check(P, "the sample pack imports", sheet == null, false) and passed
	if sheet == null:
		return false
	EventSheetACELifter.attempt_lift(sheet, FileAccess.get_file_as_string(SAMPLE_PACK))
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(sheet)
	var viewport: EventSheetViewport = editor.get_viewport_control()

	# STRUCTURAL: a clean sheet, checked twice, builds no rows.
	var before: int = viewport.row_builds()
	var issues: int = editor._run_diagnostics()
	passed = SUPPORT.check(P, "the sample pack has no diagnostics (the zero-issue case)", issues, 0) and passed
	passed = SUPPORT.check(P, "a zero-issue _run_diagnostics builds no rows",
		viewport.row_builds(), before) and passed
	before = viewport.row_builds()
	var start_usec: int = Time.get_ticks_usec()
	editor._run_diagnostics()
	var elapsed_ms: float = float(Time.get_ticks_usec() - start_usec) / 1000.0
	passed = SUPPORT.check(P, "a repeat _run_diagnostics builds no rows", viewport.row_builds(), before) and passed
	passed = SUPPORT.check(P, "a repeat _run_diagnostics costs under %.0f ms (took %.1f ms)" % [
		REPEAT_DIAGNOSTICS_BUDGET_MS, elapsed_ms], elapsed_ms <= REPEAT_DIAGNOSTICS_BUDGET_MS, true) and passed

	# BEHAVIOUR: a changed list still rebuilds; an equal one does not.
	var flag_a: Array = [{"uid": "111", "message": "first problem", "suggestion": "fix it"}]
	var flag_b: Array = [{"uid": "222", "message": "first problem", "suggestion": "fix it"}]
	before = viewport.row_builds()
	passed = SUPPORT.check(P, "a new flag is counted", viewport.set_row_diagnostics(flag_a), 1) and passed
	passed = SUPPORT.check(P, "a new flag rebuilds the rows once", viewport.row_builds(), before + 1) and passed
	passed = SUPPORT.check(P, "the same flag again is counted", viewport.set_row_diagnostics(flag_a.duplicate(true)), 1) and passed
	passed = SUPPORT.check(P, "the same flag again builds nothing", viewport.row_builds(), before + 1) and passed
	passed = SUPPORT.check(P, "a flag moved to another row is counted", viewport.set_row_diagnostics(flag_b), 1) and passed
	passed = SUPPORT.check(P, "a moved flag rebuilds the rows", viewport.row_builds(), before + 2) and passed
	passed = SUPPORT.check(P, "a changed message under the same row counts as a change",
		viewport.set_row_diagnostics([{"uid": "222", "message": "other problem", "suggestion": ""}]), 1) and passed
	passed = SUPPORT.check(P, "a changed message rebuilds the rows", viewport.row_builds(), before + 3) and passed
	passed = SUPPORT.check(P, "clearing counts zero", viewport.set_row_diagnostics([]), 0) and passed
	passed = SUPPORT.check(P, "clearing a flag rebuilds the rows", viewport.row_builds(), before + 4) and passed
	passed = SUPPORT.check(P, "clearing again counts zero", viewport.set_row_diagnostics([]), 0) and passed
	passed = SUPPORT.check(P, "clearing again builds nothing", viewport.row_builds(), before + 4) and passed
	editor.free()
	return passed