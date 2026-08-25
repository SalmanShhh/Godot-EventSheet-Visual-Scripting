# Godot EventSheets - the effect packs on a sheet (preview module).
#
# Rendered by tools/render_previews.gd, which owns the window and the shutter; this owns the picture.
# The boss wears the material an effect pack copied into the project when it was added, so the head
# grows its `effect` band with no help from the sheet, and the rows under each moment are the packs'
# own one-word verbs beside a dial row the shader named. Everything in the picture was read: nothing
# on the head was authored, and every row came back out of the file.
@tool
extends RefCounted

const PREVIEW_NAME: String = "effect-pack-rows"
const PREVIEW_SIZE: Vector2i = Vector2i(1440, 460)

const FIXTURE: String = "res://tests/fixtures/effect_pack_boss.gd"

## The two calls in the fixture, and the pack rows the picker makes for them: method name -> the
## provider and the row id it belongs to, with the parameters that row carries.
const PICKED_ROWS: Dictionary = {
	"dissolve": {"provider": "DissolveBehavior", "id": "method:dissolve",
		"params": {"target": "$DissolveBehavior", "seconds": "0.8"}},
	"flash": {"provider": "HitFlashBehavior", "id": "method:flash",
		"params": {"target": "$HitFlashBehavior", "colour": "Color.WHITE", "seconds": "0.2"}},
}


static func build(host: Window) -> Control:
	# "Who else wears this file" is a question about every scene in the project, and the editor
	# answers it a slice per idle frame. A picture has no frames to wait through, so the scan is
	# finished here - which is what the Doctor does, and gets the same answer.
	EventSheetProjectShareIndex.clear_cache()
	EventSheetProjectShareIndex.build_now()
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(FIXTURE)
	_as_picked_rows(sheet)
	sheet.read_only = true
	var style: EventSheetEditorStyle = EventSheetEditorStyle.new()
	style.ensure_defaults()
	sheet.editor_style = style
	var viewport: EventSheetViewport = EventSheetViewport.new()
	viewport.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport.set_ace_registry(_registry_with_the_packs())
	viewport.set_sheet(sheet)
	viewport.set_reading_mode(true)
	host.add_child(viewport)
	return viewport


## Puts the picker's own rows where the file's Call rows are. A hand-written `$DissolveBehavior
## .dissolve(0.8)` opens as the Object-Verb call row that EVERY pack's calls open as, which is a true
## picture of a different thing. This picture is about the row the picker makes, so the two calls are
## swapped for the pack rows they stand for and everything around them stays exactly as it was read.
static func _as_picked_rows(sheet: EventSheetResource) -> void:
	for row: Variant in sheet.events:
		if not (row is EventRow):
			continue
		var event: EventRow = row as EventRow
		for index: int in event.actions.size():
			var action: Variant = event.actions[index]
			if not (action is ACEAction) or (action as ACEAction).ace_id != "CallMethod":
				continue
			var picked: Dictionary = PICKED_ROWS.get(
				str((action as ACEAction).params.get("method", "")), {})
			if picked.is_empty():
				continue
			var replacement: ACEAction = ACEAction.new()
			replacement.provider_id = str(picked["provider"])
			replacement.ace_id = str(picked["id"])
			replacement.params = (picked["params"] as Dictionary).duplicate()
			event.actions[index] = replacement


## A registry that knows the two packs, built the way the dock builds its own: from instances of the
## provider scripts, with the built-in vocabulary alongside them. Without this the rows fall back to
## the plain "Verb (args)" reading, and the picture would say nothing about the sentences the packs
## ship. Freed straight after, because the definitions are what the registry keeps.
static func _registry_with_the_packs() -> EventSheetACERegistry:
	var sources: Array[Object] = []
	for path: String in ["res://eventsheet_addons/dissolve/dissolve_behavior.gd",
			"res://eventsheet_addons/hit_flash/hit_flash_behavior.gd"]:
		sources.append((load(path) as GDScript).new())
	var registry: EventSheetACERegistry = EventSheetACERegistry.new()
	registry.refresh_from_sources(sources, true)
	for source: Object in sources:
		if source is Node:
			(source as Node).free()
	return registry
