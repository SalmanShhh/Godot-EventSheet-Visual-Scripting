# Godot EventSheets - what a run draws on the sheet reads on every theme it is drawn on.
#
# The count chip and the number beside it (resting, busy, never fired, slow), the live value badge and a
# comment's words on a band of its own colour take their colours from the theme and are moved until they
# read at 4.5 to 1 on the ground under them, in a dark editor and in a light one.
@tool
class_name RunMarksTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const MARKS := preload("res://addons/eventsheet/theme/run_marks.gd")
const P := "run_marks_test"
const BASES := [Color("#292929"), Color("#e6e6e6")]


static func run() -> bool:
	var ok: bool = true
	for base: Color in BASES:
		ok = _chips(base) and ok
	ok = _comments() and ok
	EventSheetRunProfile.forget_stored_for_test()
	return ok


static func _chips(base: Color) -> bool:
	var style: EventSheetEditorStyle = EventSheetEditorThemeDeriver.native_style(base)
	var event_style: EventSheetEventStyle = style.get_event_style()
	var reading: EventSheetReadingStyle = style.get_reading_style()
	var ground: Color = event_style.gutter_background_color
	var warning: Color = style.get_chrome_style().object_bar_warning_color
	var weak: Array[String] = []
	var kinds: Dictionary = {"resting": [5, 5, 100], "busy": [5, 5, 3000], "slow": [5, 5, 4000000], "never fired": [0, 0, 0]}
	for kind: String in kinds:
		var run: Array = kinds[kind]
		EventSheetRunProfile.adopt_run_for_test("mark_uid", run[0], run[1], run[2], "t")
		var marks: Dictionary = MARKS.marks_for("mark_uid", event_style.gutter_text_color, reading, warning, ground)
		var floor_color: Color = ground.lerp(Color(marks["fill"], 1.0), (marks["fill"] as Color).a)
		for under: Color in [ground, floor_color]:
			var ratio: float = EventSheetEditorThemeDeriver.contrast_ratio(marks["text"], under)
			if ratio < 4.5:
				weak.append("%s %.2f" % [kind, ratio])
	var live: Color = MARKS.live_ink(reading, event_style.row_background_color)
	var live_ratio: float = EventSheetEditorThemeDeriver.contrast_ratio(live, event_style.row_background_color)
	var ok: bool = SUPPORT.check(P, "chips and numbers read at base %s" % base.to_html(false), weak, [])
	ok = SUPPORT.check(P, "the live value reads on its row at base %s" % base.to_html(false), live_ratio >= 4.5, true) and ok
	return ok


static func _comments() -> bool:
	var band: Color = Color(0.32, 0.27, 0.14, 1.0)
	var rows: Array = []
	for base: Color in BASES:
		var event_style: EventSheetEventStyle = EventSheetEditorThemeDeriver.native_style(base).get_event_style()
		var ink: Color = MARKS.comment_ink(event_style.comment_text_color, band)
		rows.append(["a coloured comment's words read on its band at base %s" % base.to_html(false), EventSheetEditorThemeDeriver.contrast_ratio(ink, band) >= 4.5, true])
		rows.append(["a comment with no colour of its own keeps the theme's ink at base %s" % base.to_html(false), MARKS.comment_ink(event_style.comment_text_color, Color(0, 0, 0, 0)), event_style.comment_text_color])
	return SUPPORT.pins(P, rows)
