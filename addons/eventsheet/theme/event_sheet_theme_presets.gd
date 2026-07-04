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
