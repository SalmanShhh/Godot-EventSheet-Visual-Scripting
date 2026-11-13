@tool
class_name LookStyleTest
extends RefCounted

## What the style file gives when there is no editor around (the suite), and the pure rules in it.
## The editor-theme half cannot run headless; the photo harness proves that half in a real editor.

const SUPPORT := preload("res://tests/support.gd")


static func run() -> bool:
	var ok: bool = true
	ok = _fallbacks() and ok
	ok = _strips() and ok
	ok = _contrast() and ok
	ok = _builders() and ok
	return ok


static func _fallbacks() -> bool:
	var chrome: EventSheetChromeStyle = EventSheetActiveTheme.chrome()
	return SUPPORT.pins("look_style_test", [
		["no editor theme is found headless", EventSheetLookStyle.editor_theme() == null, true],
		["the accent falls back to the sheet theme's", EventSheetLookStyle.accent(), chrome.drawer_accent_color],
		["the ink falls back to the sheet theme's", EventSheetLookStyle.ink(), chrome.drawer_ink_color],
		["the field box is a flat box headless", EventSheetLookStyle.field_box() is StyleBoxFlat, true],
		["a field is a plain height headless", EventSheetLookStyle.field_height() > 0.0, true],
		["a missing icon is null, not an error", EventSheetLookStyle.icon(&"NoSuchIconAnywhere"), null],
		["x and y take their own colour or the ink", EventSheetLookStyle.axis_color(0), EventSheetLookStyle.ink()],
	])


static func _strips() -> bool:
	return SUPPORT.pins("look_style_test", [
		["a lone button keeps both corners", EventSheetLookStyle.strip_sides(0, 1), [true, true]],
		["the first of three keeps its left", EventSheetLookStyle.strip_sides(0, 3), [true, false]],
		["the middle of three keeps none", EventSheetLookStyle.strip_sides(1, 3), [false, false]],
		["the last of three keeps its right", EventSheetLookStyle.strip_sides(2, 3), [false, true]],
	])


static func _contrast() -> bool:
	var on_accent: Color = EventSheetLookStyle.ink_on_accent()
	var accent: Color = EventSheetLookStyle.accent()
	var other: Color = on_accent.inverted()
	other.a = 1.0
	return SUPPORT.pins("look_style_test", [
		["identical colours have no contrast", EventSheetLookStyle.contrast_ratio(accent, accent), 1.0],
		["the chosen ink reads at least as well as its inverse on the accent",
			EventSheetLookStyle.contrast_ratio(on_accent, accent) >= EventSheetLookStyle.contrast_ratio(other, accent) - 0.001, true],
	])


static func _builders() -> bool:
	var field: Range = EventSheetLookStyle.number_field("x")
	var message: Label = EventSheetLookStyle.message_line("Required.", EventSheetLookStyle.Tone.ERROR)
	var panel: PanelContainer = EventSheetLookStyle.themed_panel()
	var button: Button = EventSheetLookStyle.icon_button(&"NoSuchIconAnywhere", "x", "Remove")
	var said: Array = [
		["headless the number field is a SpinBox", field is SpinBox],
		["the message line wraps", message.autowrap_mode != TextServer.AUTOWRAP_OFF],
		["the message line says the words", message.text == "Required."],
		["the themed panel carries a panel box", panel.has_theme_stylebox_override("panel")],
		["a missing icon leaves the glyph", button.text == "x"],
		["the button keeps its tooltip", button.tooltip_text == "Remove"],
	]
	for node: Node in [field, message, panel, button]:
		node.free()
	var rows: Array = []
	for pair: Variant in said:
		rows.append([(pair as Array)[0], (pair as Array)[1], true])
	return SUPPORT.pins("look_style_test", rows)
