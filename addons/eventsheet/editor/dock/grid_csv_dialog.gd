@tool
class_name EventSheetGridCSVDialog
extends RefCounted
# "Export Grid to CSV..." / "Import Grid from CSV..." - the grid round trip on the variable menu.
#
# A grid variable (one with the Inspector's table drawer) can be handed to a spreadsheet and taken
# back: pick the .csv, optionally point at the .tres data asset that holds the real rows, press the
# button, and READ what happened. That last part is the point - the result line is the actual
# outcome, naming the file, the row count and, when a write fails, the Error by name. A silent
# "nothing happened" is exactly what this dialog exists to abolish.
#
# TWO TARGETS, ONE FORM. With a data-asset path, the rows come from (and go back into) that .tres -
# under the property NAMED in the form, because a resource's grid property is rarely spelled like
# the sheet variable pointing at it - saved with ResourceSaver and reported by its Error. With the
# path left blank the sheet's OWN declared rows are the grid, and an import lands through the dock's
# undo funnel like every other sheet edit - so a bad CSV is one Ctrl+Z away.
#
# All the file work lives in EventSheetGridCSV (columns, the quote-aware codec, the outcomes); this
# is the form around it, and `run()` is the tested surface - the suite drives the real button path.

var _dock: Control = null
var _dialog: AcceptDialog = null
var _mode: String = "export"
var _variable_name: String = ""
var _attributes: Dictionary = {}
var _grid_label: Label = null
var _asset_edit: LineEdit = null
var _property_edit: LineEdit = null
var _csv_edit: LineEdit = null
var _separator_option: OptionButton = null
var _result_label: Label = null
## The variable the fields currently hold paths for. One dialog serves every grid on the menu, so a
## path typed for `loot` must not still be sitting there when the form reopens on `drops` - that is
## how an export overwrites the wrong file while the header reads the right variable's name.
var _filled_for: String = ""


func init(dock: Control) -> void:
	_dock = dock


## Opens the form for one grid variable. `mode` is "export" or "import".
func open(mode: String, entry: Dictionary) -> void:
	_mode = "import" if mode == "import" else "export"
	_variable_name = str(entry.get("name", ""))
	_attributes = entry.get("attributes", {}) if entry.get("attributes") is Dictionary else {}
	if _variable_name.is_empty():
		_dock._set_status("Right-click a grid variable to move it between a spreadsheet and the sheet.", true)
		return
	if not is_grid_variable(entry):
		_dock._set_status("\"%s\" is not a grid - only a variable with the table drawer has columns to line up." % _variable_name, true)
		return
	_build_dialog()
	_dialog.title = "Export Grid to CSV" if _mode == "export" else "Import Grid from CSV"
	_dialog.ok_button_text = "Write the CSV" if _mode == "export" else "Read the CSV"
	var columns: Array = grid_columns()
	var column_names: PackedStringArray = PackedStringArray()
	for column: Variant in columns:
		column_names.append(str((column as Dictionary).get("name", "")))
	_grid_label.text = "%s - columns: %s" % [_variable_name, ", ".join(column_names) if not column_names.is_empty() else "(none declared)"]
	if _filled_for != _variable_name or _csv_edit.text.strip_edges().is_empty():
		# A different grid means different files: start from ITS defaults rather than leaving the
		# last grid's paths in a form whose heading now names this one.
		_csv_edit.text = "res://%s.csv" % _variable_name
		_asset_edit.text = ""
		_property_edit.text = _variable_name
		_filled_for = _variable_name
	_result_label.text = ""
	if _dock.is_inside_tree():
		_dialog.popup_centered(Vector2i(560, 380))


## True when this variable really is a grid (the table drawer with columns) - the gate on both
## menu items, so neither ever opens on a variable that has no columns to line up.
static func is_grid_variable(entry: Dictionary) -> bool:
	var attributes: Dictionary = entry.get("attributes", {}) if entry.get("attributes") is Dictionary else {}
	return not EventSheetGridCSV.columns_from_attributes(attributes).is_empty()


func _build_dialog() -> void:
	if _dialog != null:
		return
	_dialog = AcceptDialog.new()
	_dialog.add_cancel_button("Cancel")
	_dialog.confirmed.connect(func() -> void: run())
	var content: VBoxContainer = EventSheetPopupUI.form_box()
	content.add_child(EventSheetPopupUI.hint_label("A grid is rows of data, so a spreadsheet can edit it: the first CSV line is the column names, one line per row. Point at a .tres data asset to move ITS rows, or leave that blank to move the rows this sheet declares."))
	var form: VBoxContainer = EventSheetPopupUI.form_box()
	_grid_label = EventSheetPopupUI.hint_label("")
	form.add_child(_grid_label)
	_asset_edit = LineEdit.new()
	_asset_edit.placeholder_text = "res://data/loot_table.tres  (blank = this sheet's own rows)"
	_asset_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var asset_row: HBoxContainer = HBoxContainer.new()
	asset_row.add_theme_constant_override("separation", 4)
	asset_row.add_child(_asset_edit)
	var browse_asset: Button = Button.new()
	browse_asset.text = "Browse…"
	browse_asset.pressed.connect(func() -> void: _browse_into(_asset_edit, "*.tres", "Data asset"))
	asset_row.add_child(browse_asset)
	form.add_child(EventSheetPopupUI.form_row("Data asset", asset_row,
		EventSheetPopupUI.LABEL_MIN_WIDTH, "The .tres holding the rows. Leave it blank to use the rows declared in this sheet."))
	_property_edit = LineEdit.new()
	_property_edit.placeholder_text = "entries"
	_property_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form.add_child(EventSheetPopupUI.form_row("Grid on it", _property_edit,
		EventSheetPopupUI.LABEL_MIN_WIDTH, "Which grid property on that data asset. It starts as this variable's name; a resource usually spells its own grid differently (entries, rows, drops)."))
	_csv_edit = LineEdit.new()
	_csv_edit.placeholder_text = "res://balance/loot.csv"
	_csv_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dialog.register_text_enter(_csv_edit)
	var csv_row: HBoxContainer = HBoxContainer.new()
	csv_row.add_theme_constant_override("separation", 4)
	csv_row.add_child(_csv_edit)
	var browse_csv: Button = Button.new()
	browse_csv.text = "Browse…"
	browse_csv.pressed.connect(func() -> void: _browse_into(_csv_edit, "*.csv", "Spreadsheet"))
	csv_row.add_child(browse_csv)
	form.add_child(EventSheetPopupUI.form_row("Spreadsheet", csv_row))
	_separator_option = OptionButton.new()
	for option: Dictionary in EventSheetGridCSV.SEPARATOR_OPTIONS:
		_separator_option.add_item(str(option.get("label", "")))
	_separator_option.select(0)
	form.add_child(EventSheetPopupUI.form_row("Separator", _separator_option,
		EventSheetPopupUI.LABEL_MIN_WIDTH, "What separates the columns in that file. Comma is what a spreadsheet exports by default."))
	content.add_child(EventSheetPopupUI.titled_card("Which grid, which file", form))
	_result_label = EventSheetPopupUI.hint_label("")
	content.add_child(EventSheetPopupUI.titled_card("What happened", _result_label))
	_dialog.add_child(EventSheetPopupUI.margined(content))
	EventSheetL10n.apply_to(_dialog)
	_dock.add_child(_dialog)


## The picker is built lazily: EditorFileDialog is editor-only, so the form itself never depends
## on it and stays buildable headless.
func _browse_into(edit: LineEdit, filter: String, label: String) -> void:
	if not Engine.is_editor_hint() or not _dock.is_inside_tree():
		return
	var picker: EditorFileDialog = EditorFileDialog.new()
	picker.access = EditorFileDialog.ACCESS_RESOURCES
	picker.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE if filter == "*.csv" and _mode == "export" else EditorFileDialog.FILE_MODE_OPEN_FILE
	picker.add_filter(filter, label)
	picker.file_selected.connect(func(path: String) -> void:
		edit.text = path
		picker.queue_free())
	picker.canceled.connect(func() -> void: picker.queue_free())
	_dialog.add_child(picker)
	picker.popup_file_dialog()


## The separator character the picker currently means.
func current_separator() -> String:
	var index: int = _separator_option.selected if _separator_option != null else 0
	if index < 0 or index >= EventSheetGridCSV.SEPARATOR_OPTIONS.size():
		index = 0
	return str(EventSheetGridCSV.SEPARATOR_OPTIONS[index].get("key", ","))


## The grid's columns: the variable's declared schema, falling back to the shape of the rows it
## already holds (a grid whose declaration travelled without its columns still round-trips).
func grid_columns() -> Array:
	var columns: Array = EventSheetGridCSV.columns_from_attributes(_attributes)
	if columns.is_empty():
		columns = EventSheetGridCSV.columns_from_rows(sheet_rows())
	return columns


## The rows this sheet declares for the variable (the grid's default value).
func sheet_rows() -> Array:
	if _dock == null or _dock._current_sheet == null:
		return []
	var declaration: Dictionary = EventSheetVariableRetype.find_declaration(_dock._current_sheet, _variable_name)
	var default_value: Variant = declaration.get("default", null)
	return default_value as Array if default_value is Array else []


## Runs the button: export or import, against the data asset when one is named and against the
## sheet's own rows when it is not. Returns the outcome {"ok", "message"} the result line shows.
func run() -> Dictionary:
	var csv_path: String = _csv_edit.text.strip_edges() if _csv_edit != null else ""
	var asset_path: String = _asset_edit.text.strip_edges() if _asset_edit != null else ""
	var separator: String = current_separator()
	var outcome: Dictionary = {}
	if not asset_path.is_empty():
		# The property the rows live under on that resource - named in the form, because a data
		# asset's grid is rarely spelled like the sheet variable that points at it.
		var property_name: String = _property_edit.text.strip_edges() if _property_edit != null else ""
		if property_name.is_empty():
			property_name = _variable_name
		if _mode == "export":
			outcome = EventSheetGridCSV.export_to_csv(asset_path, property_name, csv_path, separator)
		else:
			outcome = EventSheetGridCSV.import_from_csv(csv_path, asset_path, property_name, separator)
	elif _mode == "export":
		outcome = EventSheetGridCSV.write_csv(csv_path, sheet_rows(), grid_columns(), separator)
	else:
		outcome = _import_into_sheet(csv_path, separator)
	if _result_label != null:
		_result_label.text = str(outcome.get("message", ""))
	if _dock != null:
		_dock._set_status(str(outcome.get("message", "")), not bool(outcome.get("ok", false)))
	return outcome


## Import with no data asset named: the CSV becomes the rows the SHEET declares, through the undo
## funnel, so a wrong file is one Ctrl+Z away.
func _import_into_sheet(csv_path: String, separator: String) -> Dictionary:
	var read: Dictionary = EventSheetGridCSV.read_csv(csv_path, grid_columns(), separator)
	if not bool(read.get("ok", false)):
		return read
	var rows: Array = read.get("rows", [])
	var variable_name: String = _variable_name
	var declared: Array = sheet_rows()
	var changed: bool = _dock._perform_undoable_sheet_edit("Import Grid from CSV", func() -> bool:
		return write_sheet_rows(_dock._current_sheet, variable_name, rows))
	if not changed:
		if declared == rows:
			# Nothing to do is not an edit. Committing one anyway puts a do-nothing step on the undo
			# stack, so the next Ctrl+Z appears to do nothing and the real edit needs a second press.
			return {"ok": true, "rows": rows.size(), "message": "%s Those are already the rows %s declares - nothing changed." % [str(read.get("message", "")), variable_name]}
		return {"ok": false, "message": "Could not write those rows into %s - is it still declared in this sheet?" % variable_name}
	_dock._mark_dirty("Imported %d row(s) into %s." % [rows.size(), variable_name])
	return {"ok": true, "rows": rows.size(), "message": "%s Into this sheet's %s - Undo puts the old rows back." % [str(read.get("message", "")), variable_name]}


## Writes rows into the variable's declaration on the LIVE sheet (the funnel's mutation - it must
## re-fetch, never hold a resource from before the commit). True when the variable was found AND the
## rows really differ: rows identical to the ones already declared are no edit at all, and reporting
## one would push a do-nothing entry onto the undo stack.
static func write_sheet_rows(sheet: EventSheetResource, variable_name: String, rows: Array) -> bool:
	if sheet == null:
		return false
	if sheet.variables.has(variable_name):
		var descriptor: Dictionary = sheet.variables[variable_name] if sheet.variables[variable_name] is Dictionary else {}
		if descriptor.get("default", null) == rows:
			return false
		descriptor["default"] = rows.duplicate(true)
		sheet.variables[variable_name] = descriptor
		return true
	var declaration: Dictionary = EventSheetVariableRetype.find_declaration(sheet, variable_name)
	var variable: LocalVariable = declaration.get("resource", null)
	if variable == null or variable.default_value == rows:
		return false
	variable.default_value = rows.duplicate(true)
	return true
