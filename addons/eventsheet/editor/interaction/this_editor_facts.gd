@tool
class_name EventSheetThisEditor
extends RefCounted

# "THIS EDITOR": the plugin's own source, listed as sheets, grouped by what each file IS.
#
# Every batch of readings so far was proved on game scripts and on the shipped behavior packs. The
# editor itself is the largest hand-written GDScript body in this repo, written by people, in every
# shape tool code takes - so if it reads, tool code reads. This file is the FACTS behind that claim:
# which project is the editor's own, which files belong to it, and what role each one plays.
#
# THE GATE. Everything here is off unless the open project IS this plugin's own repo: the plugin's
# `plugin.cfg` present AND the pack-recipe folder beside it. A game that merely installed the plugin
# has the first and not the second, so it never sees any of this - no folder, no bar, no meta on its
# controls, nothing to opt out of. The test is ONE static, here, because several features are gated
# on it and two spellings of "is this the editor" would drift apart the first time a folder moved.
#
# THE ROLE. A file's role is DERIVED from its shape and its place, never from a list to maintain: an
# EditorPlugin is the Plugin, a helper that stores a back-reference into the dock is Workspace, a
# script under the tools folder that extends SceneTree is a Command tool. A new file lands in the
# right group the moment it is written, which is the only way a listing of 300-odd files stays true.
#
# Nothing here scans anything until it is asked to. The listing is built when the folder is first
# expanded and thrown away with it, so a reader who never opens it pays nothing.

## The two marks that say "this project is the editor itself". Both, never either.
const PLUGIN_CFG_PATH: String = "res://addons/eventforge/plugin.cfg"
const PACK_BUILDERS_DIR: String = "res://tools/pack_builders"

## The plugin's own EditorPlugin script - the file the plugin bar belongs to.
const PLUGIN_SCRIPT_PATH: String = "res://addons/eventforge/plugin.gd"

## Everything the folder LISTS: the plugin, the gates that pin it, and the tools built with it.
## Folders, so a new file is included by existing.
const SOURCE_ROOTS: PackedStringArray = [
	"res://addons/eventforge", "res://addons/eventsheet", "res://tests", "res://tools"
]

## What the RUNNING editor is built from - a much smaller thing than what the folder lists, and the
## distinction matters: saving one of these reloads the plugin under the reader, while saving a test
## or a command tool is an ordinary save of an ordinary file. The read-only bar and the save guard
## ask about THESE, not about everything the folder shows.
const PLUGIN_ROOTS: PackedStringArray = [
	"res://addons/eventforge", "res://addons/eventsheet"
]

## The role groups, in the order the folder draws them: the plugin first, then the editor a reader
## opens it in, then the machinery under it, then the things built with it. Frozen - a saved fold
## state names these, and a role id is written into a sheet's read-only bar.
const ROLE_ORDER: PackedStringArray = [
	"plugin", "workspace", "canvas", "readings", "importer", "compiler",
	"vocabulary", "manual", "tests", "command_tools", "pack_recipes", "other"
]

## Each role's heading and the muted note beside it - what that group of files DOES, in the words the
## sheet already uses for it rather than in folder names.
const ROLE_WORDS: Dictionary = {
	"plugin": ["Plugin", "the plugin itself"],
	"workspace": ["Workspace", "dock, menus, dialogs"],
	"canvas": ["Canvas", "viewport, row builder, renderer, input"],
	"readings": ["Readings", "sentence grammar, facts, patterns"],
	"importer": ["Importer", "open a .gd as events"],
	"recognisers": ["Recognisers", "the spellings a lift knows"],
	"compiler": ["Compiler", "events to GDScript"],
	"vocabulary": ["Vocabulary", "modules, registry, picker"],
	"manual": ["Manual", "docs dock, search, reference"],
	"tests": ["Tests", "what the gates pin"],
	"command_tools": ["Command tools", "run from the command line"],
	"pack_recipes": ["Pack recipes", "the behaviors that ship"],
	"other": ["Everything else", "the rest of these folders"],
}

## Where the Project bar records that this project has it turned on. Named here rather than reached
## through the bar's own glue so the gate below stays a static with no editor classes behind it.
const PROJECT_BAR_SHOWN_KEY: String = "eventsheets_project_bar_shown"

## The kind a listed file carries, so the Project bar's routing tells a this-editor entry apart from
## an ordinary project script (which opens editable, and is not part of the running editor).
const ENTRY_KIND: String = "this_editor_script"

## Answered once per session: the folders this asks about do not appear or vanish while the editor
## runs, and the folder is consulted on every control the plugin builds.
static var _is_editor_project_cached: int = -1


## THE GATE, and the only one: is the open project the editor's own repo? Cheap after the first call.
static func is_editor_project() -> bool:
	if _is_editor_project_cached < 0:
		_is_editor_project_cached = 1 if is_editor_project_at(PLUGIN_CFG_PATH, PACK_BUILDERS_DIR) else 0
	return _is_editor_project_cached == 1


## The same test with the two paths handed in, so a test pins both answers without a project behind
## it. Both marks are required: a game that INSTALLED the plugin has the cfg and no pack recipes.
static func is_editor_project_at(cfg_path: String, builders_dir: String) -> bool:
	return FileAccess.file_exists(cfg_path) and DirAccess.dir_exists_absolute(builders_dir)


## THE SECOND GATE, for the things that COST something: is the folder actually turned on? Two
## features hang off this rather than off the repo test alone - the meta a plugin-built control
## carries, and the reading-health note, which opens files to answer.
##
## False without an editor around it, which is deliberate: a headless run has no reader who asked for
## the folder, so nothing should be paying for one.
static func folder_is_on() -> bool:
	if not is_editor_project():
		return false
	if not Engine.is_editor_hint() or not Engine.has_singleton("EditorInterface"):
		return false
	var editor_interface: Object = Engine.get_singleton("EditorInterface")
	if editor_interface == null or not editor_interface.has_method("get_editor_settings"):
		return false
	var settings: Object = editor_interface.call("get_editor_settings")
	if settings == null:
		return false
	return bool(settings.call("get_project_metadata", "eventsheets", PROJECT_BAR_SHOWN_KEY, false))


## Drops the cached answer. For the tests, which move the goalposts on purpose.
static func invalidate() -> void:
	_is_editor_project_cached = -1


## One role's heading, and the muted note that says what those files do.
static func role_heading(role: String) -> String:
	var words: Array = ROLE_WORDS.get(role, [role.capitalize(), ""])
	return EventSheetL10n.translate(str(words[0]))


static func role_note(role: String) -> String:
	var words: Array = ROLE_WORDS.get(role, [role.capitalize(), ""])
	return EventSheetL10n.translate(str(words[1]))


## What a file IS, from its shape and its place. Pure: hand it a path and the file's text and it
## always answers the same thing, which is what lets a test pin every rule without a repo behind it.
##
## The order below is the order of certainty. A pack recipe and a command tool are told by where they
## live plus what they extend; a test by its name and its `run`; the plugin by what it extends; and
## only then do the folder rules run, because a file's folder is the weakest thing about it.
static func role_for(path: String, source: String) -> String:
	if path.begins_with("%s/" % PACK_BUILDERS_DIR):
		return "pack_recipes"
	if path.begins_with("res://tools/") and _extends(source, "SceneTree"):
		return "command_tools"
	if path.begins_with("res://tests/") and path.get_file().ends_with("_test.gd"):
		return "tests"
	if _extends(source, "EditorPlugin"):
		return "plugin"
	# A recogniser family before the folder it lives in: a file whose body is `lift_entries` IS a
	# table of spellings, the same shape as a pack recipe - one dictionary literal per entry, with
	# nearly every line a literal. The importer around it is code that reads; this is the list it
	# reads FROM, and calling the two the same thing measures a table against a ceiling set for
	# logic. Asked of the file's own text rather than of a list kept here, so a family added
	# tomorrow is classified the moment it declares the static.
	if path.contains("/importer/") and source.contains("static func lift_entries("):
		return "recognisers"
	if path.contains("/importer/") or path.contains("/foreign"):
		return "importer"
	if path.contains("/compiler/"):
		return "compiler"
	if path.contains("/registration/") or path.contains("/ace/") or path.get_file().begins_with("ace_"):
		return "vocabulary"
	if path.contains("/docs/") or path.contains("/help/"):
		return "manual"
	if _is_canvas_file(path):
		return "canvas"
	if _is_readings_file(path):
		return "readings"
	# A helper that stores a back-reference into the dock is a behavior OF the workspace - the shape
	# the whole dock is built out of, and the one that cannot be told from a folder name.
	if source.contains("var _dock") or path.contains("/dock/"):
		return "workspace"
	return "other"


## The canvas: the file that draws rows, the one that builds them, and the one that reads the mouse.
static func _is_canvas_file(path: String) -> bool:
	var file_name: String = path.get_file()
	for mark: String in ["viewport", "renderer", "row_builder", "_input", "drawing", "minimap"]:
		if file_name.contains(mark):
			return true
	return false


## The readings: the sentences a row is written in, the facts a file is read into, the patterns a
## shape is claimed as.
static func _is_readings_file(path: String) -> bool:
	var file_name: String = path.get_file()
	for mark: String in ["sentence", "grammar", "facts", "pattern", "reading", "lift"]:
		if file_name.contains(mark):
			return true
	return false


## True when the source declares `extends <base>` at the head of a line - read from the text rather
## than from ClassDB, so a fixture answers exactly like a real file and nothing has to be loadable.
static func _extends(source: String, base: String) -> bool:
	for line: String in source.split("\n"):
		var stripped: String = line.strip_edges()
		if stripped.begins_with("extends "):
			return stripped.substr(8).strip_edges().split(" ")[0] == base
		if stripped.begins_with("func ") or stripped.begins_with("var "):
			# Past the head. An `extends` cannot appear below the first declaration.
			return false
	return false


## True when a path is a file the RUNNING editor is built from - the test the read-only bar and the
## save guard both ask, so "part of this editor" means exactly one thing everywhere. A test or a
## command tool is listed in the folder but is NOT this: saving one reloads nothing.
static func is_editor_source(path: String) -> bool:
	if not path.ends_with(".gd"):
		return false
	for root: String in PLUGIN_ROOTS:
		if path.begins_with("%s/" % root):
			return true
	return false


## Every .gd the editor is made of, sorted. The scan itself, done once when the folder is opened.
static func source_files() -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for root: String in SOURCE_ROOTS:
		if not DirAccess.dir_exists_absolute(root):
			continue
		for path: String in EventSheetTranslationScan.files_under(root, ["gd"]):
			found.append(path)
	found.sort()
	return found


## The listing: {role: Array[{label, kind, path, note, role}]} for every role that has a file, in
## ROLE_ORDER. Pure - hand it paths and their sources and it always answers the same thing.
static func entries_from(sources_by_path: Dictionary) -> Dictionary:
	var paths: Array = sources_by_path.keys()
	paths.sort()
	var built: Dictionary = {}
	for role: String in ROLE_ORDER:
		built[role] = []
	for path_entry: Variant in paths:
		var path: String = str(path_entry)
		var role: String = role_for(path, str(sources_by_path[path_entry]))
		var entries: Array = built[role]
		entries.append({
			"label": path.get_file(),
			"kind": ENTRY_KIND,
			"path": path,
			"note": path.get_base_dir().trim_prefix("res://"),
			"role": role,
		})
		built[role] = entries
	for role: String in ROLE_ORDER:
		if (built[role] as Array).is_empty():
			built.erase(role)
	return built


## The listing for the real repo. Reads every source once; called when the folder is first expanded
## and never at boot.
static func entries() -> Dictionary:
	var sources_by_path: Dictionary = {}
	for path: String in source_files():
		sources_by_path[path] = FileAccess.get_file_as_string(path)
	return entries_from(sources_by_path)


## How many files the listing holds, for the folder's own header line.
static func entry_count(built: Dictionary) -> int:
	var counted: int = 0
	for role: String in ROLE_ORDER:
		counted += (built.get(role, []) as Array).size()
	return counted
