# EventForge - render harness (dev tool) for the batch-11 "working with sheets" windows: the
# conflict view (OURS / THEIRS columns picked per event) and the New Shared Sheet window.
# Run NON-headless:
#   godot --path . --script tools/render_working_with_sheets_preview.gd
@tool
extends SceneTree

const FIXTURE := "user://ef_conflict_preview.gd"

var _frames: int = 0
var _host: Control = null
var _conflict: RefCounted = null
var _shared: EventSheetSharedSheetDialogs = null


func _init() -> void:
	root.title = "Working With Sheets"
	root.size = Vector2i(980, 700)
	root.gui_embed_subwindows = true
	var bg: ColorRect = ColorRect.new()
	bg.color = Color("#2b2b2b")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	_host = Control.new()
	_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(_host)
	var file: FileAccess = FileAccess.open(FIXTURE, FileAccess.WRITE)
	file.store_string("\n".join(PackedStringArray([
		"extends CharacterBody2D",
		"",
		"var speed := 200.0",
		"",
		"<<<<<<< HEAD",
		"func land() -> void:",
		"\tvelocity.y = 0.0",
		"",
		"func jump() -> void:",
		"\tvelocity.y = -400.0",
		"=======",
		"func land() -> void:",
		"\tvelocity.y = 0.0",
		"",
		"func jump() -> void:",
		"\tvelocity.y = -520.0",
		">>>>>>> feature/jump",
		"",
		"func _ready() -> void:",
		"\tspeed = 200.0",
		"",
	])))
	file.close()
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frames += 1
	if _frames == 2:
		_conflict = load("res://addons/eventsheet/editor/dock/conflict_view_dialog.gd").new()
		_conflict.init(_host)
		_conflict.open_path(FIXTURE)
		return
	if _frames == 10:
		var img: Image = (_conflict.window as Window).get_texture().get_image()
		img.save_png("res://docs/images/conflict-view.png")
		print("[preview] conflict view %dx%d" % [img.get_width(), img.get_height()])
		(_conflict.window as Window).hide()
		_shared = EventSheetSharedSheetDialogs.new()
		_shared.init(_host)
		_shared.open_new_shared_sheet()
		_shared.name_edit.text = "Pause Handling"
		_shared.wiring_picker.select(1)
		_shared._refresh_preview()
		return
	if _frames < 18 or _shared == null:
		return
	var shared_image: Image = _shared.new_window.get_texture().get_image()
	shared_image.save_png("res://docs/images/shared-sheet-new.png")
	print("[preview] new shared sheet %dx%d" % [shared_image.get_width(), shared_image.get_height()])
	DirAccess.remove_absolute(FIXTURE)
	quit(0)
