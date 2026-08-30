# Godot EventSheets - one event whose collision rows say the layer's name (preview module).
#
# Rendered by tools/render_previews.gd, which owns the window and the shutter; this owns the picture.
# The point of the picture is the two action rows: they say "Enemies" and "Player", which are the
# names THIS PROJECT gave layers 2 and 3. Nothing is stored but those numbers - the emitted lines are
# `set_collision_mask_value(2, false)` and `set_collision_layer_value(3, false)` - so renaming a
# layer in Project Settings renames both rows and moves no file.
#
# The picture needs a project that has named its layers, and this repository has not, so the names
# are written IN MEMORY and left there for the rest of this throwaway render process - the rows
# resolve the number to the name when they are DRAWN, which happens after this file has run, so
# putting the names back before the shutter would photograph the numbers. Nothing is saved: the
# write is `set_setting` with no `save()`, so project.godot is untouched either way.
@tool
extends RefCounted

const PREVIEW_NAME: String = "named-layer-rows"
const PREVIEW_SIZE: Vector2i = Vector2i(1500, 100)

## The layer names the picture is taken against.
const SHOWN_NAMES: Array = ["World", "Enemies", "Player"]

## The two layers the rows are about: what the dash stops noticing, and what stops noticing the dash.
const ENEMY_LAYER: String = "2"
const PLAYER_LAYER: String = "3"


static func build(host: Window) -> Control:
	_write_layer_names()
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "CharacterBody2D"
	sheet.events.append(_dash_event())
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


## The dash that goes intangible: while it runs, stop colliding with the enemies and leave the layer
## the enemies are watching. Two familiar rows rather than one compound one.
static func _dash_event() -> EventRow:
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnProcess"
	var dashing: ACECondition = ACECondition.new()
	dashing.provider_id = "Core"
	dashing.ace_id = "CompareValues"
	dashing.params = {"a": "dash_time", "op": ">", "b": "0.0"}
	event.conditions.append(dashing)
	event.actions.append(_action("StopCollidingWithLayer", {"layer": ENEMY_LAYER}))
	event.actions.append(_action("LeaveLayer", {"layer": PLAYER_LAYER}))
	return event


static func _action(ace_id: String, params: Dictionary) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = ace_id
	action.params = params.duplicate()
	return action


## The layer names this picture is taken against, written in memory only.
static func _write_layer_names() -> void:
	for index: int in SHOWN_NAMES.size():
		ProjectSettings.set_setting(EventForgePhysicsLayers.setting_path(index + 1,
			EventForgePhysicsLayers.DIMENSION_2D), str(SHOWN_NAMES[index]))
