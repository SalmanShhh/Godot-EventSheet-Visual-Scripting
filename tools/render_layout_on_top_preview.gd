# EventForge - render harness (dev tool) for the layout-on-top rows: the pause pair as a sheet, with
# the GDScript it compiles to beside it, so the two can be read against each other in one picture.
# The pair is the whole point of the vocabulary - one event puts the menu up and freezes the game,
# its twin takes it down and lets the game run - and the code panel shows that nothing behind it is
# more than the lines a person would have written by hand.
#
# Run NON-headless (a headless run cannot render):
#   godot --path . --script tools/render_layout_on_top_preview.gd
@tool
extends SceneTree

const OUTPUT_PATH: String = "res://docs/images/layout-on-top-pause-pair.png"

var _frames: int = 0
var _viewport: EventSheetViewport = null


func _init() -> void:
	root.title = "Layout On Top"
	root.size = Vector2i(1152, 700)
	DisplayServer.window_set_size(Vector2i(1152, 700))
	var base := Color("#252525")
	var background: ColorRect = ColorRect.new()
	background.color = base.darkened(0.25)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)

	# Sheet above, the GDScript it compiles to below. Stacked rather than side by side because both
	# halves want the full width: a narrowed sheet wraps its cells and a narrowed code panel hides
	# the ends of the very lines this preview exists to show.
	var columns: VBoxContainer = VBoxContainer.new()
	columns.position = Vector2(8, 8)
	columns.size = Vector2(1136, 684)
	columns.add_theme_constant_override("separation", 6)
	root.add_child(columns)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(1136, 300)
	columns.add_child(scroll)
	_viewport = EventSheetViewport.new()
	_viewport.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_viewport.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_viewport.set_ace_registry(EventSheetACERegistry.new())
	scroll.add_child(_viewport)

	var sheet: EventSheetResource = _pause_pair_sheet(base)
	_viewport.set_sheet(sheet)

	var code: CodeEdit = CodeEdit.new()
	code.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	code.size_flags_vertical = Control.SIZE_EXPAND_FILL
	code.editable = false
	code.text = _compiled_text(sheet)
	columns.add_child(code)
	process_frame.connect(_on_frame)


## The pair: press the cancel control with no menu up and the menu goes up and the game freezes;
## press it with the menu up and the menu goes away and the game runs again. Both events are the
## same trigger and the same control - it is the layout-on-top question that tells them apart.
func _pause_pair_sheet(base: Color) -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	var style := EventSheetEditorStyle.new()
	style.ensure_defaults()
	EventSheetGodotTheme.apply(style, base, base.darkened(0.15), base.darkened(0.25),
		Color("#569eff"), Color("#ced0d2"))
	sheet.editor_style = style

	var opening: EventRow = EventRow.new()
	opening.trigger_provider_id = "Core"
	opening.trigger_id = "OnProcess"
	opening.conditions.append(_condition("IsActionJustPressed", {"action": "\"ui_cancel\""}))
	opening.conditions.append(_condition("LayoutIsOnTop", {"layout_name": "\"PauseMenu\""}, true))
	opening.actions.append(_action("AddLayoutOnTop",
		{"path": "\"res://pause_menu.tscn\"", "layout_name": "\"PauseMenu\""}, "a1"))
	opening.actions.append(_action("PauseGame", {}))
	sheet.events.append(opening)

	var closing: EventRow = EventRow.new()
	closing.trigger_provider_id = "Core"
	closing.trigger_id = "OnProcess"
	closing.conditions.append(_condition("IsActionJustPressed", {"action": "\"ui_cancel\""}))
	closing.conditions.append(_condition("LayoutIsOnTop", {"layout_name": "\"PauseMenu\""}))
	closing.actions.append(_action("RemoveLayoutOnTop", {"layout_name": "\"PauseMenu\""}, "b2"))
	closing.actions.append(_action("UnpauseGame", {}))
	sheet.events.append(closing)
	return sheet


func _condition(ace_id: String, params: Dictionary, negated: bool = false) -> ACECondition:
	var condition: ACECondition = ACECondition.new()
	condition.provider_id = "Core"
	condition.ace_id = ace_id
	condition.params = params
	condition.negated = negated
	return condition


## `uid` bakes the per-row id a template declaring a local needs - the dock does this at apply time,
## so a preview that skipped it would draw a row no sheet ever holds.
func _action(ace_id: String, params: Dictionary, uid: String = "") -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = ace_id
	action.params = params
	if not uid.is_empty():
		action.codegen_template = ACERegistry.find_descriptor("Core", ace_id).codegen_template.replace("{uid}", uid)
	return action


func _compiled_text(sheet: EventSheetResource) -> String:
	sheet.external_source_path = "user://_layout_on_top_preview.gd"
	var output: String = str(SheetCompiler.compile(sheet, sheet.external_source_path).get("output", ""))
	sheet.external_source_path = ""
	# The body alone: a sheet with no source file of its own emits no header, and the leading blank
	# it separates functions with is not worth a line of a picture this tight.
	return output.strip_edges()


func _on_frame() -> void:
	_frames += 1
	if _frames < 8:
		return
	var image: Image = root.get_texture().get_image()
	image.save_png(OUTPUT_PATH)
	print("[preview] layout on top %dx%d" % [image.get_width(), image.get_height()])
	quit(0)
