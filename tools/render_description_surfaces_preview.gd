# EventForge - draw the "one sheet, every description surface" figure from the docs guide (dev tool).
# Run NON-HEADLESS: a headless process has no renderer, and this is a picture of the real one.
#
#   godot --path . --script tools/render_description_surfaces_preview.gd
#
# The body below is the worked example the documentation guide carries as an `eventsheet` fence, so
# the picture and the page cannot drift: if the example stops lifting to rows, this harness draws
# nothing and the suite's figure gate has already failed.
@tool
extends SceneTree

## How many frames the figure is given to lay out before it is captured. Rows wrap on the first
## layout pass and the theme's fonts land on the second; capturing earlier photographs a half-built
## page.
const SETTLE_FRAMES: int = 8

## The width the figure is drawn at - wide enough that a normal row does not wrap.
const FIGURE_WIDTH: float = 980.0

const OUT_PATH := "res://docs/images/description-surfaces.png"

const BODY := """extends CharacterBody2D

## The player, and the one rule that makes a late jump still count.

## @ace_group(uid="ground_rules", name="Ground rules", description="Everything that decides whether the player is standing on something.")

## How long after leaving a ledge a jump is still allowed.
var coyote_time: float = 0.12

## The player walked off an edge without jumping.
signal slipped_off

func _ready() -> void:
	## The numbers this sheet is built on.
	coyote_time = 0.12
	# measured against the six-frame input buffer, do not round this
	velocity = Vector2.ZERO

## True while the ledge is still forgiving the player.
func still_forgiven(since_left_ground: float) -> bool:
	return since_left_ground < coyote_time
"""

var _host: Control = null
var _frames: int = 0


func _init() -> void:
	var root: Window = get_root()
	root.size = Vector2i(1040, 560)
	root.gui_embed_subwindows = true
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	if _host == null:
		_build()
		return
	_frames += 1
	if _frames < SETTLE_FRAMES:
		return
	_capture()
	quit(0)


func _build() -> void:
	var sheet: EventSheetResource = EventSheets.open_gd_as_sheet(BODY)
	if sheet == null or EventSheetDocFigures.lifted_row_count(sheet) <= 0:
		print("[preview] the example no longer lifts to rows - nothing to draw.")
		quit(1)
		return
	var figure: EventSheetDocFigure = EventSheetDocFigure.new()
	figure.set_caption("One sheet carrying every description surface at once")
	var wrapper: MarginContainer = EventSheetPopupUI.margined(figure)
	wrapper.set_anchors_preset(Control.PRESET_TOP_LEFT)
	wrapper.position = Vector2.ZERO
	wrapper.size = Vector2(FIGURE_WIDTH, 500.0)
	get_root().add_child(wrapper)
	if not figure.show_sheet(sheet):
		print("[preview] the figure refused the sheet.")
		quit(1)
		return
	_host = wrapper
	_frames = 0


func _capture() -> void:
	var image: Image = get_root().get_texture().get_image()
	var rect: Rect2i = Rect2i(Vector2i(_host.global_position), Vector2i(_host.size))
	rect = rect.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	if rect.size.x > 0 and rect.size.y > 0:
		image = image.get_region(rect)
	image.save_png(OUT_PATH)
	print("[preview] wrote %s" % OUT_PATH)
