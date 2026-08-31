# Godot EventSheets - one object's states, declared once and read everywhere (preview module).
#
# Rendered by tools/render_previews.gd, which owns the window and the shutter; this owns the picture.
# The sheet is built the way the Declare states dialog builds one - through the dialog's own writer,
# so nothing in the picture was arranged for it: the band is read from the enum the dialog wrote, and
# the rows are the shipped vocabulary.
@tool
extends RefCounted

const PREVIEW_NAME: String = "object-states"
const PREVIEW_SIZE: Vector2i = Vector2i(1600, 900)


## Where the built object is written and read back from. The picture is of an OPENED file rather than
## of a sheet held in memory, because that is what a reader sees: the head bands are read off the
## lines of a script, and an object's sheet is a script like any other.
const OBJECT_PATH: String = "user://__eventsheets_states_preview.gd"


static func build(host: Window) -> Control:
	var authored: EventSheetResource = EventSheetResource.new()
	authored.host_class = "CharacterBody2D"
	authored.custom_class_name = "Sentry"
	EventSheetStatesDialog.write(authored,
		PackedStringArray(["Patrol", "Chase", "Stagger"]), "Patrol")

	# The four rows a reader meets first: asking, going, the timed question, and the moment.
	authored.events.append(_row("OnProcess", "InState", {"state": "PATROL"}, true))
	authored.events.append(_row("OnProcess", "GoToState", {"state": "CHASE"}, false))
	authored.events.append(_row("OnProcess", "InStateForOver",
		{"state": "STAGGER", "seconds": "1.0"}, true))
	authored.events.append(_row(EventSheetStateFacts.LEAVING_TRIGGER_ID, "", {}, false,
		{"state": "CHASE"}))

	var file: FileAccess = FileAccess.open(OBJECT_PATH, FileAccess.WRITE)
	file.store_string(str(SheetCompiler.compile(authored, OBJECT_PATH).get("output", "")))
	file.close()
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(OBJECT_PATH)
	var style: EventSheetEditorStyle = EventSheetEditorStyle.new()
	style.ensure_defaults()
	sheet.editor_style = style

	var viewport: EventSheetViewport = EventSheetViewport.new()
	viewport.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport.set_ace_registry(EventSheetACERegistry.new())
	viewport.set_sheet(sheet)
	host.add_child(viewport)
	return viewport


static func _row(trigger_id: String, ace_id: String, params: Dictionary, as_condition: bool,
		trigger_params: Dictionary = {}) -> EventRow:
	var row: EventRow = EventRow.new()
	row.trigger_id = trigger_id
	row.trigger_params = trigger_params
	if ace_id.is_empty():
		return row
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", ace_id)
	if as_condition:
		var condition: ACECondition = ACECondition.new()
		condition.provider_id = "Core"
		condition.ace_id = ace_id
		condition.params = params
		if descriptor != null:
			condition.codegen_template = descriptor.codegen_template
		row.conditions.append(condition)
		return row
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = ace_id
	action.params = params
	if descriptor != null:
		action.codegen_template = descriptor.codegen_template
	row.actions.append(action)
	return row
