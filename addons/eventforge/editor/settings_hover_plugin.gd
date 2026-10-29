# EventForge - the Project Settings hover for the plugin's own settings
#
# Godot writes a setting's hover from its class documentation, and a setting a plugin registers has
# none, so hovering one said "No description available." This inspector plugin answers for the rows
# Project Settings draws (its inspector edits a SectionedInspectorFilter): a setting named in HOVERS
# gets a plain tick of its own whose hover points at a documented script member instead, so Godot's
# own hover card shows the sentence. Everything else is left to Godot.
@tool
extends EditorInspectorPlugin

## Full setting key -> the documented member ("Class|member") its hover reads.
const HOVERS: Dictionary = {
	"eventsheets/editor/open_scripts_as_event_sheets": "EventSheetSettings|open_scripts_as_event_sheets",
}

## The class Project Settings' inspector edits. Not exposed to scripts, so it is matched by name.
const SETTINGS_FILTER_CLASS: String = "SectionedInspectorFilter"
## The scripts whose doc comments the hovers read.
const DOCUMENTED_SCRIPTS: PackedStringArray = ["res://addons/eventforge/settings.gd"]

## Set once the documented scripts' docs have been handed to the editor this session.
static var _docs_handed_over: bool = false


func _can_handle(object: Object) -> bool:
	return is_settings_list(object)


## True for the object Project Settings' inspector edits, and only for that.
static func is_settings_list(object: Object) -> bool:
	return object != null and object.get_class() == SETTINGS_FILTER_CLASS


func _parse_property(_object: Object, type: Variant.Type, name: String, _hint_type: PropertyHint,
		_hint_string: String, _usage_flags: int, _wide: bool) -> bool:
	var key: String = key_for(name)
	if key.is_empty() or type != TYPE_BOOL:
		return false
	_hand_over_docs()
	var tick: HoverTick = HoverTick.new()
	tick.hover_symbol = hover_symbol_for(key)
	add_property_editor(name, tick)
	return true


## Godot's hover reads the documentation the editor keeps for each script class, which it refreshes
## only when it scans a script it saw change. A plugin updated outside a running editor (or imported
## from the command line) can leave that copy behind the file, and the hover then says "No description
## available." So the first time a documented row is drawn, its scripts' docs are handed over again.
static func _hand_over_docs() -> void:
	if _docs_handed_over:
		return
	_docs_handed_over = true
	var script_editor: ScriptEditor = EditorInterface.get_script_editor()
	if script_editor == null:
		return
	for path: String in DOCUMENTED_SCRIPTS:
		var documented: Script = load(path) as Script
		if documented != null:
			script_editor.update_docs_from_script(documented)


## The full setting key a Project Settings row stands for. The row's name is the key with its open
## section cut off ("open_scripts_as_event_sheets" under Eventsheets > Editor), or the whole key
## while the filter is searching. Empty for a row this plugin does not document.
static func key_for(row_name: String) -> String:
	for key: String in HOVERS:
		if row_name == key or key.ends_with("/" + row_name):
			return key
	return ""


## The documentation symbol Godot's hover card reads for a setting key: a property of a script class.
static func hover_symbol_for(key: String) -> String:
	return "property|%s|" % str(HOVERS.get(key, ""))


## The tick Godot draws for a bool setting ("On" beside it while it is ticked), whose hover is the
## documented member rather than the empty ProjectSettings entry.
class HoverTick:
	extends EditorProperty

	var hover_symbol: String = ""
	var _box: CheckBox = CheckBox.new()
	var _updating: bool = false

	func _init() -> void:
		add_child(_box)
		add_focusable(_box)
		_box.toggled.connect(_on_toggled)

	func _ready() -> void:
		tooltip_text = hover_symbol

	func _update_property() -> void:
		# The inspector writes its own hover symbol after building the row; this runs after that.
		tooltip_text = hover_symbol
		_updating = true
		var on: bool = bool(get_edited_object().get(get_edited_property()))
		_box.button_pressed = on
		_box.text = EventSheetL10n.translate("On") if on else ""
		_updating = false

	func _on_toggled(on: bool) -> void:
		if _updating:
			return
		emit_changed(get_edited_property(), on)
