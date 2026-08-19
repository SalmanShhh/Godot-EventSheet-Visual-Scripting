@tool
class_name EventSheetScriptIntent
extends RefCounted
## What kind of Godot script a sheet is FOR - a behaviour, a custom resource, an editor tool...
##
## Derived from fields sheets already carry (never stored), so every existing sheet classifies
## correctly with no format change. One table drives all the intent-aware UX: the New-menu
## sections, the Sheet Type presets, the identity banner pill, and the empty-sheet advice - so
## adding a new intent (or refining the advice) is a change HERE, nowhere else.

enum Intent {
	EVENT_SHEET,
	CUSTOM_NODE,
	BEHAVIOUR,
	AUTOLOAD,
	EDITOR_TOOL,
	CUSTOM_RESOURCE,
	TEST,
	EDITOR_PLUGIN,
	# W17. The editor extension classes that are neither a chore nor the plugin itself - the Properties
	# bar add-on, the importer, the thumbnail maker, the debugger panel, the context menu. They are
	# registered BY a plugin and their events are the callbacks the editor calls on them.
	EDITOR_ADDON,
	# W17. A script the Godot binary runs headless from the command line (`extends SceneTree`).
	COMMAND_TOOL,
}

## W17. The editor extension classes an "Editor add-on" sheet can be hosted on. Every one of them is
## a class a plugin hands to the editor with an add_*_plugin call, so none of them is the plugin. The
## list is what tells the Sheet Type dialog to keep the host field VISIBLE for this intent: which of
## the six it is, is the whole choice.
const ADDON_HOSTS: PackedStringArray = [
	"EditorInspectorPlugin",
	"EditorImportPlugin",
	"EditorExportPlugin",
	"EditorDebuggerPlugin",
	"EditorResourcePreviewGenerator",
	"EditorContextMenuPlugin",
	"EditorNode3DGizmoPlugin",
	"EditorTranslationParserPlugin",
	"EditorSyntaxHighlighter",
]

## W17. The two base classes Godot runs as a command-line program.
const COMMAND_TOOL_HOSTS: PackedStringArray = ["SceneTree", "MainLoop"]


## Classifies a sheet. Order matters: the mode flags are explicit choices and win over the
## host-class heuristics; a Resource-extending host means "data asset" regardless of naming.
static func of_sheet(sheet: EventSheetResource) -> Intent:
	if sheet == null:
		return Intent.EVENT_SHEET
	if sheet.test_mode:
		return Intent.TEST
	if sheet.autoload_mode:
		return Intent.AUTOLOAD
	if sheet.behavior_mode:
		return Intent.BEHAVIOUR
	if sheet.tool_mode and sheet.host_class.strip_edges() == "EditorScript":
		return Intent.EDITOR_TOOL
	# R33. A @tool sheet hosted on EditorPlugin is not a chore you run - it is a plugin the editor
	# switches on, which is a different set of events (enabled / disabled / dock / menu item) and a
	# different Include bar. Checked after EditorScript so the two tool intents never overlap.
	if sheet.tool_mode and sheet.host_class.strip_edges() == "EditorPlugin":
		return Intent.EDITOR_PLUGIN
	# W17. The other editor shapes. Checked after the two above so the three tool intents never
	# overlap, and BEFORE the resource/custom-node heuristics - an add-on always names a class, and
	# without this an EditorInspectorPlugin sheet classified as "custom node" and lost its host the
	# next time the Sheet Type dialog was confirmed.
	if sheet.tool_mode and ADDON_HOSTS.has(sheet.host_class.strip_edges()):
		return Intent.EDITOR_ADDON
	if sheet.tool_mode and COMMAND_TOOL_HOSTS.has(sheet.host_class.strip_edges()):
		return Intent.COMMAND_TOOL
	if is_resource_host(sheet.host_class):
		return Intent.CUSTOM_RESOURCE
	if not sheet.custom_class_name.strip_edges().is_empty():
		return Intent.CUSTOM_NODE
	return Intent.EVENT_SHEET


## True when the host class IS a data asset (Resource or any subclass - AudioStream, Texture2D,
## a project class). Engine classes resolve through ClassDB; unknown names count as resources
## only when they are exactly "Resource" (a project-defined subclass types the sheet by hand).
static func is_resource_host(host_class: String) -> bool:
	var trimmed: String = host_class.strip_edges()
	if trimmed == "Resource":
		return true
	return ClassDB.class_exists(trimmed) and ClassDB.is_parent_class(trimmed, "Resource")


## Display identity for banners/pills: {label, glyph}. Glyphs are plain geometric characters so
## the fallback font renders them everywhere; each intent stays visually distinct without art.
static func display(intent: Intent) -> Dictionary:
	match intent:
		Intent.BEHAVIOUR:
			return {"label": "Behavior", "glyph": "⚙"}
		Intent.AUTOLOAD:
			return {"label": "Autoload", "glyph": "◎"}
		Intent.EDITOR_TOOL:
			return {"label": "Editor Tool", "glyph": "⚒"}
		Intent.EDITOR_PLUGIN:
			return {"label": "Editor Plugin", "glyph": "⚒"}
		Intent.EDITOR_ADDON:
			return {"label": "Editor Add-on", "glyph": "⚒"}
		Intent.COMMAND_TOOL:
			return {"label": "Command Tool", "glyph": "⚒"}
		Intent.CUSTOM_RESOURCE:
			return {"label": "Custom Resource", "glyph": "▣"}
		Intent.CUSTOM_NODE:
			return {"label": "Custom Node", "glyph": "◆"}
		Intent.TEST:
			return {"label": "Test", "glyph": "✓"}
		_:
			return {"label": "Event Sheet", "glyph": "▤"}


## The empty-sheet guidance: {heading, primary, tip} - one small, concrete push toward each
## intent's full potential, shown only while the sheet has no authored rows. Kept SHORT on
## purpose (one heading + one action + one tip reads calm; a wall of advice reads like clutter).
static func empty_sheet_advice(sheet: EventSheetResource) -> Dictionary:
	# No sheet loaded at all is its own state: telling the user to "add your first event" would be
	# a lie (there is nowhere to put one). Steer toward creating a sheet instead - the viewport's
	# double-click and CTA buttons open the starter menu in this state.
	if sheet == null:
		return {
			"heading": "No event sheet is open",
			"primary": "Create one to start building - a menu of ready-made starters opens.",
			"tip": "Tip: Tools > Welcome… has a playable showcase and a 2-minute tour.",
		}
	var host: String = sheet.host_class if sheet != null else "Node"
	match of_sheet(sheet):
		Intent.BEHAVIOUR:
			return {
				"heading": "Empty behavior sheet",
				"primary": "Double-click anywhere - or press E - to add an event that drives the %s this attaches to." % host,
				"tip": "Tip: the picker understands plain language. Try typing \"every tick\".",
			}
		Intent.AUTOLOAD:
			return {
				"heading": "Empty autoload sheet",
				"primary": "Add the signals and functions every sheet in the project should reach (score, game state, an event bus).",
				"tip": "Tip: publish a function to the picker and every sheet in the project can call it.",
			}
		Intent.EDITOR_TOOL:
			return {
				"heading": "Empty editor tool",
				"primary": "Add an On Editor Run event - its actions execute when you run this script from the editor (File > Run).",
				"tip": "Tip: great for batch renames, scene checks, and one-click project chores.",
			}
		Intent.EDITOR_PLUGIN:
			return {
				"heading": "Empty editor plugin",
				"primary": "Add an On Plugin Enabled event - its actions run the moment the plugin is switched on, which is where a dock, a Tools menu item or an object type is added.",
				"tip": "Tip: undo each of them in On Plugin Disabled, or the editor keeps a dock nobody owns.",
			}
		Intent.EDITOR_ADDON:
			return {
				"heading": "Empty editor add-on",
				"primary": "Add the callbacks the editor asks this add-on - can you handle this object, draw this property, make this thumbnail.",
				"tip": "Tip: an add-on does nothing until a plugin hands it over. Make an Editor Plugin sheet too, and add it there on plugin enabled.",
			}
		Intent.COMMAND_TOOL:
			return {
				"heading": "Empty command tool",
				"primary": "Add an On run event - its actions run when the Godot binary runs this script headless from the command line.",
				"tip": "Tip: finish with an exit code, so whatever called it can tell success from failure.",
			}
		Intent.TEST:
			return {
				"heading": "Empty test sheet",
				"primary": "Add an On Test Start event, then assert something - Assert That, Assert Equal, or Expect Signal.",
				"tip": "Tip: Tools > Run Tests… runs every test sheet in the project and prints a verdict.",
			}
		Intent.CUSTOM_RESOURCE:
			return {
				"heading": "Empty custom resource",
				"primary": "Add exported variables for the data this asset holds - each .tres file you create from it becomes a designer-editable asset.",
				"tip": "Tip: resources have no _process; give them functions (and signals) instead of events, and call those from the sheets that load the asset.",
			}
		_:
			return {
				"heading": "This event sheet is empty",
				"primary": "Double-click anywhere - or press E - to add your first event.",
				"tip": "Tip: the picker understands plain language. Try typing \"every tick\".",
			}
