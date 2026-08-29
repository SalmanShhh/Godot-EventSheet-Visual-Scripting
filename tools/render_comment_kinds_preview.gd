# EventForge - render harness (dev tool) for the two comment kinds: a documentation `##` row and a
# private `#` row on one canvas, so the paragraph mark, the two ink strengths and the echo each row
# carries can be eyeballed side by side. Run NON-headless:
#   godot --path . --script tools/render_comment_kinds_preview.gd
@tool
extends SceneTree

## How much of the rendered frame the rows occupy, in framebuffer pixels.
const COMMENT_BAND_HEIGHT: int = 300

var _frames: int = 0
var _viewport: EventSheetViewport = null


func _comment(text: String, marker: String) -> CommentRow:
	var comment_row: CommentRow = CommentRow.new()
	comment_row.text = text
	comment_row.source_marker = marker
	return comment_row


func _make_event(trigger: String, value: String) -> EventRow:
	var row: EventRow = EventRow.new()
	row.trigger_provider_id = "Core"
	row.trigger_id = trigger
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "Print"
	action.codegen_template = "print({value})"
	action.params = {"value": value}
	row.actions.append(action)
	return row


func _init() -> void:
	root.title = "Comment Kinds"
	root.size = Vector2i(1040, 340)
	var modern_base := Color("#252525")
	var background: ColorRect = ColorRect.new()
	background.color = modern_base.darkened(0.25)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.position = Vector2(8, 8)
	scroll.size = Vector2(1024, 324)
	root.add_child(scroll)
	_viewport = EventSheetViewport.new()
	_viewport.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_viewport.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_viewport.set_ace_registry(EventSheetACERegistry.new())
	scroll.add_child(_viewport)

	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	var modern_style := EventSheetEditorStyle.new()
	modern_style.ensure_defaults()
	EventSheetGodotTheme.apply(modern_style, modern_base, modern_base.darkened(0.15), modern_base.darkened(0.25), Color("#569eff"), Color("#ced0d2"))
	sheet.editor_style = modern_style
	sheet.events.append(_comment("The player falls until the ground catches them.", "## "))
	sheet.events.append(_make_event("OnProcess", "\"falling\""))
	sheet.events.append(_comment("Buffer window is 6 frames - measured, do not round it.", ""))
	sheet.events.append(_make_event("OnBodyEntered", "\"landed\""))
	sheet.events.append(_comment("TODO handle the ledge grab.", ""))
	_viewport.set_sheet(sheet)
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frames += 1
	if _frames < 8:
		return
	var full: Image = root.get_texture().get_image()
	# Cropped to the rows themselves: the window is taller than the sheet so nothing is clipped, and
	# a figure that was two thirds empty space would read as a mistake.
	var img: Image = full.get_region(Rect2i(0, 0, full.get_width(), COMMENT_BAND_HEIGHT))
	img.save_png("res://docs/images/comment-kinds.png")
	print("[preview] comment kinds %dx%d" % [img.get_width(), img.get_height()])
	quit(0)
