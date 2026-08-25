# Godot EventSheets - the game's modes, declared once and read everywhere (preview module).
#
# Rendered by tools/render_previews.gd, which owns the window and the shutter; this owns the picture.
# The sheet is built the way the Edit modes dialog builds one - through the dialog's own writer, so
# nothing in the picture was arranged for it: the band is read from the enum, the group's muted word
# is its own answer, and the rows are the shipped vocabulary.
@tool
extends RefCounted

const PREVIEW_NAME: String = "game-modes"
const PREVIEW_SIZE: Vector2i = Vector2i(1600, 900)


## Where the built spine is written and read back from. The picture is of an OPENED file rather than
## of a sheet held in memory, because that is what a reader sees: the head bands are read off the
## lines of a script, and a Game sheet is a script like any other.
const SPINE_PATH: String = "user://__eventsheets_modes_preview.gd"


static func build(host: Window) -> Control:
	var authored: EventSheetResource = EventSheetResource.new()
	authored.host_class = "Node"
	authored.custom_class_name = "Game"
	EventSheetModesDialog.write(authored, PackedStringArray(["Playing", "Paused", "Cutscene", "Menu"]),
		"Menu", {})

	# A group that runs in one mode, and the two rows that move the game between them.
	var group: EventGroup = EventGroup.new()
	group.name = "Movement"
	group.group_name = "Movement"
	group.description = "Everything the player steers."
	group.runs_in = "Playing"
	group.events.append(_row("OnProcess", "InMode", "PLAYING", true))
	authored.events.append(group)
	authored.events.append(_row("OnReady", "GoToMode", "CUTSCENE", false))

	var file: FileAccess = FileAccess.open(SPINE_PATH, FileAccess.WRITE)
	file.store_string(str(SheetCompiler.compile(authored, SPINE_PATH).get("output", "")))
	file.close()
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(SPINE_PATH)
	var style: EventSheetEditorStyle = EventSheetEditorStyle.new()
	style.ensure_defaults()
	sheet.editor_style = style

	var viewport: EventSheetViewport = EventSheetViewport.new()
	viewport.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport.set_ace_registry(EventSheetACERegistry.new())
	viewport.set_sheet(sheet)
	host.add_child(viewport)
	return viewport


static func _row(trigger_id: String, ace_id: String, member: String, as_condition: bool) -> EventRow:
	var row: EventRow = EventRow.new()
	row.trigger_id = trigger_id
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", ace_id)
	if as_condition:
		var condition: ACECondition = ACECondition.new()
		condition.provider_id = "Core"
		condition.ace_id = ace_id
		condition.params = {EventSheetModeFacts.MODE_PARAM: member}
		if descriptor != null:
			condition.codegen_template = descriptor.codegen_template
		row.conditions.append(condition)
		return row
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = ace_id
	action.params = {EventSheetModeFacts.MODE_PARAM: member}
	if descriptor != null:
		action.codegen_template = descriptor.codegen_template
	row.actions.append(action)
	return row
