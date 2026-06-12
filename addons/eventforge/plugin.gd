# EventForge — Plugin entry point
# Registers the EventForge editor plugin and runtime bridge autoload.
@tool
extends EditorPlugin
class_name EventForgePlugin

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

## Returns the display name of the plugin.
func _get_plugin_name() -> String:
	return "EventSheet"

## EventSheet is exposed as a dedicated main editor workspace.
func _has_main_screen() -> bool:
	return true

## Returns the icon shown in the top editor workspace strip.
func _get_plugin_icon() -> Texture2D:
	return get_editor_interface().get_editor_theme().get_icon("Node", "EditorIcons")

## Controls visibility for the workspace surface when selected in top tabs.
func _make_visible(visible: bool) -> void:
	if _event_sheet_editor != null:
		_event_sheet_editor.visible = visible

## Checks whether the selected object can be edited by this plugin.
func _handles(object: Object) -> bool:
	return is_event_sheet_resource(object)

## Loads the selected EventSheet into the workspace editor.
func _edit(object: Object) -> void:
	if _event_sheet_editor == null:
		return
	if is_event_sheet_resource(object):
		_event_sheet_editor.call("setup", object as EventSheetResource)
		if _event_sheet_editor.has_method("get_exposed_node"):
			var exposed_node: Variant = _event_sheet_editor.call("get_exposed_node")
			if exposed_node is Object:
				get_editor_interface().inspect_object(exposed_node)

## Shared object guard used by plugin handlers and tests.
static func is_event_sheet_resource(object: Object) -> bool:
	return object is EventSheetResource

## Switches to the EventSheet workspace and loads a sheet (.tres or GDScript-backed
## .gd) — the landing point for every native entry (context menus, Inspector button).
func _open_sheet_in_workspace(path: String) -> void:
	if _event_sheet_editor == null or not _event_sheet_editor.has_method("_load_sheet_from_path"):
		return
	get_editor_interface().set_main_screen_editor(_get_plugin_name())
	_event_sheet_editor.call("_load_sheet_from_path", path)

## The script editor's "Go to Sheet Row": carries the caret line into the sheet's
## reverse provenance — errors and stack traces land on rows, not generated code.
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

## Registers plugin services when the plugin is enabled.
func _enter_tree() -> void:
	add_autoload_singleton(BRIDGE_NAME, BRIDGE_PATH)
	# Every eventsheets/* setting becomes visible + documented in Project Settings
	# (value-neutral: defaults match the in-code fallbacks).
	EventSheetSettings.register_all()
	# Native entry points: right-click a node → Attach Event Sheet; right-click a
	# sheet .tres / any .gd in the FileSystem or script editor → Open as Event Sheet.
	for slot: int in [EditorContextMenuPlugin.CONTEXT_SLOT_SCENE_TREE,
			EditorContextMenuPlugin.CONTEXT_SLOT_FILESYSTEM,
			EditorContextMenuPlugin.CONTEXT_SLOT_SCRIPT_EDITOR]:
		var menu: EventSheetContextMenu = EventSheetContextMenu.new()
		menu.slot = slot
		menu.open_sheet = _open_sheet_in_workspace
		menu.attach_sheet = _attach_sheet_to_node
		menu.goto_row = _goto_sheet_row_from_script
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
	# Tier 3 attribute drawers (progress bars…): purely cosmetic — generated scripts
	# degrade to plain fields without this plugin.
	_attribute_drawers_plugin = EventSheetAttributeDrawers.new()
	add_inspector_plugin(_attribute_drawers_plugin)
	var editor_script: Script = load(EVENT_SHEET_EDITOR_PATH)
	if editor_script == null:
		push_warning("[EventForge] Failed to load EventSheetEditor script at %s. Verify the file exists and contains valid GDScript." % EVENT_SHEET_EDITOR_PATH)
	elif not editor_script.can_instantiate():
		push_warning("[EventForge] EventSheetEditor script is not instantiable: %s" % EVENT_SHEET_EDITOR_PATH)
	else:
		var editor_candidate: Variant = editor_script.new()
		if editor_candidate == null:
			push_warning("[EventForge] EventSheetEditor script could not be instantiated: %s" % EVENT_SHEET_EDITOR_PATH)
		elif editor_candidate is Control:
			_event_sheet_editor = editor_candidate
			if _live_values_debugger != null and _event_sheet_editor.has_method("update_live_values"):
				_live_values_debugger.values_received.connect(_event_sheet_editor.update_live_values)
			if _live_values_debugger != null and _event_sheet_editor.has_method("set_live_values_debugger"):
				_event_sheet_editor.set_live_values_debugger(_live_values_debugger)
			_event_sheet_editor.name = MAIN_SCREEN_ROOT_NAME
			get_editor_interface().get_editor_main_screen().add_child(_event_sheet_editor)
			# Contract: EventSheetEditor can expose setup(sheet := null) for safe initial state.
			if _event_sheet_editor.has_method("setup"):
				_event_sheet_editor.call("setup")
			if _event_sheet_editor.has_method("set_undo_redo_manager"):
				_event_sheet_editor.call("set_undo_redo_manager", get_undo_redo())
			if _event_sheet_editor.has_method("get_editor_param_store"):
				var store: Variant = _event_sheet_editor.call("get_editor_param_store")
				if store is EditorParamStore:
					_ace_param_inspector_plugin = ACEParamInspectorPlugin.new()
					_ace_param_inspector_plugin.set_param_store(store as EditorParamStore)
					add_inspector_plugin(_ace_param_inspector_plugin)
			_make_visible(false)
		else:
			push_warning("[EventForge] EventSheetEditor script must extend Control: %s" % EVENT_SHEET_EDITOR_PATH)
			if editor_candidate is Node:
				(editor_candidate as Node).queue_free()
			# Non-Node objects here are RefCounted and released automatically.
	if _event_sheet_editor != null:
		print("[Godot EventSheets] plugin loaded")
	else:
		print("[Godot EventSheets] plugin loaded (editor panel unavailable)")
	_maybe_show_welcome()

# ── First-run welcome: the 60-second hook (per-project, via editor metadata —
# nothing committed; never shows headless) ─────────────────────────────────────────────
var _welcome_window: Window = null

func _maybe_show_welcome() -> void:
	if not Engine.is_editor_hint() or DisplayServer.get_name() == "headless":
		return
	var editor_settings: EditorSettings = get_editor_interface().get_editor_settings()
	if bool(editor_settings.get_project_metadata("eventsheets", "welcomed", false)):
		return
	editor_settings.set_project_metadata("eventsheets", "welcomed", true)
	_welcome_window = Window.new()
	_welcome_window.title = "Godot EventSheets — welcome"
	_welcome_window.size = Vector2i(440, 290)
	_welcome_window.close_requested.connect(func() -> void: _welcome_window.hide())
	var box: VBoxContainer = VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 8)
	var blurb: Label = Label.new()
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.text = "Construct 3-style event sheets that compile to plain GDScript — zero runtime, performance parity, and every sheet shows you its honest generated code."
	box.add_child(blurb)
	var showcase_button: Button = Button.new()
	showcase_button.text = "Open the playable showcase scene"
	showcase_button.pressed.connect(func() -> void:
		if FileAccess.file_exists("res://demo/showcase/showcase_v060.tscn"):
			get_editor_interface().open_scene_from_path("res://demo/showcase/showcase_v060.tscn")
		_welcome_window.hide())
	box.add_child(showcase_button)
	var workspace_button: Button = Button.new()
	workspace_button.text = "Open the EventSheet workspace (New… has starters)"
	workspace_button.pressed.connect(func() -> void:
		get_editor_interface().set_main_screen_editor(_get_plugin_name())
		_welcome_window.hide())
	box.add_child(workspace_button)
	var native_check: CheckBox = CheckBox.new()
	native_check.text = "I'm Godot-native: show the generated GDScript beside every sheet"
	native_check.toggled.connect(func(on: bool) -> void:
		ProjectSettings.set_setting("eventsheets/editor/open_code_panel_by_default", on if on else null))
	box.add_child(native_check)
	var docs_label: Label = Label.new()
	docs_label.text = "Coming from Construct? docs/C3-MIGRATION-GUIDE.md maps the vocabulary."
	docs_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	docs_label.add_theme_font_size_override("font_size", 11)
	box.add_child(docs_label)
	_welcome_window.add_child(box)
	get_editor_interface().get_base_control().add_child(_welcome_window)
	_welcome_window.popup_centered()

## Unregisters plugin services when the plugin is disabled.
func _exit_tree() -> void:
	if _welcome_window != null:
		_welcome_window.queue_free()
		_welcome_window = null
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
	if _event_sheet_editor != null:
		if _event_sheet_editor.get_parent() != null:
			_event_sheet_editor.get_parent().remove_child(_event_sheet_editor)
		_event_sheet_editor.queue_free()
		_event_sheet_editor = null
	remove_autoload_singleton(BRIDGE_NAME)
	print("[Godot EventSheets] unloaded")
