# EventSheet - shared popup UI helpers (consistent dialog look).
# Verifies the pure factory helpers produce the expected control structure.
@tool
class_name PopupUITest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true

	# form_row: an aligned "Label  [field]" row.
	var field: LineEdit = LineEdit.new()
	var row: HBoxContainer = EventSheetPopupUI.form_row("Name", field)
	all_passed = _check("form_row holds a label + the field", row.get_child_count(), 2) and all_passed
	var label: Label = row.get_child(0) as Label
	all_passed = _check("form_row label carries the text", label.text, "Name") and all_passed
	all_passed = _check("form_row label has a fixed leading width", label.custom_minimum_size.x, EventSheetPopupUI.LABEL_MIN_WIDTH) and all_passed
	all_passed = _check("form_row field expands to fill", (row.get_child(1) as Control).size_flags_horizontal, Control.SIZE_EXPAND_FILL) and all_passed
	row.free()

	# margined: standard breathing room around content.
	var content: Label = Label.new()
	var margined: MarginContainer = EventSheetPopupUI.margined(content)
	all_passed = _check("margined wraps the content", margined.get_child(0) == content, true) and all_passed
	all_passed = _check("margined applies margins on every side",
		margined.has_theme_constant_override("margin_left") and margined.has_theme_constant_override("margin_bottom"), true) and all_passed
	margined.free()

	# form_box + hint_label.
	var box: VBoxContainer = EventSheetPopupUI.form_box()
	all_passed = _check("form_box sets a row-separation override", box.has_theme_constant_override("separation"), true) and all_passed
	box.free()
	var hint: Label = EventSheetPopupUI.hint_label("note")
	all_passed = _check("hint_label text", hint.text, "note") and all_passed
	all_passed = _check("hint_label is muted", hint.modulate.a < 1.0, true) and all_passed
	hint.free()

	# Keyboard Shortcuts editor (Tools ▸ Keyboard Shortcuts): the rebindable action list + the
	# read-only fixed-keys reference are both populated.
	all_passed = _check("rebindable shortcut list is populated", EventSheetShortcuts.ORDER.size() >= 4, true) and all_passed
	all_passed = _check("rebindable action labels resolve", EventSheetShortcuts.label_for("add_event"), "Add event") and all_passed
	var flat: String = ""
	for pair: Array in EventSheetDock.FIXED_KEYS:
		flat += str(pair[0]) + " | " + str(pair[1]) + "\n"
	all_passed = _check("fixed-keys reference lists the Command Palette", flat.contains("Ctrl + P") and flat.contains("Command Palette"), true) and all_passed
	all_passed = _check("fixed-keys reference lists Find & Replace", flat.contains("Ctrl + F"), true) and all_passed

	all_passed = _test_reference_primitives() and all_passed
	return all_passed


## The Compact Developer primitives the documentation surfaces are drawn from. Pinned here rather
## than in each surface's own test, because they are ONE style shared by several files - a change
## that quietly turns the parameters table back into prose has to fail somewhere.
static func _test_reference_primitives() -> bool:
	var all_passed: bool = true

	# A section label is upper-cased for the caller (surfaces pass sentence case).
	var caps: Label = EventSheetPopupUI.small_caps_label("How this reads on the sheet")
	all_passed = _check("small_caps_label upper-cases its text", caps.text, "HOW THIS READS ON THE SHEET") and all_passed
	all_passed = _check("small_caps_label is accent-tinted",
		caps.get_theme_color("font_color"), EventSheetPopupUI.accent_color()) and all_passed
	caps.free()

	# The tracking is a FontVariation, and it is SHARED: not every small-caps row in the plugin is
	# a Label (a Tree group heading is a TreeItem, which takes a font but cannot host a control), and
	# a second recipe for "small caps" is how two headings side by side end up looking different.
	all_passed = _check("small_caps_font varies the font it is handed",
		EventSheetPopupUI.small_caps_font(ThemeDB.fallback_font) != null, true) and all_passed
	all_passed = _check("with the shared letter spacing on it",
		EventSheetPopupUI.small_caps_font(ThemeDB.fallback_font).get_spacing(TextServer.SPACING_GLYPH),
		EventSheetPalette.scaled(EventSheetPopupUI.SMALL_CAPS_TRACKING)) and all_passed
	all_passed = _check("and no font at all leaves the caller's alone",
		EventSheetPopupUI.small_caps_font(null), null) and all_passed

	var badge: PanelContainer = EventSheetPopupUI.metadata_badge("Action")
	all_passed = _check("metadata_badge carries its one label",
		(badge.get_child(0) as Label).text, "Action") and all_passed
	badge.free()

	# The table is a GRID, and its cell count is header + one row per entry, so a table that
	# silently dropped its header row (or a column) fails here rather than on a screenshot.
	var table: GridContainer = EventSheetPopupUI.compact_table(
		PackedStringArray(["Name", "Type", "Default", "Description"]),
		[PackedStringArray(["Quest Id", "String", "\"\"", "Which quest."]),
		PackedStringArray(["Amount", "int", "1", ""])], 3)
	all_passed = _check("compact_table keeps a column per header", table.columns, 4) and all_passed
	all_passed = _check("compact_table draws the header row plus one row per entry",
		table.get_child_count(), 12) and all_passed
	all_passed = _check("compact_table upper-cases its header cells",
		((table.get_child(0) as PanelContainer).get_child(0) as Label).text, "NAME") and all_passed
	all_passed = _check("compact_table keeps a row's cell verbatim",
		((table.get_child(4) as PanelContainer).get_child(0) as Label).text, "Quest Id") and all_passed
	all_passed = _check("compact_table pads a short row rather than shifting the next one",
		((table.get_child(11) as PanelContainer).get_child(0) as Label).text, "") and all_passed
	table.free()

	# The breakpoint, as a pure function of width: the whole layout decision, pinned without a
	# window. At the number itself the band is already two columns (>=, not >).
	all_passed = _check("a band at the breakpoint draws two columns",
		EventSheetPopupUI.prefers_two_columns(EventSheetPopupUI.TWO_COLUMN_MIN_WIDTH), true) and all_passed
	all_passed = _check("a band one pixel under the breakpoint stacks",
		EventSheetPopupUI.prefers_two_columns(EventSheetPopupUI.TWO_COLUMN_MIN_WIDTH - 1.0), false) and all_passed
	all_passed = _check("a dock-width column stacks",
		EventSheetPopupUI.prefers_two_columns(360.0), false) and all_passed
	all_passed = _check("a window-width page does not",
		EventSheetPopupUI.prefers_two_columns(760.0), true) and all_passed

	# A band starts STACKED and flips on its first resize: an un-laid-out band that guessed "wide"
	# would flash two columns in a narrow dock on every page change.
	var band: BoxContainer = EventSheetPopupUI.responsive_band(Label.new(), Label.new())
	all_passed = _check("a band holds both columns", band.get_child_count(), 2) and all_passed
	all_passed = _check("a band starts stacked until it is laid out", band.vertical, true) and all_passed
	all_passed = _check("both columns take the slack",
		(band.get_child(0) as Control).size_flags_horizontal, Control.SIZE_EXPAND_FILL) and all_passed
	band.free()

	var card: PanelContainer = EventSheetPopupUI.labelled_card("About Quest", Label.new())
	var card_body: VBoxContainer = card.get_child(0) as VBoxContainer
	all_passed = _check("labelled_card heads itself with a small-caps label",
		(card_body.get_child(0) as Label).text, "ABOUT QUEST") and all_passed
	card.free()
	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] popup_ui_test: %s" % label)
		return true
	print("[FAIL] popup_ui_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
