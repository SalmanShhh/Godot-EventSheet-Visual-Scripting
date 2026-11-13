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
