# Godot EventSheets - a row renamed out from under, selected (preview module).
#
# Rendered by tools/render_previews.gd, which owns the window and the shutter; this owns the picture.
# The whole state in one frame: the row still says exactly what it always said and still compiles to
# the call it always compiled to, and all the sheet says about it is the quiet amber. The words are
# in the help strip under the selected row - which name went out of which file, what arrived beside
# it in that same save, and the one door that follows from the evidence. The event under it, calling
# a function this sheet still declares, is exactly as it always was.
@tool
extends RefCounted

const PREVIEW_NAME: String = "rename-outside-row"
const PREVIEW_SIZE: Vector2i = Vector2i(1700, 900)

## The rename that happened somewhere else, and the name that arrived in its place.
const OLD_NAME: String = "sound_alarm"
const NEW_NAME: String = "ring_alarm"
## The function this sheet still declares, so the picture shows the amber against the ordinary.
const KEPT_NAME: String = "open_gate"


static func build(host: Window) -> Control:
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.custom_class_name = "Guard"
	sheet.host_class = "Node2D"
	sheet.external_source_path = "res://guard.gd"
	# The file's own opening lines, so the head band stack builds: the head is one band per line of
	# the file, and a rename adds no band to it at all.
	sheet.events.append(_raw("\n".join(PackedStringArray(["class_name Guard", "extends Node2D"]))))
	sheet.events.append(_event("OnReady", [_call(OLD_NAME)]))
	sheet.events.append(_event("OnProcess", [_call(KEPT_NAME)]))
	var kept: EventFunction = EventFunction.new()
	kept.function_name = KEPT_NAME
	sheet.functions.append(kept)
	dock.setup(sheet)
	dock.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(dock)
	# The witness, staged rather than watched: the evidence is a file saved under a running editor,
	# and a preview photographs the words rather than waiting for somebody to save something.
	var found: Array[Dictionary] = EventSheetRenameFindings.findings(dock.get_current_sheet(),
		"res://guard.gd", {
			"names_gone": PackedStringArray([OLD_NAME]),
			"names_arrived": PackedStringArray([NEW_NAME]),
		})
	if found.is_empty():
		return dock
	# Put the finding on the row the way the canvas does, then select it - which is what makes the
	# strip speak, because the words are nowhere in the sheet.
	for row_data: EventRowData in dock._viewport._root_rows:
		if row_data.source_resource != found[0].get("event"):
			continue
		row_data.attention_findings = [found[0]]
		row_data.attention_note = str(found[0].get("message", ""))
		row_data.selected = true
		dock._update_row_help_strip(row_data)
	return dock


## One row calling a function by name - the surface an outside rename actually breaks.
static func _call(function_name: String) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = EventSheetRenameFindings.CALL_PROVIDER
	action.ace_id = EventSheetRenameFindings.CALL_ACE
	action.codegen_template = "{function_name}({args})"
	action.params = {"function_name": function_name, "args": ""}
	return action


static func _raw(code: String) -> RawCodeRow:
	var raw: RawCodeRow = RawCodeRow.new()
	raw.code = code
	return raw


static func _event(trigger_id: String, actions: Array) -> EventRow:
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = trigger_id
	for action: Variant in actions:
		event.actions.append(action)
	return event
