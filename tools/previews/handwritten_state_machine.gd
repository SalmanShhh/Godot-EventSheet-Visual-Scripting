# Godot EventSheets - a hand-written state machine beside the rows it opens as (preview module).
#
# Rendered by tools/render_previews.gd, which owns the window and the shutter; this owns the picture.
# NOTHING here is arranged for the camera: the left half is a fixture file the suite byte-gates on
# every run, and the right half is that same file opened through the ordinary importer. If the two
# halves ever disagree, the picture is what says so.
@tool
extends RefCounted

const PREVIEW_NAME: String = "handwritten-state-machine"
const PREVIEW_SIZE: Vector2i = Vector2i(2400, 660)

## The machine on the left: an enum, a variable and a `match` on it - the shape a tutorial writes,
## and the shape this plugin compiles to, which is why the two meet in the middle.
const SAMPLE_PATH: String = "res://tests/fixtures/handwritten_state_patrol.gd"


static func build(host: Window) -> Control:
	var split: HBoxContainer = HBoxContainer.new()
	split.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	split.add_theme_constant_override("separation", 0)
	host.add_child(split)
	split.add_child(_code_panel(FileAccess.get_file_as_string(SAMPLE_PATH)))
	split.add_child(_sheet_panel())
	return split


## The file as it sits on disk, in a plain monospaced box. Read rather than retyped, so the picture
## cannot show a machine the fixture does not contain.
static func _code_panel(source: String) -> Control:
	var frame: PanelContainer = PanelContainer.new()
	frame.custom_minimum_size = Vector2(560, 0)
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var background: StyleBoxFlat = StyleBoxFlat.new()
	background.bg_color = Color("#1d1f23")
	background.content_margin_left = 22.0
	background.content_margin_right = 22.0
	background.content_margin_top = 18.0
	background.content_margin_bottom = 18.0
	frame.add_theme_stylebox_override("panel", background)
	var column: VBoxContainer = VBoxContainer.new()
	var text: Label = Label.new()
	# A Label collapses tabs, and the indentation is half of what this picture is showing.
	text.text = source.replace("	", "    ")
	text.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	text.add_theme_color_override("font_color", Color("#c8ccd4"))
	text.add_theme_font_size_override("font_size", 15)
	column.add_child(text)
	frame.add_child(column)
	return frame


## And the same file opened, through the importer any reader's open goes through.
static func _sheet_panel() -> Control:
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(SAMPLE_PATH)
	var style: EventSheetEditorStyle = EventSheetEditorStyle.new()
	style.ensure_defaults()
	# Narrower question lane than the default: this picture is about the ANSWERS as much as the
	# questions, and the arm bodies live on the other side of the divider.
	style.event_style.condition_lane_ratio = 0.18
	sheet.editor_style = style
	var viewport: EventSheetViewport = EventSheetViewport.new()
	viewport.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	viewport.size_flags_vertical = Control.SIZE_EXPAND_FILL
	viewport.set_ace_registry(EventSheetACERegistry.new())
	viewport.set_sheet(sheet)
	return viewport
