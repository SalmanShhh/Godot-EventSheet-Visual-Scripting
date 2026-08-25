@tool
class_name EventSheetWords
extends RefCounted

# The one place that decides what the sheet CALLS a thing.
#
# A handful of nouns have two honest names: the Godot one and the one every other event-sheet
# editor uses. "Familiar Words" used to flip a fixed table; this file turns that table into a
# per-user setting - each entry keeps its two defaults (the word with Familiar Words on, the
# word with it off), offers any extra words the team asked for, and accepts a typed-in word.
#
# Every user-facing use reads word(key). Never inline "Family" or "Layout" in a label: ask here,
# so the Words page (Settings > Words) really is the single place the vocabulary lives.
#
# Storage is per user, with the editor settings (project metadata, the same store the Familiar
# Words toggle already uses) - never the project file, because two people on one project may
# read the sheet in different words.

const METADATA_SECTION := "eventsheets"
const METADATA_KEY := "words"
const FAMILIAR_KEY := "familiar_words"

## key -> [what it names, the word with Familiar Words on, the word with it off, extra choices].
## Frozen keys: a key is read by callers all over the editor, so add, never rename.
const WORDS := {
	"inheritance_set": ["an inheritance set", "Family", "Base class", ["Kind"]],
	"layout": ["a scene", "Layout", "Scene", []],
	"every_tick": ["_process", "Every tick", "Every tick", []],
	"behavior": ["an attached pack", "Behavior", "Behavior", []],
	"group": ["a Godot group", "Family (group)", "Group", []],
	"collection": ["Array / Dictionary", "list / table", "list / table", []],
	"destroy": ["queue_free", "Destroy", "Destroy", []],
	"manual": ["the reader", "Manual", "Manual", []],
	# The editor-building nouns. Until now Familiar Words covered the GAME words (layout, object
	# type, family) and a tool sheet mixed two vocabularies on one screen: half of it in the sheet's
	# words, half in Godot's class names. These are the twenty-four a first tool meets, each with
	# Godot's own spelling as the "off" side, so nothing is hidden - only renamed, and reversibly.
	"editor_plugin": ["what the editor switches on", "Editor plugin", "EditorPlugin", []],
	"editor_object": ["the editor itself, as an object", "Editor", "EditorInterface", []],
	"editor_dock": ["a panel docked in the editor", "Panel (dock)", "Dock", []],
	"inspector": ["the properties panel and its add-ons", "Properties bar", "Inspector", ["Properties bar add-on"]],
	"scene_dock": ["the tree of the open scene", "Layout's object list", "Scene dock", []],
	"filesystem_dock": ["the project's file list", "Project bar", "FileSystem dock", []],
	"tools_menu": ["Project > Tools", "Tools menu", "Tools menu", []],
	"undo_history": ["what Ctrl+Z walks back", "Undo history", "UndoRedo", ["Undo/redo"]],
	"editor_preferences": ["the user's own editor settings", "Preferences", "EditorSettings", []],
	"project_settings": ["the settings saved with the project", "Project settings", "ProjectSettings", []],
	"style": ["how a control is drawn", "Style", "Theme", ["StyleBox"]],
	"ui_element": ["a node you can see and click", "UI element", "Control", []],
	"tool_annotation": ["a script that also runs in the editor", "runs in the editor too", "@tool", []],
	"command_tool": ["a script run from the command line", "Command tool", "SceneTree script", []],
	"importer_addon": ["what runs when files are imported", "Importer add-on", "EditorImportPlugin", []],
	"export_hook": ["what runs when the project is exported", "Export hook", "EditorExportPlugin", []],
	"view_handle": ["something drawn over the 2D or 3D view", "Layout view handle", "Gizmo", ["Viewport overlay"]],
	"thumbnail_maker": ["what draws a file's preview picture", "Thumbnail maker", "EditorResourcePreviewGenerator", []],
	"debugger_panel": ["a tab in the Debugger while the game runs", "Debugger panel", "EditorDebuggerPlugin", []],
	"object_type": ["a node of your own in Create Node", "Object type", "Custom type", ["add_custom_type"]],
	"global_singleton": ["one always-on instance the project shares", "Global", "Autoload", []],
	"shared_store": ["one copy for the whole editor", "Shared store", "Static class", ["shared"]],
	"behavior_of": ["a helper that points back at what it helps", "Behavior of …", "Helper class", []],
	"workspace": ["one of the editor's top tabs", "Workspace", "Main screen", []],
}

## Display order on the Words page - the order the page is read in, not the dictionary's.
const KEY_ORDER: Array[String] = [
	"inheritance_set", "layout", "every_tick", "behavior",
	"group", "collection", "destroy", "manual",
	# The editor-building words, in the page's own order (the plugin itself first, then its
	# surfaces, then the shapes it can take, then the three code idioms a reader meets in tool code).
	"editor_plugin", "editor_object", "editor_dock", "inspector", "scene_dock", "filesystem_dock",
	"tools_menu", "undo_history", "editor_preferences", "project_settings", "style", "ui_element",
	"tool_annotation", "command_tool", "importer_addon", "export_hook", "view_handle",
	"thumbnail_maker", "debugger_panel", "object_type", "global_singleton", "shared_store",
	"behavior_of", "workspace",
]

## The keys the editor-building wave added, so the Manual's page and any test can name "the editor-building words"
## without re-listing them. Everything before these is the game vocabulary the earlier batches shipped.
const EDITOR_KEYS: Array[String] = [
	"editor_plugin", "editor_object", "editor_dock", "inspector", "scene_dock", "filesystem_dock",
	"tools_menu", "undo_history", "editor_preferences", "project_settings", "style", "ui_element",
	"tool_annotation", "command_tool", "importer_addon", "export_hook", "view_handle",
	"thumbnail_maker", "debugger_panel", "object_type", "global_singleton", "shared_store",
	"behavior_of", "workspace",
]


## Every key, in page order. Any key in WORDS that KEY_ORDER forgot still comes out (sorted),
## so adding a word can never make it invisible.
static func keys() -> Array[String]:
	var out: Array[String] = []
	for key: String in KEY_ORDER:
		if WORDS.has(key):
			out.append(key)
	var rest: Array[String] = []
	for key: String in WORDS.keys():
		if not out.has(key):
			rest.append(key)
	rest.sort()
	out.append_array(rest)
	return out


## What the key names, in the sheet's own words ("an inheritance set").
static func names_what(key: String) -> String:
	if not WORDS.has(key):
		return key
	return str((WORDS[key] as Array)[0])


## The word this key reads as with Familiar Words ON.
static func familiar_default(key: String) -> String:
	if not WORDS.has(key):
		return key
	return str((WORDS[key] as Array)[1])


## The word this key reads as with Familiar Words OFF.
static func plain_default(key: String) -> String:
	if not WORDS.has(key):
		return key
	return str((WORDS[key] as Array)[2])


## The glossary lens both ways: hand it either spelling of a word and get the other one back.
## The lens's whole promise is that renaming a noun hides nothing - Godot's own term is one hover
## away from the sheet's, and the sheet's is one hover away from Godot's - so the lookup has to work
## from either side. "" when the word is not one of ours, so a caller can tell "no entry" from "the
## same word either way" (Tools menu is spelled the same in both vocabularies).
static func godot_word(sheet_word: String) -> String:
	var wanted: String = sheet_word.strip_edges()
	for key: String in keys():
		if familiar_default(key) == wanted:
			return plain_default(key)
	return ""


## The glossary lens as a HOVER LINE. Hand it the exact text a row is showing and get back the
## one or two lines that say what the other vocabulary calls the same thing, or "" when the text is
## not one of the sheet's nouns (which is nearly every span, so the caller can use the empty string
## as "keep looking").
##
## Both directions, because the reader who needs the lens most is the one who did NOT choose the
## word in front of them: with Familiar Words on the row says "Properties bar" and the Godot term is
## what is hidden; with it off the row says "Inspector" and the sheet's own word is. A word spelled
## the same in both vocabularies (Tools menu) returns "" rather than a sentence saying nothing.
##
## A word the reader TYPED themselves is handled too: it matches neither default, so the Godot
## spelling is the useful half and that is the one the line names.
static func glossary_hover(shown_text: String) -> String:
	return glossary_hover_for(shown_text, familiar_words_enabled(), overrides())


## The pure form, for tests and for a renderer that already holds the Familiar Words state.
static func glossary_hover_for(shown_text: String, familiar: bool, override_map: Dictionary) -> String:
	var wanted: String = shown_text.strip_edges()
	if wanted.is_empty():
		return ""
	for key: String in keys():
		if word_for(key, familiar, override_map) != wanted:
			continue
		var godot: String = plain_default(key)
		var sheet_side: String = familiar_default(key)
		var line: String = ""
		if wanted == godot:
			if sheet_side == godot:
				return ""
			line = EventSheetL10n.translate("%s - this sheet calls it %s.") % [wanted, sheet_side]
		else:
			line = EventSheetL10n.translate("%s - Godot calls this %s.") % [wanted, godot]
		var what: String = names_what(key).strip_edges()
		if what.is_empty():
			return line
		return "%s\n%s." % [line, what.substr(0, 1).to_upper() + what.substr(1)]
	return ""


## The sheet's word for a Godot term, or "" when the sheet has no word of its own for it.
static func sheet_word(godot_term: String) -> String:
	var wanted: String = godot_term.strip_edges()
	for key: String in keys():
		if plain_default(key) == wanted:
			return familiar_default(key)
	return ""


## The two defaults plus any extra offered words, deduplicated, in offer order.
static func choices(key: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if not WORDS.has(key):
		return out
	out.append(familiar_default(key))
	var plain: String = plain_default(key)
	if not out.has(plain):
		out.append(plain)
	for extra: Variant in ((WORDS[key] as Array)[3] as Array):
		if not out.has(str(extra)):
			out.append(str(extra))
	return out


## The default for the current Familiar Words state - what the key reads as with no override.
static func default_word(key: String, familiar: bool) -> String:
	return familiar_default(key) if familiar else plain_default(key)


## The word to show, right now: the user's chosen word for this key IN THE CURRENT Familiar
## Words state, else that state's default. The two states are chosen separately - the page
## shows a column each - because the point of the toggle is two vocabularies, not one.
static func word(key: String) -> String:
	return word_for(key, familiar_words_enabled(), overrides())


## The pure form, for tests and for callers that already hold the state (the viewport builds
## rows with familiar_words in its context and must not re-read the settings per row).
## `override_map` is the whole nested store: {"familiar": {key: word}, "plain": {key: word}}.
static func word_for(key: String, familiar: bool, override_map: Dictionary) -> String:
	if not WORDS.has(key):
		return key
	var state: Variant = override_map.get(state_key(familiar), {})
	if state is Dictionary:
		var chosen: String = str((state as Dictionary).get(key, "")).strip_edges()
		if not chosen.is_empty():
			return chosen
	return default_word(key, familiar)


## The store's sub-dictionary name for a Familiar Words state. Frozen - it is written to the
## user's editor settings, so a rename would silently drop everyone's choices.
static func state_key(familiar: bool) -> String:
	return "familiar" if familiar else "plain"


## Every key's current word, as key -> word. What a renderer takes once per rebuild.
static func snapshot() -> Dictionary:
	var familiar: bool = familiar_words_enabled()
	var override_map: Dictionary = overrides()
	var out: Dictionary = {}
	for key: String in keys():
		out[key] = word_for(key, familiar, override_map)
	return out


## True when the word chosen for this key in this state is one the user typed themselves
## (the page shows those as "custom…" and keeps the typed word in the field).
static func is_custom(key: String, familiar: bool) -> bool:
	var chosen: String = chosen_word(key, familiar)
	if chosen.is_empty():
		return false
	return not choices(key).has(chosen)


## The word the user pinned for this key in this state, or "" when they pinned none.
static func chosen_word(key: String, familiar: bool) -> String:
	var state: Variant = overrides().get(state_key(familiar), {})
	if state is Dictionary:
		return str((state as Dictionary).get(key, "")).strip_edges()
	return ""


# --- the store (per user, with the editor settings) -------------------------------------------


## The whole nested store: {"familiar": {key: word}, "plain": {key: word}}. Empty headless.
static func overrides() -> Dictionary:
	var stored: Variant = _project_metadata(METADATA_KEY, {})
	if stored is Dictionary:
		return (stored as Dictionary).duplicate(true)
	return {}


## The Familiar Words toggle (View > Familiar Words), read from the same store the dock writes.
static func familiar_words_enabled() -> bool:
	return bool(_project_metadata(FAMILIAR_KEY, false))


## Chooses the word for one key in one Familiar Words state. An empty word (or the word that
## state already defaults to) clears the choice, so "back to the default" never leaves a stale
## pin behind.
static func set_word(key: String, familiar: bool, chosen: String) -> void:
	if not WORDS.has(key):
		return
	var map: Dictionary = overrides()
	var slot: String = state_key(familiar)
	var state: Dictionary = map.get(slot, {}) if map.get(slot, {}) is Dictionary else {}
	var value: String = chosen.strip_edges()
	if value.is_empty() or value == default_word(key, familiar):
		state.erase(key)
	else:
		state[key] = value
	if state.is_empty():
		map.erase(slot)
	else:
		map[slot] = state
	_store_metadata(METADATA_KEY, map)


## Reset to defaults: drops every override, leaving the Familiar Words toggle alone.
static func reset() -> void:
	_store_metadata(METADATA_KEY, {})


static func _project_metadata(key: String, fallback: Variant) -> Variant:
	if not Engine.is_editor_hint() or not Engine.has_singleton("EditorInterface"):
		return fallback
	var settings: Object = EditorInterface.get_editor_settings()
	if settings == null:
		return fallback
	return settings.get_project_metadata(METADATA_SECTION, key, fallback)


static func _store_metadata(key: String, value: Variant) -> void:
	if not Engine.is_editor_hint() or not Engine.has_singleton("EditorInterface"):
		return
	var settings: Object = EditorInterface.get_editor_settings()
	if settings == null:
		return
	settings.set_project_metadata(METADATA_SECTION, key, value)
