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
		page._columns_row.get_parent() is ScrollContainer
		and (page._columns_row.get_parent() as ScrollContainer).horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, true) and ok
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
	return ok
