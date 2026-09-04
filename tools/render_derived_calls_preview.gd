# EventForge - render harness (dev tool) for the DERIVED call rows: three ordinary calls no curated
# recogniser claims, shown as the code they are and as the rows the sheet derives from them, with
# the picker's derived methods shelf beside it. Run NON-headless:
#   godot --path . --script tools/render_derived_calls_preview.gd
@tool
extends SceneTree

## The staged script the sheet is opened from - a typed timer, an @onready bar and three calls the
## vocabulary has no verb of its own for.
const STAGED_PATH: String = "user://derived_calls_preview.gd"
const STAGED_SOURCE: String = """extends CharacterBody2D

@onready var hp_bar: ProgressBar = $HpBar

var beat: Timer = null


func _ready() -> void:
	beat.set_one_shot(true)
	hp_bar.set_indeterminate(true)
	hp_bar.set_show_percentage(false)
"""

var _frames: int = 0
var _viewport: EventSheetViewport = null
var _picker: ACEPickerDialog = null


func _init() -> void:
	root.title = "Derived Call Rows"
	root.size = Vector2i(1060, 620)
	root.gui_embed_subwindows = true
	var base := Color("#252525")
	var background: ColorRect = ColorRect.new()
	background.color = base.darkened(0.25)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)
	var column: VBoxContainer = VBoxContainer.new()
	column.position = Vector2(10, 8)
	column.size = Vector2(1040, 604)
	column.add_theme_constant_override("separation", 8)
	root.add_child(column)
	column.add_child(_caption("The three calls, as the file writes them"))
	column.add_child(_code_block())
	column.add_child(_caption("The same three calls, as the sheet derives them"))
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(1040, 426)
	column.add_child(scroll)
	_viewport = EventSheetViewport.new()
	_viewport.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_viewport.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_viewport.set_ace_registry(EventSheetACERegistry.new())
	scroll.add_child(_viewport)
	_viewport.set_sheet(_staged_sheet())
	process_frame.connect(_on_frame)


## A muted heading over each half, so the figure says which is which without a caption elsewhere.
func _caption(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color("#8b9099"))
	return label


## The staged source shown verbatim, in the editor's own monospace ink.
func _code_block() -> Label:
	var label: Label = Label.new()
	label.text = "\tbeat.set_one_shot(true)\n\thp_bar.set_indeterminate(true)\n\thp_bar.set_show_percentage(false)"
	label.add_theme_color_override("font_color", Color("#ced0d2"))
	return label


## The sheet, opened from the staged file the way a reader's own script is opened.
func _staged_sheet() -> EventSheetResource:
	var handle: FileAccess = FileAccess.open(STAGED_PATH, FileAccess.WRITE)
	if handle != null:
		handle.store_string(STAGED_SOURCE)
		handle.close()
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(STAGED_PATH)
	if sheet == null:
		return null
	var style := EventSheetEditorStyle.new()
	style.ensure_defaults()
	var base := Color("#252525")
	EventSheetGodotTheme.apply(style, base, base.darkened(0.15), base.darkened(0.25),
		Color("#569eff"), Color("#ced0d2"))
	sheet.editor_style = style
	return sheet


func _on_frame() -> void:
	_frames += 1
	if _frames == 10:
		var image: Image = root.get_texture().get_image()
		image.save_png("res://docs/images/derived-call-rows.png")
		print("[preview] derived call rows %dx%d" % [image.get_width(), image.get_height()])
		_open_picker()
		return
	if _frames < 22 or _picker == null or _picker._window == null:
		return
	var shelf: Image = _picker._window.get_texture().get_image()
	shelf.save_png("res://docs/images/derived-methods-shelf.png")
	print("[preview] derived methods shelf %dx%d" % [shelf.get_width(), shelf.get_height()])
	DirAccess.remove_absolute(STAGED_PATH)
	quit(0)


## The picker, opened over a sheet that is really placed in a scene, filtered to the derived shelf.
func _open_picker() -> void:
	var registry: EventSheetACERegistry = EventSheetACERegistry.new()
	registry.refresh_from_sources([] as Array[Object], true)
	var host: Node = _PreviewHost.new()
	root.add_child(host)
	_picker = ACEPickerDialog.new()
	_picker.init_dialog(host, registry)
	_picker.open("append_action", false, null)
	if _picker._search != null:
		# Typed rather than set, so the picker's own text_changed wiring refreshes the tree exactly
		# as it does under a reader's fingers.
		_picker._search.text = "take damage"
		_picker._search.text_changed.emit("take damage")


## The stand-in for the dock: the one method the picker asks its host for.
class _PreviewHost:
	extends Node

	func get_current_sheet() -> EventSheetResource:
		return GDScriptImporter.new().import_external(
			"res://tests/fixtures/interop_corpus/room.gd")
