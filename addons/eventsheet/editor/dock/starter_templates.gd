@tool
class_name EventSheetStarterTemplates
extends RefCounted

# "New from template" starter sheets (the New-Sheet ▾ menu / shortcut / command palette / Welcome).
#
# Owns the template PopupMenu and builds a fresh EventSheetResource for each built-in starter
# (platformer, top-down, 3D controllers, autoload singletons, a signal-driven behavior component)
# plus any project template dropped in res://eventsheet_templates/. Extracted from event_sheet_dock.gd
# so the dock stays focused; the dock keeps a thin _open_template_menu() delegate (so the menu item,
# the shortcut, the palette entry, and the Welcome button all keep calling the dock unchanged) and
# this class reaches back through the dock reference to adopt the new sheet (setup) + reset its
# title strip / undo history / dirty state and write the status bar.

var _dock: Control = null


func init(dock: Control) -> void:
	_dock = dock

var _template_menu: PopupMenu = null


func open_menu() -> void:
	_build_template_menu_items()
	_template_menu.popup(Rect2i(Vector2i(_dock.get_global_mouse_position()), Vector2i(0, 0)))

## Rebuilt on every open so project templates (res://eventsheet_templates/, ids 100+)
## appear the moment a .tres lands in the folder - same zero-config convention as
## eventsheet_addons/.
var _project_template_paths: PackedStringArray = PackedStringArray()


func _build_template_menu_items() -> void:
	if _template_menu == null:
		_template_menu = PopupMenu.new()
		_template_menu.id_pressed.connect(_new_sheet_from_template)
		_dock.add_child(_template_menu)
	_template_menu.clear()
	# The creation-time ASK: what kind of Godot script is this sheet for? Sections mirror
	# EventSheetScriptIntent so a newcomer discovers custom resources and editor tools at the
	# same moment they discover behaviours - without a wizard slowing every creation down.
	_template_menu.add_separator("Scripts on a node")
	_template_menu.add_item("Blank Sheet", 0)
	_template_menu.add_item("Platformer Starter", 1)
	_template_menu.add_item("Top-down Starter", 2)
	_template_menu.add_item("First-Person Controller (3D)", 6)
	_template_menu.add_item("Third-Person Mover (3D)", 7)
	_template_menu.add_separator("Behaviours - attach under a node")
	_template_menu.add_item("Behavior Component (signal-driven)", 8)
	_template_menu.add_separator("Autoloads - project-wide singletons")
	_template_menu.add_item("Game State (Autoload)", 3)
	_template_menu.add_item("Event Bus (Autoload)", 4)
	_template_menu.add_item("Save System (Autoload)", 5)
	_template_menu.add_separator("Systems - run over a group of entities")
	_template_menu.add_item("Entity System (Autoload)", 11)
	_template_menu.add_separator("Custom Resources - data assets (.tres)")
	_template_menu.add_item("Custom Resource (data + logic)", 9)
	_template_menu.add_separator("Editor Tools - run inside the editor")
	# W17. Fifteen shapes is too many to read as a flat run in a menu that also offers game starters,
	# so the whole family lives behind one entry - the mockup's "New Sheet ▸ Editor tool" list. The
	# four R33 shapes keep their ids and their exact words; the other eleven are new.
	_template_menu.add_submenu_node_item("Editor Tool…", _build_editor_tool_menu())
	_project_template_paths = EventSheetTemplates.list_templates()
	# (the project-templates section follows the submenu above)
	if not _project_template_paths.is_empty():
		_template_menu.add_separator("Project templates")
		for index in _project_template_paths.size():
			_template_menu.add_item(_project_template_paths[index].get_file().get_basename().capitalize(), 100 + index)


## W17. Every shape Godot's editor can be extended in, as {id, label, note} in the order the mockup
## fixed. The note is the second column of that list - what the shape IS, in the words a reader who
## has never opened Godot's class reference would use. One table, so the submenu, the FileSystem
## Create New dialog and the Manual cannot drift from each other.
const EDITOR_TOOL_SHAPES: Array[Dictionary] = [
	{"id": 10, "label": "One-click chore", "note": "run it yourself, from the sheet's bar"},
	{"id": 12, "label": "Editor plugin", "note": "the editor switches it on and off"},
	{"id": 13, "label": "Importer add-on", "note": "runs when files are imported"},
	{"id": 14, "label": "Export hook", "note": "runs when the project is exported"},
	{"id": 15, "label": "Dock panel", "note": "a panel beside the Scene dock"},
	{"id": 16, "label": "Bottom panel", "note": "beside Output and Debugger"},
	{"id": 17, "label": "Tools menu item", "note": "Project > Tools > your entry"},
	{"id": 18, "label": "Properties bar add-on", "note": "buttons and editors in the Inspector"},
	{"id": 19, "label": "Context menu item", "note": "right-click in the Scene dock or Project bar"},
	{"id": 20, "label": "Layout view handle", "note": "draw over the 2D view"},
	{"id": 21, "label": "Thumbnail maker", "note": "previews for a file type"},
	{"id": 22, "label": "Debugger panel", "note": "a tab while the game runs"},
	{"id": 23, "label": "Command tool", "note": "headless, run with arguments"},
	{"id": 24, "label": "Test sheet", "note": "check rows and a verdict"},
	{"id": 25, "label": "Object type", "note": "a node of your own in Create Node"},
]

var _editor_tool_menu: PopupMenu = null


## The "Editor Tool…" submenu: one entry per shape, each reading "<what it is> - <where it shows up>"
## so the choice is made on the words rather than on a Godot class name.
func _build_editor_tool_menu() -> PopupMenu:
	if _editor_tool_menu == null:
		_editor_tool_menu = PopupMenu.new()
		_editor_tool_menu.name = "EditorToolShapes"
		_editor_tool_menu.id_pressed.connect(_new_sheet_from_template)
	_editor_tool_menu.clear()
	for shape: Dictionary in EDITOR_TOOL_SHAPES:
		_editor_tool_menu.add_item("%s - %s" % [str(shape["label"]), str(shape["note"])], int(shape["id"]))
	return _editor_tool_menu


## A signal-driven BEHAVIOR COMPONENT starter - the Godot composition idiom modelled by example, so a
## newcomer's first copy is NOT a monolithic god-sheet. It compiles to an attachable Node with a typed
## `host` accessor (its parent), reacts to the host's body_entered SIGNAL (no per-frame polling), and
## emits its own (On Collected) so other sheets stay decoupled. `value` is an exported designer knob.
static func _build_behavior_component_starter() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "Area2D"
	sheet.custom_class_name = "PickupBehavior"
	sheet.variables = {"value": {"type": "int", "default": 1, "exported": true}}
	var about: CommentRow = CommentRow.new()
	about.text = "[b]Behavior Component[/b] - Godot's answer to a node-attached behavior. Instead of one big sheet on the root, this is a small reusable piece you ATTACH as a child of the node it controls (here, an Area2D pickup); it compiles to a Node, and [code]host[/code] is the node it is attached to.\nIt REACTS to a signal (the host's body_entered) instead of checking every frame, and EMITS its own (On Collected) so other sheets stay decoupled. [code]value[/code] is a designer knob in the Inspector."
	sheet.events.append(about)
	var declared_signal: RawCodeRow = RawCodeRow.new()
	declared_signal.code = "## @ace_trigger\n## @ace_name(\"On Collected\")\n## @ace_category(\"Pickup\")\nsignal collected(by: Node, amount: int)"
	sheet.events.append(declared_signal)
	var on_ready: EventRow = EventRow.new()
	on_ready.trigger_provider_id = "Core"
	on_ready.trigger_id = "OnReady"
	var connect_signal: RawCodeRow = RawCodeRow.new()
	connect_signal.code = "if host != null:\n\thost.body_entered.connect(func(body: Node) -> void:\n\t\tcollected.emit(body, value)\n\t\thost.queue_free()\n\t)"
	on_ready.actions.append(connect_signal)
	sheet.events.append(on_ready)
	return sheet


## A CUSTOM RESOURCE starter - Godot's data-asset idiom modelled by example, so a newcomer's
## first resource sheet steers toward its full potential: exported variables ARE the asset's
## designer-editable fields, logic lives in functions (resources have no _process), and a signal
## lets live data notify listeners. Each .tres created from the compiled class is its own asset.
## An ENTITY SYSTEM starter (composition / ECS-lite): a system runs its step over every entity in a
## GROUP each frame, instead of copying logic onto every node. Compiles to an autoload singleton with an
## OnProcess that loops get_nodes_in_group - the Godot-native "systems over groups" pattern. Tag entities
## with add_to_group, rename the group + autoload for your own, and add more systems as more autoloads.
static func _build_system_starter() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.autoload_mode = true
	sheet.autoload_name = "EnemySystem"
	sheet.host_class = "Node"
	sheet.custom_class_name = "EnemySystem"
	sheet.class_description = "A SYSTEM (composition / ECS-lite): it runs over every entity in a group each frame, instead of putting logic on each node. Tag entities into the \"enemy\" group with add_to_group, rename the group + autoload for your own, and register this sheet as an autoload."
	var note: CommentRow = CommentRow.new()
	note.text = "[b]Entity System (Autoload)[/b] - composition / ECS-lite. Tag entities into a group and this runs once per frame for every one of them. Add more systems as more autoload sheets. Prefer signals over polling for big sets, and the Time Slicer pack to spread heavy sweeps."
	sheet.events.append(note)
	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"
	tick.trigger_id = "OnProcess"
	var body: RawCodeRow = RawCodeRow.new()
	body.code = "\n".join(PackedStringArray([
		"# A system runs its step over every entity in the group. Tag nodes with add_to_group(\"enemy\").",
		"for entity: Node in get_tree().get_nodes_in_group(\"enemy\"):",
		"\tif entity is Node2D:",
		"\t\t# Example: drift every enemy slowly to the right - replace with your system's logic.",
		"\t\t(entity as Node2D).position += Vector2(20.0, 0.0) * delta"
	]))
	tick.actions.append(body)
	sheet.events.append(tick)
	return sheet


static func _build_custom_resource_starter() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Resource"
	sheet.custom_class_name = "LootTable"
	sheet.variables = {
		"entries": {"type": "Array", "default": [], "exported": true, "attributes": {"tooltip": "One item name per entry - duplicates raise the odds."}},
		"fallback": {"type": "String", "default": "coin", "exported": true},
		# Two real inspector options as living documentation: a bounded slider with an open top,
		# and a file picker - the exact annotations show in the variable dialog's "Ships as:" strip.
		"rolls": {"type": "int", "default": 1, "exported": true, "attributes": {"range": {"min": "1", "max": "10", "step": "1", "or_greater": true}, "tooltip": "How many items one roll yields."}},
		"pickup_sound": {"type": "String", "default": "", "exported": true, "attributes": {"file": {"mode": "file", "filters": ["*.ogg", "*.wav"]}, "tooltip": "Played when the loot is picked up."}},
	}
	var about: CommentRow = CommentRow.new()
	about.text = "[b]Custom Resource[/b] - a data asset with logic. The exported variables become fields designers edit per-.tres file (right-click the FileSystem dock > New Resource > LootTable once this compiles). Resources have no _process or _ready: give them [b]functions[/b] instead of events, and call those from the sheets that load the asset."
	sheet.events.append(about)
	var roll: EventFunction = EventFunction.new()
	roll.function_name = "roll"
	roll.return_type = TYPE_STRING
	roll.expose_as_ace = true
	roll.ace_display_name = "Roll Loot"
	roll.ace_category = "Loot"
	var roll_body: RawCodeRow = RawCodeRow.new()
	roll_body.code = "if entries.is_empty():\n\treturn fallback\nreturn str(entries.pick_random())"
	roll.events.append(roll_body)
	sheet.functions.append(roll)
	return sheet


## An EDITOR TOOL starter - an EditorScript with @tool, run from the script editor (File > Run).
## Modelled small: one On Editor Run event doing a visible, safe chore, so the shape ("events
## that run IN the editor, not in the game") lands immediately.
static func _build_editor_tool_starter() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "EditorScript"
	sheet.tool_mode = true
	sheet.custom_class_name = ""
	var about: CommentRow = CommentRow.new()
	about.text = "[b]Editor Tool[/b] - these events run inside the EDITOR when you run the compiled script (script editor > File > Run), never in the game. Great for batch renames, scene checks, and one-click project chores."
	sheet.events.append(about)
	var run_event: EventRow = EventRow.new()
	run_event.trigger_provider_id = "Core"
	run_event.trigger_id = "OnEditorRun"
	var chore: RawCodeRow = RawCodeRow.new()
	chore.code = "var scene_root: Node = EditorInterface.get_edited_scene_root()\nif scene_root == null:\n\tprint(\"Open a scene first.\")\nelse:\n\tprint(\"%s has %d nodes.\" % [scene_root.name, scene_root.get_child_count()])"
	run_event.actions.append(chore)
	sheet.events.append(run_event)
	return sheet


## R33 - an EDITOR PLUGIN starter. Where the Editor Tool starter above is a chore you press Run on,
## a plugin is something the editor SWITCHES ON: it arrives with the pair of events that shape says
## (add the Tools menu item when the plugin is enabled, take it away again when it is disabled) plus
## the function the menu item calls, so the very first compile is a plugin that already works.
static func _build_editor_plugin_starter() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "EditorPlugin"
	sheet.tool_mode = true
	var about: CommentRow = CommentRow.new()
	about.text = "[b]Editor Plugin[/b] - the editor switches this on and off, and while it is on it adds things to the editor itself: a Tools menu item, a dock, an object type, an Inspector button. Everything On plugin enabled adds, On plugin disabled must take away again.\nSheet Type… ▸ Editor Plugin has a tick for each of those, and the Include bar has Enable plugin."
	sheet.events.append(about)
	var enabled: EventRow = EventRow.new()
	enabled.trigger_provider_id = "Core"
	enabled.trigger_id = "OnPluginEnabled"
	var add_item: ACEAction = ACEAction.new()
	add_item.provider_id = "Core"
	add_item.ace_id = "AddToolsMenuItem"
	add_item.codegen_template = "add_tool_menu_item({title}, {handler})"
	add_item.params = {"title": "\"Snap Selection\"", "handler": "_run_tool"}
	enabled.actions.append(add_item)
	sheet.events.append(enabled)
	var disabled: EventRow = EventRow.new()
	disabled.trigger_provider_id = "Core"
	disabled.trigger_id = "OnPluginDisabled"
	var remove_item: ACEAction = ACEAction.new()
	remove_item.provider_id = "Core"
	remove_item.ace_id = "RemoveToolsMenuItem"
	remove_item.codegen_template = "remove_tool_menu_item({title})"
	remove_item.params = {"title": "\"Snap Selection\""}
	disabled.actions.append(remove_item)
	sheet.events.append(disabled)
	var run_tool: EventFunction = EventFunction.new()
	run_tool.function_name = "_run_tool"
	var run_body: RawCodeRow = RawCodeRow.new()
	run_body.code = "for node: Node in EditorInterface.get_selection().get_selected_nodes():\n\tif node is Node2D:\n\t\t(node as Node2D).position = (node as Node2D).position.snapped(Vector2(16.0, 16.0))"
	run_tool.events.append(run_body)
	sheet.functions.append(run_tool)
	return sheet


## R33 - an IMPORT TOOL starter. One On File Imported event: the paths Godot just brought in arrive
## as `paths`, and the body only reports what landed - a first tool should never silently rewrite a
## designer's files, so the shape is "look at what arrived" and the editing is left to the reader.
static func _build_import_tool_starter() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "EditorScript"
	sheet.tool_mode = true
	var about: CommentRow = CommentRow.new()
	about.text = "[b]Import Tool[/b] - these events run just after Godot finishes importing files, with the paths that landed in [code]paths[/code]. Great for checking a texture's import settings, renaming what was dropped in, or keeping a manifest up to date.\nIt never runs in the game: the editor calls it, and an exported build simply never does."
	sheet.events.append(about)
	var imported: EventRow = EventRow.new()
	imported.trigger_provider_id = "Core"
	imported.trigger_id = "OnFileImported"
	var body: RawCodeRow = RawCodeRow.new()
	body.code = "for path: String in paths:\n\tif path.get_extension() == \"png\":\n\t\tprint(\"Imported image: %s\" % path)"
	imported.actions.append(body)
	sheet.events.append(imported)
	return sheet


## R33 - an EXPORT HOOK starter. The shipped On Project Export trigger with the smallest honest bake
## step: write the version stamp, and only outside a debug build, so the two facts the exporter hands
## a hook (`is_debug`, `features`) are both modelled the first time a reader sees the event.
static func _build_export_hook_starter() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "EditorScript"
	sheet.tool_mode = true
	var about: CommentRow = CommentRow.new()
	about.text = "[b]Export Hook[/b] - these events run as a project export begins, before the files are written. The place to stamp a build number, bake a data file, or strip debug content.\nKeep it synchronous: an export does not wait, so anything after an [code]await[/code] may miss the build."
	sheet.events.append(about)
	var exporting: EventRow = EventRow.new()
	exporting.trigger_provider_id = "Core"
	exporting.trigger_id = "OnProjectExport"
	var not_debug: ACECondition = ACECondition.new()
	not_debug.provider_id = "Core"
	not_debug.ace_id = "ExportIsDebug"
	not_debug.codegen_template = "is_debug"
	not_debug.negated = true
	exporting.conditions.append(not_debug)
	var stamp: RawCodeRow = RawCodeRow.new()
	stamp.code = "var config: ConfigFile = ConfigFile.new()\nconfig.set_value(\"build\", \"version\", ProjectSettings.get_setting(\"application/config/version\", \"0.0.0\"))\nconfig.save(\"res://build_stamp.cfg\")"
	exporting.actions.append(stamp)
	sheet.events.append(exporting)
	return sheet


# ── W17. The other eleven shapes Godot's editor has ──────────────────────────────────────────────
#
# R33 shipped four (chore / plugin / importer / export hook). Godot has fifteen ways to extend the
# editor, and a reader who wants "a panel" or "a button in the Inspector" should find it in the New
# Sheet list in those words and get EVENTS, not a class to go and look up.
#
# Every one of these is deliberately SMALL: the events that shape needs, with the body left blank.
# What each starter is really teaching is the pairing - whatever a plugin adds when it is switched
# on, it takes away again when it is switched off - and where the reader's own work goes. They are
# gated in both directions (compile the starter, open the result, and the same events come back).


## The head every tool starter shares: a @tool sheet on the class the editor calls, and the one
## comment line that says what the shape IS before a single event is read.
static func _tool_starter(host_class: String, about_text: String) -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = host_class
	sheet.tool_mode = true
	var about: CommentRow = CommentRow.new()
	about.text = about_text
	sheet.events.append(about)
	return sheet


## One plugin-lifecycle event (On plugin enabled / On plugin disabled) with its actions already in it.
static func _plugin_event(trigger_id: String, actions: Array) -> EventRow:
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = trigger_id
	for action: Variant in actions:
		event.actions.append(action)
	return event


## One picked action row. The template is passed in rather than looked up because a shipped template
## is a frozen promise: a starter that carried a paraphrase of it would emit a different line than
## the same row dropped from the picker, and the round-trip gate would catch it much later.
static func _tool_action(ace_id: String, template: String, params: Dictionary) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = ace_id
	action.codegen_template = template
	action.params = params
	return action


## A class-level declaration (the member a pair of events both reach for).
static func _member_row(code: String) -> RawCodeRow:
	var row: RawCodeRow = RawCodeRow.new()
	row.code = code
	return row


## One typed parameter of a function the EDITOR calls: the name and type are Godot's, not ours, so
## the compiled function has the exact header the editor looks for.
static func _fn_param(param_id: String, type_name: String) -> ACEParam:
	var parameter: ACEParam = ACEParam.new()
	parameter.id = param_id
	parameter.name = param_id
	parameter.type_name = type_name
	return parameter


## One callback function of an editor add-on: Godot's own name, arguments and answer type, with the
## reader's work left as a single line inside.
static func _callback_function(function_name: String, params: Array, return_type_name: String, body: String) -> EventFunction:
	var event_function: EventFunction = EventFunction.new()
	event_function.function_name = function_name
	for parameter: Variant in params:
		event_function.params.append(parameter)
	event_function.return_type_name = return_type_name
	event_function.events.append(_member_row(body))
	return event_function


## A DOCK PANEL: the plugin hangs a Control in one of the editor's eight dock slots, and takes it
## away again. The panel itself is left as an empty Control on purpose - what goes in it is a Panel
## sheet of the reader's own, and a starter that guessed at its contents would be in the way.
static func _build_dock_panel_starter() -> EventSheetResource:
	var sheet: EventSheetResource = _tool_starter("EditorPlugin", "[b]Dock panel[/b] - a panel of your own beside the editor's Scene and Import docks. On plugin enabled hangs it; On plugin disabled takes it down and frees it, or the editor keeps a dock nobody owns.\nBuild what goes inside it as a Control scene and load it into panel.")
	sheet.events.append(_member_row("var panel: Control = null"))
	sheet.events.append(_plugin_event("OnPluginEnabled", [
		_member_row("panel = Control.new()\npanel.name = \"My Panel\""),
		_tool_action("AddEditorDock", "add_control_to_dock({slot}, {control})", {"slot": "EditorPlugin.DOCK_SLOT_LEFT_BL", "control": "panel"}),
	]))
	sheet.events.append(_plugin_event("OnPluginDisabled", [
		_tool_action("RemoveEditorDock", "remove_control_from_docks({control})", {"control": "panel"}),
		_member_row("panel.queue_free()"),
	]))
	return sheet


## A BOTTOM PANEL: the same pairing, in the row Output and Debugger share.
static func _build_bottom_panel_starter() -> EventSheetResource:
	var sheet: EventSheetResource = _tool_starter("EditorPlugin", "[b]Bottom panel[/b] - a tab of your own in the row Output and Debugger live in. Same rule as a dock: whatever On plugin enabled adds, On plugin disabled takes away again.")
	sheet.events.append(_member_row("var panel: Control = null"))
	sheet.events.append(_plugin_event("OnPluginEnabled", [
		_member_row("panel = Control.new()"),
		_tool_action("AddBottomPanel", "add_control_to_bottom_panel({control}, {title})", {"control": "panel", "title": "\"My Panel\""}),
	]))
	sheet.events.append(_plugin_event("OnPluginDisabled", [
		_tool_action("RemoveBottomPanel", "remove_control_from_bottom_panel({control})", {"control": "panel"}),
		_member_row("panel.queue_free()"),
	]))
	return sheet


## A TOOLS MENU ITEM: one entry under Project > Tools, and the function it calls. The smallest shape
## that is still a real plugin - which is why it is the one a first tool usually wants.
static func _build_tools_menu_item_starter() -> EventSheetResource:
	var sheet: EventSheetResource = _tool_starter("EditorPlugin", "[b]Tools menu item[/b] - one entry under Project > Tools that runs a function of yours. Put the work in On My Tool below; On plugin disabled takes the entry back out.")
	sheet.events.append(_plugin_event("OnPluginEnabled", [
		_tool_action("AddToolsMenuItem", "add_tool_menu_item({title}, {handler})", {"title": "\"My Tool\"", "handler": "_run_tool"}),
	]))
	sheet.events.append(_plugin_event("OnPluginDisabled", [
		_tool_action("RemoveToolsMenuItem", "remove_tool_menu_item({title})", {"title": "\"My Tool\""}),
	]))
	sheet.functions.append(_callback_function("_run_tool", [], "void", "# What the menu item does. The editor's selection is Editor.SelectedObjects."))
	return sheet


## A PROPERTIES BAR ADD-ON: the four questions the Inspector asks a drawer of its own. Written as
## the callbacks Godot calls, so the sheet compiles to a class a plugin can hand over with
## Add Inspector plugin on plugin enabled.
static func _build_properties_bar_starter() -> EventSheetResource:
	var sheet: EventSheetResource = _tool_starter("EditorInspectorPlugin", "[b]Properties bar add-on[/b] - your own buttons and property editors in the Inspector. The editor asks whether you handle an object, then hands you each of its properties in turn.\nAn add-on does nothing on its own: make an Editor Plugin sheet too and give it Add Inspector plugin on plugin enabled.")
	sheet.functions.append(_callback_function("_can_handle", [_fn_param("object", "Object")], "bool", "return object is Node"))
	sheet.functions.append(_callback_function("_parse_begin", [_fn_param("object", "Object")], "void", "# Add your own controls above the object's properties with add_custom_control()."))
	return sheet


## A CONTEXT MENU ITEM: the right-click menu in the Scene dock or the Project bar.
static func _build_context_menu_starter() -> EventSheetResource:
	var sheet: EventSheetResource = _tool_starter("EditorContextMenuPlugin", "[b]Context menu item[/b] - your own entry in the right-click menu of the Scene dock or the Project bar. The editor calls this with whatever was right-clicked.\nRegister it from an Editor Plugin sheet with add_context_menu_plugin on plugin enabled.")
	sheet.functions.append(_callback_function("_popup_menu", [_fn_param("paths", "PackedStringArray")], "void", "# add_context_menu_item(\"My Item\", _on_chosen) - one call per entry you want."))
	return sheet


## A LAYOUT VIEW HANDLE: drawing on top of the 2D view, and getting the input that lands there
## first. Both triggers shipped with R34, so this shape is entirely events already.
static func _build_view_handle_starter() -> EventSheetResource:
	var sheet: EventSheetResource = _tool_starter("EditorPlugin", "[b]Layout view handle[/b] - draw guides, handles or labels over the editor's 2D view, and answer the input that lands there before the view does.\nAnswer true from the input event to keep the view from also acting on it.")
	var draw_event: EventRow = EventRow.new()
	draw_event.trigger_provider_id = "Core"
	draw_event.trigger_id = "OnDrawOver2DViewport"
	draw_event.actions.append(_member_row("# Draw on `overlay` - it is a Control, so the Drawing actions all work here."))
	sheet.events.append(draw_event)
	var input_event: EventRow = EventRow.new()
	input_event.trigger_provider_id = "Core"
	input_event.trigger_id = "On2DViewportInput"
	input_event.actions.append(_member_row("return false"))
	sheet.events.append(input_event)
	return sheet


## A THUMBNAIL MAKER: the two questions the editor asks before it draws a preview of a file.
static func _build_thumbnail_maker_starter() -> EventSheetResource:
	var sheet: EventSheetResource = _tool_starter("EditorResourcePreviewGenerator", "[b]Thumbnail maker[/b] - the little picture the editor draws for a file of your own type, in the Project bar and the file dialogs.\nRegister it from an Editor Plugin sheet with add_resource_preview_generator on plugin enabled.")
	sheet.functions.append(_callback_function("_handles", [_fn_param("type", "String")], "bool", "return type == \"Resource\""))
	sheet.functions.append(_callback_function("_generate", [_fn_param("resource", "Resource"), _fn_param("size", "Vector2i"), _fn_param("metadata", "Dictionary")], "Texture2D", "# Draw the preview and hand back a Texture2D, or null for no thumbnail.\nreturn null"))
	return sheet


## A DEBUGGER PANEL: a tab in the Debugger while the game runs, and the messages the running game
## sends it. The prefix is the contract between the two halves, so it is named once, in a constant.
static func _build_debugger_panel_starter() -> EventSheetResource:
	var sheet: EventSheetResource = _tool_starter("EditorDebuggerPlugin", "[b]Debugger panel[/b] - a tab of your own in the Debugger while the game is running, fed by messages the game sends.\nThe running game sends them with EngineDebugger.send_message; everything under one prefix arrives here.")
	sheet.events.append(_member_row("const MESSAGE_PREFIX: String = \"my_tool\""))
	sheet.functions.append(_callback_function("_has_capture", [_fn_param("capture", "String")], "bool", "return capture == MESSAGE_PREFIX"))
	sheet.functions.append(_callback_function("_capture", [_fn_param("message", "String"), _fn_param("data", "Array"), _fn_param("session_id", "int")], "bool", "# One message from the running game. Answer true when you handled it.\nreturn true"))
	return sheet


## A COMMAND TOOL: the script the Godot binary runs headless from the command line. `_init` is where
## it starts, the user's arguments arrive after the `--`, and the exit code is how whatever called it
## tells success from failure.
static func _build_command_tool_starter() -> EventSheetResource:
	var sheet: EventSheetResource = _tool_starter("SceneTree", "[b]Command tool[/b] - a script the Godot binary runs headless from the command line, with arguments and an exit code:\ngodot --headless --path . --script res://tools/my_tool.gd -- arg1\nEverything after the -- arrives as the arguments. Finish with code 1 when something went wrong, so a script calling this can tell.")
	sheet.functions.append(_callback_function("_init", [], "void", "var args: PackedStringArray = OS.get_cmdline_user_args()\n# What this tool does.\nquit()"))
	return sheet


## A TEST SHEET: claims about the project that a runner checks and reports pass / fail on.
static func _build_test_sheet_starter() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.test_mode = true
	sheet.host_class = "Node"
	var about: CommentRow = CommentRow.new()
	about.text = "[b]Test sheet[/b] - claims about your game that a runner checks and reports pass / fail on. Each check is a row; a failing one names itself in the verdict.\nTools > Run Tests… runs every test sheet in the project."
	sheet.events.append(about)
	var start: EventRow = EventRow.new()
	start.trigger_provider_id = "Core"
	start.trigger_id = "OnTestStart"
	start.actions.append(_member_row("# One claim per row: Assert That, Assert Equal, Expect Signal."))
	sheet.events.append(start)
	return sheet


## An OBJECT TYPE: a node of your own in the editor's Create Node dialog, with its own icon.
static func _build_object_type_starter() -> EventSheetResource:
	var sheet: EventSheetResource = _tool_starter("EditorPlugin", "[b]Object type[/b] - teaches the editor a node of your own, so it appears in Create Node beside the built-in ones with its own icon.\nPoint script at the sheet that node runs, and remove the type again on plugin disabled.")
	sheet.events.append(_plugin_event("OnPluginEnabled", [
		_tool_action("AddEditorObjectType", "add_custom_type({type_name}, {base}, {script}, {icon})", {"type_name": "\"Waypoint\"", "base": "\"Node2D\"", "script": "null", "icon": "null"}),
	]))
	sheet.events.append(_plugin_event("OnPluginDisabled", [
		_tool_action("RemoveEditorObjectType", "remove_custom_type({type_name})", {"type_name": "\"Waypoint\""}),
	]))
	return sheet


## A PLATFORMER starter: ui_left/ui_right run, ui_accept jumps. The classic first sheet.
static func _build_platformer_starter() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "CharacterBody2D"
	var note: CommentRow = CommentRow.new()
	note.text = "[b]Platformer Starter[/b] - move with ui_left/ui_right, jump with ui_accept.\nTune the numbers, then Compile and attach the script."
	sheet.events.append(note)
	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"
	tick.trigger_id = "OnPhysicsProcess"
	var move: RawCodeRow = RawCodeRow.new()
	move.code = "velocity.x = Input.get_axis(&\"ui_left\", &\"ui_right\") * 220.0\nif not is_on_floor():\n\tvelocity.y += 980.0 * delta\nmove_and_slide()"
	tick.actions.append(move)
	sheet.events.append(tick)
	var jump: EventRow = EventRow.new()
	jump.trigger_provider_id = "Core"
	jump.trigger_id = "OnPhysicsProcess"
	var grounded: ACECondition = ACECondition.new()
	grounded.provider_id = "Core"
	grounded.ace_id = "IsOnFloor"
	grounded.codegen_template = "is_on_floor()"
	jump.conditions.append(grounded)
	var pressed: ACECondition = ACECondition.new()
	pressed.provider_id = "Core"
	pressed.ace_id = "IsActionJustPressed"
	pressed.codegen_template = "Input.is_action_just_pressed(&{action})"
	pressed.params = {"action": "\"ui_accept\""}
	jump.conditions.append(pressed)
	var leap: ACEAction = ACEAction.new()
	leap.provider_id = "Core"
	leap.ace_id = "SetVelocity2D"
	leap.codegen_template = "velocity.y = {vel}"
	leap.params = {"vel": "-420.0"}
	jump.actions.append(leap)
	sheet.events.append(jump)
	return sheet


## A TOP-DOWN starter: 8-way movement on the arrow keys.
static func _build_topdown_starter() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "CharacterBody2D"
	var note2: CommentRow = CommentRow.new()
	note2.text = "[b]Top-down Starter[/b] - 8-way movement with the arrow keys."
	sheet.events.append(note2)
	var tick2: EventRow = EventRow.new()
	tick2.trigger_provider_id = "Core"
	tick2.trigger_id = "OnPhysicsProcess"
	var move2: RawCodeRow = RawCodeRow.new()
	move2.code = "velocity = Input.get_vector(&\"ui_left\", &\"ui_right\", &\"ui_up\", &\"ui_down\") * 200.0\nmove_and_slide()"
	tick2.actions.append(move2)
	sheet.events.append(tick2)
	return sheet


## Returns a fresh starter sheet for a template id - the ONE source of truth shared by the
## New-Sheet menu (below) and the FileSystem "Create New > Event Sheet" dialog. Only the
## dock-free starters live here (Blank + 2D movement + the three data-asset intents); the
## New-Sheet menu keeps the autoload/3D cases inline since it also adopts them into the dock.
static func build_starter(template_id: int) -> EventSheetResource:
	# Extension starters (EventSheets.register_starter) occupy ids 1000+ in registration order.
	if template_id >= 1000:
		var registered: Array[Dictionary] = EventSheets.registered_starters()
		var starter_index: int = template_id - 1000
		if starter_index < registered.size():
			var build: Callable = registered[starter_index].get("build", Callable())
			var built: Variant = build.call() if build.is_valid() else null
			if built is EventSheetResource:
				return built
		return EventSheetResource.new()
	match template_id:
		1: return _build_platformer_starter()
		2: return _build_topdown_starter()
		8: return _build_behavior_component_starter()
		9: return _build_custom_resource_starter()
		10: return _build_editor_tool_starter()
		11: return _build_system_starter()
		12: return _build_editor_plugin_starter()
		13: return _build_import_tool_starter()
		14: return _build_export_hook_starter()
		# W17 - the other eleven editor shapes, in the mockup's order.
		15: return _build_dock_panel_starter()
		16: return _build_bottom_panel_starter()
		17: return _build_tools_menu_item_starter()
		18: return _build_properties_bar_starter()
		19: return _build_context_menu_starter()
		20: return _build_view_handle_starter()
		21: return _build_thumbnail_maker_starter()
		22: return _build_debugger_panel_starter()
		23: return _build_command_tool_starter()
		24: return _build_test_sheet_starter()
		25: return _build_object_type_starter()
		_: return EventSheetResource.new()  # 0 Blank (and any other id) -> a minimal editable sheet


## The starters the FileSystem "Create New > Event Sheet" dialog offers, as {id, label} in menu
## order. A curated, dock-free subset of the New-Sheet menu (autoloads + 3D controllers are
## project-wide/niche and stay in the in-workspace New menu).
static func create_new_starters() -> Array[Dictionary]:
	var starters: Array[Dictionary] = [
		{"id": 0, "label": "Blank Sheet"},
		{"id": 1, "label": "Platformer Starter"},
		{"id": 2, "label": "Top-down Starter"},
		{"id": 8, "label": "Behavior Component"},
		{"id": 9, "label": "Custom Resource"},
	]
	# W17. Every editor shape, in the same order and the same words as the New-Sheet submenu - the
	# FileSystem dialog is a flat list, so the "what it is" note rides along in the label.
	for shape: Dictionary in EDITOR_TOOL_SHAPES:
		starters.append({"id": int(shape["id"]), "label": "%s - %s" % [str(shape["label"]), str(shape["note"])]})
	# Extension starters (EventSheets.register_starter) append after the built-ins, ids 1000+.
	var registered: Array[Dictionary] = EventSheets.registered_starters()
	for starter_index: int in range(registered.size()):
		starters.append({"id": 1000 + starter_index, "label": str(registered[starter_index].get("label", ""))})
	return starters


## Builds a fresh sheet from a starter template and adopts it (unsaved; Save As to keep).
func _new_sheet_from_template(template_id: int) -> void:
	# T13 - a project that started from a template is one of the two ways a reader says "give me the
	# familiar surfaces" without being asked, so the Project bar turns itself on for it.
	EventSheetProjectBarGlue.mark_started_from_template()
	if template_id >= 100:
		var template_index: int = template_id - 100
		if template_index >= _project_template_paths.size():
			return
		var template_copy: EventSheetResource = EventSheetTemplates.load_copy(_project_template_paths[template_index])
		if template_copy == null:
			_dock._set_status("Couldn't load that template.", true)
			return
		_dock.setup(template_copy)
		_dock._current_sheet_path = ""
		_dock._dirty = true
		_dock._refresh_title_strip()
		_dock._clear_undo_history()
		_dock._set_status("New sheet from project template - Save As… to keep it.")
		return
	var sheet: EventSheetResource = EventSheetResource.new()
	# W17. Every editor shape resolves through the one dock-free builder, so the New-Sheet submenu,
	# the FileSystem Create New dialog and the round-trip gate all adopt the SAME sheet.
	for shape: Dictionary in EDITOR_TOOL_SHAPES:
		if int(shape["id"]) == template_id:
			sheet = build_starter(template_id)
	match template_id:
		1:
			sheet = _build_platformer_starter()
		2:
			sheet = _build_topdown_starter()
		8:
			sheet = _build_behavior_component_starter()
		9:
			sheet = _build_custom_resource_starter()
		10:
			sheet = _build_editor_tool_starter()
		11:
			sheet = _build_system_starter()
		12:
			sheet = _build_editor_plugin_starter()
		13:
			sheet = _build_import_tool_starter()
		14:
			sheet = _build_export_hook_starter()
		6:
			sheet.host_class = "CharacterBody3D"
			var note6: CommentRow = CommentRow.new()
			note6.text = "[b]First-Person Controller (3D)[/b] - WASD/arrows to move (relative to a child Camera3D's facing), Space to jump.\nAdd a Camera3D child named \"Camera3D\", then Compile and attach the script."
			sheet.events.append(note6)
			var tick6: EventRow = EventRow.new()
			tick6.trigger_provider_id = "Core"
			tick6.trigger_id = "OnPhysicsProcess"
			var move6: RawCodeRow = RawCodeRow.new()
			move6.code = "\n".join(PackedStringArray([
				"var input_2d := Input.get_vector(&\"ui_left\", &\"ui_right\", &\"ui_up\", &\"ui_down\")",
				"var basis_node: Node3D = get_node_or_null(\"Camera3D\")",
				"var dir_basis := basis_node.global_transform.basis if basis_node != null else global_transform.basis",
				"var move_vec := dir_basis * Vector3(input_2d.x, 0.0, input_2d.y)",
				"move_vec.y = 0.0  # project onto the ground plane so look-pitch never changes speed",
				"var direction := move_vec.normalized()",
				"velocity.x = direction.x * 6.0",
				"velocity.z = direction.z * 6.0",
				"if not is_on_floor():",
				"\tvelocity.y -= 18.0 * delta",
				"elif Input.is_action_just_pressed(&\"ui_accept\"):",
				"\tvelocity.y = 7.0",
				"move_and_slide()"
			]))
			tick6.actions.append(move6)
			sheet.events.append(tick6)
		7:
			sheet.host_class = "CharacterBody3D"
			var note7: CommentRow = CommentRow.new()
			note7.text = "[b]Third-Person Mover (3D)[/b] - WASD/arrows move on the ground plane and the body turns to face its motion. Space jumps."
			sheet.events.append(note7)
			var tick7: EventRow = EventRow.new()
			tick7.trigger_provider_id = "Core"
			tick7.trigger_id = "OnPhysicsProcess"
			var move7: RawCodeRow = RawCodeRow.new()
			move7.code = "\n".join(PackedStringArray([
				"var input_2d := Input.get_vector(&\"ui_left\", &\"ui_right\", &\"ui_up\", &\"ui_down\")",
				"var direction := Vector3(input_2d.x, 0.0, input_2d.y)",
				"velocity.x = direction.x * 6.0",
				"velocity.z = direction.z * 6.0",
				"if direction.length() > 0.1:",
				"\trotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z), delta * 10.0)",
				"if not is_on_floor():",
				"\tvelocity.y -= 18.0 * delta",
				"elif Input.is_action_just_pressed(&\"ui_accept\"):",
				"\tvelocity.y = 7.0",
				"move_and_slide()"
			]))
			tick7.actions.append(move7)
			sheet.events.append(tick7)
		3:
			sheet.autoload_mode = true
			sheet.autoload_name = "GameState"
			sheet.host_class = "Node"
			sheet.variables = {
				"score": {"type": "int", "default": 0, "exported": true, "attributes": {"tooltip": "Current score."}},
				"lives": {"type": "int", "default": 3, "exported": true, "attributes": {"range": {"min": "0", "max": "99", "step": "1"}}}
			}
			var score_signal: RawCodeRow = RawCodeRow.new()
			score_signal.code = "## @ace_trigger\n## @ace_name(\"On Score Changed\")\n## @ace_category(\"Game State\")\nsignal score_changed(new_score: int)"
			sheet.events.append(score_signal)
			var add_score: EventFunction = EventFunction.new()
			add_score.function_name = "add_score"
			add_score.expose_as_ace = true
			add_score.ace_display_name = "Add Score"
			add_score.ace_category = "Game State"
			var amount_param: ACEParam = ACEParam.new()
			amount_param.id = "amount"
			amount_param.type_name = "int"
			add_score.params.append(amount_param)
			var add_body: RawCodeRow = RawCodeRow.new()
			add_body.code = "score += amount\nscore_changed.emit(score)"
			add_score.events.append(add_body)
			sheet.functions.append(add_score)
		4:
			sheet.autoload_mode = true
			sheet.autoload_name = "EventBus"
			sheet.host_class = "Node"
			var bus_note: CommentRow = CommentRow.new()
			bus_note.text = "[b]Event Bus[/b] - declare project-wide signals here; emit them from any sheet via EventBus.<signal>.emit(...)."
			sheet.events.append(bus_note)
			var bus_signals: RawCodeRow = RawCodeRow.new()
			bus_signals.code = "## @ace_trigger\n## @ace_name(\"On Game Paused\")\n## @ace_category(\"Event Bus\")\nsignal game_paused\n\n## @ace_trigger\n## @ace_name(\"On Level Completed\")\n## @ace_category(\"Event Bus\")\nsignal level_completed(level: int)"
			sheet.events.append(bus_signals)
		5:
			sheet.autoload_mode = true
			sheet.autoload_name = "SaveSystem"
			sheet.host_class = "Node"
			sheet.variables = {"save_path": {"type": "String", "default": "user://save.cfg", "exported": true, "attributes": {"tooltip": "Where the save file lives."}}}
			var save_fn: EventFunction = EventFunction.new()
			save_fn.function_name = "save_number"
			save_fn.expose_as_ace = true
			save_fn.ace_display_name = "Save Number"
			save_fn.ace_category = "Save System"
			for save_param_pair in [["key", "String"], ["value", "float"]]:
				var save_param: ACEParam = ACEParam.new()
				save_param.id = str(save_param_pair[0])
				save_param.type_name = str(save_param_pair[1])
				save_fn.params.append(save_param)
			var save_body: RawCodeRow = RawCodeRow.new()
			save_body.code = "var config: ConfigFile = ConfigFile.new()\nconfig.load(save_path)\nconfig.set_value(\"save\", key, value)\nconfig.save(save_path)"
			save_fn.events.append(save_body)
			sheet.functions.append(save_fn)
			var load_fn: EventFunction = EventFunction.new()
			load_fn.function_name = "load_number"
			load_fn.expose_as_ace = true
			load_fn.ace_display_name = "Load Number"
			load_fn.ace_category = "Save System"
			load_fn.return_type = TYPE_FLOAT
			var load_param: ACEParam = ACEParam.new()
			load_param.id = "key"
			load_param.type_name = "String"
			load_fn.params.append(load_param)
			var load_body: RawCodeRow = RawCodeRow.new()
			load_body.code = "var config: ConfigFile = ConfigFile.new()\nconfig.load(save_path)\nreturn float(config.get_value(\"save\", key, 0.0))"
			load_fn.events.append(load_body)
			sheet.functions.append(load_fn)
	_dock.setup(sheet)
	_dock._current_sheet_path = ""
	_dock._dirty = true
	_dock._refresh_title_strip()
	_dock._clear_undo_history()
	_dock._set_status("New sheet from template - Save As… to keep it.")
