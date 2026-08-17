# EventForge - render harness (dev tool) for the Event Trace's two reading lenses. Produces:
#
#   docs/images/hit-counts-off.png    the sheet with the lens OFF - the default everyone reads
#   docs/images/hit-counts-on.png     the SAME sheet with View > Row Hit Counts ticked
#   docs/images/why-didnt-fire.png    the "Why didn't this fire?" panel for one row
#
# The first two images exist to be compared: they are shot from one sheet, one viewport and one
# size, so the only difference between them is the gutter. That comparison is the feature's whole
# contract - debugger information is a lens, and with it off the sheet must be pixel-identical to
# a sheet built before the lens existed. Nothing headless can prove that; only these two files can.
#
# Run NON-headless (headless cannot render):
#   godot --path . --script tools/render_editor_seams_preview.gd
@tool
extends SceneTree

## The fake run the images are taken of: a per-frame row that fired constantly (hot), a trigger
## row that never fired at all (the x0 + rail case), and a middling row in between.
const HOT_UID := "evt_hot"
const COLD_UID := "evt_cold"
const WARM_UID := "evt_warm"

var _frames: int = 0
var _stage: int = 0
var _viewport: EventSheetViewport = null


func _init() -> void:
	root.title = "EventForge editor seams - hit counts and why"
	root.size = Vector2i(1100, 260)
	root.gui_embed_subwindows = true
	var background: ColorRect = ColorRect.new()
	background.color = Color("#1e1f24")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)
	_viewport = EventSheetViewport.new()
	_viewport.position = Vector2(8, 8)
	_viewport.size = Vector2(1084, 244)
	_viewport.set_ace_registry(EventSheetACERegistry.new())
	root.add_child(_viewport)
	_viewport.set_sheet(_demo_sheet())
	# The run the gutter reports on, staged exactly as the debugger bridge would deliver it: one
	# streamed window carrying an entry per fire, repeats included.
	EventSheetTraceHitCounts.reset()
	var window: PackedStringArray = PackedStringArray()
	for index: int in range(1431):
		window.append(HOT_UID)
	for index: int in range(3):
		window.append(WARM_UID)
	EventSheetTraceHitCounts.note_fired(window)
	process_frame.connect(_on_frame)


func _demo_sheet() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.events.append(_event(HOT_UID, "OnProcess", "\"move by speed * delta\""))
	sheet.events.append(_event(COLD_UID, "OnReady", "\"add 1 to score\""))
	sheet.events.append(_event(WARM_UID, "OnProcess", "\"take damage 5\""))
	return sheet


func _event(uid: String, trigger_id: String, message: String) -> EventRow:
	var row: EventRow = EventRow.new()
	row.event_uid = uid
	row.trigger_provider_id = "Core"
	row.trigger_id = trigger_id
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "Print"
	action.codegen_template = "print({message})"
	action.params = {"message": message}
	row.actions.append(action)
	return row


## The panel for a row whose second condition is the one saying no, against a values frame the
## Live Values stream would be carrying.
func _why_row() -> EventRow:
	var row: EventRow = EventRow.new()
	row.conditions.append(_condition("CompareVar", {"var_name": "score", "op": ">=", "value": "100"}))
	row.conditions.append(_condition("CompareVar", {"var_name": "cooldown", "op": "<=", "value": "0.0"}))
	# A condition that reads the NODE: the panel must say it cannot see it rather than guess.
	row.conditions.append(_condition("IsOnFloor", {}))
	return row


## A real builtin condition, so the panel's labels are the sentences the rows actually show.
func _condition(ace_id: String, params: Dictionary) -> ACECondition:
	var condition: ACECondition = ACECondition.new()
	condition.provider_id = "Core"
	condition.ace_id = ace_id
	condition.params = params
	return condition


func _on_frame() -> void:
	_frames += 1
	if _frames < 4:
		return
	_frames = 0
	match _stage:
		0:
			_save("hit-counts-off")
			_viewport.show_hit_counts = true
			_viewport.queue_redraw()
		1:
			_save("hit-counts-on")
			_viewport.hide()
			# The window's own chrome, minus the Window: a plugin inset card on the sheet
			# background, which is what the panel sits in inside the editor.
			var panel: PanelContainer = EventSheetPopupUI.panel_section(EventSheetWhyPanel.build_body(
				EventSheetWhyPanel.build_report(_why_row(), {"score": 142, "cooldown": 0.31}, true), 8))
			panel.position = Vector2(8, 8)
			panel.size = Vector2(600, 244)
			root.add_child(panel)
		2:
			_save("why-didnt-fire")
			quit(0)
	_stage += 1


func _save(name: String) -> void:
	var image: Image = root.get_texture().get_image()
	image.save_png("res://docs/images/%s.png" % name)
	print("[editor_seams_preview] saved docs/images/%s.png (%dx%d)" % [name, image.get_width(), image.get_height()])
	if not name.begins_with("hit-counts"):
		return
	# The margin, four times life size. The chip lives in a 20px gutter, so the full-width shot
	# proves "the cells are untouched" but cannot show what the chip actually says - this crop is
	# the one that gets read when the colours or the stacking are being judged.
	var margin: Image = image.get_region(Rect2i(0, 0, 60, 200))
	margin.resize(240, 800, Image.INTERPOLATE_NEAREST)
	margin.save_png("res://docs/images/%s-margin.png" % name)
	print("[editor_seams_preview] saved docs/images/%s-margin.png" % name)
