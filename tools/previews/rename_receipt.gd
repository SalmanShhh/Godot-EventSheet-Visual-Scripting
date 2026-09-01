# Godot EventSheets - Rename, before anybody presses anything (preview module).
#
# Rendered by tools/render_previews.gd, which owns the window and the shutter; this owns the picture.
# The whole promise in one frame: the field with the new name in it, and under it the two lists that
# make a rename readable. What will be rewritten - every row of this sheet that says the name, as the
# words it says now beside the words it would say. And what is named and left exactly as it is -
# the other files that call it, with the reason on the heading rather than repeated on every line.
# Nothing has happened yet; the button behind these lists is the only place it does.
@tool
extends RefCounted

const PREVIEW_NAME: String = "rename-receipt"
const PREVIEW_SIZE: Vector2i = Vector2i(900, 560)

## The rename the picture acts out.
const OLD_NAME: String = "sound_alarm"
const NEW_NAME: String = "ring_alarm"


static func build(host: Window) -> Node:
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	sheet.external_source_path = "res://guard.gd"
	var published: EventFunction = EventFunction.new()
	published.function_name = OLD_NAME
	sheet.functions.append(published)
	sheet.events.append(_event("OnReady", [_call(OLD_NAME)]))
	sheet.events.append(_event("OnProcess", [_call(OLD_NAME)]))
	dock.setup(sheet)
	host.add_child(dock)
	dock._rename_receipt.open(OLD_NAME)
	# The receipt is drawn for whatever is typed, so the picture is taken with the new name in the
	# field - which is the moment a reader is actually deciding.
	dock._rename_receipt._name_edit.text = NEW_NAME
	# The other files, staged rather than scanned: the walk imports every project script that
	# mentions the word, and a preview must photograph the words rather than this repository.
	dock._rename_receipt._elsewhere = [
		{"path": "res://enemies/enemy.gd", "count": 4},
		{"path": "res://traps/traps.gd", "count": 2},
	]
	dock._rename_receipt._fill()
	return dock._rename_receipt._dialog


## One row calling the function by name - the surface a rename actually moves.
static func _call(function_name: String) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = EventSheetRenameFindings.CALL_PROVIDER
	action.ace_id = EventSheetRenameFindings.CALL_ACE
	action.codegen_template = "{function_name}({args})"
	action.params = {"function_name": function_name, "args": ""}
	return action


static func _event(trigger_id: String, actions: Array) -> EventRow:
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = trigger_id
	for action: Variant in actions:
		event.actions.append(action)
	return event
