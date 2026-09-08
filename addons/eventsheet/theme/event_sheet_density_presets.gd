@tool
class_name EventSheetDensityPresets
extends RefCounted

## Discovery for the density starters View > Sheet theme > Density offers.
##
## A starter is an EventSheetDensityStyle `.tres` in one of the folders below. Three ship; a user
## who wants a fourth copies one, edits the numbers and saves it beside them, and it is in the menu
## the next time View opens - no code, no registration list, no restart. That is the whole
## extension story, and it is why the shipped three are files rather than constants.
##
## Order is by ROW HEIGHT, tightest first, so the menu reads as a dial (Compact, Comfortable,
## Spacious) and a user's own starter lands where its spacing puts it rather than where its name
## happens to sort. Ties break on the file name so the walk is stable.

## Folders scanned for density starters, in priority order. Addon-local starters win over project
## ones sharing a display name, exactly as the theme presets do.
const DENSITY_DIRS: Array[String] = [
	"res://addons/eventsheet/themes/density/",
	"res://demo/themes/density/"
]


## Returns [{name: String, path: String, density: EventSheetDensityStyle}] for every starter found.
static func list_presets() -> Array[Dictionary]:
	var presets: Array[Dictionary] = []
	var seen_names: Dictionary = {}
	for dir_path: String in DENSITY_DIRS:
		var dir: DirAccess = DirAccess.open(dir_path)
		if dir == null:
			continue
		var file_names: PackedStringArray = dir.get_files()
		file_names.sort()
		for file_name: String in file_names:
			if not (file_name.ends_with(".tres") or file_name.ends_with(".res")):
				continue
			var display_name: String = _humanize(file_name)
			if seen_names.has(display_name):
				continue
			var full_path: String = dir_path.path_join(file_name)
			var resource: Resource = ResourceLoader.load(full_path)
			if resource is EventSheetDensityStyle:
				seen_names[display_name] = true
				presets.append({
					"name": display_name,
					"path": full_path,
					"density": resource as EventSheetDensityStyle
				})
	presets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_height: int = (a["density"] as EventSheetDensityStyle).row_height
		var b_height: int = (b["density"] as EventSheetDensityStyle).row_height
		if a_height != b_height:
			return a_height < b_height
		return str(a.get("name", "")) < str(b.get("name", ""))
	)
	return presets


## Turns "comfortable_density.tres" into "Comfortable".
static func _humanize(file_name: String) -> String:
	var base: String = file_name.get_basename()
	if base.ends_with("_density"):
		base = base.substr(0, base.length() - "_density".length())
	base = base.replace("_", " ").strip_edges()
	var titled: Array[String] = []
	for word: String in base.split(" ", false):
		if word.length() > 0:
			titled.append(word.substr(0, 1).to_upper() + word.substr(1))
	return " ".join(titled)
