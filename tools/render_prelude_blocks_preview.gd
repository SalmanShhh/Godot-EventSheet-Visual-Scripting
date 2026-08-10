# EventForge - render harness (dev tool) for the enum block + Class setup strip: screenshots the
# beginner-style sample's head CLOSED (enum sentence, breadcrumb bar) then OPEN (value list,
# facts dropdown). Run NON-headless:
#   godot --path . --script tools/render_prelude_blocks_preview.gd
@tool
extends SceneTree

var _frames: int = 0
var _stage: int = 0
var _viewport: EventSheetViewport = null
var _sheet: EventSheetResource = null

const SAMPLE := """@tool
class_name ExternalSample
extends CharacterBody2D

enum State { PATROL, CHASE, FLEE }

var state := State.PATROL
var hp := 100


func _physics_process(delta):
	match state:
		State.PATROL:
			patrol_step(delta)
		State.CHASE:
			chase_step(delta)
		State.FLEE:
			flee_step(delta)
"""


func _init() -> void:
	root.title = "Prelude Blocks"
	root.size = Vector2i(1000, 420)
	var modern_base := Color("#252525")
	var background: ColorRect = ColorRect.new()
	background.color = modern_base.darkened(0.25)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.position = Vector2(8, 8)
	scroll.size = Vector2(984, 404)
	root.add_child(scroll)
	_viewport = EventSheetViewport.new()
	_viewport.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_viewport.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_viewport.set_ace_registry(EventSheetACERegistry.new())
	scroll.add_child(_viewport)
	var sample: FileAccess = FileAccess.open("user://prelude_blocks_sample.gd", FileAccess.WRITE)
	sample.store_string(SAMPLE)
	sample.close()
	_sheet = GDScriptImporter.new().import_external("user://prelude_blocks_sample.gd")
	var modern_style := EventSheetEditorStyle.new()
	modern_style.ensure_defaults()
	EventSheetGodotTheme.apply(modern_style, modern_base, modern_base.darkened(0.15), modern_base.darkened(0.25), Color("#569eff"), Color("#ced0d2"))
	_sheet.editor_style = modern_style
	_viewport.set_sheet(_sheet)
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frames += 1
	if _frames < 8:
		return
	var img: Image = root.get_texture().get_image()
	if _stage == 0:
		img.save_png("res://docs/images/prelude-blocks-closed.png")
		print("[preview] closed %dx%d" % [img.get_width(), img.get_height()])
		_stage = 1
		_frames = 0
		# Open both folds: the strip and the enum flip to their list forms.
		_viewport._fold_state["scaffolding_strip_%d" % _sheet.get_instance_id()] = false
		for row: Variant in _sheet.events:
			if row is EnumRow:
				_viewport._fold_state["enum_%s_0" % str((row as EnumRow).get_instance_id())] = false
		_viewport._refresh_rows()
		return
	img.save_png("res://docs/images/prelude-blocks-open.png")
	print("[preview] open %dx%d" % [img.get_width(), img.get_height()])
	quit(0)
