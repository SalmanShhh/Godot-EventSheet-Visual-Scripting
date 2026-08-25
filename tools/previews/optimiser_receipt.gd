# Godot EventSheets - the optimiser's finding and its receipt, under the rows (preview module).
#
# Rendered by tools/render_previews.gd, which owns the window and the shutter; this owns the picture.
# Both notes are read, not written for the picture: the finding comes out of the rows themselves, and
# the receipt out of two profiled runs handed to the same store the editor writes.
@tool
extends RefCounted

const PREVIEW_NAME: String = "optimiser-receipt"
const PREVIEW_SIZE: Vector2i = Vector2i(1500, 340)

## Where the pretend sheet lives, so the receipt store has something to key on.
const SHEET_PATH: String = "res://previewed_sheet.gd"


static func build(host: Window) -> Control:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	sheet.external_source_path = SHEET_PATH
	var style: EventSheetEditorStyle = EventSheetEditorStyle.new()
	style.ensure_defaults()
	sheet.editor_style = style
	# One row still to fix, and one already fixed - the before and the after of the whole feature.
	var scanning: EventRow = _row("OnProcess", "NearestInGroup", {"group": "\"coins\""})
	var fixed: EventRow = _row("OnProcess", "SetLabelText", {"value": "score"})
	sheet.events.append(scanning)
	sheet.events.append(fixed)

	# Two runs: the one the fix was made against, and the one that came after it.
	EventSheetRunProfile.forget()
	EventSheetOptimiserReceipts.forget_all_for_test()
	EventSheetRunProfile.adopt_run_for_test(fixed.event_uid, 400, 400, 960000, "before")
	EventSheetOptimiserReceipts.note_fix(SHEET_PATH, fixed.event_uid,
		EventSheetPerformanceFindings.KIND_CONSTANT_LOOKUP)
	EventSheetRunProfile.adopt_run_for_test(fixed.event_uid, 400, 400, 120000, "after")

	var viewport: EventSheetViewport = EventSheetViewport.new()
	viewport.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport.set_ace_registry(EventSheetACERegistry.new())
	viewport.show_costs = true
	viewport.set_sheet(sheet)
	host.add_child(viewport)
	return viewport


static func _row(trigger_id: String, ace_id: String, params: Dictionary) -> EventRow:
	var row: EventRow = EventRow.new()
	row.trigger_id = trigger_id
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = ace_id
	action.params = params
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", ace_id)
	if descriptor != null:
		action.codegen_template = descriptor.codegen_template
	row.actions.append(action)
	return row
