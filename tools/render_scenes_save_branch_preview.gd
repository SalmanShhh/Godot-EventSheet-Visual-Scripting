# EventForge - render harness (dev tool) for the two rows a build editor is made of: the branch
# written out as a scene file, and the question asked before it is read back in. The sheet is above
# and the GDScript it compiles to is below, so the owner walk can be read as the lines it really is -
# which is the whole reason the save is a row rather than one call.
#
# Run NON-headless (a headless run cannot render):
#   godot --path . --script tools/render_scenes_save_branch_preview.gd
@tool
extends SceneTree

const OUTPUT_PATH: String = "res://docs/images/scenes-save-branch.png"

var _frames: int = 0
var _viewport: EventSheetViewport = null


func _init() -> void:
	root.title = "Save Branch As Scene File"
	root.size = Vector2i(1152, 760)
	DisplayServer.window_set_size(Vector2i(1152, 760))
	var base := Color("#252525")
	var background: ColorRect = ColorRect.new()
	background.color = base.darkened(0.25)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)

	# Sheet above, the GDScript it compiles to below. Stacked rather than side by side because both
	# halves want the full width: a narrowed sheet wraps its cells, and the walk this picture exists
	# to show is the widest line in the file.
	var columns: VBoxContainer = VBoxContainer.new()
	columns.position = Vector2(8, 8)
	columns.size = Vector2(1136, 744)
	columns.add_theme_constant_override("separation", 6)
	root.add_child(columns)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(1136, 210)
	columns.add_child(scroll)
	_viewport = EventSheetViewport.new()
	_viewport.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_viewport.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_viewport.set_ace_registry(EventSheetACERegistry.new())
	scroll.add_child(_viewport)

	var sheet: EventSheetResource = _build_editor_sheet(base)
	_viewport.set_sheet(sheet)

	var code: CodeEdit = CodeEdit.new()
	code.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	code.size_flags_vertical = Control.SIZE_EXPAND_FILL
	code.editable = false
	code.text = _compiled_text(sheet)
	columns.add_child(code)
	process_frame.connect(_on_frame)


## The pair a build editor is: one button writes the branch out, the other reads it back - and the
## reading one asks whether the file is data before it builds anything, because a scene file can name
## a script and this one has been sitting in the player's own folder.
func _build_editor_sheet(base: Color) -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	var style := EventSheetEditorStyle.new()
	style.ensure_defaults()
	EventSheetGodotTheme.apply(style, base, base.darkened(0.15), base.darkened(0.25),
		Color("#569eff"), Color("#ced0d2"))
	sheet.editor_style = style

	var saving: EventRow = EventRow.new()
	saving.trigger_provider_id = "Core"
	saving.trigger_id = "OnProcess"
	saving.conditions.append(_condition("IsActionJustPressed", {"action": "\"save_level\""}))
	saving.actions.append(_action("SaveBranchAsSceneFile",
		{"branch": "$Level", "path": "\"user://built_level.tscn\""}, "a1"))
	sheet.events.append(saving)

	var loading: EventRow = EventRow.new()
	loading.trigger_provider_id = "Core"
	loading.trigger_id = "OnProcess"
	loading.conditions.append(_condition("IsActionJustPressed", {"action": "\"load_level\""}))
	loading.conditions.append(_condition("SceneFileIsDataOnly",
		{"path": "\"user://built_level.tscn\""}))
	loading.actions.append(_action("AddLayoutOnTop",
		{"path": "\"user://built_level.tscn\"", "layout_name": "\"Built\""}, "b2"))
	sheet.events.append(loading)
	return sheet


func _condition(ace_id: String, params: Dictionary) -> ACECondition:
	var condition: ACECondition = ACECondition.new()
	condition.provider_id = "Core"
	condition.ace_id = ace_id
	condition.params = params
	return condition


## `uid` bakes the per-row id a template declaring locals needs - the dock does this at apply time,
## so a preview that skipped it would draw a row no sheet ever holds.
func _action(ace_id: String, params: Dictionary, uid: String) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = ace_id
	action.params = params
	action.codegen_template = ACERegistry.find_descriptor(
		"Core", ace_id).codegen_template.replace("{uid}", uid)
	return action


func _compiled_text(sheet: EventSheetResource) -> String:
	sheet.external_source_path = "user://_scene_save_preview.gd"
	var output: String = str(SheetCompiler.compile(sheet, sheet.external_source_path).get("output", ""))
	sheet.external_source_path = ""
	return output.strip_edges()


func _on_frame() -> void:
	_frames += 1
	if _frames < 8:
		return
	var image: Image = root.get_texture().get_image()
	image.save_png(OUTPUT_PATH)
	print("[preview] save branch as scene file %dx%d" % [image.get_width(), image.get_height()])
	quit(0)
