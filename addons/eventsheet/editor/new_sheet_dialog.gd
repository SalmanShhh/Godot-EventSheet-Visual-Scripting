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

var _dialog: ConfirmationDialog = null
var _name_edit: LineEdit = null
var _start_option: OptionButton = null
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

	_name_edit = LineEdit.new()
	_name_edit.text = "event_sheet"
	_dialog.register_text_enter(_name_edit)
	form.add_child(EventSheetPopupUI.form_row("Name", _name_edit))

	# "Start from" mirrors the New-Sheet menu's dock-free starters (Blank + 2D movement + the
	# three data-asset intents) - one click lands a jammer on a working sheet at creation time.
	_start_option = OptionButton.new()
	for starter: Dictionary in EventSheetStarterTemplates.create_new_starters():
		_start_option.add_item(str(starter.get("label")))
		_start_option.set_item_metadata(_start_option.item_count - 1, int(starter.get("id")))
	_start_option.select(0)
	form.add_child(EventSheetPopupUI.form_row("Start from", _start_option))

	_target_label = EventSheetPopupUI.hint_label("Creates a .gd sheet in this folder and opens it.")
	form.add_child(_target_label)


## Shows the dialog for a target directory. Re-fills the name to a clean default each open so a
## previous run's edits never leak into the next create.
func open(directory: String = "res://") -> void:
	_directory = directory if not directory.strip_edges().is_empty() else "res://"
	if _name_edit != null:
		_name_edit.text = "event_sheet"
	if _start_option != null:
		_start_option.select(0)
	if _target_label != null:
		_target_label.text = "Creates a .gd sheet in %s and opens it." % _directory
	if _dialog != null:
		_dialog.popup_centered(Vector2i(440, 0))
		if _name_edit != null:
			_name_edit.grab_focus()
			_name_edit.select_all()


## The starter id currently chosen (from the OptionButton metadata). Defaults to Blank (0).
func selected_starter_id() -> int:
	if _start_option == null or _start_option.selected < 0:
		return 0
	return int(_start_option.get_item_metadata(_start_option.selected))


func _on_confirmed() -> void:
	var sheet_name: String = _name_edit.text if _name_edit != null else "event_sheet"
	create_requested.emit(_directory, sheet_name, selected_starter_id())


## Frees the underlying window. The plugin holds this dialog for its lifetime (reused across
## invocations) and calls this on teardown so the window never orphans on disable.
func free_dialog() -> void:
	if _dialog != null and is_instance_valid(_dialog):
		_dialog.queue_free()
	_dialog = null
