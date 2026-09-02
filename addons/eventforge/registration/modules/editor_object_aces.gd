# EventForge module - the Editor object (plugin lifecycle, docks, menu items, object types).
#
# The sibling of tooling_aces.gd, filed under the SAME "Editor Tools" category so the whole
# vocabulary reads and picks as one object - the Editor, standing next to System. Where
# tooling_aces.gd covers the one-shot chores an EditorScript runs, this file covers what an
# EditorPlugin does to the editor itself: it turns on and off, it hangs a dock, it adds a Tools
# menu item, it teaches the editor a new object type, it draws over the 2D viewport.
#
# Every action here compiles to the plain EditorPlugin method it names, with no plugin reference,
# so an opened hand-written plugin lifts into these rows and re-emits byte-identically. The
# triggers are the plugin virtuals the editor already calls: `_enter_tree` (the plugin was
# enabled), `_exit_tree` (disabled), `_edit` (an object it handles was selected),
# `_forward_canvas_draw_over_viewport` (the 2D overlay pass) and `_redraw` (a gizmo's own pass).
#
# These are editor-only in the strictest sense: the methods live on EditorPlugin, so a sheet using
# them must be a Tool sheet whose host is EditorPlugin (Sheet Type -> Editor plugin). On any other
# sheet the picker does not offer them at all.
# TWO FILES, ONE SHELF. The authoring rows - the project's settings, the user's preferences, the
# editor's own surfaces - were a module of their own, split by aspect rather than by subject: every
# one of them files under a page this module already owns ("Editor Tools: Project & preferences" and
# "Editor Tools: Panels & menus"), a reader looking for them looks here, and the two files sat next
# to each other in the sorted module walk, so joining them moves no row and no registry position.
# That half keeps its own header below, whole.
@tool
class_name EventForgeEditorObjectACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

## The root every page below hangs under. Kept as a constant even though no descriptor uses it
## any more: it is the string the tool-sheet gate and the "Editor" object label test the prefix of, and
## naming it here is what stops a page being spelled a hair differently and quietly ungating itself.
const CAT := "Editor Tools"

## The pages this module's rows are filed on. Every one begins "Editor Tools: " so the tool-sheet
## gate and the "Editor" object label keep working - both test the PREFIX, not the whole string - and
## every one names the surface a reader is already looking at when they come here: the plugin's own
## life, the panels it hangs, the Properties bar it adds to, the history Ctrl+Z walks. A page per
## surface is the whole point: the flat list was thirty-eight rows of four unrelated jobs.
const CAT_LIFECYCLE := "Editor Tools: Plugin lifecycle"
const CAT_PANELS := "Editor Tools: Panels & menus"
const CAT_PROPERTIES := "Editor Tools: Properties bar"
const CAT_UNDO := "Editor Tools: Undo history"
const CAT_PREFERENCES := "Editor Tools: Project & preferences"

## The menu a tool builds in code, and the item the user picked out of it. Its own page because a
## menu is its own object: the rows read "Menu ▸ Add item …" and "Sheet menu ▸ On Save chosen", which
## is exactly how a hand-written menu already reads when a file is opened as a sheet.
const CAT_MENUS := "Editor Tools: Menus"

## The dock slots Godot exposes, in the editor's own reading order. The label is the words a sheet
## row uses ("left, top"), the key the engine constant the emitted line needs - one list, so the
## dropdown and the reading cannot drift apart.
const DOCK_SLOTS: Array = [
	{"key": "EditorPlugin.DOCK_SLOT_LEFT_UL", "label": "left, top"},
	{"key": "EditorPlugin.DOCK_SLOT_LEFT_BL", "label": "left, bottom"},
	{"key": "EditorPlugin.DOCK_SLOT_LEFT_UR", "label": "left inner, top"},
	{"key": "EditorPlugin.DOCK_SLOT_LEFT_BR", "label": "left inner, bottom"},
	{"key": "EditorPlugin.DOCK_SLOT_RIGHT_UL", "label": "right inner, top"},
	{"key": "EditorPlugin.DOCK_SLOT_RIGHT_BL", "label": "right inner, bottom"},
	{"key": "EditorPlugin.DOCK_SLOT_RIGHT_UR", "label": "right, top"},
	{"key": "EditorPlugin.DOCK_SLOT_RIGHT_BR", "label": "right, bottom"}
]


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	# ── The plugin's own life (what the editor calls when it is switched on and off) ──
	descriptors.append(F.trig("OnPluginEnabled", "On Plugin Enabled", "_enter_tree", CAT_LIFECYCLE, "On plugin enabled", "Runs when the plugin is switched on - at editor start, or the moment you tick it in Project Settings. This is where a plugin hangs its dock, adds its Tools menu item and teaches the editor its object types."))
	descriptors.append(F.trig("OnPluginDisabled", "On Plugin Disabled", "_exit_tree", CAT_LIFECYCLE, "On plugin disabled", "Runs when the plugin is switched off or the editor closes. Undo here everything On plugin enabled did, or the editor keeps a dock nobody owns."))
	# What `_edit` actually is: the editor HANDED this plugin an object to edit, because the
	# plugin answered yes when asked whether it could. "On object selected" said only half of that,
	# and sent a reader looking for a selection change that never fires for objects this plugin
	# refused. The ace_id and the callback behind it are unchanged; only the words are.
	descriptors.append(F.trig("OnEditorObjectSelected", "On Object Handed To Plugin", "_edit", CAT_LIFECYCLE, "On object handed to plugin", "Runs when the editor hands this plugin an object to edit - the user selected something this plugin said yes to. The object arrives as `object`."))

	# ── The 2D viewport (the overlay pass and the gizmo pass) ──
	descriptors.append(F.trig("OnDrawOver2DViewport", "On Draw Over 2D Viewport", "_forward_canvas_draw_over_viewport", CAT_LIFECYCLE, "On draw over 2D viewport", "The editor's 2D overlay pass. Draw handles, guides or labels on top of the scene with the Drawing actions - the surface arrives as `overlay`."))
	descriptors.append(F.trig("On2DViewportInput", "On 2D Viewport Input", "_forward_canvas_gui_input", CAT_LIFECYCLE, "On 2D viewport input", "Input that lands in the editor's 2D viewport, before the viewport itself sees it. End the event with Stop This Input Here to keep the viewport from also acting on it."))
	descriptors.append(F.trig("OnDrawGizmo", "On Draw Gizmo", "_redraw", CAT_LIFECYCLE, "On draw gizmo", "A gizmo's own paint pass - what an EditorNode3DGizmo redraws when its node moves or changes."))

	# ── What a plugin adds to the editor, and takes away again ──
	descriptors.append(F.act("AddToolsMenuItem", "Add Tools Menu Item", "add_tool_menu_item({title}, {handler})", CAT_PANELS, "Add Tools menu item {title}", "Adds an item to the editor's Project > Tools menu. Remove it again on plugin disabled or the menu keeps a dead entry.").param("title", "\"My Tool\"", "Title", "The words the item shows in Project > Tools.", "expression").param_typed("Callable", "handler", "_run_tool", "Calls", "The function to run when the item is picked.", "expression"))
	descriptors.append(F.act("RemoveToolsMenuItem", "Remove Tools Menu Item", "remove_tool_menu_item({title})", CAT_PANELS, "Remove Tools menu item {title}", "Takes the plugin's item back out of Project > Tools.").param("title", "\"My Tool\"", "Title", "The title the item was added with.", "expression"))
	descriptors.append(F.act("AddEditorDock", "Add Dock", "add_control_to_dock({slot}, {control})", CAT_PANELS, "Add dock {control} at {slot}", "Hangs a Control in one of the editor's dock slots. Remove it on plugin disabled - a dock left behind survives the plugin.").param_typed("Control", "control", "Control.new()", "Dock", "The Control to hang in the editor as a dock.", "expression").param_built(_dock_slot_param()))
	descriptors.append(F.act("RemoveEditorDock", "Remove Dock", "remove_control_from_docks({control})", CAT_PANELS, "Remove dock {control}", "Takes a dock back out of the editor.").param_typed("Control", "control", "Control.new()", "Dock", "The Control that was added as a dock.", "expression"))
	descriptors.append(F.act("AddEditorObjectType", "Add Object Type", "add_custom_type({type_name}, {base}, {script}, {icon})", CAT_PANELS, "Add object type {type_name}", "Teaches the editor a new object type, so it shows up in Create Node like a built-in one.").param("type_name", "\"Waypoint\"", "Named", "The name the editor's Create Node dialog will show.", "expression").param("base", "\"Node2D\"", "A", "The built-in class it extends.", "expression").param_typed("Script", "script", "null", "Script", "The script the new object gets.", "expression").param_typed("Texture2D", "icon", "null", "Icon", "The icon it shows in the Scene dock. Leave null for the base class icon.", "expression"))
	descriptors.append(F.act("RemoveEditorObjectType", "Remove Object Type", "remove_custom_type({type_name})", CAT_PANELS, "Remove object type {type_name}", "Takes a custom object type back out of the Create Node dialog.").param("type_name", "\"Waypoint\"", "Named", "The name the type was added with.", "expression"))
	# The panel these two register an add-on with is the one the sheet calls the Properties
	# bar, everywhere else it names it. Same ace_ids, same emitted calls; the words catch up.
	descriptors.append(F.act("AddEditorInspectorPlugin", "Add Properties Bar Add-on", "add_inspector_plugin({plugin})", CAT_PROPERTIES, "Add Properties bar add-on {plugin}", "Registers a Properties bar add-on, so your own buttons and fields appear in the Properties bar beside the object's own.").param_typed("EditorInspectorPlugin", "plugin", "null", "Add-on", "The Properties bar add-on that draws the custom fields.", "expression"))
	descriptors.append(F.act("RemoveEditorInspectorPlugin", "Remove Properties Bar Add-on", "remove_inspector_plugin({plugin})", CAT_PROPERTIES, "Remove Properties bar add-on {plugin}", "Takes a Properties bar add-on back out.").param_typed("EditorInspectorPlugin", "plugin", "null", "Add-on", "The Properties bar add-on that was registered.", "expression"))
	descriptors.append(F.act("UpdateViewportOverlays", "Redraw Viewport Overlays", "update_overlays()", CAT_LIFECYCLE, "redraw viewport overlays", "Asks the editor to run the overlay pass again, so On draw over 2D viewport repaints."))

	# ── The menu, and the item that was chosen out of it ──────
	# The action writes the one line the reading recognises, and the trigger compiles into the one
	# handler every item of a menu shares - `match id:` with a case per item, which is the shape every
	# menu in Godot is already written in. So a menu picked here and a menu typed by hand are the same
	# file, and open as the same rows.
	descriptors.append(F.act("MenuAddItem", "Add Item", "{menu}.add_item({label}, {id})", CAT_MENUS, "Add item {label} to {menu}", "Puts one item in a menu. The id is how the menu says which item was picked, so On Item Chosen answers the same number this row was given.").param_built(_menu_param()).param("label", "\"New…\"", "Labelled", "The words the item shows in the menu.", "expression").param_typed("int", "id", "0", "Id", "The number this item sends when it is chosen. Give every item its own - two items sharing one id means the second one can never run.", "expression"))
	descriptors.append(F.trig("OnMenuItemChosen", "On Item Chosen", "", CAT_MENUS, "On item {item} of {menu} chosen", "Runs when the user picks the item with this id out of the menu. Every item of one menu shares a single handler, so all of them stay together in the emitted file.").param_built(_menu_param()).param_typed("int", "item", "0", "Item", "The id of the item this event answers - the same number Add Item gave it.", "expression"))

	# ── What the editor can be asked (the expressions the picker offers) ──
	descriptors.append(F.expr("EditorSettingsObject", "Editor Settings", "EditorInterface.get_editor_settings()", CAT_PREFERENCES, "editor settings", "The editor's own settings object - read a user's grid step, theme or font size from it."))
	descriptors.append(F.expr("EditorUndoHistory", "Undo History", "get_undo_redo()", CAT_UNDO, "the editor's undo history", "The editor's undo / redo history. Put it in a local object variable and add do / undo steps to it, so Ctrl+Z reverses what your tool changed."))

	# The authoring rows, which were a module of their own directly BEFORE this one in the sorted
	# walk, so putting them first leaves every verb's registry position exactly where it was.
	var all_descriptors: Array[ACEDescriptor] = _authoring_descriptors()
	all_descriptors.append_array(descriptors)
	return all_descriptors


## Blurbs for the six pages this module opens, so a reader clicking the folder is told what the page
## is for before reading a single row. The first two were written by the authoring half below, which
## the walk reached first and which therefore owned those two names before the merge; keeping its
## words is what makes the merge invisible to a reader.
static func section_descriptions() -> Dictionary:
	return {
		CAT_PREFERENCES: "This project's settings and the user's own Editor Settings - read one, write one, save them, and hear about it when either changes.",
		CAT_PANELS: "The editor's own surfaces: its icons, its workspace tabs, its Project bar, its script editor and its command palette.",
		CAT_LIFECYCLE: "What the editor calls on a plugin: switched on, switched off, handed an object to edit, and the two passes it paints over the 2D view.",
		CAT_PROPERTIES: "The panel an object's properties are shown in, and the add-on that puts your own buttons and fields in it beside them.",
		CAT_UNDO: "What Ctrl+Z walks back. A tool that adds its change as a step here is a tool the user can undo like any other edit.",
		CAT_MENUS: "The menus a tool puts on screen: the items that go in one, and the event that runs when the user picks one of them.",
	}


## The menu every row on the Menus page acts on - the variable the menu was made into. Written as
## a plain expression because that is what it is: `sheet_popup`, `_dock._view_menu`, whatever the file
## already calls it. The same param on both rows, so the action and the trigger can never name the
## menu two different ways.
static func _menu_param() -> ACEParam:
	return F.make_param("menu", "PopupMenu", "menu", "Menu", "The menu variable this row acts on - the one the menu was made into.", "expression")


## The dock-slot dropdown. `display_option_labels` is what makes the ROW say "at left, top" while the
## emitted line still carries the engine constant - the reader gets the corner they can point at, the
## generated GDScript gets what Godot needs.
static func _dock_slot_param() -> ACEParam:
	var parameter: ACEParam = F.make_param("slot", "int", "EditorPlugin.DOCK_SLOT_LEFT_UL", "At", "Which of the editor's eight dock slots it goes in.", "", DOCK_SLOTS)
	parameter.display_option_labels = true
	return parameter


# ── THE AUTHORING ROWS: the project, the preferences and the editor surfaces ──
#
# workspaces, the Project bar, the script editor, the command palette).
#
# The third file of the Editor object, beside tooling_aces.gd (the chores a tool runs) and
# editor_object_aces.gd (what a plugin does to the editor). Where those two cover "run this" and
# "hang that", this one covers the questions a tool author asks on the first day: which icon does
# the editor draw for a Node2D, what did the user set their theme to, what is this project's own
# setting, and the four verbs that move the editor around - switch workspace, show a path in the
# Project bar, open a script at a line, put a window on the editor's root.
#
# Every row emits the plain EditorInterface / ProjectSettings line it names, so an opened tool
# script lifts into these rows and re-emits byte-identically. The category is an "Editor Tools: …"
# page, which nests the rows one level under the Editor object in the picker and keeps the
# tool-sheet-only gate (a category that begins with "Editor Tools" is hidden on a game sheet).

## The editor's own workspace tabs, as the words on the tab and the string Godot wants. One list, so
## the dropdown a tool author picks from cannot drift from what the emitted line switches to.
const WORKSPACES: Array = [
	{"key": "\"2D\"", "label": "2D"},
	{"key": "\"3D\"", "label": "3D"},
	{"key": "\"Script\"", "label": "Script"},
	{"key": "\"Game\"", "label": "Game"},
	{"key": "\"AssetLib\"", "label": "AssetLib"},
]


## The authoring rows, which were a module of their own until they joined the pages they were always
## filed under. Kept as one call so the walk above reads as the list of pages it registers.
static func _authoring_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	# ── What the editor can be asked (the expressions a tool author reaches for) ──
	descriptors.append(F.expr("EditorIcon", "Editor Icon", "EditorInterface.get_editor_theme().get_icon({icon_name}, \"EditorIcons\")", CAT_PANELS, "Editor.Icon({icon_name})", "One of the editor's own icons, so a tool's buttons and docks look like the editor around them instead of shipping their own art. The field draws the icon it names as you pick it.").param("icon_name", "\"Node2D\"", "Named", "The editor icon's name - usually a class name like Node2D, Script or Folder.", "editor_icon"))
	descriptors.append(F.expr("EditorPreference", "Editor Preference", "EditorInterface.get_editor_settings().get_setting({path})", CAT_PREFERENCES, "Editor.Preference({path})", "One value out of the user's own Editor Settings - their theme colour, grid step, font size. Read it so a tool matches the editor the person in front of it actually set up.").param("path", "\"interface/theme/base_color\"", "Named", "The Editor Settings path, as it reads in Editor > Editor Settings.", "editor_preference"))
	descriptors.append(F.expr("ProjectSetting", "Project Setting", "ProjectSettings.get_setting({path})", CAT_PREFERENCES, "Project.Setting({path})", "One value out of this project's own settings. Unlike a preference, it is saved with the project, so every person opening it sees the same answer.").param("path", "\"application/config/name\"", "Named", "The Project Settings path, as it reads in Project > Project Settings.", "project_setting"))
	descriptors.append(F.expr("EditorMainScreen", "Workspace Area", "EditorInterface.get_editor_main_screen()", CAT_PANELS, "Editor.MainScreen", "The big area the 2D, 3D and Script tabs share. A workspace plugin adds its own screen as a child of this."))

	# ── The project's settings (read above, written here) ──
	descriptors.append(F.act("SetProjectSetting", "Set Setting", "ProjectSettings.set_setting({path}, {value})", CAT_PREFERENCES, "Set setting {path} to {value}", "Writes one project setting. It lives in memory until Save settings runs, so a tool that changes several settings writes them all and saves once.").param("path", "\"application/config/name\"", "Named", "The Project Settings path to write.", "project_setting").param_typed("Variant", "value", "\"\"", "To", "The value to store there.", "expression"))
	descriptors.append(F.act("SaveProjectSettings", "Save Settings", "ProjectSettings.save()", CAT_PREFERENCES, "Save settings", "Writes the project settings back to project.godot. Without this, everything Set setting changed is lost when the editor closes."))

	# ── Moving the editor around ──
	descriptors.append(F.act("SwitchToWorkspace", "Switch To Workspace", "EditorInterface.set_main_screen_editor({workspace})", CAT_PANELS, "Switch to workspace {workspace}", "Brings one of the editor's top tabs to the front - the same click as pressing 2D or Script yourself.").param_built(_workspace_param()))
	descriptors.append(F.act("ShowInProjectBar", "Show In Project Bar", "EditorInterface.get_file_system_dock().navigate_to_path({path})", CAT_PANELS, "Show in Project bar {path}", "Reveals a folder or file in the editor's project file list and selects it - what a tool does after it writes something, so the reader can see what just landed.").param("path", "\"res://\"", "Path", "The folder or file to reveal, as a res:// path.", "expression"))
	descriptors.append(F.act("OpenScriptAtLine", "Open Script At Line", "EditorInterface.get_script_editor().goto_line({line})", CAT_PANELS, "Open script at line {line}", "Jumps the script editor to a line of the script it already has open - how a tool points at the thing it is complaining about.").param_typed("int", "line", "0", "Line", "The line to jump to, counted from zero.", "expression"))
	descriptors.append(F.act("AddEditorWindow", "Add Window", "EditorInterface.get_base_control().add_child({window})", CAT_PANELS, "Add window {window} to the editor's root", "Puts a window or dialog under the editor's own root, which is what makes it show up with the editor's theme and stay on top of it. Free it again when the plugin is disabled.").param_typed("Node", "window", "Window.new()", "Window", "The window or dialog to hang on the editor.", "expression"))
	descriptors.append(F.act("AddCommandPaletteCommand", "Add Command", "EditorInterface.get_command_palette().add_command({title}, {key_name}, {handler})", CAT_PANELS, "Add command {title}", "Adds one entry to the editor's command palette (Ctrl+Shift+P), so a tool is reachable without a menu of its own.").param("title", "\"My Command\"", "Named", "The words the command palette shows.", "expression").param("key_name", "\"my_plugin/my_command\"", "Keyed", "The unique key the palette files it under.", "expression").param_typed("Callable", "handler", "_run_tool", "Calls", "The function to run when the command is chosen.", "expression"))

	# ── The bottom row of panels (the one Output and Debugger live in) ──
	descriptors.append(F.act("AddBottomPanel", "Add Bottom Panel", "add_control_to_bottom_panel({control}, {title})", CAT_PANELS, "Add bottom panel {control} titled {title}", "Adds a tab to the row Output and Debugger share, at the bottom of the editor. Remove it on plugin disabled or the row keeps a tab nobody owns.").param_typed("Control", "control", "Control.new()", "Panel", "The Control to show in the bottom row.", "expression").param("title", "\"My Panel\"", "Titled", "The words on its tab, beside Output and Debugger.", "expression"))
	descriptors.append(F.act("RemoveBottomPanel", "Remove Bottom Panel", "remove_control_from_bottom_panel({control})", CAT_PANELS, "Remove bottom panel {control}", "Takes the plugin's tab back out of the bottom row.").param_typed("Control", "control", "Control.new()", "Panel", "The Control that was added to the bottom row.", "expression"))

	# ── Two things the editor tells a tool about ──
	descriptors.append(F.trig("OnProjectFilesChanged", "On Project Files Changed", "filesystem_changed", CAT_PREFERENCES, "On project files changed", "Runs whenever the project's files change on disk - something was imported, moved, deleted or added. The place to rescan whatever a tool keeps a list of."))
	descriptors.append(F.trig("OnPreferencesChanged", "On Preferences Changed", "settings_changed", CAT_PREFERENCES, "On preferences changed", "Runs when the user changes anything in Editor Settings. Re-read the preferences a tool draws with, so it follows the theme instead of keeping the old one."))

	return descriptors


## The workspace dropdown. `display_option_labels` is what makes the row read "Switch to workspace 2D"
## while the emitted line still carries the quoted string Godot's own method wants.
static func _workspace_param() -> ACEParam:
	var parameter: ACEParam = F.make_param("workspace", "String", "\"2D\"", "To", "Which of the editor's top tabs to bring forward.", "", WORKSPACES)
	parameter.display_option_labels = true
	return parameter
