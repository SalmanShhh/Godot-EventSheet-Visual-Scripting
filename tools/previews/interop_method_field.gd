# Godot EventSheets - Call Method's Method field reading the target's own script (preview module).
#
# Rendered by tools/render_previews.gd. The entries come from the completion seam, which is the same
# answer the dialog's field and the sheet's inline editor both ask for, so the picture cannot drift
# from the behaviour. What is drawn as a panel here is an OS-level popup window in the editor.
#
# The target is a node of the corpus room wearing a hand-written player script: its own methods lead,
# each with the arguments as the file writes them and the `##` line above the declaration, and what
# CharacterBody2D adds follows, named with the class it came from.
@tool
extends RefCounted

const PREVIEW_NAME: String = "interop-method-field"
const PREVIEW_SIZE: Vector2i = Vector2i(760, 380)

const FIXTURE: String = "res://tests/fixtures/interop_corpus/room.gd"


static func build(host: Window) -> Control:
	EventSheetCompletions.clear_cache()
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(FIXTURE)
	var fields: VBoxContainer = EventSheetPopupUI.form_box()
	var target: LineEdit = LineEdit.new()
	target.text = "$Hero"
	fields.add_child(EventSheetPopupUI.form_row("Target", target))
	var method: LineEdit = LineEdit.new()
	method.text = "take"
	fields.add_child(EventSheetPopupUI.form_row("Method", method))
	fields.add_child(_suggestions(EventSheetCompletions.for_field(sheet,
		"%s:%s" % [EventSheetCompletions.FIELD_METHOD, target.text], method.text)))
	var strip: EventSheetPopupUI.HelpStrip = EventSheetPopupUI.help_strip()
	strip.describe("Method - a method of $Hero",
		"Everything the script on that node declares, then what CharacterBody2D adds. The line beside each one is its arguments and the ## comment above it.")
	strip.set_reading("Hero - Take damage - 5", "$Hero.take_damage(5)")
	var column: VBoxContainer = EventSheetPopupUI.form_box()
	column.add_child(EventSheetPopupUI.panel_section(fields))
	column.add_child(strip)
	var card: PanelContainer = EventSheetPopupUI.titled_card("Call method   on $Hero", column)
	var margined: MarginContainer = EventSheetPopupUI.margined(card)
	margined.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(margined)
	return margined


## The suggestion list as the popup draws it: one row per entry, the name then the line that
## explains it.
static func _suggestions(entries: Array[Dictionary]) -> Control:
	var list: ItemList = ItemList.new()
	list.custom_minimum_size = Vector2(0.0, 120.0)
	for entry: Dictionary in entries:
		list.add_item(EventSheetCompletionPopup.item_text(entry))
	if list.item_count > 0:
		list.select(0)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	column.add_child(list)
	column.add_child(EventSheetPopupUI.hint_label(
		"Tab or Enter accepts, Escape keeps what you typed", 400.0))
	return EventSheetPopupUI.panel_section(column)
