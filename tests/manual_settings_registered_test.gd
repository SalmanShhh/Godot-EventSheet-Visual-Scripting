# Godot EventSheets - Every project setting the Manual tells a reader to turn on is registered.
#
# A setting that is only read with a fallback (`ProjectSettings.get_setting(name, default)`) is not in
# Project Settings at all, so a reader told by the Manual to turn it on finds nothing to turn on. The
# Manual's pages are swept for every setting they name; each one must be one of the registered
# settings, or one of the Editor Settings the plugin registers on the editor side (kept per user, so
# never in Project Settings).
@tool
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")
const P := "manual_settings_registered_test"
const HELP_DIR := "res://addons/eventsheet/help/"
## Settings the Manual names that live in Editor Settings on purpose (one person's choice, not the
## project's): a key of your own, and the plugin's own language.
const EDITOR_SIDE: Array[String] = ["eventsheets/ask/api_key", "eventsheets/interface/language_override"]
## Settings the plugin writes itself to remember an answer, never one a reader sets by hand.
const REMEMBERED: Array[String] = ["eventsheets/addons/disabled_packs", "eventsheets/mistakes/known_at_run_time"]


static func run() -> bool:
	var registered: Array[String] = []
	for definition: Dictionary in EventSheetSettings.DEFINITIONS:
		registered.append(str(definition.get("name", "")))
	var named: Dictionary = {}
	var pattern: RegEx = RegEx.create_from_string("eventsheets/[a-z_]+/[a-z_]+")
	for path: String in _guide_pages(HELP_DIR):
		for found: RegExMatch in pattern.search_all(FileAccess.get_file_as_string(path)):
			named[found.get_string()] = true
	var missing: Array[String] = []
	for setting_name: String in named:
		if registered.has(setting_name) or EDITOR_SIDE.has(setting_name) or REMEMBERED.has(setting_name):
			continue
		missing.append(setting_name)
	missing.sort()
	var ok: bool = SUPPORT.check(P, "every project setting the Manual names is in Project Settings", missing, [])
	# The Doctor says this answer is kept for good; it has to be a setting a reader can find again.
	ok = SUPPORT.check(P, "the error-report question's answer is a registered setting",
		registered.has("eventsheets/doctor/suggest_error_report"), true) and ok
	return ok


## The Manual's own pages: the guides and module pages, not the change history (which names old keys
## on purpose).
static func _guide_pages(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	for file_name: String in DirAccess.get_files_at(dir_path):
		if file_name.ends_with(".md"):
			out.append(dir_path.path_join(file_name))
	for sub: String in DirAccess.get_directories_at(dir_path):
		out.append_array(_guide_pages(dir_path.path_join(sub)))
	return out
