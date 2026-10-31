# EventForge - Plugin entry point
# Registers the EventForge editor plugin and runtime bridge autoload.
@tool
class_name EventForgePlugin
extends EditorPlugin

const BRIDGE_NAME: String = "EventForgeBridge"
const BRIDGE_PATH: String = "res://addons/eventforge/runtime/eventforge_bridge.gd"
const EVENT_SHEET_EDITOR_PATH: String = "res://addons/eventforge/editor/event_sheet_editor.gd"
const MAIN_SCREEN_ROOT_NAME: String = "EventSheetWorkspace"
const PLUGIN_ICON_PATH: String = "res://addons/eventsheet/icons/eventsheet.svg"
## The one ink the plugin icon is drawn in: the light grey Godot draws its own plain icons in on the
## dark theme. At load it is swapped for the editor's own icon colour, so the icon turns dark grey on
## a light theme the way its neighbours do.
const PLUGIN_ICON_INK: String = "#E0E0E0"
## A plain one-ink editor icon, read for the colour the editor draws such icons in right now.
const EDITOR_INK_SAMPLE_ICON: String = "Node"
const SETTINGS_HOVER_PATH: String = "res://addons/eventforge/editor/settings_hover_plugin.gd"

# Cold-path helpers load BY PATH, not by class name: naming a global class in any function body
# (or a var type) makes its whole dependency subtree - the importer, the compiler, the registry -
# compile the moment THIS script loads, i.e. at every editor boot. load() at the call site defers
# each subtree to its first actual use and caches it from then on, so enabling the plugin (and
# opening any project that has it installed) stays near-instant.
const WORKFLOW_PATH: String = "res://addons/eventforge/editor/workflow_entry_points.gd"
const PROJECT_DOCTOR_PATH: String = "res://addons/eventforge/project_doctor.gd"
const STARTER_TEMPLATES_PATH: String = "res://addons/eventsheet/editor/dock/starter_templates.gd"
const NEW_SHEET_DIALOG_PATH: String = "res://addons/eventsheet/editor/new_sheet_dialog.gd"
const CONNECT_SIGNAL_DIALOG_PATH: String = "res://addons/eventsheet/editor/connect_signal_dialog.gd"
const ACE_PARAM_INSPECTOR_PATH: String = "res://addons/eventsheet/editor/inspector/ace_param_inspector_plugin.gd"
const FUNCTION_FIELDS_INSPECTOR_PATH: String = "res://addons/eventsheet/editor/inspector/function_inspector_plugin.gd"
const SHAPE_LINK_INSPECTOR_PATH: String = "res://addons/eventsheet/editor/inspector/shape_link_inspector_plugin.gd"
const INSTANCE_VARIABLES_INSPECTOR_PATH: String = "res://addons/eventforge/editor/instance_variables_inspector_plugin.gd"
const DRAWING_PREFAB_INSPECTOR_PATH: String = "res://addons/eventsheet/editor/inspector/drawing_prefab_inspector_plugin.gd"
const DRAWING_PREFAB_PREVIEW_GEN_PATH: String = "res://addons/eventsheet/editor/inspector/drawing_prefab_preview_generator.gd"
const INSPECTOR_HANDLES_PATH: String = "res://addons/eventsheet/editor/inspector/handle_plugin.gd"
const FEEDBACK_PLAYER_INSPECTOR_PATH: String = "res://addons/eventsheet/editor/inspector/feedback_player_inspector_plugin.gd"
const FEEDBACK_CARD_SCHEMA_PATH: String = "res://addons/eventsheet/editor/inspector/feedback_card_schema.gd"
## The name the Feedback Player's export marker asks its card vocabulary for. Spelled here as a
## literal rather than read off the schema file: naming that class would compile it, and the ACE
## reflection behind it, into every editor boot to register one callable.
const FEEDBACK_CARD_SCHEMA_NAME: String = "feedback_steps"
## The parameter HINT the Feedback Player's step parameters carry, the field that answers it, and
## the paragraph the params dialog's help strip says about that field. The paragraph is spelled here
## rather than on the field so registering it costs no load at boot - the field is only fetched the
## first time a row with a step in it is opened.
const FEEDBACK_STEP_HINT: String = "feedback_step"
## The three extension registries, reached BY PATH. The public `EventSheets` API writes to the same
## dictionaries, but naming that class here would compile the compiler, the importer, the Doctor and
## the viewport into every editor start - which is what it did, turning a ~330 ms boot closure into
## ~19,000 ms. The store names nothing, so registering through it costs a parse of a few lines.
const EXTENSION_REGISTRIES_PATH: String = "res://addons/eventsheet/api/extension_registries.gd"
const FEEDBACK_STEP_FIELD_PATH: String = "res://addons/eventsheet/editor/inspector/feedback_step_field.gd"
const FEEDBACK_STEP_HELP: String = "The feedback itself. Press Card to fill it in as the card the Feedback Player's list unfolds in the Inspector - the same kinds, the same fields, the same keys. The box holds what the row will emit, so an expression can be typed straight into it instead."
const DRAWING_CANVAS_GIZMO_PATH: String = "res://addons/eventsheet/editor/drawing_canvas_gizmo.gd"
const DRAWING_PREFAB_GIZMO_PATH: String = "res://addons/eventsheet/editor/drawing_prefab_gizmo.gd"
const DRAWING_PREFAB_3D_GIZMO_PATH: String = "res://addons/eventsheet/editor/drawing_prefab_3d_gizmo.gd"
const BEHAVIOR_GIZMOS_PATH: String = "res://addons/eventsheet/editor/behavior_gizmos.gd"
const SCENE_EVENTS_OVERLAY_PATH: String = "res://addons/eventsheet/editor/scene_events_overlay.gd"
const EXPORT_TOOLS_PLUGIN_PATH: String = "res://addons/eventforge/editor/export_tools_plugin.gd"
const IMPORT_TOOLS_PLUGIN_PATH: String = "res://addons/eventforge/editor/import_tools_plugin.gd"
const DOC_DOCK_PATH: String = "res://addons/eventsheet/editor/docs/doc_dock.gd"

var _event_sheet_editor: Control = null
var _export_integrity_plugin: EditorExportPlugin = null
# The On Project Export bake step. Loaded by path (it has no class_name on purpose, so registering it
# never widens the boot compile) and typed as the engine base class.
var _export_tools_plugin: EditorExportPlugin = null
# The On File Imported hook. Same reasoning as the bake step above: loaded by path, no class_name, so
# registering it never widens the boot compile. Typed as Object because it is a plain RefCounted that
# only listens to the editor's reimport signal.
var _import_tools_plugin: Object = null
var _live_values_debugger: EventSheetLiveValuesDebugger = null
# Typed loosely on purpose (see the path consts above): their concrete class names must not
# appear in this file, or their subtrees join the boot compile.
var _ace_param_inspector_plugin: EditorInspectorPlugin = null
var _function_fields_plugin: EditorInspectorPlugin = null
# The "Shape <Class>…" link at the top of the Inspector, registered once the workspace is built.
var _shape_link_plugin: EditorInspectorPlugin = null
var _attribute_drawers_plugin: EventSheetAttributeDrawers = null
# Loosely typed on purpose (boot-lazy): loaded by path in _enter_tree so their subtrees stay off the boot compile.
var _drawing_prefab_inspector: EditorInspectorPlugin = null
var _drawing_prefab_preview_gen: EditorResourcePreviewGenerator = null
var _feedback_player_inspector: EditorInspectorPlugin = null
# Viewport handles for any script whose decor declares them (loaded by path). It draws and drags in
# the 2D viewport through this plugin's canvas forwarding, and in 3D through a gizmo plugin of its own.
var _inspector_handles: RefCounted = null
# Selection-driven 2D gizmo: previews a selected DrawingCanvas's preview_prefab at the host (loaded by path).
var _drawing_canvas_gizmo: RefCounted = null
# Selection-driven prefab gizmos: preview a referenced DrawingPrefabResource in the 2D / 3D viewport (loaded by path).
var _drawing_prefab_gizmo: RefCounted = null
var _drawing_prefab_3d_gizmo: RefCounted = null
# Selection-driven behavior gizmos: a selected node's behaviors draw their editor_gizmo_draw overlays (loaded by path).
var _behavior_gizmos: RefCounted = null
## The events overlay (Scene dock + 2D editor badges). Inert until the setting turns it on.
var _scene_events_overlay: RefCounted = null
var _sheet_edit_button_plugin: EventSheetEditButtonPlugin = null
# The Inspector's "Instance variables" band. add_inspector_plugin takes an INSTANCE, so this is
# constructed at every boot - which is why it is loaded BY PATH and carries no class name here.
var _instance_variables_inspector: EditorInspectorPlugin = null
# The Project Settings hover for the plugin's own settings (loaded by path, no class_name).
var _settings_hover_plugin: EditorInspectorPlugin = null
# The plugin icon in the editor's own ink, and that ink: made again when the editor's ink changes (a
# switch between a dark and a light editor theme, which Godot makes without a restart).
var _plugin_icon: Texture2D = null
var _plugin_icon_ink: Color = Color(0.0, 0.0, 0.0, 0.0)
var _context_menus: Array[EventSheetContextMenu] = []
var _new_sheet_dialog: RefCounted = null
var _connect_signal_dialog: RefCounted = null
# The docked documentation surface. add_dock takes an INSTANCE, so this node is constructed at every
# boot - which is why it is loaded BY PATH (its class name must not appear here) and why it builds
# nothing but itself until the reader first opens it.
var _doc_dock: EditorDock = null


## Returns the display name of the plugin.
func _get_plugin_name() -> String:
	return "EventSheet"


## EventSheet is exposed as a dedicated main editor workspace.
func _has_main_screen() -> bool:
	return true


## Returns the icon shown in the top editor workspace strip: one event (a frame cut in two, a
## trigger arrow on the condition side, two action bars on the other) drawn in one ink like the 2D,
## 3D and Script buttons beside it. The svg is read as text and its ink swapped for the editor's own
## icon colour before it is rasterised, because Godot recolours its own icons for a light theme but
## not a plugin's. Falls back to the imported texture, then to the Node icon.
##
## The very first time a project opens with the plugin in it, the editor asks for this icon before its
## first import has reached the svg, and a load() then printed "Failed loading resource" into the
## Output panel. Asking whether the imported texture exists first makes that one boot use the fallback.
##
## The editor asks again for every main-screen icon when its theme changes, so the icon is inked again
## whenever the editor's ink is not the one it was made in.
func _get_plugin_icon() -> Texture2D:
	var ink: Color = editor_icon_ink(get_editor_interface().get_editor_theme())
	if icon_needs_inking(_plugin_icon, _plugin_icon_ink, ink):
		_plugin_icon_ink = ink
		_plugin_icon = inked_svg_texture(FileAccess.get_file_as_string(PLUGIN_ICON_PATH),
				ink, get_editor_interface().get_editor_scale())
	if _plugin_icon != null:
		return _plugin_icon
	if ResourceLoader.exists(PLUGIN_ICON_PATH):
		var icon: Resource = load(PLUGIN_ICON_PATH)
		if icon is Texture2D:
			return icon
	return get_editor_interface().get_editor_theme().get_icon("Node", "EditorIcons")


## True when the icon has to be made (again): there is none yet, or it was inked in another colour
## than the editor draws its icons in now.
static func icon_needs_inking(icon: Texture2D, made_in: Color, ink: Color) -> bool:
	return icon == null or not made_in.is_equal_approx(ink)


## The svg text with the plugin icon's ink swapped for `ink` (either spelling of the hex).
static func inked_svg(svg_text: String, ink: Color) -> String:
	var hex: String = "#" + ink.to_html(false).to_upper()
	return svg_text.replace(PLUGIN_ICON_INK, hex).replace(PLUGIN_ICON_INK.to_lower(), hex)


## The plugin svg rasterised in `ink` at `scale`, or null when the text is not a drawable svg.
static func inked_svg_texture(svg_text: String, ink: Color, scale: float) -> Texture2D:
	if svg_text.is_empty():
		return null
	var image: Image = Image.new()
	if image.load_svg_from_string(inked_svg(svg_text, ink), maxf(scale, 0.25)) != OK:
		return null
	return ImageTexture.create_from_image(image)


## Reimports the plugin svg when its imported texture is not in the editor's icon ink (the editor
## theme changed between dark and light since it was imported). Waits for the first scan to finish,
## because a reimport asked for during a scan is dropped. One 16 px read per editor start otherwise.
func _refresh_plugin_icon_import() -> void:
	var file_system: EditorFileSystem = get_editor_interface().get_resource_filesystem()
	if file_system == null or not ResourceLoader.exists(PLUGIN_ICON_PATH):
		return
	if file_system.is_scanning():
		if not file_system.filesystem_changed.is_connected(_refresh_plugin_icon_import):
			file_system.filesystem_changed.connect(_refresh_plugin_icon_import, CONNECT_ONE_SHOT)
		return
	var imported: Texture2D = load(PLUGIN_ICON_PATH) as Texture2D
	if imported != null and not is_in_ink(imported, editor_icon_ink(get_editor_interface().get_editor_theme())):
		file_system.reimport_files(PackedStringArray([PLUGIN_ICON_PATH]))


func _on_editor_theme_changed() -> void:
	_refresh_plugin_icon_import.call_deferred()


## True when the most opaque pixel of `texture` is `ink`, give or take rounding (2/255 per channel).
static func is_in_ink(texture: Texture2D, ink: Color) -> bool:
	var drawn: Color = most_opaque_colour(texture.get_image() if texture != null else null)
	return absf(drawn.r - ink.r) <= 2.0 / 255.0 and absf(drawn.g - ink.g) <= 2.0 / 255.0 \
			and absf(drawn.b - ink.b) <= 2.0 / 255.0


## The colour of the most opaque pixel of `image` (opaque black when there is none).
static func most_opaque_colour(image: Image) -> Color:
	var colour: Color = Color.BLACK
	if image == null:
		return colour
	if image.is_compressed():
		image.decompress()
	var best_alpha: float = 0.0
	for y: int in image.get_height():
		for x: int in image.get_width():
			var pixel: Color = image.get_pixel(x, y)
			if pixel.a > best_alpha:
				best_alpha = pixel.a
				colour = Color(pixel.r, pixel.g, pixel.b)
	return colour


## The colour the editor draws its plain one-ink icons in under `theme`: the most opaque pixel of a
## sample icon that Godot draws in #E0E0E0 and recolours for a light theme. #E0E0E0 when there is
## no theme to ask.
static func editor_icon_ink(theme: Theme) -> Color:
	var ink: Color = Color(PLUGIN_ICON_INK)
	if theme == null or not theme.has_icon(EDITOR_INK_SAMPLE_ICON, "EditorIcons"):
		return ink
	var image: Image = theme.get_icon(EDITOR_INK_SAMPLE_ICON, "EditorIcons").get_image()
	return ink if image == null else most_opaque_colour(image)


## Controls visibility for the workspace surface when selected in top tabs. Selecting the tab is
## the primary lazy trigger: build the editor on first show, then reveal it.
func _make_visible(visible: bool) -> void:
	if visible:
		_ensure_editor()
	if _event_sheet_editor != null:
		_event_sheet_editor.visible = visible


## Connects (or disconnects) the FileSystem dock's tree and file list clicks. Only a left click does
## anything, so walking the list with the arrow keys never pulls the editor away from its screen.
func _watch_file_system_clicks(on: bool) -> void:
	var file_system_dock: FileSystemDock = get_editor_interface().get_file_system_dock()
	if file_system_dock == null:
		return
	for tree: Node in file_system_dock.find_children("*", "Tree", true, false):
		var clicked: Signal = (tree as Tree).item_mouse_selected
		if on and not clicked.is_connected(_on_file_system_tree_clicked):
			clicked.connect(_on_file_system_tree_clicked)
		elif not on and clicked.is_connected(_on_file_system_tree_clicked):
			clicked.disconnect(_on_file_system_tree_clicked)
	for list: Node in file_system_dock.find_children("*", "ItemList", true, false):
		var clicked: Signal = (list as ItemList).item_clicked
		if on and not clicked.is_connected(_on_file_system_list_clicked):
			clicked.connect(_on_file_system_list_clicked)
		elif not on and clicked.is_connected(_on_file_system_list_clicked):
			clicked.disconnect(_on_file_system_list_clicked)


func _on_file_system_tree_clicked(_at: Vector2, button: int) -> void:
	if button == MOUSE_BUTTON_LEFT:
		# After the FileSystem has finished handling its own click, so the selection is the clicked file.
		_open_clicked_script.call_deferred()


func _on_file_system_list_clicked(_index: int, _at: Vector2, button: int) -> void:
	if button == MOUSE_BUTTON_LEFT:
		_open_clicked_script.call_deferred()


## A click in the FileSystem that leaves one script selected opens it as a sheet while "Open Scripts as
## Event Sheets" is ticked; a second click on it brings its tab forward again.
func _open_clicked_script() -> void:
	if not _open_scripts_as_sheets_enabled():
		return
	var paths: PackedStringArray = get_editor_interface().get_selected_paths()
	if paths.size() == 1 and opens_on_click(paths[0], true):
		_open_sheet_in_workspace(paths[0])


## True when a click on `path` in the FileSystem opens it as a sheet: the setting is ticked and the
## file is a script the sheet reads (not an editor script, and one that saves back byte for byte).
## Any other file keeps doing what Godot does with it, a script going to the Script editor.
static func opens_on_click(path: String, enabled: bool) -> bool:
	if not enabled or path.get_extension().to_lower() != "gd":
		return false
	var workflow: Script = load(WORKFLOW_PATH)
	return workflow.is_openable_as_sheet(path) and workflow.click_opens_as_sheet(path)


## Checks whether the selected object can be edited by this plugin.
func _handles(object: Object) -> bool:
	if is_event_sheet_resource(object):
		return true
	# Open scripts as event sheets (off by default): when on, clicking a script the sheet can read routes
	# here, so it opens as an editable sheet instead of in the Script editor. A script the sheet cannot
	# read is not claimed, so Godot still opens it in the Script editor.
	return object is Script and opens_on_click((object as Script).resource_path, _open_scripts_as_sheets_enabled())


## Loads the selected EventSheet (or, with the setting on, a .gd) into the workspace editor.
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
		# Open-scripts path: open the clicked script's file as a sheet.
		_open_sheet_in_workspace((object as Script).resource_path)


## True when the "open scripts as event sheets" project setting is ticked.
static func _open_scripts_as_sheets_enabled() -> bool:
	return bool(ProjectSettings.get_setting(EventSheetSettings.OPEN_SCRIPTS_SETTING, false))


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
	# A file already open in a tab is brought forward rather than read again into a second tab: every
	# door here (the FileSystem's Open as Event Sheet, the Inspector button, a double-click) is asked
	# again and again for the same few scripts, and each ask used to add another tab of the same file.
	if _event_sheet_editor.has_method("open_or_focus_sheet"):
		_event_sheet_editor.call("open_or_focus_sheet", path)
		return
	_event_sheet_editor.call("_load_sheet_from_path", path)


## The pencil on an Inspector instance-variable row: the sheet, opened on the row that variable's
## declaration line became. The line travels as the SCRIPT's own line number, which is the same
## thing a stack trace carries, so both doors land through one reverse-provenance lookup.
func _open_sheet_line_in_workspace(path: String, line: int) -> void:
	_open_sheet_in_workspace(path)
	if _event_sheet_editor != null and _event_sheet_editor.has_method("goto_generated_line"):
		_event_sheet_editor.call("goto_generated_line", line)


## An initial value typed into an Inspector row. It is written by the sheet, through the same undo
## funnel its own variable table writes through, so the line that lands is the line the table would
## have written and one Ctrl+Z takes it back.
func _write_sheet_variable_value(path: String, variable_name: String, value_text: String) -> void:
	_open_sheet_in_workspace(path)
	if _event_sheet_editor != null and _event_sheet_editor.has_method("set_instance_variable_value"):
		_event_sheet_editor.call("set_instance_variable_value", variable_name, value_text)


## "+ Add instance variable": the sheet's own Add variable dialog, so a variable born in the
## Inspector carries every field one born on the sheet does. Falls back to the variables table on a
## workspace that does not offer the dialog door, so the link is never a dead click.
func _add_sheet_variable_in_workspace(path: String) -> void:
	_open_sheet_in_workspace(path)
	if _event_sheet_editor == null:
		return
	if _event_sheet_editor.has_method("add_instance_variable"):
		_event_sheet_editor.call("add_instance_variable")
	elif _event_sheet_editor.has_method("open_instance_variables"):
		_event_sheet_editor.call("open_instance_variables")


## The FileSystem's "Open its sheets": a scene opens as one named tab group holding the
## scene-as-sheet and every script in it, in tree order.
func _open_scene_workspace(scene_path: String) -> void:
	_ensure_editor()
	if _event_sheet_editor == null or not _event_sheet_editor.has_method("open_scene_workspace"):
		return
	get_editor_interface().set_main_screen_editor(_get_plugin_name())
	_event_sheet_editor.call("open_scene_workspace", scene_path)


## The script editor's "Go to Sheet Row": carries the caret line into the sheet's
## reverse provenance - errors and stack traces land on rows, not generated code.
func _goto_sheet_row_from_script(script_path: String) -> void:
	var sheet_path: String = load(PROJECT_DOCTOR_PATH).sheet_for_script(script_path)
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
	var result: Dictionary = load(WORKFLOW_PATH).create_sheet_for_node(node, directory)
	if bool(result.get("ok", false)):
		get_editor_interface().mark_scene_as_unsaved()
		get_editor_interface().get_resource_filesystem().scan()
		_open_sheet_in_workspace(str(result.get("sheet_path")))
	else:
		push_warning("[Godot EventSheets] %s" % str(result.get("message")))


## Right-clicked node -> Connect Signal to Event Sheet: resolve the node's sheet and open
## the signal picker. A node without a sheet is pointed at Attach Event Sheet instead of
## failing silently.
func _connect_signal_from_node(node: Node) -> void:
	if node == null:
		return
	var node_script: Script = node.get_script() as Script
	var sheet_path: String = "" if node_script == null else str(load(PROJECT_DOCTOR_PATH).sheet_for_script(node_script.resource_path))
	if sheet_path.is_empty():
		push_warning("[Godot EventSheets] %s has no event sheet - use Attach Event Sheet first, then connect signals." % node.name)
		return
	if _connect_signal_dialog == null:
		_connect_signal_dialog = load(CONNECT_SIGNAL_DIALOG_PATH).new()
	_connect_signal_dialog.call("open", node, sheet_path, get_editor_interface().get_base_control())


## Right-clicked node -> Show events: open the node's script AS A SHEET and filter its events to
## that object, so the answer to "what is this node's logic?" is one gesture from the Scene dock.
## A node with no script says so rather than opening an empty workspace.
func _show_events_for_node(node: Node) -> void:
	if node == null:
		return
	var node_script: Script = node.get_script() as Script
	if node_script == null or node_script.resource_path.is_empty():
		push_warning("[Godot EventSheets] %s has no script - use Attach Event Sheet first." % node.name)
		return
	var sheet_path: String = str(load(PROJECT_DOCTOR_PATH).sheet_for_script(node_script.resource_path))
	_open_sheet_in_workspace(sheet_path if not sheet_path.is_empty() else node_script.resource_path)
	if _event_sheet_editor != null and _event_sheet_editor.has_method("filter_events_to_object"):
		_event_sheet_editor.call("filter_events_to_object", node.name)


## The FileSystem "Create New > Event Sheet..." entry: pop the name + starter dialog for the
## clicked folder. The dialog is parented to the editor's base control (always present), so it
## works even before the workspace editor has ever been built.
func _create_sheet_in_directory(directory: String, kind_of: String = "") -> void:
	# Built once and reused (the standard reusable-dialog pattern) - the plugin holds the strong
	# reference so the window is never freed out from under its connections. It carries the target
	# folder in its create_requested signal, so one connection serves every folder.
	if _new_sheet_dialog == null:
		_new_sheet_dialog = load(NEW_SHEET_DIALOG_PATH).new()
		_new_sheet_dialog.init_dialog(get_editor_interface().get_base_control())
		_new_sheet_dialog.create_requested.connect(_finish_create_sheet)
	_new_sheet_dialog.open(directory, kind_of)


## Writes the chosen starter to a fresh .gd in the target folder, indexes it, and opens it EDITABLE
## in the workspace (not the read-only preview a casual .gd Open gives - the user just authored it).
func _finish_create_sheet(directory: String, sheet_name: String, starter_id: int) -> void:
	var sheet: EventSheetResource = load(STARTER_TEMPLATES_PATH).build_starter(starter_id)
	# A kind of another class extends it and names itself after the file; the starter's events stay.
	var kind_of: String = str(_new_sheet_dialog.call("kind_of")) if _new_sheet_dialog != null else ""
	if not kind_of.is_empty():
		sheet.host_class = kind_of
		sheet.custom_class_name = load("res://addons/eventsheet/editor/dock/class_kinds.gd").class_name_from(sheet_name)
	var result: Dictionary = load(WORKFLOW_PATH).write_sheet_file(sheet, directory, sheet_name)
	if not bool(result.get("ok", false)):
		push_warning("[Godot EventSheets] %s" % str(result.get("message")))
		return
	if bool(result.get("renamed", false)):
		# The typed name was taken: say which file was written instead of leaving the user to find it.
		print("[Godot EventSheets] %s" % str(result.get("message")))
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
## versioned filename meant every showcase refresh had to edit the plugin). Each showcase
## lives in its own subfolder now, so the scan walks one level deep for showcase_*.tscn.
static func _find_showcase_scene() -> String:
	var root: DirAccess = DirAccess.open("res://demo/showcase")
	if root == null:
		return ""
	var newest: String = ""
	for folder: String in root.get_directories():
		var dir: DirAccess = DirAccess.open("res://demo/showcase/%s" % folder)
		if dir == null:
			continue
		for entry: String in dir.get_files():
			var candidate: String = "res://demo/showcase/%s/%s" % [folder, entry]
			if entry.begins_with("showcase_") and entry.ends_with(".tscn") and candidate.get_file() > newest.get_file():
				newest = candidate
	return newest


## The bridge autoload belongs to the project, so it is written into project.godot when the plugin is
## switched on and taken out when it is switched off - not on every editor start and quit. _exit_tree
## also runs while the editor is closing, with the tree half torn down, and taking the autoload out
## then reached for a root that was busy freeing its children and printed an error on every quit.
func _enable_plugin() -> void:
	add_autoload_singleton(BRIDGE_NAME, BRIDGE_PATH)


func _disable_plugin() -> void:
	remove_autoload_singleton(BRIDGE_NAME)


## Registers plugin services when the plugin is enabled.
func _enter_tree() -> void:
	# A project that was already using the plugin before the autoload moved to _enable_plugin, or whose
	# project.godot lost the line, gets it back here. One that has it is left exactly as it is.
	if not ProjectSettings.has_setting("autoload/%s" % BRIDGE_NAME):
		add_autoload_singleton(BRIDGE_NAME, BRIDGE_PATH)
	# Every eventsheets/* setting becomes visible + documented in Project Settings
	# (value-neutral: defaults match the in-code fallbacks).
	# A project that ticked a setting under its old key gets the choice saved under the new key once.
	if EventSheetSettings.register_all():
		ProjectSettings.save()
	# The hover Project Settings shows for the settings that are documented.
	_settings_hover_plugin = load(SETTINGS_HOVER_PATH).new()
	add_inspector_plugin(_settings_hover_plugin)
	# A single click on a script in the FileSystem only shows it in the Inspector, so _handles() is never
	# asked; with "Open Scripts as Event Sheets" ticked, the click itself opens the sheet. The dock's
	# tree and its file list say "an item was clicked" even when it was already selected, which is what
	# lets a second click bring the sheet forward again.
	_watch_file_system_clicks(true)
	# The @icon a sheet resource wears in the FileSystem is the imported svg, which the importer draws in
	# the editor's colours of the day it ran. After a switch between a dark and a light editor theme it
	# is redrawn once, so it does not stay pale on the light theme.
	_refresh_plugin_icon_import.call_deferred()
	# A switch of the editor theme while the editor runs redraws the sheet resources' icon the same way.
	var base: Control = get_editor_interface().get_base_control()
	if base != null and not base.theme_changed.is_connected(_on_editor_theme_changed):
		base.theme_changed.connect(_on_editor_theme_changed)
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
		menu.connect_signal = _connect_signal_from_node
		menu.open_workspace = _open_scene_workspace
		menu.show_events = _show_events_for_node
		add_context_menu_plugin(slot, menu)
		_context_menus.append(menu)
	# Inspector: nodes whose script is sheet-generated get an "Edit Event Sheet" button.
	_sheet_edit_button_plugin = EventSheetEditButtonPlugin.new()
	_sheet_edit_button_plugin.open_sheet = _open_sheet_in_workspace
	add_inspector_plugin(_sheet_edit_button_plugin)
	# And under it, the object's own variables as Inspector ROWS - name, type, initial value, and a
	# pencil that opens the sheet on the line that declares each. Loaded by path (it carries no
	# class_name), so registering it adds nothing to the boot compile.
	_instance_variables_inspector = load(INSTANCE_VARIABLES_INSPECTOR_PATH).new()
	_instance_variables_inspector.open_line = _open_sheet_line_in_workspace
	_instance_variables_inspector.write_value = _write_sheet_variable_value
	_instance_variables_inspector.add_variable = _add_sheet_variable_in_workspace
	add_inspector_plugin(_instance_variables_inspector)
	# Export integrity: recompile every sheet when an export starts so stale generated
	# scripts can never ship (see export_integrity_plugin.gd).
	_export_integrity_plugin = EventSheetExportIntegrityPlugin.new()
	add_export_plugin(_export_integrity_plugin)
	# The export bake step: Editor Tool sheets that declared the On Project Export trigger get their
	# handler called as the export begins, so a build stamp or a baked data file is part of the export
	# instead of a chore somebody has to remember. Loaded by path - it carries no class_name, so this
	# registration adds nothing to the boot compile.
	_export_tools_plugin = load(EXPORT_TOOLS_PLUGIN_PATH).new()
	add_export_plugin(_export_tools_plugin)
	# The import reaction: Editor Tool sheets that declared the On File Imported trigger get their
	# handler called with the paths Godot just (re)imported, so "fix up what a designer dropped in"
	# is a sheet event instead of a chore. Loaded by path for the same boot-compile reason.
	_import_tools_plugin = load(IMPORT_TOOLS_PLUGIN_PATH).new()
	_import_tools_plugin.call("attach", EditorInterface.get_resource_filesystem())
	# Live Values (debugging rung 2): capture the values frames debug-compiled sheets
	# stream, and feed them to the workspace editor's Live Values window.
	_live_values_debugger = EventSheetLiveValuesDebugger.new()
	add_debugger_plugin(_live_values_debugger)
	# DrawingPrefabResource: a shape-aware `steps` editor + a live preview panel + a FileSystem/resource-picker
	# thumbnail, all rendered by the tree-free rasterizer. Registered BEFORE the generic attribute drawers so
	# its _parse_property claims `steps` (the titled per-shape editor) ahead of the generic p1/p2/p3 grid.
	# Cosmetic - a prefab still edits as a plain steps table and draws identically without this plugin.
	_drawing_prefab_inspector = load(DRAWING_PREFAB_INSPECTOR_PATH).new()
	add_inspector_plugin(_drawing_prefab_inspector)
	# FeedbackPlayer: the strip under its list (how long the beat is, the buttons that play it in the
	# editor, the debug timeline, and the two doors to a moment file). The list itself is drawn by the
	# shared card-list drawer through the ordinary marker on its export, so nothing is claimed here.
	_feedback_player_inspector = load(FEEDBACK_PLAYER_INSPECTOR_PATH).new()
	add_inspector_plugin(_feedback_player_inspector)
	# And the vocabulary that list is drawn WITH, registered as a callable rather than as a table: the
	# kinds are derived from the Juice pack's own verbs, which are known when an Inspector opens and
	# not when the plugin boots. The lambda loads the schema file on first ask, so registering it
	# costs nothing at boot.
	var extension_registries: Script = load(EXTENSION_REGISTRIES_PATH)
	extension_registries.call("register_card_schema", FEEDBACK_CARD_SCHEMA_NAME,
		func() -> Dictionary: return load(FEEDBACK_CARD_SCHEMA_PATH).call("schema"))
	# And the SAME card, opened from a row: Add Feedback, Insert Feedback Before and Replace Feedback
	# each take a step, and a step typed into a plain parameter box is a dictionary with no kinds, no
	# fields and no help. The registered field opens the card instead, so a feedback authored by a row
	# and one authored in the list are the same dictionary spelled the same way. Loaded by path on
	# first ask, for the same reason the schema is.
	extension_registries.call("register_param_editor", FEEDBACK_STEP_HINT,
		func(_param: Dictionary, initial_text: String) -> LineEdit:
			return load(FEEDBACK_STEP_FIELD_PATH).new(initial_text))
	extension_registries.call("register_param_help", FEEDBACK_STEP_HINT, FEEDBACK_STEP_HELP)
	# Tier 3 attribute drawers (progress bars…): purely cosmetic - generated scripts
	# degrade to plain fields without this plugin.
	_attribute_drawers_plugin = EventSheetAttributeDrawers.new()
	_attribute_drawers_plugin.open_table = _open_sheet_in_workspace
	add_inspector_plugin(_attribute_drawers_plugin)
	_drawing_prefab_preview_gen = load(DRAWING_PREFAB_PREVIEW_GEN_PATH).new()
	var prefab_previewer: EditorResourcePreview = get_editor_interface().get_resource_previewer()
	if prefab_previewer != null:
		prefab_previewer.add_preview_generator(_drawing_prefab_preview_gen)
	# Viewport handles: a selected node whose script declares `# @inspector_handle` lines shows a
	# draggable mark per handle, and each drag is one undo step. It rides the FORCE canvas forwarding
	# below rather than _handles(), because a main-screen plugin that claims scene nodes makes Godot
	# switch workspaces the moment one is selected - the same reason the gizmos ride selection.
	_inspector_handles = load(INSPECTOR_HANDLES_PATH).new()
	_inspector_handles.call("init", self)
	# DrawingCanvas 2D preview gizmo: selecting a DrawingCanvas draws its preview_prefab at the host.
	# Selection-driven (never _handles), so it can't hijack the workspace. Cosmetic design aid.
	_drawing_canvas_gizmo = load(DRAWING_CANVAS_GIZMO_PATH).new()
	_drawing_canvas_gizmo.call("init", get_editor_interface())
	# DrawingPrefabResource preview gizmos: selecting any Node2D/Node3D that references a prefab draws it
	# in the 2D viewport at the node's origin, or as a camera-facing billboard in the 3D viewport. Both
	# are selection-driven (never _handles) and spawn transient owner-less children, so they can't hijack
	# the workspace and never touch the scene file. Cosmetic design aids.
	_drawing_prefab_gizmo = load(DRAWING_PREFAB_GIZMO_PATH).new()
	_drawing_prefab_gizmo.call("init", get_editor_interface())
	_drawing_prefab_3d_gizmo = load(DRAWING_PREFAB_3D_GIZMO_PATH).new()
	_drawing_prefab_3d_gizmo.call("init", get_editor_interface())
	# Behavior gizmos: any behavior shipping an editor_gizmo_draw static (or registered via
	# EventSheets.register_editor_gizmo) draws its setup overlay while its node is selected.
	# Selection-driven (never _handles), transient owner-less canvas - can't hijack the workspace.
	_behavior_gizmos = load(BEHAVIOR_GIZMOS_PATH).new()
	_behavior_gizmos.call("init", get_editor_interface())
	# The events overlay - a node whose script is a sheet wears a ⌗ and its event count in the
	# Scene dock and beside it in the 2D editor, with its triggers on hover. Off until the setting
	# says otherwise, so the scene editor stays exactly as the person editing the scene left it.
	_scene_events_overlay = load(SCENE_EVENTS_OVERLAY_PATH).new()
	_scene_events_overlay.call("init", get_editor_interface())
	# Documentation, docked: the guides and the "what does this do?" reference beside the sheet, in a
	# dock that persists in the editor layout and can be floated onto a second monitor. Registered
	# here because add_dock takes an instance, and deliberately EMPTY until the reader first opens it -
	# the reading surface, the parser, the guide bundle and the viewport behind it all build on that
	# first reveal, so a session that never opens the dock pays for one bare node.
	_doc_dock = load(DOC_DOCK_PATH).new()
	add_dock(_doc_dock)
	# The workspace editor (the ~3400-line dock, its ~45 delegates, every dialog, and the addon-folder
	# vocabulary scans) is built LAZILY on first use - see _ensure_editor. Enabling the plugin, or
	# opening a project that never touches event sheets, pays none of it. The top-strip tab still
	# appears immediately (driven by _has_main_screen / _get_plugin_name, which don't need the editor).
	print("[Godot EventSheets] plugin loaded")


## The 2D editor's input, forwarded here for every event (set_input_event_forwarding_always_enabled):
## the handle seam claims a drag on one of its own marks and nothing else, so every gesture it does
## not claim stays the 2D editor's.
func _forward_canvas_gui_input(event: InputEvent) -> bool:
	return _inspector_handles != null and bool(_inspector_handles.call("canvas_gui_input", event))


## The 2D editor's overlay, forwarded here whenever the viewport redraws
## (set_force_draw_over_forwarding_enabled): the handle marks for the selected node, and nothing at
## all for a selection that declares none.
func _forward_canvas_force_draw_over_viewport(overlay: Control) -> void:
	if _inspector_handles != null:
		_inspector_handles.call("draw_over_viewport", overlay)


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
	if _live_values_debugger != null and editor.has_method("update_event_times"):
		_live_values_debugger.event_times_received.connect(editor.update_event_times)
	if _live_values_debugger != null and editor.has_method("reveal_paused_row"):
		_live_values_debugger.paused_row_received.connect(editor.reveal_paused_row)
	if _live_values_debugger != null and editor.has_method("report_runtime_error"):
		# A script error announced by the running game lands on the runtime-error strip, re-said
		# as the row said it, with Jump to event / Explain / Godot's words live.
		_live_values_debugger.runtime_error_received.connect(editor.report_runtime_error)
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
		if store != null:
			_ace_param_inspector_plugin = load(ACE_PARAM_INSPECTOR_PATH).new()
			_ace_param_inspector_plugin.call("set_param_store", store)
			add_inspector_plugin(_ace_param_inspector_plugin)
	# The selected function's fields: registered on the first function selection, through this door.
	if "function_fields_door" in editor:
		editor.set("function_fields_door", _register_function_fields)
	# Commit only after the whole build succeeds - see the docstring's clean-retry contract.
	_event_sheet_editor = editor
	# Deferred, so the workspace's first open does not wait for it.
	_register_shape_link.call_deferred()
	_maybe_show_welcome()


## Adds the Inspector's "Shape <Class>…" link, once: it opens the sheet and its Inspector Designer.
## Loaded by path.
func _register_shape_link() -> void:
	if _shape_link_plugin != null or _event_sheet_editor == null:
		return
	_shape_link_plugin = load(SHAPE_LINK_INSPECTOR_PATH).new()
	_shape_link_plugin.set("open_designer", func(sheet_path: String) -> void:
		_ensure_editor()
		if _event_sheet_editor == null or not _event_sheet_editor.has_method("open_designer_for"):
			return
		get_editor_interface().set_main_screen_editor(_get_plugin_name())
		_event_sheet_editor.call("open_designer_for", sheet_path))
	add_inspector_plugin(_shape_link_plugin)


## Adds the Inspector plugin that draws a selected function's fields, once. Loaded by path.
func _register_function_fields() -> void:
	if _function_fields_plugin == null:
		_function_fields_plugin = load(FUNCTION_FIELDS_INSPECTOR_PATH).new()
		add_inspector_plugin(_function_fields_plugin)


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
	if _inspector_handles != null:
		_inspector_handles.call("teardown")
		_inspector_handles = null
	if _drawing_canvas_gizmo != null:
		_drawing_canvas_gizmo.call("teardown")
		_drawing_canvas_gizmo = null
	if _behavior_gizmos != null:
		_behavior_gizmos.call("teardown")
		_behavior_gizmos = null
	if _scene_events_overlay != null:
		_scene_events_overlay.call("teardown")
		_scene_events_overlay = null
	if _drawing_prefab_gizmo != null:
		_drawing_prefab_gizmo.call("teardown")
		_drawing_prefab_gizmo = null
	if _drawing_prefab_3d_gizmo != null:
		_drawing_prefab_3d_gizmo.call("teardown")
		_drawing_prefab_3d_gizmo = null
	if _sheet_edit_button_plugin != null:
		remove_inspector_plugin(_sheet_edit_button_plugin)
		_sheet_edit_button_plugin = null
	if _instance_variables_inspector != null:
		remove_inspector_plugin(_instance_variables_inspector)
		_instance_variables_inspector = null
	if _settings_hover_plugin != null:
		remove_inspector_plugin(_settings_hover_plugin)
		_settings_hover_plugin = null
	_watch_file_system_clicks(false)
	var base: Control = get_editor_interface().get_base_control()
	if base != null and base.theme_changed.is_connected(_on_editor_theme_changed):
		base.theme_changed.disconnect(_on_editor_theme_changed)
	if _export_integrity_plugin != null:
		remove_export_plugin(_export_integrity_plugin)
		_export_integrity_plugin = null
	if _export_tools_plugin != null:
		remove_export_plugin(_export_tools_plugin)
		_export_tools_plugin = null
	if _import_tools_plugin != null:
		_import_tools_plugin.call("detach")
		_import_tools_plugin = null
	if _live_values_debugger != null:
		remove_debugger_plugin(_live_values_debugger)
		_live_values_debugger = null
	if _feedback_player_inspector != null:
		remove_inspector_plugin(_feedback_player_inspector)
		_feedback_player_inspector = null
		# All THREE registrations this pair of files made, taken off together: the schema, the
		# parameter field and the sentence the help strip says about it. Each is a callable or a
		# string held in a shared static, so one left behind outlives the disabled plugin.
		var registries: Script = load(EXTENSION_REGISTRIES_PATH)
		registries.call("unregister_card_schema", FEEDBACK_CARD_SCHEMA_NAME)
		registries.call("unregister_param_editor", FEEDBACK_STEP_HINT)
		registries.call("unregister_param_help", FEEDBACK_STEP_HINT)
	if _attribute_drawers_plugin != null:
		remove_inspector_plugin(_attribute_drawers_plugin)
		_attribute_drawers_plugin = null
		if _drawing_prefab_inspector != null:
			remove_inspector_plugin(_drawing_prefab_inspector)
			_drawing_prefab_inspector = null
		if _drawing_prefab_preview_gen != null:
			var prefab_previewer: EditorResourcePreview = get_editor_interface().get_resource_previewer()
			if prefab_previewer != null:
				prefab_previewer.remove_preview_generator(_drawing_prefab_preview_gen)
			_drawing_prefab_preview_gen = null
	if _ace_param_inspector_plugin != null:
		remove_inspector_plugin(_ace_param_inspector_plugin)
		_ace_param_inspector_plugin = null
	if _function_fields_plugin != null:
		remove_inspector_plugin(_function_fields_plugin)
		_function_fields_plugin = null
	if _shape_link_plugin != null:
		remove_inspector_plugin(_shape_link_plugin)
		_shape_link_plugin = null
	if _new_sheet_dialog != null:
		_new_sheet_dialog.free_dialog()
		_new_sheet_dialog = null
	if _doc_dock != null:
		remove_dock(_doc_dock)
		_doc_dock.queue_free()
		_doc_dock = null
	if _event_sheet_editor != null:
		if _event_sheet_editor.get_parent() != null:
			_event_sheet_editor.get_parent().remove_child(_event_sheet_editor)
		_event_sheet_editor.queue_free()
		_event_sheet_editor = null
	print("[Godot EventSheets] unloaded")
