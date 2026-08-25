@tool
class_name EditorPluginReadingTest
extends RefCounted

# Pins what a script that extends one of the editor's own plugin classes reads as.
#
# The claim these gates protect is narrow and total: the reading is keyed off the class the file
# EXTENDS and nothing else, it changes only what is drawn, and the file still saves the bytes it
# opened. So there are five gates:
#   1. an opened EditorPlugin reads with the Editor object's plugin triggers - the two lifetimes
#      told apart (enabled / first turned on), the questions read as questions, and the add_* calls
#      read as what they add rather than as the engine method that adds it;
#   2. its head bar states the three constant-answer virtuals as facts, and their rows are gone;
#   3. an opened EditorInspectorPlugin reads in the Properties bar's words, with `return true` /
#      `return false` as the handled flag they mean;
#   4. every other plugin class Godot offers has a word and an object of its own;
#   5. neither file moves a byte.
#
# The sources are strings rather than fixtures for the reason the Editor object test gives: the byte
# gate compares against what the COMPILER emits, which puts one blank line between functions, so a
# checked-in two-blank-line file could never round-trip and would test nothing.

const PLUGIN_PATH := "user://eventforge_w2_plugin.gd"
const INSPECTOR_PATH := "user://eventforge_w15_inspector.gd"

const PLUGIN_SOURCE: String = """@tool
extends EditorPlugin

var _menus: Array = []

func _get_plugin_name() -> String:
	return "Sheets"

func _has_main_screen() -> bool:
	return true

func _get_plugin_icon() -> Texture2D:
	return load("res://addons/eventsheet/icons/eventsheet.svg")

func _enter_tree() -> void:
	add_autoload_singleton("Bridge", "res://addons/eventforge/runtime/eventforge_bridge.gd")
	add_inspector_plugin(_edit_button)
	add_export_plugin(_export_integrity)
	add_debugger_plugin(_live_values)
	add_context_menu_plugin(EditorContextMenuPlugin.CONTEXT_SLOT_SCENE_TREE, _menu)

func _exit_tree() -> void:
	remove_autoload_singleton("Bridge")
	remove_inspector_plugin(_edit_button)

func _enable_plugin() -> void:
	_seed_settings()

func _disable_plugin() -> void:
	_forget_settings()

func _handles(object: Object) -> bool:
	return object is Resource

func _make_visible(visible: bool) -> void:
	if visible:
		_ensure_editor()

func _build() -> bool:
	return true

func _save_external_data() -> void:
	_flush()
"""

const INSPECTOR_SOURCE: String = """@tool
extends EditorInspectorPlugin

func _can_handle(object: Object) -> bool:
	return object is Node

func _parse_begin(object: Object) -> void:
	add_custom_control(_button_for(object))

func _parse_property(object, type, name, hint, hint_text, usage, wide) -> bool:
	if name == "steps":
		add_property_editor(name, _steps_editor())
		return true
	return false
"""

## What the opened plugin must say, in the sheet's own words.
const EXPECTED_PLUGIN: Array[String] = [
	"Editor ▸ On plugin first turned on",
	"Editor ▸ On plugin first turned off",
	"Editor ▸ Asks: can this plugin edit object?",
	"System ▸ Answer object is Resource",
	"Editor ▸ On workspace shown",
	"Editor ▸ On project run",
	"Editor ▸ On save",
	"Editor ▸ Add global \"Bridge\" from \"eventforge_bridge.gd\"",
	"Editor ▸ Remove global \"Bridge\"",
	# The members read under the names the sheet gives members everywhere else, not their identifier
	# spelling - "edit button" is what every other row in every other sheet calls `_edit_button`.
	"Editor ▸ Add Properties bar add-on edit button",
	"Editor ▸ Remove Properties bar add-on edit button",
	"Editor ▸ Add export hook export integrity",
	"Editor ▸ Add debugger panel live values",
	"Editor ▸ Add context menu menu to Scene dock"
]

## And what the opened Properties bar add-on must say.
const EXPECTED_INSPECTOR: Array[String] = [
	"Properties bar ▸ Asks: show this add-on for object?",
	"System ▸ Answer object is Node",
	"Properties bar ▸ On start of object's properties",
	"Properties bar ▸ Add control",
	"Properties bar ▸ On property name of object",
	"System ▸ Answer handled",
	"System ▸ Answer not handled"
]


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _plugin_reads_with_the_editor_object() and all_passed
	all_passed = _head_states_the_constant_answers() and all_passed
	all_passed = _inspector_reads_in_the_properties_bar_words() and all_passed
	all_passed = _every_plugin_class_has_its_own_word() and all_passed
	all_passed = _context_slots_read_as_panels() and all_passed
	all_passed = _the_head_names_who_registered_the_addon() and all_passed
	all_passed = _the_file_level_shape_is_claimed() and all_passed
	all_passed = _round_trips_byte_for_byte() and all_passed
	return all_passed


static func _plugin_reads_with_the_editor_object() -> bool:
	var ok: bool = true
	var readings: PackedStringArray = _render(_import(PLUGIN_PATH, PLUGIN_SOURCE))
	for expected: String in EXPECTED_PLUGIN:
		ok = _check("the opened plugin reads \"%s\"" % expected, readings.has(expected), true) and ok
	# The two lifetimes are told APART, which is the whole reason the second pair exists: adding
	# "first turned on" must not have taken the enabled pair's own rows away.
	ok = _check("the enabled lifetime is still its own row",
		readings.has("Editor ▸ On Plugin Enabled"), true) and ok
	return ok


## The three questions with constant answers are facts on the head bar, and their function rows
## are not drawn a second time underneath it.
static func _head_states_the_constant_answers() -> bool:
	var ok: bool = true
	var joined: String = "\n".join(_render(_import(PLUGIN_PATH, PLUGIN_SOURCE)))
	ok = _check("the head says what kind of add-on it is",
		joined.contains("editor plugin"), true) and ok
	ok = _check("the head names the main screen",
		joined.contains("main screen \"Sheets\""), true) and ok
	ok = _check("the head names the icon", joined.contains("icon eventsheet.svg"), true) and ok
	for gone: String in ["On Get Plugin Name", "On Has Main Screen", "On Get Plugin Icon"]:
		ok = _check("the constant-answer virtual \"%s\" is not a row" % gone,
			joined.contains(gone), false) and ok
	return ok


static func _inspector_reads_in_the_properties_bar_words() -> bool:
	var ok: bool = true
	var readings: PackedStringArray = _render(_import(INSPECTOR_PATH, INSPECTOR_SOURCE))
	var joined: String = "\n".join(readings)
	for expected: String in EXPECTED_INSPECTOR:
		ok = _check("the opened add-on reads \"%s\"" % expected, joined.contains(expected), true) and ok
	ok = _check("the head calls it a Properties bar add-on",
		joined.contains("Properties bar add-on"), true) and ok
	# The words Godot uses are exactly the words a migrating reader cannot act on.
	ok = _check("no callback reads as its engine virtual", joined.contains("On Parse Property"), false) and ok
	return ok


## Every plugin class Godot offers has a word of its own and an object to wear it, so no
## opened add-on falls back to reading as a nameless helper.
static func _every_plugin_class_has_its_own_word() -> bool:
	var ok: bool = true
	var expected: Dictionary = {
		"EditorPlugin": ["Editor", "editor plugin"],
		"EditorInspectorPlugin": ["Properties bar", "Properties bar add-on"],
		"EditorImportPlugin": ["Importer", "Importer add-on"],
		"EditorExportPlugin": ["Export hook", "Export hook"],
		"EditorDebuggerPlugin": ["Debugger panel", "Debugger panel"],
		"EditorResourcePreviewGenerator": ["Thumbnail maker", "Thumbnail maker"],
		"EditorContextMenuPlugin": ["Context menu", "Context menu"],
		"EditorSyntaxHighlighter": ["Code colours", "Code colours"],
		"EditorTranslationParserPlugin": ["Text finder", "Text finder"]
	}
	for host_class: String in expected:
		var pair: Array = expected[host_class]
		ok = _check("%s wears the object %s" % [host_class, str(pair[0])],
			EventSheetEditorPluginWords.object_for(host_class), str(pair[0])) and ok
		ok = _check("%s is called a %s" % [host_class, str(pair[1])],
			EventSheetEditorPluginWords.head_word_for(host_class), str(pair[1])) and ok
	# A class that is NOT one of them must claim nothing at all - the gate that keeps every game
	# script's `add_file` reading as it always did.
	ok = _check("a plain node claims no editor words",
		EventSheetEditorPluginWords.is_editor_plugin_class("CharacterBody2D"), false) and ok
	ok = _check("a plain node's add_file is not the exporter's",
		EventSheetEditorPluginWords.verb_for("CharacterBody2D", "add_file").is_empty(), true) and ok
	return ok


## The four right-click surfaces read as the panels they name, and the longest spelling wins - a
## naive replace would leave "Project bar_CREATE" behind.
static func _context_slots_read_as_panels() -> bool:
	var ok: bool = true
	var pairs: Array = [
		["EditorContextMenuPlugin.CONTEXT_SLOT_SCENE_TREE", "Scene dock"],
		["EditorContextMenuPlugin.CONTEXT_SLOT_FILESYSTEM", "Project bar"],
		["EditorContextMenuPlugin.CONTEXT_SLOT_FILESYSTEM_CREATE", "Project bar ▸ Create new"],
		["EditorContextMenuPlugin.CONTEXT_SLOT_SCRIPT_EDITOR", "Script editor"]
	]
	for pair: Array in pairs:
		ok = _check("%s reads as %s" % [str(pair[0]).get_file(), str(pair[1])],
			EventSheetEditorPluginWords.context_slot_words(str(pair[0])), str(pair[1])) and ok
	return ok


## The head bar's receipt: who registered this add-on with the editor. Proved against THIS
## project's own plugin, which is the only kind of file the walk is allowed to name - an add-on
## registered by nothing here must say nothing rather than guess.
static func _the_head_names_who_registered_the_addon() -> bool:
	var ok: bool = true
	EventSheetEditorPluginWords.clear_added_by_cache()
	ok = _check("the Properties bar add-on names the plugin that registers it",
		EventSheetEditorPluginWords.added_by("EventSheetEditButtonPlugin"), "EventForgePlugin") and ok
	ok = _check("an add-on nothing here registers names nobody",
		EventSheetEditorPluginWords.added_by("SomeAddonNoProjectFileRegisters"), "") and ok
	return ok


## The reading claims the file's shape once, for the whole file, with nothing to adopt.
static func _the_file_level_shape_is_claimed() -> bool:
	var ok: bool = true
	var sheet: EventSheetResource = _import(PLUGIN_PATH, PLUGIN_SOURCE)
	_render(sheet)
	var patterns: PackedStringArray = PackedStringArray()
	var adoptable: String = "-"
	for entry: Variant in EventSheetPatternFacts.claims(sheet):
		patterns.append(str((entry as Dictionary).get("pattern", "")))
		if str((entry as Dictionary).get("pattern", "")) == "editor_plugin":
			adoptable = str((entry as Dictionary).get("adoptable", ""))
	ok = _check("the plugin's shape is claimed", patterns.has("editor_plugin"), true) and ok
	ok = _check("there is nothing to adopt - it IS the plugin", adoptable, "") and ok
	return ok


## A reading may never cost a byte: opening either file and saving it untouched reproduces it exactly.
static func _round_trips_byte_for_byte() -> bool:
	var ok: bool = true
	for pair: Array in [[PLUGIN_PATH, PLUGIN_SOURCE], [INSPECTOR_PATH, INSPECTOR_SOURCE]]:
		var sheet: EventSheetResource = _import(str(pair[0]), str(pair[1]))
		var output: String = str(SheetCompiler.compile(sheet, str(pair[0])).get("output", ""))
		ok = _check("opening %s and saving it reproduces every byte" % str(pair[0]).get_file(),
			output, str(pair[1])) and ok
	return ok


static func _import(path: String, source: String) -> EventSheetResource:
	var handle: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	handle.store_string(source)
	handle.close()
	return GDScriptImporter.new().import_external(path)


## The readings of one sheet, straight off the canvas's own spans.
static func _render(sheet: EventSheetResource) -> PackedStringArray:
	sheet.read_only = true
	var style: EventSheetEditorStyle = EventSheetEditorStyle.new()
	style.ensure_defaults()
	sheet.editor_style = style
	var viewport: EventSheetViewport = EventSheetViewport.new()
	viewport.set_ace_registry(EventSheetACERegistry.new())
	viewport.set_sheet(sheet)
	viewport.set_reading_mode(true)
	var readings: PackedStringArray = PackedStringArray()
	for row_data: EventRowData in _walk(viewport._root_rows, viewport):
		for span: SemanticSpan in row_data.spans:
			var label: String = str(span.metadata.get("object_label", ""))
			var text: String = span.text.strip_edges()
			readings.append("%s ▸ %s" % [label, text] if not label.is_empty() else text)
	viewport.free()
	return readings


## Every row in the tree, parents before children.
static func _walk(rows: Array, viewport: EventSheetViewport) -> Array:
	var found: Array = []
	for row_data: EventRowData in rows:
		viewport._row_builder._ensure_event_spans(row_data)
		found.append(row_data)
		found.append_array(_walk(row_data.children, viewport))
	return found


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] editor plugin reading: %s" % label)
		return true
	print("[FAIL] editor plugin reading: %s - expected %s, got %s" % [label, str(expected), str(actual)])
	return false
