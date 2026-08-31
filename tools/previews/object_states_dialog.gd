# Godot EventSheets - the Declare states dialog (preview module).
#
# Rendered by tools/render_previews.gd. Two questions and one help strip: what the states are called,
# which one the object starts in, and under them the two lines that say what pressing OK will do -
# what the head will read as, and the declarations it is about to write. The strings are the dialog's
# OWN (`reads_as` and `in_code` are the same statics the dialog calls), so the picture cannot show a
# reading the dialog would not produce.
@tool
extends RefCounted

const PREVIEW_NAME: String = "object-states-dialog"
const PREVIEW_SIZE: Vector2i = Vector2i(760, 360)

## What the fields are filled with for the photograph - the states of an enemy that patrols.
const DECLARED: PackedStringArray = ["Patrol", "Chase", "Stagger"]
const STARTS_IN: String = "Patrol"


static func build(host: Window) -> Control:
	var fields: VBoxContainer = EventSheetPopupUI.form_box()
	var states: LineEdit = LineEdit.new()
	states.text = " · ".join(DECLARED)
	fields.add_child(EventSheetPopupUI.form_row("States", states))
	var starts: OptionButton = OptionButton.new()
	for word: String in DECLARED:
		starts.add_item(word)
	starts.select(0)
	fields.add_child(EventSheetPopupUI.form_row("Starts in", starts))

	var strip: EventSheetPopupUI.HelpStrip = EventSheetPopupUI.help_strip()
	var note: String = "The states this one object can be in, separated by anything you like. They become an enum, and every row that names a state is offered this list as it types - so a state is picked rather than remembered, and a row naming one that is not here is what the Doctor calls out."
	strip.follow(states, "States", note)
	strip.describe("States", note)
	strip.set_reading(EventSheetStatesDialog.reads_as(DECLARED, STARTS_IN),
		EventSheetStatesDialog.in_code(DECLARED, STARTS_IN))

	var column: VBoxContainer = EventSheetPopupUI.form_box()
	column.add_child(EventSheetPopupUI.panel_section(fields))
	column.add_child(strip)
	var card: PanelContainer = EventSheetPopupUI.titled_card("States", column)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var framed: Control = EventSheetPopupUI.margined(card)
	framed.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(framed)
	return framed
