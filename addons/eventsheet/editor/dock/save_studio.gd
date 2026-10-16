@tool
class_name EventSheetSaveStudio
extends RefCounted
# Save Studio (Tools menu): everything about game saves in one window.
#
#   1. What gets saved - one Save choice per variable of the open sheet (Never / Auto / Load only /
#      Save only / Manual). The choice is stored on the variable and the compiler writes the plain
#      code for it (compiler/save_choices.gd); a row here is the whole gesture.
#   2. Format Preview - pick a bundled addon (or the selected scene node) and a format,
#      and see EXACTLY what its save_state() snapshot looks like on disk. The preview
#      runs the real Save System backend (a throwaway save_system instance writing a
#      temp file), so what you see is byte-for-byte what ships.
#   3. Save Slots - browse the project's user:// save files, view their contents, and
#      export them anywhere - optionally converting between formats (config / json /
#      binary / csv) on the way out.
#
# The seam contract this window teaches: a node participates in saves by exposing
# `save_state() -> Dictionary` and `load_state(state: Dictionary)`. No base class, no
# registration - the Save System duck-types the pair (persist group, Save Node State).

# Used only by the Save Slots export-conversion path (reads/writes through the pack's own
# backend). The preview runs through the public EventSheets API.
const SAVE_SYSTEM_SCRIPT: String = "res://eventsheet_addons/save_system/save_system_addon.gd"
const FORMATS: PackedStringArray = ["config", "json", "binary", "csv", "ini", "xml"]
const FORMAT_EXTENSIONS: Dictionary = {"config": ".cfg", "json": ".json", "binary": ".sav", "csv": ".csv", "ini": ".ini", "xml": ".xml"}
const SAVE_CHOICES := preload("res://addons/eventforge/compiler/save_choices.gd")
## The Save dropdown's choices in their order; "" is Never, which stores nothing.
const SAVE_CHOICE_ORDER: PackedStringArray = ["", "auto", "load", "save", "manual"]

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
var _what_object_picker: OptionButton = null
var _what_rows: GridContainer = null
var _what_summary: Label = null
var _where_kept: VBoxContainer = null


func init(dock: Control) -> void:
	_dock = dock


## What each format is and when it is the right one - the line the open list shows on hover. Each
## sentence is written out inside its translate() call so the translation harvest finds it.
static func format_description(fmt: String) -> String:
	match fmt:
		"config":
			return EventSheetL10n.translate("Godot's ConfigFile: plain text, one section per object. Readable and easy to fix by hand. The default, good for most games.")
		"json":
			return EventSheetL10n.translate("Plain text that almost every tool and website can read. Good when a server, a website or another program reads the saves too.")
		"binary":
			return EventSheetL10n.translate("Godot's compact binary form. Smallest and fastest; not readable in a text editor. Good for big saves (open worlds, many objects).")
		"csv":
			return EventSheetL10n.translate("One row per value, which opens in a spreadsheet. Good for checking balance numbers in a spreadsheet.")
		"ini":
			return EventSheetL10n.translate("The classic settings-file layout, readable by many older tools. Good when modders expect a familiar file.")
		"xml":
			return EventSheetL10n.translate("Tagged text that many tools can check against a schema. Good when another tool needs to validate the file.")
	return ""


func open() -> void:
	if _window == null:
		_build_window()
	_refresh_what()
	_refresh_preview_addons()
	_refresh_slots()
	_window.popup_centered(Vector2i(820, 620))


# ── Window construction ─────────────────────────────────────────────────────────────


func _build_window() -> void:
	_window = Window.new()
	_window.title = "Save Studio"
	_window.close_requested.connect(func() -> void: _window.hide())
	# An undo, or a choice made from the sheet, while the window sat behind the editor.
	_window.focus_entered.connect(_refresh_what)
	var tabs: TabContainer = TabContainer.new()
	tabs.add_child(_build_what_tab())
	tabs.add_child(_build_preview_tab())
	tabs.add_child(_build_slots_tab())
	_window.add_child(EventSheetPopupUI.window_body(tabs))
	_dock.add_child(_window)


func _build_preview_tab() -> Control:
	var box: VBoxContainer = EventSheetPopupUI.form_box()
	box.name = "Format Preview"
	box.add_child(EventSheetPopupUI.hint_label("See what an addon's save looks like on disk before you commit to a format. The preview runs the real save pipeline on the addon's save_state() snapshot (default values - run the game and check Save Slots for live data)."))
	_preview_addon_picker = OptionButton.new()
	_preview_addon_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(EventSheetPopupUI.form_row("Addon", _preview_addon_picker))
	_preview_format_picker = EventSheetPopupUI.described_option()
	for fmt: String in FORMATS:
		EventSheetPopupUI.add_described_item(_preview_format_picker, "%s  (save_0%s)" % [fmt, FORMAT_EXTENSIONS[fmt]],
			format_description(fmt))
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
	_slots_convert_picker = EventSheetPopupUI.described_option()
	EventSheetPopupUI.add_described_item(_slots_convert_picker, "keep format",
		EventSheetL10n.translate("Export the file exactly as it was written."))
	for fmt: String in FORMATS:
		EventSheetPopupUI.add_described_item(_slots_convert_picker, "as %s" % fmt,
			format_description(fmt))
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
	# The public API enumerates the bundled packs that ship the seam.
	for path: String in EventSheets.save_capable_scripts():
		_preview_addons.append({"label": path.get_base_dir().get_file().capitalize(), "script": path})
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
			_preview_output.text = "Neither %s nor its children expose save_state() yet - give its variables a Save choice in What gets saved." % node.name
			return
	else:
		var instance: Node = (load(str(entry["script"])) as GDScript).new()
		snapshot = instance.call("save_state")
		key = str(entry["label"])
		instance.free()
	# The public API runs the real Save System backend and returns the on-disk text.
	_preview_output.text = EventSheets.preview_save(snapshot, FORMATS[_preview_format_picker.selected], key)


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
	for file: String in slot_files(DirAccess.get_files_at("user://"), _slot_file_pattern()):
		var path: String = "user://%s" % file
		_slots_files.append(path)
		var size_kb: float = FileAccess.get_file_as_bytes(path).size() / 1024.0
		var stamp: String = Time.get_datetime_string_from_unix_time(FileAccess.get_modified_time(path), true)
		_slots_list.add_item("%s   (%.1f KB, %s)" % [file, size_kb, stamp])


## The save files among `file_names`: the ones the Save System's slot pattern names
## ("save_{slot}.cfg" makes save_0.cfg, save_1.cfg...), in that pattern's extension or any other
## save format's. The editor's own settings files and anything else in user:// stay out.
static func slot_files(file_names: PackedStringArray, pattern: String) -> PackedStringArray:
	var stem: String = pattern.get_basename()
	var extensions: PackedStringArray = PackedStringArray(FORMAT_EXTENSIONS.values())
	if not pattern.get_extension().is_empty() and not extensions.has(".%s" % pattern.get_extension()):
		extensions.append(".%s" % pattern.get_extension())
	var matcher: RegEx = RegEx.create_from_string("^%s$" % _regex_escape(stem).replace("\\{slot\\}", "\\d+"))
	var found: PackedStringArray = PackedStringArray()
	for file: String in file_names:
		if extensions.has(".%s" % file.get_extension()) and matcher.search(file.get_basename()) != null:
			found.append(file)
	return found


static func _regex_escape(text: String) -> String:
	var escaped: String = ""
	for character: String in text:
		escaped += ("\\" + character) if "\\^$.|?*+()[]{}".contains(character) else character
	return escaped


## The slot file pattern the Save System pack declares, or its shipped default when the pack is absent.
func _slot_file_pattern() -> String:
	var pack: Script = load(SAVE_SYSTEM_SCRIPT) as Script if ResourceLoader.exists(SAVE_SYSTEM_SCRIPT) else null
	var declared: Variant = pack.get_property_default_value("file_pattern") if pack != null else null
	return str(declared) if declared is String and not str(declared).is_empty() else "save_{slot}.cfg"


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
		"ini":
			return "ini"
		"xml":
			return "xml"
		"cfg":
			return "config"
	return "binary"


# ── What gets saved: one Save choice per variable ───────────────────────────────────


## The name a Save choice shows in its dropdown and in the legend.
static func save_choice_name(choice: String) -> String:
	match choice:
		"auto":
			return EventSheetL10n.translate("Auto")
		"load":
			return EventSheetL10n.translate("Load only")
		"save":
			return EventSheetL10n.translate("Save only")
		"manual":
			return EventSheetL10n.translate("Manually")
	return EventSheetL10n.translate("Never")


## What a Save choice does, in one sentence - the line its option shows on hover and the legend
## repeats. Each sentence is written out inside its translate() call so the translation harvest finds it.
static func save_choice_description(choice: String) -> String:
	match choice:
		"auto":
			return EventSheetL10n.translate("Loaded when the object enters the game, saved when it leaves (and when the game quits). The easy default.")
		"load":
			return EventSheetL10n.translate("Loaded automatically, but only saved when your events say Save Game.")
		"save":
			return EventSheetL10n.translate("Saved automatically, never loaded back: good for stats or play time.")
		"manual":
			return EventSheetL10n.translate("Only when your events say Save Game / Load Game: checkpoints and save slots.")
	return EventSheetL10n.translate("Not saved. It starts from its default every time.")


## What a Save choice is usually for - the second line of its option's hover.
static func save_choice_use(choice: String) -> String:
	match choice:
		"auto":
			return EventSheetL10n.translate("Use for: health, coins, unlocked doors.")
		"load":
			return EventSheetL10n.translate("Use for: settings you write yourself at a menu.")
		"save":
			return EventSheetL10n.translate("Use for: play time, total jumps, stats you read elsewhere.")
		"manual":
			return EventSheetL10n.translate("Use for: checkpoint position, save-slot games.")
	return EventSheetL10n.translate("Use for: timers, cooldowns, anything worked out again each run.")


## The variables of `sheet` a Save choice can be given: every variable but the constants and the
## object references (a Node, a Texture...), which point at things rather than hold state.
static func savable_variables(sheet: EventSheetResource) -> Array:
	return SAVE_CHOICES.variables_of(sheet).filter(func(variable: Dictionary) -> bool:
		return not ClassDB.class_exists(str(variable["type"])))


## The whole saving story of `object_name` in one sentence, from its variables' choices: who comes back
## by itself, who waits for Save Game / Load Game, who only loads, who is only written.
static func saving_line(object_name: String, variables: Array) -> String:
	var by_choice: Dictionary = {}
	for variable: Dictionary in variables:
		var names: PackedStringArray = by_choice.get(variable["choice"], PackedStringArray())
		names.append(str(variable["name"]))
		by_choice[variable["choice"]] = names
	var parts: PackedStringArray = PackedStringArray()
	_say_names(parts, by_choice.get("auto", PackedStringArray()), EventSheetL10n.translate("%s comes back by itself"),
		EventSheetL10n.translate("%s come back by themselves"))
	_say_names(parts, by_choice.get("manual", PackedStringArray()), EventSheetL10n.translate("%s only at your Save Game / Load Game"),
		EventSheetL10n.translate("%s only at your Save Game / Load Game"))
	_say_names(parts, by_choice.get("load", PackedStringArray()), EventSheetL10n.translate("%s loads by itself"),
		EventSheetL10n.translate("%s load by themselves"))
	_say_names(parts, by_choice.get("save", PackedStringArray()), EventSheetL10n.translate("%s is only written"),
		EventSheetL10n.translate("%s are only written"))
	if parts.is_empty():
		return EventSheetL10n.translate("Nothing is saved: %s starts fresh every time.") % object_name
	return EventSheetL10n.translate("%s: %s.") % [object_name, "; ".join(parts)]


static func _say_names(parts: PackedStringArray, names: PackedStringArray, one: String, many: String) -> void:
	if not names.is_empty():
		parts.append((one if names.size() == 1 else many) % ", ".join(names))


## Gives `variable_name` on `sheet` the Save choice `choice` ("" for Never). False when the sheet has no
## such variable or it already had that choice, so the undo funnel records nothing.
static func set_save_choice(sheet: EventSheetResource, variable_name: String, choice: String) -> bool:
	if sheet == null:
		return false
	if sheet.variables.get(variable_name) is Dictionary:
		var descriptor: Dictionary = sheet.variables[variable_name]
		var attributes: Dictionary = (descriptor.get("attributes") as Dictionary).duplicate() if descriptor.get("attributes") is Dictionary else {}
		if SAVE_CHOICES.choice_of(attributes) == choice:
			return false
		SAVE_CHOICES.set_choice(attributes, choice)
		if attributes.is_empty():
			descriptor.erase("attributes")
		else:
			descriptor["attributes"] = attributes
		sheet.variables[variable_name] = descriptor
		return true
	for entry: Variant in sheet.events:
		if entry is LocalVariable and (entry as LocalVariable).name == variable_name:
			var row_attributes: Dictionary = (entry as LocalVariable).attributes.duplicate()
			if SAVE_CHOICES.choice_of(row_attributes) == choice:
				return false
			SAVE_CHOICES.set_choice(row_attributes, choice)
			(entry as LocalVariable).attributes = row_attributes
			return true
	return false


## How a sheet is named in the Object picker and the saving line: its class name, else its file's name.
static func object_name(sheet: EventSheetResource, path: String) -> String:
	var named: String = sheet.custom_class_name.strip_edges() if sheet != null else ""
	if named.is_empty():
		named = path.get_file().get_basename() if not path.is_empty() else EventSheetL10n.translate("This sheet")
	return named


func _build_what_tab() -> Control:
	var box: VBoxContainer = EventSheetPopupUI.form_box()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var quick_start: RichTextLabel = RichTextLabel.new()
	quick_start.bbcode_enabled = true
	quick_start.fit_content = true
	quick_start.text = EventSheetL10n.translate("[b]Quick start:[/b] set a variable's [b]Save[/b] to [b]Auto[/b]. That's it: it is saved when the object leaves the game and loaded when it comes back.")
	box.add_child(quick_start)
	box.add_child(EventSheetPopupUI.hint_label(EventSheetL10n.translate("Pick when each variable is saved. Hover the choice, or any option in its list, to see what it does.")))
	_what_object_picker = OptionButton.new()
	_what_object_picker.item_selected.connect(func(index: int) -> void:
		_dock.activate_open_tab(index)
		_refresh_what())
	box.add_child(EventSheetPopupUI.form_row(EventSheetL10n.translate("Object"), _what_object_picker))
	_what_rows = GridContainer.new()
	_what_rows.columns = 4
	_what_rows.add_theme_constant_override("h_separation", EventSheetPalette.scaled(12))
	box.add_child(EventSheetPopupUI.panel_section(_what_rows))
	_what_summary = Label.new()
	_what_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_what_summary.add_theme_color_override("font_color", EventSheetPopupUI.text_color())
	box.add_child(_what_summary)
	var legend: Array = []
	for choice: String in SAVE_CHOICE_ORDER:
		legend.append(PackedStringArray([save_choice_name(choice), save_choice_description(choice)]))
	box.add_child(EventSheetPopupUI.compact_table(PackedStringArray([EventSheetL10n.translate("Save"),
		EventSheetL10n.translate("What it does")]), legend, 1))
	_where_kept = VBoxContainer.new()
	box.add_child(EventSheetPopupUI.titled_card(EventSheetL10n.translate("Where it is kept"), _where_kept))
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = EventSheetL10n.translate("What gets saved")
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.add_child(box)
	return scroll


## Lists the open sheets in the Object picker and the active one's variables, each with its Save choice.
func _refresh_what() -> void:
	if _what_rows == null:
		return
	_what_object_picker.clear()
	for tab: Dictionary in _dock._open_tabs:
		var path: String = str(tab.get("path", ""))
		var named: String = object_name(tab.get("sheet") as EventSheetResource, path)
		_what_object_picker.add_item("%s (%s)" % [named, path.get_file()] if not path.is_empty() else named)
	_what_object_picker.select(_dock._active_tab_index)
	for child: Node in _what_rows.get_children():
		_what_rows.remove_child(child)
		child.queue_free()
	var sheet: EventSheetResource = _dock._current_sheet
	var variables: Array = savable_variables(sheet)
	var mono: Font = EventSheetPopupUI.editor_font("doc_source")
	for variable: Dictionary in variables:
		# Type and name in the code font, as written; the variable's own description beside them.
		for cell: Array in [[variable["type"], true, true], [variable["name"], true, false], [variable["description"], false, true]]:
			var label: Label = Label.new()
			label.text = str(cell[0])
			label.add_theme_color_override("font_color", EventSheetPopupUI.muted_text_color() if cell[2] else EventSheetPopupUI.text_color())
			if cell[1] and mono != null:
				label.add_theme_font_override("font", mono)
			_what_rows.add_child(label)
		_what_rows.get_child(_what_rows.get_child_count() - 1).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_what_rows.add_child(_save_choice_dropdown(str(variable["name"]), str(variable["choice"])))
	_what_summary.text = saving_line(object_name(sheet, _dock._current_sheet_path), variables) if sheet != null \
		else EventSheetL10n.translate("Open a sheet to choose what it saves.")
	_fill_where_kept()


## The Save dropdown of one variable: every choice with its sentence on hover, the chosen one's
## sentence as the dropdown's own tooltip.
func _save_choice_dropdown(variable_name: String, chosen: String) -> OptionButton:
	var dropdown: OptionButton = EventSheetPopupUI.described_option()
	for choice: String in SAVE_CHOICE_ORDER:
		var index: int = EventSheetPopupUI.add_described_item(dropdown, save_choice_name(choice),
			"%s\n%s" % [save_choice_description(choice), save_choice_use(choice)], choice)
		if choice == chosen:
			dropdown.select(index)
	EventSheetPopupUI.follow_description(dropdown)
	dropdown.item_selected.connect(func(index: int) -> void:
		var choice: String = str(dropdown.get_item_metadata(index))
		var changed: bool = _dock._perform_undoable_sheet_edit("Set Save Choice", func() -> bool:
			return set_save_choice(_dock._current_sheet, variable_name, choice))
		if changed:
			_dock._mark_dirty(EventSheetL10n.translate("%s is now saved: %s.") % [variable_name, save_choice_name(choice)])
		_refresh_what())
	return dropdown


## Where it is kept: what each step writes and which file it lands in - in the editor once, and in
## the game every run.
func _fill_where_kept() -> void:
	for child: Node in _where_kept.get_children():
		_where_kept.remove_child(child)
		child.queue_free()
	var script_file: String = _dock._current_sheet_path.get_file() if not _dock._current_sheet_path.is_empty() \
		else EventSheetL10n.translate("the object's script")
	var slot_file: String = "user://%s" % _slot_file_pattern().replace("{slot}", "0")
	var columns: PackedStringArray = PackedStringArray([EventSheetL10n.translate("What happens"), EventSheetL10n.translate("File")])
	_where_kept.add_child(EventSheetPopupUI.small_caps_label(EventSheetL10n.translate("In the editor (once, while you build)")))
	_where_kept.add_child(EventSheetPopupUI.compact_table(columns, [
		PackedStringArray([EventSheetL10n.translate("A variable's Save choice adds save_state() and load_state() to the object's script, listing exactly those variables."), script_file]),
		PackedStringArray([EventSheetL10n.translate("The same script puts the object in the \"persist\" group as it starts, so Save Game finds it."), script_file]),
	], 0))
	_where_kept.add_child(EventSheetPopupUI.small_caps_label(EventSheetL10n.translate("In the game (every time it runs)")))
	_where_kept.add_child(EventSheetPopupUI.compact_table(columns, [
		PackedStringArray([EventSheetL10n.translate("Auto and Load only variables load when their object enters the tree (_ready); Auto and Save only ones save when it leaves (_exit_tree) or the game quits."), SAVE_CHOICES.STORE]),
		PackedStringArray([EventSheetL10n.translate("Save Game asks every \"persist\" object for save_state() and writes one file per slot."), slot_file]),
		PackedStringArray([EventSheetL10n.translate("Load Game reads that slot, hands each object its part through load_state(), then fires On After Load."), slot_file]),
		PackedStringArray([EventSheetL10n.translate("Save Number / Save Value keep single values in the same slot file, under their own name."), slot_file]),
	], 0))
	_where_kept.add_child(EventSheetPopupUI.hint_label(EventSheetL10n.translate("Everything a save holds lives on the player's computer, never in res://: deleting a save never touches your project.")))
