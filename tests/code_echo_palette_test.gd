# Godot EventSheets - the code beside a variable row is coloured for the ground it is drawn on.
#
# The script editor's colours belong to the editor's own ground. A light sheet theme in a dark editor
# (or a dark one in a light editor) must keep the sheet theme's own tokens, or the code would be dark
# grey on near-black.
@tool
class_name CodeEchoPaletteTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const CHOICES := preload("res://addons/eventsheet/theme/theme_choices.gd")
const P := "code_echo_palette_test"


static func run() -> bool:
	var dark: Color = Color("#262626")
	var light: Color = Color("#ededed")
	var ok: bool = SUPPORT.pins(P, [
		["a dark sheet in a dark editor takes the editor's colours", CHOICES.use_editor_colours(dark, Color("#292929")), true],
		["a light sheet in a light editor takes the editor's colours", CHOICES.use_editor_colours(light, Color("#e6e6e6")), true],
		["a light sheet in a dark editor keeps its own", CHOICES.use_editor_colours(light, Color("#292929")), false],
		["a dark sheet in a light editor keeps its own", CHOICES.use_editor_colours(dark, Color("#e6e6e6")), false],
		["with no editor there are no editor colours", CHOICES.use_editor_colours(dark, Color(0, 0, 0, 0)), false],
	])
	var style: EventSheetEditorStyle = EventSheetEditorThemeDeriver.native_style(Color("#e6e6e6"))
	var own: Dictionary = EventSheetCodeEcho.palette(style.get_reading_style(), style.get_event_style())
	ok = SUPPORT.check(P, "outside the editor the palette is the sheet theme's own", own[EventSheetCodeEcho.TOKEN_MEMBER], style.get_reading_style().primary_text_color) and ok
	return ok
