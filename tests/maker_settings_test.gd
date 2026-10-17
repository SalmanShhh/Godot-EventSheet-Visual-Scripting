# Godot EventSheets - Behaviour settings… and Global settings…, and the doors that reach the makers.
#
# The New behaviour / New global form reopens on a file that exists with every answer read from the
# file's own header, so a file written by hand opens the same way; Save changes writes only what
# changed, through the sheet, and saves the file. A new name goes through the one rename everywhere.
# The doors: the file name's click menu, an object's Behaviours list (+ New behaviour…, and a
# behaviour's right-click), a global's right-click in the picker, and the Start page shelves.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "maker_settings_test"
const BEHAVIOUR_PATH := "user://zz_settings_patrol.gd"
const GLOBAL_PATH := "user://zz_settings_state.gd"
const BEHAVIOUR := """## @ace_category("Movement")
@icon("res://icon.svg")
class_name ZzSettingsPatrol
extends Node
## Walks between points.

## The node this behavior acts on (its parent). Required host: CharacterBody2D.
var host: CharacterBody2D = null

func _enter_tree() -> void:
	host = get_parent() as CharacterBody2D
	if host == null:
		push_warning("ZzSettingsPatrol behavior requires a CharacterBody2D parent.")
"""


static func run() -> bool:
	var ok: bool = _answers_come_from_the_header()
	ok = _behaviour_settings_save_what_changed() and ok
	ok = _global_settings_and_its_row() and ok
	ok = _the_doors() and ok
	return ok


static func _answers_come_from_the_header() -> bool:
	var hand_written: String = "# my enemy helper\n## Patrols the ledge.\nextends Node\nvar host: Node2D\n"
	return SUPPORT.pins(P, [
		["a behaviour's answers are its header's lines", EventSheetNewAddonPanel.answers_of(BEHAVIOUR, BEHAVIOUR_PATH), {
			"path": BEHAVIOUR_PATH, "global": false, "name": "ZzSettingsPatrol", "works_on": "CharacterBody2D",
			"scene": false, "category": "Movement", "icon": "res://icon.svg", "description": "Walks between points."}],
		["a hand-written one answers too: the ## line above extends, no category, no class",
			EventSheetNewAddonPanel.answers_of(hand_written, "res://zz.gd"), {
			"path": "res://zz.gd", "global": false, "name": "", "works_on": "Node2D", "scene": false,
			"category": "", "icon": "", "description": "Patrols the ledge."}],
		["the doc comments under the host are not the description",
			EventSheetNewAddonPanel.answers_of("extends Node\n\n## The host.\nvar host: Node2D\n", "res://zz.gd")["description"], ""],
		["...nor a function's doc comment written straight under extends", EventSheetNewAddonPanel.answers_of(
			"extends Node\n## Called each frame.\nfunc _process(_delta: float) -> void:\n\tpass\n", "res://zz.gd")["description"], ""],
		["...while the line under extends, then a blank, still is", EventSheetNewAddonPanel.answers_of(
			"extends Node\n## Patrols the ledge.\n\nfunc _process(_delta: float) -> void:\n\tpass\n", "res://zz.gd")["description"],
			"Patrols the ledge."],
	])


static func _behaviour_settings_save_what_changed() -> bool:
	_write(BEHAVIOUR_PATH, BEHAVIOUR)
	var dock: EventSheetDock = _dock_on(BEHAVIOUR_PATH)
	var panel: EventSheetNewAddonPanel = dock._new_addon_panel
	panel.open_settings(BEHAVIOUR_PATH)
	var rows: Array = [
		["the form is titled with the name and says what it is", panel._dialog.title, "ZzSettingsPatrol · Behaviour settings"],
		["and saves rather than creates", panel._dialog.ok_button_text, "Save changes"],
		["every answer is filled in", [panel._name_edit.text, panel._kind_option.get_item_text(panel._kind_option.selected),
			str(panel._shelf_option.get_item_metadata(panel._shelf_option.selected)), panel._icon_path, panel._desc_edit.text],
			["ZzSettingsPatrol", "CharacterBody2D", "Movement", "res://icon.svg", "Walks between points."]],
		["the line under the form says where the answers live", panel._path_label.text,
			"Saves into user://zz_settings_patrol.gd itself: its ## @ace_category line, @icon, the ## description line and the type of its host."],
		["the name it already has is no problem", panel._name_note.visible, false],
	]
	EventSheetNewAddonPanel._choose(panel._kind_option, "Node2D", "")
	EventSheetNewAddonPanel._choose(panel._shelf_option, "Combat", "")
	panel._desc_edit.text = "Walks, waits, walks again."
	panel._on_create()
	rows.append(["Save changes writes what changed into the file and nothing else", FileAccess.get_file_as_string(BEHAVIOUR_PATH),
		BEHAVIOUR.replace("Movement", "Combat").replace("CharacterBody2D", "Node2D").replace(
			"Walks between points.", "Walks, waits, walks again.")])
	rows.append(["the sheet reads the new host", dock._current_sheet.host_class, "Node2D"])
	rows.append(["and the file reads back with those answers", EventSheetNewAddonPanel.answers_of(
		FileAccess.get_file_as_string(BEHAVIOUR_PATH), BEHAVIOUR_PATH)["category"], "Combat"])
	# A new name goes through the rename everywhere, which lists the places before it writes.
	panel.open_settings(BEHAVIOUR_PATH)
	panel._name_edit.text = "ZzSettingsWalker"
	panel._on_create()
	var asked: ConfirmationDialog = dock._head_actions._rename_dialog
	rows.append(["a new name asks the rename everywhere first", asked.title if asked != null else "",
		"Rename ZzSettingsPatrol to ZzSettingsWalker?"])
	rows.append(["and nothing is written before it is answered", FileAccess.get_file_as_string(BEHAVIOUR_PATH).contains("ZzSettingsWalker"), false])
	# Reopening rebuilds the form; the window it replaces goes.
	var first: ConfirmationDialog = panel._dialog
	panel.open()
	rows.append(["a reopened form leaves no old window behind", first.is_queued_for_deletion(), true])
	rows.append(["and making a new one is the New behaviour form again", [panel._dialog.title, panel._dialog.ok_button_text], ["New behaviour", "Create"]])
	dock.free()
	DirAccess.remove_absolute(BEHAVIOUR_PATH)
	return SUPPORT.pins(P, rows)


static func _global_settings_and_its_row() -> bool:
	_write(GLOBAL_PATH, "## @ace_category(\"Audio\")\nextends Node\n## Score and lives.\n\nvar score: int = 0\n")
	ProjectSettings.set_setting("autoload/ZzSettingsState", "*" + GLOBAL_PATH)
	var dock: EventSheetDock = _dock_on(GLOBAL_PATH)
	var panel: EventSheetNewAddonPanel = dock._new_addon_panel
	panel.open_settings(GLOBAL_PATH)
	var rows: Array = [
		["a global's form is titled with its autoload name", panel._dialog.title, "ZzSettingsState · Global settings"],
		["its answers come from the file and its Autoload row", [panel._name_edit.text, panel._kind_option.get_item_text(panel._kind_option.selected),
			panel._shelf_option.get_item_text(panel._shelf_option.selected), panel._desc_edit.text], ["ZzSettingsState", "Script", "Audio", "Score and lives."]],
		["the picker finds the script a global runs", ACEPickerDialog.global_script_for("ZzSettingsState"), GLOBAL_PATH],
		["and finds none for a card that is not a global", ACEPickerDialog.global_script_for("Core"), ""],
	]
	# Made as Scene: the scene is made beside the script and the row loads it; the heading is the
	# header's line.
	EventSheetNewAddonPanel._choose(panel._kind_option, "PackedScene", "")
	EventSheetNewAddonPanel._choose(panel._shelf_option, "Saving", "")
	panel._on_create()
	rows.append(["Save changes writes the heading into the file", FileAccess.get_file_as_string(GLOBAL_PATH).get_slice("\n", 0),
		"## @ace_category(\"Saving\")"])
	rows.append(["and the row loads the scene made beside it",
		[ProjectSettings.get_setting("autoload/ZzSettingsState", ""), FileAccess.file_exists("user://zz_settings_state.tscn")],
		["*user://zz_settings_state.tscn", true]])
	DirAccess.remove_absolute("user://zz_settings_state.tscn")
	# The row is renamed where it stands, so Godot loads it in the same order; a row whose name was not
	# global stays that way.
	var order: int = ProjectSettings.get_order("autoload/ZzSettingsState")
	EventSheetNewAddonPanel.set_global_row("ZzSettingsState", "user://zz_settings_state.tscn", "ZzSettingsScore")
	rows.append(["a renamed row keeps its place and loads the new target",
		[ProjectSettings.has_setting("autoload/ZzSettingsState"), ProjectSettings.get_setting("autoload/ZzSettingsScore", ""),
			ProjectSettings.get_order("autoload/ZzSettingsScore")], [false, "*user://zz_settings_state.tscn", order]])
	ProjectSettings.set_setting("autoload/ZzSettingsScore", "user://zz_settings_state.gd")
	EventSheetNewAddonPanel.set_global_row("ZzSettingsScore", GLOBAL_PATH)
	rows.append(["a row without the star keeps it off", ProjectSettings.get_setting("autoload/ZzSettingsScore", ""), GLOBAL_PATH])
	ProjectSettings.set_setting("autoload/ZzSettingsScore", null)
	dock.free()
	DirAccess.remove_absolute(GLOBAL_PATH)
	return SUPPORT.pins(P, rows)


static func _the_doors() -> bool:
	# The file name's click menu leads with the settings.
	_write(BEHAVIOUR_PATH, BEHAVIOUR)
	var dock: EventSheetDock = _dock_on(BEHAVIOUR_PATH)
	dock._head_actions.open_file_options()
	var menu: PopupMenu = dock._head_actions._file_menu
	var rows: Array = [["the file name offers its settings first", _menu_texts(menu),
		["Behaviour settings…", "Open in the script editor", "Show in FileSystem"]]]
	# An object's Behaviours list: + New behaviour… for that object, and a behaviour's right-click.
	var made: Array = []
	var opened: Array = []
	var dialog: EventSheetAddBehaviorDialog = EventSheetAddBehaviorDialog.new()
	dialog.configure(func(_pack: Dictionary, _values: Dictionary, _inline: bool, _label: String) -> void: pass,
		func(label: String, host_class: String) -> void: made.append([label, host_class]),
		func(path: String, settings: bool) -> void: opened.append([path, settings]))
	var body: CharacterBody2D = CharacterBody2D.new()
	dialog._object_label = "Enemy"
	dialog._host = body
	var only_bullet: Array[Dictionary] = [EventSheetPackCatalog.describe("bullet")]
	dialog._packs = only_bullet
	dialog._rebuild_list()
	var last: Button = dialog._list.get_child(dialog._list.get_child_count() - 1) as Button
	rows.append(["the list ends with + New behaviour…", last.text if last != null else "", "+ New behaviour…"])
	if last != null:
		last.pressed.emit()
	rows.append(["which makes one for that object, on its kind", made, [["Enemy", "CharacterBody2D"]]])
	dialog.open_card_menu("res://eventsheet_addons/bullet/bullet_behavior.gd")
	rows.append(["a behaviour's right-click offers its settings or its sheet", _menu_texts(dialog._card_menu),
		["Behaviour settings…", "Open as sheet"]])
	dialog._card_menu.id_pressed.emit(0)
	rows.append(["and settings opens that file's form", opened, [["res://eventsheet_addons/bullet/bullet_behavior.gd", true]]])
	# The New behaviour form opened for an object starts on that object's kind.
	var panel: EventSheetNewAddonPanel = dock._new_addon_panel
	panel.open(false, {"label": "Enemy", "class": "Sprite2D"})
	rows.append(["Works on starts on the object's kind, said in its words",
		[panel._kind_option.get_item_text(panel._kind_option.selected), panel._kind_option.get_item_tooltip(panel._kind_option.selected)],
		["Sprite2D", "The kind of object Enemy is."]])
	panel.open(false, {"label": "Hero", "class": "CharacterBody2D"})
	rows.append(["a kind the list has is chosen, not added again",
		[panel._kind_option.get_item_text(panel._kind_option.selected), panel._kind_option.item_count], ["CharacterBody2D", 7]])
	rows.append(["the picker's globals ask for their settings", ACEPickerDialog.new().has_signal("global_settings_requested"), true])
	dialog.free()
	body.free()
	dock.free()
	DirAccess.remove_absolute(BEHAVIOUR_PATH)
	return SUPPORT.pins(P, rows)


## A dock with the file at `path` open as its sheet, the way opening it opens it.
static func _dock_on(path: String) -> EventSheetDock:
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(GDScriptImporter.new().import_external(path))
	dock._current_sheet_path = path
	return dock


static func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


static func _menu_texts(menu: PopupMenu) -> Array:
	var texts: Array = []
	for index: int in range(menu.item_count if menu != null else 0):
		texts.append(menu.get_item_text(index))
	return texts
