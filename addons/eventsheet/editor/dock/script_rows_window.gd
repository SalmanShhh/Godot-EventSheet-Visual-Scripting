@tool
extends RefCounted
# "<Script> in event sheets": one window for a script of yours that sheets read, instead of a table of
# columns to curate. It lists what the script gives sheets as plain sentences with a tick each; what is
# unticked is left out of the picker (`## @ace_hidden`, written above the member), and a member the
# script already leaves out is listed too, marked "left out", so unticking is never a one-way door.
# Done writes straight into the script after a backup and says which lines it wrote.
#
# Loaded by path by the provider registry glue when someone opens it, so the first open of a sheet
# never compiles it. No class_name. Every decision (names, sentences, lines, findings) comes from the
# one scan, EventSheetProviderPreview.scan; this only puts it on screen and writes the ticks back.

const PROVIDER_PREVIEW_PATH := "res://addons/eventsheet/ace/provider_preview.gd"
const SHIPPED_SCRIPTS_PATH := "res://addons/eventsheet/ace/shipped_scripts.gd"
const ANNOTATION_WRITER_PATH := "res://addons/eventsheet/ace/annotation_writer.gd"
const EVENTSHEETS_API_PATH := "res://addons/eventsheet/api/eventsheets.gd"

var _dock: Control = null
var _window: ConfirmationDialog = null
var _scripts: ItemList = null
var _heading: Label = null
var _tree: Tree = null
var _notes: VBoxContainer = null
var _door_button: Button = null
var _line_button: Button = null
var _keep_button: Button = null
var _file_dialog: FileDialog = null
var _path: String = ""
var _scan: Dictionary = {}


## The window's current script path ("" before one is shown).
func shown_path() -> String:
	return _path


func window() -> ConfirmationDialog:
	return _window


func tree() -> Tree:
	return _tree


## Opens the window on `path`, or on the first script the open sheet or the project uses.
func open(dock: Control, path: String = "") -> void:
	_dock = dock
	if _window == null:
		_build()
	_refresh_scripts()
	var target: String = path
	if target.is_empty() and _scripts.item_count > 0:
		target = str((_scripts.get_item_metadata(0) as Dictionary).get("path", ""))
	show_script(target)
	EventSheetWindowPlacement.popup_centered(_window, Vector2i(760, 640))


func _build() -> void:
	var parts: Dictionary = EventSheetPopupUI.panel_window(EventSheetL10n.translate("Scripts in event sheets"),
		Vector2i(720, 600), _dock, EventSheetL10n.translate("Done"), _apply, true)
	_window = parts["window"]
	var form: VBoxContainer = parts["box"]
	form.add_child(EventSheetPopupUI.hint_label(EventSheetL10n.translate(
		"Untick what sheets should not see. Click a sentence to change it.")))
	_scripts = ItemList.new()
	_scripts.custom_minimum_size = Vector2(0, EventSheetPalette.scaled_f(70.0))
	_scripts.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_scripts.item_selected.connect(func(index: int) -> void:
		show_script(str((_scripts.get_item_metadata(index) as Dictionary).get("path", ""))))
	var script_buttons: HBoxContainer = HBoxContainer.new()
	var add_button: Button = Button.new()
	add_button.text = EventSheetL10n.translate("Add a script…")
	add_button.pressed.connect(func() -> void:
		EventSheetWindowPlacement.popup_centered(_file_dialog, Vector2i(720, 520)))
	script_buttons.add_child(add_button)
	var remove_button: Button = Button.new()
	remove_button.text = EventSheetL10n.translate("Remove from this sheet")
	remove_button.pressed.connect(_remove_selected)
	script_buttons.add_child(remove_button)
	_door_button = Button.new()
	_door_button.text = EventSheetL10n.translate("Open in Godot Script Editor")
	_door_button.pressed.connect(func() -> void: _open_in_godot(-1))
	script_buttons.add_child(_door_button)
	var script_box: VBoxContainer = EventSheetPopupUI.form_box()
	script_box.add_child(_scripts)
	script_box.add_child(script_buttons)
	form.add_child(EventSheetPopupUI.titled_card(EventSheetL10n.translate("Scripts"), script_box))

	var rows_box: VBoxContainer = EventSheetPopupUI.form_box()
	rows_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_heading = EventSheetPopupUI.hint_label("")
	rows_box.add_child(_heading)
	_tree = EventSheetPopupUI.table(PackedStringArray(["", "Reads as", "Kind"]), 160.0, {0: 40.0, 2: 100.0})
	_tree.set_column_expand(1, true)
	rows_box.add_child(_tree)
	_notes = VBoxContainer.new()
	_notes.add_theme_constant_override("separation", 2)
	rows_box.add_child(_notes)
	var row_buttons: HBoxContainer = HBoxContainer.new()
	_line_button = Button.new()
	_line_button.text = EventSheetL10n.translate("Go to the line")
	_line_button.pressed.connect(func() -> void: _open_in_godot(_selected_line()))
	row_buttons.add_child(_line_button)
	_keep_button = Button.new()
	_keep_button.text = EventSheetL10n.translate("Keep Old Name…")
	_keep_button.tooltip_text = EventSheetL10n.translate(
		"Renamed this function? Add a deprecated stand-in under its old name so sheets that already use it keep working.")
	_keep_button.pressed.connect(_ask_old_name)
	row_buttons.add_child(_keep_button)
	rows_box.add_child(row_buttons)
	var rows_card: PanelContainer = EventSheetPopupUI.titled_card(EventSheetL10n.translate("What sheets can use"), rows_box)
	rows_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	form.add_child(rows_card)
	_tree.item_selected.connect(_sync_buttons)

	_file_dialog = FileDialog.new()
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.access = FileDialog.ACCESS_RESOURCES
	_file_dialog.filters = PackedStringArray(["*.gd ; GDScript"])
	_file_dialog.file_selected.connect(func(chosen: String) -> void:
		_dock._providers_glue.add_ace_provider_script(chosen)
		_refresh_scripts()
		show_script(chosen))
	_window.add_child(_file_dialog)


## The scripts this sheet reads (registered on it) and the project's own (the taught setting), one line
## each, by file name with the folder after it.
func _refresh_scripts() -> void:
	_scripts.clear()
	for listed: String in _dock._providers_glue.get_ace_provider_scripts():
		_add_script_line(listed, false)
	for taught: Variant in ProjectSettings.get_setting(EventSheetDock.TAUGHT_PROVIDERS_SETTING, PackedStringArray()):
		_add_script_line(str(taught), true)


func _add_script_line(script_path: String, project_wide: bool) -> void:
	for index: int in _scripts.item_count:
		if str((_scripts.get_item_metadata(index) as Dictionary).get("path", "")) == script_path:
			return
	var at: int = _scripts.add_item("%s   %s" % [script_path.get_file(), script_path.get_base_dir()])
	_scripts.set_item_metadata(at, {"path": script_path, "project_wide": project_wide})
	_scripts.set_item_tooltip(at, script_path)


## Reads `path` once through the scan and draws its rows.
func show_script(path: String) -> void:
	_path = path
	_tree.clear()
	for stale: Node in _notes.get_children():
		_notes.remove_child(stale)
		stale.queue_free()
	if path.is_empty():
		_scan = {}
		_heading.text = EventSheetL10n.translate("No script yet. Add one to see what sheets can use from it.")
		_sync_buttons()
		return
	var preview: GDScript = load(PROVIDER_PREVIEW_PATH)
	_scan = preview.scan(path)
	var shipped: bool = load(SHIPPED_SCRIPTS_PATH).is_shipped(path)
	_heading.text = EventSheetL10n.translate("From %s. Right-click one to change how it reads.") % path.get_file()
	if shipped:
		_heading.text += "\n" + EventSheetL10n.translate("This script belongs to a behaviour that ships with the plugin, so it is shown but never changed here.")
	elif not bool(_scan.get("ok", false)):
		_heading.text = str(_scan.get("reason", ""))
	var root: TreeItem = _tree.create_item()
	for entry: Variant in _scan.get("entries", []):
		var row: Dictionary = entry
		var item: TreeItem = _tree.create_item(root)
		var left_out: bool = bool(row.get("left_out", false))
		item.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
		item.set_checked(0, not left_out)
		item.set_editable(0, not shipped)
		item.set_text(1, _reading(row))
		item.set_text(2, EventSheetL10n.translate("left out") if left_out else str(row.get("kind_label", "")))
		item.set_tooltip_text(1, "%s - %s `%s`" % [str(row.get("ace_id", "")), str(row.get("source", "")), str(row.get("member", ""))])
		item.set_metadata(0, row)
	for warning: Variant in _scan.get("warnings", []):
		var note: EventSheetPopupUI.StateNote = EventSheetPopupUI.StateNote.new()
		note.say(str((warning as Dictionary).get("text", "")), EventSheetPopupUI.TONE_WARNING)
		_notes.add_child(note)
	_sync_buttons()


## The sentence a row reads as, its slots in braces as the script wrote them.
func _reading(row: Dictionary) -> String:
	return str(row.get("sentence", row.get("label", "")))


func _selected_row() -> Dictionary:
	var item: TreeItem = _tree.get_selected() if _tree != null else null
	return item.get_metadata(0) as Dictionary if item != null and item.get_metadata(0) is Dictionary else {}


func _selected_line() -> int:
	return int(_selected_row().get("line", -1))


func _sync_buttons() -> void:
	if _line_button == null:
		return
	var row: Dictionary = _selected_row()
	_line_button.disabled = int(row.get("line", -1)) < 0
	_keep_button.visible = str(row.get("source", "")) == "method"
	_door_button.disabled = _path.is_empty()


func _open_in_godot(line: int) -> void:
	if not _path.is_empty():
		_dock._preview_glue._open_gdscript_path_in_godot(_path, line)


func _remove_selected() -> void:
	var picked: PackedInt32Array = _scripts.get_selected_items()
	if picked.is_empty():
		_dock._set_status(EventSheetL10n.translate("Pick a script in the list first."), true)
		return
	var meta: Dictionary = _scripts.get_item_metadata(picked[0])
	if bool(meta.get("project_wide", false)):
		_dock._providers_glue.unteach_provider(str(meta.get("path", "")))
	else:
		_dock._providers_glue.remove_ace_provider_script(str(meta.get("path", "")))
	_refresh_scripts()
	show_script("" if _scripts.item_count == 0 else str((_scripts.get_item_metadata(0) as Dictionary).get("path", "")))


func _ask_old_name() -> void:
	var row: Dictionary = _selected_row()
	if row.is_empty():
		return
	_dock._providers_glue.open_shim_question(_path, str(row.get("member", "")))


## The edits Done will write: one per row whose tick differs from what the script says now.
func collect_edits() -> Array:
	var edits: Array = []
	var root: TreeItem = _tree.get_root() if _tree != null else null
	if root == null:
		return edits
	var item: TreeItem = root.get_first_child()
	while item != null:
		var row: Dictionary = item.get_metadata(0) as Dictionary
		if row != null and item.is_checked(0) == bool(row.get("left_out", false)):
			edits.append({"source_kind": str(row.get("source", "method")), "member": str(row.get("member", "")),
				"hidden": not item.is_checked(0)})
		item = item.get_next()
	return edits


## Done: writes the ticks into the script (a backup first) and says which lines went in.
func _apply() -> void:
	var edits: Array = collect_edits()
	if edits.is_empty() or _path.is_empty():
		return
	var result: Dictionary = load(EVENTSHEETS_API_PATH).curate_provider(_path, edits)
	if not bool(result.get("ok", false)):
		_dock._set_status(str(result.get("reason", "Could not write the script.")), true)
		return
	var lines: PackedStringArray = PackedStringArray()
	for edit: Variant in edits:
		for annotation: String in load(ANNOTATION_WRITER_PATH).annotation_lines(edit as Dictionary):
			lines.append("%s above %s" % [annotation, str((edit as Dictionary).get("member", ""))])
	var message: String = EventSheetL10n.translate("Written to %s: %s") % [_path.get_file(), "; ".join(lines) if not lines.is_empty() else EventSheetL10n.translate("the members are shown again")]
	var skipped: Array = result.get("skipped", [])
	if not skipped.is_empty():
		message += " " + EventSheetL10n.translate("Not found: %s.") % ", ".join(PackedStringArray(skipped))
	_dock._set_status(message, not skipped.is_empty())


## Redraws the list of scripts and the rows of the one shown, after a script was added or taken away.
func open_refresh() -> void:
	_refresh_scripts()
	show_script(_path)
