# EventForge - render harness (dev tool) for the Second View pack's rows on the canvas: the
# two-sentence minimap, and the three rows that change or remove it afterwards. The point of the
# picture is that the whole feature is two sentences a reader can take in at a glance. Run
# NON-headless (a headless run cannot render):
#   godot --path . --script tools/render_second_view_rows_preview.gd
@tool
extends SceneTree

const PACK: String = "res://eventsheet_addons/second_view/second_view_addon.gd"

## How much of the rendered frame the rows occupy, in framebuffer pixels.
const ROW_BAND_HEIGHT: int = 132

var _frames: int = 0
var _viewport: EventSheetViewport = null


func _verb(method_name: String, template: String, values: Dictionary) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "SecondViewPackAddon"
	action.ace_id = "method:%s" % method_name
	action.codegen_template = template
	action.params = values
	return action


func _event(trigger: String, verbs: Array) -> EventRow:
	var row: EventRow = EventRow.new()
	row.trigger_provider_id = "Core"
	row.trigger_id = trigger
	for verb: ACEAction in verbs:
		row.actions.append(verb)
	return row


func _init() -> void:
	root.title = "Second View rows"
	root.size = Vector2i(1152, 200)
	var base := Color("#252525")
	var background: ColorRect = ColorRect.new()
	background.color = base.darkened(0.25)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.position = Vector2(8, 8)
	scroll.size = Vector2(1136, 184)
	root.add_child(scroll)

	# The dock feeds the registry its addon-scanned providers; mirror that with the one pack this
	# picture is about, so the rows read as the pack's own authored sentences.
	var registry: EventSheetACERegistry = EventSheetACERegistry.new()
	var pack_script: Script = load(PACK) as Script
	var sources: Array[Object] = []
	if pack_script != null and pack_script.can_instantiate():
		sources.append(pack_script.new())
	registry.refresh_from_sources(sources)

	_viewport = EventSheetViewport.new()
	_viewport.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_viewport.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_viewport.set_ace_registry(registry)
	scroll.add_child(_viewport)

	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	var style := EventSheetEditorStyle.new()
	style.ensure_defaults()
	EventSheetGodotTheme.apply(style, base, base.darkened(0.15), base.darkened(0.25), Color("#569eff"), Color("#ced0d2"))
	sheet.editor_style = style

	sheet.events.append(_event("OnReady", [
		_verb("make_a_view", "SecondView.make_a_view({view_name}, {followed}, {zoom})",
			{"view_name": "\"minimap\"", "followed": "$Player", "zoom": "0.25"}),
		_verb("show_view_in", "SecondView.show_view_in({view_name}, {frame})",
			{"view_name": "\"minimap\"", "frame": "$HUD/MinimapFrame"}),
	]))
	_viewport.set_sheet(sheet)
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frames += 1
	if _frames < 8:
		return
	var full: Image = root.get_texture().get_image()
	# Cropped to the rows themselves: the window is taller than the sheet so nothing is clipped, and
	# a figure that was two thirds empty space would read as a mistake.
	var img: Image = full.get_region(Rect2i(0, 0, full.get_width(), ROW_BAND_HEIGHT))
	img.save_png("res://docs/images/second-view-rows.png")
	print("[preview] second view rows %dx%d" % [img.get_width(), img.get_height()])
	quit(0)
