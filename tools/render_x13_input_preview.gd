# EventForge - render harness (dev tool) for batch thirteen's input items: the gyro shapes, a
# hand-written swipe recogniser, the boomer arsenal starter, the input-window reading and the game
# options starter. Run NON-headless:
#   godot --path . --script tools/render_x13_input_preview.gd
@tool
extends SceneTree

var _frames: int = 0
var _stage: int = 0
var _viewport: EventSheetViewport = null

const SHOTS: Array[Dictionary] = [
	{"file": "gyro-controls-reading.png", "source": "user://x13_gyro.gd"},
	{"file": "swipe-gestures-reading.png", "source": "user://x13_swipe.gd"},
	{"file": "boomer-arsenal-starter.png", "starter": 15},
	{"file": "input-window-reading.png", "source": "user://x13_window.gd"},
	{"file": "game-options-starter.png", "starter": 16}
]

const GYRO_SOURCE := """extends CharacterBody3D

@onready var cam: Camera3D = $Camera3D
@export var tilt_strength := 900.0
var neutral := Vector3.ZERO

func calibrate() -> void:
	neutral = Input.get_accelerometer()

func steer_by_tilt(delta: float) -> void:
	var tilt := Input.get_accelerometer() - neutral
	velocity.x = tilt.x * tilt_strength * delta

func aim_by_gyro(delta: float) -> void:
	var rate := Input.get_gyroscope()
	rotate_y(-rate.y * delta)
	cam.rotate_x(-rate.x * delta)
"""

const SWIPE_SOURCE := """extends Node2D

var touch_start := Vector2.ZERO
var touch_time := 0.0
var stroke: PackedVector2Array = []

func gather(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		touch_start = event.position
		touch_time = Time.get_ticks_msec() / 1000.0
	elif event is InputEventScreenDrag:
		stroke.append(event.position)
"""

const WINDOW_SOURCE := """extends Node

var window_open := false
var window_until := 0.0

func open_dodge_window(seconds: float) -> void:
	window_open = true
	window_until = Time.get_ticks_msec() / 1000.0 + seconds

func answer_the_window(event: InputEvent) -> void:
	if window_open and event.is_action_pressed("dodge"):
		var remaining := window_until - Time.get_ticks_msec() / 1000.0
		if remaining > 0.15:
			print("good")
"""


func _init() -> void:
	root.title = "Batch 13 input readings"
	root.size = Vector2i(1100, 560)
	var base := Color("#252525")
	var background: ColorRect = ColorRect.new()
	background.color = base.darkened(0.25)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.position = Vector2(8, 8)
	scroll.size = Vector2(1084, 544)
	root.add_child(scroll)
	_viewport = EventSheetViewport.new()
	_viewport.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_viewport.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_viewport.set_ace_registry(EventSheetACERegistry.new())
	scroll.add_child(_viewport)
	_write("user://x13_gyro.gd", GYRO_SOURCE)
	_write("user://x13_swipe.gd", SWIPE_SOURCE)
	_write("user://x13_window.gd", WINDOW_SOURCE)
	_apply(_sheet_for(SHOTS[0]))
	process_frame.connect(_on_frame)


static func _write(path: String, text: String) -> void:
	var handle: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	handle.store_string(text)
	handle.close()


func _sheet_for(shot: Dictionary) -> EventSheetResource:
	if shot.has("starter"):
		return EventSheetStarterTemplates.build_starter(int(shot["starter"]))
	return GDScriptImporter.new().import_external(str(shot["source"]))


func _apply(sheet: EventSheetResource) -> void:
	var base := Color("#252525")
	var style: EventSheetEditorStyle = EventSheetEditorStyle.new()
	style.ensure_defaults()
	EventSheetGodotTheme.apply(style, base, base.darkened(0.15), base.darkened(0.25),
		Color("#569eff"), Color("#ced0d2"))
	sheet.editor_style = style
	_viewport.set_sheet(sheet)
	_viewport.set_reading_mode(true)


func _on_frame() -> void:
	_frames += 1
	if _frames < 8:
		return
	var image: Image = root.get_texture().get_image()
	image.save_png("res://docs/images/%s" % str(SHOTS[_stage]["file"]))
	print("[preview] %s %dx%d" % [str(SHOTS[_stage]["file"]), image.get_width(), image.get_height()])
	_stage += 1
	if _stage >= SHOTS.size():
		quit(0)
		return
	_frames = 0
	_apply(_sheet_for(SHOTS[_stage]))
