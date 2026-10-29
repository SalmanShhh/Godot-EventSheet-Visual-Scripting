# EventForge - the "Open Scripts as Event Sheets" project setting.
#
# Clicking a script in the FileSystem or the Inspector opens it as a sheet when this one tick is on.
# It used to be called auto_preview_gd_on_select, sat behind Advanced Settings like every other
# EventSheets setting, and its hover said "No description available." This pins the new key, the
# old key carried over once, the basic flag that lists it in the plain Project Settings view, and
# the sentence its hover reads.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const NAME: String = "open_scripts_setting_test"
const NEW_KEY: String = "eventsheets/editor/open_scripts_as_event_sheets"
const OLD_KEY: String = "eventsheets/editor/auto_preview_gd_on_select"
const SETTINGS_PATH: String = "res://addons/eventforge/settings.gd"
const HOVER_PATH: String = "res://addons/eventforge/editor/settings_hover_plugin.gd"
const BOARD_SENTENCE: String = "When on, clicking a script in the FileSystem or the Inspector opens it as an event sheet you can edit, instead of in the Script editor. A script the sheet cannot read still opens in the Script editor. Off by default; right-click a script, then Open as Event Sheet, works either way."


static func run() -> bool:
	var ok: bool = true
	ok = _definitions() and ok
	ok = _registered_as_basic() and ok
	ok = _old_key_carried_over() and ok
	ok = _hover_sentence() and ok
	ok = _hover_plugin_rows() and ok
	ok = _filesystem_clicks() and ok
	return ok


static func _definitions() -> bool:
	var names: PackedStringArray = PackedStringArray()
	var basic: PackedStringArray = PackedStringArray()
	var doc: String = ""
	for definition: Dictionary in EventSheetSettings.DEFINITIONS:
		var name: String = str(definition.get("name", ""))
		names.append(name)
		if bool(definition.get("basic", false)):
			basic.append(name)
		if name == NEW_KEY:
			doc = str(definition.get("doc", ""))
	return SUPPORT.pins(NAME, [
		["the setting is registered under its new key", names.has(NEW_KEY), true],
		["and no longer under the old one", names.has(OLD_KEY), false],
		["it is the one setting marked basic", basic, PackedStringArray([NEW_KEY])],
		["its description is the board's sentence", doc, BOARD_SENTENCE],
		["the constant names the new key", EventSheetSettings.OPEN_SCRIPTS_SETTING, NEW_KEY],
		["the old key maps to the new one", str(EventSheetSettings.RENAMED_SETTINGS.get(OLD_KEY, "")), NEW_KEY],
	])


## Basic settings carry PROPERTY_USAGE_EDITOR_BASIC_SETTING in ProjectSettings' property list, which
## is what Project Settings reads to list a row without Advanced Settings.
static func _registered_as_basic() -> bool:
	EventSheetSettings.register_all()
	return SUPPORT.pins(NAME, [
		["Project Settings lists it without Advanced Settings", _is_basic(NEW_KEY), true],
		["while the other settings stay advanced", _is_basic("eventsheets/editor/compile_on_save"), false],
		["it is off by default", ProjectSettings.get_setting(NEW_KEY), false],
	])


static func _is_basic(key: String) -> bool:
	for property: Dictionary in ProjectSettings.get_property_list():
		if str(property.get("name", "")) == key:
			return (int(property.get("usage", 0)) & PROPERTY_USAGE_EDITOR_BASIC_SETTING) != 0
	return false


static func _old_key_carried_over() -> bool:
	var rows: Array = []
	ProjectSettings.set_setting(NEW_KEY, null)
	ProjectSettings.set_setting(OLD_KEY, true)
	rows.append(["a project that ticked the old key reports a move", EventSheetSettings.migrate_renamed(), true])
	rows.append(["the choice is under the new key", ProjectSettings.get_setting(NEW_KEY, false), true])
	rows.append(["the old key is dropped", ProjectSettings.has_setting(OLD_KEY), false])
	rows.append(["and a second pass moves nothing", EventSheetSettings.migrate_renamed(), false])
	rows.append(["the plugin reads the new key", EventForgePlugin._open_scripts_as_sheets_enabled(), true])
	# A project carrying both keeps the new key's value and still loses the old one.
	ProjectSettings.set_setting(NEW_KEY, false)
	ProjectSettings.set_setting(OLD_KEY, true)
	EventSheetSettings.migrate_renamed()
	rows.append(["a value already under the new key wins", ProjectSettings.get_setting(NEW_KEY, true), false])
	rows.append(["and the old key goes either way", ProjectSettings.has_setting(OLD_KEY), false])
	ProjectSettings.set_setting(OLD_KEY, null)
	ProjectSettings.set_setting(NEW_KEY, null)
	EventSheetSettings.register_all()
	rows.append(["registering again leaves the default", ProjectSettings.get_setting(NEW_KEY, true), false])
	return SUPPORT.pins(NAME, rows)


## Godot's hover card reads the doc comment of the member the row points at, so that comment must be
## the same sentence (and the key, the way the board prints it under the sentence).
static func _hover_sentence() -> bool:
	var lines: PackedStringArray = FileAccess.get_file_as_string(SETTINGS_PATH).split("\n")
	var doc: PackedStringArray = PackedStringArray()
	for i: int in lines.size():
		if lines[i].begins_with("var open_scripts_as_event_sheets"):
			var k: int = i - 1
			while k >= 0 and lines[k].begins_with("## "):
				doc.insert(0, lines[k].substr(3))
				k -= 1
	return SUPPORT.pins(NAME, [
		["the hover member's doc comment is the sentence and the key", doc,
			PackedStringArray([BOARD_SENTENCE, "[code]%s[/code]" % NEW_KEY])],
	])


static func _hover_plugin_rows() -> bool:
	var hover: Script = load(HOVER_PATH)
	var node: Node = Node.new()
	var rows: Array = [
		["a row under Eventsheets > Editor is ours", hover.key_for("open_scripts_as_event_sheets"), NEW_KEY],
		["so is a row under Eventsheets", hover.key_for("editor/open_scripts_as_event_sheets"), NEW_KEY],
		["and the whole key while filtering", hover.key_for(NEW_KEY), NEW_KEY],
		["an undocumented setting is left to Godot", hover.key_for("compile_on_save"), ""],
		["the hover points at the documented member", hover.hover_symbol_for(NEW_KEY),
			"property|EventSheetSettings|open_scripts_as_event_sheets|"],
		["a scene node's inspector is not touched", hover.is_settings_list(node), false],
	]
	node.free()
	return SUPPORT.pins(NAME, rows)


## A click on a file in the FileSystem: only a script, and only with the tick on, goes to a sheet.
static func _filesystem_clicks() -> bool:
	return SUPPORT.pins(NAME, [
		["with the tick on a script opens as a sheet", EventForgePlugin.opens_on_click("res://player.gd", true), true],
		["with it off the click is Godot's", EventForgePlugin.opens_on_click("res://player.gd", false), false],
		["a scene keeps opening in its own editor", EventForgePlugin.opens_on_click("res://main.tscn", true), false],
		["a script the sheet does not open is left alone", EventForgePlugin.opens_on_click("res://tool.cs", true), false],
	])
