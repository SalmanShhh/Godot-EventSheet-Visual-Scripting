# EventSheet - bundled theme discovery for the toolbar theme switcher.
# Scans the theme directories for EventSheetEditorStyle resources and returns selectable
# presets. The built-in (palette) look is offered separately as "Default" by the dock.
@tool
class_name EventSheetThemePresets
extends RefCounted

## Directories scanned for theme resources, in priority order. Addon-local themes win over
## demo themes when both define the same file name.
const THEME_DIRS: Array[String] = [
	"res://addons/eventsheet/themes/",
	"res://demo/themes/"
]


## Returns [{name: String, path: String}] for every EventSheetEditorStyle theme found,
## sorted by display name.
static func list_presets() -> Array[Dictionary]:
	var presets: Array[Dictionary] = []
	var seen_names: Dictionary = {}
	for dir_path in THEME_DIRS:
		var dir: DirAccess = DirAccess.open(dir_path)
		if dir == null:
			continue
		for file_name in dir.get_files():
			if not (file_name.ends_with(".tres") or file_name.ends_with(".res")):
				continue
			var display_name: String = _humanize(file_name)
			if seen_names.has(display_name):
				continue
			var full_path: String = dir_path.path_join(file_name)
			var resource: Resource = ResourceLoader.load(full_path)
			if resource is EventSheetEditorStyle:
				seen_names[display_name] = true
				presets.append({"name": display_name, "path": full_path})
	presets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.get("name", "")) < str(b.get("name", "")))
	return presets


## Which tokens a preset FILE actually states, block by block.
##
## A `.tres` omits every property whose value equals the script default, so the loaded resource
## cannot tell "this theme chose that colour" from "this theme never heard of that token". The file
## can, and that difference is the whole question when a new token ships: a preset that never stated
## it is wearing the plugin's own dark default, which is exactly wrong on a pale theme.
##
## Returns one entry per resource block, in file order:
##   [{"script": "event_sheet_reading_style.gd", "tokens": ["primary_text_color", ...]}, ...]
## The condition and action styles share one script, so they arrive as two entries with the same
## script name - callers that care which is which read them in file order.
##
## Matching is per block and anchored at the start of the line, deliberately: a whole-file substring
## search for "text_color = " is also satisfied by "comment_text_color = ", which is how a coverage
## sweep can report a token as covered that no preset ever set.
static func stated_tokens(preset_path: String) -> Array[Dictionary]:
	var blocks: Array[Dictionary] = []
	var script_by_id: Dictionary = {}
	var current: Dictionary = {}
	for raw_line: String in FileAccess.get_file_as_string(preset_path).split("\n"):
		var line: String = raw_line.strip_edges(true, false)
		if line.begins_with("[ext_resource"):
			var path_value: String = _quoted_value(line, "path=\"")
			var id_value: String = _quoted_value(line, "id=\"")
			if not id_value.is_empty():
				script_by_id[id_value] = path_value.get_file()
			continue
		if line.begins_with("[sub_resource") or line.begins_with("[resource]"):
			current = {"script": "", "tokens": [] as Array[String]}
			blocks.append(current)
			continue
		if current.is_empty() or not line.contains(" = "):
			continue
		var token_name: String = line.get_slice(" = ", 0)
		if token_name == "script":
			current["script"] = str(script_by_id.get(_quoted_value(line, "ExtResource(\""), ""))
			continue
		var tokens: Array[String] = current["tokens"]
		tokens.append(token_name)
	return blocks


## The text between a marker's quote and the next one ("" when the marker is absent).
static func _quoted_value(line: String, marker: String) -> String:
	var start: int = line.find(marker)
	if start < 0:
		return ""
	start += marker.length()
	var end: int = line.find("\"", start)
	return line.substr(start, end - start) if end > start else ""


## Turns "gruvbox_dark_theme.tres" into "Gruvbox Dark".
static func _humanize(file_name: String) -> String:
	var base: String = file_name.get_basename()
	if base.ends_with("_theme"):
		base = base.substr(0, base.length() - "_theme".length())
	base = base.replace("_", " ").strip_edges()
	var words: PackedStringArray = base.split(" ", false)
	var titled: Array[String] = []
	for word in words:
		if word.length() > 0:
			titled.append(word.substr(0, 1).to_upper() + word.substr(1))
	return " ".join(titled)
