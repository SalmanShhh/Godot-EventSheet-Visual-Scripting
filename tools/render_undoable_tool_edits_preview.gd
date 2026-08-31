# EventForge - render harness (dev tool) for the undoable tool touch: a snap-the-props tool event
# above, and the GDScript it compiles to below, so the create_action / commit_action bracket the
# compiler writes around the whole event can be read as the lines it really is. That bracket is the
# point of the picture - it is what makes three rows ONE Ctrl+Z, and it is not a row anybody picked.
#
# Run NON-headless (a headless run cannot render):
#   godot --path . --script tools/render_undoable_tool_edits_preview.gd
@tool
extends SceneTree

const OUTPUT_PATH: String = "res://docs/images/undoable-tool-edits.png"

var _frames: int = 0
var _viewport: EventSheetViewport = null


func _init() -> void:
	root.title = "Snap the props, undoably"
	root.size = Vector2i(1152, 820)
	var base := Color("#252525")
	var background: ColorRect = ColorRect.new()
	background.color = base.darkened(0.25)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)

	# Sheet above, the GDScript it compiles to below. Stacked rather than side by side because the
	# bracket and the do/undo pairs are the widest lines in the file, and a narrowed half would wrap
	# exactly the lines this picture exists to show.
	var columns: VBoxContainer = VBoxContainer.new()
	columns.position = Vector2(8, 8)
	columns.size = Vector2(1136, 804)
	columns.add_theme_constant_override("separation", 6)
	root.add_child(columns)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(1136, 175)
	columns.add_child(scroll)
	_viewport = EventSheetViewport.new()
	_viewport.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_viewport.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_viewport.set_ace_registry(EventSheetACERegistry.new())
	scroll.add_child(_viewport)

	var sheet: EventSheetResource = _snap_props_sheet(base)
	_viewport.set_sheet(sheet)

	var code: CodeEdit = CodeEdit.new()
	code.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	code.size_flags_vertical = Control.SIZE_EXPAND_FILL
	code.editable = false
	code.text = _compiled_text(sheet)
	columns.add_child(code)
	process_frame.connect(_on_frame)


## The tool a level artist actually presses: snap a prop to the grid, say so, and drop a marker under
## the scene root. Two undoable rows with an ordinary one standing between them, in ONE event - so
## the bracket the compiler writes goes round all three and one Ctrl+Z takes the whole run back.
func _snap_props_sheet(base: Color) -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	sheet.tool_mode = true
	var style := EventSheetEditorStyle.new()
	style.ensure_defaults()
	EventSheetGodotTheme.apply(style, base, base.darkened(0.15), base.darkened(0.25),
		Color("#569eff"), Color("#ced0d2"))
	sheet.editor_style = style

	var snapping: EventRow = EventRow.new()
	snapping.trigger_provider_id = "Core"
	snapping.trigger_id = "OnEditorRun"
	snapping.actions.append(_action("SetPropertyUndoable",
		{"target": "%Crate", "property": "position",
		"value": "Vector2(64, 64)"}, "s1"))
	snapping.actions.append(_action("Print", {"value": "\"Snapped.\""}, "s3"))
	snapping.actions.append(_action("AddNodeUndoable",
		{"node": "Marker2D.new()", "parent": "EditorInterface.get_edited_scene_root()"}, "s4"))
	sheet.events.append(snapping)
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
	sheet.external_source_path = "user://_undoable_preview.gd"
	var output: String = str(SheetCompiler.compile(sheet, sheet.external_source_path).get("output", ""))
	sheet.external_source_path = ""
	return output.strip_edges()


func _on_frame() -> void:
	_frames += 1
	if _frames < 8:
		return
	var image: Image = root.get_texture().get_image()
	image.save_png(OUTPUT_PATH)
	print("[preview] undoable tool edits %dx%d" % [image.get_width(), image.get_height()])
	quit(0)
