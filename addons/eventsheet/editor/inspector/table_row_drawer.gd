# Godot EventSheets - the "pick a row of a data table" drawer.
#
# An int that names a row of a table beside it: `eventsheet:table_row:<array property>:<name column>`.
# The Inspector shows a dropdown of that table's rows by their name column, with "row 1 of drops"
# under it; the file still stores the row's number, which is what `drops[drop_row]` reads in the game.
#
#   drop_row    Gem ▾
#               row 1 of drops
#
# A stored number past the table's end is never quietly moved onto another row: the dropdown shows
# it as it is, with a quiet amber edge and a line that says the row is gone. Without the plugin the
# property is Godot's plain number field.
#
# Loaded BY PATH from the attribute drawers the first time a property asks for it, so an editor boot
# and a sheet's first open never compile it.
@tool
extends EditorProperty

var _table: String = ""
var _name_column: String = ""
var _dropdown: OptionButton = null
var _offered: Dictionary = {}


func _init(table: String = "", name_column: String = "") -> void:
	_table = table
	_name_column = name_column
	_dropdown = EventSheetPopupUI.described_option()
	_dropdown.item_selected.connect(_on_picked)
	var field: VBoxContainer = EventSheetPopupUI.described_field(_dropdown)
	add_child(field)
	add_focusable(_dropdown)


func _on_picked(index: int) -> void:
	var picked: Variant = _dropdown.get_item_metadata(index)
	if picked is int and picked != get_edited_object().get(get_edited_property()):
		emit_changed(get_edited_property(), picked)


func _update_property() -> void:
	var edited: Object = get_edited_object()
	if edited == null:
		return
	var rows: Variant = edited.get(_table)
	var offered: Dictionary = choices(rows if rows is Array else [], _table, _name_column, int(edited.get(get_edited_property())))
	# The Inspector asks again on every refresh; refilling an unchanged list would close it while open.
	if offered == _offered:
		return
	_offered = offered
	fill(_dropdown, offered)


## The dropdown's choices for a stored number: {items: [{text, description, value}], selected, missing}.
## One item per row, named by its name column (or "row N" when that cell is empty), each described
## "row N of <table>". A stored number that points at no row gets one more item of its own, selected
## and marked `missing`, so the field shows the number it holds rather than another row's name.
## Static and UI-free, so a test pins what the dropdown offers.
static func choices(rows: Array, table: String, name_column: String, stored: int) -> Dictionary:
	var items: Array = []
	for index: int in range(rows.size()):
		var row_name: String = row_name_of(rows[index], name_column)
		items.append({"text": row_name if not row_name.is_empty() else EventSheetL10n.translate("row %d") % index,
			"description": EventSheetL10n.translate("row %d of %s") % [index, table], "value": index})
	if stored >= 0 and stored < rows.size():
		return {"items": items, "selected": stored, "missing": false}
	items.append({"text": EventSheetL10n.translate("row %d") % stored,
		"description": EventSheetL10n.translate("%s has no row %d: pick a row, or the number stays as it is.") % [table, stored],
		"value": stored})
	return {"items": items, "selected": items.size() - 1, "missing": true}


## A row's name: its name-column cell, from a Dictionary row or a Resource row alike.
static func row_name_of(row: Variant, name_column: String) -> String:
	var value: Variant = null
	if row is Dictionary:
		value = (row as Dictionary).get(name_column)
	elif row is Object:
		value = (row as Object).get(name_column)
	return str(value).strip_edges() if value != null else ""


## Puts `choices()` into a described dropdown, with the amber edge while the number points at no row.
static func fill(dropdown: OptionButton, offered: Dictionary) -> void:
	dropdown.clear()
	for item: Variant in offered.get("items", []):
		var entry: Dictionary = item
		EventSheetPopupUI.add_described_item(dropdown, str(entry.get("text", "")), str(entry.get("description", "")), entry.get("value"))
	dropdown.select(int(offered.get("selected", -1)))
	EventSheetPopupUI.follow_description(dropdown)
	if not bool(offered.get("missing", false)):
		dropdown.remove_theme_stylebox_override("normal")
		return
	var amber: Color = EventSheetPalette.COLOR_HEALTH_WARN
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(amber.r, amber.g, amber.b, 0.14)
	style.border_color = Color(amber.r, amber.g, amber.b, 0.7)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(EventSheetPalette.scaled_f(4.0))
	dropdown.add_theme_stylebox_override("normal", style)
