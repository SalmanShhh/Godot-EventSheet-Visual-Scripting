# EventForge - render harness (dev tool) for the visible guard: a sheet opened from a script that
# holds a plain read, the guarded read with its own fallback, and a write under a folder it makes
# first - so the code echo beside each row can be eyeballed against the sentence. Run NON-headless:
#   godot --path . --script tools/render_guarded_read_preview.gd
@tool
extends SceneTree

var _frames: int = 0
var _viewport: EventSheetViewport = null

## The script the sheet is opened from. Every line here is one a project would already have.
const SOURCE := """extends Node


func _ready() -> void:
	var save_text = FileAccess.get_file_as_string("user://save.dat") if FileAccess.file_exists("user://save.dat") else "{}"
	DirAccess.make_dir_recursive_absolute("user://runs/latest.txt".get_base_dir())
	var file = FileAccess.open("user://runs/latest.txt", FileAccess.WRITE)
	if file:
		file.store_string(save_text)
		file.close()
	OS.shell_open(ProjectSettings.globalize_path("user://"))
"""


func _init() -> void:
	root.title = "The Visible Guard"
	root.size = Vector2i(1200, 420)
	var base: Color = Color("#252525")
	var background: ColorRect = ColorRect.new()
	background.color = base.darkened(0.25)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.position = Vector2(8, 8)
	scroll.size = Vector2(1184, 404)
	root.add_child(scroll)
	_viewport = EventSheetViewport.new()
	_viewport.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_viewport.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_viewport.set_ace_registry(EventSheetACERegistry.new())
	scroll.add_child(_viewport)
	var path: String = "user://__guarded_read_preview.gd"
	var handle: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	handle.store_string(SOURCE)
	handle.close()
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(path)
	var style: EventSheetEditorStyle = EventSheetEditorStyle.new()
	style.ensure_defaults()
	EventSheetGodotTheme.apply(style, base, base.darkened(0.15), base.darkened(0.25),
		Color("#569eff"), Color("#ced0d2"))
	sheet.editor_style = style
	_viewport.set_sheet(sheet)
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frames += 1
	if _frames < 8:
		return
	var image: Image = root.get_texture().get_image()
	image.save_png("res://docs/images/file-guarded-read.png")
	print("[preview] guarded read %dx%d" % [image.get_width(), image.get_height()])
	DirAccess.remove_absolute("user://__guarded_read_preview.gd")
	quit(0)
