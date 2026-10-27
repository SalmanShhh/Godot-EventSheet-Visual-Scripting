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
#
# Behaviour settings… / Global settings… reopen the same form on a file that exists, every answer
# read from the file's own header (`## @ace_category`, `@icon`, the `##` description line, the type
# of its `host`; a global's name and script-or-scene from its Autoload row), so a file written by
# hand opens the same way. Save changes writes only what changed, through the sheet as one undo step,
# and a new name goes through the one rename everywhere, which lists the places before it writes.

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
## The answers the form was reopened with on an existing file, or {} while it makes a new one: what
## Save changes compares against, so only what changed is written.
var _editing: Dictionary = {}
## The object a behaviour made from its Behaviours list is added to, as {"label", "class"}, or {}.
var _for_object: Dictionary = {}


## Wires the dock reference used to parent the windows and to open what Create made.
func init(dock: Control) -> void:
	_dock = dock


## Opens the form fresh, for a behaviour or (`as_global`) a global. Built anew each time, because the
## two kinds ask different questions in the same places and a reopened file adds its own answers to
## the lists. `for_object` ({"label", "class"}) is the object whose Behaviours list asked: Works on
## starts on its kind, and Create adds the new behaviour to it.
func open(as_global: bool = false, for_object: Dictionary = {}) -> void:
	_global = as_global
	_editing = {}
	_for_object = {} if as_global else for_object
	_icon_path = ""
	_build_dialog()
	if not str(_for_object.get("class", "")).is_empty():
		_choose(_kind_option, str(_for_object["class"]),
			EventSheetL10n.translate("The kind of object %s is.") % str(_for_object.get("label", "")))
	_fill_starts()
	_refresh()
	_popup()


## Behaviour settings… / Global settings…: the form reopened on the behaviour or global at `path`,
## with every answer filled in from the file. The file opens as a sheet first (or its tab is
## focused), because Save changes writes the answers through the sheet like any edit of its head.
func open_settings(path: String) -> void:
	if path.is_empty():
		return
	if _dock._current_sheet == null or _dock._current_sheet.external_source_path != path:
		_dock._navigate.record_current()
		_dock._navigate.open_or_focus(path)
	if _dock._current_sheet == null or _dock._current_sheet.external_source_path != path:
		return
	var answers: Dictionary = answers_of(Scaffold.source_of(_dock._current_sheet), path)
	_global = bool(answers["global"])
	_for_object = {}
	_editing = answers
	_build_dialog()
	_name_edit.text = str(answers["name"])
	_choose(_kind_option, ("PackedScene" if bool(answers["scene"]) else "Node") if _global else str(answers["works_on"]),
		EventSheetL10n.translate("The kind of object it works on now."))
	_choose(_shelf_option, str(answers["category"]), EventSheetL10n.translate("Where it is listed now."))
	_icon_path = str(answers["icon"])
	_desc_edit.text = str(answers["description"])
	_refresh()
	_popup()


func _popup() -> void:
	if _dialog.is_inside_tree():  # headless tests: the fields are filled, there is no window to pop
		_dialog.popup_centered(Vector2i(int(EventSheetPalette.scaled_f(620.0)), 0))
		_name_edit.grab_focus()


## Selects the item of `dropdown` standing for `value`, adding it (described by `description`) when
## the list does not offer it - a hand-written file can work on, or be listed under, anything.
static func _choose(dropdown: OptionButton, value: String, description: String) -> void:
	var at: int = -1
	for index: int in range(dropdown.item_count):
		if str(dropdown.get_item_metadata(index)) == value:
			at = index
	if at < 0:
		at = EventSheetPopupUI.add_described_item(dropdown,
			value if not value.is_empty() else EventSheetL10n.translate("None"), description, value)
	dropdown.select(at)
	EventSheetPopupUI.follow_description(dropdown)


## The Properties and actions window for the open sheet - the behaviour's or global's own lists.
func open_members() -> void:
	if _members == null:
		_members = load(MEMBERS_WINDOW_PATH).new(_dock)
		_dock.add_child(_members)
	_members.open()


func _build_dialog() -> void:
	if _dialog != null:
		_dialog.queue_free()
	var title: String = EventSheetL10n.translate("New global") if _global else EventSheetL10n.translate("New behaviour")
	if not _editing.is_empty():
		title = (EventSheetL10n.translate("%s · Global settings") if _global
			else EventSheetL10n.translate("%s · Behaviour settings")) % str(_editing["name"])
	var parts: Dictionary = EventSheetPopupUI.panel_window(title, Vector2i.ZERO, _dock, EventSheetL10n.translate("Create")
		if _editing.is_empty() else EventSheetL10n.translate("Save changes"), _on_create)
	_dialog = parts["window"]
	var form: VBoxContainer = parts["box"]
	form.custom_minimum_size = Vector2(EventSheetPalette.scaled_f(560.0), 0.0)
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "GameState" if _global else "Patrol"
	_name_edit.text_changed.connect(func(_text: String) -> void: _refresh())
	_name_edit.text_submitted.connect(func(_text: String) -> void: _on_create())
	form.add_child(EventSheetPopupUI.form_row(EventSheetL10n.translate("Name"), _name_edit))
	_name_note = EventSheetPopupUI.StateNote.new()
	form.add_child(_name_note)
	if not _editing.is_empty():
		form.add_child(EventSheetPopupUI.hint_label(EventSheetL10n.translate(
			"Renaming changes its name in Project Settings > Globals and every use; the places are listed before anything is written. The file keeps its name.")
			if _global else EventSheetL10n.translate(
			"Renaming changes its class name and every use in one undo step; the places are listed before anything is written. The file keeps its name.")))
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
		if _editing.is_empty():
			_fill_starts()
		_refresh())
	form.add_child(EventSheetPopupUI.form_row(EventSheetL10n.translate("Made as") if _global else EventSheetL10n.translate("Works on"),
		EventSheetPopupUI.described_field(_kind_option)))
	_shelf_option = EventSheetPopupUI.described_option()
	_fill_shelves()
	form.add_child(EventSheetPopupUI.form_row(EventSheetL10n.translate("Picker heading") if _global
		else EventSheetL10n.translate("Category"), EventSheetPopupUI.described_field(_shelf_option)))
	form.add_child(EventSheetPopupUI.form_row(EventSheetL10n.translate("Icon"), _build_icon_row()))
	_desc_edit = LineEdit.new()
	_desc_edit.placeholder_text = EventSheetL10n.translate("What it does, in one line.")
	form.add_child(EventSheetPopupUI.form_row(EventSheetL10n.translate("Description"), _desc_edit))
	_start_option = EventSheetPopupUI.described_option()
	_start_option.item_selected.connect(func(_index: int) -> void: _refresh())
	if _editing.is_empty():
		form.add_child(EventSheetPopupUI.form_row(EventSheetL10n.translate("Start from"), EventSheetPopupUI.described_field(_start_option)))
	else:
		# How it began is not kept in the file, so the reopened form says so rather than guess.
		form.add_child(EventSheetPopupUI.form_row(EventSheetL10n.translate("Made from"), EventSheetPopupUI.hint_label(
			EventSheetL10n.translate("Not kept in the file - it is not linked to what it started from."))))
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
	# Its own name leads and is the one chosen: a project with no packs has no other shelf at all
	# (the list was empty, and Create wrote a heading read off no item), and with packs installed
	# every shelf is one pack's own name, so picking one for the reader filed a new Patrol with Car.
	EventSheetPopupUI.add_described_item(_shelf_option, EventSheetL10n.translate("Its own name"), EventSheetL10n.translate(
		"Listed under its own name in the picker and the Add behaviour list. The usual choice."), "")
	var packs: Array[Dictionary] = EventSheetPackCatalog.packs()
	for shelf: String in EventSheetPackCatalog.categories(packs):
		var names: PackedStringArray = PackedStringArray()
		for pack: Dictionary in EventSheetPackCatalog.filtered(packs, shelf, ""):
			if names.size() < 3:
				names.append(str(pack.get("name", "")))
		EventSheetPopupUI.add_described_item(_shelf_option, shelf,
			EventSheetL10n.translate("Listed with %s.") % ", ".join(names), shelf)
	_shelf_option.select(0)
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
	EventSheetPopupUI.follow_description(_start_option)


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


## A button opening the editor's own file picker on `filters`.
func _browse_button(filters: PackedStringArray, picked: Callable, text: String = "…") -> Button:
	var button: Button = Button.new()
	button.text = text
	button.pressed.connect(func() -> void: EventSheetPopupUI.browse_file(_dialog, filters, picked))
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
	if not _editing.is_empty():
		_path_label.text = (EventSheetL10n.translate("Saves into %s itself: its ## @ace_category line, @icon, the ## description line and its row in Project Settings > Globals > Autoload.")
			if _global else EventSheetL10n.translate("Saves into %s itself: its ## @ace_category line, @icon, the ## description line and the type of its host.")) % str(_editing["path"])
		_name_note.say(name_problem(addon_name, _global, str(_editing["name"])))
		return
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
## of an autoload already), or a folder of that name already there. Renaming one that exists
## (`current` is its name now) keeps its file and folder, so only the name itself is asked about.
static func name_problem(addon_name: String, as_global: bool = false, current: String = "") -> String:
	if not current.is_empty() and addon_name.strip_edges() == current:
		return ""
	if not Scaffold.is_valid_class_name(addon_name):
		return EventSheetL10n.translate("\"%s\" can't be a name here - use letters, digits and underscores, starting with a letter, and not the name of a class that already exists.") % addon_name
	if as_global and ProjectSettings.has_setting("autoload/" + addon_name.strip_edges()):
		return EventSheetL10n.translate("Project Settings > Globals already has an autoload called %s - pick another name.") % addon_name.strip_edges()
	if not current.is_empty():
		return ""
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
	if not _editing.is_empty():
		_save_settings()
		return
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
	if not _global and not _for_object.is_empty():
		# Added while the object's own sheet is still the open one: the dock finds its node through it.
		var object_label: String = str(_for_object.get("label", ""))
		_dock._add_made_behaviour(path, object_label)
		_open_made(path, EventSheetL10n.translate("Made the behaviour %s at %s and added it to %s.") % [addon_name, path, object_label])
		return
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
	set_global_row(global_name, target if on else "")


## Writes a global's row in Godot's own list as one undo step in the editor: `target` is the script or
## scene Godot loads ("" takes the row away), and a `new_name` renames the row where it stands, so the
## load order is kept. A row already there keeps whether its name is global (the "*").
static func set_global_row(global_name: String, target: String, new_name: String = "") -> void:
	var key: String = "autoload/" + global_name
	var new_key: String = "autoload/" + (new_name if not new_name.is_empty() else global_name)
	var before: Variant = ProjectSettings.get_setting(key) if ProjectSettings.has_setting(key) else null
	var order: int = ProjectSettings.get_order(key) if before != null else -1
	var star: String = "" if before != null and not str(before).begins_with("*") else "*"
	var after: Variant = (star + target) if not target.is_empty() else null
	var action: String = EventSheetL10n.translate("Turn off global %s") % global_name if after == null \
		else EventSheetL10n.translate("Turn on global %s") % global_name if before == null \
		else EventSheetL10n.translate("Change global %s") % global_name
	var undo: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo() if Engine.is_editor_hint() else null
	if undo == null:
		_write_global_row(null, key, new_key, after, order)
	else:
		undo.create_action(action)
		_write_global_row(undo, key, new_key, after, order)
		_write_global_row(undo, new_key, key, before, order, true)
		undo.commit_action()
	EventSheetSentence.clear_autoload_cache()


## One side of a global's row change, done now (no `undo`) or added to `undo` as its do side (or, with
## `as_undo`, its undo side): `key` is cleared when the row moves to `new_key`, which then holds `value`
## (null takes it away) at `order` in Godot's list (-1 leaves it where Godot puts it).
static func _write_global_row(undo: EditorUndoRedoManager, key: String, new_key: String, value: Variant,
		order: int, as_undo: bool = false) -> void:
	var calls: Array = []
	if key != new_key:
		calls.append(["set_setting", key, null])
	calls.append(["set_setting", new_key, value])
	if value != null and order >= 0:
		calls.append(["set_order", new_key, order])
	if undo != null:
		calls.append(["save"])
	for call: Array in calls:
		if undo == null:
			ProjectSettings.callv(str(call[0]), call.slice(1))
		elif as_undo:
			undo.add_undo_method.callv([ProjectSettings, call[0]] + call.slice(1))
		else:
			undo.add_do_method.callv([ProjectSettings, call[0]] + call.slice(1))


# ── Behaviour settings… / Global settings… ──────────────────────────────────────────────────────


## The answers a behaviour or global at `path` was made with, read from `source` (its text) the way
## the form asks them: {path, global, name, works_on, scene, category, icon, description}. Read from
## the header alone - `## @ace_category`, `@icon`, the `##` description line, `class_name` and the
## type of `host` - plus, for a global, its name and script-or-scene from its Autoload row, so a file
## written by hand answers the same way as one this form wrote.
static func answers_of(source: String, path: String) -> Dictionary:
	var global_name: String = EventSheetACEGenerator.autoload_name_for_path(path)
	var target: String = str(ProjectSettings.get_setting("autoload/" + global_name, "")).trim_prefix("*") \
		if not global_name.is_empty() else ""
	var works_on: String = Scaffold.host_class_of(source)
	var answers: Dictionary = {"path": path, "global": not global_name.is_empty(), "name": global_name,
		"works_on": works_on if not works_on.is_empty() else "Node", "scene": target.get_extension() == "tscn",
		"category": "", "icon": "", "description": ""}
	var past_extends: bool = false
	var read_below_extends: bool = false
	for raw_line: String in source.split("\n"):
		var line: String = raw_line.strip_edges()
		if line.begins_with("## ") and not line.begins_with("## @") and str(answers["description"]).is_empty():
			answers["description"] = line.trim_prefix("## ").strip_edges()
			read_below_extends = past_extends
		# Godot's own new-script template leaves a blank line under extends before the class doc
		# comment, and a script written by hand usually does too; the description is still the one
		# the file states, so those blank lines are stepped over until the doc block starts.
		if past_extends and line.is_empty() and str(answers["description"]).is_empty():
			continue
		if past_extends and not line.begins_with("##"):
			# A ## block under extends that runs straight into a member is that member's doc comment,
			# the way Godot reads it, so the behaviour has no description of its own.
			if read_below_extends and not line.is_empty() and not line.begins_with("#"):
				answers["description"] = ""
			break
		if line.begins_with("## @ace_category(") and str(answers["category"]).is_empty():
			answers["category"] = line.get_slice("\"", 1)
		elif line.begins_with("@icon(") and str(answers["icon"]).is_empty():
			answers["icon"] = line.get_slice("\"", 1)
		elif line.begins_with("class_name ") and global_name.is_empty():
			answers["name"] = line.trim_prefix("class_name ").get_slice(" ", 0).strip_edges()
		if line.begins_with("extends ") or line.contains(" extends "):
			past_extends = true
	return answers


## The form's answers now, in the shape `answers_of` reads, with `name` as the one to keep.
func _answers_now(name: String) -> Dictionary:
	var shelf: Variant = _shelf_option.get_item_metadata(_shelf_option.selected) if _shelf_option.selected >= 0 else ""
	return {"name": name, "works_on": str(_kind_option.get_item_metadata(_kind_option.selected)),
		"scene": _global and _kind_option.selected == 1, "category": str(shelf), "icon": _icon_path,
		"description": Scaffold._one_line(_desc_edit.text)}


## Save changes: a name problem is said under the field; a new name asks the rename everywhere first,
## which lists every place it changes before it writes, and Rename there saves the rest with it.
func _save_settings() -> void:
	var current: String = str(_editing["name"])
	var typed: String = _name_edit.text.strip_edges()
	var problem: String = name_problem(typed, _global, current)
	if not problem.is_empty():
		_name_note.say(problem)
		return
	_dialog.hide()
	if typed == current:
		write_settings(typed)
		return
	_dock._head_actions.open_class_rename(current, typed, write_settings)


## Writes what changed since the form opened into the open sheet as ONE undo step - with the class
## rename everywhere when a behaviour's name changed - then the Autoload row a global's name or
## script-or-scene lives in, and saves the file.
func write_settings(name: String) -> void:
	var before: Dictionary = _editing
	var after: Dictionary = _answers_now(name)
	var current: String = str(before["name"])
	var action: String = EventSheetL10n.translate("Global settings") if _global else EventSheetL10n.translate("Behaviour settings")
	var write: Callable = func() -> bool:
		var changed: bool = write_answers(_dock._current_sheet, before, after, _dock._head_actions)
		if _global and name != current:
			EventSheetRefactor.rename_symbol(_dock._current_sheet, current, name, true)
			changed = true
		return changed
	var written: bool = false
	if not _global and name != current:
		written = _dock._head_actions.apply_class_rename_to(name, action, write)
	else:
		written = _dock._perform_undoable_sheet_edit(action, write)
	var elsewhere: String = ""
	if _global and name != current:
		# Every other sheet reaches a global by its name, so they are renamed by the same walk.
		var moved: Array[Dictionary] = EventSheetHeadActions.rename_class_across(current, name,
			EventSheetFindReferences.open_sheets_of(_dock), PackedStringArray([str(before["path"])]),
			EventSheetProjectFind.list_all_project_sheets(), true)
		_dock._head_actions.mark_open_tabs_unsaved(moved)
		elsewhere = EventSheetHeadActions.class_rename_elsewhere_text(current, moved)
	var row_note: String = _write_global_row_for(before, after) if _global else ""
	if not written and row_note.is_empty():
		_dock._set_status(EventSheetL10n.translate("Nothing changed."))
		return
	_dock._refresh_after_edit()
	_dock._refresh_title_strip()
	if written:
		_dock._sheet_io._on_save_requested()
	_dock._set_status(EventSheetL10n.translate("Saved the settings of %s.") % name + elsewhere + row_note)


## A global's Autoload row, moved to its new name and to its script or its scene when either changed.
## Says what it did, or "" when the row did not change.
func _write_global_row_for(before: Dictionary, after: Dictionary) -> String:
	var current: String = str(before["name"])
	var scene: bool = bool(after["scene"])
	if str(after["name"]) == current and scene == bool(before["scene"]):
		return ""
	var target: String = str(ProjectSettings.get_setting("autoload/" + current, "")).trim_prefix("*")
	if scene != bool(before["scene"]):
		# A scene made here sits beside the script, the way New global makes one.
		target = str(before["path"]).get_basename() + ".tscn" if scene else str(before["path"])
		if scene and not FileAccess.file_exists(target):
			ResourceSaver.save(Scaffold.global_scene(str(after["name"]), load(str(before["path"])) as Script), target)
	set_global_row(current, target, str(after["name"]))
	return " " + EventSheetL10n.translate("Its row in Project Settings > Globals > Autoload now loads %s as %s; Edit > Undo in Godot puts it back.") % [
		target.get_file(), str(after["name"])]


## Writes into `sheet` the answers that differ between `before` and `after`: the `@icon` line and the
## `##` description line through the head's own writer (`head`), the `## @ace_category` line, and the
## type of a behaviour's host. True when anything was written. Runs inside the undo funnel.
static func write_answers(sheet: EventSheetResource, before: Dictionary, after: Dictionary, head: RefCounted) -> bool:
	var changed: bool = false
	if str(after["icon"]) != str(before["icon"]):
		head.write_head_line(EventSheetHeadBands.BAND_ICON, str(after["icon"]))
		changed = true
	if str(after["description"]) != str(before["description"]):
		head.write_head_line(EventSheetHeadBands.BAND_DESCRIPTION, str(after["description"]))
		changed = true
	if str(after["category"]) != str(before["category"]):
		write_category(sheet, str(after["category"]))
		changed = true
	if not bool(before["global"]) and str(after["works_on"]) != str(before["works_on"]):
		retarget_host(sheet, str(before["works_on"]), str(after["works_on"]))
		changed = true
	return changed


## The `## @ace_category("...")` line of `sheet`'s header written as `category`: replaced where it is,
## put at the top of the file when it is not, taken out for "". The sheet's own field follows it.
static func write_category(sheet: EventSheetResource, category: String) -> void:
	var value: String = Scaffold._one_line(category)
	var wanted: String = "" if value.is_empty() else "## @ace_category(\"%s\")" % value
	sheet.addon_category = value
	for entry: Variant in sheet.events:
		var raw: RawCodeRow = entry as RawCodeRow
		if raw == null or not EventSheetViewport.is_scaffolding_code(raw.code):
			break
		var lines: PackedStringArray = raw.code.split("\n")
		for index: int in range(lines.size()):
			if not lines[index].strip_edges().begins_with("## @ace_category("):
				continue
			if wanted.is_empty():
				lines.remove_at(index)
			else:
				lines[index] = wanted
			raw.code = "\n".join(lines)
			return
	var first: RawCodeRow = sheet.events[0] as RawCodeRow if not sheet.events.is_empty() else null
	if not wanted.is_empty() and first != null and EventSheetViewport.is_scaffolding_code(first.code):
		first.code = "%s\n%s" % [wanted, first.code]


## A behaviour moved onto another kind of object: its `host` variable is typed `works_on`, and the
## lines about the host (the cast in `_enter_tree`, its doc comment, the warning when the parent is
## not one) name it instead of `was`. Nothing else in the file is touched.
static func retarget_host(sheet: EventSheetResource, was: String, works_on: String) -> void:
	sheet.host_class = works_on
	var word: RegEx = RegEx.create_from_string("\\b%s\\b" % was)
	for entry: Variant in sheet.events:
		var variable: LocalVariable = entry as LocalVariable
		if variable != null and variable.name == "host" and variable.type_name == was:
			variable.type_name = works_on
		var raw: RawCodeRow = entry as RawCodeRow
		if raw == null:
			continue
		var lines: PackedStringArray = raw.code.split("\n")
		for index: int in range(lines.size()):
			if lines[index].contains("host") or lines[index].contains("requires a %s parent" % was):
				lines[index] = word.sub(lines[index], works_on, true)
		raw.code = "\n".join(lines)
