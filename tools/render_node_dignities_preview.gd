# EventForge - render harness (dev tool) for the three small node dignities: the owner a node is
# written out as part of, the copy with its three questions asked out loud, and the reparent that
# says which of the two things should happen to where the node is. Each one is drawn NEXT TO the
# frozen row it stands beside, because the whole point of the three is the difference - and the
# GDScript echo below shows that the difference is one honest argument, not a wrapper.
#
# Run NON-headless (a headless run cannot render):
#   godot --path . --script tools/render_node_dignities_preview.gd
@tool
extends SceneTree

const OUTPUT_PATH: String = "res://docs/images/node-dignities.png"

var _frames: int = 0
var _viewport: EventSheetViewport = null


func _init() -> void:
	root.title = "Owner, copy, reparent - said out loud"
	root.size = Vector2i(1152, 648)
	var base := Color("#252525")
	var background: ColorRect = ColorRect.new()
	background.color = base.darkened(0.25)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)

	var columns: VBoxContainer = VBoxContainer.new()
	columns.position = Vector2(8, 8)
	columns.size = Vector2(1136, 632)
	columns.add_theme_constant_override("separation", 6)
	root.add_child(columns)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(1136, 400)
	columns.add_child(scroll)
	_viewport = EventSheetViewport.new()
	_viewport.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_viewport.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_viewport.set_ace_registry(EventSheetACERegistry.new())
	scroll.add_child(_viewport)

	var sheet: EventSheetResource = _dignities_sheet(base)
	_viewport.set_sheet(sheet)

	var code: CodeEdit = CodeEdit.new()
	code.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	code.size_flags_vertical = Control.SIZE_EXPAND_FILL
	code.editable = false
	code.text = _compiled_text(sheet)
	columns.add_child(code)
	process_frame.connect(_on_frame)


## Three pairs, one per event: the frozen row first, the row that says which second. Read down the
## left column and the difference is the whole story - the same call with the answer written in.
func _dignities_sheet(base: Color) -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	var style := EventSheetEditorStyle.new()
	style.ensure_defaults()
	EventSheetGodotTheme.apply(style, base, base.darkened(0.15), base.darkened(0.25),
		Color("#569eff"), Color("#ced0d2"))
	sheet.editor_style = style

	var owning: EventRow = EventRow.new()
	owning.trigger_provider_id = "Core"
	owning.trigger_id = "OnReady"
	owning.actions.append(_action("SetSceneOwner",
		{"target": "$Level/Crate", "root": "$Level"}, "d1"))
	sheet.events.append(owning)

	var copying: EventRow = EventRow.new()
	copying.trigger_provider_id = "Core"
	copying.trigger_id = "OnReady"
	copying.actions.append(_action("AddChild",
		{"node": "$Level/Crate.duplicate()"}, "d2"))
	copying.actions.append(_action("AddChild", {"node":
		"$Level/Crate.duplicate(Node.DUPLICATE_SIGNALS * int(false)"
			+ " | Node.DUPLICATE_GROUPS * int(true)"
			+ " | Node.DUPLICATE_SCRIPTS * int(true))"}, "d3"))
	sheet.events.append(copying)

	var moving: EventRow = EventRow.new()
	moving.trigger_provider_id = "Core"
	moving.trigger_id = "OnReady"
	moving.actions.append(_action("ReparentNode", {"new_parent": "$Level"}, "d4"))
	moving.actions.append(_action("ReparentToChoosing",
		{"new_parent": "$Player/Hand", "keep": "false"}, "d5"))
	sheet.events.append(moving)
	return sheet


## `uid` bakes the per-row id a template declaring locals needs - the dock does this at apply time,
## so a preview that skipped it would draw a row no sheet ever holds.
func _action(ace_id: String, params: Dictionary, uid: String) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = ace_id
	action.params = params
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", ace_id)
	if descriptor != null:
		action.codegen_template = descriptor.codegen_template.replace("{uid}", uid)
	return action


func _compiled_text(sheet: EventSheetResource) -> String:
	sheet.external_source_path = "user://_dignities_preview.gd"
	var output: String = str(SheetCompiler.compile(sheet, sheet.external_source_path).get("output", ""))
	sheet.external_source_path = ""
	return output.strip_edges()


func _on_frame() -> void:
	_frames += 1
	if _frames < 8:
		return
	var image: Image = root.get_texture().get_image()
	image.save_png(OUTPUT_PATH)
	print("[preview] node dignities %dx%d" % [image.get_width(), image.get_height()])
	quit(0)
