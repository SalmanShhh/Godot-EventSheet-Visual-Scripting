# Godot EventSheets - one row's share of a weighted table: a bar and the percent beside it.
#
# The bar is Godot's own ProgressBar with the accent fill and no reading of its own; the percent is a
# label that never gets cut. The bar shows only while the table says it has room for it, and the
# percent stays whole either way. The cell draws no outline and holds nothing but the number it was
# last given.
#
# The cell never asks for more than it needs: in a grid it is a column that takes the room its widest
# percent wants (and the bar's, once the table says it is roomy), so the text columns beside it get
# every pixel that is left over rather than an equal share of it.
@tool
extends HBoxContainer

## The shortest the bar is worth drawing, in unscaled pixels.
const BAR_MIN_WIDTH: float = 28.0

var _bar: ProgressBar = null
var _percent: Label = null
## True while the table around the cell has room to spare for the bar.
var _roomy: bool = false


func _init() -> void:
	size_flags_horizontal = Control.SIZE_FILL
	custom_minimum_size.y = EventSheetLookStyle.field_height()
	add_theme_constant_override("separation", int(EventSheetLookStyle.px(6.0)))
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.min_value = 0.0
	_bar.max_value = 1.0
	_bar.step = 0.0
	_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_bar.custom_minimum_size.x = 0.0
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.visible = false
	_bar.add_theme_stylebox_override("fill", EventSheetLookStyle.accent_fill())
	add_child(_bar)
	_percent = Label.new()
	_percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_percent.custom_minimum_size.x = EventSheetLookStyle.font().get_string_size("99.9%", HORIZONTAL_ALIGNMENT_LEFT, -1.0, EventSheetLookStyle.font_size()).x
	_percent.add_theme_color_override("font_color", EventSheetLookStyle.quiet())
	add_child(_percent)


## Tells the cell whether the table around it has room for the bar; the bar then takes its own
## minimum width beside the percent, and no more.
func set_roomy(roomy: bool) -> void:
	if roomy == _roomy:
		return
	_roomy = roomy
	if _bar != null:
		_bar.custom_minimum_size.x = EventSheetLookStyle.px(BAR_MIN_WIDTH) if _roomy else 0.0
		_bar.visible = _roomy


## Shows `share` (0 to 1): the bar's fill and the percent in words.
func set_share(share: float) -> void:
	_bar.value = clampf(share, 0.0, 1.0)
	_percent.text = load("res://addons/eventsheet/editor/inspector/weight_math.gd").percent_text(share)
	tooltip_text = _percent.text


## The percent as the cell shows it, for a test to read.
func percent_text() -> String:
	return _percent.text


## True while the bar is drawn.
func bar_shown() -> bool:
	return _bar.visible
