# Godot EventSheets - a row whose verb the vocabulary has lost, selected (preview module).
#
# Rendered by tools/render_previews.gd, which owns the window and the shutter; this owns the picture.
# The whole state in one frame: the row still reads as the sentence it was written as - the reading
# rides on the row, so the missing pack cannot blank it - and it still compiles, because its template
# does too. All the sheet says about it is the quiet amber. The head's one counting line says how
# many rows ask a question and how many would migrate without one, and the selected row's help strip
# at the bottom says the finding's sentence with its two doors beside it. The event under it, written
# in words the vocabulary still has, is exactly as it always was.
@tool
extends RefCounted

const PREVIEW_NAME: String = "migration-amber-row"
const PREVIEW_SIZE: Vector2i = Vector2i(1700, 900)


static func build(host: Window) -> Control:
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.custom_class_name = "Lamp"
	sheet.host_class = "Node2D"
	# The file's own opening lines, so the head band stack builds: the head is one band per line of
	# the file, and the migration band joins it as the one line that is derived instead.
	sheet.events.append(_raw("\n".join(PackedStringArray(["class_name Lamp", "extends Node2D"]))))
	sheet.events.append(_event("OnReady", [_gone_action()]))
	sheet.events.append(_event("OnProcess", [_print_action()]))
	dock.setup(sheet)
	dock.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(dock)
	# Select the amber row, which is what makes the strip speak: the words are nowhere in the sheet.
	for row_data: EventRowData in dock._viewport._root_rows:
		if not row_data.attention_note.is_empty():
			row_data.selected = true
			dock._update_row_help_strip(row_data)
	return dock


## The row the picture is about: a verb from a pack this project no longer installs, with the code
## and the reading it was applied with both written onto it.
static func _gone_action() -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "LightFlicker"
	action.ace_id = "FlickerLight"
	action.codegen_template = "flicker({light}, {amount})"
	action.display_text = "Flicker {light} by {amount}"
	action.params = {"light": "$Lamp", "amount": "0.4"}
	return action


## The row beside it, written in words the vocabulary still has - so the picture shows the amber
## against the ordinary rather than on its own.
static func _print_action() -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "Print"
	action.params = {"value": "\"lit\""}
	return action


static func _raw(code: String) -> RawCodeRow:
	var raw: RawCodeRow = RawCodeRow.new()
	raw.code = code
	return raw


static func _event(trigger_id: String, actions: Array) -> EventRow:
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = trigger_id
	for action: Variant in actions:
		event.actions.append(action)
	return event
