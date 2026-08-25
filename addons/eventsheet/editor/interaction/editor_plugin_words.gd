# EventForge - the words every editor-plugin class reads in.
#
# Godot's editor extension surface is nine classes, and a script that extends one of them is not a
# game object at all: it is something the EDITOR owns, calls back, and hands things to. This file is
# the one table that says, for each of those classes, what the sheet calls it and what it calls its
# callbacks and its verbs - so a reader who has met the Editor object (its plugin lifecycle, its
# docks and its menu items) meets no second vocabulary when they open an Inspector add-on or an
# importer.
#
# Everything here is DISPLAY ONLY. Nothing in this file is consulted while emitting; the sheet still
# saves the same bytes it opened, and the readings are keyed off the class the script EXTENDS, which
# the Include bar already knows. That is also why the callbacks are addressed by their Godot virtual
# names rather than by a lifted trigger id: a hand-written plugin arrives as plain functions, and
# renaming what those functions READ AS costs nothing and moves nothing.
#
# Three tables, in the order a reader meets them:
#   1. CLASS_WORDS - the head fact ("Properties bar add-on") and the object a row of that class
#      wears in its object column ("Properties bar").
#   2. CALLBACKS - one entry per engine virtual: the sentence it reads as, and whether a `return`
#      inside it is an Answer (and of what shape).
#   3. VERBS - the add_* / remove_* calls, as the Add / Remove sentences the Editor object already
#      speaks, plus the two Inspector verbs and the exporter's own two.
@tool
class_name EventSheetEditorPluginWords
extends RefCounted

## The shape a `return` inside a callback reads as. "" is the ordinary reading (Stop event / Return
## x); ANSWER_VALUE reads `Answer <the value>`; ANSWER_HANDLED reads `Answer handled` /
## `Answer not handled` for a bare true / false, because that is what the flag those callbacks answer
## with actually MEANS - the engine reads it as "did this add-on take that property".
const ANSWER_VALUE := "value"
const ANSWER_HANDLED := "handled"

## The object column of the Editor object itself, as the editor-object vocabulary named it. Every other class here gets its
## own noun, because "Editor ▸ Add control" would send a reader looking in the wrong panel.
const EDITOR_OBJECT := "Editor"

## extends class -> {object: the object column, word: the head fact}.
##
## The words are the sheet's own, chosen so that someone who has never read Godot's class reference
## can point at the thing on screen: an EditorInspectorPlugin puts buttons and editors in the panel
## the sheet calls the Properties bar, so it is a Properties bar add-on.
const CLASS_WORDS: Dictionary = {
	"EditorPlugin": {"object": EDITOR_OBJECT, "word": "editor plugin"},
	"EditorInspectorPlugin": {"object": "Properties bar", "word": "Properties bar add-on"},
	"EditorImportPlugin": {"object": "Importer", "word": "Importer add-on"},
	"EditorExportPlugin": {"object": "Export hook", "word": "Export hook"},
	"EditorDebuggerPlugin": {"object": "Debugger panel", "word": "Debugger panel"},
	"EditorResourcePreviewGenerator": {"object": "Thumbnail maker", "word": "Thumbnail maker"},
	"EditorContextMenuPlugin": {"object": "Context menu", "word": "Context menu"},
	"EditorSyntaxHighlighter": {"object": "Code colours", "word": "Code colours"},
	"EditorTranslationParserPlugin": {"object": "Text finder", "word": "Text finder"}
}

## extends class -> virtual name -> {text, answer}.
##
## `text` may name the callback's OWN parameters positionally - `{0}` is the first declared
## parameter, `{1}` the second and so on - and a sentence that names any of them shows none of them
## as trailing chips: "Asks: can this plugin edit object?" already said which object, and a chip
## repeating it would be the second half of the same sentence printed twice. A sentence that names
## none keeps the chips, which is how "On workspace shown [visible]" reads.
const CALLBACKS: Dictionary = {
	"EditorPlugin": {
		# _enter_tree / _exit_tree on a plugin are not "on created" - the head says editor plugin, so
		# they are the moment it was switched on and the moment it was switched off. The lifter
		# already re-pins these two when it can see the extends line; this entry catches the file
		# where it could not (a plugin whose callback lifted as a plain function).
		"_enter_tree": {"text": "On plugin enabled", "answer": ""},
		"_exit_tree": {"text": "On plugin disabled", "answer": ""},
		# The OTHER pair, which almost nobody knows apart: these two run ONCE, the first time the
		# user ticks the plugin on in Project Settings, and never again at editor start.
		"_enable_plugin": {"text": "On plugin first turned on", "answer": ""},
		"_disable_plugin": {"text": "On plugin first turned off", "answer": ""},
		"_handles": {"text": "Asks: can this plugin edit {0}?", "answer": ANSWER_VALUE},
		"_edit": {"text": "On object handed to plugin", "answer": ""},
		"_make_visible": {"text": "On workspace shown", "answer": ""},
		"_build": {"text": "On project run", "answer": ANSWER_VALUE},
		"_save_external_data": {"text": "On save", "answer": ""}
	},
	"EditorInspectorPlugin": {
		"_can_handle": {"text": "Asks: show this add-on for {0}?", "answer": ANSWER_VALUE},
		"_parse_begin": {"text": "On start of {0}'s properties", "answer": ""},
		"_parse_property": {"text": "On property {2} of {0}", "answer": ANSWER_HANDLED},
		"_parse_end": {"text": "On end of {0}'s properties", "answer": ""},
		"_parse_group": {"text": "On group {1} of {0}", "answer": ""}
	},
	"EditorImportPlugin": {
		"_import": {"text": "On import", "answer": ANSWER_VALUE}
	},
	"EditorExportPlugin": {
		"_export_begin": {"text": "On export begins", "answer": ""},
		"_export_file": {"text": "On file exported", "answer": ""},
		"_export_end": {"text": "On export ends", "answer": ""}
	},
	"EditorDebuggerPlugin": {
		"_setup_session": {"text": "On session started", "answer": ""},
		"_capture": {"text": "On message", "answer": ANSWER_HANDLED}
	},
	"EditorResourcePreviewGenerator": {
		"_handles": {"text": "Asks: handles type?", "answer": ANSWER_VALUE},
		"_generate": {"text": "On make thumbnail", "answer": ANSWER_VALUE}
	},
	"EditorContextMenuPlugin": {
		"_popup_menu": {"text": "On menu opens for {0}", "answer": ""}
	}
}

## extends class -> method -> {text, arity}. `text` names arguments positionally (`{0}`, `{1}`),
## `arity` is the smallest argument count the reading is honest for - a user's own `skip()` taking
## three arguments is not the exporter's, and keeps its plain reading.
##
## Every one of these is what a plugin DOES to the editor, so on an EditorPlugin they all read with
## the Editor object in front, exactly as the picked rows of the Editor Tools vocabulary do.
const VERBS: Dictionary = {
	"EditorPlugin": {
		"add_control_to_dock": {"text": "Add dock {1} at {0}", "arity": 2},
		"add_dock": {"text": "Add dock {0}", "arity": 1},
		"remove_control_from_docks": {"text": "Remove dock {0}", "arity": 1},
		"remove_dock": {"text": "Remove dock {0}", "arity": 1},
		"add_control_to_bottom_panel": {"text": "Add bottom panel {0} named {1}", "arity": 2},
		"remove_control_from_bottom_panel": {"text": "Remove bottom panel {0}", "arity": 1},
		"add_tool_menu_item": {"text": "Add Tools menu item {0}", "arity": 1},
		"remove_tool_menu_item": {"text": "Remove Tools menu item {0}", "arity": 1},
		"add_context_menu_plugin": {"text": "Add context menu {1} to {0}", "arity": 2},
		"remove_context_menu_plugin": {"text": "Remove context menu {0}", "arity": 1},
		"add_inspector_plugin": {"text": "Add Properties bar add-on {0}", "arity": 1},
		"remove_inspector_plugin": {"text": "Remove Properties bar add-on {0}", "arity": 1},
		"add_import_plugin": {"text": "Add importer add-on {0}", "arity": 1},
		"remove_import_plugin": {"text": "Remove importer add-on {0}", "arity": 1},
		"add_export_plugin": {"text": "Add export hook {0}", "arity": 1},
		"remove_export_plugin": {"text": "Remove export hook {0}", "arity": 1},
		"add_debugger_plugin": {"text": "Add debugger panel {0}", "arity": 1},
		"remove_debugger_plugin": {"text": "Remove debugger panel {0}", "arity": 1},
		"add_custom_type": {"text": "Add object type {0}", "arity": 2},
		"remove_custom_type": {"text": "Remove object type {0}", "arity": 1},
		"add_autoload_singleton": {"text": "Add global {0} from {1}", "arity": 2},
		"remove_autoload_singleton": {"text": "Remove global {0}", "arity": 1}
	},
	"EditorInspectorPlugin": {
		"add_custom_control": {"text": "Add control {0}", "arity": 1},
		"add_property_editor": {"text": "Use editor {1} for {0}", "arity": 2},
		"add_property_editor_for_multiple_properties": {"text": "Use editor {2} for {1}", "arity": 3}
	},
	"EditorExportPlugin": {
		"add_file": {"text": "Add file to export {0}", "arity": 1},
		"skip": {"text": "Skip file", "arity": 0}
	},
	"EditorDebuggerPlugin": {
		"send_message": {"text": "Send message {0}", "arity": 1}
	},
	"EditorContextMenuPlugin": {
		"add_context_menu_item": {"text": "Add item {0}", "arity": 1}
	}
}

## The right-click surfaces a context menu can be added to, in the names this sheet already uses for
## those panels everywhere else. Written as whole constant spellings so a partial match can never
## rewrite half an identifier, and LONGEST FIRST: `..._FILESYSTEM` is a prefix of
## `..._FILESYSTEM_CREATE`, so rewriting the short one first would leave `Project bar_CREATE` behind.
const CONTEXT_SLOTS: Dictionary = {
	"EditorContextMenuPlugin.CONTEXT_SLOT_FILESYSTEM_CREATE": "Project bar ▸ Create new",
	"EditorContextMenuPlugin.CONTEXT_SLOT_SCRIPT_EDITOR_CODE": "Script editor ▸ Code",
	"EditorContextMenuPlugin.CONTEXT_SLOT_SCENE_TREE": "Scene dock",
	"EditorContextMenuPlugin.CONTEXT_SLOT_FILESYSTEM": "Project bar",
	"EditorContextMenuPlugin.CONTEXT_SLOT_SCRIPT_EDITOR": "Script editor"
}

## The virtuals that are QUESTIONS WITH CONSTANT ANSWERS: what the plugin is called, whether it owns
## a workspace, which icon that workspace wears - and, for an importer, its name and the extensions
## it claims. None of them is an event, because nothing ever "happens" in them, so they read on the
## head bar as the facts they state and the functions themselves are not drawn as rows.
const HEAD_FACT_CALLBACKS_BY_CLASS: Dictionary = {
	"EditorPlugin": ["_get_plugin_name", "_has_main_screen", "_get_plugin_icon"],
	"EditorImportPlugin": ["_get_importer_name", "_get_visible_name", "_get_recognized_extensions"],
	"EditorSyntaxHighlighter": ["_get_name"]
}


## True when a script extending `host_class` is one of the editor's own plugin classes - the one
## question every reading in this file is gated on.
static func is_editor_plugin_class(host_class: String) -> bool:
	return CLASS_WORDS.has(host_class.strip_edges())


## The object column a row of this class wears ("Editor", "Properties bar"), "" for anything else.
static func object_for(host_class: String) -> String:
	var entry: Variant = CLASS_WORDS.get(host_class.strip_edges(), null)
	return str((entry as Dictionary)["object"]) if entry is Dictionary else ""


## The head fact this class states about itself ("editor plugin", "Importer add-on"), "" for anything
## else. Untranslated here: the caller translates, because the head bar joins it with its neighbours.
static func head_word_for(host_class: String) -> String:
	var entry: Variant = CLASS_WORDS.get(host_class.strip_edges(), null)
	return str((entry as Dictionary)["word"]) if entry is Dictionary else ""


## The reading of one engine virtual - {text, answer} - or {} when this class does not name it.
static func callback_for(host_class: String, function_name: String) -> Dictionary:
	var table: Variant = CALLBACKS.get(host_class.strip_edges(), null)
	if not (table is Dictionary):
		return {}
	var entry: Variant = (table as Dictionary).get(function_name.strip_edges(), null)
	return (entry as Dictionary) if entry is Dictionary else {}


## The Answer shape a `return` inside this callback takes - "" when it is an ordinary return.
static func answer_shape(host_class: String, function_name: String) -> String:
	return str(callback_for(host_class, function_name).get("answer", ""))


## The reading of one add_* / remove_* verb - {text, arity} - or {} when this class does not name it.
static func verb_for(host_class: String, method: String) -> Dictionary:
	var table: Variant = VERBS.get(host_class.strip_edges(), null)
	if not (table is Dictionary):
		return {}
	var entry: Variant = (table as Dictionary).get(method.strip_edges(), null)
	return (entry as Dictionary) if entry is Dictionary else {}


## True when a virtual states a head fact rather than doing something, so the head bar says it once
## and the row is not drawn.
static func is_head_fact_callback(host_class: String, function_name: String) -> bool:
	var names: Variant = HEAD_FACT_CALLBACKS_BY_CLASS.get(host_class.strip_edges(), null)
	return names is Array and (names as Array).has(function_name.strip_edges())


## The add_* calls that REGISTER one add-on with the editor, and so answer "who added this?" for the
## file the add-on lives in. Keyed by method because that is what the walk over a plugin's source
## can see; the value is unused beyond membership, which is why it is a plain list.
const REGISTERING_CALLS: PackedStringArray = [
	"add_inspector_plugin", "add_import_plugin", "add_export_plugin", "add_debugger_plugin",
	"add_context_menu_plugin", "add_syntax_highlighter", "add_translation_parser_plugin"
]

## class name of an add-on -> the plugin class that registers it. Built once per session by the walk
## below and cleared with `clear_added_by_cache()`; a receipt on a head bar is not worth re-reading
## every EditorPlugin in the project on every row rebuild.
static var _added_by: Dictionary = {}
static var _added_by_walked: bool = false


## Forget the who-added-what walk, so the next ask re-reads the project. Called by nothing in the
## normal course of a session - it exists so a test can prove the walk from a clean state.
static func clear_added_by_cache() -> void:
	_added_by.clear()
	_added_by_walked = false


## The plugin class that registers an add-on of `class_name_of_addon` with the editor, "" when no
## file of THIS project does. Only this project's own files are walked: naming a plugin the user
## cannot open would be a receipt pointing nowhere.
static func added_by(class_name_of_addon: String) -> String:
	var bare: String = class_name_of_addon.strip_edges()
	if bare.is_empty():
		return ""
	if not _added_by_walked:
		_walk_registering_plugins()
	return str(_added_by.get(bare, ""))


## Reads every EditorPlugin script the project declares and records, for each add-on it registers,
## which plugin did the registering. The argument of `add_inspector_plugin(x)` is a member, so the
## class it holds is looked up from that member's own declaration in the same file - a declared type
## (`var _x: EventSheetEditButtonPlugin`) or the constructor it is given (`_x = Foo.new()`).
static func _walk_registering_plugins() -> void:
	_added_by_walked = true
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		if str(entry.get("base", "")) != "EditorPlugin":
			continue
		var path: String = str(entry.get("path", ""))
		var plugin_class: String = str(entry.get("class", ""))
		if path.is_empty() or plugin_class.is_empty() or not FileAccess.file_exists(path):
			continue
		var source: String = FileAccess.get_file_as_string(path)
		var member_types: Dictionary = _member_types(source)
		for line: String in source.split("\n"):
			var stripped: String = line.strip_edges()
			for call_name: String in REGISTERING_CALLS:
				var head: String = "%s(" % call_name
				var at: int = stripped.find(head)
				if at < 0:
					continue
				var rest: String = stripped.substr(at + head.length())
				var argument: String = rest.split(")")[0].split(",")[-1].strip_edges()
				var member_class: String = str(member_types.get(argument.trim_prefix("self."), ""))
				if not member_class.is_empty() and not _added_by.has(member_class):
					_added_by[member_class] = plugin_class


## Every member of a source file whose class this walk can be sure of: `var _x: SomeClass` states it
## outright, and `_x = SomeClass.new()` states it just as plainly. A member typed as an engine base
## class (`var _x: EditorInspectorPlugin = null`) is deliberately overwritten by its constructor when
## the file has one, because the base class is what the plugin declared, not what it registered.
static func _member_types(source: String) -> Dictionary:
	var types: Dictionary = {}
	for line: String in source.split("\n"):
		var stripped: String = line.strip_edges()
		if stripped.begins_with("var ") and stripped.contains(":"):
			var name_part: String = stripped.substr(4, stripped.find(":") - 4).strip_edges()
			var after: String = stripped.substr(stripped.find(":") + 1).strip_edges()
			var declared: String = after.split("=")[0].strip_edges()
			if _is_identifier(name_part) and _is_identifier(declared) and not types.has(name_part):
				types[name_part] = declared
		var new_at: int = stripped.find(".new()")
		var equals_at: int = stripped.find(" = ")
		if new_at > equals_at and equals_at > 0:
			var assigned: String = stripped.substr(0, equals_at).strip_edges().trim_prefix("var ").trim_prefix("self.")
			var constructed: String = stripped.substr(equals_at + 3, new_at - equals_at - 3).strip_edges()
			if _is_identifier(assigned) and _is_identifier(constructed):
				types[assigned] = constructed
	return types


## True for a bare GDScript identifier - the only spelling either half of the walk above may trust.
static func _is_identifier(text: String) -> bool:
	if text.is_empty() or text[0].is_valid_int():
		return false
	for character: String in text:
		if not (character == "_" or character.to_lower() != character.to_upper() or character.is_valid_int()):
			return false
	return true


## Every context-menu slot constant in `text`, rewritten to the panel's own name. Left alone when the
## text names none, so the common case costs one `contains`.
static func context_slot_words(text: String) -> String:
	if not text.contains("CONTEXT_SLOT_"):
		return text
	var out: String = text
	for spelling: String in CONTEXT_SLOTS:
		out = out.replace(spelling, str(CONTEXT_SLOTS[spelling]))
	return out
