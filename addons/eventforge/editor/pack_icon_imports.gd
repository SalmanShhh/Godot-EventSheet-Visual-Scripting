# EventForge - keeps the icons of a project's packs and the picker's section icons drawn in the
# editor's own icon colours.
#
# Godot draws its own icons in one ink and recolours them for a light theme; it does the same for an
# icon of ours only when the icon's import says so (editor/convert_colors_with_editor_theme). The repo
# ships that import beside every icon, but a pack added to a project from the behaviour library
# arrives without one (the library never carries Godot's import files), so the editor imports it with
# the flag off and the icon stays pale on a light theme. This turns the flag on, and lists the
# icons to be imported again when the editor's theme changes, because the colours are baked at import.
#
# Loaded by path from the plugin, so nothing names it and the editor never compiles it unless asked.
@tool
extends RefCounted

const PACK_ROOT: String = "res://eventsheet_addons"
const SECTION_ROOT: String = "res://addons/eventsheet/icons/sections"
const FLAG_OFF: String = "editor/convert_colors_with_editor_theme=false"
const FLAG_ON: String = "editor/convert_colors_with_editor_theme=true"
const SCALE_OFF: String = "editor/scale_with_editor_scale=false"
const SCALE_ON: String = "editor/scale_with_editor_scale=true"


## The icons of the packs this project holds: each pack folder's icon.svg and icon_3d.svg.
static func pack_icon_paths() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	# A project with no behaviours yet has no such folder: nothing to look after, and nothing to print.
	if not DirAccess.dir_exists_absolute(PACK_ROOT):
		return out
	for folder: String in DirAccess.get_directories_at(PACK_ROOT):
		for file_name: String in ["icon.svg", "icon_3d.svg"]:
			var path: String = "%s/%s/%s" % [PACK_ROOT, folder, file_name]
			if FileAccess.file_exists(path):
				out.append(path)
	return out


## Every icon of ours the editor bakes colours into: the packs' and the picker sections'.
static func all_icon_paths() -> PackedStringArray:
	var out: PackedStringArray = pack_icon_paths()
	for file_name: String in DirAccess.get_files_at(SECTION_ROOT):
		if file_name.ends_with(".svg"):
			out.append("%s/%s" % [SECTION_ROOT, file_name])
	return out


## Turns the flag on in the import of each icon whose import has it off, and returns those icons: they
## are what the editor has to import again. An icon with no import yet is left to the editor.
static func follow_the_editor_theme(paths: PackedStringArray) -> PackedStringArray:
	var changed: PackedStringArray = PackedStringArray()
	for path: String in paths:
		var import_path: String = path + ".import"
		if not FileAccess.file_exists(import_path):
			continue
		var text: String = FileAccess.get_file_as_string(import_path)
		if not text.contains(FLAG_OFF):
			continue
		var file: FileAccess = FileAccess.open(import_path, FileAccess.WRITE)
		if file == null:
			continue
		file.store_string(text.replace(FLAG_OFF, FLAG_ON).replace(SCALE_OFF, SCALE_ON))
		file.close()
		changed.append(path)
	return changed
