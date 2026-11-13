# Godot EventSheets - an Ask key is never saved into the project.
#
# project.godot is committed, so a key typed into a project setting travels with the repository. The
# key lives in the editor's settings (per user) with an environment variable as the fallback, and a
# key an earlier version saved into the project is moved out once. Pinned against a stand-in for the
# editor's settings object, since a headless run has no editor.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "api_key_storage_test"
const STORAGE := preload("res://addons/eventforge/ask_key_storage.gd")


class FakeEditorSettings extends RefCounted:
	var values: Dictionary = {}

	func has_setting(setting_name: String) -> bool:
		return values.has(setting_name)

	func get_setting(setting_name: String) -> Variant:
		return values.get(setting_name)

	func set_setting(setting_name: String, value: Variant) -> void:
		values[setting_name] = value


static func run() -> bool:
	var previous_env: String = OS.get_environment(EventSheetAsk.ENV_KEY)
	var previous_ask: Variant = ProjectSettings.get_setting(EventSheetAsk.SETTING_KEY, "")
	var previous_ai: Variant = ProjectSettings.get_setting(EventSheetAsk.AI_SETTING_KEY, null)
	var store: FakeEditorSettings = FakeEditorSettings.new()
	OS.set_environment(EventSheetAsk.ENV_KEY, "")
	var empty_read: String = EventSheetAsk.secret(EventSheetAsk.SETTING_KEY, EventSheetAsk.ENV_KEY, store)
	OS.set_environment(EventSheetAsk.ENV_KEY, "from-env")
	var env_read: String = EventSheetAsk.secret(EventSheetAsk.SETTING_KEY, EventSheetAsk.ENV_KEY, store)
	store.set_setting(EventSheetAsk.SETTING_KEY, "from-editor")
	var editor_read: String = EventSheetAsk.secret(EventSheetAsk.SETTING_KEY, EventSheetAsk.ENV_KEY, store)
	var project_ignored: String = ""
	store.values.clear()
	OS.set_environment(EventSheetAsk.ENV_KEY, "")
	ProjectSettings.set_setting(EventSheetAsk.SETTING_KEY, "typed-in-project")
	project_ignored = EventSheetAsk.secret(EventSheetAsk.SETTING_KEY, EventSheetAsk.ENV_KEY, store)
	ProjectSettings.set_setting(EventSheetAsk.AI_SETTING_KEY, "ai-typed-in-project")
	var moved: PackedStringArray = STORAGE.move_project_keys_to_editor(store)
	var moved_again: PackedStringArray = STORAGE.move_project_keys_to_editor(store)
	var registered: Array = EventSheetSettings.DEFINITIONS.map(func(entry: Dictionary) -> String: return str(entry.get("name", "")))
	var ok: bool = SUPPORT.pins(P, [
		["with nothing set the key is empty", empty_read, ""],
		["the environment variable is the fallback", env_read, "from-env"],
		["the editor's setting wins over the environment", editor_read, "from-editor"],
		["a key in the project is not read", project_ignored, ""],
		["both project keys are moved out", moved, PackedStringArray([EventSheetAsk.SETTING_KEY, EventSheetAsk.AI_SETTING_KEY])],
		["the editor's settings now hold them", [store.get_setting(EventSheetAsk.SETTING_KEY), store.get_setting(EventSheetAsk.AI_SETTING_KEY)],
			["typed-in-project", "ai-typed-in-project"]],
		["the project no longer holds the Ask key", str(ProjectSettings.get_setting(EventSheetAsk.SETTING_KEY, "")), ""],
		["the project no longer holds the generator key", ProjectSettings.has_setting(EventSheetAsk.AI_SETTING_KEY) and str(ProjectSettings.get_setting(EventSheetAsk.AI_SETTING_KEY)) != "", false],
		["moving is once: the second call has nothing to move", moved_again, PackedStringArray()],
		["the key is not among the project settings the plugin registers", registered.has(EventSheetAsk.SETTING_KEY), false],
	])
	OS.set_environment(EventSheetAsk.ENV_KEY, previous_env)
	ProjectSettings.set_setting(EventSheetAsk.SETTING_KEY, previous_ask)
	ProjectSettings.set_setting(EventSheetAsk.AI_SETTING_KEY, previous_ai)
	return ok
