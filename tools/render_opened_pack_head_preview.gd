# EventForge - render harness (dev tool) for the HEAD of an opened behaviour pack.
# Imports the FPS Controller pack as a READ-ONLY preview and screenshots the top of the sheet twice:
#   docs/images/opened-pack-head.png      - the head as it opens: the Include bar, the description
#                                           once, and the Triggers / settings / Internal state bars
#                                           closed, with the pack's logic right below them
#   docs/images/opened-pack-head-open.png - the same head with the Jump bar open, so a knob's reading
#                                           shows (type word, name, value, description)
# Run NON-headless (headless runs cannot render):
#   godot --path . --script tools/render_opened_pack_head_preview.gd
@tool
extends SceneTree

const PACK_PATH: String = "res://eventsheet_addons/fps_controller/fps_controller_behavior.gd"

var _frames: int = 0
var _stage: int = 0
var _viewport: EventSheetViewport = null
var _scroll: ScrollContainer = null
var _sheet: EventSheetResource = null


func _init() -> void:
	root.title = "Opened pack head"
	root.size = Vector2i(1500, 900)
	var modern_base := Color("#252525")
	var background: ColorRect = ColorRect.new()
	background.color = modern_base.darkened(0.25)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)
	_scroll = ScrollContainer.new()
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
	var style := EventSheetEditorStyle.new()
	style.ensure_defaults()
	EventSheetGodotTheme.apply(style, modern_base, modern_base.darkened(0.15), modern_base.darkened(0.25), Color("#569eff"), Color("#ced0d2"))
	_sheet.editor_style = style
	_viewport.set_sheet(_sheet)
	_viewport.set_reading_mode(true)
	root.gui_disable_input = true
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frames += 1
	if _frames < 10:
		return
	match _stage:
		0:
			var img: Image = root.get_texture().get_image()
			img.save_png("res://docs/images/opened-pack-head.png")
			print("[preview] head %dx%d" % [img.get_width(), img.get_height()])
			_print_head_rows()
			_open_jump_bar()
			_stage = 1
			_frames = 0
		_:
			var open_img: Image = root.get_texture().get_image()
			open_img.save_png("res://docs/images/opened-pack-head-open.png")
			print("[preview] head open %dx%d" % [open_img.get_width(), open_img.get_height()])
			quit(0)


## Opens the Jump settings bar (the fold state the user would click), rebuilds, and scrolls to it -
## so the second shot carries both readings: an open settings bar, and the logic the head hands over to.
func _open_jump_bar() -> void:
	for entry: Variant in _viewport._flat_rows:
		var row_data: EventRowData = (entry as Dictionary).get("row")
		if row_data != null and row_data.row_uid.begins_with("pack_settings_Jump"):
			_viewport._fold_state[row_data.row_uid] = false
	_viewport.set_sheet(_sheet)
	_viewport.set_reading_mode(true)
	for index in range(_viewport._flat_rows.size()):
		var row_data: EventRowData = (_viewport._flat_rows[index] as Dictionary).get("row")
		if row_data != null and row_data.row_uid.begins_with("pack_settings_Jump"):
			_scroll.scroll_vertical = int(maxf(_viewport._row_metrics_helper.row_top(index) - 20.0, 0.0))
			return


## Prints what the head actually READS as, so a run doubles as a text check of the bars (the image
## proves the look; this proves the words).
func _print_head_rows() -> void:
	for index in range(mini(_viewport._flat_rows.size(), 14)):
		var row_data: EventRowData = (_viewport._flat_rows[index] as Dictionary).get("row")
		if row_data == null:
			continue
		var texts: PackedStringArray = PackedStringArray()
		for span: SemanticSpan in row_data.spans:
			texts.append(span.text)
		print("  head: [%s]" % " | ".join(texts).substr(0, 150))
