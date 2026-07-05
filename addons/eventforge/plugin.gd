# EventForge - Plugin entry point
# Registers the EventForge editor plugin and runtime bridge autoload.
@tool
class_name EventForgePlugin
extends EditorPlugin

const BRIDGE_NAME: String = "EventForgeBridge"
const BRIDGE_PATH: String = "res://addons/eventforge/runtime/eventforge_bridge.gd"
const EVENT_SHEET_EDITOR_PATH: String = "res://addons/eventforge/editor/event_sheet_editor.gd"
const MAIN_SCREEN_ROOT_NAME: String = "EventSheetWorkspace"

var _event_sheet_editor: Control = null
var _export_integrity_plugin: EditorExportPlugin = null
var _live_values_debugger: EventSheetLiveValuesDebugger = null
var _ace_param_inspector_plugin: ACEParamInspectorPlugin = null
var _attribute_drawers_plugin: EventSheetAttributeDrawers = null
var _sheet_edit_button_plugin: EventSheetEditButtonPlugin = null
var _context_menus: Array[EventSheetContextMenu] = []
var _new_sheet_dialog: EventSheetNewSheetDialog = null


## Returns the display name of the plugin.
func _get_plugin_name() -> String:
	return "EventSheet"


## EventSheet is exposed as a dedicated main editor workspace.
func _has_main_screen() -> bool:
	return true


## Returns the icon shown in the top editor workspace strip.
func _get_plugin_icon() -> Texture2D:
	return get_editor_interface().get_editor_theme().get_icon("Node", "EditorIcons")


## Controls visibility for the workspace surface when selected in top tabs. Selecting the tab is
## the primary lazy trigger: build the editor on first show, then reveal it.
func _make_visible(visible: bool) -> void:
	if visible:
		_ensure_editor()
	if _event_sheet_editor != null:
		_event_sheet_editor.visible = visible


## Checks whether the selected object can be edited by this plugin.
func _handles(object: Object) -> bool:
	if is_event_sheet_resource(object):
		return true
	# Auto-preview toggle (OFF by default): when on, selecting a sheet-liftable .gd routes here so it
	# opens as a read-only EVENTS preview instead of the script editor. Limited to liftable game scripts.
	return _auto_preview_gd_enabled() and object is Script and EventSheetWorkflow.is_openable_as_sheet((object as Script).resource_path)


## Loads the selected EventSheet (or, with the toggle on, a .gd) into the workspace editor.
func _edit(object: Object) -> void:
	# Selecting a sheet resource can precede the user ever opening the workspace tab - build on demand.
	_ensure_editor()
	if _event_sheet_editor == null:
		return
	if is_event_sheet_resource(object):
		_event_sheet_editor.call("setup", object as EventSheetResource)
		if _event_sheet_editor.has_method("get_exposed_node"):
			var exposed_node: Variant = _event_sheet_editor.call("get_exposed_node")
			if exposed_node is Object:
				get_editor_interface().inspect_object(exposed_node)
	elif object is Script:
		# Auto-preview path: open the selected script's file as a read-only events preview.
		_open_sheet_in_workspace((object as Script).resource_path)


## True when the "auto-preview a selected .gd as events" project setting is enabled.
static func _auto_preview_gd_enabled() -> bool:
	return bool(ProjectSettings.get_setting("eventsheets/editor/auto_preview_gd_on_select", false))


## Shared object guard used by plugin handlers and tests.
static func is_event_sheet_resource(object: Object) -> bool:
	return object is EventSheetResource


## Switches to the EventSheet workspace and loads a sheet (.tres or GDScript-backed
## .gd) - the landing point for every native entry (context menus, Inspector button).
func _open_sheet_in_workspace(path: String) -> void:
	# Context menus / Inspector button / Attach can fire before the workspace was ever opened;
	# force-build the editor first (set_main_screen_editor only flips visibility, it never builds).
	_ensure_editor()
	if _event_sheet_editor == null or not _event_sheet_editor.has_method("_load_sheet_from_path"):
		return
	get_editor_interface().set_main_screen_editor(_get_plugin_name())
	_event_sheet_editor.call("_load_sheet_from_path", path)


## The script editor's "Go to Sheet Row": carries the caret line into the sheet's
## reverse provenance - errors and stack traces land on rows, not generated code.
func _goto_sheet_row_from_script(script_path: String) -> void:
	var sheet_path: String = EventSheetProjectDoctor.sheet_for_script(script_path)
	if sheet_path.is_empty():
		return
	var line: int = 0
	var current_editor: ScriptEditorBase = get_editor_interface().get_script_editor().get_current_editor()
	if current_editor != null and current_editor.get_base_editor() is CodeEdit:
		line = (current_editor.get_base_editor() as CodeEdit).get_caret_line() + 1
	_open_sheet_in_workspace(sheet_path)
	if _event_sheet_editor != null and _event_sheet_editor.has_method("goto_generated_line"):
		_event_sheet_editor.call("goto_generated_line", line)


## The Scene dock's "Attach Event Sheet": create beside the scene, compile, attach,
## then drop the user straight into the sheet.
func _attach_sheet_to_node(node: Node) -> void:
	var scene_root: Node = get_editor_interface().get_edited_scene_root()
	var directory: String = "res://"
	if scene_root != null and not scene_root.scene_file_path.is_empty():
		directory = scene_root.scene_file_path.get_base_dir()
	var result: Dictionary = EventSheetWorkflow.create_sheet_for_node(node, directory)
	if bool(result.get("ok", false)):
		get_editor_interface().mark_scene_as_unsaved()
		get_editor_interface().get_resource_filesystem().scan()
		_open_sheet_in_workspace(str(result.get("sheet_path")))
	else:
		push_warning("[Godot EventSheets] %s" % str(result.get("message")))


## The FileSystem "Create New > Event Sheet..." entry: pop the name + starter dialog for the
## clicked folder. The dialog is parented to the editor's base control (always present), so it
## works even before the workspace editor has ever been built.
func _create_sheet_in_directory(directory: String) -> void:
	# Built once and reused (the standard reusable-dialog pattern) - the plugin holds the strong
	# reference so the window is never freed out from under its connections. It carries the target
	# folder in its create_requested signal, so one connection serves every folder.
	if _new_sheet_dialog == null:
		_new_sheet_dialog = EventSheetNewSheetDialog.new()
		_new_sheet_dialog.init_dialog(get_editor_interface().get_base_control())
		_new_sheet_dialog.create_requested.connect(_finish_create_sheet)
	_new_sheet_dialog.open(directory)


## Writes the chosen starter to a fresh .gd in the target folder, indexes it, and opens it EDITABLE
## in the workspace (not the read-only preview a casual .gd Open gives - the user just authored it).
func _finish_create_sheet(directory: String, sheet_name: String, starter_id: int) -> void:
	var sheet: EventSheetResource = EventSheetStarterTemplates.build_starter(starter_id)
	var result: Dictionary = EventSheetWorkflow.write_sheet_file(sheet, directory, sheet_name)
	if not bool(result.get("ok", false)):
		push_warning("[Godot EventSheets] %s" % str(result.get("message")))
		return
	var sheet_path: String = str(result.get("sheet_path"))
	# Index the just-written file so it appears in the FileSystem dock, then build + reveal the
	# workspace and open the new sheet editable.
	get_editor_interface().get_resource_filesystem().scan()
	_ensure_editor()
	if _event_sheet_editor == null or not _event_sheet_editor.has_method("open_new_sheet"):
		return
	get_editor_interface().set_main_screen_editor(_get_plugin_name())
	_event_sheet_editor.call("open_new_sheet", sheet_path)


## The newest showcase scene under demo/showcase (review catch: hardcoding the
## versioned filename meant every showcase refresh had to edit the plugin).
static func _find_showcase_scene() -> String:
	var dir: DirAccess = DirAccess.open("res://demo/showcase")
	if dir == null:
		return ""
	var newest: String = ""
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while not entry.is_empty():
		if entry.begins_with("showcase_") and entry.ends_with(".tscn") and entry > newest:
			newest = entry
		entry = dir.get_next()
	dir.list_dir_end()
	return "res://demo/showcase/%s" % newest if not newest.is_empty() else ""


## Registers plugin services when the plugin is enabled.
func _enter_tree() -> void:
	add_autoload_singleton(BRIDGE_NAME, BRIDGE_PATH)
	# Every eventsheets/* setting becomes visible + documented in Project Settings
	# (value-neutral: defaults match the in-code fallbacks).
	EventSheetSettings.register_all()
	# Native entry points: right-click a node → Attach Event Sheet; right-click a
	# sheet .tres / any .gd in the FileSystem or script editor → Open as Event Sheet;
	# FileSystem "Create New >" submenu → Event Sheet... (a fresh sheet in that folder).
	for slot: int in [EditorContextMenuPlugin.CONTEXT_SLOT_SCENE_TREE,
			EditorContextMenuPlugin.CONTEXT_SLOT_FILESYSTEM,
			EditorContextMenuPlugin.CONTEXT_SLOT_FILESYSTEM_CREATE,
			EditorContextMenuPlugin.CONTEXT_SLOT_SCRIPT_EDITOR]:
		var menu: EventSheetContextMenu = EventSheetContextMenu.new()
		menu.slot = slot
		menu.open_sheet = _open_sheet_in_workspace
		menu.attach_sheet = _attach_sheet_to_node
		menu.goto_row = _goto_sheet_row_from_script
		menu.create_sheet = _create_sheet_in_directory
		add_context_menu_plugin(slot, menu)
		_context_menus.append(menu)
	# Inspector: nodes whose script is sheet-generated get an "Edit Event Sheet" button.
	_sheet_edit_button_plugin = EventSheetEditButtonPlugin.new()
	_sheet_edit_button_plugin.open_sheet = _open_sheet_in_workspace
	add_inspector_plugin(_sheet_edit_button_plugin)
	# Export integrity: recompile every sheet when an export starts so stale generated
	# scripts can never ship (see export_integrity_plugin.gd).
	_export_integrity_plugin = EventSheetExportIntegrityPlugin.new()
	add_export_plugin(_export_integrity_plugin)
	# Live Values (debugging rung 2): capture the values frames debug-compiled sheets
	# stream, and feed them to the workspace editor's Live Values window.
	_live_values_debugger = EventSheetLiveValuesDebugger.new()
	add_debugger_plugin(_live_values_debugger)
	# Tier 3 attribute drawers (progress bars…): purely cosmetic - generated scripts
	# degrade to plain fields without this plugin.
	_attribute_drawers_plugin = EventSheetAttributeDrawers.new()
	add_inspector_plugin(_attribute_drawers_plugin)
	# The workspace editor (the ~3400-line dock, its ~45 delegates, every dialog, and the addon-folder
	# vocabulary scans) is built LAZILY on first use - see _ensure_editor. Enabling the plugin, or
	# opening a project that never touches event sheets, pays none of it. The top-strip tab still
	# appears immediately (driven by _has_main_screen / _get_plugin_name, which don't need the editor).
	print("[Godot EventSheets] plugin loaded")


## Builds the workspace editor on demand (idempotent). Everything heavy is deferred here so plugin
## enable stays cheap; called from _make_visible(true) and every native entry point before it needs
## the editor. _event_sheet_editor is assigned ONLY after a fully successful build, so a failure
## leaves it null for a clean retry (never a half-registered inspector plugin or double-connected
## signal). The first-run welcome now pops on first workspace open rather than at editor boot.
func _ensure_editor() -> void:
	if _event_sheet_editor != null:
		return
	var editor_script: Script = load(EVENT_SHEET_EDITOR_PATH)
	if editor_script == null:
		push_warning("[EventForge] Failed to load EventSheetEditor script at %s. Verify the file exists and contains valid GDScript." % EVENT_SHEET_EDITOR_PATH)
		return
	if not editor_script.can_instantiate():
		push_warning("[EventForge] EventSheetEditor script is not instantiable: %s" % EVENT_SHEET_EDITOR_PATH)
		return
	var editor_candidate: Variant = editor_script.new()
	if editor_candidate == null:
		push_warning("[EventForge] EventSheetEditor script could not be instantiated: %s" % EVENT_SHEET_EDITOR_PATH)
		return
	if not (editor_candidate is Control):
		push_warning("[EventForge] EventSheetEditor script must extend Control: %s" % EVENT_SHEET_EDITOR_PATH)
		if editor_candidate is Node:
			(editor_candidate as Node).queue_free()
		# Non-Node objects here are RefCounted and released automatically.
		return
	var editor: Control = editor_candidate as Control
	# The Live Values debugger itself is registered eagerly in _enter_tree (transport stays live even
	# before the workspace opens); only these editor-facing sinks defer until the editor exists.
	if _live_values_debugger != null and editor.has_method("update_live_values"):
		_live_values_debugger.values_received.connect(editor.update_live_values)
	if _live_values_debugger != null and editor.has_method("update_fired_events"):
		_live_values_debugger.fired_events_received.connect(editor.update_fired_events)
	if _live_values_debugger != null and editor.has_method("reveal_paused_row"):
		_live_values_debugger.paused_row_received.connect(editor.reveal_paused_row)
	if _live_values_debugger != null and editor.has_method("set_live_values_debugger"):
		editor.set_live_values_debugger(_live_values_debugger)
	editor.name = MAIN_SCREEN_ROOT_NAME
	get_editor_interface().get_editor_main_screen().add_child(editor)
	# A main-screen Control defaults to visible and Godot never auto-hides unselected ones, so it
	# must start hidden - otherwise the _edit-first path (selecting a sheet .tres before ever opening
	# the tab) would overlay it on the active screen. The reveal happens via _make_visible(true) when
	# the workspace tab is actually selected (directly, or through set_main_screen_editor).
	editor.visible = false
	# Contract: EventSheetEditor can expose setup(sheet := null) for safe initial state.
	if editor.has_method("setup"):
		editor.call("setup")
	if editor.has_method("set_undo_redo_manager"):
		editor.call("set_undo_redo_manager", get_undo_redo())
	if editor.has_method("get_editor_param_store"):
		var store: Variant = editor.call("get_editor_param_store")
		if store is EditorParamStore:
			_ace_param_inspector_plugin = ACEParamInspectorPlugin.new()
			_ace_param_inspector_plugin.set_param_store(store as EditorParamStore)
			add_inspector_plugin(_ace_param_inspector_plugin)
	# Commit only after the whole build succeeds - see the docstring's clean-retry contract.
	_event_sheet_editor = editor
	_maybe_show_welcome()


# ── First-run welcome: the 60-second hook. The window lives on the dock (it owns
# every other window, fixes the unmargined first cut, and Tools → Welcome… can
# reopen it any time); the plugin only triggers the first-run check.
func _maybe_show_welcome() -> void:
	if _event_sheet_editor != null and _event_sheet_editor.has_method("show_welcome_if_first_run"):
		_event_sheet_editor.call("show_welcome_if_first_run")


## Unregisters plugin services when the plugin is disabled.
func _exit_tree() -> void:
	for menu: EventSheetContextMenu in _context_menus:
		remove_context_menu_plugin(menu)
	_context_menus.clear()
	if _sheet_edit_button_plugin != null:
		remove_inspector_plugin(_sheet_edit_button_plugin)
		_sheet_edit_button_plugin = null
	if _export_integrity_plugin != null:
		remove_export_plugin(_export_integrity_plugin)
		_export_integrity_plugin = null
	if _live_values_debugger != null:
		remove_debugger_plugin(_live_values_debugger)
		_live_values_debugger = null
	if _attribute_drawers_plugin != null:
		remove_inspector_plugin(_attribute_drawers_plugin)
		_attribute_drawers_plugin = null
	if _ace_param_inspector_plugin != null:
		remove_inspector_plugin(_ace_param_inspector_plugin)
		_ace_param_inspector_plugin = null
	if _new_sheet_dialog != null:
		_new_sheet_dialog.free_dialog()
		_new_sheet_dialog = null
	if _event_sheet_editor != null:
		if _event_sheet_editor.get_parent() != null:
			_event_sheet_editor.get_parent().remove_child(_event_sheet_editor)
		_event_sheet_editor.queue_free()
		_event_sheet_editor = null
	remove_autoload_singleton(BRIDGE_NAME)
	print("[Godot EventSheets] unloaded")
