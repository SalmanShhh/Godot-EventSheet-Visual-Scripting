@tool
extends RefCounted
# Godot EventSheets - a .gd opening says so without a banner.
#
# The open used to put a 72 px strip above the sheet (drawn in its own navy in every look) that
# pushed the rows down and jumped them back up. Now the signs are a spinner on the tab, a 2 px
# hairline along the foot of the tab strip and the status line, none of which takes room. Pinned as
# values: the hairline takes no layout room and fills by the job's ratio, the ratio runs through the
# passes in order and never reaches the end before the open does, the status line names each pass
# in the board's words (seconds only once past half a second), and "Show as code" reports the
# request once.

const SUPPORT := preload("res://tests/support.gd")
const NAME := "opening_without_banner_test"


static func run() -> bool:
	var job: EventSheetOpenJob = EventSheetOpenJob.new()
	job._started_msec = Time.get_ticks_msec()
	var ratios: Array = []
	var words: Array = []
	for phase: Array in [["reading", 0, 0], ["lifting", 5, 10], ["lifting", 10, 10], ["verifying", 10, 10], ["checking", 10, 10]]:
		EventSheetACELifter.progress_phase = phase[0]
		EventSheetACELifter.progress_functions_done = phase[1]
		EventSheetACELifter.progress_functions_total = phase[2]
		ratios.append(roundi(job.progress_ratio() * 100.0))
		words.append(job.status_text().split(" · ")[0])
	EventSheetACELifter.reset_progress()

	var progress: EventSheetOpenProgress = EventSheetOpenProgress.new()
	var hairline: Control = progress.build_hairline()
	var link: Control = progress.build_link()
	var asked: Array = [0]
	progress.cancel_requested_callback = func() -> void: asked[0] += 1
	var before: Array = [progress.is_active(), hairline.visible, link.visible]
	progress.request_code()
	var idle_asks: int = asked[0]
	progress.show_for("res://player.gd")
	progress.update("reading functions 6 of 14", 0.45)
	var during: Array = [progress.is_active(), hairline.visible, link.visible, progress.is_opening("res://player.gd"),
		progress.is_opening("res://other.gd")]
	var anchored: Array = [hairline.anchor_top, hairline.anchor_bottom, hairline.offset_top, hairline.mouse_filter]
	progress.update("checking the script compiles", 0.2)
	var never_backwards: float = snappedf((hairline as EventSheetOpenProgress.Hairline).ratio, 0.01)
	progress.request_code()
	progress.request_code()
	var asks: int = asked[0]
	var link_text: String = (link as LinkButton).text
	progress.hide_strip()
	var after: Array = [progress.is_active(), hairline.visible, link.visible]
	hairline.free()
	link.free()
	# While an open runs, Code takes the button's own hover box: no outline of any colour is added.
	var door: Button = Button.new()
	var hover: StyleBox = door.get_theme_stylebox("hover")
	var quiet: StyleBox = EventSheetOpenProgress.quiet_style(door)
	var quiet_facts: Array = [quiet.get_class(), quiet.get_minimum_size(), quiet is StyleBoxFlat and (quiet as StyleBoxFlat).border_width_top == (hover as StyleBoxFlat).border_width_top]
	var hover_facts: Array = [hover.get_class(), hover.get_minimum_size(), hover is StyleBoxFlat]
	door.free()
	return SUPPORT.pins(NAME, [
		["the open gives Code its own hover box and draws no ring of its own", quiet_facts, hover_facts],
		["the ratio (in percent) runs through the passes in order", ratios, [0, 48, 88, 88, 94]],
		["each pass is named in the board's words", words, [
			"reading the code", "reading functions 5 of 10", "reading functions 10 of 10",
			"checking the code still matches", "checking the script compiles"]],
		["nothing shows before an open", before, [false, false, false]],
		["a request with no open does nothing", idle_asks, 0],
		["an open shows the hairline and the link", during, [true, true, true, true, false]],
		["the hairline sits on the foot of the strip and takes no clicks", anchored, [1.0, 1.0, -2.0, Control.MOUSE_FILTER_IGNORE]],
		["the hairline never moves backwards", never_backwards, 0.45],
		["Show as code asks once however often it is pressed", asks, 1],
		["Show as code reads as taken after it is pressed", link_text, "Showing as code…"],
		["the end takes every sign down", after, [false, false, false]],
	])
