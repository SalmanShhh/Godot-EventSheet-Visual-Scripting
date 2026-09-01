# Godot EventSheets - the one line an older sheet's head grows (preview module).
#
# Rendered by tools/render_previews.gd, which owns the window and the shutter; this owns the picture.
# Three of this sheet's events are written in a spelling the vocabulary has since replaced, and the
# whole of what the sheet says about that is the band at the top: one counting line, derived from the
# rows themselves. The project's own one-line record supplies the second half of it - "since 0.14.0"
# - and a project that has never carried the record gets the same band without the version.
#
# The rows underneath are the point of the picture as much as the band is: not one of them is marked,
# tinted, badged or annotated. A sheet written five versions ago looks exactly like a sheet written
# this morning, because it still compiles to exactly the same code.
@tool
extends RefCounted

const PREVIEW_NAME: String = "migration-head-band"
const PREVIEW_SIZE: Vector2i = Vector2i(1700, 640)

## The version the picture is taken under, written for the length of the run and put back after, so
# taking a preview never leaves a record behind in this repo's own project file.
const RECORDED_VERSION: String = "0.14.0"


static func build(host: Window) -> Control:
	var restore: Variant = ProjectSettings.get_setting(EventForgeVocabularyRecord.SETTING, "")
	ProjectSettings.set_setting(EventForgeVocabularyRecord.SETTING, RECORDED_VERSION)
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.custom_class_name = "Sentry"
	sheet.host_class = "CharacterBody2D"
	# The file's own opening lines, so the head band stack builds: the head is one band per line
	# of the file, and the migration band joins it as the one line that is derived instead.
	sheet.events.append(_raw("\n".join(PackedStringArray(["class_name Sentry", "extends CharacterBody2D"]))))
	sheet.events.append(_event("OnReady", [_go_to_state("\"patrolling\"")]))
	sheet.events.append(_event("OnBodyEntered", [_go_to_state("\"chasing\"")]))
	sheet.events.append(_event("OnProcess", [_go_to_state("\"searching\"")]))
	sheet.events.append(_event("OnExitTree", [_raw("queue_free()")]))
	dock.setup(sheet)
	dock.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(dock)
	ProjectSettings.set_setting(EventForgeVocabularyRecord.SETTING, restore)
	return dock


static func _event(trigger_id: String, actions: Array) -> EventRow:
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = trigger_id
	for action: Variant in actions:
		event.actions.append(action)
	return event


## The superseded verb, exactly as a sheet written before the newer family existed holds it.
static func _go_to_state(state: String) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "StateMachineBehavior"
	action.ace_id = "method:set_state"
	action.params = {"target": "$StateMachineBehavior", "next": state}
	return action


static func _raw(code: String) -> RawCodeRow:
	var raw: RawCodeRow = RawCodeRow.new()
	raw.code = code
	return raw
