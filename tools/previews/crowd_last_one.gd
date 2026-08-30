# Godot EventSheets - the gate under On The Last One Destroyed, as a row anyone can see (preview).
#
# Rendered by tools/render_previews.gd, which owns the window and the shutter; this owns the picture.
# The point of the picture is the SECOND line of the event. The trigger is the scene tree's own
# node-removed signal, which fires for every node anywhere in the game; the question that narrows it
# to one crowd emptying is an ordinary condition row, added when the trigger is picked. It is not a
# wrapper the compiler writes behind the row - it is in the sheet, editable and deletable, and it is
# the `if` the emitted handler holds.
@tool
extends RefCounted

const PREVIEW_NAME: String = "crowd-last-one"
const PREVIEW_SIZE: Vector2i = Vector2i(2000, 90)

## The crowd the wave belongs to, as the row spells it.
const ENEMIES: String = "\"enemies\""

## The gate's own spelling, read off the module so the picture cannot drift from the vocabulary.
const CROWD_ACES := preload("res://addons/eventforge/registration/modules/crowd_aces.gd")


static func build(host: Window) -> Control:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	sheet.events.append(_wave_cleared_event())
	sheet.read_only = true
	var style: EventSheetEditorStyle = EventSheetEditorStyle.new()
	style.ensure_defaults()
	sheet.editor_style = style
	var viewport: EventSheetViewport = EventSheetViewport.new()
	viewport.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport.set_ace_registry(EventSheetACERegistry.new())
	viewport.set_sheet(sheet)
	viewport.set_reading_mode(true)
	host.add_child(viewport)
	return viewport


## The wave being cleared: the trigger, the gate the dock put underneath it, and the reward.
static func _wave_cleared_event() -> EventRow:
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = str(CROWD_ACES.LAST_REMOVED_TRIGGER_ID)
	event.trigger_params = {"crowd": ENEMIES}
	# The trigger as a row carries its own values, which is what lets the sentence name the crowd
	# rather than falling back to the verb on its own.
	var trigger: ACECondition = ACECondition.new()
	trigger.provider_id = "Core"
	trigger.ace_id = str(CROWD_ACES.LAST_REMOVED_TRIGGER_ID)
	trigger.params = {"crowd": ENEMIES}
	event.trigger = trigger
	var gate: ACECondition = ACECondition.new()
	gate.provider_id = "Core"
	gate.ace_id = str(CROWD_ACES.LAST_REMOVED_GATE_ID)
	gate.codegen_template = str(CROWD_ACES.LAST_REMOVED_GATE_TEMPLATE)
	gate.params = {"crowd": ENEMIES, "node": str(CROWD_ACES.REMOVED_NODE_ARGUMENT)}
	event.conditions.append(gate)
	var open_door: ACEAction = ACEAction.new()
	open_door.provider_id = "Core"
	open_door.ace_id = "SetProperty"
	open_door.params = {"target": "$Door", "property": "locked", "value": "false"}
	event.actions.append(open_door)
	var announce: ACEAction = ACEAction.new()
	announce.provider_id = "Core"
	announce.ace_id = "SetProperty"
	announce.params = {"target": "$HUD/Banner", "property": "text", "value": "\"Wave cleared\""}
	event.actions.append(announce)
	return event
