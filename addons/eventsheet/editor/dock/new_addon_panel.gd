@tool
class_name EventSheetNewAddonPanel
extends RefCounted

# Sheet > New behaviour… and Sheet > New global…: one form, asked the familiar way.
#
# A behaviour is asked its name, the kind of object it works on, the shelf it sits on in the Add
# behaviour list, its icon (the Works-on class's own icon unless another is chosen), a description and
# what to start from. A global is asked its name, whether Godot loads a script or a whole scene, the
# heading its verbs sit under in the picker, its icon, a description and what to start from - the only
# real choice Godot asks of an autoload is script or scene, so that is the only one here.
#
# Every choice is a described dropdown with the chosen choice's sentence kept in view under it. Create
# writes the file (a behaviour is a folder under eventsheet_addons/, so is a global - that folder is
# how the plugin reads what it offers), turns a global on in Project Settings > Globals > Autoload as
# one undo step, and opens the result as a sheet with its Properties and actions window beside it.
# The file text comes from EventSheetBehaviourAddonScaffold; this file only asks and writes.

const Scaffold := preload("res://addons/eventsheet/editor/behaviour_addon_scaffold.gd")
const MEMBERS_WINDOW_PATH := "res://addons/eventsheet/editor/dock/own_members_window.gd"
const START_EMPTY := "empty"
const START_COPY := "copy"
const START_SCRIPT := "script"
const START_NODE := "node"
const START_AUTOLOAD := "autoload"

var _dock: Control = null
var _dialog: ConfirmationDialog = null
var _members: AcceptDialog = null
var _global: bool = false
var _name_edit: LineEdit = null
var _name_note: EventSheetPopupUI.StateNote = null
var _kind_option: OptionButton = null
var _shelf_option: OptionButton = null
var _start_option: OptionButton = null
var _icon_rect: TextureRect = null
var _icon_label: Label = null
var _icon_path: String = ""
var _desc_edit: LineEdit = null
var _script_edit: LineEdit = null
var _autoload_option: OptionButton = null
var _path_label: Label = null
var _rows: Dictionary = {}


## Wires the dock reference used to parent the windows and to open what Create made.
func init(dock: Control) -> void:
	_dock = dock


## Opens the form fresh, for a behaviour or (`as_global`) a global. Built on first use and rebuilt
## when the other kind is asked for, because the two ask different questions in the same places.
func open(as_global: bool = false) -> void:
	if _dialog != null and _global != as_global:
		_dialog.queue_free()
		_dialog = null
	_global = as_global
	_build_dialog()
	_name_edit.text = ""
	_desc_edit.text = ""
	_script_edit.text = ""
	_icon_path = ""
	_fill_starts()
	_refresh()
	if _dialog.is_inside_tree():  # headless tests: the fields are reset, there is no window to pop
		_dialog.popup_centered(Vector2i(int(EventSheetPalette.scaled_f(620.0)), 0))
		_name_edit.grab_focus()


## The Properties and actions window for the open sheet - the behaviour's or global's own lists.
func open_members() -> void:
	if _members == null:
		_members = load(MEMBERS_WINDOW_PATH).new(_dock)
		_dock.add_child(_members)
	_members.open()


func _build_dialog() -> void:
	_dialog = ConfirmationDialog.new()
	_dialog.title = EventSheetL10n.translate("New global") if _global else EventSheetL10n.translate("New behaviour")
	_dialog.ok_button_text = EventSheetL10n.translate("Create")
	_dialog.dialog_hide_on_ok = false
	_dialog.confirmed.connect(_on_create)
	_dock.add_child(_dialog)
	var form: VBoxContainer = EventSheetPopupUI.form_box()
	form.custom_minimum_size = Vector2(EventSheetPalette.scaled_f(560.0), 0.0)
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "GameState" if _global else "Patrol"
	_name_edit.text_changed.connect(func(_text: String) -> void: _refresh())
	_name_edit.text_submitted.connect(func(_text: String) -> void: _on_create())
	form.add_child(EventSheetPopupUI.form_row(EventSheetL10n.translate("Name"), _name_edit))
	_name_note = EventSheetPopupUI.StateNote.new()
	form.add_child(_name_note)
	_kind_option = EventSheetPopupUI.described_option()
	if _global:
		EventSheetPopupUI.add_described_item(_kind_option, EventSheetL10n.translate("Script"), EventSheetL10n.translate(
			"Just code and values: score, lives, messages between scenes, saving. The usual choice - Godot adds it as a plain Node."), "Node")
		EventSheetPopupUI.add_described_item(_kind_option, EventSheetL10n.translate("Scene"), EventSheetL10n.translate(
			"Needs nodes of its own: music players, a fade overlay, a pause menu or a HUD that stays while levels change. Godot loads the whole scene."), "PackedScene")
	else:
		for host: Array in _works_on():
			EventSheetPopupUI.add_described_item(_kind_option, str(host[1]), str(host[2]), str(host[0]))
		_kind_option.select(2)
	_kind_option.item_selected.connect(func(_index: int) -> void:
		_fill_starts()
		_refresh())
	form.add_child(_described_row(EventSheetL10n.translate("Made as") if _global else EventSheetL10n.translate("Works on"), _kind_option))
	_shelf_option = EventSheetPopupUI.described_option()
	_fill_shelves()
	form.add_child(_described_row(EventSheetL10n.translate("Picker heading") if _global else EventSheetL10n.translate("Category"), _shelf_option))
	form.add_child(EventSheetPopupUI.form_row(EventSheetL10n.translate("Icon"), _build_icon_row()))
	_desc_edit = LineEdit.new()
	_desc_edit.placeholder_text = EventSheetL10n.translate("What it does, in one line.")
	form.add_child(EventSheetPopupUI.form_row(EventSheetL10n.translate("Description"), _desc_edit))
	_start_option = EventSheetPopupUI.described_option()
	_start_option.item_selected.connect(func(_index: int) -> void: _refresh())
	form.add_child(_described_row(EventSheetL10n.translate("Start from"), _start_option))
	var script_row: HBoxContainer = HBoxContainer.new()
	_script_edit = LineEdit.new()
	_script_edit.placeholder_text = "res://player.gd"
	_script_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_script_edit.text_changed.connect(func(_text: String) -> void: _refresh())
	script_row.add_child(_script_edit)
	script_row.add_child(_browse_button(["*.gd"], func(path: String) -> void:
		_script_edit.text = path
		_refresh()))
	_rows[START_SCRIPT] = EventSheetPopupUI.form_row(EventSheetL10n.translate("Script"), script_row)
	form.add_child(_rows[START_SCRIPT])
	_autoload_option = OptionButton.new()
	_autoload_option.item_selected.connect(func(_index: int) -> void: _refresh())
	_rows[START_AUTOLOAD] = EventSheetPopupUI.form_row(EventSheetL10n.translate("Autoload"), _autoload_option)
	form.add_child(_rows[START_AUTOLOAD])
	_path_label = EventSheetPopupUI.hint_label("")
	form.add_child(_path_label)
	_dialog.add_child(form)


## A described dropdown with its chosen choice's sentence kept in view under it.
func _described_row(label_text: String, dropdown: OptionButton) -> Control:
	var box: VBoxContainer = VBoxContainer.new()
	dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(dropdown)
	var note: Label = EventSheetPopupUI.hint_label("")
	box.add_child(note)
	var follow: Callable = func(_index: int = 0) -> void:
		note.text = dropdown.get_item_tooltip(dropdown.selected) if dropdown.selected >= 0 else ""
	dropdown.item_selected.connect(follow)
	dropdown.set_meta("chosen_note", note)
	follow.call()
	return EventSheetPopupUI.form_row(label_text, box)


## The kinds of object a behaviour can work on: [class, label, what it means].
static func _works_on() -> Array:
	return [
		["Node", EventSheetL10n.translate("Any node"), EventSheetL10n.translate("Works on every object. It can only use what every node has: its name, groups, signals, timers.")],
		["Node2D", "Node2D", EventSheetL10n.translate("Any 2D object. It can move, turn and scale the object it is added to.")],
		["CharacterBody2D", "CharacterBody2D", EventSheetL10n.translate("A 2D character moved by code: it gets velocity and move_and_slide(), the usual choice for walking, patrolling, jumping.")],
		["RigidBody2D", "RigidBody2D", EventSheetL10n.translate("A 2D object moved by physics: it pushes with forces and impulses rather than setting positions.")],
		["Control", "Control", EventSheetL10n.translate("A piece of UI: buttons, labels, panels.")],
		["Node3D", "Node3D", EventSheetL10n.translate("Any 3D object.")],
		["CharacterBody3D", "CharacterBody3D", EventSheetL10n.translate("A 3D character moved by code.")],
	]


## A behaviour's shelves are the ones the installed packs already sit on, each described by the packs
## on it; a global's heading is its own name at the top of the picker or one of the familiar groups.
func _fill_shelves() -> void:
	_shelf_option.clear()
	if _global:
		EventSheetPopupUI.add_described_item(_shelf_option, EventSheetL10n.translate("Its own name"), EventSheetL10n.translate(
			"Listed under its own name at the top of every picker, like System. The usual choice."), "")
		EventSheetPopupUI.add_described_item(_shelf_option, "Audio", EventSheetL10n.translate("Listed with the sound and music actions."), "Audio")
		EventSheetPopupUI.add_described_item(_shelf_option, "Saving", EventSheetL10n.translate("Listed with the save and load actions."), "Saving")
		EventSheetPopupUI.add_described_item(_shelf_option, "UI", EventSheetL10n.translate("Listed with menus and screens."), "UI")
		return
	var packs: Array[Dictionary] = EventSheetPackCatalog.packs()
	for shelf: String in EventSheetPackCatalog.categories(packs):
		var names: PackedStringArray = PackedStringArray()
		for pack: Dictionary in EventSheetPackCatalog.filtered(packs, shelf, ""):
			if names.size() < 3:
				names.append(str(pack.get("name", "")))
		var index: int = EventSheetPopupUI.add_described_item(_shelf_option, shelf,
			EventSheetL10n.translate("Listed with %s.") % ", ".join(names), shelf)
		if shelf == "General":
			_shelf_option.select(index)
	EventSheetPopupUI.follow_description(_shelf_option)


## What a new one can start from. Copies are of the installed packs made for the same kind of object
## (a behaviour) or meant to be an autoload (a global), so the list only offers what fits.
func _fill_starts() -> void:
	_start_option.clear()
	if _global:
		_start_item(EventSheetL10n.translate("Empty"), EventSheetL10n.translate("A global with no values or events yet. You add each one next."), START_EMPTY)
	else:
		_start_item(EventSheetL10n.translate("Empty"), EventSheetL10n.translate(
			"A behaviour with no properties or events yet. You add each one next. Pick this when nothing that ships is close to what you want."), START_EMPTY)
	var works_on: String = str(_kind_option.get_item_metadata(_kind_option.selected))
	for pack: Dictionary in EventSheetPackCatalog.packs():
		var source: String = FileAccess.get_file_as_string(str(pack.get("path", "")))
		var fits: bool = _is_global_shaped(source) if _global else Scaffold.host_class_of(source) == works_on
		if fits and not Scaffold.is_yours(source):
			# The shelf a new one is likely to share is the one the packs made for the same object sit on.
			if not _global and _start_option.item_count == 1 and not str(pack.get("category", "")).is_empty():
				EventSheetPopupUI.select_option(_shelf_option, str(pack.get("category", "")))
				_shelf_option.item_selected.emit(_shelf_option.selected)
			_start_item(EventSheetL10n.translate("Copy of %s") % str(pack.get("name", "")),
				EventSheetL10n.translate("%s Your copy gets its own name and folder; the shipped one stays as it is.") % str(pack.get("pitch", "")),
				START_COPY, str(pack.get("path", "")))
	if _global:
		_start_item(EventSheetL10n.translate("From a script I wrote"), EventSheetL10n.translate(
			"Its variables become this global's values. The script itself is not changed."), START_SCRIPT)
		_start_item(EventSheetL10n.translate("From an autoload I already have"), EventSheetL10n.translate(
			"Opens a global your project already lists in Project Settings > Globals as a sheet. Nothing is moved or renamed."), START_AUTOLOAD)
		_autoload_option.clear()
		for entry: Dictionary in EventSheetProjectScanner.list_autoloads():
			_autoload_option.add_item(str(entry.get("autoload", "")))
			_autoload_option.set_item_metadata(_autoload_option.item_count - 1, str(entry.get("path", "")))
	else:
		_start_item(EventSheetL10n.translate("From a script I wrote"), EventSheetL10n.translate(
			"Its exported variables become this behaviour's properties. The script itself is not changed."), START_SCRIPT)
		_start_item(EventSheetL10n.translate("From the selected node"), EventSheetL10n.translate(
			"Uses the script on the node selected in the Scene dock, the same way as From a script I wrote."), START_NODE)
	_start_option.select(0)
	(_start_option.get_meta("chosen_note") as Label).text = _start_option.get_item_tooltip(0)


func _start_item(label_text: String, description: String, kind: String, path: String = "") -> void:
	EventSheetPopupUI.add_described_item(_start_option, label_text, description, {"kind": kind, "path": path})


## A pack meant to run as an autoload says so in its own class description.
static func _is_global_shaped(source: String) -> bool:
	var after_extends: PackedStringArray = PackedStringArray()
	var reading: bool = false
	for line: String in source.split("\n"):
		if line.begins_with("extends "):
			reading = true
		elif reading and line.begins_with("##"):
			after_extends.append(line)
		elif reading:
			break
	return " ".join(after_extends).to_lower().contains("autoload")


func _build_icon_row() -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", int(EventSheetPalette.scaled_f(8.0)))
	_icon_rect = TextureRect.new()
	_icon_rect.custom_minimum_size = Vector2.ONE * EventSheetPalette.scaled_f(20.0)
	_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(_icon_rect)
	_icon_label = Label.new()
	_icon_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_icon_label.add_theme_color_override("font_color", EventSheetPopupUI.text_color())
	row.add_child(_icon_label)
	row.add_child(_browse_button(["*.svg", "*.png"], func(path: String) -> void:
		_icon_path = path
		_refresh(), EventSheetL10n.translate("Choose another…")))
	return row


## A button opening the editor's own file picker on `filters`. Editor-only by construction: a
## headless run types the path instead.
func _browse_button(filters: PackedStringArray, picked: Callable, text: String = "…") -> Button:
	var button: Button = Button.new()
	button.text = text
	button.pressed.connect(func() -> void:
		if not Engine.is_editor_hint():
			return
		var browser: EditorFileDialog = EditorFileDialog.new()
		browser.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
		browser.access = EditorFileDialog.ACCESS_RESOURCES
		browser.filters = filters
		browser.file_selected.connect(func(path: String) -> void:
			picked.call(path)
			browser.queue_free())
		browser.canceled.connect(browser.queue_free)
		_dialog.add_child(browser)
		browser.popup_centered_ratio(0.6))
	return button


## The chosen start, as {"kind", "path"}.
func _start() -> Dictionary:
	return _start_option.get_item_metadata(_start_option.selected) if _start_option.selected >= 0 else {"kind": START_EMPTY}


## The icon class the Works-on (or Made-as) choice stands for.
func _icon_class() -> String:
	return "Node" if _global else str(_kind_option.get_item_metadata(_kind_option.selected))


func _refresh() -> void:
	var start: Dictionary = _start()
	var kind: String = str(start.get("kind", START_EMPTY))
	(_rows[START_SCRIPT] as Control).visible = kind == START_SCRIPT
	(_rows[START_AUTOLOAD] as Control).visible = kind == START_AUTOLOAD
	_name_edit.editable = kind != START_AUTOLOAD
	if _icon_path.is_empty():
		_icon_rect.texture = EventSheetPopupUI._editor_icon(_icon_class())
		_icon_label.text = EventSheetL10n.translate("Default: the %s icon, following Works on") % _icon_class() \
			if not _global else EventSheetL10n.translate("Default: the %s icon") % _icon_class()
	else:
		_icon_rect.texture = load(_icon_path) as Texture2D if ResourceLoader.exists(_icon_path) else null
		_icon_label.text = _icon_path
	var addon_name: String = _name_edit.text.strip_edges()
	if kind == START_AUTOLOAD:
		_path_label.text = EventSheetL10n.translate("Opens %s as a sheet.") % _autoload_path()
		_name_note.say("")
		return
	var path: String = Scaffold.script_path_for(addon_name if not addon_name.is_empty() else _name_edit.placeholder_text)
	_path_label.text = (EventSheetL10n.translate("Makes %s, turns it on in Project Settings > Globals > Autoload and opens it as a sheet.") \
		if _global else EventSheetL10n.translate("Makes %s and opens it as a sheet.")) % path
	_name_note.say("" if addon_name.is_empty() else name_problem(addon_name, _global))


func _autoload_path() -> String:
	return str(_autoload_option.get_item_metadata(_autoload_option.selected)) if _autoload_option.selected >= 0 else ""


## Why `addon_name` cannot be made, or "" when it can: not a usable name (or, for a global, the name
## of an autoload already), or a folder of that name already there.
static func name_problem(addon_name: String, as_global: bool = false) -> String:
	if not Scaffold.is_valid_class_name(addon_name):
		return EventSheetL10n.translate("\"%s\" can't be a name here - use letters, digits and underscores, starting with a letter, and not the name of a class that already exists.") % addon_name
	if as_global and ProjectSettings.has_setting("autoload/" + addon_name.strip_edges()):
		return EventSheetL10n.translate("Project Settings > Globals already has an autoload called %s - pick another name.") % addon_name.strip_edges()
	var folder: String = Scaffold.script_path_for(addon_name).get_base_dir()
	if DirAccess.dir_exists_absolute(folder):
		return EventSheetL10n.translate("%s already exists - pick another name.") % folder
	return ""


## The script a "From a script I wrote" or "From the selected node" start reads, or "" with a reason.
func _source_script() -> String:
	if str(_start().get("kind")) == START_SCRIPT:
		return _script_edit.text.strip_edges()
	if not Engine.is_editor_hint():
		return ""
	var selected: Array[Node] = EditorInterface.get_selection().get_selected_nodes()
	var script: Script = selected[0].get_script() as Script if not selected.is_empty() else null
	return script.resource_path if script != null else ""


func _on_create() -> void:
	var start: Dictionary = _start()
	var kind: String = str(start.get("kind", START_EMPTY))
	if kind == START_AUTOLOAD:
		if not _autoload_path().is_empty():
			_dialog.hide()
			_open_made(_autoload_path(), EventSheetL10n.translate("Opened the global %s as a sheet - nothing was moved or renamed.") % _autoload_option.get_item_text(_autoload_option.selected))
		return
	var addon_name: String = _name_edit.text.strip_edges()
	var problem: String = name_problem(addon_name, _global)
	var source_script: String = _source_script() if kind in [START_SCRIPT, START_NODE] else ""
	if problem.is_empty() and kind in [START_SCRIPT, START_NODE] and not FileAccess.file_exists(source_script):
		problem = EventSheetL10n.translate("Choose the script to start from.") if kind == START_SCRIPT \
			else EventSheetL10n.translate("Select a node that has a script in the Scene dock first.")
	if not problem.is_empty():
		_name_note.say(problem)
		return
	var path: String = Scaffold.script_path_for(addon_name)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var shelf: String = str(_shelf_option.get_item_metadata(_shelf_option.selected))
	var source: String = _source_for(kind, addon_name, shelf, str(start.get("path", "")), source_script, path)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_name_note.say(EventSheetL10n.translate("Couldn't write %s - check folder permissions.") % path)
		return
	file.store_string(source)
	file.close()
	_dialog.hide()
	if not _global:
		_open_made(path, EventSheetL10n.translate("Made the behaviour %s at %s. Add it to an object from the Add behaviour list.") % [addon_name, path])
		return
	var target: String = path
	if _kind_option.selected == 1:
		target = Scaffold.scene_path_for(addon_name)
		ResourceSaver.save(Scaffold.global_scene(addon_name, ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)), target)
	set_global_on(addon_name, target, true)
	_open_made(path, EventSheetL10n.translate("Made the global %s and turned it on in Project Settings > Globals > Autoload. Ctrl+Z turns it off again; the file stays.") % addon_name)


## The text of the new file. A global's picker heading and chosen icon are header lines, because a
## global has no class_name for the sheet to hang them on.
func _source_for(kind: String, addon_name: String, shelf: String, pack_path: String, source_script: String,
		path: String) -> String:
	var description: String = _desc_edit.text
	if kind == START_COPY:
		return Scaffold.copied_source(FileAccess.get_file_as_string(pack_path), addon_name,
			"" if _global else shelf, description, not _global)
	var sheet: EventSheetResource = Scaffold.global_sheet(description) if _global else Scaffold.behaviour_sheet(
		addon_name, _icon_class(), shelf, description, _icon_path if not _icon_path.is_empty() else _write_default_icon(path))
	if not source_script.is_empty():
		Scaffold.with_variables(sheet, Scaffold.carried_variables(source_script, not _global))
	var source: String = Scaffold.source_of(sheet)
	if _global and not _icon_path.is_empty():
		source = "@icon(\"%s\")\n%s" % [_icon_path, source]
	if _global and not shelf.is_empty():
		source = "## @ace_category(\"%s\")\n%s" % [shelf, source]
	return source


## The Works-on class's own editor icon saved beside the behaviour, so it shows as that kind of object
## in the Scene dock and the Add behaviour list. "" outside the editor, where there is no theme to ask.
func _write_default_icon(script_path: String) -> String:
	var icon: Texture2D = EventSheetPopupUI._editor_icon(_icon_class())
	var image: Image = icon.get_image() if icon != null else null
	var icon_path: String = script_path.get_base_dir().path_join("icon.png")
	return icon_path if image != null and image.save_png(icon_path) == OK else ""


func _open_made(path: String, message: String) -> void:
	if Engine.is_editor_hint():
		EditorInterface.get_resource_filesystem().scan()
	_dock._refresh_ace_registry()
	_dock._navigate.record_current()
	_dock._navigate.open_or_focus(path)
	open_members()
	_dock._set_status(message)


## Turns a global on or off in Godot's own list, Project Settings > Globals > Autoload, as one undo
## step in the editor. `target` is the script or scene Godot loads; the "*" makes its name global.
static func set_global_on(global_name: String, target: String, on: bool) -> void:
	var key: String = "autoload/" + global_name
	var before: Variant = ProjectSettings.get_setting(key) if ProjectSettings.has_setting(key) else null
	var after: Variant = ("*" + target) if on else null
	if Engine.is_editor_hint():
		var undo: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
		undo.create_action(EventSheetL10n.translate("Turn on global %s") % global_name if on
			else EventSheetL10n.translate("Turn off global %s") % global_name)
		undo.add_do_method(ProjectSettings, "set_setting", key, after)
		undo.add_do_method(ProjectSettings, "save")
		undo.add_undo_method(ProjectSettings, "set_setting", key, before)
		undo.add_undo_method(ProjectSettings, "save")
		undo.commit_action()
	else:
		ProjectSettings.set_setting(key, after)
	EventSheetSentence.clear_autoload_cache()
