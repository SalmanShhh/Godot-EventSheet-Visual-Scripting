@tool
extends EventSheetInspectorLook

## Tag from a table's rows
## A menu of the tags a table's rows already use. You can still type a new one.

## The kinds of property this look can be put on.
@export var works_on: String = "String,StringName"
## Table
## The Array variable beside this one that holds the rows.
@export var table: String = ""
## Tags column
## The column whose cells hold the tags, comma separated.
@export var tags_column: String = "tags"

## The sentence the preview card says under a variable that wears this look.
const PREVIEW_SENTENCE := "Picked from the tags a table's rows carry."

const TAGS_PATH: String = "res://addons/eventsheet/editor/inspector/table_tags.gd"

var _edit: LineEdit = null
var _menu: PopupMenu = null
var _arrow: Button = null
var _note: Label = null


## A table that is not a variable name leaves the plain text field, as without this plugin.
func _can_draw() -> bool:
	return table.is_valid_identifier() and tags_column.is_valid_identifier()


func _look_built() -> void:
	var line: HBoxContainer = HBoxContainer.new()
	line.add_theme_constant_override("separation", 0)
	_edit = LineEdit.new()
	_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_edit.text_submitted.connect(_on_typed)
	_edit.focus_exited.connect(func() -> void: _on_typed(_edit.text))
	EventSheetLookStyle.join_field(_edit, true, false)
	line.add_child(_edit)
	_arrow = Button.new()
	_arrow.icon = EventSheetLookStyle.icon(&"GuiOptionArrow")
	_arrow.tooltip_text = EventSheetL10n.translate("The tags the rows already use.")
	EventSheetLookStyle.join_button(_arrow, false, true)
	_arrow.pressed.connect(_open_menu)
	line.add_child(_arrow)
	add_child(line)
	add_focusable(_edit)
	_menu = PopupMenu.new()
	_menu.id_pressed.connect(_on_chosen)
	add_child(_menu)


## The amber line under the field when the tag in it is on no row.
func _rows_under_field() -> Array[Control]:
	_note = EventSheetLookStyle.message_line("", EventSheetLookStyle.Tone.WARNING)
	_note.visible = false
	return [_note]


func _value_shown(value: Variant) -> void:
	var text: String = str(value)
	if _edit.text != text and not _edit.has_focus():
		_edit.text = text
	_edit.editable = not is_field_read_only()
	_arrow.disabled = is_field_read_only()
	_show_note(text)


func _rows() -> Array:
	var rows: Variant = field_object().get(table) if field_object() != null else null
	return rows if rows is Array else []


func _show_note(tag: String) -> void:
	if _note == null:
		return
	var tidy: String = tag.strip_edges()
	var missing: bool = not tidy.is_empty() and not load(TAGS_PATH).carries(_rows(), tags_column, tidy)
	_note.visible = missing
	_note.text = EventSheetL10n.translate("No row has the tag %s.") % tidy if missing else ""


## Fills the menu from the rows as they are now, so it is never stale, and opens it under the arrow.
func _open_menu() -> void:
	_menu.clear()
	var tags: PackedStringArray = load(TAGS_PATH).tags_in(_rows(), tags_column)
	if tags.is_empty():
		_menu.add_item(EventSheetL10n.translate("No row has a tag yet."), 0)
		_menu.set_item_disabled(0, true)
	for index: int in tags.size():
		_menu.add_item(tags[index], index)
	_menu.set_meta("tags", tags)
	EventSheetWindowPlacement.popup_at(_menu, Vector2i(_arrow.get_screen_position() + Vector2(0.0, _arrow.size.y)))


func _on_chosen(id: int) -> void:
	var tags: PackedStringArray = _menu.get_meta("tags", PackedStringArray())
	if id >= 0 and id < tags.size():
		_write(tags[id])


func _on_typed(text: String) -> void:
	_write(text)


func _write(text: String) -> void:
	_edit.text = text
	if text != str(field_value()):
		set_field_value(StringName(text) if field_type() == TYPE_STRING_NAME else text)
	_show_note(text)
