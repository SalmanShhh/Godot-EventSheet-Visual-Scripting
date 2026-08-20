# EventForge module - the tool author's everyday Editor set (icons, preferences, project settings,
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
@tool
class_name EventForgeEditorAuthorACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

## The picker pages this module fills. Both are "Editor Tools: …" so the scoping gate and the
## Editor object label keep working - they test the prefix, not the whole string.
const CAT_PROJECT := "Editor Tools: Project & preferences"
const CAT_PANELS := "Editor Tools: Panels & menus"

## The editor's own workspace tabs, as the words on the tab and the string Godot wants. One list, so
## the dropdown a tool author picks from cannot drift from what the emitted line switches to.
const WORKSPACES: Array = [
	{"key": "\"2D\"", "label": "2D"},
	{"key": "\"3D\"", "label": "3D"},
	{"key": "\"Script\"", "label": "Script"},
	{"key": "\"Game\"", "label": "Game"},
	{"key": "\"AssetLib\"", "label": "AssetLib"},
]


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	# ── What the editor can be asked (the expressions a tool author reaches for) ──
	descriptors.append(F.make_descriptor("Core", "EditorIcon", "Editor Icon", ACEDescriptor.ACEType.EXPRESSION, "EditorInterface.get_editor_theme().get_icon({icon_name}, \"EditorIcons\")", "", [F.make_param("icon_name", "String", "\"Node2D\"", "Named", "The editor icon's name - usually a class name like Node2D, Script or Folder.", "editor_icon")], CAT_PANELS, "Editor.Icon({icon_name})")
		.described("One of the editor's own icons, so a tool's buttons and docks look like the editor around them instead of shipping their own art. The field draws the icon it names as you pick it."))
	descriptors.append(F.make_descriptor("Core", "EditorPreference", "Editor Preference", ACEDescriptor.ACEType.EXPRESSION, "EditorInterface.get_editor_settings().get_setting({path})", "", [F.make_param("path", "String", "\"interface/theme/base_color\"", "Named", "The Editor Settings path, as it reads in Editor > Editor Settings.", "editor_preference")], CAT_PROJECT, "Editor.Preference({path})")
		.described("One value out of the user's own Editor Settings - their theme colour, grid step, font size. Read it so a tool matches the editor the person in front of it actually set up."))
	descriptors.append(F.make_descriptor("Core", "ProjectSetting", "Project Setting", ACEDescriptor.ACEType.EXPRESSION, "ProjectSettings.get_setting({path})", "", [F.make_param("path", "String", "\"application/config/name\"", "Named", "The Project Settings path, as it reads in Project > Project Settings.", "project_setting")], CAT_PROJECT, "Project.Setting({path})")
		.described("One value out of this project's own settings. Unlike a preference, it is saved with the project, so every person opening it sees the same answer."))
	descriptors.append(F.make_descriptor("Core", "EditorMainScreen", "Workspace Area", ACEDescriptor.ACEType.EXPRESSION, "EditorInterface.get_editor_main_screen()", "", [], CAT_PANELS, "Editor.MainScreen")
		.described("The big area the 2D, 3D and Script tabs share. A workspace plugin adds its own screen as a child of this."))

	# ── The project's settings (read above, written here) ──
	descriptors.append(F.make_descriptor("Core", "SetProjectSetting", "Set Setting", ACEDescriptor.ACEType.ACTION, "ProjectSettings.set_setting({path}, {value})", "", [F.make_param("path", "String", "\"application/config/name\"", "Named", "The Project Settings path to write.", "project_setting"), F.make_param("value", "Variant", "\"\"", "To", "The value to store there.", "expression")], CAT_PROJECT, "Set setting {path} to {value}")
		.described("Writes one project setting. It lives in memory until Save settings runs, so a tool that changes several settings writes them all and saves once."))
	descriptors.append(F.make_descriptor("Core", "SaveProjectSettings", "Save Settings", ACEDescriptor.ACEType.ACTION, "ProjectSettings.save()", "", [], CAT_PROJECT, "Save settings")
		.described("Writes the project settings back to project.godot. Without this, everything Set setting changed is lost when the editor closes."))

	# ── Moving the editor around ──
	descriptors.append(F.make_descriptor("Core", "SwitchToWorkspace", "Switch To Workspace", ACEDescriptor.ACEType.ACTION, "EditorInterface.set_main_screen_editor({workspace})", "", [_workspace_param()], CAT_PANELS, "Switch to workspace {workspace}")
		.described("Brings one of the editor's top tabs to the front - the same click as pressing 2D or Script yourself."))
	descriptors.append(F.make_descriptor("Core", "ShowInProjectBar", "Show In Project Bar", ACEDescriptor.ACEType.ACTION, "EditorInterface.get_file_system_dock().navigate_to_path({path})", "", [F.make_param("path", "String", "\"res://\"", "Path", "The folder or file to reveal, as a res:// path.", "expression")], CAT_PANELS, "Show in Project bar {path}")
		.described("Reveals a folder or file in the editor's project file list and selects it - what a tool does after it writes something, so the reader can see what just landed."))
	descriptors.append(F.make_descriptor("Core", "OpenScriptAtLine", "Open Script At Line", ACEDescriptor.ACEType.ACTION, "EditorInterface.get_script_editor().goto_line({line})", "", [F.make_param("line", "int", "0", "Line", "The line to jump to, counted from zero.", "expression")], CAT_PANELS, "Open script at line {line}")
		.described("Jumps the script editor to a line of the script it already has open - how a tool points at the thing it is complaining about."))
	descriptors.append(F.make_descriptor("Core", "AddEditorWindow", "Add Window", ACEDescriptor.ACEType.ACTION, "EditorInterface.get_base_control().add_child({window})", "", [F.make_param("window", "Node", "Window.new()", "Window", "The window or dialog to hang on the editor.", "expression")], CAT_PANELS, "Add window {window} to the editor's root")
		.described("Puts a window or dialog under the editor's own root, which is what makes it show up with the editor's theme and stay on top of it. Free it again when the plugin is disabled."))
	descriptors.append(F.make_descriptor("Core", "AddCommandPaletteCommand", "Add Command", ACEDescriptor.ACEType.ACTION, "EditorInterface.get_command_palette().add_command({title}, {key_name}, {handler})", "", [F.make_param("title", "String", "\"My Command\"", "Named", "The words the command palette shows.", "expression"), F.make_param("key_name", "String", "\"my_plugin/my_command\"", "Keyed", "The unique key the palette files it under.", "expression"), F.make_param("handler", "Callable", "_run_tool", "Calls", "The function to run when the command is chosen.", "expression")], CAT_PANELS, "Add command {title}")
		.described("Adds one entry to the editor's command palette (Ctrl+Shift+P), so a tool is reachable without a menu of its own."))

	# ── The bottom row of panels (the one Output and Debugger live in) ──
	descriptors.append(F.make_descriptor("Core", "AddBottomPanel", "Add Bottom Panel", ACEDescriptor.ACEType.ACTION, "add_control_to_bottom_panel({control}, {title})", "", [F.make_param("control", "Control", "Control.new()", "Panel", "The Control to show in the bottom row.", "expression"), F.make_param("title", "String", "\"My Panel\"", "Titled", "The words on its tab, beside Output and Debugger.", "expression")], CAT_PANELS, "Add bottom panel {control} titled {title}")
		.described("Adds a tab to the row Output and Debugger share, at the bottom of the editor. Remove it on plugin disabled or the row keeps a tab nobody owns."))
	descriptors.append(F.make_descriptor("Core", "RemoveBottomPanel", "Remove Bottom Panel", ACEDescriptor.ACEType.ACTION, "remove_control_from_bottom_panel({control})", "", [F.make_param("control", "Control", "Control.new()", "Panel", "The Control that was added to the bottom row.", "expression")], CAT_PANELS, "Remove bottom panel {control}")
		.described("Takes the plugin's tab back out of the bottom row."))

	# ── Two things the editor tells a tool about ──
	descriptors.append(F.make_descriptor("Core", "OnProjectFilesChanged", "On Project Files Changed", ACEDescriptor.ACEType.TRIGGER, "", "filesystem_changed", [], CAT_PROJECT, "On project files changed")
		.described("Runs whenever the project's files change on disk - something was imported, moved, deleted or added. The place to rescan whatever a tool keeps a list of."))
	descriptors.append(F.make_descriptor("Core", "OnPreferencesChanged", "On Preferences Changed", ACEDescriptor.ACEType.TRIGGER, "", "settings_changed", [], CAT_PROJECT, "On preferences changed")
		.described("Runs when the user changes anything in Editor Settings. Re-read the preferences a tool draws with, so it follows the theme instead of keeping the old one."))

	return descriptors


## Blurbs for the two pages this module opens, so a reader clicking the folder is told what the page
## is for before reading a single row.
static func section_descriptions() -> Dictionary:
	return {
		CAT_PROJECT: "This project's settings and the user's own Editor Settings - read one, write one, save them, and hear about it when either changes.",
		CAT_PANELS: "The editor's own surfaces: its icons, its workspace tabs, its Project bar, its script editor and its command palette.",
	}


## The workspace dropdown. `display_option_labels` is what makes the row read "Switch to workspace 2D"
## while the emitted line still carries the quoted string Godot's own method wants.
static func _workspace_param() -> ACEParam:
	var parameter: ACEParam = F.make_param("workspace", "String", "\"2D\"", "To", "Which of the editor's top tabs to bring forward.", "", WORKSPACES)
	parameter.display_option_labels = true
	return parameter
