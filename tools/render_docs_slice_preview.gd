# EventForge - render harness (dev tool) for the documentation FIGURE slice. Produces two PNGs:
#
#   docs/images/doc-figure.png            a bare EventSheetDocFigure - caption, live rows, buttons
#   docs/images/ace-picker-figure.png     the ACE picker's info panel with its live one-row figure
#
# The second image is the one that settles the picker's panel-height question: the description
# panel keeps its 110 px minimum and the figure lives in its own row below it, so a long
# description is never squeezed into a scrollbox to make room for an illustration.
#
# Run NON-headless (headless cannot render):
#   godot --path . --script tools/render_docs_slice_preview.gd
@tool
extends SceneTree

var _frames: int = 0
var _editor: EventSheetEditor = null
var _stage: int = 0


func _make_event(trigger_id: String, message: String) -> EventRow:
	var row: EventRow = EventRow.new()
	row.trigger_provider_id = "Core"
	row.trigger_id = trigger_id
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "Print"
	action.codegen_template = "print({message})"
	action.params = {"message": message}
	row.actions.append(action)
	return row


func _demo_sheet() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.events.append(_make_event("OnReady", "\"game started\""))
	sheet.events.append(_make_event("OnProcess", "\"score ticks\""))
	return sheet


func _init() -> void:
	root.title = "Docs figure slice"
	root.size = Vector2i(1100, 1000)
	root.gui_embed_subwindows = true
	var bg: ColorRect = ColorRect.new()
	bg.color = Color("#2b2b2b")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frames += 1
	if _stage == 0 and _frames == 2:
		var margin: MarginContainer = EventSheetPopupUI.margined(_build_bare_figure())
		# An explicit width: a figure is content-sized, so a host that hugs its child's minimum
		# in BOTH axes gives it nothing to fit inside and the rows wrap to a sliver.
		margin.set_anchors_preset(Control.PRESET_TOP_LEFT)
		margin.position = Vector2.ZERO
		margin.size = Vector2(900.0, 400.0)
		root.add_child(margin)
		_stage = 1
		return
	if _stage == 1 and _frames == 10:
		var image: Image = root.get_texture().get_image()
		image.save_png("res://docs/images/doc-figure.png")
		print("[preview] bare figure %dx%d" % [image.get_width(), image.get_height()])
		for child in root.get_children():
			if child is MarginContainer:
				child.queue_free()
		_stage = 2
		return
	if _stage == 2 and _frames == 14:
		# The picker is a tall dialog; give it room before it opens, or the info panel and its
		# figure - the whole point of this image - sit below the window's bottom edge.
		root.size = Vector2i(1010, 1010)
		_editor = EventSheetEditor.new()
		root.add_child(_editor)
		_editor.setup(_demo_sheet())
		_stage = 3
		return
	if _stage == 3 and _frames == 20:
		var picker: ACEPickerDialog = _editor._ace_picker
		picker.open("new_event", false, null)
		_shrink_dialog_body(picker)
		_stage = 4
		return
	if _stage == 4 and _frames == 26:
		_search_and_select(_editor._ace_picker, "Print")
		_stage = 5
		return
	if _stage == 5 and _frames == 34:
		# Resized LAST: the dialog re-runs its own layout after the popup and after the tree is
		# refilled, and either pass undoes an earlier resize.
		_editor._ace_picker._window.size = Vector2i(940, 700)
		_editor._ace_picker._window.position = Vector2i(20, 12)
		_stage = 6
		return
	if _stage == 6 and _frames == 44:
		var image: Image = root.get_texture().get_image()
		image.save_png("res://docs/images/ace-picker-figure.png")
		print("[preview] picker figure %dx%d" % [image.get_width(), image.get_height()])
		_report_geometry()
		_editor.queue_free()
		_editor = null
		_stage = 7
		return
	if _stage == 7 and _frames == 50:
		root.size = Vector2i(760, 900)
		root.add_child(_build_explain_page())
		_stage = 8
		return
	if _stage == 8 and _frames == 60:
		var image: Image = root.get_texture().get_image()
		image.save_png("res://docs/images/doc-explain-panel.png")
		print("[preview] explain panel %dx%d" % [image.get_width(), image.get_height()])
		quit(0)


func _build_bare_figure() -> EventSheetDocFigure:
	var figure: EventSheetDocFigure = EventSheetDocFigure.new()
	figure.set_caption("Print a line when the scene is ready, and again every frame:")
	figure.set_guide_action("Open the Core guide")
	figure.show_sheet(_demo_sheet())
	return figure


## The Phase 2 page: the whole "what does this do?" panel for a real pack verb, drawn from the
## live vocabulary. Screenshotted as the bare panel rather than through the window, so the image
## shows the page itself (the window around it is an AcceptDialog and adds nothing to read).
func _build_explain_page() -> Control:
	var panel: EventSheetDocPanel = EventSheetDocPanel.new()
	panel.show_definition(_pack_definition("res://eventsheet_addons/quest/quest_addon.gd", "method:advance_objective"))
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.add_child(panel)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var margin: MarginContainer = EventSheetPopupUI.margined(scroll)
	margin.set_anchors_preset(Control.PRESET_TOP_LEFT)
	margin.position = Vector2.ZERO
	margin.size = Vector2(700.0, 860.0)
	return margin


## One verb, reflected from a shipped pack exactly as the editor builds its vocabulary.
func _pack_definition(script_path: String, ace_id: String) -> ACEDefinition:
	var script: GDScript = load(script_path) as GDScript
	if script == null:
		return null
	for definition: ACEDefinition in EventSheetACEGenerator.new().generate_from_object(script.new()):
		if definition.id == ace_id:
			return definition
	return null


## A ConfirmationDialog never shrinks below its content's minimum size, and the picker's browse
## area asks for a tall one - so on a modest screen the info panel and its figure fall off the
## bottom of the shot. Relaxing the browse area's minimum for the screenshot moves nothing about
## the panel below it, which is what the image is of.
func _shrink_dialog_body(picker: ACEPickerDialog) -> void:
	var node: Node = picker._tree
	while node != null and node != picker._info_panel.get_parent():
		if node is Control and (node as Control).custom_minimum_size.y > 200.0:
			(node as Control).custom_minimum_size.y = 200.0
		node = node.get_parent()


## Searches the picker and highlights the first hit, so the info panel and its figure are
## populated when the screenshot is taken - the same flow a reader uses.
func _search_and_select(picker: ACEPickerDialog, query: String) -> void:
	picker._search.text = query
	picker._refresh_tree()
	picker._select_first_match()


## Prints the numbers the spec asks to be settled against a rendered image rather than in code
## review: what the figure actually measures, and what the picker's panels actually occupy.
func _report_geometry() -> void:
	var picker: ACEPickerDialog = _editor._ace_picker
	print("[preview] info panel min height = %.1f, actual height = %.1f" % [
		picker._info_panel.custom_minimum_size.y, picker._info_panel.size.y])
	if picker._figure != null and picker._figure.visible:
		var viewport: EventSheetViewport = picker._figure.figure_viewport()
		print("[preview] figure row canvas = %.1f x %.1f (content %.1f x %.1f)" % [
			viewport.size.x, viewport.size.y, viewport.content_width(), viewport.content_height()])
		print("[preview] whole figure widget height = %.1f" % picker._figure.size.y)
	else:
		print("[preview] figure not visible - nothing was selected")
