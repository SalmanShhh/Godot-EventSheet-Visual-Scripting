# Godot EventSheets - a draw reuses the whole-sheet answers instead of walking every row.
#
# Every frame the canvas needs the margin brackets (one dictionary per row of the WHOLE sheet) and
# the variable-folder runs (a second and third walk of every row). On the 1,516-row pathfinding pack
# those three walks were 15 ms of a 40 ms draw, on every scroll frame. They are held now, keyed to
# the rows' generation, the layout, the width, the font, the zoom and the look's colours.
#
# Pinned with call counters (`group_memo_computes()`): thirty unchanged asks compute once, and a
# rebuild, a fold, a resize, a zoom or a look change computes again. The wall figure (draw median
# 39.9 -> 21.9 ms) is a real-editor measurement and lives in the changelog, since a headless
# process cannot draw.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "group_memo_test"
const SAMPLE_PACK: String = "res://eventsheet_addons/fps_controller/fps_controller_behavior.gd"


static func run() -> bool:
	var passed: bool = true
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(SAMPLE_PACK, false)
	if sheet == null:
		return SUPPORT.check(P, "the sample pack imports", false, true)
	EventSheetACELifter.attempt_lift(sheet, FileAccess.get_file_as_string(SAMPLE_PACK))
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(sheet)
	var viewport: EventSheetViewport = editor.get_viewport_control()
	var width: float = 900.0
	var first_strokes: Array = viewport.group_bracket_strokes(width)
	var first_runs: Array = viewport.variable_group_runs_cached()
	var base: Vector2i = viewport.group_memo_computes()
	for _frame in 30:
		viewport.group_bracket_strokes(width)
		viewport.variable_group_runs_cached()
	passed = SUPPORT.check(P, "thirty unchanged asks compute nothing more", viewport.group_memo_computes(), base) and passed
	passed = SUPPORT.check(P, "the held answers are the same objects", is_same(first_strokes, viewport.group_bracket_strokes(width)), true) and passed
	passed = SUPPORT.check(P, "the held runs are the same object", is_same(first_runs, viewport.variable_group_runs_cached()), true) and passed

	# A different width is a different answer for the brackets only.
	viewport.group_bracket_strokes(width + 100.0)
	passed = SUPPORT.check(P, "a new width recomputes the brackets",
		viewport.group_memo_computes(), base + Vector2i(1, 0)) and passed
	viewport.group_bracket_strokes(width + 100.0)
	passed = SUPPORT.check(P, "and holds again", viewport.group_memo_computes(), base + Vector2i(1, 0)) and passed

	# A rebuild (an edit, a fold, a diagnostics change all go through it) recomputes both.
	var before_rebuild: Vector2i = viewport.group_memo_computes()
	viewport.set_sheet(sheet)
	viewport.group_bracket_strokes(width + 100.0)
	viewport.variable_group_runs_cached()
	passed = SUPPORT.check(P, "a row rebuild recomputes both", viewport.group_memo_computes(), before_rebuild + Vector2i(1, 1)) and passed
	viewport.group_bracket_strokes(width + 100.0)
	viewport.variable_group_runs_cached()
	passed = SUPPORT.check(P, "and holds again after it", viewport.group_memo_computes(), before_rebuild + Vector2i(1, 1)) and passed

	# A fold replaces the rows, so the brackets follow it.
	var folded_any: bool = false
	for index: int in viewport.get_total_row_count():
		var row: EventRowData = viewport._row_at(index)
		if row != null and not row.children.is_empty():
			var before_fold: Vector2i = viewport.group_memo_computes()
			viewport._folding.toggle_row_fold(index)
			viewport.group_bracket_strokes(width + 100.0)
			passed = SUPPORT.check(P, "a fold recomputes the brackets", viewport.group_memo_computes().x, before_fold.x + 1) and passed
			folded_any = true
			break
	passed = SUPPORT.check(P, "the sample has a row that folds", folded_any, true) and passed

	# Zoom and the look's colours are part of the key.
	var before_zoom: Vector2i = viewport.group_memo_computes()
	viewport.set_zoom_factor(1.25)
	viewport.group_bracket_strokes(width + 100.0)
	passed = SUPPORT.check(P, "a zoom recomputes the brackets", viewport.group_memo_computes().x, before_zoom.x + 1) and passed
	var look: EventSheetEventStyle = viewport._get_event_style()
	var title_color: Color = look.group_title_color
	look.group_title_color = Color(0.1, 0.2, 0.3, 1.0) if title_color != Color(0.1, 0.2, 0.3, 1.0) else Color(0.3, 0.2, 0.1, 1.0)
	viewport.group_bracket_strokes(width + 100.0)
	passed = SUPPORT.check(P, "a look change recomputes the brackets", viewport.group_memo_computes().x, before_zoom.x + 2) and passed
	look.group_title_color = title_color
	editor.free()
	return passed
