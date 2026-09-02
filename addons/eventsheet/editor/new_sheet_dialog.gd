# Godot EventSheets - "New Event Sheet" dialog for the FileSystem "Create New >" submenu.
#
# The follow-up prompt behind the FileSystem right-click "Create New > Event Sheet..." entry: it
# asks for a file name and a starter, exactly like Godot's own "Create New > Script/Scene" dialogs
# do, then emits create_requested(directory, sheet_name, starter_id) - the plugin writes the .gd and
# opens it.
#
# Built ENTIRELY with EventSheetPopupUI helpers (house rule). It is parented to whatever Node the
# caller passes to init_dialog() (the plugin hands it EditorInterface.get_base_control()), so it
# never reaches into the EventSheet workspace dock - which may not be built yet the first time the
# FileSystem entry fires. All logic (name -> filename) lives in EventSheetWorkflow.write_sheet_file
# and EventSheetStarterTemplates.build_starter, so this class is thin glue and headless-newable.
@tool
class_name EventSheetNewSheetDialog
extends RefCounted

signal create_requested(directory: String, sheet_name: String, starter_id: int)

## The two fields, named once so the build, the re-open and the read-back cannot spell them apart.
const FIELD_NAME := "name"
const FIELD_STARTER := "starter"
## What the name field opens at, and the starter a fresh dialog lands on.
const DEFAULT_SHEET_NAME := "event_sheet"
const BLANK_STARTER_ID := 0

var _dialog: ConfirmationDialog = null
var _form: EventSheetFieldForm = null
var _name_edit: LineEdit = null
var _target_label: Label = null
var _directory: String = "res://"


func init_dialog(parent_node: Node) -> void:
	if _dialog != null:
		return
	_dialog = ConfirmationDialog.new()
	_dialog.title = "New Event Sheet"
	_dialog.ok_button_text = "Create"
	_dialog.confirmed.connect(_on_confirmed)
	parent_node.add_child(_dialog)

	var form: VBoxContainer = EventSheetPopupUI.form_box()
	form.custom_minimum_size = Vector2(420.0, 0.0)
	_dialog.add_child(EventSheetPopupUI.margined(form))

	# "Start from" mirrors the New-Sheet menu's dock-free starters (Blank + 2D movement + the
	# three data-asset intents) - one click lands a jammer on a working sheet at creation time.
	var starter_labels: PackedStringArray = PackedStringArray()
	var starter_ids: Array = []
	for starter: Dictionary in EventSheetStarterTemplates.create_new_starters():
		starter_labels.append(str(starter.get("label")))
		starter_ids.append(int(starter.get("id")))
	_form = EventSheetPopupUI.form(form, [
		EventSheetPopupUI.text_field(FIELD_NAME, "Name").default(DEFAULT_SHEET_NAME),
		EventSheetPopupUI.options_field(FIELD_STARTER, "Start from").options(starter_labels, starter_ids),
	], "New Event Sheet")
	# Enter in the Name field confirms the dialog, which is hand wiring on the built control.
	_name_edit = _form.control(FIELD_NAME) as LineEdit
	_dialog.register_text_enter(_name_edit)

	_target_label = EventSheetPopupUI.hint_label("Creates a .gd sheet in this folder and opens it.")
	form.add_child(_target_label)


## Shows the dialog for a target directory. Re-fills the name to a clean default each open so a
## previous run's edits never leak into the next create.
func open(directory: String = "res://") -> void:
	_directory = directory if not directory.strip_edges().is_empty() else "res://"
	if _form != null:
		_form.set_value(FIELD_NAME, DEFAULT_SHEET_NAME)
		_form.set_value(FIELD_STARTER, BLANK_STARTER_ID)
	if _target_label != null:
		_target_label.text = "Creates a .gd sheet in %s and opens it." % _directory
	if _dialog != null:
		_dialog.popup_centered(Vector2i(440, 0))
		if _name_edit != null:
			_name_edit.grab_focus()
			_name_edit.select_all()


## The starter id currently chosen (from the OptionButton metadata). Defaults to Blank (0).
func selected_starter_id() -> int:
	return BLANK_STARTER_ID if _form == null else int(_form.value(FIELD_STARTER))


func _on_confirmed() -> void:
	var sheet_name: String = DEFAULT_SHEET_NAME if _form == null else str(_form.value(FIELD_NAME))
	create_requested.emit(_directory, sheet_name, selected_starter_id())


## Frees the underlying window. The plugin holds this dialog for its lifetime (reused across
## invocations) and calls this on teardown so the window never orphans on disable.
func free_dialog() -> void:
	if _dialog != null and is_instance_valid(_dialog):
		_dialog.queue_free()
	_dialog = null
