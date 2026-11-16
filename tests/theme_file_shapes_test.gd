# Godot EventSheets - A theme file keeps every value it holds, old or new.
#
# Every theme saved before light colours existed opens, saves and opens again with no value lost and
# none changed, and a second save writes the same text as the first (Godot picks fresh ids for the
# blocks of a file on each save, so the ids are left out of that comparison). A theme whose blocks hold
# a light colour opens with no error and keeps its light colours through a save.
@tool
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")
const P := "theme_file_shapes_test"
const THEME_DIRS: Array[String] = ["res://addons/eventsheet/themes/", "res://demo/themes/"]
const LIGHT_SOURCE := "res://addons/eventsheet/themes/classic_sheet_theme.tres"
const LIGHT_PATH := "user://theme_file_shapes_light.tres"
const LIGHT_LINE := "light_colors = {\"sheet_background_color\": Color(0.95, 0.95, 0.95, 1)}"


static func run() -> bool:
	var ok: bool = true
	for dir_path: String in THEME_DIRS:
		for file_name: String in DirAccess.get_files_at(dir_path):
			if file_name.ends_with(".tres"):
				ok = _round_trip(dir_path.path_join(file_name)) and ok
	ok = _light_colours_kept() and ok
	return ok


static func _round_trip(path: String) -> bool:
	var original: EventSheetEditorStyle = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as EventSheetEditorStyle
	if original == null:
		return SUPPORT.check(P, "%s opens as a theme" % path.get_file(), false, true)
	var first_path: String = "user://theme_file_shapes_1_%s" % path.get_file()
	var second_path: String = "user://theme_file_shapes_2_%s" % path.get_file()
	ResourceSaver.save(original, first_path)
	var reopened: EventSheetEditorStyle = ResourceLoader.load(first_path, "", ResourceLoader.CACHE_MODE_IGNORE) as EventSheetEditorStyle
	ResourceSaver.save(reopened, second_path)
	var changed: Array[String] = _values_that_differ(original, reopened)
	var ok: bool = SUPPORT.check(P, "%s keeps every value through a save" % path.get_file(), changed, [])
	ok = SUPPORT.check(P, "%s writes the same text when saved again" % path.get_file(),
		_without_ids(FileAccess.get_file_as_string(second_path)), _without_ids(FileAccess.get_file_as_string(first_path))) and ok
	DirAccess.remove_absolute(ProjectSettings.globalize_path(first_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(second_path))
	return ok


static func _light_colours_kept() -> bool:
	var source: String = FileAccess.get_file_as_string(LIGHT_SOURCE)
	# The event block is the one whose script is the event style; the line goes right under its script line.
	var event_script_id: String = ""
	for line: String in source.split("\n"):
		if line.begins_with("[ext_resource") and line.contains("event_sheet_event_style.gd"):
			event_script_id = line.get_slice(" id=\"", 1).get_slice("\"", 0)
	var anchor: String = "script = ExtResource(\"%s\")" % event_script_id
	var at: int = source.find(anchor)
	var ok: bool = SUPPORT.check(P, "the starter has an event block to give a light colour", at >= 0, true)
	if at < 0:
		return ok
	var with_light: String = source.insert(at + anchor.length(), "\n" + LIGHT_LINE)
	var file: FileAccess = FileAccess.open(LIGHT_PATH, FileAccess.WRITE)
	file.store_string(with_light)
	file.close()
	var lit: EventSheetEditorStyle = ResourceLoader.load(LIGHT_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as EventSheetEditorStyle
	ok = SUPPORT.check(P, "a theme with a light colour opens as a theme", lit != null, true) and ok
	if lit == null:
		return ok
	var held: Variant = lit.get_event_style().get("light_colors")
	ok = SUPPORT.check(P, "its event block holds the light colour",
		(held as Dictionary).get("sheet_background_color") if held is Dictionary else null, Color(0.95, 0.95, 0.95, 1)) and ok
	ResourceSaver.save(lit, LIGHT_PATH)
	ok = SUPPORT.check(P, "and a save keeps it", FileAccess.get_file_as_string(LIGHT_PATH).contains("light_colors = {"), true) and ok
	DirAccess.remove_absolute(ProjectSettings.globalize_path(LIGHT_PATH))
	return ok


## Every stored value of every block that differs between the two themes, as "block.name".
static func _values_that_differ(first: EventSheetEditorStyle, second: EventSheetEditorStyle) -> Array[String]:
	var out: Array[String] = []
	var pairs: Array[Array] = [
		["style", first, second],
		["event", first.event_style, second.event_style],
		["condition", first.condition_style, second.condition_style],
		["action", first.action_style, second.action_style],
		["reading", first.reading_style, second.reading_style],
		["chrome", first.chrome_style, second.chrome_style],
		["manual", first.manual_style, second.manual_style],
	]
	for pair: Array in pairs:
		var a: Resource = pair[1]
		var b: Resource = pair[2]
		if a == null or b == null:
			if a != b:
				out.append("%s missing" % pair[0])
			continue
		for property: Dictionary in a.get_property_list():
			if not (int(property.get("usage", 0)) & PROPERTY_USAGE_STORAGE) or not (int(property.get("usage", 0)) & PROPERTY_USAGE_SCRIPT_VARIABLE):
				continue
			var name: String = str(property.get("name"))
			if typeof(a.get(name)) == TYPE_OBJECT:
				continue
			if a.get(name) != b.get(name):
				out.append("%s.%s" % [pair[0], name])
	return out


## The file's text with the ids Godot picks afresh on each save taken out.
static func _without_ids(text: String) -> String:
	var ids: RegEx = RegEx.create_from_string(" id=\"[^\"]*\"|(Ext|Sub)Resource\\(\"[^\"]*\"\\)")
	return ids.sub(text, "", true)
