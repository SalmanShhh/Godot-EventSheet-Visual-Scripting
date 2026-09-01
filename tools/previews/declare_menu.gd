# Godot EventSheets - the Add menu's Declare group (preview module).
#
# Rendered by tools/render_previews.gd, which owns the window and the shutter; this owns the
# picture. The claim is the GROUP: every way to give something a name, in one submenu, each entry
# saying in its tooltip which dialog it opens and already set to which shape. So the picture is
# built from the REAL menu - a dock is stood up, the Declare popup is found by its name, and every
# label and tooltip on the card is read off the popup's own items rather than retyped here.
@tool
extends RefCounted

const PREVIEW_NAME: String = "declare-menu"
const PREVIEW_SIZE: Vector2i = Vector2i(760, 520)


static func build(host: Window) -> Control:
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(EventSheetResource.new())
	# Add hangs off the one cascading Menu button now rather than off a MenuButton of its own.
	var menu_button: MenuButton = editor._toolbar.find_child("EventSheetMenu", true, false) as MenuButton
	var add_popup: PopupMenu = menu_button.get_popup().find_child("EventSheetAddMenu", true, false) as PopupMenu
	var declare_popup: PopupMenu = add_popup.find_child("EventSheetDeclareMenu", true, false) as PopupMenu
	var rows: VBoxContainer = EventSheetPopupUI.form_box()
	for item_index: int in declare_popup.item_count:
		var entry: VBoxContainer = VBoxContainer.new()
		var label: Label = Label.new()
		label.text = declare_popup.get_item_text(item_index)
		entry.add_child(label)
		var tooltip: Label = Label.new()
		tooltip.text = declare_popup.get_item_tooltip(item_index)
		tooltip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tooltip.add_theme_font_size_override("font_size", 11)
		tooltip.modulate = Color(1.0, 1.0, 1.0, 0.6)
		entry.add_child(tooltip)
		rows.add_child(entry)
	editor.queue_free()
	var card: Control = EventSheetPopupUI.titled_card("Add ▸ Declare", EventSheetPopupUI.panel_section(rows))
	var margined: MarginContainer = EventSheetPopupUI.margined(card)
	margined.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(margined)
	return margined
