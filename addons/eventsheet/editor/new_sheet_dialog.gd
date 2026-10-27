# Godot EventSheets - "New Event Sheet" dialog for the FileSystem "Create New >" submenu.
#
# The follow-up prompt behind the FileSystem right-click "Create New > Event Sheet..." entry: it
# asks for a file name and a starter, exactly like Godot's own "Create New > Script/Scene" dialogs
# do, then emits create_requested(directory, sheet_name, starter_id) - the plugin writes the .gd and
# opens it.
#
# The band across the top names the exact file Create writes. A name already taken in the folder
# says so beside the field and Create waits, rather than quietly writing a suffixed file nobody
# asked for. Each starter in the dropdown carries its one-line pitch, and the help strip at the foot
# says what the focused field is and the line the sheet will start with.
#
# Built ENTIRELY with EventSheetPopupUI helpers (house rule). It is parented to whatever Node the
# caller passes to init_dialog() (the plugin hands it EditorInterface.get_base_control()), so it
# never reaches into the EventSheet workspace dock - which may not be built yet the first time the
# FileSystem entry fires. All logic (name -> filename) lives in EventSheetWorkflow and
# EventSheetStarterTemplates.build_starter, so this class is thin glue and headless-newable.
@tool
class_name EventSheetNewSheetDialog
extends RefCounted

signal create_requested(directory: String, sheet_name: String, starter_id: int)

## What the name field opens at, and the starter a fresh dialog lands on.
const DEFAULT_SHEET_NAME := "event_sheet"
const BLANK_STARTER_ID := 0

var _dialog: ConfirmationDialog = null
var _name_edit: LineEdit = null
var _starter_option: OptionButton = null
var _band: EventSheetPopupUI.RowBand = null
var _taken_note: EventSheetPopupUI.StateNote = null
var _strip: EventSheetPopupUI.HelpStrip = null
var _directory: String = "res://"


func init_dialog(parent_node: Node) -> void:
	if _dialog != null:
		return
	var parts: Dictionary = EventSheetPopupUI.panel_window("", Vector2i.ZERO, parent_node, EventSheetL10n.translate("Create"),
		_on_confirmed, true)
	_dialog = parts["window"]
	var form: VBoxContainer = parts["box"]
	form.custom_minimum_size = Vector2(EventSheetPalette.scaled_f(440.0), 0.0)
	_band = EventSheetPopupUI.RowBand.new(true)
	form.add_child(_band)
	_name_edit = LineEdit.new()
	_name_edit.text_changed.connect(func(_text: String) -> void: _refresh())
	_dialog.register_text_enter(_name_edit)
	var fields: VBoxContainer = EventSheetPopupUI.form_box()
	fields.add_child(EventSheetPopupUI.form_row("Name", _name_edit))
	_taken_note = EventSheetPopupUI.StateNote.new()
	fields.add_child(_taken_note)
	# "Start from" offers the dock-free starters (Blank, the 2D movers, the data and system shapes,
	# the editor tools) - one click lands a jammer on a working sheet at creation time.
	_starter_option = EventSheetPopupUI.described_option()
	for starter: Dictionary in EventSheetStarterTemplates.create_new_starters():
		EventSheetPopupUI.add_described_item(_starter_option, str(starter.get("label")),
			EventSheetL10n.translate(starter_pitch(int(starter.get("id")))), int(starter.get("id")))
	_starter_option.item_selected.connect(func(_index: int) -> void: _refresh())
	fields.add_child(EventSheetPopupUI.form_row("Start from",
		EventSheetPopupUI.described_field(_starter_option, EventSheetPalette.scaled_f(300.0))))
	form.add_child(EventSheetPopupUI.titled_card(EventSheetL10n.translate("New Event Sheet"), fields))
	_strip = EventSheetPopupUI.help_strip("", "", "", "", EventSheetPalette.scaled_f(420.0))
	_strip.follow(_name_edit, EventSheetL10n.translate("Name"),
		EventSheetL10n.translate("The file name. Words become snake_case and a trailing .gd is dropped."))
	_strip.follow_option(_starter_option, func(index: int) -> Dictionary:
		return {"heading": _starter_option.get_item_text(index), "body": _starter_option.get_item_tooltip(index)})
	form.add_child(_strip)


## The one line a starter is offered with: the Start page's pitch for a game starter, the editor
## tool shape's note for a tool, an extension starter's own description.
static func starter_pitch(starter_id: int) -> String:
	for starter: Dictionary in EventSheetStarterTemplates.MENU_STARTERS:
		if int(starter["id"]) == starter_id:
			return str(starter["pitch"])
	for shape: Dictionary in EventSheetStarterTemplates.EDITOR_TOOL_SHAPES:
		if int(shape["id"]) == starter_id:
			var note: String = str(shape["note"])
			return "%s%s." % [note.substr(0, 1).to_upper(), note.substr(1)]
	var registered: Array[Dictionary] = EventSheets.registered_starters()
	if starter_id >= 1000 and starter_id - 1000 < registered.size():
		return str(registered[starter_id - 1000].get("description", ""))
	return ""


## Shows the dialog for a target directory. Re-fills the name to a clean default each open so a
## previous run's edits never leak into the next create.
func open(directory: String = "res://") -> void:
	_directory = directory if not directory.strip_edges().is_empty() else "res://"
	if _dialog == null:
		return
	_dialog.title = EventSheetL10n.translate("Create an event sheet in %s") % _directory
	_name_edit.text = DEFAULT_SHEET_NAME
	_starter_option.select(0)
	EventSheetPopupUI.follow_description(_starter_option)
	_refresh()
	EventSheetPopupUI.popup_fitted(_dialog, Vector2i(EventSheetPalette.scaled(460), 0))
	_name_edit.grab_focus()
	_name_edit.select_all()


## The band, the taken-name note, Create's state and the strip's IN CODE line, from the fields.
func _refresh() -> void:
	var path: String = target_path()
	var taken: bool = FileAccess.file_exists(path)
	_band.show_row("", path, EventSheetL10n.translate("written and opened on Create"))
	_taken_note.say(EventSheetL10n.translate("%s is already in this folder - pick another name.") % path.get_file() if taken else "")
	EventSheetPopupUI.mark_field(_name_edit, taken)
	_dialog.get_ok_button().disabled = taken
	var host: String = EventSheetStarterTemplates.build_starter(selected_starter_id()).host_class
	_strip.set_reading("", "extends %s" % (host if not host.is_empty() else "Node"))


## The exact file Create writes for the name in the field.
func target_path() -> String:
	return EventSheetWorkflow.sheet_file_path(_directory, _name_edit.text if _name_edit != null else DEFAULT_SHEET_NAME)


## The starter id currently chosen (from the OptionButton metadata). Defaults to Blank (0).
func selected_starter_id() -> int:
	if _starter_option == null or _starter_option.selected < 0:
		return BLANK_STARTER_ID
	return int(_starter_option.get_item_metadata(_starter_option.selected))


func _on_confirmed() -> void:
	if FileAccess.file_exists(target_path()):
		return
	create_requested.emit(_directory, _name_edit.text if _name_edit != null else DEFAULT_SHEET_NAME, selected_starter_id())


## Frees the underlying window. The plugin holds this dialog for its lifetime (reused across
## invocations) and calls this on teardown so the window never orphans on disable.
func free_dialog() -> void:
	if _dialog != null and is_instance_valid(_dialog):
		_dialog.queue_free()
	_dialog = null
