# Godot EventSheets — project-local sheet templates
#
# Zero-config, same convention as eventsheet_addons/: drop a sheet .tres into
# res://eventsheet_templates/ (override with eventsheets/project/templates_dir) and it
# joins the dock's New… menu under "Project templates". Teams encode THEIR starting
# points (a boss-fight skeleton, the studio's autoload layout) once and every new
# sheet starts there — the dock's "Save as Template" writes the current sheet in.
#
# Templates are blueprints, not live game code: the Project Doctor and the vocabulary
# doc skip them (non_template_sheets / is_template_path).
@tool
class_name EventSheetTemplates
extends RefCounted

const DEFAULT_DIR := "res://eventsheet_templates"


static func templates_dir() -> String:
	return str(ProjectSettings.get_setting("eventsheets/project/templates_dir", DEFAULT_DIR)).trim_suffix("/")


static func is_template_path(path: String) -> bool:
	return path.begins_with(templates_dir() + "/")


## Every sheet .tres under the templates dir (recursive), sorted for stable menus.
static func list_templates() -> PackedStringArray:
	var templates: PackedStringArray = PackedStringArray()
	var pending: PackedStringArray = PackedStringArray([templates_dir()])
	while not pending.is_empty():
		var directory_path: String = pending[pending.size() - 1]
		pending.remove_at(pending.size() - 1)
		var dir: DirAccess = DirAccess.open(directory_path)
		if dir == null:
			continue
		dir.list_dir_begin()
		var entry: String = dir.get_next()
		while not entry.is_empty():
			var full_path: String = directory_path.path_join(entry)
			if dir.current_is_dir():
				if not entry.begins_with("."):
					pending.append(full_path)
			elif entry.ends_with(".tres") and ResourceLoader.load(full_path, "", ResourceLoader.CACHE_MODE_REUSE) is EventSheetResource:
				templates.append(full_path)
			entry = dir.get_next()
		dir.list_dir_end()
	templates.sort()
	return templates


## A deep, path-less copy of a template — adopting it can never mutate the template
## (shared sub-resources would otherwise leak edits back into the blueprint).
static func load_copy(template_path: String) -> EventSheetResource:
	var template: EventSheetResource = ResourceLoader.load(template_path, "", ResourceLoader.CACHE_MODE_IGNORE) as EventSheetResource
	if template == null:
		return null
	return template.duplicate(true) as EventSheetResource


## Filter for project-health consumers (doctor, vocabulary doc): everything except
## templates — blueprints have no generated output, no scene, no live vocabulary.
static func non_template_sheets(sheet_paths: PackedStringArray) -> PackedStringArray:
	var live: PackedStringArray = PackedStringArray()
	for sheet_path: String in sheet_paths:
		if not is_template_path(sheet_path):
			live.append(sheet_path)
	return live
