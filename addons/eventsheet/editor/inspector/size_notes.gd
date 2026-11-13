# Godot EventSheets - what sits under a width and height shown on one row: a strip of common sizes
# and one line of what the texture costs.
#
# The strip is Godot's own toggle buttons joined into one, the one equal to both numbers filled with
# the accent. A click on a size asks for both numbers to become it; this control only says so, the
# row writes both as one undo step. The line works the cost out as 4 bytes a pixel and says "about",
# because the real figure depends on the texture's format and the renderer. Nothing here is stored.
@tool
extends VBoxContainer

## A size was clicked: the row sets width and height to it.
signal size_picked(size: int)

## Bytes a pixel in the plain colour format the cost is worked out from.
const BYTES_PER_PIXEL: int = 4

var _sizes: PackedInt32Array = PackedInt32Array()
var _buttons: Array[Button] = []
var _strip: Container = null
var _cost: Label = null
var _syncing: bool = false


func _init(sizes: PackedInt32Array = PackedInt32Array()) -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", int(EventSheetLookStyle.px(3.0)))
	_sizes = sizes
	if not _sizes.is_empty():
		var flow: HFlowContainer = HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 0)
		flow.add_theme_constant_override("v_separation", int(EventSheetLookStyle.px(3.0)))
		for size: int in _sizes:
			var button: Button = Button.new()
			button.text = str(size)
			button.toggle_mode = true
			button.tooltip_text = EventSheetL10n.translate("Set both to %d.") % size
			button.toggled.connect(_on_toggled.bind(size, button))
			_buttons.append(button)
		_strip = EventSheetLookStyle.joined_strip(_buttons, flow)
		add_child(_strip)
	_cost = EventSheetLookStyle.message_line("")
	add_child(_cost)


## The line under the strip: "512 x 512 px, about 1.00 MiB of video memory." in Godot's own size wording.
static func cost_text(width: int, height: int) -> String:
	return EventSheetL10n.translate("%d x %d px, about %s of video memory.") % [width, height, String.humanize_size(maxi(0, width) * maxi(0, height) * BYTES_PER_PIXEL)]


## The size that is filled for a pair: the one both numbers equal, or 0 when none is.
static func pressed_size(width: int, height: int, sizes: PackedInt32Array) -> int:
	return width if width == height and sizes.has(width) else 0


## Shows the pair as it stands: the matching size filled and the cost worked out.
func show_pair(width: int, height: int) -> void:
	_syncing = true
	var filled: int = pressed_size(width, height, _sizes)
	for index: int in _buttons.size():
		_buttons[index].set_pressed_no_signal(_sizes[index] == filled)
	_syncing = false
	_cost.text = cost_text(width, height)


## The text of the cost line, for a test to read.
func cost_line() -> String:
	return _cost.text


## How many sizes the strip offers.
func size_count() -> int:
	return _buttons.size()


func _on_toggled(on: bool, size: int, button: Button) -> void:
	if _syncing:
		return
	# A click on the filled size would turn it off; the pair stays on it, and the next refresh fills it.
	if not on:
		button.set_pressed_no_signal(true)
		return
	size_picked.emit(size)
