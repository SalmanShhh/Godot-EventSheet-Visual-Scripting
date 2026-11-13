@tool
class_name EventSheetInspectorLook
extends EditorProperty

## THE BASE OF AN INSPECTOR LOOK: a script that draws one property in Godot's own Inspector, in the
## place of the plain field. It is a thin layer over EditorProperty, so everything EditorProperty
## offers (`add_focusable`, `set_bottom_editor`, `emit_changed`, `_set_read_only`, ...) is still yours.
##
## A look is ONE script file in `res://eventsheet_addons/looks/` (your own) or in the plugin's own
## looks folder (the ones that ship). The file name is the look's name and the word the marker uses:
## a variable written `@export_custom(PROPERTY_HINT_NONE, "eventsheet:star_rating:5")` is drawn by
## `star_rating.gd`. Nothing is registered; dropping the file in the folder is the whole step.
##
## What the editor needs to list a look is read from the file's TEXT, never by running it:
##   - the first `##` lines after `extends` are the look's name and its hover,
##   - `@export var works_on: String = "int,float"` is the list of types it can be put on
##     (empty = any type),
##   - every other `@export var` is one question the Variable window asks, in file order; each is
##     written into the marker after the look's name, separated by ":".
##
## A look runs in the editor, so its file starts with `@tool`. It does nothing in a running game:
## the marker is only a hint string, and without this plugin the property is a plain field.
##
## Override these, not `_update_property` (the base needs that one to keep the value in step):
##   `_can_draw()`                          say no when the marker's values make no sense (the plain field stays)
##   `_look_built()`                        build the control, once, with the questions already answered
##   `_value_shown(value)`                  show this value; called on every refresh
##   `_value_changed_from_outside(value)`   the value moved without this look (undo, a script, another editor)
## and call `set_field_value(value)` when the person edits.

## What the marker carried after the look's name, split on ":" exactly as written. A look reads its
## questions from the variables it exports; this is only for a marker with a grammar of its own.
var marker_args: Array = []
var _built: bool = false
var _last_set: Variant = null
var _has_last_set: bool = false
var _read_only: bool = false


## Builds the control the first time anything needs it. Called by the base, never by a look.
func _build_once() -> void:
	if _built:
		return
	_built = true
	_look_built()


func _notification(what: int) -> void:
	# `_notification` runs at every level of inheritance, so a look's own `_ready` cannot shadow this.
	if what == NOTIFICATION_READY:
		_build_once()


func _set_read_only(read_only: bool) -> void:
	_read_only = read_only


func _update_property() -> void:
	_build_once()
	var value: Variant = field_value()
	if _has_last_set and str(value) != str(_last_set):
		_last_set = value
		_value_changed_from_outside(value)
	_value_shown(value)


## Whether the values the marker carried can be drawn. Asked once, after the questions are answered and
## before anything is built; a look that says no leaves Godot's plain field, as without this plugin.
func _can_draw() -> bool:
	return true


## The control is built here: add children, connect signals. Runs once.
func _look_built() -> void:
	pass


## Shows `value` in the control. Runs on every refresh, so it must not call `set_field_value`.
func _value_shown(_value: Variant) -> void:
	pass


## Rows the Inspector draws ABOVE this look's field, each in the value column. A row may carry the
## words for its label column as the meta `row_label`; with none it has no label. Asked once, right
## after the look is built and before it is shown, so keep a reference to anything that must follow
## the value.
func _rows_above_field() -> Array[Control]:
	return []


## Rows the Inspector draws directly UNDER this look's field, in the value column, as a note is.
func _rows_under_field() -> Array[Control]:
	return []


## The value moved without this look having set it. Runs before `_value_shown`.
func _value_changed_from_outside(_value: Variant) -> void:
	pass


## Writes a new value to the property. The Inspector owns undo, so this is one undo step.
func set_field_value(value: Variant) -> void:
	_last_set = value
	_has_last_set = true
	emit_changed(get_edited_property(), value)


## The property's value right now.
func field_value() -> Variant:
	var object: Object = get_edited_object()
	return object.get(get_edited_property()) if object != null else null


func field_name() -> StringName:
	return get_edited_property()


## The Variant type of the property's value (TYPE_INT, TYPE_FLOAT, ...).
func field_type() -> int:
	return typeof(field_value())


func field_object() -> Object:
	return get_edited_object()


## True when the Inspector has this property locked.
func is_field_read_only() -> bool:
	return _read_only


## The rules a look follows to read like Godot's own fields, so a look written on a sheet gets them
## without reaching into the style file itself.
func themed_panel() -> PanelContainer:
	return EventSheetLookStyle.themed_panel()


## A wrapping line of words in the editor's own font: `tone` is NOTE, WARNING or ERROR.
func message_line(text: String, tone: EventSheetLookStyle.Tone = EventSheetLookStyle.Tone.NOTE) -> Label:
	return EventSheetLookStyle.message_line(text, tone)


## A number field that is Godot's own spin slider with a label inside it.
func number_field(field_label: String = "") -> Range:
	return EventSheetLookStyle.number_field(field_label)


## A row of toggle buttons joined into one strip, the pressed one filled with the accent.
func joined_strip(buttons: Array) -> Container:
	return EventSheetLookStyle.joined_strip(buttons)


## The height of one Inspector field, from the editor theme.
func field_height() -> float:
	return EventSheetLookStyle.field_height()


## A 1x-authored size through the editor scale.
func px(amount: float) -> float:
	return EventSheetLookStyle.px(amount)


## Puts a wide part (a dial, a picture, a table) under the first row, in the value column, with the
## name staying level with the first row. `first_row` is the row of fields the name belongs to and
## `under` is the part below it; this adds both, so neither is added by the caller.
func add_under_field(first_row: Control, under: Control) -> void:
	add_child(first_row)
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_top", int(px(3.0)))
	margin.add_child(under)
	add_child(margin)
	set_bottom_editor(margin)
	draw_background = false
	var align: Callable = _align_under_field.bind(first_row, margin)
	sort_children.connect(align)
	draw.connect(align)


## How far in from the row's left edge the part under the first row starts: the width of the label
## column, which is what the first row's own width leaves of the whole. A first row with no width
## yet gives 0, so nothing is pushed in before the layout has run.
static func under_field_margin(row_width: float, first_width: float) -> int:
	return int(maxf(0.0, row_width - first_width)) if first_width > 0.0 else 0


func _align_under_field(first: Control, margin: MarginContainer) -> void:
	var left: int = under_field_margin(size.x, first.size.x)
	if margin.get_theme_constant("margin_left") != left:
		margin.add_theme_constant_override("margin_left", left)
