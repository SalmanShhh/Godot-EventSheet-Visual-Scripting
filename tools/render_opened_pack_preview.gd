# EventForge - render harness (dev tool) for an opened behaviour pack read as a sheet.
# Imports the FPS Controller pack as a READ-ONLY preview and screenshots two things:
#   docs/images/opened-pack-verbs.png    - the published verbs as Construct Function blocks
#                                          plus the folded Helpers group
#   docs/images/ace-properties-popup.png - the ACE properties panel a verb header opens
#   docs/images/opened-pack-input-triggers.png - the pack's `_unhandled_input`, read as one
#                                          Mouse / Keyboard trigger row per branch
# Run NON-headless (headless runs cannot render):
#   godot --path . --script tools/render_opened_pack_preview.gd
@tool
extends SceneTree

const PACK_PATH: String = "res://eventsheet_addons/fps_controller/fps_controller_behavior.gd"

var _frames: int = 0
var _stage: int = 0
var _viewport: EventSheetViewport = null
var _scroll: ScrollContainer = null
var _sheet: EventSheetResource = null
var _style: EventSheetEditorStyle = null
var _popup_frame: PanelContainer = null


func _init() -> void:
	root.title = "Opened pack"
	root.size = Vector2i(1500, 900)
	var modern_base := Color("#252525")
	var background: ColorRect = ColorRect.new()
	background.color = modern_base.darkened(0.25)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)
	_scroll = ScrollContainer.new()
	# Anchored, not sized by hand: the window manager may clamp a 1500x900 window to the screen, and a
	# scroll box that still believes it is 884 tall scrolls the shot to the wrong place.
	_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(_scroll)
	_viewport = EventSheetViewport.new()
	_viewport.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_viewport.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_viewport.set_ace_registry(EventSheetACERegistry.new())
	_scroll.add_child(_viewport)
	_sheet = GDScriptImporter.new().import_external(PACK_PATH)
	# The dock opens a .gd as a read-only preview; the importer leaves the flag alone, so the
	# harness sets what the dock would set.
	_sheet.read_only = true
	_style = EventSheetEditorStyle.new()
	_style.ensure_defaults()
	EventSheetGodotTheme.apply(_style, modern_base, modern_base.darkened(0.15), modern_base.darkened(0.25), Color("#569eff"), Color("#ced0d2"))
	_sheet.editor_style = _style
	_viewport.set_sheet(_sheet)
	_viewport.set_reading_mode(true)
	# No pointer input at all, so wherever the mouse happens to rest, no hover tooltip drifts across
	# the screenshot.
	root.gui_disable_input = true
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frames += 1
	if _frames < 10:
		return
	match _stage:
		0:
			_scroll.scroll_vertical = int(_first_verb_top())
			_stage = 1
			_frames = 0
		1:
			var img: Image = root.get_texture().get_image()
			img.save_png("res://docs/images/opened-pack-verbs.png")
			print("[preview] verbs %dx%d" % [img.get_width(), img.get_height()])
			_print_verb_rows()
			_show_popup()
			_stage = 2
			_frames = 0
		2:
			var popup_img: Image = root.get_texture().get_image()
			popup_img.save_png("res://docs/images/ace-properties-popup.png")
			print("[preview] popup %dx%d" % [popup_img.get_width(), popup_img.get_height()])
			if _popup_frame != null:
				_popup_frame.queue_free()
				_popup_frame = null
			_scroll.scroll_vertical = int(_input_handler_top())
			_stage = 3
			_frames = 0
		_:
			var input_img: Image = root.get_texture().get_image()
			input_img.save_png("res://docs/images/opened-pack-input-triggers.png")
			print("[preview] input triggers %dx%d" % [input_img.get_width(), input_img.get_height()])
			_print_input_rows()
			quit(0)


## Where the shot opens: on the folded "Helpers" bar with the last published verbs above it, so one
## image carries both readings. Falls back to the first published verb when there is no Helpers bar.
func _first_verb_top() -> float:
	var first_verb: float = 0.0
	for index in range(_viewport._flat_rows.size()):
		var row_data: EventRowData = _viewport._flat_rows[index].get("row")
		if row_data == null:
			continue
		if row_data.row_uid.begins_with("helpers_group_"):
			return maxf(_viewport._row_metrics_helper.row_top(index) - _scroll.size.y * 0.72, 0.0)
		if first_verb <= 0.0 and _is_published_verb_row(row_data):
			first_verb = maxf(_viewport._row_metrics_helper.row_top(index) - 12.0, 0.0)
	return first_verb


func _is_published_verb_row(row_data: EventRowData) -> bool:
	var verb: EventFunction = row_data.source_resource as EventFunction
	return verb != null and verb.expose_as_ace


## Prints what each verb header actually READS as, so a run doubles as a text check of the
## header spans (the image proves the look; this proves the words).
func _print_verb_rows() -> void:
	var printed: int = 0
	for index in range(_viewport._flat_rows.size()):
		var row_data: EventRowData = _viewport._flat_rows[index].get("row")
		if row_data == null or not (row_data.source_resource is EventFunction):
			continue
		var texts: PackedStringArray = PackedStringArray()
		for span: SemanticSpan in row_data.spans:
			texts.append(span.text)
		print("  header: [%s]" % " | ".join(texts))
		printed += 1
		if printed >= 12:
			return


## The event_uids the pack's `_unhandled_input` anchor owns - the rows the third shot frames.
func _input_event_uids() -> Dictionary:
	var uids: Dictionary = {}
	for entry: Variant in _sheet.events:
		if entry is EventAnchorRow and (entry as EventAnchorRow).trigger_id == "OnUnhandledInput":
			for anchored_uid: String in (entry as EventAnchorRow).event_uids:
				uids[anchored_uid] = true
	return uids


## Where the third shot opens: a little above the first branch of the input handler.
func _input_handler_top() -> float:
	var uids: Dictionary = _input_event_uids()
	for index in range(_viewport._flat_rows.size()):
		var row_data: EventRowData = _viewport._flat_rows[index].get("row")
		if row_data == null or not (row_data.source_resource is EventRow):
			continue
		if uids.has((row_data.source_resource as EventRow).event_uid):
			return maxf(_viewport._row_metrics_helper.row_top(index) - _scroll.size.y * 0.35, 0.0)
	return 0.0


## Prints what each branch of the input handler READS as - the words behind the third image.
func _print_input_rows() -> void:
	var uids: Dictionary = _input_event_uids()
	for entry: Dictionary in _viewport.get_flat_rows():
		var row_data: EventRowData = entry.get("row")
		if row_data == null or not (row_data.source_resource is EventRow):
			continue
		if not uids.has((row_data.source_resource as EventRow).event_uid):
			continue
		_viewport._ensure_event_spans(row_data)
		var texts: PackedStringArray = PackedStringArray()
		for span: SemanticSpan in row_data.spans:
			texts.append(span.text)
		print("  branch: [%s]" % " | ".join(texts))


## Draws the ACE properties panel over the sheet, exactly as the popup shows it.
func _show_popup() -> void:
	var target: EventFunction = null
	for entry: Variant in _sheet.functions:
		if entry is EventFunction and (entry as EventFunction).function_name == "set_third_person":
			target = entry as EventFunction
	if target == null:
		return
	# The three ways out are wired to no-ops here: the harness draws the panel, it does not drive it.
	var noop: Callable = func() -> void: pass
	var panel: Control = EventSheetVerbProperties.build_panel(target, _sheet, noop, noop, noop)
	var frame := PanelContainer.new()
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color("#1e222c")
	frame_style.border_color = Color("#4a5370")
	frame_style.set_border_width_all(1)
	frame_style.set_corner_radius_all(8)
	frame_style.set_content_margin_all(2)
	frame.add_theme_stylebox_override("panel", frame_style)
	frame.position = Vector2(360, 120)
	frame.size = Vector2(640, 0)
	frame.add_child(panel)
	root.add_child(frame)
	_popup_frame = frame
