# EventForge - render harness (dev tool) for the %name as an object: the Add picker's `%names`
# section, and one whole event whose two actions sit on two named nodes with their code echoes. Run
# NON-headless (headless cannot render):
#   godot --path . --script tools/render_unique_names_preview.gd
@tool
extends SceneTree

## The staged HUD - two nodes ticked *Access as Unique Name* in its scene, and lines written on both.
const HUD_SCRIPT: String = "res://tests/fixtures/unique_names_hud.gd"

var _frames: int = 0
var _viewport: EventSheetViewport = null
var _picker: ACEPickerDialog = null


func _init() -> void:
	root.title = "The %name as an object"
	root.size = Vector2i(1060, 420)
	root.gui_embed_subwindows = true
	var base := Color("#252525")
	var background: ColorRect = ColorRect.new()
	background.color = base.darkened(0.25)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)
	var column: VBoxContainer = VBoxContainer.new()
	column.position = Vector2(10, 8)
	column.size = Vector2(1040, 404)
	column.add_theme_constant_override("separation", 8)
	root.add_child(column)
	column.add_child(_caption("The four lines the file writes"))
	column.add_child(_code_block())
	column.add_child(_caption("One event, two named objects - and the same four lines back"))
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(1040, 300)
	column.add_child(scroll)
	_viewport = EventSheetViewport.new()
	_viewport.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_viewport.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_viewport.set_ace_registry(EventSheetACERegistry.new())
	scroll.add_child(_viewport)
	_viewport.set_sheet(_hud_sheet())
	process_frame.connect(_on_frame)


## A muted heading over the figure, so it says what it is without a caption elsewhere.
func _caption(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color("#8b9099"))
	return label


## The staged lines shown verbatim, so the figure carries the echo of what each row came out of.
func _code_block() -> Label:
	var label: Label = Label.new()
	label.text = "\t\t%HealthBar.show_percentage = false\n\t\t%HealthBar.indeterminate = false" \
		+ "\n\t\t%ScoreLabel.set_modulate(Color(1.0, 0.3, 0.3))\n\t\t%ScoreLabel.text = \"%d\" % score"
	label.add_theme_color_override("font_color", Color("#ced0d2"))
	return label


## The HUD opened the way a reader's own script is opened, in the editor's own ink.
func _hud_sheet() -> EventSheetResource:
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(HUD_SCRIPT)
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
		image.save_png("res://docs/images/unique-name-rows.png")
		print("[preview] unique name rows %dx%d" % [image.get_width(), image.get_height()])
		_open_picker()
		return
	if _frames < 24 or _picker == null or _picker._window == null:
		return
	var page: Image = _picker._window.get_texture().get_image()
	page.save_png("res://docs/images/unique-names-picker-section.png")
	print("[preview] %%names picker section %dx%d" % [page.get_width(), page.get_height()])
	quit(0)


## The picker over the same HUD, opened on the OBJECT step - which is where the `%names` section is.
func _open_picker() -> void:
	var registry: EventSheetACERegistry = EventSheetACERegistry.new()
	registry.refresh_from_sources([] as Array[Object], true)
	var host: Node = _PreviewHost.new()
	root.add_child(host)
	_picker = ACEPickerDialog.new()
	_picker.init_dialog(host, registry)
	_picker.open("new_event", false, null, {"object_first": true})


## The stand-in for the dock: the one method the picker asks its host for.
class _PreviewHost:
	extends Node

	func get_current_sheet() -> EventSheetResource:
		return GDScriptImporter.new().import_external(HUD_SCRIPT)
