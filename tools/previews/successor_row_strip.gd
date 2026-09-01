# Godot EventSheets - a row in the older spelling, and the one muted line that says so (preview module).
#
# Rendered by tools/render_previews.gd, which owns the window and the shutter; this owns the picture.
# The point of the picture is what is NOT in it. The first event uses the State Machine pack's Go to
# state, which the object-state vocabulary has since superseded - and the row looks exactly like the
# row under it, which uses nothing of the kind: no block, no icon, no badge, no amber, no inline
# text. It still compiles to the same call it always did.
#
# The only place the sheet mentions it at all is the strip along the bottom, once the row is
# selected, where it reads muted and offers no door: following a forwarding address is an edit
# somebody approves from the head band, not a button under one row.
@tool
extends RefCounted

const PREVIEW_NAME: String = "successor-row-strip"
const PREVIEW_SIZE: Vector2i = Vector2i(1700, 900)


static func build(host: Window) -> Control:
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.custom_class_name = "Sentry"
	sheet.host_class = "CharacterBody2D"
	# The file's own opening lines, so the head band stack builds: the head is one band per line
	# of the file, and the migration band joins it as the one line that is derived instead.
	sheet.events.append(_raw("\n".join(PackedStringArray(["class_name Sentry", "extends CharacterBody2D"]))))
	sheet.events.append(_event("OnBodyEntered", [_go_to_state("\"chasing\"")]))
	sheet.events.append(_event("OnReady", [_raw("velocity = Vector2.ZERO")]))
	dock.setup(sheet)
	dock.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(dock)
	# Select the older-spelling row, which is what makes the strip speak: the words are nowhere in
	# the sheet, and there is nothing in the row that would have led a reader to look.
	for row_data: EventRowData in dock._viewport._root_rows:
		if not row_data.successor_hint.is_empty():
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


## The superseded verb, exactly as a sheet written before the newer family existed holds it.
static func _go_to_state(state: String) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "StateMachineBehavior"
	action.ace_id = "method:set_state"
	action.params = {"target": "$StateMachineBehavior", "next": state}
	return action


static func _raw(code: String) -> RawCodeRow:
	var raw: RawCodeRow = RawCodeRow.new()
	raw.code = code
	return raw
