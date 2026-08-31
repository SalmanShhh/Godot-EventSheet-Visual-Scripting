# Godot EventSheets - the save event a player meets: one trigger, three deeds (preview module).
#
# Rendered by tools/render_previews.gd, which owns the window and the shutter; this owns the picture.
# The point of the picture is that the two new words are EXPRESSIONS sitting inside slots, not rows of
# their own. The first deed names a path: Safe File Name turns whatever the player typed into a name a
# file system takes, and Free File Path moves it off one that is already used. The second deed is the
# write that was always there, pointed at that name. The third opens the player's own file browser on
# it, so they can see where it went.
@tool
extends RefCounted

const PREVIEW_NAME: String = "safe-name-save-event"
const PREVIEW_SIZE: Vector2i = Vector2i(3400, 200)

## The local the first deed names, and the two rows after it say.
const CHIP: String = "save_path"


static func build(host: Window) -> Control:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	sheet.events.append(_save_event())
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


## The player pressed Save: work out a path, write the file, show them where it landed.
static func _save_event() -> EventRow:
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnButtonPressed"
	event.trigger_params = {"button": "$SaveButton"}
	var safe: String = "$NameField.text.validate_filename()" \
		+ " if not $NameField.text.validate_filename().is_empty() else \"untitled\""
	var wanted: String = "\"user://runs/\" + (%s) + \".txt\"" % safe
	event.actions.append(_action("SetLocalVarInferred", {
		"name": CHIP,
		"value": _free_path(wanted),
	}))
	event.actions.append(_action("WriteTextFileInFolder", {
		"path": CHIP, "text": "run_report", "folder": "make its folder first",
	}))
	event.actions.append(_action("ShowInFileManager", {"path": CHIP}))
	return event


## The free-path answer, spelled exactly as the row emits it.
static func _free_path(path_expression: String) -> String:
	return "(func(__wanted: String) -> String: return __wanted" \
		+ " if not FileAccess.file_exists(__wanted) else (range(1, 99 + 1).map(" \
		+ "func(__number: int) -> String: return __wanted.get_basename() + \"_\" + str(__number)" \
		+ " + __wanted.trim_prefix(__wanted.get_basename())).filter(" \
		+ "func(__candidate: String) -> bool: return not FileAccess.file_exists(__candidate))" \
		+ " + [__wanted]).front()).call(" + path_expression + ")"


static func _action(ace_id: String, params: Dictionary) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = ace_id
	action.params = params.duplicate()
	return action
