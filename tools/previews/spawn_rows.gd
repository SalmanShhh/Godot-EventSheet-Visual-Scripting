# Godot EventSheets - a spawn and the rows that use the name it left behind (preview module).
#
# Rendered by tools/render_previews.gd, which owns the window and the shutter; this owns the picture.
# The point of the picture is the second and third rows: they say `new_enemy`, which is the name the
# spawn row above them gave the copy. Nothing looks it up - the spawn row wrote
# `var new_enemy = …` into the emitted code, so by the time those rows run the name is simply what
# the code says.
@tool
extends RefCounted

const PREVIEW_NAME: String = "spawn-rows"
const PREVIEW_SIZE: Vector2i = Vector2i(1780, 170)

## The name the spawn row gives the copy, and the name the rows after it say.
const CHIP: String = "new_enemy"


static func build(host: Window) -> Control:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
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


## One wave: spawn a copy at a marker, then tag it and dim it - both by the name the spawn gave it.
static func _wave_event() -> EventRow:
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnProcess"
	var due: ACECondition = ACECondition.new()
	due.provider_id = "Core"
	due.ace_id = "CompareValues"
	due.params = {"a": "spawn_timer", "op": "<=", "b": "0.0"}
	event.conditions.append(due)
	event.actions.append(_action("SpawnNewCopy", {
		"scene": "Enemy",
		"name": CHIP,
		"at": "$SpawnPoint.global_position",
		"parent": "$Enemies",
	}))
	event.actions.append(_action("AddToGroup", {"target": CHIP, "group": "\"enemies\""}))
	event.actions.append(_action("SetProperty", {
		"target": CHIP, "property": "modulate", "value": "Color(1, 0.8, 0.8)"
	}))
	return event


static func _action(ace_id: String, params: Dictionary) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = ace_id
	action.params = params.duplicate()
	return action
