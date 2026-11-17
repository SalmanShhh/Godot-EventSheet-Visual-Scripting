# Godot EventSheets - which theme files may be written, where a copy goes, and the theme every sheet wears.
#
# DELIBERATELY NO `class_name`: callers load it by path at the moment they ask, so the first open of
# the workspace does not compile it. Everything here is a plain static question or one file write, so
# the Theme Editor window, the Sheet theme menu and the FileSystem's right-click door share one answer.
@tool
extends RefCounted


## The project setting that names the theme file a sheet wears when it chose none of its own.
const DEFAULT_SETTING := "eventsheets/theme/default_theme"
## Where a copy of a starter is made: the project's own themes folder, which the Sheet theme menu lists.
const COPY_DIR := "res://eventsheet_themes/"
## A theme under one of these folders came with the plugin or with the demos. A plugin update would
## replace it, so it is never written; a copy is made in the project instead.
const SHIPPED_FOLDERS: Array[String] = ["res://addons/", "res://demo/"]
## The script class every theme file names on its first line.
const THEME_CLASS := "EventSheetEditorStyle"


## Whether a theme at this path came with the plugin or a demo.
static func is_shipped(path: String) -> bool:
	for folder: String in SHIPPED_FOLDERS:
		if path.begins_with(folder):
			return true
	return false


## Whether Save may write this file: a real theme file of the project's own, not a shipped one.
static func can_save_in_place(path: String) -> bool:
	if path.is_empty() or is_shipped(path):
		return false
	return path.get_extension().to_lower() in ["tres", "res"]


## The file a style came from, or "" for a style that has none (the editor-matched default, or a copy
## kept inside a sheet, whose path names the sheet).
static func file_of(style: Resource) -> String:
	if style == null:
		return ""
	var path: String = style.resource_path
	return "" if path.contains("::") else path


## Whether a file is a theme, read from its first line without loading it.
static func is_theme_file(path: String) -> bool:
	if path.get_extension().to_lower() != "tres" or not FileAccess.file_exists(path):
		return false
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var head: String = file.get_buffer(400).get_string_from_utf8()
	return head.begins_with("[gd_resource") and head.contains("script_class=\"%s\"" % THEME_CLASS)


## The name a copy of this theme is offered under: "editor_native_theme.tres" gives "editor_native_copy.tres".
static func copy_name(path: String) -> String:
	var base: String = path.get_file().get_basename()
	if base.ends_with("_theme"):
		base = base.trim_suffix("_theme")
	return "%s_copy.tres" % base


## The path a copy is offered at: its name in the project's themes folder, numbered when taken.
static func copy_path(source: String, folder: String = COPY_DIR) -> String:
	return unique_path(folder, copy_name(source))


## `file_name` in `folder`, numbered ("my_theme_2.tres") when a file of that name is already there.
static func unique_path(folder: String, file_name: String) -> String:
	var path: String = folder.path_join(file_name)
	var number: int = 2
	while FileAccess.file_exists(path):
		path = folder.path_join("%s_%d.tres" % [file_name.get_basename(), number])
		number += 1
	return path


## The theme file the project says every sheet wears, or "" when it names none.
static func project_default_path() -> String:
	return str(ProjectSettings.get_setting(DEFAULT_SETTING, "")).strip_edges()


## The theme the project says every sheet wears, or null when none is named or the file is not a theme.
static func project_default_style() -> EventSheetEditorStyle:
	var path: String = project_default_path()
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return ResourceLoader.load(path) as EventSheetEditorStyle


## Writes `working` into the theme file at `path`. The style the sheets already wear from that file is
## changed in place and then says it changed, so every sheet wearing it repaints; nothing is written for
## a shipped theme.
static func write_in_place(path: String, working: EventSheetEditorStyle) -> Error:
	if not can_save_in_place(path):
		return ERR_UNAUTHORIZED
	var copy: EventSheetEditorStyle = working.duplicate(true) as EventSheetEditorStyle
	var live: EventSheetEditorStyle = null
	if ResourceLoader.exists(path):
		live = ResourceLoader.load(path) as EventSheetEditorStyle
	if live == null:
		return ResourceSaver.save(copy, path)
	for info: Dictionary in copy.get_property_list():
		var usage: int = int(info.get("usage", 0))
		if usage & PROPERTY_USAGE_SCRIPT_VARIABLE and usage & PROPERTY_USAGE_STORAGE:
			live.set(str(info["name"]), copy.get(str(info["name"])))
	var error: Error = ResourceSaver.save(live, path)
	if error == OK:
		live.emit_changed()
	return error


## Names the theme every sheet wears by default ("" goes back to matching the editor). In the editor the
## setting is written to project.godot as one step of Godot's own undo, so Edit > Undo puts the earlier
## choice back. Returns the theme it replaced ("" when there was none).
static func set_project_default(path: String) -> String:
	var replaced: String = str(ProjectSettings.get_setting(DEFAULT_SETTING, "")) if ProjectSettings.has_setting(DEFAULT_SETTING) else ""
	var label: String = EventSheetL10n.translate("Use %s for every sheet") % path.get_file() if not path.is_empty() \
		else EventSheetL10n.translate("Match the editor again")
	load("res://addons/eventforge/editor/undo_steps.gd").call("project_setting_step", DEFAULT_SETTING, path, label)
	return replaced
