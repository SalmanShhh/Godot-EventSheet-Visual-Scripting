@tool
extends RefCounted
class_name EventSheetNewAddonPanel

# New Behaviour Addon scaffold dialog (Sheet ▸ New Behaviour Addon…).
#
# Owns a small authoring dialog that writes a richly-commented behaviour script under
# res://eventsheet_addons/: its signals become triggers, its methods become actions/conditions,
# and its @export vars become properties — all auto-discovered as custom ACEs in the picker.
#
# Extracted from event_sheet_dock.gd so the dock stays focused. It parents its dialog on the dock
# (passed to init) and, after a successful create, calls back through the dock reference for the
# three post-create steps: rebuild the ACE registry, open the new .gd in Godot, and write the
# dock status bar. The actual code generation + validation lives in BehaviourAddonScaffold.
#
# Owned entirely by this class — the dock just holds one instance and calls open() from the menu.

# preload (not the global class_name) so this parses even before a project re-import registers the
# freshly-added scaffold class in the global class cache.
const BehaviourAddonScaffold := preload("res://addons/eventsheet/editor/behaviour_addon_scaffold.gd")

var _dock: Control = null
var _dialog: Window = null
var _name_edit: LineEdit = null
var _recipe_option: OptionButton = null
var _base_option: OptionButton = null
var _category_edit: LineEdit = null
var _desc_edit: LineEdit = null
var _path_label: Label = null
var _status_label: Label = null

## Wires the dock reference used to parent the dialog and to call back after a create.
func init(dock: Control) -> void:
	_dock = dock

## Opens the dialog fresh (clears the fields), building it lazily on first use.
func open() -> void:
	_build_dialog()
	_name_edit.text = ""
	_category_edit.text = ""
	_desc_edit.text = ""
	_refresh_preview()
	if _dialog.is_inside_tree():  # headless tests: fields are reset, there is no window to pop
		_dialog.popup_centered(Vector2i(540, 360))
		_name_edit.grab_focus()

func _build_dialog() -> void:
	if _dialog != null:
		return
	_dialog = Window.new()
	_dialog.title = "New Behaviour Addon"
	_dialog.visible = false
	_dialog.min_size = Vector2i(480, 320)
	_dialog.close_requested.connect(func() -> void: _dialog.hide())
	_dock.add_child(_dialog)

	var content: VBoxContainer = EventSheetPopupUI.form_box()
	content.add_child(EventSheetPopupUI.hint_label("Creates a ready-to-edit behaviour script under res://eventsheet_addons/. Its signals become triggers, methods become actions/conditions, and @export vars become properties — all auto-discovered as custom ACEs. The skeleton is richly commented to teach the @ace_* annotations."))

	# "Properties" card — name / base class / category / description, grouped into a themed inset
	# card so this dialog matches the picker / variable / function dialogs instead of flat gray.
	var properties_box: VBoxContainer = EventSheetPopupUI.form_box()
	content.add_child(EventSheetPopupUI.titled_card("Properties", properties_box))

	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "PlayerCombat"
	_name_edit.text_changed.connect(func(_t: String) -> void: _refresh_preview())
	_name_edit.text_submitted.connect(func(_t: String) -> void: _on_create())
	properties_box.add_child(EventSheetPopupUI.form_row("Name", _name_edit))

	# Starter recipe — the teaching skeleton by default, or a small COMPLETE behaviour (cooldown,
	# stat pool) so "new addon" can mean "working example I rename", not just a commented template.
	_recipe_option = OptionButton.new()
	for recipe: Dictionary in BehaviourAddonScaffold.RECIPES:
		_recipe_option.add_item(str(recipe.get("label")))
	_recipe_option.select(0)
	properties_box.add_child(EventSheetPopupUI.form_row("Start from", _recipe_option))

	_base_option = OptionButton.new()
	for base: String in BehaviourAddonScaffold.BASE_CLASSES:
		_base_option.add_item(base)
	_base_option.select(0)
	properties_box.add_child(EventSheetPopupUI.form_row("Base class", _base_option))

	_category_edit = LineEdit.new()
	_category_edit.placeholder_text = "(defaults to the name)"
	properties_box.add_child(EventSheetPopupUI.form_row("Category", _category_edit))

	_desc_edit = LineEdit.new()
	_desc_edit.placeholder_text = "What this behaviour does (one line)."
	properties_box.add_child(EventSheetPopupUI.form_row("Description", _desc_edit))

	# "Preview" card — the suggested target path (muted hint) + an error line if the name clashes.
	var preview_box: VBoxContainer = EventSheetPopupUI.form_box()
	content.add_child(EventSheetPopupUI.titled_card("Preview", preview_box))

	# Muted, width-bounded path line (reuses the shared hint style; text is updated live).
	_path_label = EventSheetPopupUI.hint_label("")
	preview_box.add_child(_path_label)

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Width-bound so a long validation message can't balloon the content-sized dialog.
	_status_label.custom_minimum_size = Vector2(EventSheetPopupUI.HINT_WRAP_WIDTH, 0.0)
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.55))
	preview_box.add_child(_status_label)

	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(spacer)

	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 6)
	content.add_child(buttons)
	var cancel_button: Button = Button.new()
	cancel_button.text = "Cancel"
	cancel_button.pressed.connect(func() -> void: _dialog.hide())
	buttons.add_child(cancel_button)
	var create_button: Button = Button.new()
	create_button.text = "Create"
	create_button.pressed.connect(_on_create)
	buttons.add_child(create_button)

	_dialog.add_child(EventSheetPopupUI.margined(content))

func _refresh_preview() -> void:
	if _path_label == null:
		return
	var addon_name: String = _name_edit.text.strip_edges()
	if addon_name.is_empty():
		_path_label.text = "Will be created under res://eventsheet_addons/…"
	else:
		_path_label.text = "Will be created at: %s" % BehaviourAddonScaffold.suggested_path(addon_name)
	if _status_label != null:
		_status_label.text = ""

func _on_create() -> void:
	var addon_name: String = _name_edit.text.strip_edges()
	if not BehaviourAddonScaffold.is_valid_class_name(addon_name):
		_status_label.text = "\"%s\" isn't a usable class name — use letters/digits/underscore starting with a letter, and not a reserved or existing class name." % addon_name
		return
	var path: String = BehaviourAddonScaffold.suggested_path(addon_name)
	if FileAccess.file_exists(path):
		_status_label.text = "A file already exists at %s — pick another name." % path
		return
	var base: String = _base_option.get_item_text(_base_option.selected)
	var recipe_id: String = str((BehaviourAddonScaffold.RECIPES[maxi(_recipe_option.selected, 0)] as Dictionary).get("id"))
	var source: String = BehaviourAddonScaffold.generate_recipe(recipe_id, addon_name, base, _category_edit.text, _desc_edit.text)
	var folder: String = path.get_base_dir()
	if DirAccess.make_dir_recursive_absolute(folder) != OK and not DirAccess.dir_exists_absolute(folder):
		_status_label.text = "Couldn't create the folder %s — check permissions." % folder
		return
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_status_label.text = "Couldn't write %s — check folder permissions." % path
		return
	file.store_string(source)
	file.close()
	_dialog.hide()
	# Register the new file + its class_name, then rebuild the registry so its ACEs appear in the picker.
	if Engine.is_editor_hint():
		EditorInterface.get_resource_filesystem().scan()
	_dock._refresh_ace_registry()
	_dock._open_gdscript_path_in_godot(path)
	_dock._set_status("Created behaviour addon \"%s\" at %s — edit it, save, and its ACEs appear in the picker." % [addon_name, path])
