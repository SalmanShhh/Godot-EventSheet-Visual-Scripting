# Godot EventSheets — ProjectSettings registration
#
# Every eventsheets/* setting, registered the Godot way: visible and documented in
# Project Settings instead of existing only as invisible get_setting() defaults.
# Registration is value-neutral — defaults equal the in-code fallbacks, and values
# matching the initial value are never written to project.godot (no git noise).
# Readers keep their get_setting(name, default) form, so tests that reset a setting
# to null keep working (null erases; the fallback takes over).
@tool
extends RefCounted
class_name EventSheetSettings

const DEFINITIONS: Array[Dictionary] = [
	{"name": "eventsheets/editor/compile_on_save", "default": true, "type": TYPE_BOOL,
		"doc": "Saving a sheet also writes its generated script (F5 can never play-test stale code)."},
	{"name": "eventsheets/editor/backup_count", "default": 10, "type": TYPE_INT,
		"hint": PROPERTY_HINT_RANGE, "hint_string": "0,50,1",
		"doc": "Pre-save backups kept per sheet under user://eventsheet_backups (0 disables)."},
	{"name": "eventsheets/editor/restore_session", "default": true, "type": TYPE_BOOL,
		"doc": "Reopen last session's sheet tabs when the editor starts."},
	{"name": "eventsheets/editor/open_code_panel_by_default", "default": false, "type": TYPE_BOOL,
		"doc": "Show the generated-GDScript panel whenever a sheet opens (the Godot-native default from the welcome panel)."},
	{"name": "eventsheets/project/vocabulary_doc_path", "default": "res://EVENTSHEETS-VOCABULARY.md", "type": TYPE_STRING,
		"hint": PROPERTY_HINT_FILE, "hint_string": "*.md",
		"doc": "Where Tools → Vocabulary Doc writes the generated project reference."},
	{"name": "eventsheets/project/templates_dir", "default": "res://eventsheet_templates", "type": TYPE_STRING,
		"hint": PROPERTY_HINT_DIR,
		"doc": "Sheets in this folder join the New… menu as project templates."},
	{"name": "eventsheets/project/snippets_dir", "default": "res://eventsheet_snippets", "type": TYPE_STRING,
		"hint": PROPERTY_HINT_DIR,
		"doc": "Row snippets live here (Save Selection as Snippet… / Insert Snippet…)."},
	{"name": "eventsheets/addons/composition_mode", "default": "allowed", "type": TYPE_STRING,
		"hint": PROPERTY_HINT_ENUM, "hint_string": "allowed,off",
		"doc": "Whether sheets may include other sheets (policy gates, never bytes)."},
	{"name": "eventsheets/addons/max_include_depth", "default": 2, "type": TYPE_INT,
		"hint": PROPERTY_HINT_RANGE, "hint_string": "1,8,1",
		"doc": "How deep include chains may nest."},
	{"name": "eventsheets/addons/depth_overflow", "default": "warn", "type": TYPE_STRING,
		"hint": PROPERTY_HINT_ENUM, "hint_string": "warn,error",
		"doc": "What happens past max_include_depth."},
	{"name": "eventsheets/addons/collision_policy", "default": "warn", "type": TYPE_STRING,
		"hint": PROPERTY_HINT_ENUM, "hint_string": "warn,error,silent",
		"doc": "Symbol collisions between included sheets."},
	{"name": "eventsheets/addons/include_sources", "default": "anywhere", "type": TYPE_STRING,
		"doc": "Where includes may come from (\"anywhere\" or \"tagged:<tag>\")."},
	{"name": "eventsheets/addons/deprecated_tag_blocks", "default": "warn", "type": TYPE_STRING,
		"hint": PROPERTY_HINT_ENUM, "hint_string": "warn,error,silent",
		"doc": "Including a sheet tagged deprecated."},
]

## Registers every setting (idempotent; call at plugin load). Values equal to the
## initial value are never persisted into project.godot.
static func register_all() -> void:
	# Authoring shortcuts moved to a per-user file (EventSheetShortcuts / Tools ▸ Keyboard Shortcuts),
	# so they are no longer registered as project settings.
	var definitions: Array[Dictionary] = DEFINITIONS.duplicate()
	for definition: Dictionary in definitions:
		var setting_name: String = str(definition.get("name"))
		if not ProjectSettings.has_setting(setting_name):
			ProjectSettings.set_setting(setting_name, definition.get("default"))
		ProjectSettings.set_initial_value(setting_name, definition.get("default"))
		ProjectSettings.add_property_info({
			"name": setting_name,
			"type": int(definition.get("type", TYPE_STRING)),
			"hint": int(definition.get("hint", PROPERTY_HINT_NONE)),
			"hint_string": str(definition.get("hint_string", "")),
		})
