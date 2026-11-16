# Godot EventSheets - two small decisions about which theme colours and which menu entry apply.
#
# DELIBERATELY NO `class_name`: callers load it by path at the moment they ask, so the first open of
# the workspace does not compile it.
@tool
extends RefCounted


## Whether the script editor's colours may paint the code beside a variable row on a sheet whose rows are
## `sheet_ground`, in an editor whose base colour is `editor_base`: only when both are the same brightness
## (a light sheet theme in a dark editor keeps its own colours, or the code would be unreadable). With no
## editor (a clear base) there are no editor colours to use.
static func use_editor_colours(sheet_ground: Color, editor_base: Color) -> bool:
	if editor_base.a <= 0.0 or sheet_ground.a <= 0.0:
		return editor_base.a > 0.0 and sheet_ground.a <= 0.0
	return EventSheetEditorThemeDeriver.is_light_base(sheet_ground) == EventSheetEditorThemeDeriver.is_light_base(editor_base)


## Which theme menu entry to tick. `paths` is each entry's stored path ("" is Match Editor). No theme on
## the sheet ticks Match Editor; a theme from a file ticks its entry; a theme with no file (the copy
## Apply To Current Sheet writes into the sheet) is none of the entries, so nothing is ticked.
static func menu_index_for(active_path: String, has_style: bool, paths: Array) -> int:
	if not has_style:
		return 0
	if active_path.is_empty():
		return -1
	for i in range(paths.size()):
		if str(paths[i]) == active_path:
			return i
	return 0


## The theme file a style stands for. A style loaded from a file is that file; a copy with no file (a
## Density pick copies the sheet's style) stands for whatever file it was copied from, which `sources`
## remembers by the copy's instance id. "" is a look made from the editor-matched default.
static func source_for(sources: Dictionary, style: Resource) -> String:
	if style == null:
		return ""
	var path: String = style.resource_path
	if not path.is_empty() and not path.contains("::"):
		return path
	return str(sources.get(style.get_instance_id(), ""))


## Whether `source_for` knows where this style came from (a style with a file, or a remembered copy).
static func has_source(sources: Dictionary, style: Resource) -> bool:
	if style == null:
		return false
	var path: String = style.resource_path
	return (not path.is_empty() and not path.contains("::")) or sources.has(style.get_instance_id())


## Remembers that a style with no file was made from `path`. The list stays short; past 24 it starts over.
static func note_source(sources: Dictionary, style: Resource, path: String) -> void:
	if style == null or (not style.resource_path.is_empty() and not style.resource_path.contains("::")):
		return
	if sources.size() > 24:
		sources.clear()
	sources[style.get_instance_id()] = path


## The Sheet theme menu's first entry: it names the project's theme when one is set for every sheet, and
## Match Editor otherwise.
static func first_entry_text(project_theme_path: String) -> String:
	if project_theme_path.is_empty():
		return EventSheetL10n.translate("Match Editor (default)")
	return EventSheetL10n.translate("Project theme: %s") % EventSheetThemePresets._humanize(project_theme_path.get_file())


## The words on a theme's entry in the Sheet theme menu. While the project names a theme for every sheet, the
## first entry is that theme and cannot be the way back to the editor's own look, so the Editor Native starter,
## which is that look, is the entry that says Match Editor.
static func entry_text(preset_name: String, preset_path: String, project_theme_path: String) -> String:
	if not project_theme_path.is_empty() and preset_path == EventSheetEditorThemeDeriver.NATIVE_STARTER_PATH:
		return EventSheetL10n.translate("Match Editor")
	return preset_name
