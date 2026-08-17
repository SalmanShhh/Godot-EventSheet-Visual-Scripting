# EventForge - render harness (dev tool) for the "Opening <file>" progress strip, and the proof
# that opening a big .gd no longer freezes the editor.
#
# It opens the largest file in the repo (addons/eventsheet/editor/event_sheet_dock.gd, 4,623 lines)
# through the REAL async path: the raw import paints the sheet immediately, EventSheetOpenJob runs
# the ACE lift on a worker thread, and this harness polls it once a frame exactly as the dock does.
# It counts the frames rendered while the job runs (the responsiveness measurement - before this
# landed the number was zero, because the editor never got a frame) and screenshots the strip
# mid-open.
#
# Run NON-headless (headless cannot render):
#   godot --path . --script tools/render_open_progress_preview.gd
@tool
extends SceneTree

const TARGET: String = "res://addons/eventsheet/editor/event_sheet_dock.gd"

var _frames_during_open: int = 0
var _strip: EventSheetOpenProgress = null
var _job: EventSheetOpenJob = null
var _viewport: EventSheetViewport = null
var _shot_saved: bool = false
var _started_msec: int = 0


func _init() -> void:
	root.title = "Opening a sheet"
	root.size = Vector2i(1100, 420)
	var base: Color = Color("#252525")
	var background: ColorRect = ColorRect.new()
	background.color = base.darkened(0.25)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)

	var column: VBoxContainer = VBoxContainer.new()
	column.position = Vector2(8, 8)
	column.size = Vector2(1084, 404)
	column.add_theme_constant_override("separation", 6)
	root.add_child(column)

	_strip = EventSheetOpenProgress.new()
	column.add_child(_strip.build())
	_strip.cancel_requested_callback = func() -> void:
		if _job != null:
			_job.cancel()

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	_viewport = EventSheetViewport.new()
	_viewport.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_viewport.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_viewport.set_ace_registry(EventSheetACERegistry.new())
	scroll.add_child(_viewport)

	# PAINT FIRST: the raw pass (rows + verbatim code blocks) costs tens of milliseconds, so the
	# file is readable on screen before the lift has done anything at all.
	var raw_start: int = Time.get_ticks_msec()
	var raw_sheet: EventSheetResource = GDScriptImporter.new().import_external(TARGET, false)
	var raw_import_msec: int = Time.get_ticks_msec() - raw_start
	var style: EventSheetEditorStyle = EventSheetEditorStyle.new()
	style.ensure_defaults()
	EventSheetGodotTheme.apply(style, base, base.darkened(0.15), base.darkened(0.25), Color("#569eff"), Color("#ced0d2"))
	raw_sheet.editor_style = style
	_viewport.set_sheet(raw_sheet)
	print("[preview] raw import: %d ms (%d rows); on screen after %d ms including the first row build" % [raw_import_msec, raw_sheet.events.size(), Time.get_ticks_msec() - raw_start])

	_job = EventSheetOpenJob.new()
	_started_msec = Time.get_ticks_msec()
	_job.start(TARGET)
	_strip.show_for(TARGET)
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	if _job == null:
		return
	_frames_during_open += 1
	_strip.update(_job.status_text(), _job.progress_ratio())
	# One screenshot mid-open, taken around the half-way mark so the bar reads as a bar.
	if not _shot_saved and _job.progress_ratio() > 0.45:
		var image: Image = root.get_texture().get_image()
		image.save_png("res://docs/images/open-progress-strip.png")
		_shot_saved = true
		print("[preview] strip %dx%d saved" % [image.get_width(), image.get_height()])
	if not _job.is_done():
		return
	var sheet: EventSheetResource = _job.finish()
	var elapsed: float = float(Time.get_ticks_msec() - _started_msec) / 1000.0
	_strip.hide_strip()
	_viewport.set_sheet(sheet)
	print("[preview] opened %s in %.1f s - %d frames rendered while it worked (a frozen editor renders 0)" % [TARGET.get_file(), elapsed, _frames_during_open])
	print("[preview] lifted %d functions, %d rows" % [sheet.functions.size(), sheet.events.size()])
	_job = null
	quit(0)
