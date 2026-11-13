# Godot EventSheets - one row's share of a weighted table: a bar and the percent beside it.
#
# The bar is Godot's own ProgressBar with the accent fill and no reading of its own; the percent is a
# label that never gets cut. When the cell is too narrow for both, the bar hides and the percent stays
# whole. The cell draws no outline and holds nothing but the number it was last given.
@tool
extends HBoxContainer

## The shortest the bar is worth drawing, in unscaled pixels.
const BAR_MIN_WIDTH: float = 28.0

var _bar: ProgressBar = null
var _percent: Label = null


func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	_bar.add_theme_stylebox_override("fill", EventSheetLookStyle.accent_fill())
	add_child(_bar)
	_percent = Label.new()
	_percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_percent.custom_minimum_size.x = EventSheetLookStyle.text_room("100.0%")
	_percent.add_theme_color_override("font_color", EventSheetLookStyle.quiet())
	add_child(_percent)


## The room the percent needs, so a column can be as wide as that and no narrower.
func _get_minimum_size() -> Vector2:
	var percent_size: Vector2 = _percent.get_combined_minimum_size() if _percent != null else Vector2.ZERO
	return Vector2(percent_size.x, maxf(percent_size.y, EventSheetLookStyle.field_height()))


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _bar != null:
		_bar.visible = size.x >= _percent.custom_minimum_size.x + EventSheetLookStyle.px(BAR_MIN_WIDTH) + EventSheetLookStyle.px(6.0)


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
