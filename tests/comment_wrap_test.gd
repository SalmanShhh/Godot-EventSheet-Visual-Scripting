# Godot EventSheets - comment rows wrap to the row width and grow vertically.
#
# A long comment used to render as one line clipped off the right edge. Now each logical
# comment line word-wraps to the available width and the row reserves enough height for the
# wrapped text, so the whole note is readable at any zoom (the wrap is computed in logical
# pixels, which zoom scales uniformly). This pins: the pure wrap-count math, and that a long
# comment row ends up taller than a short one (it actually wrapped through the layout).
@tool
class_name CommentWrapTest
extends RefCounted

const LONG_COMMENT := "Platformer movement: attach under a CharacterBody2D. Run with ui_left/ui_right, call Jump (with coyote time + buffering), and turn on wall slide / wall jump / double jump in the Inspector. Call Jump Released when the player lets go of the jump button for variable jump height."


static func run() -> bool:
	var all_passed: bool = true
	var font: Font = ThemeDB.fallback_font
	var font_size: int = 16

	# Pure wrap-count math (the single source of truth shared by metrics + drawing).
	all_passed = _check("blank text is one line",
		EventSheetViewport.wrapped_line_count("", 200.0, font, font_size), 1) and all_passed
	all_passed = _check("short text fits on one line",
		EventSheetViewport.wrapped_line_count("hi", 200.0, font, font_size), 1) and all_passed
	var narrow_lines: int = EventSheetViewport.wrapped_line_count(LONG_COMMENT, 120.0, font, font_size)
	all_passed = _check("a long comment wraps to several lines at a narrow width", narrow_lines > 1, true) and all_passed
	var wide_lines: int = EventSheetViewport.wrapped_line_count(LONG_COMMENT, 600.0, font, font_size)
	all_passed = _check("a wider column wraps to fewer-or-equal lines", wide_lines <= narrow_lines, true) and all_passed
	all_passed = _check("a wider column still needs at least one line", wide_lines >= 1, true) and all_passed
	all_passed = _check("a zero/degenerate width never collapses below one line",
		EventSheetViewport.wrapped_line_count(LONG_COMMENT, 0.0, font, font_size), 1) and all_passed

	# Integration: a long comment row is taller than a short one once it flows through the
	# real layout/metrics (so it grows vertically instead of clipping).
	var sheet: EventSheetResource = EventSheetResource.new()
	var short_comment: CommentRow = CommentRow.new()
	short_comment.text = "short note"
	var long_comment: CommentRow = CommentRow.new()
	long_comment.text = LONG_COMMENT
	sheet.events.append(short_comment)
	sheet.events.append(long_comment)
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(sheet)
	var viewport: EventSheetViewport = editor.get_viewport_control()
	viewport._rebuild_row_metrics()
	var short_height: float = viewport._get_row_height(0)
	var long_height: float = viewport._get_row_height(1)
	all_passed = _check("a long comment row is taller than a short one (it wrapped vertically)",
		long_height > short_height, true) and all_passed

	# The long comment's plain span is flagged for word-wrapped drawing (not single-line clip).
	var long_row: EventRowData = viewport.get_flat_rows()[1].get("row")
	var layout: Dictionary = viewport.get_row_layout_for_test(1)
	var wrapped_flagged: bool = false
	for span: SemanticSpan in long_row.spans:
		if span != null and span.metadata is Dictionary and bool((span.metadata as Dictionary).get("comment_wrap", false)):
			wrapped_flagged = true
			break
	all_passed = _check("the comment span is flagged for wrapped drawing", wrapped_flagged, true) and all_passed
	all_passed = _check("layout reports the wrapped row height", float(layout.get("row_height", 0.0)) > short_height, true) and all_passed
	editor.free()

	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] comment_wrap_test: %s" % label)
		return true
	print("[FAIL] comment_wrap_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
