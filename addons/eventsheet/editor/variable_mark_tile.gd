@tool
extends Control
# Godot EventSheets - one variable mark tile, beside the option in the Variable window that puts it on
# the row.
#
# A variable row says each fact about the variable as a 20 px coloured tile (in the Inspector, kept in
# a range, has a description...). The window that edits those facts carries the SAME tile, in the same
# colour pair, beside each option that writes one, so ticking an option is visibly the same thing as
# the tile appearing on the row. The tile is painted by NativeVariableMarks.draw_badge_tile - the
# row's own painter - and its colours come from the event style of the sheet the window edits. Resting
# the pointer on it opens the row tile's hover card (title, sentence, code), the head bar's card.

const NativeVariableMarks := preload("res://addons/eventsheet/editor/interaction/native_variable_marks.gd")
const HEAD_CARD_PATH := "res://addons/eventsheet/editor/interaction/sheet_head_card.gd"

## The badge this tile draws (a NativeVariableMarks.BADGE_* id); "" draws nothing and takes no room.
var badge: String = "":
	set(value):
		badge = value
		visible = not value.is_empty()
		queue_redraw()
## Returns the EventSheetEventStyle whose tile colours this tile wears; unset (or returning null) wears
## the default style's.
var style_provider: Callable = Callable()
## The variable the window is editing, when it is one the sheet already has: its card then names its
## own limits and its own code line, as the row's card does.
var variable: LocalVariable = null

var _card: Control = null


func _init() -> void:
	custom_minimum_size = Vector2(NativeVariableMarks.TILE_SIZE, NativeVariableMarks.TILE_SIZE) \
		* EventSheetPalette.scaled_f(1.0)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	visible = false


## The tile's card, as the row's tile shows it: {} when there is no badge.
func card() -> Dictionary:
	return NativeVariableMarks.badge_card(badge, variable)


## The two colours this tile is painted in, [foreground, background].
func inks() -> Array[Color]:
	return NativeVariableMarks.badge_colors(_style(), badge)


func _draw() -> void:
	if badge.is_empty():
		return
	var side: float = minf(size.x, size.y)
	var rect := Rect2((size - Vector2(side, side)) * 0.5, Vector2(side, side))
	var pair: Array[Color] = inks()
	NativeVariableMarks.draw_badge_tile(self, rect, badge, pair[0], pair[1])


func _style() -> EventSheetEventStyle:
	if style_provider.is_valid():
		var provided: Variant = style_provider.call()
		if provided is EventSheetEventStyle:
			return provided as EventSheetEventStyle
	return null


func _on_mouse_entered() -> void:
	var words: Dictionary = card()
	if words.is_empty():
		return
	if _card == null:
		_card = (load(HEAD_CARD_PATH) as GDScript).new() as Control
		add_child(_card)
	_card.call("hover_word", words, get_global_rect())


func _on_mouse_exited() -> void:
	if _card != null:
		_card.call("leave_word")
