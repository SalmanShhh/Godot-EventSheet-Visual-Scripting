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

const CAT := "Editor Tools"

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
	descriptors.append(F.make_descriptor("Core", "OnPluginEnabled", "On Plugin Enabled", ACEDescriptor.ACEType.TRIGGER, "", "_enter_tree", [], CAT, "On plugin enabled")
		.described("Runs when the plugin is switched on - at editor start, or the moment you tick it in Project Settings. This is where a plugin hangs its dock, adds its Tools menu item and teaches the editor its object types."))
	descriptors.append(F.make_descriptor("Core", "OnPluginDisabled", "On Plugin Disabled", ACEDescriptor.ACEType.TRIGGER, "", "_exit_tree", [], CAT, "On plugin disabled")
		.described("Runs when the plugin is switched off or the editor closes. Undo here everything On plugin enabled did, or the editor keeps a dock nobody owns."))
	# W2 - what `_edit` actually is: the editor HANDED this plugin an object to edit, because the
	# plugin answered yes when asked whether it could. "On object selected" said only half of that,
	# and sent a reader looking for a selection change that never fires for objects this plugin
	# refused. The ace_id and the callback behind it are unchanged; only the words are.
	descriptors.append(F.make_descriptor("Core", "OnEditorObjectSelected", "On Object Handed To Plugin", ACEDescriptor.ACEType.TRIGGER, "", "_edit", [], CAT, "On object handed to plugin")
		.described("Runs when the editor hands this plugin an object to edit - the user selected something this plugin said yes to. The object arrives as `object`."))

	# ── The 2D viewport (the overlay pass and the gizmo pass) ──
	descriptors.append(F.make_descriptor("Core", "OnDrawOver2DViewport", "On Draw Over 2D Viewport", ACEDescriptor.ACEType.TRIGGER, "", "_forward_canvas_draw_over_viewport", [], CAT, "On draw over 2D viewport")
		.described("The editor's 2D overlay pass. Draw handles, guides or labels on top of the scene with the Drawing actions - the surface arrives as `overlay`."))
	descriptors.append(F.make_descriptor("Core", "On2DViewportInput", "On 2D Viewport Input", ACEDescriptor.ACEType.TRIGGER, "", "_forward_canvas_gui_input", [], CAT, "On 2D viewport input")
		.described("Input that lands in the editor's 2D viewport, before the viewport itself sees it. End the event with Stop This Input Here to keep the viewport from also acting on it."))
	descriptors.append(F.make_descriptor("Core", "OnDrawGizmo", "On Draw Gizmo", ACEDescriptor.ACEType.TRIGGER, "", "_redraw", [], CAT, "On draw gizmo")
		.described("A gizmo's own paint pass - what an EditorNode3DGizmo redraws when its node moves or changes."))

	# ── What a plugin adds to the editor, and takes away again ──
	descriptors.append(F.make_descriptor("Core", "AddToolsMenuItem", "Add Tools Menu Item", ACEDescriptor.ACEType.ACTION, "add_tool_menu_item({title}, {handler})", "", [F.make_param("title", "String", "\"My Tool\"", "Title", "The words the item shows in Project > Tools.", "expression"), F.make_param("handler", "Callable", "_run_tool", "Calls", "The function to run when the item is picked.", "expression")], CAT, "Add Tools menu item {title}")
		.described("Adds an item to the editor's Project > Tools menu. Remove it again on plugin disabled or the menu keeps a dead entry."))
	descriptors.append(F.make_descriptor("Core", "RemoveToolsMenuItem", "Remove Tools Menu Item", ACEDescriptor.ACEType.ACTION, "remove_tool_menu_item({title})", "", [F.make_param("title", "String", "\"My Tool\"", "Title", "The title the item was added with.", "expression")], CAT, "Remove Tools menu item {title}")
		.described("Takes the plugin's item back out of Project > Tools."))
	descriptors.append(F.make_descriptor("Core", "AddEditorDock", "Add Dock", ACEDescriptor.ACEType.ACTION, "add_control_to_dock({slot}, {control})", "", [F.make_param("control", "Control", "Control.new()", "Dock", "The Control to hang in the editor as a dock.", "expression"), _dock_slot_param()], CAT, "Add dock {control} at {slot}")
		.described("Hangs a Control in one of the editor's dock slots. Remove it on plugin disabled - a dock left behind survives the plugin."))
	descriptors.append(F.make_descriptor("Core", "RemoveEditorDock", "Remove Dock", ACEDescriptor.ACEType.ACTION, "remove_control_from_docks({control})", "", [F.make_param("control", "Control", "Control.new()", "Dock", "The Control that was added as a dock.", "expression")], CAT, "Remove dock {control}")
		.described("Takes a dock back out of the editor."))
	descriptors.append(F.make_descriptor("Core", "AddEditorObjectType", "Add Object Type", ACEDescriptor.ACEType.ACTION, "add_custom_type({type_name}, {base}, {script}, {icon})", "", [F.make_param("type_name", "String", "\"Waypoint\"", "Named", "The name the editor's Create Node dialog will show.", "expression"), F.make_param("base", "String", "\"Node2D\"", "A", "The built-in class it extends.", "expression"), F.make_param("script", "Script", "null", "Script", "The script the new object gets.", "expression"), F.make_param("icon", "Texture2D", "null", "Icon", "The icon it shows in the Scene dock. Leave null for the base class icon.", "expression")], CAT, "Add object type {type_name}")
		.described("Teaches the editor a new object type, so it shows up in Create Node like a built-in one."))
	descriptors.append(F.make_descriptor("Core", "RemoveEditorObjectType", "Remove Object Type", ACEDescriptor.ACEType.ACTION, "remove_custom_type({type_name})", "", [F.make_param("type_name", "String", "\"Waypoint\"", "Named", "The name the type was added with.", "expression")], CAT, "Remove object type {type_name}")
		.described("Takes a custom object type back out of the Create Node dialog."))
	# W15 - the panel these two register an add-on with is the one the sheet calls the Properties
	# bar, everywhere else it names it. Same ace_ids, same emitted calls; the words catch up.
	descriptors.append(F.make_descriptor("Core", "AddEditorInspectorPlugin", "Add Properties Bar Add-on", ACEDescriptor.ACEType.ACTION, "add_inspector_plugin({plugin})", "", [F.make_param("plugin", "EditorInspectorPlugin", "null", "Add-on", "The Properties bar add-on that draws the custom fields.", "expression")], CAT, "Add Properties bar add-on {plugin}")
		.described("Registers a Properties bar add-on, so your own buttons and fields appear in the Properties bar beside the object's own."))
	descriptors.append(F.make_descriptor("Core", "RemoveEditorInspectorPlugin", "Remove Properties Bar Add-on", ACEDescriptor.ACEType.ACTION, "remove_inspector_plugin({plugin})", "", [F.make_param("plugin", "EditorInspectorPlugin", "null", "Add-on", "The Properties bar add-on that was registered.", "expression")], CAT, "Remove Properties bar add-on {plugin}")
		.described("Takes a Properties bar add-on back out."))
	descriptors.append(F.make_descriptor("Core", "UpdateViewportOverlays", "Redraw Viewport Overlays", ACEDescriptor.ACEType.ACTION, "update_overlays()", "", [], CAT, "redraw viewport overlays")
		.described("Asks the editor to run the overlay pass again, so On draw over 2D viewport repaints."))

	# ── What the editor can be asked (the expressions the picker offers) ──
	descriptors.append(F.make_descriptor("Core", "EditorSettingsObject", "Editor Settings", ACEDescriptor.ACEType.EXPRESSION, "EditorInterface.get_editor_settings()", "", [], CAT, "editor settings")
		.described("The editor's own settings object - read a user's grid step, theme or font size from it."))
	descriptors.append(F.make_descriptor("Core", "EditorUndoHistory", "Undo History", ACEDescriptor.ACEType.EXPRESSION, "get_undo_redo()", "", [], CAT, "the editor's undo history")
		.described("The editor's undo / redo history. Put it in a local object variable and add do / undo steps to it, so Ctrl+Z reverses what your tool changed."))

	return descriptors


## The dock-slot dropdown. `display_option_labels` is what makes the ROW say "at left, top" while the
## emitted line still carries the engine constant - the reader gets the corner they can point at, the
## generated GDScript gets what Godot needs.
static func _dock_slot_param() -> ACEParam:
	var parameter: ACEParam = F.make_param("slot", "int", "EditorPlugin.DOCK_SLOT_LEFT_UL", "At", "Which of the editor's eight dock slots it goes in.", "", DOCK_SLOTS)
	parameter.display_option_labels = true
	return parameter
