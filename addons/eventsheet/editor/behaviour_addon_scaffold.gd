# Godot EventSheets - the files the New behaviour and New global windows write.
#
# A behaviour is one script in its own folder under eventsheet_addons/: it extends Node, is added as a
# child of the object it works on, and reaches that object as `host`. A global is Godot's autoload: one
# script (or one scene) Godot loads before the first scene and keeps for the whole game. Both live in a
# folder of their own under eventsheet_addons/, because that folder is how the plugin finds what a
# script offers - there is no list to register in.
#
# A new one is written as an ordinary sheet compiled to plain GDScript, so the file reopens as the
# sheet it was made from and a behaviour has the shape every shipped pack has. A copy is the source it
# was copied from with its header rewritten. Pure and static: the window collects the answers, these
# turn them into text.
@tool
class_name EventSheetBehaviourAddonScaffold
extends RefCounted

## Where every behaviour and global made here lives (and where the plugin reads what they offer).
const ROOT := "res://eventsheet_addons"
## The tag that marks a behaviour as one the project made itself, so the Add behaviour list puts it first.
const YOURS_TAG := "custom"

## A handful of words that can't be a class_name (would collide with the engine or break parsing).
const _RESERVED: PackedStringArray = [
	"Node", "Object", "Resource", "RefCounted", "Variant", "Signal", "Callable", "Array", "Dictionary",
	"String", "int", "float", "bool", "true", "false", "null", "self", "class", "func", "var", "const",
	"if", "else", "for", "while", "return", "match", "enum", "signal", "extends", "tool"
]


## True when `addon_name` is usable as a GDScript class_name: a plain identifier that isn't a reserved word
## and isn't already a registered global class (which would be a duplicate class_name error).
static func is_valid_class_name(addon_name: String) -> bool:
	var name: String = addon_name.strip_edges()
	if not name.is_valid_ascii_identifier() or _RESERVED.has(name) or ClassDB.class_exists(name):
		return false
	# A duplicate class_name is a HARD project-wide parse error, not just a bad file - so also reject names
	# already taken by a global script class (ClassDB only knows engine classes).
	for global_class: Dictionary in ProjectSettings.get_global_class_list():
		if str(global_class.get("class", "")) == name:
			return false
	return true


## The script a behaviour or global called `addon_name` is written to: its own folder, both snake_cased.
static func script_path_for(addon_name: String) -> String:
	var folder: String = addon_name.strip_edges().to_snake_case()
	return ROOT.path_join(folder).path_join(folder + ".gd")


## The scene a global made as a scene is written to, beside its script.
static func scene_path_for(addon_name: String) -> String:
	return script_path_for(addon_name).get_basename() + ".tscn"


## A new behaviour as a sheet: it works on `works_on` (typed as its host), sits on the `category`
## shelf, is marked as yours, and wears `icon_path` when one is given.
static func behaviour_sheet(addon_name: String, works_on: String, category: String, description: String,
		icon_path: String = "") -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = works_on if ClassDB.class_exists(works_on) else "Node"
	sheet.custom_class_name = addon_name.strip_edges()
	sheet.addon_tags = PackedStringArray([YOURS_TAG])
	sheet.addon_category = _one_line(category)
	sheet.class_description = _one_line(description)
	sheet.custom_class_icon = icon_path
	return sheet


## A new global as a sheet: a plain Node script with no class_name, because Godot refuses a class
## named like an autoload - the autoload's own name is what every script reaches it by.
static func global_sheet(description: String) -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.autoload_mode = true
	sheet.class_description = _one_line(description)
	return sheet


## The file a sheet becomes, exactly as the sheet writes it on save.
static func source_of(sheet: EventSheetResource) -> String:
	return str(SheetCompiler.echo(sheet, true).get("output", ""))


## `variables` added to a new sheet, in their order - what "From a script I wrote" carries over.
static func with_variables(sheet: EventSheetResource, variables: Array[LocalVariable]) -> EventSheetResource:
	for variable: LocalVariable in variables:
		sheet.events.append(variable.duplicate(true))
	return sheet


## What a script declares that a new behaviour or global takes over: its exported variables for a
## behaviour (its properties), every variable that is not a constant for a global (its values).
static func carried_variables(script_path: String, exported_only: bool) -> Array[LocalVariable]:
	var carried: Array[LocalVariable] = []
	if not FileAccess.file_exists(script_path):
		return carried
	var opened: EventSheetResource = GDScriptImporter.new().import_external(script_path)
	for entry: Variant in opened.events if opened != null else []:
		var variable: LocalVariable = entry as LocalVariable
		if variable != null and not variable.is_constant and (variable.exported or not exported_only):
			carried.append(variable)
	return carried


## A copy of `source` (a shipped pack, or a script of your own) made into a new one of yours: the
## class is renamed (or dropped when `keep_class` is false - a global), the header marks it as yours and
## shelves it under `category`, its version line goes because the copy has not shipped, and a
## description you wrote replaces the one it came with. Everything below the header is untouched.
static func copied_source(source: String, addon_name: String, category: String, description: String,
		keep_class: bool) -> String:
	var tags: PackedStringArray = PackedStringArray()
	var header: PackedStringArray = PackedStringArray()
	var lines: PackedStringArray = source.split("\n")
	var index: int = 0
	while index < lines.size() and not lines[index].begins_with("extends "):
		var text: String = lines[index].strip_edges()
		index += 1
		if text.begins_with("## @ace_tags("):
			for tag: String in text.trim_prefix("## @ace_tags(").trim_suffix(")").split(",", false):
				tags.append(tag.strip_edges())
		elif not (text.begins_with("## @ace_category(") or text.begins_with("## @ace_version(")
				or text.begins_with("## @ace_name(") or text.begins_with("class_name ")):
			header.append(lines[index - 1])
	if not tags.has(YOURS_TAG):
		tags.append(YOURS_TAG)
	var out: PackedStringArray = PackedStringArray(["## @ace_tags(%s)" % ", ".join(tags)])
	if not _one_line(category).is_empty():
		out.append("## @ace_category(\"%s\")" % _one_line(category))
	out.append_array(header)
	if keep_class:
		out.append("class_name %s" % addon_name.strip_edges())
	if index < lines.size():
		out.append(lines[index])
		index += 1
	if not _one_line(description).is_empty():
		out.append("## %s" % _one_line(description))
		while index < lines.size() and lines[index].begins_with("##"):
			index += 1
	for rest: int in range(index, lines.size()):
		out.append(lines[rest])
	return "\n".join(out)


## The kind of object a behaviour's source works on - the type of its `host` - or "" when it says none.
static func host_class_of(source: String) -> String:
	var found: RegExMatch = RegEx.create_from_string(
		"(?m)^(?:@onready\\s+)?var host\\s*:\\s*([A-Za-z_][A-Za-z0-9_]*)").search(source)
	return "" if found == null else found.get_string(1)


## True when the source is marked as one the project made itself (its header tags include `custom`).
static func is_yours(source: String) -> bool:
	var found: RegExMatch = RegEx.create_from_string("(?m)^##\\s*@ace_tags\\(([^)]*)\\)").search(source)
	if found == null:
		return false
	for tag: String in found.get_string(1).split(",", false):
		if tag.strip_edges() == YOURS_TAG:
			return true
	return false


## A global made as a scene: one root Node named for it, carrying its script.
static func global_scene(addon_name: String, script: Script) -> PackedScene:
	var root: Node = Node.new()
	root.name = addon_name.strip_edges()
	root.set_script(script)
	var scene: PackedScene = PackedScene.new()
	scene.pack(root)
	root.free()
	return scene


## A user string made safe for one `## ...` line or one `## @ace_*("...")` argument: a newline would
## split the comment (a parse error on the next line) and a double quote would end the argument early.
static func _one_line(text: String) -> String:
	return text.replace("\r", " ").replace("\n", " ").replace("\"", "'").strip_edges()
