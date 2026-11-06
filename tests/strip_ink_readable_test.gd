# Godot EventSheets - the sheet strip's words and the open tab's name stay readable on any editor theme.
#
# The strip wears the editor's own button and tab styles. An editor whose fonts are set to the light
# colour on a light base hands out white words on white boxes, which left the strip's Menu, Code and
# Both buttons blank. EventSheetMenuBar.keep_readable redraws only a word that does not stand out from
# its box, so a dark editor and Godot's Light preset are pinned to come through untouched. A stand-in
# theme plays the editor's here, with the colours the real editor hands out for each base.
@tool
class_name StripInkReadableTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const TEST_NAME := "strip_ink_readable_test"
## [name, base, button font, button box, tab font, selected tab box], as the editor hands them out.
const BASES: Array = [
	["dark", Color("292929"), Color(1, 1, 1, 0.75), Color("424242"), Color(1, 1, 1, 0.75), Color("1a1a1a99")],
	["light preset", Color("e6e6e6"), Color(0, 0, 0, 0.75), Color("cacaca"), Color(0, 0, 0, 0.75), Color("e6e6e6")],
	["custom light, fonts automatic", Color("e3e3e3"), Color(0, 0, 0, 0.75), Color("ffffff"), Color(0, 0, 0, 0.75), Color("e3e3e3")],
	["custom light, fonts set light", Color("e3e3e3"), Color(1, 1, 1, 0.75), Color("ffffff"), Color(1, 1, 1, 0.75), Color("e3e3e3")],
]


static func run() -> bool:
	var rows: Array = []
	for base: Array in BASES:
		rows.append_array(_rows_for(base))
	rows.append_array(_switch_back_rows())
	rows.append_array(_owner_colour_rows())
	_restore()
	return SUPPORT.pins(TEST_NAME, rows)


const BUTTON_FONTS: Array[String] = ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]
const BUTTON_BOXES: Array[String] = ["normal", "hover", "pressed", "hover_pressed"]
const TAB_FONTS: Array[String] = ["font_selected_color", "font_unselected_color", "font_hovered_color"]
const TAB_BOXES: Array[String] = ["tab_selected", "tab_unselected", "tab_hovered"]
## The default theme's own items, put back when the test ends.
static var _saved: Dictionary = {}


## Writes a base's colours into the default theme. A control outside a tree (the suite has none)
## resolves its theme items from there alone, so that is where the stand-in editor theme goes.
static func _wear(base: Array) -> void:
	var theme: Theme = ThemeDB.get_default_theme()
	if _saved.is_empty():
		for slot: String in BUTTON_FONTS:
			_saved[["c", slot, "Button"]] = theme.get_color(slot, "Button")
		for box_name: String in BUTTON_BOXES:
			_saved[["s", box_name, "Button"]] = theme.get_stylebox(box_name, "Button")
		for slot: String in TAB_FONTS:
			_saved[["c", slot, "TabBar"]] = theme.get_color(slot, "TabBar")
		for box_name: String in TAB_BOXES:
			_saved[["s", box_name, "TabBar"]] = theme.get_stylebox(box_name, "TabBar")
	for slot: String in BUTTON_FONTS:
		theme.set_color(slot, "Button", base[2])
	for box_name: String in BUTTON_BOXES:
		theme.set_stylebox(box_name, "Button", _flat(base[3]))
	for slot: String in TAB_FONTS:
		theme.set_color(slot, "TabBar", base[4])
	for box_name: String in TAB_BOXES:
		theme.set_stylebox(box_name, "TabBar", _flat(base[5]))


static func _flat(fill: Color) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = fill
	return box


static func _restore() -> void:
	var theme: Theme = ThemeDB.get_default_theme()
	for key: Array in _saved:
		if key[0] == "c":
			theme.set_color(key[1], key[2], _saved[key])
		else:
			theme.set_stylebox(key[1], key[2], _saved[key])
	_saved.clear()


## The worst contrast any slot of `control` has against its box, as the reader sees it.
static func _worst(control: Control, slots: Array, backdrop: Color) -> float:
	var worst: float = 100.0
	for pair: Array in slots:
		var fill: Color = EventSheetMenuBar._fill_behind(control, str(pair[1]), backdrop)
		var ink: Color = control.get_theme_color(str(pair[0]))
		var shown: Color = fill.lerp(Color(ink.r, ink.g, ink.b, 1.0), ink.a)
		worst = minf(worst, EventSheetEditorThemeDeriver.contrast_ratio(shown, fill))
	return worst


static func _rows_for(base: Array) -> Array:
	var root: Control = Control.new()
	_wear(base)
	var button: Button = Button.new()
	button.text = "Code"
	var flat: Button = Button.new()
	flat.text = "Run Scene"
	flat.flat = true
	var tabs: TabBar = TabBar.new()
	for child: Control in [button, flat, tabs]:
		root.add_child(child)
	var backdrop: Color = base[1]
	var before: Color = button.get_theme_color("font_color")
	for control: Control in [button, flat]:
		EventSheetMenuBar.keep_readable(control, EventSheetMenuBar.BUTTON_INK_SLOTS, backdrop)
	EventSheetMenuBar.keep_readable(tabs, EventSheetMenuBar.TAB_INK_SLOTS, backdrop)
	var name: String = base[0]
	var already_readable: bool = name != "custom light, fonts set light"
	var rows: Array = [
		["%s: every strip button word reads on its box" % name,
			_worst(button, EventSheetMenuBar.BUTTON_INK_SLOTS, backdrop) >= EventSheetMenuBar.STRIP_INK_MIN_CONTRAST, true],
		["%s: a flat button's word reads on the strip" % name,
			_worst(flat, EventSheetMenuBar.BUTTON_INK_SLOTS, backdrop) >= EventSheetMenuBar.STRIP_INK_MIN_CONTRAST, true],
		["%s: the tab names read on their tabs" % name,
			_worst(tabs, EventSheetMenuBar.TAB_INK_SLOTS, backdrop) >= EventSheetMenuBar.STRIP_INK_MIN_CONTRAST, true],
		["%s: the editor's own word is kept when it reads" % name,
			button.get_theme_color("font_color") == before, already_readable],
		["%s: an ink of the plugin's own only where the editor's did not read" % name,
			[button.has_theme_color_override("font_color"), tabs.has_theme_color_override("font_selected_color")],
			[not already_readable, not already_readable]],
	]
	root.free()
	return rows


## A switch back to a dark editor takes the plugin's inks off again, so the editor's own words return.
static func _switch_back_rows() -> Array:
	var root: Control = Control.new()
	_wear(BASES[3])
	var button: Button = Button.new()
	root.add_child(button)
	EventSheetMenuBar.keep_readable(button, EventSheetMenuBar.BUTTON_INK_SLOTS, BASES[3][1])
	var dark_ink: Color = Color(0.0, 0.0, 0.0, 0.85)
	var on_light: Color = button.get_theme_color("font_color")
	_wear(BASES[0])
	# The editor tells its controls their theme changed; this button is told by hand.
	button.notification(Control.NOTIFICATION_THEME_CHANGED)
	EventSheetMenuBar.keep_readable(button, EventSheetMenuBar.BUTTON_INK_SLOTS, BASES[0][1])
	var rows: Array = [
		["on white boxes the word is drawn dark", on_light, dark_ink],
		["after a switch to dark the editor's own word is back", button.get_theme_color("font_color"), BASES[0][2]],
		["and nothing of the plugin's is left on the button", button.has_theme_color_override("font_color"), false],
	]
	root.free()
	return rows


## A colour the strip set itself (the view switch's accent) is its owner's choice and is not touched.
static func _owner_colour_rows() -> Array:
	var root: Control = Control.new()
	_wear(BASES[3])
	var button: Button = Button.new()
	root.add_child(button)
	var accent: Color = Color("30578c")
	button.add_theme_color_override("font_pressed_color", accent)
	EventSheetMenuBar.keep_readable(button, EventSheetMenuBar.BUTTON_INK_SLOTS, BASES[3][1])
	var kept: Color = button.get_theme_color("font_pressed_color")
	root.free()
	return [["a word coloured by its owner keeps its colour", kept, accent]]
