@tool
class_name EventSheetImportSheetWizard
extends RefCounted

# Sheet ▸ Import event sheet… - bringing an event sheet over from another event-sheet editor.
#
# Four questions in one window: which file, which sheet inside it, which node each of its objects
# became, and - once those are answered - what the result actually reads like before anything is
# written. The last one is the point. An importer that writes a file and then tells you it went
# fine is an importer nobody trusts; this one shows the sheet and the exact count ("14 of 17 rows
# mapped") with every row it could not spell named, and only writes when the reader says so.
#
# The source file is never touched. Save as… compiles the imported sheet to a new .gd through the
# ordinary compiler, so the file it writes is an ordinary sheet that re-opens byte-identically.
#
# All the thinking is in EventSheetForeignImporter, a pure static: this file is the window.

var _dock: Control = null
var _dialog: Window = null
var _source_edit: LineEdit = null
var _sheet_picker: OptionButton = null
var _mapping_grid: GridContainer = null
var _preview: TextEdit = null
var _report_label: RichTextLabel = null
var _save_button: Button = null
var _band: EventSheetPopupUI.RowBand = null
var _strip: EventSheetPopupUI.HelpStrip = null
var _save_note: EventSheetPopupUI.StateNote = null
var _browse_dialog: FileDialog = null
var _save_dialog: FileDialog = null

var _sheets: Dictionary = {}
var _project_objects: Dictionary = {}
var _mapping_fields: Dictionary = {}
var _imported: Dictionary = {}

## What the archive reader could not use. Held apart from the per-sheet report because it is a fact
## about the WHOLE file, and re-stated on every re-import so the reader never loses sight of it.
var _project_notes: PackedStringArray = PackedStringArray()


func init(dock: Control) -> void:
	_dock = dock


## Opens the window fresh. Nothing is read until a file is chosen.
func open() -> void:
	_build_dialog()
	_source_edit.text = ""
	_sheets = {}
	_project_objects = {}
	_imported = {}
	_sheet_picker.clear()
	_refresh()
	if _dialog.is_inside_tree():  # headless tests: the fields reset, there is no window to pop
		_dialog.popup_centered(Vector2i(880, 760))


func _build_dialog() -> void:
	if _dialog != null:
		return
	_dialog = Window.new()
	_dialog.title = "Import event sheet"
	_dialog.visible = false
	_dialog.min_size = Vector2i(720, 560)
	_dialog.close_requested.connect(func() -> void: _dialog.hide())
	_dock.add_child(_dialog)

	var content: VBoxContainer = EventSheetPopupUI.form_box()
	# The band names the sheet coming across, the file it becomes and the count, redrawn on every
	# answer, so nothing is saved blind.
	_band = EventSheetPopupUI.RowBand.new()
	content.add_child(_band)
	_strip = EventSheetPopupUI.help_strip("", "", "", "", EventSheetPalette.scaled_f(640.0))

	var source_box: VBoxContainer = EventSheetPopupUI.form_box()
	content.add_child(EventSheetPopupUI.titled_card("Which file?", source_box))
	var source_row: HBoxContainer = HBoxContainer.new()
	_source_edit = LineEdit.new()
	_source_edit.placeholder_text = "The exported project, or one exported event sheet"
	_source_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_source_edit.text_submitted.connect(func(_t: String) -> void: load_source(_source_edit.text))
	source_row.add_child(_source_edit)
	var browse_button: Button = Button.new()
	browse_button.text = "Browse…"
	browse_button.pressed.connect(_open_browse_dialog)
	source_row.add_child(browse_button)
	source_box.add_child(EventSheetPopupUI.form_row("File", source_row))
	_sheet_picker = OptionButton.new()
	_sheet_picker.item_selected.connect(func(_index: int) -> void: refresh_import())
	source_box.add_child(EventSheetPopupUI.form_row("Sheet", _sheet_picker))
	_strip.follow(_source_edit, EventSheetL10n.translate("Source file"),
		EventSheetL10n.translate("The exported project (.zip) or one exported sheet (.json); it is never written to. Every condition, action and expression this vocabulary knows becomes the row that says the same thing; anything it does not know arrives switched off with its own words beside it."))
	_strip.follow(_sheet_picker, EventSheetL10n.translate("Sheet"),
		EventSheetL10n.translate("Which event sheet inside the project comes across. Nothing is written until Save as…"))
	# The window opens on the first question, so the strip opens on what it means.
	_source_edit.focus_entered.emit()

	var mapping_box: VBoxContainer = EventSheetPopupUI.form_box()
	content.add_child(EventSheetPopupUI.titled_card("Which node is which object?", mapping_box))
	_mapping_grid = GridContainer.new()
	_mapping_grid.columns = 3
	mapping_box.add_child(_mapping_grid)

	# What it reads like and what came across sit side by side: the report is about the preview.
	var preview_box: VBoxContainer = EventSheetPopupUI.form_box()
	_preview = TextEdit.new()
	_preview.editable = false
	_preview.custom_minimum_size = Vector2(0, EventSheetPalette.scaled_f(220.0))
	_preview.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	preview_box.add_child(_preview)
	var report_box: VBoxContainer = EventSheetPopupUI.form_box()
	_report_label = RichTextLabel.new()
	_report_label.bbcode_enabled = true
	_report_label.fit_content = true
	_report_label.custom_minimum_size = Vector2(0, EventSheetPalette.scaled_f(120.0))
	report_box.add_child(_report_label)
	content.add_child(EventSheetPopupUI.responsive_band(
		EventSheetPopupUI.titled_card("What it reads like", preview_box),
		EventSheetPopupUI.titled_card("What came across", report_box)))
	content.add_child(_strip)

	var buttons: HBoxContainer = HBoxContainer.new()
	# Why Save as… did not write, in the foot beside the button that was pressed.
	_save_note = EventSheetPopupUI.StateNote.new(EventSheetPalette.scaled_f(420.0))
	_save_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(_save_note)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(spacer)
	var cancel_button: Button = Button.new()
	cancel_button.text = "Cancel"
	cancel_button.pressed.connect(func() -> void: _dialog.hide())
	buttons.add_child(cancel_button)
	_save_button = Button.new()
	_save_button.text = "Save as…"
	_save_button.disabled = true
	_save_button.pressed.connect(_open_save_dialog)
	buttons.add_child(_save_button)
	content.add_child(buttons)

	var scroll: ScrollContainer = ScrollContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	_dialog.add_child(EventSheetPopupUI.window_body(scroll))


## Reads the chosen file and fills the sheet list. Returns the error to show, or "" when it read.
## Split out from the browse button so a test can walk the whole wizard with no window.
func load_source(path: String) -> String:
	_source_edit.text = path
	_sheets = {}
	_project_objects = {}
	_project_notes = PackedStringArray()
	_sheet_picker.clear()
	if path.strip_edges().is_empty():
		_refresh()
		return "Pick a file first."
	if path.to_lower().ends_with(".json"):
		var single: Dictionary = EventSheetForeignImporter.read_sheet_file(path)
		if not bool(single["ok"]):
			_refresh(str(single["error"]))
			return str(single["error"])
		var single_name: String = str((single["sheet"] as Dictionary).get("name", path.get_file().get_basename()))
		_sheets[single_name] = single["sheet"]
	else:
		var project: Dictionary = EventSheetForeignImporter.read_project(path)
		_project_notes = project.get("notes", PackedStringArray()) as PackedStringArray
		if not bool(project["ok"]):
			_refresh(str(project["error"]))
			return str(project["error"])
		_sheets = project["sheets"] as Dictionary
		_project_objects = project["objects"] as Dictionary
	var names: Array = _sheets.keys()
	names.sort()
	for sheet_name: String in names:
		_sheet_picker.add_item(sheet_name)
	if _sheet_picker.item_count > 0:
		_sheet_picker.selected = 0
	refresh_import()
	return ""


## The sheet chosen in the picker, as the export wrote it.
func selected_sheet_json() -> Dictionary:
	if _sheet_picker == null or _sheet_picker.item_count == 0:
		return {}
	return _sheets.get(_sheet_picker.get_item_text(_sheet_picker.selected), {}) as Dictionary


## The object table as the reader has edited it.
func object_map() -> Dictionary:
	var out: Dictionary = {}
	for object_name: String in _mapping_fields:
		var fields: Dictionary = _mapping_fields[object_name] as Dictionary
		out[object_name] = {
			"kind": (fields["kind"] as OptionButton).get_item_text((fields["kind"] as OptionButton).selected),
			"node": (fields["node"] as LineEdit).text.strip_edges(),
		}
	return out


## Re-runs the import with the current answers and repaints the preview and the report. The one
## place an import happens, so what the reader looks at is what Save as… writes.
func refresh_import() -> void:
	var json: Dictionary = selected_sheet_json()
	if json.is_empty():
		_imported = {}
		_refresh()
		return
	_rebuild_mapping_table(json)
	_imported = EventSheetForeignImporter.import_sheet(json, object_map())
	# import_sheet builds a fresh report every time, so the archive's own notes are added once per
	# import and never accumulate. They lead, because a member that never arrived explains a sheet
	# that looks thinner than the project it came from.
	var report: Dictionary = _imported["report"] as Dictionary
	var notes: Array = report["notes"] as Array
	for index: int in _project_notes.size():
		notes.insert(index, _project_notes[index])
	_refresh()


func _rebuild_mapping_table(json: Dictionary) -> void:
	var wanted: PackedStringArray = EventSheetForeignImporter.object_names(json)
	var same: bool = wanted.size() == _mapping_fields.size()
	if same:
		for object_name: String in wanted:
			same = same and _mapping_fields.has(object_name)
	if same:
		return
	for child: Node in _mapping_grid.get_children():
		_mapping_grid.remove_child(child)
		child.queue_free()
	_mapping_fields = {}
	var defaults: Dictionary = EventSheetForeignImporter.default_object_map(json, _project_objects)
	for head: String in ["Object", "Becomes", "Node"]:
		_mapping_grid.add_child(EventSheetPopupUI.small_caps_label(EventSheetL10n.translate(head), EventSheetPopupUI.muted_text_color()))
	for object_name: String in wanted:
		var name_label: Label = Label.new()
		name_label.text = object_name
		_mapping_grid.add_child(name_label)
		var kind_picker: OptionButton = OptionButton.new()
		var default_kind: String = str((defaults[object_name] as Dictionary).get("kind", "Object"))
		for kind_index: int in EventSheetForeignACEMap.PLACED_OBJECT_KINDS.size():
			kind_picker.add_item(EventSheetForeignACEMap.PLACED_OBJECT_KINDS[kind_index])
			if EventSheetForeignACEMap.PLACED_OBJECT_KINDS[kind_index] == default_kind:
				kind_picker.selected = kind_index
		kind_picker.item_selected.connect(func(_index: int) -> void: refresh_import())
		_mapping_grid.add_child(kind_picker)
		var node_edit: LineEdit = LineEdit.new()
		node_edit.text = str((defaults[object_name] as Dictionary).get("node", ""))
		node_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		node_edit.text_submitted.connect(func(_t: String) -> void: refresh_import())
		node_edit.focus_exited.connect(refresh_import)
		_mapping_grid.add_child(node_edit)
		_strip.follow(kind_picker, EventSheetL10n.translate("Becomes"),
			EventSheetL10n.translate("What kind of object it was, which decides the words its rows read with."))
		_strip.follow(node_edit, EventSheetL10n.translate("Node"),
			EventSheetL10n.translate("Written into the rows as-is, so $Player means the child called Player; empty acts on the sheet's own node and keeps the object name in the report."))
		_mapping_fields[object_name] = {"kind": kind_picker, "node": node_edit}


## The report exactly as counted, plus every row that did not come across.
func report_text() -> String:
	if _imported.is_empty():
		return "Pick a file to see what comes across."
	var report: Dictionary = _imported["report"] as Dictionary
	var lines: PackedStringArray = PackedStringArray(["[b]%s[/b]" % EventSheetForeignImporter.report_summary(report)])
	for entry: Dictionary in report["unmapped"] as Array:
		lines.append("Switched off: [b]%s[/b] - %s" % [entry["label"], entry["reason"]])
	for entry: Dictionary in report["flagged"] as Array:
		lines.append("Check by hand: [b]%s[/b] - %s" % [entry["label"], entry["reason"]])
	for note: String in report["notes"] as Array:
		lines.append("Note: %s" % note)
	return "\n".join(lines)


func _refresh(error: String = "") -> void:
	if _report_label == null:
		return
	_save_note.say("")
	var sheet_name: String = str(selected_sheet_json().get("name", ""))
	_band.show_row("", "" if sheet_name.is_empty() else "%s → %s.gd" % [sheet_name, sheet_name.to_snake_case()],
		"" if _imported.is_empty() else EventSheetForeignImporter.report_summary(_imported["report"] as Dictionary))
	if not error.is_empty():
		_report_label.text = error
		_preview.text = ""
		_save_button.disabled = true
		return
	_report_label.text = report_text()
	_preview.text = "" if _imported.is_empty() else EventSheetTextDump.dump(_imported["sheet"] as EventSheetResource)
	_save_button.disabled = _imported.is_empty()


func _open_browse_dialog() -> void:
	if _browse_dialog == null:
		_browse_dialog = FileDialog.new()
		_browse_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		_browse_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_browse_dialog.filters = PackedStringArray([
			"*.c3p, *.zip ; Exported project", "*.json ; One exported event sheet",
		])
		_browse_dialog.title = "Pick the exported project or sheet"
		_browse_dialog.file_selected.connect(func(path: String) -> void: load_source(path))
		_dialog.add_child(_browse_dialog)
	_browse_dialog.popup_centered(Vector2i(720, 520))


func _open_save_dialog() -> void:
	if _save_dialog == null:
		_save_dialog = FileDialog.new()
		_save_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
		_save_dialog.access = FileDialog.ACCESS_RESOURCES
		_save_dialog.filters = PackedStringArray(["*.gd ; Event sheet"])
		_save_dialog.title = "Save the imported sheet as"
		_save_dialog.file_selected.connect(_on_save_path_chosen)
		_dialog.add_child(_save_dialog)
	_save_dialog.current_file = "%s.gd" % str(selected_sheet_json().get("name", "imported_sheet")).to_snake_case()
	_save_dialog.popup_centered(Vector2i(720, 520))


## The Save as… answer. A sheet that could not be written says why in the foot, beside the button;
## without it the window simply stayed open with nothing said.
func _on_save_path_chosen(path: String) -> void:
	var error: String = save_as(path)
	if error.is_empty() or _save_note == null:
		return
	_save_note.say("%s %s" % [EventSheetL10n.translate("Not saved."), error])


## Writes the imported sheet to `path` through the ordinary compiler and opens it. Returns the
## error to show, or "" when it wrote.
func save_as(path: String) -> String:
	if _imported.is_empty():
		return "Nothing has been imported yet."
	var compiled: Dictionary = SheetCompiler.compile(_imported["sheet"] as EventSheetResource, path, true)
	if not bool(compiled["success"]):
		return "That sheet did not compile: %s" % ", ".join(compiled["errors"] as Array)
	if _dialog != null:
		_dialog.hide()
	var report: Dictionary = _imported["report"] as Dictionary
	_dock.open_new_sheet(path)
	_dock._set_status("Imported %s - %s. The rows that did not come across are switched off with their own words." % [
		path.get_file(), EventSheetForeignImporter.report_summary(report)])
	return ""
