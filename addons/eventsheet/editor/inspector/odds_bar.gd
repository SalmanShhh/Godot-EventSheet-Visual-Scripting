# Godot EventSheets - the odds of a weighted table as one bar and one line of words.
#
# The bar is one block split into a piece per row that has a weight, in row order, the largest piece
# in the accent colour and the others in the resting grey, with a hairline gap between pieces and no
# outline. Under it one wrapping line names the biggest few. A table where no row has a weight says
# so in amber instead of drawing a bar. The control holds nothing but what it was last given.
@tool
extends VBoxContainer

## How many names the line under the bar speaks before it says "and N more".
const NAMED_ROWS: int = 3
## The gap between two pieces of the bar, at 1x.
const GAP: float = 1.0

const MATH_PATH: String = "res://addons/eventsheet/editor/inspector/weight_math.gd"

var _bar: Control = null
var _line: Label = null
var _empty: Label = null
var _shares: PackedFloat64Array = PackedFloat64Array()
var _biggest: int = -1


func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", int(EventSheetLookStyle.px(3.0)))
	_bar = Control.new()
	_bar.custom_minimum_size.y = EventSheetLookStyle.field_height()
	_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bar.draw.connect(_draw_bar)
	add_child(_bar)
	_line = EventSheetLookStyle.message_line("")
	add_child(_line)
	_empty = EventSheetLookStyle.message_line(EventSheetL10n.translate("No row has a weight above 0, so nothing can be picked."), EventSheetLookStyle.Tone.WARNING)
	add_child(_empty)
	set_rows([], "", "")


## Shows the odds of `rows` worked out from `weight_column`, naming rows by `label_column`. With no
## rows at all the control hides itself; with rows and no weight it says nothing can be picked.
func set_rows(rows: Array, weight_column: String, label_column: String) -> void:
	var math: GDScript = load(MATH_PATH)
	_shares = math.shares(rows, weight_column)
	_biggest = math.largest(rows, weight_column)
	var drawn: bool = _biggest >= 0
	visible = not rows.is_empty()
	_bar.visible = drawn
	_line.visible = drawn
	_empty.visible = not rows.is_empty() and not drawn
	_line.text = math.odds_line(rows, weight_column, label_column, NAMED_ROWS, EventSheetL10n.translate("and %d more")) if drawn else ""
	_bar.queue_redraw()


## The share of each piece the bar draws, in row order, for a test to read.
func shares_drawn() -> PackedFloat64Array:
	return _shares if _biggest >= 0 else PackedFloat64Array()


## The line of words under the bar.
func line_text() -> String:
	return _line.text if _line.visible else ""


## The amber sentence for a table nothing can be picked from, or "" when the bar shows.
func empty_text() -> String:
	return _empty.text if _empty.visible else ""


func _draw_bar() -> void:
	if _biggest < 0:
		return
	var gap: float = maxf(1.0, EventSheetLookStyle.px(GAP))
	var pieces: int = 0
	for share: float in _shares:
		if share > 0.0:
			pieces += 1
	var room: float = maxf(0.0, _bar.size.x - gap * float(pieces - 1))
	var left: float = 0.0
	for index: int in _shares.size():
		if _shares[index] <= 0.0:
			continue
		var width: float = room * _shares[index]
		_bar.draw_rect(Rect2(left, 0.0, width, _bar.size.y), EventSheetLookStyle.accent() if index == _biggest else EventSheetLookStyle.rest())
		left += width + gap
