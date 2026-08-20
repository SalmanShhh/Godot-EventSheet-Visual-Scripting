@tool
class_name EventSheetDocEditorWords
extends RefCounted
# W21. The Manual's page for the editor-building words: what this sheet calls each of Godot's
# editor concepts, what Godot itself calls it, and WHY the word was changed.
#
# The table is not written here. The words come from EventSheetWords, which is also what the
# Familiar Words toggle and the Words settings page read, so the page can never say one thing while
# the sheet says another - the only thing this file owns is the "why" per row, which is the one part
# of the table a reader cannot derive from a pair of spellings.
#
# THE NAMING RULE, the same one the migration glossary carries: no other editor is ever named in a
# shipped string. The words here are the sheet's own, chosen to be what someone who has used any
# event-sheet editor would call the thing.

const PAGE_TITLE := "The words for building editor tools"

## key -> why this word. One sentence, in the second person, saying what the sheet's word tells a
## reader that Godot's spelling does not. Keyed by EventSheetWords key, so a word renamed there
## needs no edit here, and a word ADDED there without a reason shows the plain pair - honest, if
## less useful, which is better than a page that silently drops a row.
const REASONS: Dictionary = {
	"editor_plugin": "A plugin is not a node you create - it is something the editor switches on and off, and its two big events say exactly that.",
	"editor_object": "An event sheet talks to things by name. The editor is one of those things, so it gets a name rather than an interface class.",
	"editor_dock": "\"Dock\" is a verb in most people's English. Panel is the thing; where it is docked is a choice you make when you add it.",
	"inspector": "It is the bar where an object's properties are, and an add-on for it adds to that bar. Naming it for what it shows beats naming it for what it inspects.",
	"scene_dock": "It is the list of objects in the layout you have open - which is what a reader is looking for when they go there.",
	"filesystem_dock": "It is the project, listed. \"FileSystem\" describes the storage; a reader is looking for their project.",
	"tools_menu": "Unchanged: Project > Tools is already the plainest name in the editor.",
	"undo_history": "What Ctrl+Z walks back is a history, and a tool that adds a step to it is adding to that history - which is the whole idea a tool author needs.",
	"editor_preferences": "These are the settings of the person in front of the editor, not of the project. Preferences says whose they are.",
	"project_settings": "Unchanged apart from the space: these travel with the project, and everyone who opens it sees the same ones.",
	"style": "Theme and StyleBox are two names for one idea - how a control is drawn. Style is that idea.",
	"ui_element": "Control is Godot's base class for anything you can see and click in a UI. UI element is what it is.",
	"tool_annotation": "@tool is a mark, not a word. What it means is that this script also runs while the editor is open - which is the fact that surprises people.",
	"command_tool": "A script that extends SceneTree is not a scene and has no tree of its own to speak of - it is a program you run from the command line.",
	"importer_addon": "Naming it for WHEN it runs (files were imported) is the one fact that tells a reader whether they want it.",
	"export_hook": "Same reason as the importer: it runs as the project is exported, and a hook is the smallest honest word for something the export calls.",
	"view_handle": "A gizmo is a handle you drag in the layout view. The 2D overlay and the 3D gizmo are the same idea, so they get one word.",
	"thumbnail_maker": "The little picture beside a file is a thumbnail everywhere else in computing.",
	"debugger_panel": "It is a tab in the Debugger, added by you. Panel is what it looks like; Debugger is where it lives.",
	"object_type": "add_custom_type is the call; what you get is a new type of object in the Create Node dialog, which is what a reader is trying to make.",
	"global_singleton": "One always-on instance the whole project can reach by name is a global. Singleton is the pattern's name, not the thing's.",
	"shared_store": "A static variable is one copy for the whole editor rather than one per object - a store everything shares, which is the fact that matters when two tabs disagree.",
	"behavior_of": "A helper that holds a reference back to what it helps is not a free-standing class - it is a behavior OF that thing, and reads far better as one.",
	"workspace": "The editor's top tabs (2D, 3D, Script) are workspaces you move between. \"Main screen\" names the container, not the choice.",
}


## The page's rows, in the Words page's own order: {key, godot, here, why}. Pure, so the suite pins
## the table without opening a window, and so the Manual and the Words page cannot drift.
static func rows() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for key: String in EventSheetWords.EDITOR_KEYS:
		out.append({
			"key": key,
			"godot": EventSheetWords.plain_default(key),
			"here": EventSheetWords.familiar_default(key),
			"why": str(REASONS.get(key, "")),
		})
	return out


## One row by key, or {} when there is none - the shape every derived Manual page answers with.
static func row(key: String) -> Dictionary:
	for entry: Dictionary in rows():
		if str(entry.get("key", "")) == key:
			return entry
	return {}


## The whole page as blocks, in the shape the page view draws: the title, a lead line, then one
## chapter per word - Godot's spelling, the sheet's, and the reason.
static func blocks() -> Array[Dictionary]:
	var blocks: Array[Dictionary] = [
		{"kind": "heading", "level": 1, "text": PAGE_TITLE, "bbcode": PAGE_TITLE,
			"slug": EventSheetDocMarkdown.slug(PAGE_TITLE)},
		{"kind": "paragraph", "bbcode":
			"Building a tool means meeting twenty-odd editor nouns at once. These are the ones this sheet gives a word of its own, with Godot's spelling beside each - View ▸ Familiar Words switches between them, and nothing is hidden either way."},
	]
	for entry: Dictionary in rows():
		var here: String = str(entry.get("here", ""))
		var godot: String = str(entry.get("godot", ""))
		blocks.append({"kind": "heading", "level": 2, "text": here, "bbcode": here,
			"slug": str(entry.get("key", ""))})
		var pair: String = "Godot says [b]%s[/b]." % godot if godot == here \
			else "Godot says [b]%s[/b]. This sheet says [b]%s[/b]." % [godot, here]
		blocks.append({"kind": "paragraph", "bbcode": EventSheetDocMarkdown.escape_brackets(pair)})
		var why: String = str(entry.get("why", "")).strip_edges()
		if not why.is_empty():
			blocks.append({"kind": "quote", "bbcode": EventSheetDocMarkdown.escape_brackets(why)})
	return blocks
