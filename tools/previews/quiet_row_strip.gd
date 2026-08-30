# Godot EventSheets - the amber row selected, and the strip that speaks for it (preview module).
#
# Rendered by tools/render_previews.gd, which owns the window and the shutter; this owns the picture.
# The whole journey in one frame: a spawning finding has put its row into the quiet amber state - a
# faint warning tint and a thin inset, nothing drawn inside the row - and the row is selected, so
# the help strip at the bottom of the dock says the finding's sentence with its one door beside it.
# The row below it, with nothing wrong, is exactly as it always was.
@tool
extends RefCounted

const PREVIEW_NAME: String = "quiet-row-strip"
const PREVIEW_SIZE: Vector2i = Vector2i(1700, 900)


static func build(host: Window) -> Control:
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Area2D"
	sheet.events.append(_event("OnBodyEntered", [_raw("add_child(Bullet.instantiate())")]))
	sheet.events.append(_event("OnReady", [_raw("print(\"ready\")")]))
	dock.setup(sheet)
	dock.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(dock)
	# Select the amber row, which is what makes the strip speak: the words are nowhere in the sheet.
	for row_data: EventRowData in dock._viewport._root_rows:
		if not row_data.attention_note.is_empty():
			row_data.selected = true
			dock._update_row_help_strip(row_data)
	return dock


static func _event(trigger_id: String, actions: Array) -> EventRow:
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = trigger_id
	for action: Variant in actions:
		event.actions.append(action)
	return event


static func _raw(code: String) -> RawCodeRow:
	var raw: RawCodeRow = RawCodeRow.new()
	raw.code = code
	return raw
