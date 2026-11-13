# Godot EventSheets - where the Ask keys live, as far as the plugin's start needs to know.
#
# Kept apart from ask.gd on purpose: ask.gd names classes the first open needs, and loading it while
# the plugin is being enabled would pull them in at boot. This file names nothing but engine classes.
@tool
extends RefCounted

const SETTING_KEY := "eventsheets/ask/api_key"
const AI_SETTING_KEY := "eventsheets/ai/api_key"


static func _editor_settings() -> Object:
	if not Engine.is_editor_hint() or not Engine.has_singleton("EditorInterface"):
		return null
	return (Engine.get_singleton("EditorInterface") as Object).call("get_editor_settings")


## Declares both keys in the editor's settings as password fields, so Editor Settings shows them
## hidden. Called when the plugin starts.
static func register_editor_keys() -> void:
	var settings: Object = _editor_settings()
	if settings == null:
		return
	for setting_name: String in [SETTING_KEY, AI_SETTING_KEY]:
		if not bool(settings.call("has_setting", setting_name)):
			settings.call("set_setting", setting_name, "")
		settings.call("set_initial_value", setting_name, "", false)
		settings.call("add_property_info", {"name": setting_name, "type": TYPE_STRING, "hint": PROPERTY_HINT_PASSWORD})


## Moves a key an earlier version saved into the PROJECT (where it is committed) over to the editor's
## settings and clears it from the project. A key already in the editor's settings wins and the
## project's copy is simply cleared. Returns the setting names it moved, so the caller can say so
## once and save the project. `store` is the settings object (the editor's by default).
static func move_project_keys_to_editor(store: Object = null) -> PackedStringArray:
	var moved: PackedStringArray = PackedStringArray()
	var settings: Object = store if store != null else _editor_settings()
	if settings == null:
		return moved
	for setting_name: String in [SETTING_KEY, AI_SETTING_KEY]:
		var in_project: String = str(ProjectSettings.get_setting(setting_name, "")).strip_edges()
		if in_project.is_empty():
			continue
		var held: String = ""
		if bool(settings.call("has_setting", setting_name)):
			held = str(settings.call("get_setting", setting_name)).strip_edges()
		if held.is_empty():
			settings.call("set_setting", setting_name, in_project)
		ProjectSettings.set_setting(setting_name, null)
		moved.append(setting_name)
	return moved


