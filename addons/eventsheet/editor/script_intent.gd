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
}


## Classifies a sheet. Order matters: the mode flags are explicit choices and win over the
## host-class heuristics; a Resource-extending host means "data asset" regardless of naming.
static func of_sheet(sheet: EventSheetResource) -> Intent:
	if sheet == null:
		return Intent.EVENT_SHEET
	if sheet.autoload_mode:
		return Intent.AUTOLOAD
	if sheet.behavior_mode:
		return Intent.BEHAVIOUR
	if sheet.tool_mode and sheet.host_class.strip_edges() == "EditorScript":
		return Intent.EDITOR_TOOL
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
		Intent.CUSTOM_RESOURCE:
			return {"label": "Custom Resource", "glyph": "▣"}
		Intent.CUSTOM_NODE:
			return {"label": "Custom Node", "glyph": "◆"}
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
