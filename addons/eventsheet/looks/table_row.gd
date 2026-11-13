@tool
extends EventSheetInspectorLook

## Pick a row of a data table
## A dropdown of the rows of a data table, shown by their name column. The file still stores the row's number.

## The kinds of property this look can be put on.
@export var works_on: String = "int"
## The Array variable beside this one that holds the rows, e.g. drops.
@export var table: String = ""
## The column of a row that names it.
@export var name_column: String = "name"

const DRAWER_PATH: String = "res://addons/eventsheet/editor/inspector/table_row_drawer.gd"

var _dropdown: OptionButton = null
var _offered: Dictionary = {}


## A table that is not a variable name leaves the plain number field, as without this plugin.
func _can_draw() -> bool:
	return table.is_valid_identifier()


func _look_built() -> void:
	_dropdown = EventSheetPopupUI.described_option()
	_dropdown.item_selected.connect(_on_picked)
	add_child(EventSheetPopupUI.described_field(_dropdown))
	add_focusable(_dropdown)


func _value_shown(value: Variant) -> void:
	if field_object() == null:
		return
	var rows: Variant = field_object().get(table)
	var offered: Dictionary = load(DRAWER_PATH).choices(rows if rows is Array else [], table, name_column, int(value))
	# The Inspector asks again on every refresh; refilling an unchanged list would close it while open.
	if offered == _offered:
		return
	_offered = offered
	load(DRAWER_PATH).fill(_dropdown, offered)


func _on_picked(index: int) -> void:
	var picked: Variant = _dropdown.get_item_metadata(index)
	if picked is int and picked != field_value():
		set_field_value(picked)
