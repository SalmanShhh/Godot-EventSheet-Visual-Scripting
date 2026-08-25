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
	descriptors.append(F.make_descriptor("Core", "OnPluginEnabled", "On Plugin Enabled", ACEDescriptor.ACEType.TRIGGER, "", "_enter_tree", [], CAT_LIFECYCLE, "On plugin enabled")
		.described("Runs when the plugin is switched on - at editor start, or the moment you tick it in Project Settings. This is where a plugin hangs its dock, adds its Tools menu item and teaches the editor its object types."))
	descriptors.append(F.make_descriptor("Core", "OnPluginDisabled", "On Plugin Disabled", ACEDescriptor.ACEType.TRIGGER, "", "_exit_tree", [], CAT_LIFECYCLE, "On plugin disabled")
		.described("Runs when the plugin is switched off or the editor closes. Undo here everything On plugin enabled did, or the editor keeps a dock nobody owns."))
	# What `_edit` actually is: the editor HANDED this plugin an object to edit, because the
	# plugin answered yes when asked whether it could. "On object selected" said only half of that,
	# and sent a reader looking for a selection change that never fires for objects this plugin
	# refused. The ace_id and the callback behind it are unchanged; only the words are.
	descriptors.append(F.make_descriptor("Core", "OnEditorObjectSelected", "On Object Handed To Plugin", ACEDescriptor.ACEType.TRIGGER, "", "_edit", [], CAT_LIFECYCLE, "On object handed to plugin")
		.described("Runs when the editor hands this plugin an object to edit - the user selected something this plugin said yes to. The object arrives as `object`."))

	# ── The 2D viewport (the overlay pass and the gizmo pass) ──
	descriptors.append(F.make_descriptor("Core", "OnDrawOver2DViewport", "On Draw Over 2D Viewport", ACEDescriptor.ACEType.TRIGGER, "", "_forward_canvas_draw_over_viewport", [], CAT_LIFECYCLE, "On draw over 2D viewport")
		.described("The editor's 2D overlay pass. Draw handles, guides or labels on top of the scene with the Drawing actions - the surface arrives as `overlay`."))
	descriptors.append(F.make_descriptor("Core", "On2DViewportInput", "On 2D Viewport Input", ACEDescriptor.ACEType.TRIGGER, "", "_forward_canvas_gui_input", [], CAT_LIFECYCLE, "On 2D viewport input")
		.described("Input that lands in the editor's 2D viewport, before the viewport itself sees it. End the event with Stop This Input Here to keep the viewport from also acting on it."))
	descriptors.append(F.make_descriptor("Core", "OnDrawGizmo", "On Draw Gizmo", ACEDescriptor.ACEType.TRIGGER, "", "_redraw", [], CAT_LIFECYCLE, "On draw gizmo")
		.described("A gizmo's own paint pass - what an EditorNode3DGizmo redraws when its node moves or changes."))

	# ── What a plugin adds to the editor, and takes away again ──
	descriptors.append(F.make_descriptor("Core", "AddToolsMenuItem", "Add Tools Menu Item", ACEDescriptor.ACEType.ACTION, "add_tool_menu_item({title}, {handler})", "", [F.make_param("title", "String", "\"My Tool\"", "Title", "The words the item shows in Project > Tools.", "expression"), F.make_param("handler", "Callable", "_run_tool", "Calls", "The function to run when the item is picked.", "expression")], CAT_PANELS, "Add Tools menu item {title}")
		.described("Adds an item to the editor's Project > Tools menu. Remove it again on plugin disabled or the menu keeps a dead entry."))
	descriptors.append(F.make_descriptor("Core", "RemoveToolsMenuItem", "Remove Tools Menu Item", ACEDescriptor.ACEType.ACTION, "remove_tool_menu_item({title})", "", [F.make_param("title", "String", "\"My Tool\"", "Title", "The title the item was added with.", "expression")], CAT_PANELS, "Remove Tools menu item {title}")
		.described("Takes the plugin's item back out of Project > Tools."))
	descriptors.append(F.make_descriptor("Core", "AddEditorDock", "Add Dock", ACEDescriptor.ACEType.ACTION, "add_control_to_dock({slot}, {control})", "", [F.make_param("control", "Control", "Control.new()", "Dock", "The Control to hang in the editor as a dock.", "expression"), _dock_slot_param()], CAT_PANELS, "Add dock {control} at {slot}")
		.described("Hangs a Control in one of the editor's dock slots. Remove it on plugin disabled - a dock left behind survives the plugin."))
	descriptors.append(F.make_descriptor("Core", "RemoveEditorDock", "Remove Dock", ACEDescriptor.ACEType.ACTION, "remove_control_from_docks({control})", "", [F.make_param("control", "Control", "Control.new()", "Dock", "The Control that was added as a dock.", "expression")], CAT_PANELS, "Remove dock {control}")
		.described("Takes a dock back out of the editor."))
	descriptors.append(F.make_descriptor("Core", "AddEditorObjectType", "Add Object Type", ACEDescriptor.ACEType.ACTION, "add_custom_type({type_name}, {base}, {script}, {icon})", "", [F.make_param("type_name", "String", "\"Waypoint\"", "Named", "The name the editor's Create Node dialog will show.", "expression"), F.make_param("base", "String", "\"Node2D\"", "A", "The built-in class it extends.", "expression"), F.make_param("script", "Script", "null", "Script", "The script the new object gets.", "expression"), F.make_param("icon", "Texture2D", "null", "Icon", "The icon it shows in the Scene dock. Leave null for the base class icon.", "expression")], CAT_PANELS, "Add object type {type_name}")
		.described("Teaches the editor a new object type, so it shows up in Create Node like a built-in one."))
	descriptors.append(F.make_descriptor("Core", "RemoveEditorObjectType", "Remove Object Type", ACEDescriptor.ACEType.ACTION, "remove_custom_type({type_name})", "", [F.make_param("type_name", "String", "\"Waypoint\"", "Named", "The name the type was added with.", "expression")], CAT_PANELS, "Remove object type {type_name}")
		.described("Takes a custom object type back out of the Create Node dialog."))
	# The panel these two register an add-on with is the one the sheet calls the Properties
	# bar, everywhere else it names it. Same ace_ids, same emitted calls; the words catch up.
	descriptors.append(F.make_descriptor("Core", "AddEditorInspectorPlugin", "Add Properties Bar Add-on", ACEDescriptor.ACEType.ACTION, "add_inspector_plugin({plugin})", "", [F.make_param("plugin", "EditorInspectorPlugin", "null", "Add-on", "The Properties bar add-on that draws the custom fields.", "expression")], CAT_PROPERTIES, "Add Properties bar add-on {plugin}")
		.described("Registers a Properties bar add-on, so your own buttons and fields appear in the Properties bar beside the object's own."))
	descriptors.append(F.make_descriptor("Core", "RemoveEditorInspectorPlugin", "Remove Properties Bar Add-on", ACEDescriptor.ACEType.ACTION, "remove_inspector_plugin({plugin})", "", [F.make_param("plugin", "EditorInspectorPlugin", "null", "Add-on", "The Properties bar add-on that was registered.", "expression")], CAT_PROPERTIES, "Remove Properties bar add-on {plugin}")
		.described("Takes a Properties bar add-on back out."))
	descriptors.append(F.make_descriptor("Core", "UpdateViewportOverlays", "Redraw Viewport Overlays", ACEDescriptor.ACEType.ACTION, "update_overlays()", "", [], CAT_LIFECYCLE, "redraw viewport overlays")
		.described("Asks the editor to run the overlay pass again, so On draw over 2D viewport repaints."))

	# ── The menu, and the item that was chosen out of it ──────
	# The action writes the one line the reading recognises, and the trigger compiles into the one
	# handler every item of a menu shares - `match id:` with a case per item, which is the shape every
	# menu in Godot is already written in. So a menu picked here and a menu typed by hand are the same
	# file, and open as the same rows.
	descriptors.append(F.make_descriptor("Core", "MenuAddItem", "Add Item", ACEDescriptor.ACEType.ACTION, "{menu}.add_item({label}, {id})", "", [_menu_param(), F.make_param("label", "String", "\"New…\"", "Labelled", "The words the item shows in the menu.", "expression"), F.make_param("id", "int", "0", "Id", "The number this item sends when it is chosen. Give every item its own - two items sharing one id means the second one can never run.", "expression")], CAT_MENUS, "Add item {label} to {menu}")
		.described("Puts one item in a menu. The id is how the menu says which item was picked, so On Item Chosen answers the same number this row was given."))
	descriptors.append(F.make_descriptor("Core", "OnMenuItemChosen", "On Item Chosen", ACEDescriptor.ACEType.TRIGGER, "", "", [_menu_param(), F.make_param("item", "int", "0", "Item", "The id of the item this event answers - the same number Add Item gave it.", "expression")], CAT_MENUS, "On item {item} of {menu} chosen")
		.described("Runs when the user picks the item with this id out of the menu. Every item of one menu shares a single handler, so all of them stay together in the emitted file."))

	# ── What the editor can be asked (the expressions the picker offers) ──
	descriptors.append(F.make_descriptor("Core", "EditorSettingsObject", "Editor Settings", ACEDescriptor.ACEType.EXPRESSION, "EditorInterface.get_editor_settings()", "", [], CAT_PREFERENCES, "editor settings")
		.described("The editor's own settings object - read a user's grid step, theme or font size from it."))
	descriptors.append(F.make_descriptor("Core", "EditorUndoHistory", "Undo History", ACEDescriptor.ACEType.EXPRESSION, "get_undo_redo()", "", [], CAT_UNDO, "the editor's undo history")
		.described("The editor's undo / redo history. Put it in a local object variable and add do / undo steps to it, so Ctrl+Z reverses what your tool changed."))

	return descriptors


## Blurbs for the four pages this module opens, so a reader clicking the folder is told what the page
## is for before reading a single row. Panels & menus and Project & preferences are described by the
## module that opened them first - the merge keeps the first blurb registered for a name, so naming
## them again here would be a second answer to a settled question.
static func section_descriptions() -> Dictionary:
	return {
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
