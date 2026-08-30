# Godot EventSheets - a spawning finding as the quiet amber state (preview).
#
# Rendered by tools/render_previews.gd, which owns the window and the shutter; this owns the picture.
# The point of the picture is where the sentence does NOT live: the rows with the problems wear the
# quiet amber state and nothing else changes in the sheet. The words and the one-click repair wait
# in the Doctor's inbox and in the help strip under the row once it is selected.
#
# Two of the four are shown together because they are the two a spawning sheet earns first: a node
# parented inside a collision callback, which Godot refuses outright, and a wait booked against
# something an earlier row in the same event destroyed.
@tool
extends RefCounted

const PREVIEW_NAME: String = "spawning-quiet-sheet"
const PREVIEW_SIZE: Vector2i = Vector2i(2000, 280)

const ENEMY: String = "Shard"


static func build(host: Window) -> Control:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Area2D"
	sheet.events.append(_collision_event())
	sheet.events.append(_booked_event())
	sheet.read_only = false
	var style: EventSheetEditorStyle = EventSheetEditorStyle.new()
	style.ensure_defaults()
	sheet.editor_style = style
	var viewport: EventSheetViewport = EventSheetViewport.new()
	viewport.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport.set_ace_registry(EventSheetACERegistry.new())
	viewport.set_sheet(sheet)
	viewport.set_reading_mode(false)
	host.add_child(viewport)
	return viewport


## The spawn row Godot refuses: a copy parented while the physics server is still flushing the very
## query that raised this callback. The repair swaps it for the deferred row standing beside it.
static func _collision_event() -> EventRow:
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnBodyEntered"
	event.actions.append(_action("SpawnNewCopy", {
		"scene": ENEMY, "name": "new_shard", "at": "global_position", "parent": "self",
	}))
	return event


## The order that does not work: the destroy is marked at once, and the wait below it is then booked
## against something on its way out of the world.
static func _booked_event() -> EventRow:
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnTimeout"
	event.trigger_source_path = "PrizeTimer"
	event.actions.append(_action("SpawnNewCopy", {
		"scene": ENEMY, "name": "new_prize", "at": "global_position", "parent": "self",
	}))
	event.actions.append(_action("DestroyNow", {"object": "new_prize"}))
	event.actions.append(_action("DestroyAfterSeconds", {"object": "new_prize", "seconds": "2.0"}))
	return event


static func _action(ace_id: String, params: Dictionary) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = ace_id
	action.params = params.duplicate()
	return action
