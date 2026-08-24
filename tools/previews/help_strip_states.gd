# Godot EventSheets - the ONE help strip, in the three voices it speaks in (preview module).
#
# Rendered by tools/render_previews.gd, which owns the window and the shutter; this owns the picture.
# The strip is the one place a dialog explains itself, so what it looks like when it is describing,
# when it is warning, and when it is refusing is worth being able to see side by side.
@tool
extends RefCounted

const PREVIEW_NAME: String = "help-strip-states"
const PREVIEW_SIZE: Vector2i = Vector2i(720, 560)


static func build(host: Window) -> Control:
	var column: VBoxContainer = EventSheetPopupUI.form_box()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.add_child(_titled("Describing", _describing()))
	column.add_child(_titled("Warning", _warning()))
	column.add_child(_titled("Refusing", _refusing()))
	var margined: MarginContainer = EventSheetPopupUI.margined(column)
	margined.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(margined)
	return margined


## The ordinary voice: what the focused field is, what it does, and what the row will read as.
static func _describing() -> Control:
	return EventSheetPopupUI.help_strip("Scope - Instance",
		"One of these per copy of the object. Each enemy gets its own, and the sheet's own rows can read and write it.",
		"Instance number hp = 100", "var hp: int = 100")


static func _warning() -> Control:
	var strip: EventSheetPopupUI.HelpStrip = EventSheetPopupUI.help_strip()
	strip.show_note("Initial value", "3.5 is not a whole number, so the value will be rounded when the game runs.",
		EventSheetPopupUI.HelpStrip.TONE_WARNING)
	strip.set_reading("Instance whole number lives = 3", "var lives: int = 3")
	return strip


static func _refusing() -> Control:
	var strip: EventSheetPopupUI.HelpStrip = EventSheetPopupUI.help_strip()
	strip.show_note("Name", "There is already a variable called hp on this object.",
		EventSheetPopupUI.HelpStrip.TONE_ERROR,
		[{"text": "Edit the existing hp", "pressed": Callable()}])
	return strip


static func _titled(title: String, strip: Control) -> Control:
	return EventSheetPopupUI.titled_card(title, strip)
