@tool
class_name EventSheetSaveStudio
extends RefCounted
# Save Studio (Tools menu): everything about game saves in one window, three tabs.
#
#   1. Format Preview - pick a bundled addon (or the selected scene node) and a format,
#      and see EXACTLY what its save_state() snapshot looks like on disk. The preview
#      runs the real Save System backend (a throwaway save_system instance writing a
#      temp file), so what you see is byte-for-byte what ships.
#   2. Save Slots - browse the project's user:// save files, view their contents, and
#      export them anywhere - optionally converting between formats (config / json /
#      binary / csv) on the way out.
#   3. Add Save Support - for addon and tool authors: point it at any .gd, tick the
#      variables worth persisting, and copy a generated save_state()/load_state() pair
#      that follows the repo-wide seam convention (plain data, coerced loads, missing
#      keys tolerated).
#
# The seam contract this window teaches: a node participates in saves by exposing
# `save_state() -> Dictionary` and `load_state(state: Dictionary)`. No base class, no
# registration - the Save System duck-types the pair (persist group, Save Node State).

const SAVE_SYSTEM_SCRIPT: String = "res://eventsheet_addons/save_system/save_system_addon.gd"
const PREVIEW_FILE: String = "__save_studio_preview.tmp"
const FORMATS: PackedStringArray = ["config", "json", "binary", "csv"]
const FORMAT_EXTENSIONS: Dictionary = {"config": ".cfg", "json": ".json", "binary": ".sav", "csv": ".csv"}
# Object-ish declared types that never belong in a snapshot (references, not data).
const NON_DATA_TYPES: PackedStringArray = ["Node", "Node2D", "Node3D", "Control", "Tween", "Timer", "Resource", "Texture2D", "PackedScene", "RandomNumberGenerator", "FastNoiseLite", "Mutex", "Thread", "Camera2D", "Camera3D", "SubViewport", "Sprite2D", "Line2D", "AudioStreamPlayer", "Callable", "Signal"]

var _dock: Control = null
var _window: Window = null
var _preview_addon_picker: OptionButton = null
var _preview_format_picker: OptionButton = null
var _preview_output: CodeEdit = null
var _preview_addons: Array = []
var _slots_list: ItemList = null
var _slots_view: CodeEdit = null
var _slots_convert_picker: OptionButton = null
var _slots_section_edit: LineEdit = null
var _slots_files: PackedStringArray = PackedStringArray()
var _export_dialog: EditorFileDialog = null
var _support_path_edit: LineEdit = null
var _support_vars: Tree = null
var _support_output: CodeEdit = null
var _support_pick_dialog: EditorFileDialog = null


func init(dock: Control) -> void:
	_dock = dock


func open() -> void:
	if _window == null:
		_build_window()
	_refresh_preview_addons()
	_refresh_slots()
	_window.popup_centered(Vector2i(820, 620))


# ── Window construction ─────────────────────────────────────────────────────────────


func _build_window() -> void:
	_window = Window.new()
	_window.title = "Save Studio"
	_window.close_requested.connect(func() -> void: _window.hide())
	var tabs: TabContainer = TabContainer.new()
	tabs.set_anchors_preset(Control.PRESET_FULL_RECT)
	tabs.add_child(_build_preview_tab())
	tabs.add_child(_build_slots_tab())
	tabs.add_child(_build_support_tab())
	var body: MarginContainer = EventSheetPopupUI.margined(tabs)
	body.set_anchors_preset(Control.PRESET_FULL_RECT)
	_window.add_child(body)
	_dock.add_child(_window)


func _build_preview_tab() -> Control:
	var box: VBoxContainer = EventSheetPopupUI.form_box()
	box.name = "Format Preview"
	box.add_child(EventSheetPopupUI.hint_label("See what an addon's save looks like on disk before you commit to a format. The preview runs the real save pipeline on the addon's save_state() snapshot (default values - run the game and check Save Slots for live data)."))
	_preview_addon_picker = OptionButton.new()
	_preview_addon_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(EventSheetPopupUI.form_row("Addon", _preview_addon_picker))
	_preview_format_picker = OptionButton.new()
	for fmt: String in FORMATS:
		_preview_format_picker.add_item("%s  (save_0%s)" % [fmt, FORMAT_EXTENSIONS[fmt]])
	_preview_format_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(EventSheetPopupUI.form_row("Format", _preview_format_picker))
	var preview_button: Button = Button.new()
	preview_button.text = "Preview Save Output"
	preview_button.pressed.connect(_run_format_preview)
	box.add_child(preview_button)
	_preview_output = CodeEdit.new()
	EventSheetPopupUI.configure_code_editor(_preview_output)
	_preview_output.editable = false
	_preview_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var card: PanelContainer = EventSheetPopupUI.titled_card("What lands in the save file", _preview_output)
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(card)
	return box


func _build_slots_tab() -> Control:
	var box: VBoxContainer = EventSheetPopupUI.form_box()
	box.name = "Save Slots"
	box.add_child(EventSheetPopupUI.hint_label("The project's save files (user://). Select one to view it; export copies it anywhere - optionally converted to another format."))
	_slots_list = ItemList.new()
	_slots_list.custom_minimum_size = Vector2(0.0, 110.0)
	_slots_list.item_selected.connect(func(_index: int) -> void: _view_selected_slot())
	box.add_child(EventSheetPopupUI.panel_section(_slots_list))
	var actions: HBoxContainer = HBoxContainer.new()
	var refresh_button: Button = Button.new()
	refresh_button.text = "Refresh"
	refresh_button.pressed.connect(_refresh_slots)
	actions.add_child(refresh_button)
	var folder_button: Button = Button.new()
	folder_button.text = "Open Folder"
	folder_button.pressed.connect(func() -> void: OS.shell_open(ProjectSettings.globalize_path("user://")))
	actions.add_child(folder_button)
	actions.add_spacer(false)
	_slots_section_edit = LineEdit.new()
	_slots_section_edit.text = "save"
	_slots_section_edit.tooltip_text = "The Save System section the file was written with (needed to convert)."
	_slots_section_edit.custom_minimum_size = Vector2(80.0, 0.0)
	actions.add_child(_slots_section_edit)
	_slots_convert_picker = OptionButton.new()
	_slots_convert_picker.add_item("keep format")
	for fmt: String in FORMATS:
		_slots_convert_picker.add_item("as %s" % fmt)
	actions.add_child(_slots_convert_picker)
	var export_button: Button = Button.new()
	export_button.text = "Export…"
	export_button.pressed.connect(_export_selected_slot)
	actions.add_child(export_button)
	box.add_child(actions)
	_slots_view = CodeEdit.new()
	EventSheetPopupUI.configure_code_editor(_slots_view)
	_slots_view.editable = false
	_slots_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var card: PanelContainer = EventSheetPopupUI.titled_card("File contents", _slots_view)
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(card)
	return box


## The EditorFileDialogs are built lazily on first use - tab construction never depends
## on them (EditorFileDialog is editor-only, so this keeps the window buildable anywhere).
func _ensure_export_dialog() -> void:
	if _export_dialog != null:
		return
	_export_dialog = EditorFileDialog.new()
	_export_dialog.access = EditorFileDialog.ACCESS_FILESYSTEM
	_export_dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
	_export_dialog.file_selected.connect(_on_export_destination_picked)
	_window.add_child(_export_dialog)


func _build_support_tab() -> Control:
	var box: VBoxContainer = EventSheetPopupUI.form_box()
	box.name = "Add Save Support"
	box.add_child(EventSheetPopupUI.hint_label("Give any script (your addon, a tool, a plain node) save support: it just needs save_state() -> Dictionary and load_state(state). Pick the script, tick the variables worth keeping, and paste the generated pair in - the Save System finds it automatically (persist group, Save Node State)."))
	var pick_row: HBoxContainer = HBoxContainer.new()
	_support_path_edit = LineEdit.new()
	_support_path_edit.placeholder_text = "res://path/to/your_script.gd"
	_support_path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_support_path_edit.text_submitted.connect(func(_text: String) -> void: _scan_support_script())
	pick_row.add_child(_support_path_edit)
	var browse_button: Button = Button.new()
	browse_button.text = "Browse…"
	browse_button.pressed.connect(func() -> void:
		_ensure_support_pick_dialog()
		_support_pick_dialog.popup_centered_ratio(0.6))
	pick_row.add_child(browse_button)
	var scan_button: Button = Button.new()
	scan_button.text = "Scan Variables"
	scan_button.pressed.connect(_scan_support_script)
	pick_row.add_child(scan_button)
	box.add_child(pick_row)
	_support_vars = Tree.new()
	_support_vars.columns = 3
	_support_vars.set_column_title(0, "Save")
	_support_vars.set_column_title(1, "Variable")
	_support_vars.set_column_title(2, "Type")
	_support_vars.column_titles_visible = true
	_support_vars.set_column_expand(0, false)
	_support_vars.set_column_custom_minimum_width(0, 52)
	_support_vars.hide_root = true
	_support_vars.custom_minimum_size = Vector2(0.0, 130.0)
	box.add_child(EventSheetPopupUI.panel_section(_support_vars))
	var generate_row: HBoxContainer = HBoxContainer.new()
	var generate_button: Button = Button.new()
	generate_button.text = "Generate save_state / load_state"
	generate_button.pressed.connect(_generate_support_code)
	generate_row.add_child(generate_button)
	var copy_button: Button = Button.new()
	copy_button.text = "Copy to Clipboard"
	copy_button.pressed.connect(func() -> void:
		DisplayServer.clipboard_set(_support_output.text)
		_dock._set_status("Save-support snippet copied - paste it into your script."))
	generate_row.add_child(copy_button)
	box.add_child(generate_row)
	_support_output = CodeEdit.new()
	EventSheetPopupUI.configure_code_editor(_support_output)
	_support_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var card: PanelContainer = EventSheetPopupUI.titled_card("Generated seam (paste into the script)", _support_output)
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(card)
	return box


func _ensure_support_pick_dialog() -> void:
	if _support_pick_dialog != null:
		return
	_support_pick_dialog = EditorFileDialog.new()
	_support_pick_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	_support_pick_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	_support_pick_dialog.add_filter("*.gd", "GDScript")
	_support_pick_dialog.file_selected.connect(func(path: String) -> void:
		_support_path_edit.text = path
		_scan_support_script())
	_window.add_child(_support_pick_dialog)


# ── Tab 1: format preview ───────────────────────────────────────────────────────────


## Scans the bundled packs for the seam so the picker only offers addons that actually
## snapshot themselves. The selected scene node (with its behavior children) is offered
## too, so users can preview THEIR composition, not just one pack.
func _refresh_preview_addons() -> void:
	_preview_addons.clear()
	_preview_addon_picker.clear()
	if Engine.is_editor_hint() and _dock.is_inside_tree():
		var selection: Array[Node] = EditorInterface.get_selection().get_selected_nodes()
		if not selection.is_empty():
			_preview_addons.append({"label": "Selected node: %s" % selection[0].name, "node": selection[0]})
	for pack_dir: String in DirAccess.get_directories_at("res://eventsheet_addons"):
		for file: String in DirAccess.get_files_at("res://eventsheet_addons/%s" % pack_dir):
			if not file.ends_with(".gd"):
				continue
			var path: String = "res://eventsheet_addons/%s/%s" % [pack_dir, file]
			if FileAccess.get_file_as_string(path).contains("func save_state() -> Dictionary:"):
				_preview_addons.append({"label": pack_dir.capitalize(), "script": path})
				break
	for entry: Dictionary in _preview_addons:
		_preview_addon_picker.add_item(str(entry["label"]))


## The honest preview: build the snapshot, push it through a throwaway Save System
## instance in the chosen format, and show the resulting file verbatim.
func _run_format_preview() -> void:
	var index: int = _preview_addon_picker.selected
	if index < 0 or index >= _preview_addons.size():
		_preview_output.text = "Pick an addon first."
		return
	var entry: Dictionary = _preview_addons[index]
	var snapshot: Dictionary = {}
	var key: String = "state"
	if entry.has("node"):
		var node: Node = entry["node"]
		snapshot = _collect_like_save_system(node)
		key = str(node.name)
		if snapshot.is_empty():
			_preview_output.text = "Neither %s nor its children expose save_state() yet - the Add Save Support tab generates the pair." % node.name
			return
	else:
		var instance: Node = (load(str(entry["script"])) as GDScript).new()
		snapshot = instance.call("save_state")
		key = str(entry["label"])
		instance.free()
	var fmt: String = FORMATS[_preview_format_picker.selected]
	var writer: Node = (load(SAVE_SYSTEM_SCRIPT) as GDScript).new()
	writer.set("save_directory", "user://")
	writer.set("file_pattern", PREVIEW_FILE)
	writer.set("format", fmt)
	writer.call("save_value", key, snapshot)
	var path: String = str(writer.call("_slot_path"))
	if fmt == "binary":
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
		_preview_output.text = "binary (store_var): %d bytes - compact and fast, not hand-editable.\n\nFirst bytes:\n%s" % [bytes.size(), bytes.slice(0, mini(96, bytes.size())).hex_encode()]
	else:
		_preview_output.text = FileAccess.get_file_as_string(path)
	DirAccess.remove_absolute(path)
	writer.free()


## The same duck-typed walk Save Node State performs (node + behavior children).
func _collect_like_save_system(node: Node) -> Dictionary:
	var states: Dictionary = {}
	if node.has_method("save_state"):
		states["."] = node.call("save_state")
	for child: Node in node.get_children():
		if child.has_method("save_state"):
			states[str(child.name)] = child.call("save_state")
	return states


# ── Tab 2: save slots ───────────────────────────────────────────────────────────────


func _refresh_slots() -> void:
	_slots_files = PackedStringArray()
	_slots_list.clear()
	for file: String in DirAccess.get_files_at("user://"):
		if file.begins_with("__save_studio"):
			continue
		var path: String = "user://%s" % file
		_slots_files.append(path)
		var size_kb: float = FileAccess.get_file_as_bytes(path).size() / 1024.0
		var stamp: String = Time.get_datetime_string_from_unix_time(FileAccess.get_modified_time(path), true)
		_slots_list.add_item("%s   (%.1f KB, %s)" % [file, size_kb, stamp])


func _view_selected_slot() -> void:
	var selected: PackedInt32Array = _slots_list.get_selected_items()
	if selected.is_empty():
		return
	var path: String = _slots_files[selected[0]]
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	# Binary files render as noise - a zero byte near the head means show hex instead.
	if bytes.is_empty() or bytes.slice(0, mini(256, bytes.size())).find(0) != -1:
		_slots_view.text = "binary file: %d bytes\n\nFirst bytes:\n%s" % [bytes.size(), bytes.slice(0, mini(160, bytes.size())).hex_encode()]
	else:
		_slots_view.text = bytes.get_string_from_utf8()


func _export_selected_slot() -> void:
	var selected: PackedInt32Array = _slots_list.get_selected_items()
	if selected.is_empty():
		_dock._set_status("Select a save file to export first.", true)
		return
	var source: String = _slots_files[selected[0]]
	var convert_index: int = _slots_convert_picker.selected
	var suggested: String = source.get_file()
	if convert_index > 0:
		var target_fmt: String = FORMATS[convert_index - 1]
		suggested = "%s%s" % [suggested.get_basename(), FORMAT_EXTENSIONS[target_fmt]]
	_ensure_export_dialog()
	_export_dialog.current_file = suggested
	_export_dialog.popup_centered_ratio(0.6)


## Copies the selected slot to the picked destination; when a target format is chosen,
## reads through the Save System backend for the SOURCE format (guessed by extension)
## and rewrites through the target backend, so the conversion is the shipping code path.
func _on_export_destination_picked(destination: String) -> void:
	var selected: PackedInt32Array = _slots_list.get_selected_items()
	if selected.is_empty():
		return
	var source: String = _slots_files[selected[0]]
	var convert_index: int = _slots_convert_picker.selected
	if convert_index == 0:
		var copy_error: Error = DirAccess.copy_absolute(source, destination)
		_dock._set_status("Exported %s to %s." % [source.get_file(), destination] if copy_error == OK else "Export failed (error %d)." % copy_error, copy_error != OK)
		return
	var section: String = _slots_section_edit.text.strip_edges()
	var reader: Node = (load(SAVE_SYSTEM_SCRIPT) as GDScript).new()
	reader.set("save_directory", source.get_base_dir())
	reader.set("file_pattern", source.get_file())
	reader.set("format", _format_for_extension(source))
	reader.set("section", section if not section.is_empty() else "save")
	var data: Dictionary = reader.call("_read_all")
	reader.free()
	if data.is_empty():
		_dock._set_status("Nothing readable in %s (is the section name right? encrypted saves export with \"keep format\" only)." % source.get_file(), true)
		return
	var writer: Node = (load(SAVE_SYSTEM_SCRIPT) as GDScript).new()
	writer.set("save_directory", destination.get_base_dir())
	writer.set("file_pattern", destination.get_file())
	writer.set("format", FORMATS[_slots_convert_picker.selected - 1])
	writer.set("section", section if not section.is_empty() else "save")
	var written: bool = writer.call("_write_all", data)
	writer.free()
	_dock._set_status("Converted %s to %s." % [source.get_file(), destination] if written else "Conversion failed writing %s." % destination, not written)


func _format_for_extension(path: String) -> String:
	match path.get_extension().to_lower():
		"json":
			return "json"
		"csv":
			return "csv"
		"cfg", "ini":
			return "config"
	return "binary"


# ── Tab 3: add save support (the generator) ─────────────────────────────────────────


## Lists the script's top-level variables with a checkbox each. Plain-data variables
## (numbers, text, dictionaries, arrays, Vector2/Color...) start checked; object-typed
## references start unchecked - they are pointers, not state, and never belong in a save.
func _scan_support_script() -> void:
	_support_vars.clear()
	var path: String = _support_path_edit.text.strip_edges()
	if not FileAccess.file_exists(path):
		_dock._set_status("No script at %s." % path, true)
		return
	var root: TreeItem = _support_vars.create_item()
	var pattern: RegEx = RegEx.new()
	pattern.compile("^(?:@export[^\\n]*?\\s+)?var\\s+([a-zA-Z_]\\w*)\\s*(?::\\s*([\\w\\[\\], ]+?))?\\s*(?::?=.*)?$")
	for line: String in FileAccess.get_file_as_string(path).split("\n"):
		if line.begins_with("\t") or line.begins_with(" "):
			continue
		var hit: RegExMatch = pattern.search(line.strip_edges())
		if hit == null:
			continue
		var var_name: String = hit.get_string(1)
		var var_type: String = hit.get_string(2).strip_edges()
		var item: TreeItem = _support_vars.create_item(root)
		item.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
		item.set_editable(0, true)
		item.set_checked(0, _looks_like_data(var_name, var_type))
		item.set_text(1, var_name)
		item.set_text(2, var_type if not var_type.is_empty() else "Variant")
	if root.get_child_count() == 0:
		_dock._set_status("No top-level variables found in %s." % path.get_file(), true)


func _looks_like_data(var_name: String, var_type: String) -> bool:
	if var_name == "host" or var_type.begins_with("Array[Node"):
		return false
	for object_type: String in NON_DATA_TYPES:
		if var_type == object_type:
			return false
	return true


## Reads the ticked rows and hands them to the static generator, then shows the result.
func _generate_support_code() -> void:
	var root: TreeItem = _support_vars.get_root()
	if root == null:
		_support_output.text = "Scan a script first."
		return
	var entries: Array = []
	var item: TreeItem = root.get_first_child()
	while item != null:
		if item.is_checked(0):
			entries.append({"name": item.get_text(1), "type": item.get_text(2)})
		item = item.get_next()
	if entries.is_empty():
		_support_output.text = "Tick at least one variable to persist."
		return
	_support_output.text = build_seam_code(entries)


## The generator, pure and testable: turns [{name, type}, ...] into the seam verbatim -
## snapshot keys without the leading underscore, duplicate(true) on collections, typed
## coercion + the declared default on loads. This is the convention the whole repo follows.
static func build_seam_code(entries: Array) -> String:
	var save_lines: PackedStringArray = PackedStringArray()
	var load_lines: PackedStringArray = PackedStringArray()
	for entry: Dictionary in entries:
		var var_name: String = str(entry["name"])
		var var_type: String = str(entry["type"])
		var key: String = var_name.trim_prefix("_")
		match var_type:
			"Dictionary":
				save_lines.append("\t\t\"%s\": %s.duplicate(true)," % [key, var_name])
				load_lines.append("\t%s = (state.get(\"%s\", {}) as Dictionary).duplicate(true)" % [var_name, key])
			"Array":
				save_lines.append("\t\t\"%s\": %s.duplicate(true)," % [key, var_name])
				load_lines.append("\t%s = (state.get(\"%s\", []) as Array).duplicate(true)" % [var_name, key])
			"int":
				save_lines.append("\t\t\"%s\": %s," % [key, var_name])
				load_lines.append("\t%s = int(state.get(\"%s\", %s))" % [var_name, key, var_name])
			"float":
				save_lines.append("\t\t\"%s\": %s," % [key, var_name])
				load_lines.append("\t%s = float(state.get(\"%s\", %s))" % [var_name, key, var_name])
			"bool":
				save_lines.append("\t\t\"%s\": %s," % [key, var_name])
				load_lines.append("\t%s = bool(state.get(\"%s\", %s))" % [var_name, key, var_name])
			"String":
				save_lines.append("\t\t\"%s\": %s," % [key, var_name])
				load_lines.append("\t%s = str(state.get(\"%s\", %s))" % [var_name, key, var_name])
			_:
				save_lines.append("\t\t\"%s\": %s," % [key, var_name])
				load_lines.append("\t%s = state.get(\"%s\", %s)" % [var_name, key, var_name])
	if save_lines.is_empty():
		return ""
	# The last snapshot entry drops its trailing comma.
	save_lines[save_lines.size() - 1] = str(save_lines[save_lines.size() - 1]).trim_suffix(",")
	var lines: PackedStringArray = PackedStringArray([
		"# Save-state seam: the Save System walks any node in its persist group (or targeted",
		"# by Save/Load Node State) and duck-types these two methods. Plain data only.",
		"func save_state() -> Dictionary:",
		"\treturn {"
	])
	lines.append_array(save_lines)
	lines.append("\t}")
	lines.append("")
	lines.append("")
	lines.append("func load_state(state: Dictionary) -> void:")
	lines.append("\tif state.is_empty():")
	lines.append("\t\treturn")
	lines.append_array(load_lines)
	return "\n".join(lines)
