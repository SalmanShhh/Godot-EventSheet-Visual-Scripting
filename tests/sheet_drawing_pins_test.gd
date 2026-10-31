@tool
extends RefCounted
# Godot EventSheets - the drawing fixes of the sub-events, states and opening work, pinned as values.
#
#   1. A sheet that never chose a look keeps Editor Native when a divider or name-column drag saves
#      a number onto it (the drag once turned it into a Classic-like style).
#   2. In a look that draws strips, an event's fold arrow sits at the foot of its block.
#   3. A word card is found by the rectangle its word drew in.
#   4. The word cards' offsets are measured once per text and kept, and the running game's live
#      states are worked out once per frame that arrives, not once per drawn name.
#   5. Code in the Events / Code / Both switch during an open asks the open to stop exactly once.

const SUPPORT := preload("res://tests/support.gd")
const TEST_NAME := "sheet_drawing_pins_test"
const NATIVE_THEME := "res://addons/eventsheet/themes/editor_native_theme.tres"


## Stands in for the dock in the one question set_sheet_view asks of it during an open.
class FakeDock extends Control:
	var _open_progress: EventSheetOpenProgress = null
	var _scroll: Control = null


	func is_code_panel_visible() -> bool:
		return true


static func run() -> bool:
	var ok: bool = true
	ok = _test_promoted_style() and ok
	ok = _test_fold_at_foot() and ok
	ok = _test_word_cards() and ok
	ok = _test_code_cancels_open() and ok
	return ok


static func _test_promoted_style() -> bool:
	var starter: EventSheetEventStyle = (load(NATIVE_THEME) as EventSheetEditorStyle).get_event_style()
	var promoted: EventSheetEventStyle = EventSheetEditorThemeDeriver.promoted_default_style(
		EventSheetEditorThemeDeriver.NATIVE_DARK_REFERENCE_BASE).get_event_style()
	return SUPPORT.pins(TEST_NAME, [
		["a dragged number on a no-look sheet keeps the Native strips, badge and name columns",
			[promoted.sub_event_strips, promoted.condition_badge_column_width, promoted.condition_object_column_width,
				promoted.action_object_column_width, promoted.condition_lane_ratio],
			[true, starter.condition_badge_column_width, starter.condition_object_column_width,
				starter.action_object_column_width, starter.condition_lane_ratio]],
		["and it is a copy, so the drag never edits the starter",
			EventSheetEditorThemeDeriver.promoted_default_style(EventSheetEditorThemeDeriver.NATIVE_DARK_REFERENCE_BASE)
				.get_event_style() != starter, true],
	])


static func _test_fold_at_foot() -> bool:
	var sheet := EventSheetResource.new()
	var parent := EventRow.new()
	for index: int in 3:
		var condition := ACECondition.new()
		condition.provider_id = "Core"
		condition.ace_id = "Compare"
		parent.conditions.append(condition)
	parent.sub_events.append(EventRow.new())
	sheet.events.append(parent)
	var results: Array = []
	for theme_path: String in [NATIVE_THEME, ""]:
		var sheet_copy: EventSheetResource = sheet.duplicate(true)
		sheet_copy.editor_style = (load(theme_path) as EventSheetEditorStyle).duplicate(true) if not theme_path.is_empty() else null
		var view := EventSheetViewport.new()
		view.set_ace_registry(EventSheetACERegistry.new())
		view.size = Vector2(1200.0, 900.0)
		view.set_sheet(sheet_copy)
		var layout: Dictionary = view._layout_builder.get_or_build_row_layout(0, view._get_logical_canvas_width(),
			view._get_font(), view._get_font_size())
		var fold: Rect2 = layout.get("fold_rect", Rect2())
		var top: float = view._row_metrics_helper.row_top(0)
		var height: float = view._row_metrics_helper.row_height(0)
		results.append([fold.size != Vector2.ZERO, is_equal_approx(fold.end.y, top + height - 4.0), height > 40.0])
		view.free()
	return SUPPORT.pins(TEST_NAME, [
		["with strips, a tall event's fold arrow sits 4 px above the foot of its block", results[0], [true, true, true]],
		["without strips it stays at the head", results[1][1], false],
	])


static func _test_word_cards() -> bool:
	var card_a: Dictionary = {"title": "IDLE"}
	var card_b: Dictionary = {"title": "RUN"}
	var metadata: Dictionary = {"word_card_rects": [
		{"rect": Rect2(10.0, 0.0, 30.0, 20.0), "card": card_a},
		{"rect": Rect2(50.0, 0.0, 25.0, 20.0), "card": card_b},
	]}
	var font: Font = ThemeDB.fallback_font
	var span_meta: Dictionary = {"word_cards": [{"start": 3, "length": 4, "card": card_a}]}
	var first: Array = EventRowRenderer.word_card_offsets(span_meta, "is IDLE", font, 12)
	var kept: Variant = span_meta.get("word_card_measure")
	var second: Array = EventRowRenderer.word_card_offsets(span_meta, "is IDLE", font, 12)
	var still_kept: bool = is_same(span_meta.get("word_card_measure"), kept)
	var remeasured: Array = EventRowRenderer.word_card_offsets(span_meta, "is RUN!", font, 12)
	EventSheetStateWatch.clear()
	EventSheetStateWatch.note_frame({"state": "CHASE", "state_seconds": 1.0})
	var live_once: PackedStringArray = EventSheetStateWatch.live_members()
	EventSheetStateWatch.note_frame({"state": "PATROL", "state_seconds": 0.5})
	var live_after: PackedStringArray = EventSheetStateWatch.live_members()
	EventSheetStateWatch.clear()
	var live_cleared: PackedStringArray = EventSheetStateWatch.live_members()
	return SUPPORT.pins(TEST_NAME, [
		["the point on the second word picks the second card",
			EventSheetViewport.word_card_at(metadata, Vector2(60.0, 10.0)).get("card"), card_b],
		["a point between the words picks none", EventSheetViewport.word_card_at(metadata, Vector2(45.0, 10.0)), {}],
		["the word's offset is the width of the text before it",
			is_equal_approx(float((first[0] as Dictionary)["lead"]),
				font.get_string_size("is ", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12).x), true],
		["asked again for the same text, the kept measurement is handed back",
			[second == first, still_kept], [true, true]],
		["new text is measured again", remeasured != first, true],
		["the live states follow each frame that arrives, and the end of the run",
			[live_once, live_after, live_cleared],
			[PackedStringArray(["CHASE"]), PackedStringArray(["PATROL"]), PackedStringArray()]],
	])


static func _test_code_cancels_open() -> bool:
	var dock := FakeDock.new()
	var progress := EventSheetOpenProgress.new()
	var hairline: Control = progress.build_hairline()
	var link: Control = progress.build_link()
	progress.init(dock)
	dock._open_progress = progress
	var cancels: Array = [0]
	progress.cancel_requested_callback = func() -> void: cancels[0] += 1
	var glue := EventSheetCodePanelGlue.new()
	glue.init(dock)
	progress.show_for("res://player.gd")
	glue.set_sheet_view(EventSheetPopupUI.ViewSwitch.CODE)
	glue.set_sheet_view(EventSheetPopupUI.ViewSwitch.CODE)
	var during_open: int = cancels[0]
	progress.hide_strip()
	glue.set_sheet_view(EventSheetPopupUI.ViewSwitch.CODE)
	var ok: bool = SUPPORT.pins(TEST_NAME, [
		["Code during an open asks it to stop exactly once", during_open, 1],
		["Code with no open running asks nothing", cancels[0], 1],
	])
	hairline.free()
	link.free()
	dock.free()
	return ok
