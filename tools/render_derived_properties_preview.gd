# EventForge - render harness (dev tool) for the DERIVED property rows: one whole event whose
# condition and two of whose actions are derived off the class the sheet knows the object is, with a
# curated word-map row sitting between them so the two layers are visible side by side. Run
# NON-headless:
#   godot --path . --script tools/render_derived_properties_preview.gd
@tool
extends SceneTree

## The staged script the sheet is opened from - one light, one question about a property no word map
## claims, and three writes: one the word map owns, and two it does not.
##
## A staging path a previous run left behind cannot always be reopened for writing, and the import
## then reads yesterday's file while everything else about the run looks right - so this name is this
## harness's alone and the file is removed on the way out.
const STAGED_PATH: String = "user://property_rows_figure.gd"
const STAGED_SOURCE: String = """extends CharacterBody2D

@onready var torch: Light2D = $Torch


func _physics_process(_delta: float) -> void:
	if torch.shadow_filter_smooth > 1.0:
		torch.energy = 1.2
		torch.shadow_filter_smooth = 0.5
		torch.shadow_color = torch.color
"""

## The body of the staged function, drawn verbatim above the rows it becomes.
const SHOWN_CODE: String = """	if torch.shadow_filter_smooth > 1.0:
		torch.energy = 1.2
		torch.shadow_filter_smooth = 0.5
		torch.shadow_color = torch.color"""

var _frames: int = 0
var _viewport: EventSheetViewport = null


func _init() -> void:
	# The sheet is opened BEFORE anything else is built: an ACE registry constructed and left
	# unrefreshed is a registry with no vocabulary in it, and the lifter matches templates against
	# whatever registry is current - so importing after one exists reads the file as a verbatim block.
	var sheet: EventSheetResource = _staged_sheet()
	root.title = "Derived Property Rows"
	root.size = Vector2i(1060, 470)
	root.gui_embed_subwindows = true
	var base := Color("#252525")
	var background: ColorRect = ColorRect.new()
	background.color = base.darkened(0.25)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)
	var column: VBoxContainer = VBoxContainer.new()
	column.position = Vector2(10, 8)
	column.size = Vector2(1040, 454)
	column.add_theme_constant_override("separation", 8)
	root.add_child(column)
	column.add_child(_caption("One event, as the file writes it"))
	column.add_child(_code_block())
	column.add_child(_caption(
		"The same event as the sheet reads it - a word map somebody wrote, then two rows read "
		+ "off the class the sheet knows the object is"))
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(1040, 290)
	column.add_child(scroll)
	_viewport = EventSheetViewport.new()
	_viewport.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_viewport.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_viewport.set_ace_registry(EventSheetACERegistry.new())
	scroll.add_child(_viewport)
	_viewport.set_sheet(sheet)
	process_frame.connect(_on_frame)


## A muted heading over each half, so the figure says which is which without a caption elsewhere.
func _caption(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color("#8b9099"))
	return label


## The staged body shown verbatim, in the editor's own ink.
func _code_block() -> Label:
	var label: Label = Label.new()
	label.text = SHOWN_CODE
	label.add_theme_color_override("font_color", Color("#ced0d2"))
	return label


## Whether the build in front of us is the settled one: a row whose span the derived layer claimed.
func _has_derived_rows() -> bool:
	for row: EventRowData in _all_rows(_viewport._root_rows):
		for span: SemanticSpan in row.spans:
			if bool(span.metadata.get("derived_call", false)):
				return true
	return false


func _all_rows(rows: Array) -> Array:
	var out: Array = []
	for row: EventRowData in rows:
		out.append(row)
		out.append_array(_all_rows(row.children))
	return out


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
	# The sheet is rebuilt more than once on the way up (the project scan finishes some frames after
	# the file is opened), and only the settled build has the derived rows on it. So the shot waits
	# for the fact it is a picture OF rather than for a frame count that happened to work once.
	if _frames < 8 or (not _has_derived_rows() and _frames < 400):
		return
	var image: Image = root.get_texture().get_image()
	image.save_png("res://docs/images/derived-property-rows.png")
	print("[preview] derived property rows %dx%d" % [image.get_width(), image.get_height()])
	DirAccess.remove_absolute(STAGED_PATH)
	quit(0)
