# Godot EventSheets - Keep as code, before anybody presses anything (preview module).
#
# Rendered by tools/render_previews.gd, which owns the window and the shutter; this owns the picture.
# The second of the two doors a row with a lost verb offers, drawn as the receipt it is: the row as
# it reads now on the left, the block it becomes on the right, and the comment offered above the kept
# line with the one tick that strikes it out. Nothing has happened yet - the sheet is compiled with
# the block in place and checked against the sheet as it stands before the button writes anything.
@tool
extends RefCounted

const PREVIEW_NAME: String = "migration-keep-as-code"
const PREVIEW_SIZE: Vector2i = Vector2i(900, 520)


static func build(host: Window) -> Node:
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	sheet.external_source_path = "res://lamp.gd"
	sheet.events.append(_event("OnReady", [_gone_action()]))
	dock.setup(sheet)
	host.add_child(dock)
	var found: Array[Dictionary] = EventSheetMigrationFindings.findings(
		dock.get_current_sheet(), "res://lamp.gd",
		func(provider_id: String, ace_id: String) -> bool:
			return ACERegistry.find_descriptor(provider_id, ace_id) != null)
	if found.is_empty():
		return dock
	dock._keep_as_code_dialog.open(found[0])
	return dock._keep_as_code_dialog._dialog


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


static func _event(trigger_id: String, actions: Array) -> EventRow:
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = trigger_id
	for action: Variant in actions:
		event.actions.append(action)
	return event
