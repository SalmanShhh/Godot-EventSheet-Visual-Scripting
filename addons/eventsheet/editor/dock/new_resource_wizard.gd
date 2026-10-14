@tool
class_name EventSheetNewResourceWizard
extends RefCounted

# The New data table window (Sheet > New Data Table…).
#
# A data table is a Custom Resource holding a list of rows: loot drops, waves, dialogue lines, shop
# items. The window is filled in like a spreadsheet - name what one row is, click a column header to
# set what kind of thing that column holds, type into the cells - and Insert writes TWO ordinary
# files: the Resource script (its exported grid is the Inspector's table drawer, built by
# EventSheets.resource_grid, the one owner of that syntax) and a .tres holding the rows typed here.
# Any sheet can then load the .tres and read its rows.
#
# THE MODEL IS PLAIN DATA. `columns` is [{name, type, options}] in the table drawer's own shape and
# `rows` is the Array of Dictionary rows the drawer stores, so the CSV round trip
# (EventSheetGridCSV) and the drawer read them as they are. Every edit goes through the model and
# the grid is redrawn from it, which is what lets the suite drive the whole window headless.
#
# The grid is a Tree: a cell is typed into, ticked, or picked from a dropdown, depending on its
# column's kind. Godot's Tree has no column resizing of its own, so a drag on a column's right edge
# sets that column's width here, and a double-click on the edge fits the column to its contents.

## How near (px, before display scaling) a column's right edge the pointer must be to drag it.
const EDGE_GRAB := 4.0
## The narrowest a column can be dragged, and the width a new column starts at.
const MIN_COLUMN_WIDTH := 60.0
const START_COLUMN_WIDTH := 130.0

## The table drawer's columns, [{name, type, options}], in order.
var columns: Array = []
## The rows typed so far, one Dictionary per row keyed by column name.
var rows: Array = []
## Which column the panel beside the grid is about.
var selected_column: int = 0

var _dock: Control = null
var _dialog: ConfirmationDialog = null
var _name_edit: LineEdit = null
var _row_edit: LineEdit = null
var _caption_label: Label = null
var _table: Tree = null
var _counts_label: Label = null
var _column_card_title: Label = null
var _column_name_edit: LineEdit = null
var _kind_option: OptionButton = null
var _choices_row: Control = null
var _choices_edit: LineEdit = null
var _default_label: Label = null
var _warn_check: CheckBox = null
var _help_strip: EventSheetPopupUI.HelpStrip = null
var _files_label: Label = null
## Under the column's name: a name that cannot be a column. Under the grid: what Insert or an
## import has to say, on this window rather than on the dock behind it.
var _column_note: EventSheetPopupUI.StateNote = null
var _problem_label: EventSheetPopupUI.StateNote = null
var _widths: Array[float] = []
var _drag_column: int = -1
var _drag_from: float = 0.0
var _drag_width: float = 0.0
var _last_title_click: Array = [-1, 0]


func init(dock: Control) -> void:
	_dock = dock


## Opens the window fresh: one Text column called name and no rows, building it on first use.
func open() -> void:
	_build_dialog()
	_name_edit.text = ""
	_row_edit.text = ""
	_warn_check.button_pressed = false
	columns = [{"name": "name", "type": "String"}]
	_widths = [START_COLUMN_WIDTH]
	rows = []
	selected_column = 0
	show_problem("")
	_refresh()
	if _dialog.is_inside_tree():  # headless tests: fields reset, no window to pop
		_dialog.popup_centered(Vector2i(Vector2(EventSheetPalette.scaled_f(1040.0), EventSheetPalette.scaled_f(640.0))))
		_row_edit.grab_focus()


## The kinds a column can hold, as [type, label, description]: the table drawer's cell types.
static func kinds() -> Array:
	return [
		["String", EventSheetL10n.translate("Text"), EventSheetL10n.translate("Words: a name, a line of dialogue, a file path.")],
		["int", EventSheetL10n.translate("Number (whole)"), EventSheetL10n.translate("A whole number: an amount, a count, a level.")],
		["float", EventSheetL10n.translate("Number"), EventSheetL10n.translate("A number that can have a fraction: a weight, a speed, a chance.")],
		["bool", EventSheetL10n.translate("True/false"), EventSheetL10n.translate("A tick: yes or no.")],
		["enum", EventSheetL10n.translate("Choice"), EventSheetL10n.translate("One of a list of words you name; the cell is a dropdown.")],
		["color", EventSheetL10n.translate("Colour"), EventSheetL10n.translate("A colour, picked from a swatch in the Inspector.")],
		["key", EventSheetL10n.translate("Translation key"), EventSheetL10n.translate("Text a translator turns into each language; the cell holds its key.")],
	]


static func _kind(type: String) -> Array:
	for kind: Array in kinds():
		if kind[0] == type:
			return kind
	return kinds()[0]


func _build_dialog() -> void:
	if _dialog != null:
		return
	var parts: Dictionary = EventSheetPopupUI.panel_window(EventSheetL10n.translate("New data table"), Vector2i.ZERO,
		_dock, EventSheetL10n.translate("Insert"), _on_create)
	_dialog = parts["window"]
	_dialog.min_size = Vector2i(Vector2(EventSheetPalette.scaled_f(760.0), EventSheetPalette.scaled_f(520.0)))
	var content: VBoxContainer = parts["box"]

	var head: HBoxContainer = HBoxContainer.new()
	head.add_theme_constant_override("separation", int(EventSheetPalette.scaled_f(16.0)))
	content.add_child(head)
	var about: VBoxContainer = VBoxContainer.new()
	about.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(about)
	about.add_child(EventSheetPopupUI.section_header(EventSheetL10n.translate("Data table · a Custom Resource")))
	about.add_child(EventSheetPopupUI.hint_label(EventSheetL10n.translate("A list of entries you fill in like a spreadsheet, saved as a .tres file any sheet can read: loot, waves, dialogue lines, shop items.")))
	var names: VBoxContainer = EventSheetPopupUI.form_box()
	head.add_child(names)
	_name_edit = LineEdit.new()
	_name_edit.custom_minimum_size.x = EventSheetPalette.scaled_f(220.0)
	_name_edit.text_changed.connect(func(_t: String) -> void: _refresh_names())
	names.add_child(EventSheetPopupUI.form_row(EventSheetL10n.translate("Name"), _name_edit))
	_row_edit = LineEdit.new()
	_row_edit.placeholder_text = "LootDrop"
	_row_edit.text_changed.connect(func(_t: String) -> void: _refresh_names())
	names.add_child(EventSheetPopupUI.form_row(EventSheetL10n.translate("One row is a"), _row_edit))

	var body: HBoxContainer = HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", int(EventSheetPalette.scaled_f(16.0)))
	content.add_child(body)
	var grid_box: VBoxContainer = VBoxContainer.new()
	grid_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(grid_box)
	var caption: HBoxContainer = HBoxContainer.new()
	grid_box.add_child(caption)
	_caption_label = Label.new()
	_caption_label.add_theme_color_override("font_color", EventSheetPopupUI.text_color())
	caption.add_child(_caption_label)
	caption.add_child(_line_label(EventSheetL10n.translate("click a header to set its kind, a cell to type · Delete removes the selected row")))
	_table = Tree.new()
	_table.hide_root = true
	_table.column_titles_visible = true
	_table.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_table.custom_minimum_size.y = EventSheetPalette.scaled_f(150.0)
	_table.item_edited.connect(_on_cell_edited)
	_table.cell_selected.connect(func() -> void: _select_column(_table.get_selected_column() - 1))
	_table.column_title_clicked.connect(_on_title_clicked)
	_table.gui_input.connect(_on_table_input)
	grid_box.add_child(_table)
	var grid_buttons: HBoxContainer = HBoxContainer.new()
	grid_box.add_child(grid_buttons)
	for button_spec: Array in [[EventSheetL10n.translate("+ Row"), add_row],
			[EventSheetL10n.translate("Import from CSV…"), _pick_csv.bind(false)],
			[EventSheetL10n.translate("Export to CSV…"), _pick_csv.bind(true)]]:
		var button: Button = Button.new()
		button.text = button_spec[0]
		button.pressed.connect(button_spec[1])
		grid_buttons.add_child(button)
	_counts_label = _line_label("")
	_counts_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	grid_buttons.add_child(_counts_label)

	var column_box: VBoxContainer = EventSheetPopupUI.form_box()
	var column_card: PanelContainer = EventSheetPopupUI.panel_section(column_box)
	column_card.custom_minimum_size.x = EventSheetPalette.scaled_f(300.0)
	body.add_child(column_card)
	_column_card_title = EventSheetPopupUI.section_header("")
	column_box.add_child(_column_card_title)
	_column_name_edit = LineEdit.new()
	_column_name_edit.text_changed.connect(func(text: String) -> void: _show_column_note(rename_column(selected_column, text)))
	column_box.add_child(EventSheetPopupUI.form_row(EventSheetL10n.translate("Name"), _column_name_edit, 96.0))
	_column_note = EventSheetPopupUI.StateNote.new(260.0)
	column_box.add_child(_column_note)
	_kind_option = EventSheetPopupUI.described_option()
	for kind: Array in kinds():
		EventSheetPopupUI.add_described_item(_kind_option, kind[1], kind[2], kind[0])
	_kind_option.item_selected.connect(func(index: int) -> void: set_kind(selected_column, str(_kind_option.get_item_metadata(index))))
	column_box.add_child(EventSheetPopupUI.form_row(EventSheetL10n.translate("Kind"), _kind_option, 96.0))
	_choices_edit = LineEdit.new()
	_choices_edit.placeholder_text = "coin, gem, heal, key"
	_choices_edit.text_changed.connect(func(text: String) -> void: set_choices(selected_column, text))
	_choices_row = EventSheetPopupUI.form_row(EventSheetL10n.translate("Choices"), _choices_edit, 96.0)
	column_box.add_child(_choices_row)
	_default_label = Label.new()
	_default_label.add_theme_color_override("font_color", EventSheetPopupUI.text_color())
	column_box.add_child(EventSheetPopupUI.form_row(EventSheetL10n.translate("New rows get"), _default_label, 96.0))
	var remove_button: Button = Button.new()
	remove_button.text = EventSheetL10n.translate("Remove column")
	remove_button.pressed.connect(func() -> void: remove_column(selected_column))
	column_box.add_child(remove_button)

	_warn_check = CheckBox.new()
	_warn_check.text = EventSheetL10n.translate("Warn in the Inspector when a row is missing a value")
	_warn_check.toggled.connect(func(_on: bool) -> void: _refresh_reading())
	content.add_child(_warn_check)
	_problem_label = EventSheetPopupUI.StateNote.new(600.0)
	content.add_child(_problem_label)
	_help_strip = EventSheetPopupUI.help_strip("", "", "", "", 600.0)
	_help_strip.in_code_value.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	content.add_child(_help_strip)
	_help_strip.follow(_warn_check, EventSheetL10n.translate("Warn in the Inspector"),
		EventSheetL10n.translate("Adds a check the Inspector runs while the table is edited: it warns until the table has rows, and names the first row with an empty text cell."))

	_files_label = _line_label("")
	content.add_child(_files_label)


## A muted one-line label that takes the width it is given and clips rather than wraps.
static func _line_label(text: String) -> Label:
	var label: Label = EventSheetPopupUI.hint_label(text, 0.0)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = true
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


# ── The model: every edit lands here, and the grid is redrawn from it ─────────────────────────


## Adds a row holding each column's blank - the same blank the Inspector's Add Row uses.
func add_row() -> void:
	var fresh: Dictionary = {}
	for column: Dictionary in columns:
		fresh[column["name"]] = EventSheetDrawerWidgets.DrawerTable._default_for(column)
	rows.append(fresh)
	_refresh()


## Adds a Text column with the first free name (column, column_2, ...) and selects it.
func add_column() -> void:
	var column_name: String = "column"
	var suffix: int = 2
	while _column_index(column_name) >= 0:
		column_name = "column_%d" % suffix
		suffix += 1
	columns.append({"name": column_name, "type": "String"})
	_widths.append(START_COLUMN_WIDTH)
	for row: Dictionary in rows:
		row[column_name] = ""
	selected_column = columns.size() - 1
	_refresh()


## Removes a column and its cell from every row. The last column stays: a table has at least one.
func remove_column(index: int) -> void:
	if columns.size() <= 1 or index < 0 or index >= columns.size():
		return
	for row: Dictionary in rows:
		row.erase(columns[index]["name"])
	columns.remove_at(index)
	_widths.remove_at(index)
	_refresh()


## Renames a column and the key every row stores it under. Returns why it could not, or "".
func rename_column(index: int, new_name: String) -> String:
	var wanted: String = new_name.strip_edges()
	if index < 0 or index >= columns.size() or wanted == str(columns[index]["name"]):
		return ""
	if not wanted.is_valid_identifier():
		return EventSheetL10n.translate("A column name is a GDScript name: letters, digits and _, not starting with a digit.")
	if _column_index(wanted) >= 0:
		return EventSheetL10n.translate("Another column already has this name.")
	var old_name: String = columns[index]["name"]
	columns[index]["name"] = wanted
	for row: Dictionary in rows:
		row[wanted] = row.get(old_name, "")
		row.erase(old_name)
	_refresh()
	return ""


## Sets what kind of thing a column holds, carrying each row's cell over as its text.
func set_kind(index: int, type: String) -> void:
	if index < 0 or index >= columns.size():
		return
	var column: Dictionary = columns[index]
	column["type"] = type
	if type == "enum" and not column.has("options"):
		column["options"] = []
	_convert_cells(column)


## Sets a Choice column's words, from "coin, gem | key" however it is separated.
func set_choices(index: int, text: String) -> void:
	if index < 0 or index >= columns.size():
		return
	var options: Array = []
	for word: String in text.replace("|", ",").replace("·", ",").split(",", false):
		if not word.strip_edges().is_empty() and not options.has(word.strip_edges()):
			options.append(word.strip_edges())
	columns[index]["options"] = options
	_convert_cells(columns[index])


func _convert_cells(column: Dictionary) -> void:
	var options: Array = column.get("options", [])
	for row: Dictionary in rows:
		var text: String = EventSheetGridCSV.cell_text(row.get(column["name"], ""))
		row[column["name"]] = EventSheetGridCSV.cell_value(text, column)
		if column["type"] == "enum" and not options.has(text):
			row[column["name"]] = EventSheetDrawerWidgets.DrawerTable._default_for(column)
	_refresh()


## Reads a CSV into the table: a header name the table lacks becomes a column - a number column when
## every cell under it is a number - and the file's rows replace the ones typed here.
func import_csv(csv_path: String) -> String:
	var text: String = FileAccess.get_file_as_string(csv_path)
	var records: Array = EventSheetGridCSV.parse_records(text)
	if records.is_empty():
		return EventSheetL10n.translate("%s has no rows under its header line.") % csv_path.get_file()
	for header: String in (records[0] as Dictionary).keys():
		if not header.is_valid_identifier() or _column_index(header) >= 0:
			continue
		var type: String = "int"
		for record: Dictionary in records:
			var cell: String = str(record.get(header, "")).strip_edges()
			if not cell.is_valid_int():
				type = "float" if cell.is_valid_float() and type != "String" else "String"
		columns.append({"name": header, "type": type})
		_widths.append(START_COLUMN_WIDTH)
	rows = EventSheetGridCSV.rows_from_csv(text, columns).get("rows", [])
	_refresh()
	return EventSheetL10n.translate("Read %d row(s) from %s.") % [rows.size(), csv_path.get_file()]


## Writes the table as a CSV a spreadsheet opens. Returns what happened, in words.
func export_csv(csv_path: String) -> String:
	var written: Dictionary = EventSheetGridCSV.write_csv(csv_path, rows, columns)
	if not bool(written.get("ok", false)):
		return str(written.get("message", ""))
	return EventSheetL10n.translate("Wrote %d row(s) to %s.") % [rows.size(), csv_path.get_file()]


func _column_index(column_name: String) -> int:
	for index: int in columns.size():
		if str(columns[index]["name"]) == column_name:
			return index
	return -1


# ── Drawing the model ─────────────────────────────────────────────────────────────────────────


func _refresh() -> void:
	if _table == null:
		return
	selected_column = clampi(selected_column, 0, columns.size() - 1)
	_table.clear()
	_table.columns = columns.size() + 2
	_table.set_column_title(0, "")
	_table.set_column_expand(0, false)
	_table.set_column_custom_minimum_width(0, int(EventSheetPalette.scaled_f(40.0)))
	for index: int in columns.size():
		_table.set_column_title(index + 1, "%s · %s" % [columns[index]["name"], _kind(columns[index]["type"])[1]])
		_table.set_column_title_tooltip_text(index + 1, EventSheetL10n.translate("%s - double-click to rename, drag the right edge to resize") % columns[index]["name"])
		_table.set_column_expand(index + 1, false)
		_table.set_column_clip_content(index + 1, true)
		_table.set_column_custom_minimum_width(index + 1, int(EventSheetPalette.scaled_f(_widths[index])))
	_table.set_column_title(columns.size() + 1, EventSheetL10n.translate("+ Column"))
	_table.set_column_title_tooltip_text(columns.size() + 1, EventSheetL10n.translate("Add a column"))
	var root: TreeItem = _table.create_item()
	var picked: Color = EventSheetPopupUI.accent_color()
	picked.a = 0.12
	for row_index: int in rows.size():
		var item: TreeItem = _table.create_item(root)
		item.set_text(0, str(row_index))
		item.set_custom_color(0, EventSheetPopupUI.muted_text_color())
		for index: int in columns.size():
			_fill_cell(item, index + 1, columns[index], rows[row_index])
			if index == selected_column:
				item.set_custom_bg_color(index + 1, picked)
	_counts_label.text = EventSheetL10n.translate("%d row(s) · %d column(s)") % [rows.size(), columns.size()]
	_show_column()
	_refresh_names()


func _fill_cell(item: TreeItem, cell: int, column: Dictionary, row: Dictionary) -> void:
	var value: Variant = row.get(column["name"], "")
	item.set_editable(cell, true)
	match str(column["type"]):
		"bool":
			item.set_cell_mode(cell, TreeItem.CELL_MODE_CHECK)
			item.set_checked(cell, bool(value))
			return
		"enum":
			var options: Array = column.get("options", [])
			item.set_cell_mode(cell, TreeItem.CELL_MODE_RANGE)
			item.set_text(cell, ",".join(PackedStringArray(options)))
			item.set_range(cell, maxi(0, options.find(str(value))))
			return
		"int", "float":
			item.set_custom_color(cell, EventSheetPopupUI.tone_color(EventSheetPopupUI.TONE_OK))
	item.set_text(cell, EventSheetGridCSV.cell_text(value))


func _on_cell_edited() -> void:
	var item: TreeItem = _table.get_edited()
	var index: int = _table.get_edited_column() - 1
	if item == null or index < 0 or index >= columns.size():
		return
	var column: Dictionary = columns[index]
	var row: Dictionary = rows[item.get_index()]
	match str(column["type"]):
		"bool":
			row[column["name"]] = item.is_checked(index + 1)
		"enum":
			var options: Array = column.get("options", [])
			var picked: int = int(item.get_range(index + 1))
			row[column["name"]] = options[picked] if picked < options.size() else ""
		_:
			row[column["name"]] = EventSheetGridCSV.cell_value(item.get_text(index + 1), column)
			item.set_text.call_deferred(index + 1, EventSheetGridCSV.cell_text(row[column["name"]]))


func _select_column(index: int) -> void:
	if index < 0 or index >= columns.size() or index == selected_column:
		return
	selected_column = index
	_refresh()


## The panel beside the grid, and the strip under it, about the selected column.
func _show_column() -> void:
	var column: Dictionary = columns[selected_column]
	var kind: Array = _kind(column["type"])
	_column_card_title.text = EventSheetL10n.translate("Column: %s") % column["name"]
	if _column_name_edit.text != column["name"]:
		_column_name_edit.text = column["name"]
		_column_note.say("")
	for index: int in _kind_option.item_count:
		if _kind_option.get_item_metadata(index) == column["type"]:
			_kind_option.select(index)
	EventSheetPopupUI.follow_description(_kind_option)
	_choices_row.visible = column["type"] == "enum"
	var options_text: String = ", ".join(PackedStringArray(column.get("options", [])))
	if _choices_row.visible and _choices_edit.text.replace(" ", "") != options_text.replace(" ", ""):
		_choices_edit.text = options_text
	var blank: String = EventSheetGridCSV.cell_text(EventSheetDrawerWidgets.DrawerTable._default_for(column))
	_default_label.text = blank if not blank.is_empty() else EventSheetL10n.translate("(empty)")
	# The name rides the sentence, not the small-caps heading: a name reads exactly as it is written.
	_help_strip.describe("", "%s - %s" % [column["name"], kind[2]])


func _show_column_note(problem: String) -> void:
	_column_note.say(problem)
	EventSheetPopupUI.mark_field(_column_name_edit, not problem.is_empty())


## The names the window derives - the Name placeholder, the grid's caption, the files Insert writes
## - redrawn as one row's name is typed.
func _refresh_names() -> void:
	var entry: String = _row_edit.text.strip_edges()
	_name_edit.placeholder_text = class_name_for("", entry if not entry.is_empty() else _row_edit.placeholder_text)
	var grid: String = grid_name_for(entry if not entry.is_empty() else _row_edit.placeholder_text)
	_caption_label.text = grid.substr(0, 1).to_upper() + grid.substr(1).replace("_", " ")
	var file_stem: String = class_name_for(_name_edit.text, entry).to_snake_case() if not entry.is_empty() \
		else _name_edit.placeholder_text.to_snake_case()
	_files_label.text = EventSheetL10n.translate("Creates %s and %s in %s; any sheet can read its rows.") % [
		file_stem + ".gd", file_stem + ".tres", target_folder()]
	_refresh_reading()


## The strip's IN CODE line: the declaration the Resource script will carry.
func _refresh_reading() -> void:
	var entry: String = _row_edit.text.strip_edges()
	var sheet: EventSheetResource = build_wizard_sheet(_name_edit.text,
		entry if not entry.is_empty() else _row_edit.placeholder_text, columns, _warn_check.button_pressed)
	for variable_name: String in sheet.variables:
		var declared: LocalVariable = LocalVariable.new()
		declared.name = variable_name
		declared.type_name = "Array"
		declared.default_value = []
		declared.exported = true
		declared.attributes = (sheet.variables[variable_name] as Dictionary).get("attributes", {})
		_help_strip.set_reading("", EventSheets.row_code_line(declared))


# ── The grid's own gestures: a header click, a drag on a column edge, Delete ─────────────────


func _on_title_clicked(column: int, mouse_button: int) -> void:
	if mouse_button != MOUSE_BUTTON_LEFT:
		return
	if column == columns.size() + 1:
		add_column()
		return
	var now: int = Time.get_ticks_msec()
	var twice: bool = _last_title_click[0] == column and now - int(_last_title_click[1]) < 400
	_last_title_click = [column, now]
	_select_column(column - 1)
	if twice:
		_column_name_edit.grab_focus()
		_column_name_edit.select_all()


func _on_table_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_DELETE:
		var doomed: TreeItem = _table.get_selected()
		if doomed != null:
			rows.remove_at(doomed.get_index())
			_refresh()
			_table.accept_event()
		return
	var mouse: InputEventMouse = event as InputEventMouse
	if mouse == null:
		return
	if event is InputEventMouseMotion:
		if _drag_column >= 0:
			_widths[_drag_column] = maxf(MIN_COLUMN_WIDTH, _drag_width + (mouse.position.x - _drag_from) / EventSheetPalette.scaled_f(1.0))
			_table.set_column_custom_minimum_width(_drag_column + 1, int(EventSheetPalette.scaled_f(_widths[_drag_column])))
			_table.accept_event()
		else:
			_table.mouse_default_cursor_shape = Control.CURSOR_HSIZE if edge_at(mouse.position.x) >= 0 else Control.CURSOR_ARROW
		return
	var press: InputEventMouseButton = event as InputEventMouseButton
	if press == null or press.button_index != MOUSE_BUTTON_LEFT:
		return
	if not press.pressed:
		_drag_column = -1
		return
	var edge: int = edge_at(press.position.x)
	if edge < 0:
		return
	if press.double_click:
		fit_column(edge)
	else:
		_drag_column = edge
		_drag_from = press.position.x
		_drag_width = _widths[edge]
	_table.accept_event()


## The column whose right edge is under x (Tree coordinates), or -1.
func edge_at(x: float) -> int:
	var right: float = _table.get_theme_stylebox("panel").get_margin(SIDE_LEFT) - _table.get_scroll().x
	right += _table.get_column_width(0)
	for index: int in columns.size():
		right += _table.get_column_width(index + 1)
		if absf(x - right) <= EventSheetPalette.scaled_f(EDGE_GRAB):
			return index
	return -1


## Widens or narrows a column to its widest cell or title.
func fit_column(index: int) -> void:
	var font: Font = _table.get_theme_font("font")
	var font_size: int = _table.get_theme_font_size("font_size")
	var widest: float = font.get_string_size(_table.get_column_title(index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	for row: Dictionary in rows:
		var text: String = EventSheetGridCSV.cell_text(row.get(columns[index]["name"], ""))
		widest = maxf(widest, font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	_widths[index] = maxf(MIN_COLUMN_WIDTH, widest / EventSheetPalette.scaled_f(1.0) + 24.0)
	_table.set_column_custom_minimum_width(index + 1, int(EventSheetPalette.scaled_f(_widths[index])))


func _pick_csv(saving: bool) -> void:
	EventSheetPopupUI.browse_file(_dialog, ["*.csv ; CSV"], func(path: String) -> void:
		show_problem(export_csv(path) if saving else import_csv(path), EventSheetPopupUI.TONE_OK),
		{"plain": true, "save": saving, "disk": true,
			"size": Vector2i(Vector2(EventSheetPalette.scaled_f(760.0), EventSheetPalette.scaled_f(480.0)))})


# ── Insert ────────────────────────────────────────────────────────────────────────────────────


func _on_create() -> void:
	var written: Dictionary = write_files(target_folder())
	if not bool(written["ok"]):
		show_problem(str(written["message"]))
		return
	_dialog.hide()
	if Engine.is_editor_hint() and Engine.has_singleton("EditorInterface"):
		EditorInterface.get_resource_filesystem().scan()
	_dock._load_sheet_from_path(str(written["gd"]))
	_dock._set_status(str(written["message"]))


## Writes the Resource script and the .tres holding the rows into `folder`. Returns
## {ok, message, gd, tres}; nothing is written when something stops it.
func write_files(folder: String) -> Dictionary:
	var entry: String = _row_edit.text.strip_edges()
	var problem: String = create_problem(entry, _name_edit.text, columns)
	var resource_class: String = class_name_for(_name_edit.text, entry)
	var gd_path: String = folder.path_join(resource_class.to_snake_case() + ".gd")
	var tres_path: String = gd_path.get_basename() + ".tres"
	for path: String in [gd_path, tres_path]:
		if problem.is_empty() and FileAccess.file_exists(path):
			problem = EventSheetL10n.translate("%s already exists - pick another Name.") % path.get_file()
	if not problem.is_empty():
		return {"ok": false, "message": problem}
	var sheet: EventSheetResource = build_wizard_sheet(_name_edit.text, entry, columns, _warn_check.button_pressed)
	var grid: String = grid_name_for(entry)
	if _warn_check.button_pressed:
		# The Inspector runs a validator only in a script that runs in the editor.
		sheet.tool_mode = true
		_check_rows(sheet, EventSheets.attach_validator(sheet, grid))
	# Written the way Save As writes a .gd: the file IS the sheet, so it carries no generated banner.
	if not bool(SheetCompiler.compile(sheet, gd_path, true).get("success", false)) or not FileAccess.file_exists(gd_path):
		return {"ok": false, "message": EventSheetL10n.translate("Could not write %s.") % gd_path.get_file()}
	var script: Script = load(gd_path) as Script
	var data: Resource = script.new() as Resource if script != null and script.can_instantiate() else null
	if data == null:
		return {"ok": false, "message": EventSheetL10n.translate("%s was written but does not compile, so no .tres was made.") % gd_path.get_file()}
	data.set(grid, rows.duplicate(true))
	if ResourceSaver.save(data, tres_path) != OK:
		return {"ok": false, "message": EventSheetL10n.translate("Could not write %s.") % tres_path.get_file()}
	return {"ok": true, "gd": gd_path, "tres": tres_path,
		"message": EventSheetL10n.translate("Made %s and %s - load the .tres from any sheet to read its rows.") % [gd_path.get_file(), tres_path.get_file()]}


## Turns the validator into the check the box promises: no rows yet, or a row with an empty text cell.
static func _check_rows(sheet: EventSheetResource, function_name: String) -> void:
	var grid: String = function_name.trim_prefix("validate_")
	for candidate: Resource in sheet.functions:
		if candidate is EventFunction and (candidate as EventFunction).function_name == function_name:
			var body: RawCodeRow = (candidate as EventFunction).events[0] as RawCodeRow
			body.code = ("if %s.is_empty():\n\treturn \"Add at least one row.\"\nfor row: Dictionary in %s:\n\tfor column: String in row:\n"
				+ "\t\tif row[column] is String and str(row[column]).is_empty():\n\t\t\treturn \"Row %%d has no %%s.\" %% [%s.find(row), column]\nreturn \"\"") % [grid, grid, grid]


## The folder Insert writes into: the one open in the FileSystem dock, else the project root.
static func target_folder() -> String:
	if Engine.is_editor_hint() and Engine.has_singleton("EditorInterface"):
		return EditorInterface.get_current_directory()
	return "res://"


## Shows what Insert or a CSV import has to say on the window itself, or hides the line.
func show_problem(problem: String, tone: String = EventSheetPopupUI.TONE_ERROR) -> void:
	if _problem_label != null:
		_problem_label.say(problem, tone)


## What keeps Insert from making the table, or "" when nothing does: no row name, no columns, a
## column name GDScript cannot use, or a class name the project or the engine already has (a second
## class_name of the same name would not compile).
static func create_problem(entry_name: String, resource_name: String, table_columns: Array) -> String:
	if entry_name.strip_edges().is_empty():
		return EventSheetL10n.translate("Say what one row is first (e.g. LootDrop).")
	if table_columns.is_empty():
		return EventSheetL10n.translate("Add at least one column.")
	var seen: Array = []
	for column: Variant in table_columns:
		var column_name: String = str((column as Dictionary).get("name", "")) if column is Dictionary else str(column).get_slice(":", 0).strip_edges()
		if not column_name.is_valid_identifier() or seen.has(column_name):
			return EventSheetL10n.translate("Column %s needs a name of its own: letters, digits and _.") % column_name
		seen.append(column_name)
	var chosen: String = class_name_for(resource_name, entry_name)
	if EventSheetHeadActions.class_name_taken(chosen):
		return EventSheetL10n.translate("%s is already a class name - pick another Name.") % chosen
	return ""


## The whole table as a pure function: row name + columns -> a Resource-host sheet whose grid
## variable came from EventSheets.resource_grid. Columns are column dictionaries or the API's
## phrases ("weight: float"). Headless-testable.
static func build_wizard_sheet(resource_name: String, entry_name: String, table_columns: Array, required: bool) -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Resource"
	sheet.custom_class_name = class_name_for(resource_name, entry_name)
	var grid_name: String = grid_name_for(entry_name)
	var entry_words: String = grid_name.replace("_", " ")
	sheet.class_description = "A data table of %s. Fill the grid in the Inspector and save as a .tres - one asset per variant, shared by every scene that loads it." % entry_words
	sheet.variables = {
		grid_name: EventSheets.resource_grid(table_columns, {
			"tooltip": "One row per %s." % entry_words.trim_suffix("s"),
			"required": required,
		})
	}
	var about: CommentRow = CommentRow.new()
	about.text = "[b]%s[/b] - a data table. The [b]%s[/b] grid is the whole Inspector: designers fill rows and save .tres variants (FileSystem dock > right-click > New Resource > %s once this compiles). Resources have no _ready or _process - add [b]functions[/b] for logic (roll a row, find by name) and call them from the sheets that load the asset." % [sheet.custom_class_name, grid_name, sheet.custom_class_name]
	sheet.events.append(about)
	return sheet


## "Loot Drop" or "LootDrop" -> "loot_drops" (the grid variable). Naive plural: append s unless it
## ends in s.
static func grid_name_for(entry_name: String) -> String:
	var snake: String = entry_name.strip_edges().to_snake_case().replace(" ", "_")
	while snake.contains("__"):
		snake = snake.replace("__", "_")
	if snake.is_empty():
		return ""
	return snake if snake.ends_with("s") else snake + "s"


## The class_name: the explicit Name field wins; else derived from the row name
## ("LootDrop" -> "LootDropTable"). Always a valid PascalCase identifier.
static func class_name_for(resource_name: String, entry_name: String) -> String:
	var chosen: String = resource_name.strip_edges()
	if chosen.is_empty():
		chosen = entry_name.strip_edges() + " Table"
	var pascal: String = ""
	for word: String in chosen.replace("_", " ").split(" ", false):
		pascal += word.substr(0, 1).to_upper() + word.substr(1)
	var identifier: RegEx = RegEx.new()
	identifier.compile("[^A-Za-z0-9_]")
	pascal = identifier.sub(pascal, "", true)
	if pascal.is_empty() or pascal.substr(0, 1).is_valid_int():
		pascal = "My" + pascal
	return pascal
