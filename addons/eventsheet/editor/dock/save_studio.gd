@tool
class_name EventSheetSaveStudio
extends RefCounted
# Saving your game (Tools menu, "Save Studio"), one tab each: What gets saved (a Save choice per
# variable, which compiler/save_choices.gd turns into code), File and format (the Save System node's
# own settings, on the scene the SaveSystem autoload names), Save slots (the files in user://), Look
# inside a save (a slot, the selected node or a pack, in plain words) and Player settings (the
# settings.cfg and bindings.cfg files kept apart from the slots). Everything shown is read through
# the shipping code - the Save System's backends, Godot's ConfigFile, the Game Settings pack's own
# rows - so the window cannot drift from what a game really writes.
#
# The seam this window teaches: a node joins a save by exposing `save_state() -> Dictionary` and
# `load_state(state: Dictionary)`. No base class, no registration - the Save System duck-types it.

const SAVE_SYSTEM_SCRIPT: String = "res://eventsheet_addons/save_system/save_system_addon.gd"
const GAME_SETTINGS_SCRIPT: String = "res://eventsheet_addons/game_settings/game_settings_addon.gd"
## The built-in bindings rows, whose BINDINGS_FILE names the file Save Bindings writes.
const BINDINGS_MODULE: String = "res://addons/eventforge/registration/modules/controls_aces.gd"
const SAVE_AUTOLOAD: String = "SaveSystem"
## Where "Keep them in a scene" puts the Save System node when the autoload is a bare script.
const SETTINGS_SCENE: String = "res://save_system.tscn"
const FORMATS: PackedStringArray = ["config", "json", "binary", "csv", "ini", "xml"]
const FORMAT_EXTENSIONS: Dictionary = {"config": ".cfg", "json": ".json", "binary": ".sav", "csv": ".csv", "ini": ".ini", "xml": ".xml"}
## The Save System properties this window reads: its node's own, so the Inspector shows the same.
const SETTINGS: PackedStringArray = ["format", "file_pattern", "save_directory", "encryption_key",
	"backup_count", "autosave_interval", "section"]
## One object's everyday values: what a format preview writes, so every format shows the same save.
const SAMPLE_STATE: Dictionary = {"health": 3, "coins": 42, "position": Vector2(120, 64)}
## The pack's Open Save Folder row, as the picker files it - what "For your players" hides.
const OPEN_FOLDER_PROVIDER: String = "SaveSystemAddon"
const OPEN_FOLDER_ACE: String = "method:open_save_folder"
const SMALL_PROMPT_PATH: String = "res://addons/eventsheet/editor/small_prompt.gd"
const SAVE_CHOICES := preload("res://addons/eventforge/compiler/save_choices.gd")
## The Save dropdown's choices in their order; "" is Never, which stores nothing.
const SAVE_CHOICE_ORDER: PackedStringArray = ["", "auto", "load", "save", "manual"]

var _dock: Control = null
var _window: Window = null
var _tabs: TabContainer = null
var _settings: Dictionary = {}
var _format_pick: OptionButton = null
var _file_name: Label = null
## The folder, key, backups and autosave fields, keyed by the Save System property each one writes.
var _form: EventSheetFieldForm = null
var _format_preview: CodeEdit = null
var _preview_title: Label = null
var _scene_note: EventSheetPopupUI.StateNote = null
var _scene_button: Button = null
var _slot_rows: VBoxContainer = null
var _players_open: CheckBox = null
var _players_detail: Label = null
var _peek_pick: OptionButton = null
var _peek_tab: Control = null
var _peek_sources: Array = []
var _peek_heading: Label = null
var _peek_table: Control = null
var _peek_file: CodeEdit = null
var _settings_views: Array = []
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


## A format's name as the dropdown shows it, with the ending its files get: "JSON (.json)".
static func format_label(fmt: String) -> String:
	var words: String = fmt.to_upper()
	if fmt == "config":
		words = EventSheetL10n.translate("Godot settings file")
	elif fmt == "binary":
		words = EventSheetL10n.translate("Binary")
	return "%s (%s)" % [words, FORMAT_EXTENSIONS.get(fmt, "")]


func open() -> void:
	if _window == null:
		_build_window()
	_load_settings()
	_refresh_what()
	_refresh_slots()
	_refresh_peek_sources()
	_window.popup_centered(Vector2i(EventSheetPalette.scaled(900), EventSheetPalette.scaled(680)))


# ── Window construction ─────────────────────────────────────────────────────────────


func _build_window() -> void:
	_window = Window.new()
	_window.title = EventSheetL10n.translate("Saving your game")
	_window.close_requested.connect(func() -> void: _window.hide())
	# Coming back to the window: an undo or a choice made from the sheet, or new slots a game run wrote.
	_window.focus_entered.connect(func() -> void:
		_refresh_what()
		_refresh_slots())
	_tabs = TabContainer.new()
	for page: Control in [_build_what_tab(), _build_file_tab(), _build_slots_tab(), _build_peek_tab(), _build_player_settings_tab()]:
		_tabs.add_child(page)
		_tabs.set_tab_title(_tabs.get_tab_count() - 1, str(page.get_meta("title")))
	var body: VBoxContainer = EventSheetPopupUI.form_box()
	body.add_child(EventSheetPopupUI.hint_label(EventSheetL10n.translate("Choose what to remember between play sessions, then save and load from your events with the Save System's actions.")))
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_tabs)
	_window.add_child(EventSheetPopupUI.window_body(body))
	_dock.add_child(_window)


## A tab's column, carrying its (translated) title for the tab bar.
func _tab(title: String) -> VBoxContainer:
	var box: VBoxContainer = EventSheetPopupUI.form_box()
	box.set_meta("title", title)
	return box


static func _muted(text: String, wrap_width: float = EventSheetPopupUI.HINT_WRAP_WIDTH) -> Label:
	var label: Label = EventSheetPopupUI.hint_label(text, wrap_width)
	label.modulate = Color.WHITE
	label.add_theme_color_override("font_color", EventSheetPopupUI.muted_text_color())
	return label


## A plain label, in one of the window kit's text colours when `color` is given.
static func _label(text: String, color: Color = Color(0.0, 0.0, 0.0, 0.0)) -> Label:
	var label: Label = Label.new()
	label.text = text
	if color.a > 0.0:
		label.add_theme_color_override("font_color", color)
	return label


static func _code_box(lines_high: float) -> CodeEdit:
	var code: CodeEdit = CodeEdit.new()
	EventSheetPopupUI.configure_code_editor(code)
	code.editable = false
	code.custom_minimum_size = Vector2(0.0, EventSheetPalette.scaled_f(18.0 * lines_high))
	code.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return code


## `content` in a scroll that only scrolls down and takes the tab's spare height.
static func _scrolled(content: Control) -> ScrollContainer:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	return scroll


## A card that takes the width it is given.
static func _card(content: Control) -> PanelContainer:
	var panel: PanelContainer = EventSheetPopupUI.panel_section(content)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return panel


static func _button(text: String, pressed: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.pressed.connect(pressed)
	return button


# ── File and format: the Save System node's own settings ────────────────────────────


func _build_file_tab() -> Control:
	var box: VBoxContainer = _tab(EventSheetL10n.translate("File and format"))
	box.add_child(_muted(EventSheetL10n.translate("How the save files are written. These are the Save System node's own settings, so they also show in its Inspector.")))
	_scene_note = EventSheetPopupUI.StateNote.new()
	box.add_child(_scene_note)
	_scene_button = _button(EventSheetL10n.translate("Keep them in a scene"), _keep_settings_in_scene)
	_scene_button.tooltip_text = EventSheetL10n.translate("Saves the Save System node as save_system.tscn and points the SaveSystem global at it, so its settings can change here and in the Inspector.")
	_scene_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	box.add_child(_scene_button)
	_format_pick = EventSheetPopupUI.described_option()
	for fmt: String in FORMATS:
		EventSheetPopupUI.add_described_item(_format_pick, format_label(fmt), format_description(fmt), fmt)
	_format_pick.item_selected.connect(func(index: int) -> void: _choose_format(str(_format_pick.get_item_metadata(index))))
	box.add_child(EventSheetPopupUI.form_row(EventSheetL10n.translate("File format"),
		EventSheetPopupUI.described_field(_format_pick), EventSheetPopupUI.LABEL_MIN_WIDTH,
		EventSheetL10n.translate("The kind of file each save slot is written as.")))
	_file_name = Label.new()
	var mono: Font = EventSheetPopupUI.editor_font("doc_source")
	if mono != null:
		_file_name.add_theme_font_override("font", mono)
	box.add_child(EventSheetPopupUI.form_row(EventSheetL10n.translate("File name"), _file_name,
		EventSheetPopupUI.LABEL_MIN_WIDTH, EventSheetL10n.translate("Each slot gets its own file; the number is the slot. The ending follows the format.")))
	var fields: Array[EventSheetFieldSpec] = [
		EventSheetPopupUI.text_field("save_directory", EventSheetL10n.translate("Folder")).tooltip(
			EventSheetL10n.translate("Where save files go. user:// is the player's own data folder.")),
		EventSheetPopupUI.text_field("encryption_key", EventSheetL10n.translate("Encryption key")).placeholder(
			EventSheetL10n.translate("(none: the file stays readable)")).tooltip(
			EventSheetL10n.translate("Optional. With a key, the file is encrypted, so players cannot read or edit it in a text editor.")),
		EventSheetPopupUI.number_field("backup_count", EventSheetL10n.translate("Backups to keep")).at_most(50.0).stepping(1.0, true).tooltip(
			EventSheetL10n.translate("How many older copies of each slot to keep, for Restore Slot From Backup.")),
		EventSheetPopupUI.number_field("autosave_interval", EventSheetL10n.translate("Autosave every")).at_most(600.0).tooltip(
			EventSheetL10n.translate("Save by itself every few seconds. 0 means only when your events say Save Game.")),
	]
	_form = EventSheetPopupUI.form(box, fields, "Save studio")
	(_form.control("autosave_interval") as SpinBox).suffix = EventSheetL10n.translate("seconds (0 = off)")
	# A typed setting is written when it is submitted or left; a number as soon as it changes.
	for property: String in _form.field_ids():
		var field: Control = _form.control(property)
		if field is LineEdit:
			(field as LineEdit).text_submitted.connect(func(_text: String) -> void: _write_field(property))
			field.focus_exited.connect(_write_field.bind(property))
		else:
			(field as SpinBox).value_changed.connect(func(_value: float) -> void: _write_field(property))
	_preview_title = EventSheetPopupUI.small_caps_label("", EventSheetPopupUI.muted_text_color())
	box.add_child(_preview_title)
	_format_preview = _code_box(6.0)
	box.add_child(_format_preview)
	box.add_child(_muted(EventSheetL10n.translate("Each change is saved into the Save System's scene at once; change it back here or in its Inspector to undo it.")))
	return box


## Where the Save System's settings live: the scene the SaveSystem autoload names, or "" when the
## autoload is a bare script or is not registered at all.
static func settings_scene(autoload_value: String) -> String:
	var path: String = autoload_value.trim_prefix("*")
	return path if path.get_extension() in ["tscn", "scn"] else ""


## The settings as the game will run them: the pack script's defaults, overlaid by whatever the
## scene's root node changes. Read off the scene's state, so nothing is instantiated to ask.
static func read_settings(scene_path: String) -> Dictionary:
	var values: Dictionary = {}
	var pack: Script = load(SAVE_SYSTEM_SCRIPT) as Script if ResourceLoader.exists(SAVE_SYSTEM_SCRIPT) else null
	for property: String in SETTINGS:
		values[property] = pack.get_property_default_value(property) if pack != null else null
	if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
		return values
	var state: SceneState = (ResourceLoader.load(scene_path, "", ResourceLoader.CACHE_MODE_REPLACE) as PackedScene).get_state()
	for index: int in range(state.get_node_property_count(0)):
		if SETTINGS.has(str(state.get_node_property_name(0, index))):
			values[str(state.get_node_property_name(0, index))] = state.get_node_property_value(0, index)
	return values


## Writes one setting onto the scene's root node and saves the scene. Returns the save's error.
static func write_setting(scene_path: String, property: String, value: Variant) -> Error:
	var scene: PackedScene = ResourceLoader.load(scene_path, "", ResourceLoader.CACHE_MODE_REPLACE) as PackedScene
	if scene == null:
		return ERR_FILE_NOT_FOUND
	var node: Node = scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	node.set(property, value)
	var packed: Error = scene.pack(node)
	node.free()
	return packed if packed != OK else ResourceSaver.save(scene, scene_path)


## Saves the Save System node as a scene and points the SaveSystem global at it - the way Godot keeps
## a node's settings, so they change here and in its Inspector alike. Returns "" or the problem.
static func make_settings_scene(scene_path: String) -> String:
	var node: Node = Node.new()
	node.name = SAVE_AUTOLOAD
	node.set_script(load(SAVE_SYSTEM_SCRIPT))
	var scene: PackedScene = PackedScene.new()
	scene.pack(node)
	node.free()
	var saved: Error = ResourceSaver.save(scene, scene_path)
	if saved != OK:
		return EventSheetL10n.translate("Could not save %s (error %d).") % [scene_path, saved]
	ProjectSettings.set_setting("autoload/%s" % SAVE_AUTOLOAD, "*%s" % scene_path)
	if Engine.is_editor_hint():
		ProjectSettings.save()
	return ""


## The slot file pattern with its ending swapped for the format's: save_{slot}.cfg -> save_{slot}.json.
static func pattern_for_format(pattern: String, fmt: String) -> String:
	var stem: String = pattern.get_basename() if not pattern.get_extension().is_empty() else pattern
	return stem + str(FORMAT_EXTENSIONS.get(fmt, ".%s" % pattern.get_extension()))


func _scene_path() -> String:
	return settings_scene(str(ProjectSettings.get_setting("autoload/%s" % SAVE_AUTOLOAD, "")))


func _pattern() -> String:
	return str(_settings.get("file_pattern", "save_{slot}.cfg"))


func _load_settings() -> void:
	var scene_path: String = _scene_path()
	_settings = read_settings(scene_path)
	var installed: bool = ResourceLoader.exists(SAVE_SYSTEM_SCRIPT)
	if not installed:
		_scene_note.say(EventSheetL10n.translate("The Save System pack is not installed (eventsheet_addons/save_system/)."))
	elif scene_path.is_empty() and ProjectSettings.has_setting("autoload/%s" % SAVE_AUTOLOAD):
		_scene_note.say(EventSheetL10n.translate("The SaveSystem global is its script, so these are the pack's defaults and cannot change here. Keep them in a scene to change them here and in the Inspector."), EventSheetPopupUI.TONE_WARNING)
	elif scene_path.is_empty():
		_scene_note.say(EventSheetL10n.translate("The Save System is not a global yet, so these are the pack's defaults. Keep them in a scene: it is added to Project Settings > Globals as SaveSystem."), EventSheetPopupUI.TONE_WARNING)
	else:
		_scene_note.say("")
	_scene_button.visible = scene_path.is_empty() and installed
	var editable: bool = not scene_path.is_empty()
	var fmt: String = str(_settings.get("format", "config"))
	EventSheetPopupUI.select_option(_format_pick, format_label(fmt))
	EventSheetPopupUI.follow_description(_format_pick)
	_format_pick.disabled = not editable
	for property: String in _form.field_ids():
		var field: Control = _form.control(property)
		field.set("editable", editable)
		if field is SpinBox:
			(field as SpinBox).set_value_no_signal(float(_settings.get(property, 0)))
		else:
			(field as LineEdit).text = str(_settings.get(property, ""))
	var file_name: String = _pattern().replace("{slot}", "0")
	_file_name.text = file_name
	# Upper case like every small-caps heading, but the file name reads exactly as written.
	_preview_title.text = EventSheetL10n.translate("What %s looks like in this format").to_upper().replace("%S", "%s") % file_name
	_format_preview.text = EventSheets.preview_save(SAMPLE_STATE, fmt, "player")


func _choose_format(fmt: String) -> void:
	if write_setting(_scene_path(), "file_pattern", pattern_for_format(_pattern(), fmt)) == OK:
		_write("format", fmt)


## Writes what one of the form's fields now says, when it can be written and differs from the scene's.
func _write_field(property: String) -> void:
	var value: Variant = _form.value(property)
	if value is String:
		value = (value as String).strip_edges()
	if _form.control(property).get("editable") and str(value) != str(_settings.get(property, "")):
		_write(property, value)


func _write(property: String, value: Variant) -> void:
	var scene_path: String = _scene_path()
	if scene_path.is_empty():
		return
	var error: Error = write_setting(scene_path, property, value)
	if error == OK:
		_dock._set_status(EventSheetL10n.translate("Saved %s into %s.") % [property, scene_path.get_file()])
	else:
		_dock._set_status(EventSheetL10n.translate("Could not save %s (error %d).") % [scene_path, error], true)
	_load_settings()
	_refresh_slots()


func _keep_settings_in_scene() -> void:
	var problem: String = make_settings_scene(SETTINGS_SCENE)
	_dock._set_status(problem if not problem.is_empty() else EventSheetL10n.translate("The SaveSystem global now runs save_system.tscn; its settings change here and in its Inspector."), not problem.is_empty())
	_load_settings()


# ── Save slots ─────────────────────────────────────────────────────────────────────


func _build_slots_tab() -> Control:
	var box: VBoxContainer = _tab(EventSheetL10n.translate("Save slots"))
	box.add_child(_muted(EventSheetL10n.translate("Each save slot is one file on the player's computer. Saves live in Godot's user:// folder, not in your project.")))
	_slot_rows = EventSheetPopupUI.form_box()
	_slot_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(_scrolled(_slot_rows))
	var actions: HBoxContainer = HBoxContainer.new()
	actions.add_child(_button(EventSheetL10n.translate("Open the save folder"), func() -> void:
		OS.shell_show_in_file_manager(ProjectSettings.globalize_path(_save_directory()))))
	# Which slot to copy is asked in the button's own list, filled from the folder as it opens.
	var copy_out: MenuButton = MenuButton.new()
	copy_out.text = EventSheetL10n.translate("Copy a slot out…")
	copy_out.flat = false
	copy_out.about_to_popup.connect(func() -> void:
		copy_out.get_popup().clear()
		for path: String in _slot_paths():
			copy_out.get_popup().add_item(path.get_file()))
	copy_out.get_popup().index_pressed.connect(func(index: int) -> void:
		_copy_slot_out(_save_directory().path_join(copy_out.get_popup().get_item_text(index))))
	actions.add_child(copy_out)
	box.add_child(actions)
	var players: VBoxContainer = EventSheetPopupUI.form_box()
	players.add_child(EventSheetPopupUI.small_caps_label(EventSheetL10n.translate("For your players, in the game"), EventSheetPopupUI.muted_text_color()))
	_players_open = CheckBox.new()
	_players_open.text = EventSheetL10n.translate("Players can open their save folder")
	_players_open.toggled.connect(_set_players_open)
	players.add_child(_players_open)
	players.add_child(_muted(EventSheetL10n.translate("Adds an Open Save Folder action. A button in your menu can then show players the folder that holds their saves in their own file manager (Explorer, Finder, Files), so they can back up, share or delete them.")))
	_players_detail = _muted("")
	players.add_child(_players_detail)
	box.add_child(EventSheetPopupUI.panel_section(players))
	return box


func _save_directory() -> String:
	return str(_settings.get("save_directory", "user://"))


func _slot_paths() -> PackedStringArray:
	var paths: PackedStringArray = PackedStringArray()
	for file: String in slot_files(DirAccess.get_files_at(_save_directory()), _pattern()):
		paths.append(_save_directory().path_join(file))
	return paths


func _refresh_slots() -> void:
	for old: Node in _slot_rows.get_children():
		old.queue_free()
	var paths: PackedStringArray = _slot_paths()
	if paths.is_empty():
		_slot_rows.add_child(_muted(EventSheetL10n.translate("No saves yet. Run the game and save, and each slot shows here.")))
	for path: String in paths:
		var words: VBoxContainer = VBoxContainer.new()
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var title: Label = _label(EventSheetL10n.translate("Slot %s") % slot_number(path.get_file(), _pattern()))
		title.tooltip_text = path
		title.mouse_filter = Control.MOUSE_FILTER_STOP
		words.add_child(title)
		words.add_child(_muted(slot_meta(FileAccess.get_modified_time(path), FileAccess.get_file_as_bytes(path).size(),
			int(Time.get_unix_time_from_system()))))
		var row: HBoxContainer = HBoxContainer.new()
		row.add_child(words)
		for button: Button in [_button(EventSheetL10n.translate("Look inside"), _look_inside.bind(path)),
				_button(EventSheetL10n.translate("Delete"), _ask_delete.bind(path))]:
			button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(button)
		_slot_rows.add_child(EventSheetPopupUI.panel_section(row))
	var shown: bool = not EventSheetVocabularyCatalog.hidden_keys().has(
		EventSheetVocabularyCatalog.key_for(OPEN_FOLDER_PROVIDER, OPEN_FOLDER_ACE))
	_players_open.set_pressed_no_signal(shown)
	_show_players_detail(shown)


## The save files among `file_names`: the ones the Save System's slot pattern names
## ("save_{slot}.cfg" makes save_0.cfg, save_1.cfg...), in that pattern's extension or any other
## save format's. The editor's own settings files and anything else in user:// stay out.
static func slot_files(file_names: PackedStringArray, pattern: String) -> PackedStringArray:
	var stem: String = pattern.get_basename()
	var extensions: Array = FORMAT_EXTENSIONS.values()
	if not pattern.get_extension().is_empty():
		extensions.append(".%s" % pattern.get_extension())
	var found: PackedStringArray = PackedStringArray()
	for file: String in file_names:
		# The slot is all digits, and the name is exactly the stem with that number in it.
		var number: String = slot_number(file, pattern)
		var digits: bool = number.lstrip("0123456789").is_empty() and (not number.is_empty() or not stem.contains("{slot}"))
		if extensions.has(".%s" % file.get_extension()) and digits and file.get_basename() == stem.replace("{slot}", number):
			found.append(file)
	return found


## The slot number a file name carries under the pattern: "save_12.json" under "save_{slot}.cfg" is "12".
static func slot_number(file_name: String, pattern: String) -> String:
	var stem: String = pattern.get_basename()
	return file_name.get_basename().trim_prefix(stem.get_slice("{slot}", 0)).trim_suffix(stem.get_slice("{slot}", 1))


## A slot's line under its name: when it was saved, in the reader's own clock, and how big it is.
static func slot_meta(saved_unix: int, size_bytes: int, now_unix: int) -> String:
	var bias: int = int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var saved: String = Time.get_datetime_string_from_unix_time(saved_unix + bias, true)
	var clock: String = saved.substr(11, 5)
	var when: String = EventSheetL10n.translate("Saved %s") % saved.substr(0, 16)
	if saved.begins_with(Time.get_date_string_from_unix_time(now_unix + bias)):
		when = EventSheetL10n.translate("Saved today at %s") % clock
	elif saved.begins_with(Time.get_date_string_from_unix_time(now_unix + bias - 86400)):
		when = EventSheetL10n.translate("Saved yesterday at %s") % clock
	return "%s · %.1f KB" % [when, size_bytes / 1024.0]


func _look_inside(path: String) -> void:
	_refresh_peek_sources()
	for index: int in range(_peek_sources.size()):
		if str((_peek_sources[index] as Dictionary).get("file", "")) == path:
			_peek_pick.select(index)
			EventSheetPopupUI.follow_description(_peek_pick)
	_show_peek()
	_tabs.current_tab = _peek_tab.get_index()


func _ask_delete(path: String) -> void:
	var delete: Callable = func() -> void:
		DirAccess.remove_absolute(path)
		_dock._set_status(EventSheetL10n.translate("Deleted %s.") % path.get_file())
		_refresh_slots()
		_refresh_peek_sources()
	load(SMALL_PROMPT_PATH).open(_dock, {
		"title": EventSheetL10n.translate("Delete this save?"),
		"say": EventSheetL10n.translate("The slot's file is removed from the save folder. The next Load Game of that slot finds nothing."),
		"list": [[path.get_file(), path.get_base_dir()]],
		"glyph": "!",
		"main": EventSheetL10n.translate("Keep it"),
		"danger": EventSheetL10n.translate("Delete"),
		"note": EventSheetL10n.translate("Ctrl+Z cannot bring a deleted save back."),
		"on_danger": delete,
	})


func _copy_slot_out(source: String) -> void:
	var filters: PackedStringArray = PackedStringArray()
	for fmt: String in FORMATS:
		filters.append("*%s ; %s" % [FORMAT_EXTENSIONS[fmt], format_label(fmt)])
	var copy: Callable = func(destination: String) -> void:
		var problem: String = copy_slot(source, destination, _settings)
		_dock._set_status(problem if not problem.is_empty() else EventSheetL10n.translate("Copied %s to %s.") % [source.get_file(), destination], not problem.is_empty())
	EventSheetPopupUI.browse_file(_window, filters, copy, {"save": true, "disk": true, "title": EventSheetL10n.translate("Copy a slot out")})


## Copies a slot file to `destination`. When the copy's ending names another format it is read and
## rewritten through the Save System's own backends, so the conversion is the shipping code path.
## Returns "" or the problem, in the reader's words.
static func copy_slot(source: String, destination: String, settings: Dictionary) -> String:
	var from_format: String = format_for_extension(source)
	var to_format: String = format_for_extension(destination)
	if from_format == to_format:
		var copied: Error = DirAccess.copy_absolute(source, destination)
		return "" if copied == OK else EventSheetL10n.translate("The copy failed (error %d).") % copied
	var reader: Node = _save_system(settings)
	var data: Dictionary = reader.call("read_file", source, from_format)
	reader.free()
	if data.is_empty():
		return EventSheetL10n.translate("Nothing readable in %s.") % source.get_file()
	var writer: Node = _save_system(settings)
	writer.set("save_directory", destination.get_base_dir())
	writer.set("file_pattern", destination.get_file())
	writer.set("format", to_format)
	var written: bool = writer.call("_write_all", data)
	writer.free()
	return "" if written else EventSheetL10n.translate("Could not write %s.") % destination


## A throwaway Save System node with these settings, for reading and converting files as the game would.
static func _save_system(settings: Dictionary) -> Node:
	var node: Node = (load(SAVE_SYSTEM_SCRIPT) as GDScript).new()
	for property: String in settings:
		if settings[property] != null:
			node.set(property, settings[property])
	return node


static func format_for_extension(path: String) -> String:
	var fmt: Variant = FORMAT_EXTENSIONS.find_key(".%s" % path.get_extension().to_lower())
	return "binary" if fmt == null else str(fmt)


## Shows or hides the pack's Open Save Folder row in Add Action - the reader's own hide, the same
## one the picker's "Hide this entry" writes, so it is undone the same way.
func _set_players_open(shown: bool) -> void:
	EventSheetVocabularyCatalog.set_override(OPEN_FOLDER_PROVIDER, OPEN_FOLDER_ACE, {"hidden": null if shown else true})
	_show_players_detail(shown)


func _show_players_detail(shown: bool) -> void:
	if not shown:
		_players_detail.text = EventSheetL10n.translate("Off: the action stays out of Add Action, and players never see where saves are kept.")
		return
	_players_detail.text = EventSheetL10n.translate("Opens %s, which on this computer is %s. Works on Windows, macOS and Linux. On the web and on phones there is no folder to show: the action does nothing there, and the Can Open Save Folder condition lets you hide the button.") % [
		_save_directory(), ProjectSettings.globalize_path(_save_directory())]


# ── Look inside a save ──────────────────────────────────────────────────────────────


func _build_peek_tab() -> Control:
	var box: VBoxContainer = _tab(EventSheetL10n.translate("Look inside a save"))
	_peek_tab = box
	_peek_pick = EventSheetPopupUI.described_option()
	_peek_pick.item_selected.connect(func(_index: int) -> void: _show_peek())
	box.add_child(EventSheetPopupUI.form_row(EventSheetL10n.translate("Save of"), EventSheetPopupUI.described_field(_peek_pick),
		EventSheetPopupUI.LABEL_MIN_WIDTH, EventSheetL10n.translate("A save slot on disk, the node selected in the scene, or a bundled pack.")))
	_peek_heading = _muted("")
	box.add_child(_peek_heading)
	_peek_table = VBoxContainer.new()
	box.add_child(EventSheetPopupUI.panel_section(_peek_table))
	var reveal: Button = Button.new()
	reveal.text = EventSheetL10n.translate("Show the file as Godot writes it")
	reveal.toggle_mode = true
	reveal.flat = true
	reveal.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	box.add_child(reveal)
	_peek_file = _code_box(8.0)
	_peek_file.visible = false
	reveal.toggled.connect(func(on: bool) -> void: _peek_file.visible = on)
	box.add_child(_peek_file)
	return box


## The saves to look inside: each slot on disk, the selected scene node (with its behavior children),
## and every bundled pack that snapshots itself, so a composition is seen before it is ever saved.
func _refresh_peek_sources() -> void:
	_peek_sources.clear()
	_peek_pick.clear()
	for path: String in _slot_paths():
		_peek_sources.append({"label": path.get_file(), "file": path})
		EventSheetPopupUI.add_described_item(_peek_pick, path.get_file(), EventSheetL10n.translate("A save file on disk, read the way Load Game reads it."))
	if Engine.is_editor_hint() and _dock.is_inside_tree():
		var selection: Array[Node] = EditorInterface.get_selection().get_selected_nodes()
		if not selection.is_empty():
			_peek_sources.append({"label": str(selection[0].name), "node": selection[0]})
			EventSheetPopupUI.add_described_item(_peek_pick, EventSheetL10n.translate("Selected node: %s") % selection[0].name,
				EventSheetL10n.translate("What Save Game would write for this node and its behaviors right now."))
	for path: String in EventSheets.save_capable_scripts():
		var label: String = path.get_base_dir().get_file().capitalize()
		_peek_sources.append({"label": label, "script": path})
		EventSheetPopupUI.add_described_item(_peek_pick, label, EventSheetL10n.translate("What this pack saves of itself, from its default values."))
	EventSheetPopupUI.follow_description(_peek_pick)
	_show_peek()


func _show_peek() -> void:
	for old: Node in _peek_table.get_children():
		old.queue_free()
	var index: int = _peek_pick.selected
	if index < 0 or index >= _peek_sources.size():
		_peek_heading.text = EventSheetL10n.translate("Nothing to look inside yet.")
		_peek_file.text = ""
		return
	var entry: Dictionary = _peek_sources[index]
	# Read the way the game reads it: a file through the Save System's backends, a node through the
	# same walk Save Node State takes (the node and its behavior children).
	var reader: Node = _save_system(_settings)
	var data: Dictionary = {}
	if entry.has("file"):
		var path: String = str(entry["file"])
		data = reader.call("read_file", path, reader.call("save_file_format", path))
		_peek_heading.text = EventSheetL10n.translate("What %s holds, in plain words:") % path.get_file()
		_peek_file.text = file_text(FileAccess.get_file_as_bytes(path))
	else:
		if entry.has("node"):
			data = reader.call("_collect_node_state", entry["node"])
		else:
			var instance: Node = (load(str(entry["script"])) as GDScript).new()
			data = instance.call("save_state")
			instance.free()
		_peek_heading.text = EventSheetL10n.translate("What a save of %s would hold right now, in plain words:") % entry["label"]
		_peek_file.text = EventSheets.preview_save(data, str(_settings.get("format", "config")), str(entry["label"]))
	reader.free()
	var rows: Array = plain_rows(data)
	if rows.is_empty():
		_peek_table.add_child(_muted(EventSheetL10n.translate("It holds nothing yet. A node joins a save by exposing save_state(); a Save choice on its variables writes the pair.")))
	else:
		_peek_table.add_child(EventSheetPopupUI.compact_table(PackedStringArray([EventSheetL10n.translate("Name"),
			EventSheetL10n.translate("Value")]), rows, 1))


## A file's bytes as the reader can see them: its text, or the head of a binary file in hex.
static func file_text(bytes: PackedByteArray) -> String:
	if bytes.is_empty() or bytes.slice(0, mini(256, bytes.size())).find(0) != -1:
		return EventSheetL10n.translate("Binary file, %d bytes (not text). First bytes:") % bytes.size() \
			+ "\n" + bytes.slice(0, mini(160, bytes.size())).hex_encode()
	return bytes.get_string_from_utf8()


## A save's values as [name, value in plain words] rows. Nested snapshots read as paths
## ("Health/current"); a node's own part ("." in a snapshot) reads under no name at all.
static func plain_rows(data: Dictionary, prefix: String = "") -> Array:
	var rows: Array = []
	for key: Variant in data:
		var value: Variant = data[key]
		var name: String = prefix if str(key) == "." else prefix + str(key)
		if value is Dictionary and not (value as Dictionary).is_empty():
			rows.append_array(plain_rows(value, name if name.is_empty() or str(key) == "." else name + "/"))
		else:
			rows.append(PackedStringArray([name, plain_words(value)]))
	return rows


## One saved value, said plainly: a position as "x 120, y 64", a list by its length, a flag as yes/no.
static func plain_words(value: Variant) -> String:
	match typeof(value):
		TYPE_BOOL:
			return EventSheetL10n.translate("yes") if value else EventSheetL10n.translate("no")
		TYPE_FLOAT:
			return _number(value)
		TYPE_VECTOR2, TYPE_VECTOR2I:
			return "x %s, y %s" % [_number(value.x), _number(value.y)]
		TYPE_VECTOR3, TYPE_VECTOR3I:
			return "x %s, y %s, z %s" % [_number(value.x), _number(value.y), _number(value.z)]
		TYPE_ARRAY, TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_FLOAT32_ARRAY:
			return EventSheetL10n.translate("a list of %d") % value.size()
		TYPE_DICTIONARY:
			return EventSheetL10n.translate("nothing")
	return str(value)


## A number without a trailing ".0" when it is whole: 120, not 120.0.
static func _number(value: float) -> String:
	return str(int(value)) if is_equal_approx(value, roundf(value)) and absf(value) < 1e15 else str(value)


# ── Player settings: the files that live apart from the save slots ──────────────────


func _build_player_settings_tab() -> Control:
	var box: VBoxContainer = _tab(EventSheetL10n.translate("Player settings"))
	var head: HBoxContainer = HBoxContainer.new()
	var why: Label = _muted(EventSheetL10n.translate("Options, key bindings and graphics are kept in their own files, apart from save slots, so starting a new game never resets the volume or the controls."), EventSheetPalette.scaled_f(300.0))
	why.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(why)
	var switch: EventSheetPopupUI.ViewSwitch = EventSheetPopupUI.ViewSwitch.new(EventSheetPopupUI.ViewSwitch.BOTH, {
		EventSheetPopupUI.ViewSwitch.SHEET: [EventSheetL10n.translate("Events"), EventSheetL10n.translate("Each use as the rows on a sheet.")],
		EventSheetPopupUI.ViewSwitch.CODE: [EventSheetL10n.translate("Code"), EventSheetL10n.translate("Each use as the GDScript it compiles to.")],
		EventSheetPopupUI.ViewSwitch.BOTH: [EventSheetL10n.translate("Both"), EventSheetL10n.translate("The rows and the code together.")],
	})
	switch.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	switch.view_chosen.connect(_show_settings_view)
	head.add_child(switch)
	var column: VBoxContainer = EventSheetPopupUI.form_box()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(head)
	var files: HBoxContainer = HBoxContainer.new()
	column.add_child(files)
	box.add_child(_scrolled(column))
	# The cards read the Game Settings pack's own rows, which means reflecting the pack: done the
	# first time the tab is shown rather than every time the window opens.
	box.visibility_changed.connect(func() -> void:
		if not box.is_visible_in_tree() or files.get_child_count() > 0:
			return
		for card: Array in settings_files():
			files.add_child(_file_card(card))
		for use: Array in settings_uses():
			column.add_child(_use_card(use))
		_show_settings_view(switch.view))
	return box


## The three files a game keeps for its player: [title, file, what, sample, written by, read by,
## what a new game does to it]. Each file and its sample are the ones the shipping code writes: the
## Save System's default slot in its default format, and the two ConfigFiles as Godot encodes them.
static func settings_files() -> Array:
	var slot: Dictionary = read_settings("")
	var settings_pack: Dictionary = (load(GAME_SETTINGS_SCRIPT) as Script).get_script_constant_map() if ResourceLoader.exists(GAME_SETTINGS_SCRIPT) else {}
	var settings: ConfigFile = ConfigFile.new()
	for setting: Array in [["master_volume", 80], ["fullscreen", true], ["quality", "High"]]:
		settings.set_value(str(settings_pack.get("SETTINGS_SECTION", "settings")), setting[0], setting[1])
	var space: InputEventKey = InputEventKey.new()
	space.keycode = KEY_SPACE
	var bindings: ConfigFile = ConfigFile.new()
	bindings.set_value("bindings", "jump", [space])
	return [
		[EventSheetL10n.translate("Save slots"), str(slot["save_directory"]).path_join(str(slot["file_pattern"]).replace("{slot}", "0")),
			EventSheetL10n.translate("The game itself: where the player is, what they carry. One file per slot."),
			EventSheets.preview_save({"health": 3, "coins": 42}, str(slot["format"]), "player").strip_edges(),
			EventSheetL10n.translate("Save Game, Save Value"), EventSheetL10n.translate("Load Game"), EventSheetL10n.translate("Starts empty (a new slot)")],
		[EventSheetL10n.translate("Options and graphics"), str(settings_pack.get("SETTINGS_FILE", "")),
			EventSheetL10n.translate("Every declared setting: volume, subtitles, fullscreen, quality. One file for the whole game."),
			settings.encode_to_text().strip_edges(), EventSheetL10n.translate("Save All Settings, Save Setting"),
			EventSheetL10n.translate("Load All Settings"), EventSheetL10n.translate("Kept as it is")],
		[EventSheetL10n.translate("Key bindings"), str((load(BINDINGS_MODULE) as Script).get_script_constant_map().get("BINDINGS_FILE", "")).trim_prefix("\"").trim_suffix("\""),
			EventSheetL10n.translate("Which key or button does each action in the Input Map. One file for the whole game."),
			# A key is stored as its whole object, every field spelled out; its class says enough here.
			bindings.encode_to_text().get_slice(",", 0) + ", …)]", EventSheetL10n.translate("Save Bindings"),
			EventSheetL10n.translate("Load Bindings"), EventSheetL10n.translate("Kept as it is")],
	]


## The settings uses, each as [title, why, conditions, actions, code]; a condition or action is
## [object, the words the sheet reads]. A Game Settings row is written [its name, {param: value}] and
## read off the pack's own definition - its reading and its codegen template - so the card is the row
## a reader gets from Add Action. A built-in row is [object, words, its line of code]. The code is the
## trigger's function line, the conditions as one `if`, then the actions.
static func settings_uses() -> Array:
	var rows: Array = EventSheetPackReadingCheck.definitions_for_script(GAME_SETTINGS_SCRIPT)
	var uses: Array = []
	for use: Array in [
		[EventSheetL10n.translate("Name each setting once, then load them"),
			EventSheetL10n.translate("At start: declare each setting with its default, read the saved values, apply them, and put the saved keys back."),
			"func _ready() -> void:", [["System", EventSheetL10n.translate("On created"), ""]],
			[["Declare Setting", {"setting_name": "\"master_volume\"", "default_value": "80"}],
				["Declare Setting", {"setting_name": "\"fullscreen\"", "default_value": "false", "kind": "toggle"}],
				["Load All Settings", {}], ["Apply All Settings", {}],
				["Input", EventSheetL10n.translate("Load bindings from \"user://bindings.cfg\""), "# Load Bindings: the Input Map gets the saved keys back from user://bindings.cfg"]]],
		[EventSheetL10n.translate("Do what a setting means"),
			EventSheetL10n.translate("One reaction per setting. Start-up and the options screen both arrive here, so they never disagree."),
			"func _on_setting_changed(setting_name: String, value: Variant) -> void:",
			[["On Setting Changed", {}], ["Changed Setting Is", {"setting_name": "\"master_volume\""}]],
			[["Audio", EventSheetL10n.translate("Set bus \"Master\" volume to Setting Value(\"master_volume\") %"), "AudioServer.set_bus_volume_db(0, linear_to_db(value / 100.0))"]]],
		[EventSheetL10n.translate("A slider on the options screen"),
			EventSheetL10n.translate("Dragging it changes the setting; the reaction above does the rest."),
			"func _on_volume_slider_value_changed(value: float) -> void:", [["VolumeSlider", EventSheetL10n.translate("On value changed"), ""]],
			[["Set Setting", {"setting_name": "\"master_volume\"", "value": "value"}]]],
		[EventSheetL10n.translate("Keep them when the menu closes"),
			EventSheetL10n.translate("Writes settings.cfg. Save slots are not touched."),
			"func _on_back_button_pressed() -> void:", [["BackButton", EventSheetL10n.translate("On pressed"), ""]],
			[["Save All Settings", {}], ["Options", EventSheetL10n.translate("Hide"), "$Options.hide()"]]],
		[EventSheetL10n.translate("Let players rebind a key"),
			EventSheetL10n.translate("The button sets waiting_for to \"jump\"; the next key pressed becomes the new jump key and is saved."),
			"func _unhandled_input(event: InputEvent) -> void:",
			[["Input", EventSheetL10n.translate("On any key pressed"), ""],
				["System", "waiting_for != \"\"", "waiting_for != \"\" and event is InputEventKey and event.pressed"]],
			[["Input", EventSheetL10n.translate("Rebind Control To waiting_for, the key pressed"), "InputMap.action_erase_events(waiting_for)\nInputMap.action_add_event(waiting_for, event)"],
				["Input", EventSheetL10n.translate("Save bindings to \"user://bindings.cfg\""), "# Save Bindings writes user://bindings.cfg"],
				["System", EventSheetL10n.translate("Set waiting_for to \"\""), "waiting_for = \"\""]]],
		[EventSheetL10n.translate("Graphics with a way back"),
			EventSheetL10n.translate("Apply a quality preset with a 10 second countdown; if the screen goes wrong, it goes back by itself."),
			"func _on_apply_button_pressed() -> void:", [["ApplyButton", EventSheetL10n.translate("On pressed"), ""]],
			[["Apply Quality", {"preset": "\"High\""}], ["Apply With A Way Back", {"seconds": "10.0"}]]],
	]:
		var halves: Array = [[], []]
		var tests: Array = []
		var body: Array = []
		for half: int in range(2):
			for line: Array in use[3 + half]:
				var row: Array = line if line.size() == 3 else _pack_row(rows, str(line[0]), line[1])
				halves[half].append([row[0], row[1]])
				if not str(row[2]).is_empty():
					(tests if half == 0 else body).append(str(row[2]))
		var code: String = str(use[2])
		var indent: String = "\n\t"
		if not tests.is_empty():
			code += "%sif %s:" % [indent, " and ".join(PackedStringArray(tests))]
			indent += "\t"
		for line: String in body:
			code += indent + line.replace("\n", indent)
		uses.append([use[0], use[1], halves[0], halves[1], code])
	return uses


## One Game Settings row as [object, the words the sheet reads, its line of code], read off the pack
## definition named `ace_name` with `values` in its parameters (a parameter left out keeps its default).
static func _pack_row(definitions: Array, ace_name: String, values: Dictionary) -> Array:
	for definition: ACEDefinition in definitions:
		if definition.display_name != ace_name:
			continue
		var words: String = EventSheetL10n.translate(str(definition.metadata.get("display_template", ace_name)))
		var code: String = str(definition.metadata.get("codegen_template", ""))
		for parameter: Dictionary in definition.parameters:
			var slot: String = "{%s}" % parameter.get("id", "")
			var value: String = str(values.get(parameter.get("id", ""), parameter.get("default_value", parameter.get("default", ""))))
			words = words.replace(slot, value)
			code = code.replace(slot, value)
		return ["Settings", words.replace("[b]", "").replace("[/b]", ""), code]
	return ["Settings", ace_name, ""]


func _file_card(card: Array) -> Control:
	var box: VBoxContainer = EventSheetPopupUI.form_box()
	var head: HBoxContainer = HBoxContainer.new()
	var title: Label = _label(str(card[0]))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(EventSheetPopupUI.metadata_badge(str(card[1])))
	box.add_child(head)
	box.add_child(_muted(str(card[2]), EventSheetPalette.scaled_f(150.0)))
	box.add_child(EventSheetPopupUI.code_card(str(card[3]), EventSheetPalette.scaled_f(150.0)))
	var facts: GridContainer = GridContainer.new()
	facts.columns = 2
	var names: Array = [EventSheetL10n.translate("Written by"), EventSheetL10n.translate("Read by"), EventSheetL10n.translate("New game")]
	for index: int in range(3):
		facts.add_child(_label(str(names[index]), EventSheetPopupUI.muted_text_color()))
		var fact: Label = _muted(str(card[4 + index]), EventSheetPalette.scaled_f(80.0))
		fact.add_theme_color_override("font_color", EventSheetPopupUI.text_color())
		fact.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		facts.add_child(fact)
	box.add_child(facts)
	return _card(box)


func _use_card(use: Array) -> Control:
	var box: VBoxContainer = EventSheetPopupUI.form_box()
	box.add_child(_label(str(use[0])))
	box.add_child(_muted(str(use[1]), EventSheetPalette.scaled_f(560.0)))
	var events: HBoxContainer = HBoxContainer.new()
	for half: Array in [use[2], use[3]]:
		var lines: VBoxContainer = VBoxContainer.new()
		for line: Array in half:
			# One condition or action as the sheet reads it: the object in the quiet object column, then its words.
			var row: HBoxContainer = HBoxContainer.new()
			var object_label: Label = _label(str(line[0]), EventSheetPopupUI.secondary_text_color())
			object_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			row.add_child(object_label)
			var said: Label = _label(str(line[1]), EventSheetPopupUI.text_color())
			said.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			said.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			said.custom_minimum_size = Vector2(EventSheetPalette.scaled_f(160.0), 0.0)
			row.add_child(said)
			lines.add_child(row)
		events.add_child(_card(lines))
	box.add_child(events)
	# A Label draws no tab stops, so the code's indentation is spelled in spaces.
	var code: PanelContainer = EventSheetPopupUI.code_card(str(use[4]).replace("\t", "    "), EventSheetPalette.scaled_f(560.0))
	box.add_child(code)
	_settings_views.append([events, code])
	return _card(box)


func _show_settings_view(view: String) -> void:
	for pair: Array in _settings_views:
		(pair[0] as Control).visible = view != EventSheetPopupUI.ViewSwitch.CODE
		(pair[1] as Control).visible = view != EventSheetPopupUI.ViewSwitch.SHEET


# ── What gets saved: one Save choice per variable ───────────────────────────────────


## The name a Save choice shows in its dropdown and in the legend.
static func save_choice_name(choice: String) -> String:
	return _choice_words(choice)[0]


## What a Save choice does, in one sentence - the line its option shows on hover and the legend repeats.
static func save_choice_description(choice: String) -> String:
	return _choice_words(choice)[1]


## What a Save choice is usually for - the second line of its option's hover.
static func save_choice_use(choice: String) -> String:
	return _choice_words(choice)[2]


## A Save choice's [name, what it does, what it is for]. Each sentence is written out inside its
## translate() call so the translation harvest finds it.
static func _choice_words(choice: String) -> Array:
	match choice:
		"auto":
			return [EventSheetL10n.translate("Auto"), EventSheetL10n.translate("Loaded when the object enters the game, saved when it leaves (and when the game quits). The easy default."),
				EventSheetL10n.translate("Use for: health, coins, unlocked doors.")]
		"load":
			return [EventSheetL10n.translate("Load only"), EventSheetL10n.translate("Loaded automatically, but only saved when your events say Save Game."),
				EventSheetL10n.translate("Use for: settings you write yourself at a menu.")]
		"save":
			return [EventSheetL10n.translate("Save only"), EventSheetL10n.translate("Saved automatically, never loaded back: good for stats or play time."),
				EventSheetL10n.translate("Use for: play time, total jumps, stats you read elsewhere.")]
		"manual":
			return [EventSheetL10n.translate("Manually"), EventSheetL10n.translate("Only when your events say Save Game / Load Game: checkpoints and save slots."),
				EventSheetL10n.translate("Use for: checkpoint position, save-slot games.")]
	return [EventSheetL10n.translate("Never"), EventSheetL10n.translate("Not saved. It starts from its default every time."),
		EventSheetL10n.translate("Use for: timers, cooldowns, anything worked out again each run.")]


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
	_what_summary = _label("", EventSheetPopupUI.text_color())
	_what_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_what_summary)
	var legend: Array = []
	for choice: String in SAVE_CHOICE_ORDER:
		legend.append(PackedStringArray([save_choice_name(choice), save_choice_description(choice)]))
	box.add_child(EventSheetPopupUI.compact_table(PackedStringArray([EventSheetL10n.translate("Save"),
		EventSheetL10n.translate("What it does")]), legend, 1))
	_where_kept = VBoxContainer.new()
	box.add_child(EventSheetPopupUI.titled_card(EventSheetL10n.translate("Where it is kept"), _where_kept))
	var scroll: ScrollContainer = _scrolled(box)
	scroll.set_meta("title", EventSheetL10n.translate("What gets saved"))
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
			var label: Label = _label(str(cell[0]), EventSheetPopupUI.muted_text_color() if cell[2] else EventSheetPopupUI.text_color())
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
	var slot_file: String = _save_directory().path_join(_pattern().replace("{slot}", "0"))
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
