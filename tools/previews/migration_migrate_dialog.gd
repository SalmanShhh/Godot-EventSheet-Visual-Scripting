# Godot EventSheets - the migrate receipt, mid-decision (preview module).
#
# Rendered by tools/render_previews.gd, which owns the window and the shutter; this owns the picture.
# The one door out of the head band's counting line, drawn at the moment that matters: two rows that
# would be rewritten - each shown as the sentence it reads today beside the sentence it would read,
# and the line it writes today beside the line it would write - and one that is named and left
# exactly as it is, with the reason. Nothing has happened yet.
#
# THE OLD PACK IS INVENTED, the successor is real. The gate reads a rewritten line back through the
# importer's own reverse grammar, so a made-up successor would draw a picture of something that could
# not actually happen; every verb on the right of an arrow here is one this plugin really ships.
@tool
extends RefCounted

const PREVIEW_NAME: String = "migration-migrate-dialog"
const PREVIEW_SIZE: Vector2i = Vector2i(900, 620)

## The pack whose verbs these sheets were written on, back when it had them.
const OLD_PROVIDER: String = "InputBindings"


static func build(host: Window) -> Node:
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	sheet.external_source_path = "res://options_screen.gd"
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnReady"
	event.actions.append(_old_row("ClearBinding", {"control": "\"jump\""}))
	event.actions.append(_old_row("ClearBinding", {"control": "\"fire\""}))
	event.actions.append(_gone_row())
	sheet.events.append(event)
	dock.setup(sheet)
	host.add_child(dock)
	dock._migrate_dialog.open(_vocabulary())
	return dock._migrate_dialog._dialog


## The vocabulary this receipt is drawn against: everything installed, plus the one verb the sheets
## were written on and the address it carries.
static func _vocabulary() -> Dictionary:
	var known: Dictionary = EventForgeSuccessors.catalog().duplicate()
	known["%s::ClearBinding" % OLD_PROVIDER] = {
		"key": "%s::ClearBinding" % OLD_PROVIDER, "name": "Clear binding",
		"template": "InputMap.action_erase_events({control})",
		"display_template": "Clear the bindings for {control}",
		"needs_baking": false, "ace_type": ACEDefinition.ACEType.ACTION,
		"params": PackedStringArray(["control"]),
		"declared_defaults": {"control": "\"ui_accept\""},
		"answered_by_default": PackedStringArray(["control"]),
		"map": {"id": "Core::ActionEraseEvents", "renames": {"control": "action"}, "defaults": {}},
	}
	return known


## One row on the older spelling, with the code and the reading it was applied with both written onto
## it - which is what lets the receipt quote the sentence a reader actually sees in the sheet.
static func _old_row(ace_id: String, params: Dictionary) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = OLD_PROVIDER
	action.ace_id = ace_id
	action.codegen_template = "InputMap.action_erase_events({control})"
	action.display_text = "Clear the bindings for {control}"
	action.params = params
	return action


## The third row: a verb from a pack this project no longer installs at all. Nothing can carry a
## forwarding address for it, so it is named in the second list and left exactly as written.
static func _gone_row() -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "LightFlicker"
	action.ace_id = "FlickerLight"
	action.codegen_template = "flicker({light}, {amount})"
	action.display_text = "Flicker {light} by {amount}"
	action.params = {"light": "$Lamp", "amount": "0.4"}
	return action
