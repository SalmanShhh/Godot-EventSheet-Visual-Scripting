@tool
class_name EventSheetProjectBarGlue
extends RefCounted

# T13 - what the Project bar MEANS. The bar itself is shell and gestures (it lists the project by
# kind and says what happened); this decides where each gesture goes, and every destination is
# something that already exists:
#
#   a scene       -> Godot's own 2D/3D editor, with the scene-as-sheet offered beside it
#   a script      -> a sheet tab, or Godot's script editor, per the reader's default
#   a class       -> Object properties (the same dialog the Object bar opens)
#   a behavior    -> that pack's reference page in the Manual
#   New scene / New script / New class / Extract base class / Import sound -> Godot's dialogs and
#                    the plugin's existing ones, never a second way to do the same thing
#
# WHEN THE BAR SHOWS. Off by default. A project gets it automatically when Simple mode is on or when
# it was started from a template / the "coming from another event-sheet editor" preset; View ▸
# Project bar turns it on or off by hand and ✕ hides it, and that choice is remembered per project.

const _META_KEY: String = "eventsheets_project_bar_shown"
## Set when a sheet is made from a template or the reader takes the migration path - the two ways a
## project says "I want the familiar surfaces" without being asked.
const STARTED_FROM_TEMPLATE_KEY: String = "eventsheets_started_from_template"

var _dock: Control = null
var _bar: EventSheetProjectBar = null


func init(dock: Control) -> void:
	_dock = dock


## The bar itself, once it exists. Null until something asks for it - the panel is built on first
## show, so a project that never turns it on never pays for it.
func bar() -> EventSheetProjectBar:
	return _bar


## Whether this project should have the Project bar, resolved the way the item describes: an explicit
## choice wins, and with no choice on record Simple mode or a template start turns it on.
static func should_show(explicit: Variant, simple_mode: bool, started_from_template: bool) -> bool:
	if explicit is bool:
		return explicit
	return simple_mode or started_from_template


## Applies the rule above to the live project, building or dropping the tab to match. Called on dock
## setup, on the View toggle, and whenever Simple mode flips.
func apply_visibility() -> void:
	if _dock._objects_panel == null:
		return
	var wanted: bool = should_show(_stored_choice(), _dock.is_simple_mode(), _started_from_template())
	if wanted and _bar == null:
		_build()
	elif not wanted and _bar != null:
		_dock._objects_panel.set_project_bar(null)
		_bar.queue_free()
		_bar = null
	_sync_view_menu(wanted)


## View ▸ Project bar, and the bar's own ✕ (which lands here with `shown` false).
func set_shown(shown: bool) -> void:
	_write_choice(shown)
	apply_visibility()
	_dock._set_status("Project bar on - the project by kind, in the Object bar." if shown
		else "Project bar hidden. View ▸ Project bar brings it back.")


## Marks this project as one that started from a template or from the migration path, which is what
## turns the bar on for a reader who never asked for it by name.
static func mark_started_from_template() -> void:
	var settings: Object = _editor_settings()
	if settings != null:
		settings.call("set_project_metadata", "eventsheets", STARTED_FROM_TEMPLATE_KEY, true)


## The filesystem_changed ping the rest of the plugin already listens to. The bar keeps no watcher of
## its own; it simply asks again, and only when it is actually open.
func on_filesystem_changed() -> void:
	if _bar != null and _bar.is_expanded():
		_bar.set_coverage(_coverage_of_open_sheets())
		_bar.refresh()


## Pushes the reader's word choice down whenever it changes (Familiar Words, and where a
## double-clicked script opens).
func refresh_reading_prefs() -> void:
	if _bar != null:
		_bar.set_reading_prefs(_dock._familiar_words_enabled(), _script_opens_as_sheet())


func _build() -> void:
	_bar = EventSheetProjectBar.new()
	_bar.entry_activated.connect(_on_entry_activated)
	_bar.create_requested.connect(_on_create_requested)
	_bar.close_requested.connect(func() -> void: set_shown(false))
	_bar.set_coverage(_coverage_of_open_sheets())
	_bar.set_reading_prefs(_dock._familiar_words_enabled(), _script_opens_as_sheet())
	_dock._objects_panel.set_project_bar(_bar)


## Where a double-click goes. Every branch hands the work to something that already exists.
func _on_entry_activated(route: String, entry: Dictionary) -> void:
	var path: String = str(entry.get("path", ""))
	match route:
		"scene_editor":
			_open_scene(path)
		"sheet":
			_dock._navigate.record_current()
			_dock._navigate.open_or_focus(path)
		"script_editor":
			_dock._open_gdscript_path_in_godot(path)
		"object_properties":
			_dock.open_object_properties(str(entry.get("label", "")))
		"pack_reference":
			_dock.open_documentation(str(entry.get("note", "")))
		_:
			_reveal_in_filesystem(path)


## A scene opens where a scene belongs - Godot's own 2D/3D editor - and the sheet says the other
## thing it can be, because reading a whole layout as one sheet is exactly what a reader coming from
## another event-sheet editor expects a layout to do.
func _open_scene(scene_path: String) -> void:
	if Engine.is_editor_hint() and Engine.has_singleton("EditorInterface"):
		var editor_interface: Object = Engine.get_singleton("EditorInterface")
		if editor_interface.has_method("open_scene_from_path"):
			editor_interface.call("open_scene_from_path", scene_path)
	_dock._set_status("Opened %s in the scene editor. Sheet ▸ Open… the same file to read the whole layout as one sheet."
		% scene_path.get_file())


func _reveal_in_filesystem(path: String) -> void:
	if Engine.is_editor_hint() and Engine.has_singleton("EditorInterface"):
		var editor_interface: Object = Engine.get_singleton("EditorInterface")
		if editor_interface.has_method("select_file"):
			editor_interface.call("select_file", path)
	_dock._set_status("%s - shown in the FileSystem dock." % path.get_file())


## Right-click. Not one of these makes a file here: each opens the dialog that already does.
func _on_create_requested(what: String) -> void:
	match what:
		"new_scene":
			_open_godot_create_dialog("Scene", "Scene ▸ New Scene makes a layout - the sheet does not make one for you.")
		"new_script":
			_dock._open_template_menu()
		"new_class":
			_dock._open_template_menu()
		"extract_base_class":
			_dock._set_status("Extract base class lives on the class itself - open Object properties and use its refactor entry.")
		"import_sound":
			_open_godot_create_dialog("Sound", "Drop an audio file into the FileSystem dock and Godot imports it - nothing to do here.")


func _open_godot_create_dialog(_what: String, note: String) -> void:
	_dock._set_status(note)


## The coverage line the bar shows on a script entry, for the sheets the reader has OPEN. Measuring
## the rest would mean loading every .gd in the project, which is the cost this bar promised not to
## have.
func _coverage_of_open_sheets() -> Dictionary:
	var coverage: Dictionary = {}
	for tab: Variant in _dock.get_open_sheets_state().get("open", []):
		var path: String = str((tab as Dictionary).get("path", ""))
		if path.is_empty() or path.get_extension() != "gd":
			continue
		if _dock._current_sheet != null and _dock._current_sheet_path == path:
			coverage[path] = EventSheetReadingCoverage.chip_text(_dock._current_sheet)
	return coverage


## Where a double-clicked script goes - the reader's own default, remembered per project. A sheet is
## the default because a sheet is what this plugin is for; a reader who prefers the code sets it once.
const SCRIPT_OPENS_AS_KEY: String = "eventsheets_script_opens_as"


func _script_opens_as_sheet() -> bool:
	var settings: Object = _editor_settings()
	if settings == null:
		return true
	return str(settings.call("get_project_metadata", "eventsheets", SCRIPT_OPENS_AS_KEY, "sheet")) == "sheet"


func _sync_view_menu(shown: bool) -> void:
	if _dock._view_popup == null:
		return
	var index: int = _dock._view_popup.get_item_index(_dock.PROJECT_BAR_VIEW_ID)
	if index >= 0:
		_dock._view_popup.set_item_checked(index, shown)


func _stored_choice() -> Variant:
	var settings: Object = _editor_settings()
	if settings == null:
		return null
	var stored: Variant = settings.call("get_project_metadata", "eventsheets", _META_KEY, null)
	return stored if stored is bool else null


func _write_choice(shown: bool) -> void:
	var settings: Object = _editor_settings()
	if settings != null:
		settings.call("set_project_metadata", "eventsheets", _META_KEY, shown)


func _started_from_template() -> bool:
	var settings: Object = _editor_settings()
	if settings == null:
		return false
	return bool(settings.call("get_project_metadata", "eventsheets", STARTED_FROM_TEMPLATE_KEY, false))


static func _editor_settings() -> Object:
	if not Engine.is_editor_hint() or not Engine.has_singleton("EditorInterface"):
		return null
	var editor_interface: Object = Engine.get_singleton("EditorInterface")
	if editor_interface == null or not editor_interface.has_method("get_editor_settings"):
		return null
	return editor_interface.call("get_editor_settings")
