# Godot EventSheets - a button that rolls a weighted table a thousand times and shows how often each
# row came up.
#
# The counts are worked out from the weights alone, so the line under them says what they leave out.
# Nothing is stored: the counts live in this control and clear the moment the rows change.
@tool
extends VBoxContainer

## How many picks one press makes.
const ROLLS: int = 1000
const MATH_PATH: String = "res://addons/eventsheet/editor/inspector/weight_math.gd"

var _button: Button = null
var _panel: PanelContainer = null
var _lines: VBoxContainer = null
var _rows: Array = []
var _weight_column: String = ""
var _label_column: String = ""
var _counts: PackedInt32Array = PackedInt32Array()
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", int(EventSheetLookStyle.px(3.0)))
	_button = Button.new()
	_button.text = EventSheetL10n.translate("Roll 1,000 times")
	_button.tooltip_text = EventSheetL10n.translate("Picks from the rows 1,000 times in proportion to their weights and counts how often each came up.")
	_button.pressed.connect(roll)
	add_child(_button)
	_panel = EventSheetLookStyle.themed_panel()
	_lines = VBoxContainer.new()
	_panel.add_child(_lines)
	add_child(_panel)
	_panel.visible = false
	_rng.randomize()


## Gives the control the rows it rolls. A change in the rows clears the counts it showed.
func set_rows(rows: Array, weight_column: String, label_column: String) -> void:
	var changed: bool = rows != _rows or weight_column != _weight_column
	_rows = rows.duplicate(true)
	_weight_column = weight_column
	_label_column = label_column
	if changed:
		_counts = PackedInt32Array()
		_show_counts()
	var math: GDScript = load(MATH_PATH)
	_button.disabled = float(math.total(_rows, _weight_column)) <= 0.0


## Rolls the rows `ROLLS` times from the weights and shows the counts.
func roll() -> void:
	_counts = load(MATH_PATH).roll(_rows, _weight_column, ROLLS, _rng)
	_show_counts()


## The rolls as shown: one "name count" per row, in row order; empty before the first roll.
func count_lines() -> PackedStringArray:
	var shown: PackedStringArray = PackedStringArray()
	if _counts.is_empty():
		return shown
	var math: GDScript = load(MATH_PATH)
	for index: int in _rows.size():
		shown.append("%s %d" % [math.row_name(_rows[index], _label_column, index), _counts[index]])
	return shown


func rolled() -> bool:
	return not _counts.is_empty()


func button_disabled() -> bool:
	return _button.disabled


func _show_counts() -> void:
	for old: Node in _lines.get_children():
		_lines.remove_child(old)
		old.queue_free()
	_panel.visible = not _counts.is_empty()
	if _counts.is_empty():
		return
	for line: String in count_lines():
		var label: Label = Label.new()
		label.text = line
		_lines.add_child(label)
	_lines.add_child(EventSheetLookStyle.message_line(EventSheetL10n.translate("Weights only. Rules the game adds, such as pity, are not counted.")))
