# The Start window at the smallest size it can be made. A language whose words wrap to more lines asks the
# columns for more height than the window's least height, and the strip and the Close and Open buttons under
# them were pushed past the window's bottom edge, out of reach. The columns now scroll inside the window, so
# whatever they ask for, what the window's content asks for never passes the window's least size and the
# buttons stay in view.
@tool
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")
const TEST_NAME: String = "start_window_smallest_test"


static func run() -> bool:
	var ok: bool = true
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	var page: EventSheetStartPage = EventSheetStartPage.new()
	page.init(dock)
	page._build()
	var window: Window = page._window
	ok = SUPPORT.pin_value(TEST_NAME, "the columns sit in a scroll area that never scrolls sideways",
		page._columns_stack.get_parent() is ScrollContainer
		and (page._columns_stack.get_parent() as ScrollContainer).horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, true) and ok
	var worst_height: float = 0.0
	var worst_locale: String = ""
	for locale: String in EventSheetL10n.available_locales():
		EventSheetL10n.set_locale(locale)
		page._fill()
		var content: Control = window.get_child(0) as Control
		var asked: float = content.get_combined_minimum_size().y
		if asked > worst_height:
			worst_height = asked
			worst_locale = locale
		ok = SUPPORT.pin_value(TEST_NAME, "%s: the window's content asks for no more height than the window's least (%d of %d)" % [locale, int(asked), window.min_size.y],
			asked <= float(window.min_size.y), true) and ok
	EventSheetL10n.set_locale("en")
	dock.free()
	ok = _test_the_columns_go_on_more_rows_when_the_window_cannot_read_them_side_by_side() and ok
	ok = _test_what_a_column_needs_to_read() and ok
	return ok


static func _test_what_a_column_needs_to_read() -> bool:
	var scale: float = EventSheetPalette.scaled_f(1.0)
	var long_names: Dictionary = EventSheetStartPage.column_plan(400.0, 60.0, 40.0, 50.0)
	long_names["name"] = 400.0
	var short_names: Dictionary = EventSheetStartPage.column_plan(60.0, 0.0, 40.0, 40.0)
	short_names["name"] = 60.0
	var wide: float = EventSheetStartPage.readable_width(long_names)
	var narrow: float = EventSheetStartPage.readable_width(short_names)
	var ok: bool = SUPPORT.pin_value(TEST_NAME, "long names are given a few words of room, no more",
		is_equal_approx(wide, float(long_names["tag"]) + (EventSheetStartPage.READABLE_NAME + EventSheetStartPage.CELL_SLACK + EventSheetStartPage.CARD_PAD) * scale), true)
	ok = SUPPORT.pin_value(TEST_NAME, "a column of short names asks for less than one of long names", narrow < wide, true) and ok
	ok = SUPPORT.pin_value(TEST_NAME, "no column asks for less than the least the plan allows", narrow >= float(short_names["minimum"]), true) and ok
	return ok


static func _test_the_columns_go_on_more_rows_when_the_window_cannot_read_them_side_by_side() -> bool:
	var four: PackedFloat32Array = PackedFloat32Array([300.0, 250.0, 250.0, 200.0])
	var three: PackedFloat32Array = PackedFloat32Array([300.0, 250.0, 250.0])
	var ok: bool = true
	var cases: Array = [
		["wide enough for all four: one row", four, 1100.0, [4]],
		["just short of four: two rows of two, not three and one", four, 1000.0, [2, 2]],
		["room for two, not three: two rows of two", four, 600.0, [2, 2]],
		["room for three only: three columns, one row", three, 850.0, [3]],
		["a narrow window: one column per row", four, 320.0, [1, 1, 1, 1]],
		["a window too narrow for even one keeps one per row", four, 100.0, [1, 1, 1, 1]],
		["no room measured yet keeps one row", four, 0.0, [4]],
		["no columns, no rows", PackedFloat32Array(), 500.0, []],
	]
	for case: Array in cases:
		var got: Array[int] = EventSheetStartPage.columns_per_row(case[1] as PackedFloat32Array, float(case[2]), 12.0)
		ok = SUPPORT.pin_value(TEST_NAME, str(case[0]), Array(got), case[3]) and ok
	return ok
