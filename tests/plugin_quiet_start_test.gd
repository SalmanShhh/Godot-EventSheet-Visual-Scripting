# EventForge - the plugin starts and stops without printing errors into the user's Output panel.
#
# Four things used to print on an ordinary project:
#   - quitting the editor: the bridge autoload was taken out in _exit_tree, which also runs while the
#     editor tears its tree down, and removing the autoload node then hit a parent busy freeing its
#     children ("Parent node is busy adding/removing children"). It now goes in _disable_plugin;
#   - a project without the drawing-prefab pack: the thumbnail generator named the pack's class, so
#     the file failed to compile and the plugin's start-up stopped half way ("Could not find type");
#   - the very first boot: the workspace icon was loaded before the import had reached it;
#   - the first import: the translators' template CSV was imported as a translation with an empty
#     locale ("Locale 'xx' does not contain any translation").
# And the general rule behind the second one: no file of the plugin names a class a pack declares.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "plugin_quiet_start_test"
const PLUGIN_PATH := "res://addons/eventforge/plugin.gd"
const GENERATOR_PATH := "res://addons/eventsheet/editor/inspector/drawing_prefab_preview_generator.gd"
const TEMPLATE_IMPORT := "res://addons/eventsheet/translations/TEMPLATE.csv.import"


static func run() -> bool:
	var source: String = FileAccess.get_file_as_string(PLUGIN_PATH)
	var import_file: ConfigFile = ConfigFile.new()
	import_file.load(TEMPLATE_IMPORT)
	return SUPPORT.pins(P, [
		["_exit_tree no longer takes the autoload out", _body_of(source, "_exit_tree").contains("remove_autoload_singleton"), false],
		["switching the plugin off does", _body_of(source, "_disable_plugin").contains("remove_autoload_singleton(BRIDGE_NAME)"), true],
		["switching it on puts it in", _body_of(source, "_enable_plugin").contains("add_autoload_singleton(BRIDGE_NAME, BRIDGE_PATH)"), true],
		["a start only adds it when project.godot lacks it",
			_body_of(source, "_enter_tree").contains("if not ProjectSettings.has_setting(\"autoload/%s\" % BRIDGE_NAME):"), true],
		["the icon is asked for only once it is imported",
			_body_of(source, "_get_plugin_icon").contains("ResourceLoader.exists(PLUGIN_ICON_PATH)"), true],
		["the thumbnail generator compiles on its own", (load(GENERATOR_PATH) as GDScript).can_instantiate(), true],
		["the translators' template is kept, not imported", str(import_file.get_value("remap", "importer", "")), "keep"],
		["no plugin file names a class a pack declares", _pack_classes_named_by_plugin(), []],
	])


## The body of `func <name>(` in `source`, up to the next top-level line.
static func _body_of(source: String, function_name: String) -> String:
	var lines: PackedStringArray = source.split("\n")
	var out: PackedStringArray = PackedStringArray()
	var inside: bool = false
	for line: String in lines:
		if line.begins_with("func %s(" % function_name):
			inside = true
			continue
		if inside:
			if not line.is_empty() and not line.begins_with("\t"):
				break
			out.append(line)
	return "\n".join(out)


## "<file>:<line> <Class>" for every line of code under addons/ that names a pack's class_name outside
## a string or a comment. A project without that pack has no such name, so the file cannot compile.
static func _pack_classes_named_by_plugin() -> Array:
	var classes: PackedStringArray = PackedStringArray()
	var declare: RegEx = RegEx.create_from_string("^class_name\\s+(\\w+)")
	for path: String in _gd_files("res://eventsheet_addons"):
		for line: String in FileAccess.get_file_as_string(path).split("\n"):
			var found: RegExMatch = declare.search(line)
			if found != null:
				classes.append(found.get_string(1))
	if classes.is_empty():
		return []
	var named: RegEx = RegEx.create_from_string("\\b(%s)\\b" % "|".join(classes))
	var strings: RegEx = RegEx.create_from_string("\"(?:[^\"\\\\]|\\\\.)*\"")
	var offenders: Array = []
	for path: String in _gd_files("res://addons"):
		var number: int = 0
		for line: String in FileAccess.get_file_as_string(path).split("\n"):
			number += 1
			var code: String = strings.sub(line, "\"\"", true).get_slice("#", 0)
			var hit: RegExMatch = named.search(code)
			if hit != null:
				offenders.append("%s:%d %s" % [path, number, hit.get_string(1)])
	return offenders


static func _gd_files(root: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var dir: DirAccess = DirAccess.open(root)
	if dir == null:
		return out
	for file: String in dir.get_files():
		if file.ends_with(".gd"):
			out.append(root.path_join(file))
	for sub: String in dir.get_directories():
		if not sub.begins_with("."):
			out.append_array(_gd_files(root.path_join(sub)))
	return out
