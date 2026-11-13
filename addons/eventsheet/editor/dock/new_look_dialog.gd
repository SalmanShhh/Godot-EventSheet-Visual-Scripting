@tool
extends RefCounted
# New inspector look: asks a name and what the look works on, writes a small working look (a plain field
# that shows the value) into res://eventsheet_addons/looks/, and hands the new file back to be opened as
# a sheet.
#
#   Name        [ star_rating     ]
#   Works on    [ int, float      ]
#   The file it writes: res://eventsheet_addons/looks/star_rating.gd
#                                                     Create   Cancel
#
# DELIBERATELY NO `class_name`: the dock reaches it with `load()` of its path when the window is asked
# for, so nothing about it compiles on the boot or first-open path. All the logic (the name, the types,
# the text of the file) lives in EventSheetInspectorLookCatalogue, so this is thin glue.

## Handed the path of the file that was written, once Create has written it.
signal created(path: String)

const CATALOGUE_PATH := "res://addons/eventsheet/editor/inspector/look_catalogue.gd"
const DEFAULT_NAME := "my_look"
const DEFAULT_TYPES := "int, float"

var _dialog: ConfirmationDialog = null
var _name_edit: LineEdit = null
var _types_edit: LineEdit = null
var _band: EventSheetPopupUI.RowBand = null
var _note: EventSheetPopupUI.StateNote = null
var _strip: EventSheetPopupUI.HelpStrip = null


func init_dialog(parent_node: Node) -> void:
	if _dialog != null:
		return
	var parts: Dictionary = EventSheetPopupUI.panel_window("", Vector2i.ZERO, parent_node, EventSheetL10n.translate("Create"),
		_on_confirmed, false)
	_dialog = parts["window"]
	var form: VBoxContainer = parts["box"]
	form.custom_minimum_size = Vector2(EventSheetPalette.scaled_f(440.0), 0.0)
	_band = EventSheetPopupUI.RowBand.new(true)
	form.add_child(_band)
	_name_edit = LineEdit.new()
	_name_edit.text_changed.connect(func(_text: String) -> void: _refresh())
	_dialog.register_text_enter(_name_edit)
	_types_edit = LineEdit.new()
	_types_edit.placeholder_text = EventSheetL10n.translate("int, float, Vector2 - or nothing for any type")
	_types_edit.text_changed.connect(func(_text: String) -> void: _refresh())
	_dialog.register_text_enter(_types_edit)
	var fields: VBoxContainer = EventSheetPopupUI.form_box()
	fields.add_child(EventSheetPopupUI.form_row(EventSheetL10n.translate("Name"), _name_edit))
	fields.add_child(EventSheetPopupUI.form_row(EventSheetL10n.translate("Works on"), _types_edit))
	_note = EventSheetPopupUI.StateNote.new()
	fields.add_child(_note)
	form.add_child(EventSheetPopupUI.titled_card(EventSheetL10n.translate("New inspector look"), fields))
	_strip = EventSheetPopupUI.help_strip("", "", "", "", EventSheetPalette.scaled_f(420.0))
	_strip.follow(_name_edit, EventSheetL10n.translate("Name"),
		EventSheetL10n.translate("The file name, and the word the look is known by. Words become snake_case."))
	_strip.follow(_types_edit, EventSheetL10n.translate("Works on"),
		EventSheetL10n.translate("The kinds of property this look can be put on, separated by commas. Leave it empty for any kind."))
	form.add_child(_strip)


func open() -> void:
	if _dialog == null:
		return
	_dialog.title = EventSheetL10n.translate("New inspector look")
	_name_edit.text = _free_name()
	_types_edit.text = DEFAULT_TYPES
	_refresh()
	EventSheetPopupUI.popup_fitted(_dialog, Vector2i(EventSheetPalette.scaled(460), 0))
	_name_edit.grab_focus()
	_name_edit.select_all()


## The first of my_look, my_look2, my_look3... that is not taken, so the window never opens on a red line.
func _free_name() -> String:
	var catalogue: Script = load(CATALOGUE_PATH)
	var candidate: String = DEFAULT_NAME
	var number: int = 2
	while not str(catalogue.call("new_look_problem", candidate, "")).is_empty() and number < 100:
		candidate = "%s%d" % [DEFAULT_NAME, number]
		number += 1
	return candidate


## The file the name makes, the sentence that stops Create (if any), and Create's state.
func _refresh() -> void:
	var catalogue: Script = load(CATALOGUE_PATH)
	var problem: String = str(catalogue.call("new_look_problem", _name_edit.text, _types_edit.text))
	var path: String = "%s/%s.gd" % [catalogue.get("PROJECT_FOLDER"), catalogue.call("look_file_name", _name_edit.text)]
	_band.show_row("", path, EventSheetL10n.translate("written and opened on Create"))
	_note.say(problem)
	EventSheetPopupUI.mark_field(_name_edit, not problem.is_empty() and not _name_edit.text.strip_edges().is_empty())
	_dialog.get_ok_button().disabled = not problem.is_empty()
	_strip.set_reading("", "extends EventSheetInspectorLook")


func _on_confirmed() -> void:
	var result: Dictionary = load(CATALOGUE_PATH).call("create_look", _name_edit.text, _types_edit.text)
	if not bool(result.get("ok", false)):
		_note.say(str(result.get("message", "")), EventSheetPopupUI.TONE_WARNING)
		return
	_dialog.hide()
	if Engine.is_editor_hint() and Engine.has_singleton("EditorInterface"):
		Engine.get_singleton("EditorInterface").get_resource_filesystem().scan()
	created.emit(str(result["path"]))


## Frees the window. The dock holds this dialog for its lifetime and calls this on teardown.
func free_dialog() -> void:
	if _dialog != null and is_instance_valid(_dialog):
		_dialog.queue_free()
	_dialog = null
