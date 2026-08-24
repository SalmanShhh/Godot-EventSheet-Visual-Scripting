# Godot EventSheets - the shape every parameter dialog wears (preview module).
#
# Rendered by tools/render_previews.gd. A card with the row's own sentence as its title, the fields
# under it, and ONE help strip at the foot describing whatever is focused - the shape the Add
# variable, Compare, Sheet type, Message and Parameters dialogs all share. Kept here because a slice
# that adds a dialog can point this at its own fields and see the answer before wiring a window.
@tool
extends RefCounted

const PREVIEW_NAME: String = "dialog-shape"
const PREVIEW_SIZE: Vector2i = Vector2i(720, 460)


static func build(host: Window) -> Control:
	var fields: VBoxContainer = EventSheetPopupUI.form_box()
	var brightness: LineEdit = LineEdit.new()
	brightness.text = "1.2"
	fields.add_child(EventSheetPopupUI.form_row("Brightness", brightness))
	var seconds: LineEdit = LineEdit.new()
	seconds.text = "0.4"
	fields.add_child(EventSheetPopupUI.form_row("Over", seconds))
	var strip: EventSheetPopupUI.HelpStrip = EventSheetPopupUI.help_strip()
	# The wiring the walk gate checks for: every field says what it is THROUGH the one strip, on
	# focus, rather than printing a hint of its own under itself.
	strip.follow(brightness, "Brightness",
		"How bright the light burns. 1 is the light's own setting; 0 turns it off without hiding it.")
	strip.follow(seconds, "Over", "How long the change takes, in seconds. 0 changes it at once.")
	strip.describe("Brightness",
		"How bright the light burns. 1 is the light's own setting; 0 turns it off without hiding it.")
	strip.set_reading("Torch - Fade brightness to 1.2 over 0.4 seconds",
		"create_tween().tween_property($Torch, \"energy\", 1.2, 0.4)")
	var column: VBoxContainer = EventSheetPopupUI.form_box()
	column.add_child(EventSheetPopupUI.panel_section(fields))
	column.add_child(strip)
	var card: PanelContainer = EventSheetPopupUI.titled_card("Torch - Fade brightness", column)
	var margined: MarginContainer = EventSheetPopupUI.margined(card)
	margined.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(margined)
	return margined
