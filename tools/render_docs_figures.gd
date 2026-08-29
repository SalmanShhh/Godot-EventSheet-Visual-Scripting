# EventForge - draw the exported site's figures (dev tool). Run NON-headless: a headless process has
# no renderer, and these are pictures of the real one.
#
#   godot --path . --script tools/render_docs_figures.gd
#
# WHAT IT DRAWS, and what it does not. The site exporter writes a job list beside the figure cache -
# one entry per fence in the whole corpus that the editor would draw as rows - and this harness draws
# the ones that have no picture yet. A figure is keyed by the HASH OF ITS FENCE BODY, so a guide that
# was reworded but whose example did not change costs nothing, and a corpus that has not changed at
# all costs one directory listing.
#
# It is the SAME renderer the editor draws rows with (EventSheetDocFigure in figure mode), off the
# same lift, so a picture in the site cannot disagree with what the reader would see in the dock.
#
# Nothing here writes into the project: the cache lives in the user directory, and the export copies
# from it. Run this, then export the site again, and the code cards become pictures.
@tool
extends SceneTree

## How many frames a figure is given to lay out before it is captured. Rows wrap on the first layout
## pass and the theme's fonts land on the second; capturing earlier photographs a half-built page.
const SETTLE_FRAMES: int = 6

## The width figures are drawn at. Wide enough that a normal row does not wrap, narrow enough that
## the picture is legible in a page of prose.
const FIGURE_WIDTH: float = 900.0

var _jobs: Array[Dictionary] = []
var _index: int = -1
var _frames: int = 0
var _host: Control = null
var _drawn: int = 0
var _skipped: int = 0
var _cache: String = ""


func _init() -> void:
	_cache = EventSheetDocSiteExport.figures_cache_dir()
	DirAccess.make_dir_recursive_absolute(_cache)
	var jobs_path: String = "%s/jobs.esdoc" % _cache
	_jobs = EventSheetDocSiteExport.read_jobs(jobs_path)
	if _jobs.is_empty():
		print("[figures] no job list at %s - export the site once first." % jobs_path)
		quit(0)
		return
	var root: Window = get_root()
	root.size = Vector2i(1000, 800)
	root.gui_embed_subwindows = true
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frames += 1
	if _host == null:
		_begin_next()
		return
	if _frames < SETTLE_FRAMES:
		return
	_capture()
	_host.queue_free()
	_host = null
	_begin_next()


## Sets up the next figure that has no picture yet, or finishes.
func _begin_next() -> void:
	_index += 1
	while _index < _jobs.size():
		var job: Dictionary = _jobs[_index]
		var key: String = str(job.get("hash", ""))
		var target: String = "%s/%s" % [_cache, EventSheetDocSiteExport.figure_file(key)]
		if FileAccess.file_exists(target):
			_skipped += 1
			_index += 1
			continue
		var sheet: EventSheetResource = EventSheets.open_gd_as_sheet(str(job.get("body", "")))
		# The same measure the figure gate uses, rather than "does it have any rows": a body that
		# lifted to nothing but verbatim code has rows and is not a figure.
		if sheet == null or EventSheetDocFigures.lifted_row_count(sheet) <= 0:
			_index += 1
			continue
		var figure: EventSheetDocFigure = EventSheetDocFigure.new()
		figure.set_insert_enabled(false)
		var wrapper: MarginContainer = EventSheetPopupUI.margined(figure)
		wrapper.set_anchors_preset(Control.PRESET_TOP_LEFT)
		wrapper.position = Vector2.ZERO
		wrapper.size = Vector2(FIGURE_WIDTH, 600.0)
		get_root().add_child(wrapper)
		if not figure.show_sheet(sheet):
			wrapper.queue_free()
			_index += 1
			continue
		_host = wrapper
		_frames = 0
		return
	print("[figures] %d drawn, %d already had a picture, cache: %s" % [_drawn, _skipped, _cache])
	quit(0)


func _capture() -> void:
	var job: Dictionary = _jobs[_index]
	var image: Image = get_root().get_texture().get_image()
	var rect: Rect2i = Rect2i(Vector2i(_host.global_position), Vector2i(_host.size))
	rect = rect.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	if rect.size.x > 0 and rect.size.y > 0:
		image = image.get_region(rect)
	image.save_png("%s/%s" % [_cache,
		EventSheetDocSiteExport.figure_file(str(job.get("hash", "")))])
	_drawn += 1
