# Godot EventSheets - the Start window gives each column the room its words ask for.
#
# The Learn column cut "Your first ev..." and "5 mi", the This editor column cut its one line, and the template list
# could cut "First person", while the Recent column beside them stood nearly empty. Each column now measures its own
# words (in the language the page speaks) and asks for that much: the kind column is as wide as its widest kind, the
# name column takes the rest and wraps a long name onto a second line, and a column with nothing in it gives its room
# to the others. This pins the arithmetic, and that at the window's own size no kind is ever cut in any language.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "start_page_columns_test"
## The window's default width and the room its margins and the gaps between four columns take.
const WINDOW_WIDTH: float = 1240.0
const FRAME: float = 90.0
## The least width the window can be made, and what it holds the columns to.
const LEAST_WIDTH: float = 760.0


static func _font() -> Font:
	return ThemeDB.fallback_font


static func run() -> bool:
	var table: Array = []
	var scale: float = EventSheetPalette.scaled_f(1.0)
	var none: Dictionary = EventSheetStartPage.column_plan(100.0, 0.0, 40.0)
	table.append(["a column with no kinds asks for no kind column", none["tag"], 0.0])
	var some: Dictionary = EventSheetStartPage.column_plan(200.0, 60.0, 40.0)
	table.append(["a short kind gets its own width and a gap", some["tag"], 60.0 + EventSheetStartPage.CELL_GAP * scale])
	var long_kind: Dictionary = EventSheetStartPage.column_plan(200.0, 400.0, 40.0)
	table.append(["a long kind is held to the limit, past which it wraps", long_kind["tag"], (EventSheetStartPage.TAG_LIMIT + EventSheetStartPage.CELL_GAP) * scale])
	table.append(["a name is never asked to shrink below the floor", EventSheetStartPage.column_plan(900.0, 60.0, 40.0)["name_floor"], EventSheetStartPage.NAME_FLOOR * scale])
	table.append(["a short name keeps all its words in the name column", EventSheetStartPage.column_plan(50.0, 60.0, 40.0)["name_floor"], 50.0])
	var wide_title: Dictionary = EventSheetStartPage.column_plan(10.0, 0.0, 300.0)
	table.append(["a column is never narrower than its own title", float(wide_title["minimum"]) >= 300.0, true])
	table.append(["what a column would like is never less than what it needs", float(some["ideal"]) >= float(some["minimum"]), true])
	table.append(["a long name is asked for up to the limit and no more", EventSheetStartPage.column_plan(5000.0, 60.0, 40.0)["ideal"], float(EventSheetStartPage.column_plan(EventSheetStartPage.NAME_LIMIT * scale, 60.0, 40.0)["ideal"])])

	# The shipped columns, in every language the plugin speaks.
	var folders: PackedStringArray = EventSheetStartPage.showcase_folders()
	var sections: Array = EventSheetStartPage.columns(folders, [], true, EventSheetStartPage.showcase_abouts(folders))
	var locales: PackedStringArray = PackedStringArray(["en"])
	locales.append_array(EventSheetL10n.available_locales())
	var seen: Dictionary = {}
	var first_locale: String = EventSheetL10n.get_locale()
	for locale: String in locales:
		if seen.has(locale):
			continue
		seen[locale] = true
		EventSheetL10n.set_locale(locale)
		var asked: float = 0.0
		var cut_kind: String = ""
		var recent_ideal: float = 0.0
		var learn_ideal: float = 0.0
		for section: Variant in sections:
			var plan: Dictionary = EventSheetStartPage.plan_for(section as Dictionary, _font(), 13, 13)
			asked += float(plan["minimum"])
			if float(plan["tag"]) < minf(float(plan["widest_tag"]), EventSheetStartPage.TAG_LIMIT * scale):
				cut_kind = str((section as Dictionary).get("id", ""))
			if str((section as Dictionary).get("id", "")) == "recent":
				recent_ideal = float(plan["ideal"])
			if str((section as Dictionary).get("id", "")) == "learn":
				learn_ideal = float(plan["ideal"])
		table.append(["%s: no kind column is narrower than its widest kind (or the limit)" % locale, cut_kind, ""])
		table.append(["%s: the empty Recent column asks for less than Learn" % locale, recent_ideal < learn_ideal, true])
		table.append(["%s: the four columns, at the least each needs, fit the window's own width" % locale, asked <= (WINDOW_WIDTH - FRAME) * scale, true])
		table.append(["%s: and fit the narrowest the window can be made" % locale, asked <= (LEAST_WIDTH - FRAME) * scale, true])
	EventSheetL10n.set_locale(first_locale)
	_row_pins(table, sections)
	return SUPPORT.pins(P, table)


## Every row carries the whole of its name and its kind as a tooltip, and both cells wrap rather than cut.
static func _row_pins(table: Array, sections: Array) -> void:
	var page: EventSheetStartPage = EventSheetStartPage.new()
	var checked: int = 0
	var without_tip: int = 0
	var without_wrap: int = 0
	for section: Variant in sections:
		var list: Tree = Tree.new()
		list.columns = 2
		list.hide_root = true
		page._fill_list(list, (section as Dictionary).get("entries", []))
		var stack: Array = [list.get_root()]
		while not stack.is_empty():
			var item: TreeItem = stack.pop_back()
			var child: TreeItem = item.get_first_child()
			while child != null:
				stack.append(child)
				child = child.get_next()
			if item == list.get_root() or item.get_metadata(0) == null:
				continue
			checked += 1
			if item.get_tooltip_text(0) != item.get_text(0) or item.get_tooltip_text(1) != item.get_text(1):
				without_tip += 1
			if item.get_autowrap_mode(0) == TextServer.AUTOWRAP_OFF or item.get_autowrap_mode(1) == TextServer.AUTOWRAP_OFF:
				without_wrap += 1
		list.free()
	table.append(["every row of every column was looked at (%d)" % checked, checked > 40, true])
	table.append(["each carries its whole name and kind as a tooltip", without_tip, 0])
	table.append(["and each wraps a long name or kind instead of cutting it", without_wrap, 0])
