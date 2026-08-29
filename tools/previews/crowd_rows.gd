# Godot EventSheets - the cap and its policy, said on the row itself (preview module).
#
# Rendered by tools/render_previews.gd, which owns the window and the shutter; this owns the picture.
# The point of the picture is that "at most N alive" is never a setting hidden behind a row: both
# capped rows carry the number AND what happens when the crowd is already that big, in the sentence
# a reader sees. The count expression underneath reads the same crowd, so the three rows say one
# thing between them.
@tool
extends RefCounted

const PREVIEW_NAME: String = "crowd-rows"
const PREVIEW_SIZE: Vector2i = Vector2i(2400, 110)

## The two crowds the picture uses - one capped by recycling, one capped by refusing.
const MARKS: String = "\"marks\""
const ENEMIES: String = "\"enemies\""


static func build(host: Window) -> Control:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	sheet.events.append(_trail_event())
	sheet.events.append(_wave_event())
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


## The recycling policy: a skid mark every tick, twenty at a time, the oldest making way.
static func _trail_event() -> EventRow:
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnProcess"
	var moving: ACECondition = ACECondition.new()
	moving.provider_id = "Core"
	moving.ace_id = "CompareValues"
	moving.params = {"a": "velocity.length()", "op": ">", "b": "40.0"}
	event.conditions.append(moving)
	event.actions.append(_action("SpawnIntoCrowdOldestFirst", {
		"scene": "Mark",
		"name": "new_mark",
		"crowd": MARKS,
		"cap": "20",
		"at": "global_position",
		"parent": "$Marks",
	}))
	return event


## The refusing policy, with the count beside it so the reader can see what the cap is counting.
static func _wave_event() -> EventRow:
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnTimeout"
	event.trigger_source_path = "SpawnTimer"
	event.actions.append(_action("SpawnIntoCrowdUnlessFull", {
		"scene": "Enemy",
		"name": "new_enemy",
		"crowd": ENEMIES,
		"cap": "12",
		"at": "global_position",
		"parent": "$Enemies",
	}))
	event.actions.append(_action("SetProperty", {
		"target": "$HUD/Remaining",
		"property": "text",
		"value": "str(get_tree().get_node_count_in_group(\"enemies\"))",
	}))
	return event


static func _action(ace_id: String, params: Dictionary) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = ace_id
	action.params = params.duplicate()
	return action
