@tool
class_name EventSheetSharedSheetDialogs
extends RefCounted
# Shared event sheets: the two gestures (V11).
#
#  Sheet ▸ New shared sheet…   makes a script whose whole job is to be included, and asks the one
#                              question that is answered per shared sheet rather than per includer:
#                              is it a BASE CLASS (the including script extends it) or a HELPER (the
#                              including script keeps one, calls it each tick and forwards its
#                              triggers to it)?
#  Add ▸ Include sheet…        wires the open script to one, in whichever way that shared sheet
#                              already said. Nothing is asked twice.
#
# Both are ordinary Godot underneath - inheritance or composition - so a project that deletes the
# addon keeps working. All the writing lives in EventSheetSharedSheets (static, pure, pinned
# headless); this file is the shell.

var _dock: Control = null

var new_window: Window = null
var name_edit: LineEdit = null
var wiring_picker: OptionButton = null
var preview_label: Label = null


func init(dock: Control) -> void:
	_dock = dock


func open_new_shared_sheet() -> void:
	_build_new_window()
	_refresh_preview()
	new_window.popup_centered(Vector2i(560, 320))


func _build_new_window() -> void:
	if new_window != null:
		return
	new_window = Window.new()
	new_window.title = EventSheetL10n.translate("New Shared Sheet")
	new_window.size = Vector2i(560, 320)
	new_window.close_requested.connect(func() -> void: new_window.hide())
	var body: VBoxContainer = EventSheetPopupUI.form_box()
	name_edit = LineEdit.new()
	name_edit.placeholder_text = "Pause Handling"
	name_edit.text_changed.connect(func(_text: String) -> void: _refresh_preview())
	body.add_child(EventSheetPopupUI.form_row(EventSheetL10n.translate("Called"), name_edit))
	wiring_picker = OptionButton.new()
	wiring_picker.add_item(EventSheetL10n.translate("as a base class"), 0)
	wiring_picker.add_item(EventSheetL10n.translate("as a helper"), 1)
	wiring_picker.item_selected.connect(func(_index: int) -> void: _refresh_preview())
	body.add_child(EventSheetPopupUI.form_row(EventSheetL10n.translate("Included"), wiring_picker,
		EventSheetPopupUI.LABEL_MIN_WIDTH,
		EventSheetL10n.translate("As a base class, the including script extends it and its events simply are that script's events. As a helper, the including script keeps one of it and forwards its triggers to it - use this when the script already has a base class it needs.")))
	preview_label = Label.new()
	body.add_child(EventSheetPopupUI.titled_card(EventSheetL10n.translate("Ships as"), preview_label))
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	var create_button: Button = Button.new()
	create_button.text = EventSheetL10n.translate("Create")
	create_button.pressed.connect(_create_shared_sheet)
	buttons.add_child(create_button)
	body.add_child(buttons)
	new_window.add_child(EventSheetPopupUI.margined(body))
	_dock.add_child(new_window)


func chosen_wiring() -> String:
	return EventSheetSharedSheets.WIRING_HELPER if wiring_picker.selected == 1 else EventSheetSharedSheets.WIRING_BASE_CLASS


func _refresh_preview() -> void:
	var shared_class: String = EventSheetSharedSheets.class_name_for(name_edit.text)
	preview_label.text = "class_name %s  ·  %s" % [shared_class,
		EventSheetL10n.translate(EventSheetSharedSheets.wiring_words(chosen_wiring()))]


func _create_shared_sheet() -> void:
	var display_name: String = name_edit.text.strip_edges()
	if display_name.is_empty():
		_dock._set_status(EventSheetL10n.translate("A shared sheet needs a name."), true)
		return
	var path: String = "res://%s.gd" % EventSheetSharedSheets.class_name_for(display_name).to_snake_case()
	if FileAccess.file_exists(path):
		_dock._set_status(EventSheetL10n.translate("%s already exists.") % path.get_file(), true)
		return
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_dock._set_status(EventSheetL10n.translate("Could not write %s.") % path.get_file(), true)
		return
	file.store_string(EventSheetSharedSheets.new_shared_sheet_source(display_name, chosen_wiring()))
	file.close()
	new_window.hide()
	if Engine.is_editor_hint() and Engine.has_singleton("EditorInterface"):
		EditorInterface.get_resource_filesystem().scan()
	_dock._set_status(EventSheetL10n.translate("Made %s - include it from any script with Add > Include sheet….") % path.get_file())
	_dock._load_sheet_from_path(path)


## Add ▸ Include sheet…: browse to a shared sheet and wire the open script to it.
func open_include_sheet() -> void:
	var dialog: FileDialog = FileDialog.new()
	dialog.title = EventSheetL10n.translate("Include Sheet")
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_RESOURCES
	dialog.filters = PackedStringArray(["*.gd ; Shared sheet"])
	dialog.file_selected.connect(func(path: String) -> void:
		include_shared_sheet(path)
		dialog.call_deferred("queue_free"))
	dialog.canceled.connect(func() -> void: dialog.queue_free())
	_dock.add_child(dialog)
	dialog.popup_centered(Vector2i(820, 560))


## Wires the open script to the shared sheet at `path`. Returns what happened, so the menu item and
## a test read the same answer. The open sheet is saved first: the include is written into the FILE,
## which is the only place a base class or a member can honestly live.
func include_shared_sheet(path: String) -> Dictionary:
	var target: String = str(_dock._current_sheet_path)
	if target.is_empty() or not target.ends_with(".gd"):
		var refusal: Dictionary = {"ok": false, "error": EventSheetL10n.translate("Save this sheet as a script first - an include is written into the file.")}
		_dock._set_status(str(refusal["error"]), true)
		return refusal
	_dock._on_save_requested()
	var result: Dictionary = EventSheetSharedSheets.apply_include(
		FileAccess.get_file_as_string(target), FileAccess.get_file_as_string(path), path)
	if not bool(result["ok"]):
		_dock._set_status(str(result["error"]), true)
		return result
	var file: FileAccess = FileAccess.open(target, FileAccess.WRITE)
	if file == null:
		_dock._set_status(EventSheetL10n.translate("Could not write %s.") % target.get_file(), true)
		return {"ok": false, "error": "write failed"}
	file.store_string(str(result["text"]))
	file.close()
	_dock._set_status(EventSheetL10n.translate("Included %s %s.") % [path.get_file(),
		EventSheetL10n.translate(EventSheetSharedSheets.wiring_words(str(result["wiring"])))])
	_dock._load_sheet_from_path(target)
	return result
