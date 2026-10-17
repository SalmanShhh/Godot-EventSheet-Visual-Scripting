# Godot EventSheets - the Save studio's File and format, Save slots, Look inside and Player
# settings tabs, and the Save System pack's Open Save Folder pair.
#
# Pins: the format choice carries the file ending with it; the settings are read off and written
# onto the scene the SaveSystem global names (and a bare-script global is said, not edited); a slot
# file names its slot and its saved time; a copy whose ending names another format is converted
# through the pack's own backends; a save reads in plain words; the two new rows are what the pack
# publishes; "For your players" hides an AUTHORED row through the reader's own hide list; and every
# row the Player settings cards name is a row that exists, in the file the card says it uses.
@tool
class_name SaveStudioTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const NAME := "save_studio_test"
const DIR := "user://save_studio_test/"
const GAME_SETTINGS_PACK := "res://eventsheet_addons/game_settings/game_settings_addon.gd"
const BINDINGS_MODULE := "res://addons/eventforge/registration/modules/controls_aces.gd"
const REBIND_MODULE := "res://addons/eventforge/registration/modules/game_accessibility_aces.gd"


static func run() -> bool:
	DirAccess.make_dir_recursive_absolute(DIR)
	var all_passed: bool = _formats_and_slots()
	all_passed = _settings_scene() and all_passed
	all_passed = _copy_and_plain_words() and all_passed
	all_passed = _open_save_folder_pair() and all_passed
	all_passed = _player_settings_cards() and all_passed
	for file: String in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + file)
	DirAccess.remove_absolute(DIR)
	return all_passed


static func _formats_and_slots() -> bool:
	var studio: GDScript = EventSheetSaveStudio
	var now: int = int(Time.get_unix_time_from_system())
	return SUPPORT.pins(NAME, [
		["the file name follows the format", studio.pattern_for_format("save_{slot}.cfg", "json"), "save_{slot}.json"],
		["a renamed pattern keeps its stem", studio.pattern_for_format("slot-{slot}.dat", "binary"), "slot-{slot}.sav"],
		["every format names its own dropdown line", studio.format_label("config"), "Godot settings file (.cfg)"],
		["and a plain one by its name", studio.format_label("xml"), "XML (.xml)"],
		["a scene global is where the settings live", studio.settings_scene("*res://save_system.tscn"), "res://save_system.tscn"],
		["a bare-script global is not", studio.settings_scene("*res://eventsheet_addons/save_system/save_system_addon.gd"), ""],
		["a slot file names its slot", studio.slot_number("save_12.json", "save_{slot}.cfg"), "12"],
		["under a renamed pattern too", studio.slot_number("slot-3.dat", "slot-{slot}.dat"), "3"],
		["a slot saved a minute ago reads as today", studio.slot_meta(now - 60, 2048, now).begins_with("Saved today at "), true],
		["with its size", studio.slot_meta(now - 60, 2048, now).ends_with(" · 2.0 KB"), true],
		["a slot saved yesterday says so", studio.slot_meta(now - 86400, 512, now).begins_with("Saved yesterday at "), true],
		["a copy's ending names its format", studio.format_for_extension("C:/backups/slot.json"), "json"],
		["the binary ending is binary", studio.format_for_extension("user://save_0.sav"), "binary"],
	])


static func _settings_scene() -> bool:
	var scene_path: String = DIR + "save_system.tscn"
	var before: Variant = ProjectSettings.get_setting("autoload/SaveSystem", null)
	var problem: String = EventSheetSaveStudio.make_settings_scene(scene_path)
	var global_after: String = str(ProjectSettings.get_setting("autoload/SaveSystem", ""))
	ProjectSettings.set_setting("autoload/SaveSystem", before)
	var defaults: Dictionary = EventSheetSaveStudio.read_settings(scene_path)
	var wrote: Error = EventSheetSaveStudio.write_setting(scene_path, "format", "json")
	var written: Dictionary = EventSheetSaveStudio.read_settings(scene_path)
	return SUPPORT.pins(NAME, [
		["keeping the settings in a scene works", problem, ""],
		["and points the SaveSystem global at it", global_after, "*" + scene_path],
		["a fresh scene reads the pack's defaults", [defaults["format"], defaults["file_pattern"], defaults["save_directory"]],
			["config", "save_{slot}.cfg", "user://"]],
		["a setting is written onto the scene", wrote, OK],
		["and reads back from it", written["format"], "json"],
		["leaving the others as they were", written["file_pattern"], "save_{slot}.cfg"],
		["a spin box's 600.0 is the scene's 600, so leaving it writes nothing, while 601 and a missing value are changes",
			[EventSheetSaveStudio.differs(600.0, 600), EventSheetSaveStudio.differs(601.0, 600), EventSheetSaveStudio.differs(600.0, "")],
			[false, true, true]],
		["text compares as text", [EventSheetSaveStudio.differs("json", "json"), EventSheetSaveStudio.differs("json", "config")], [false, true]],
	])


static func _copy_and_plain_words() -> bool:
	var writer: Node = (load(EventSheetSaveStudio.SAVE_SYSTEM_SCRIPT) as GDScript).new()
	writer.set("save_directory", DIR)
	writer.call("save_value", "coins", 42)
	writer.call("save_value", "position", Vector2(120, 64))
	writer.free()
	var settings: Dictionary = {"save_directory": DIR, "section": "save", "format": "config"}
	var problem: String = EventSheetSaveStudio.copy_slot(DIR + "save_0.cfg", DIR + "copy.json", settings)
	var reader: Node = (load(EventSheetSaveStudio.SAVE_SYSTEM_SCRIPT) as GDScript).new()
	var copied: Dictionary = reader.call("read_file", DIR + "copy.json", "json")
	var detected: String = reader.call("save_file_format", DIR + "copy.json")
	reader.free()
	var snapshot: Dictionary = {".": {"health": 3}, "Timer": {"left": 1.5}, "pos": Vector2(120, 64), "flag": true, "bag": [1, 2]}
	return SUPPORT.pins(NAME, [
		["a copy ending in .json is converted", problem, ""],
		["into a real JSON save", detected, "json"],
		["holding the same values", copied, {"coins": 42, "position": Vector2(120, 64)}],
		["a save reads in plain words", EventSheetSaveStudio.plain_rows(snapshot), [
			PackedStringArray(["health", "3"]), PackedStringArray(["Timer/left", "1.5"]),
			PackedStringArray(["pos", "x 120, y 64"]), PackedStringArray(["flag", "yes"]), PackedStringArray(["bag", "a list of 2"])]],
		["a binary file shows its head in hex", EventSheetSaveStudio.file_text(PackedByteArray([71, 0, 1])),
			"Binary file, 3 bytes (not text). First bytes:\n470001"],
	])


static func _open_save_folder_pair() -> bool:
	var found: Dictionary = {}
	for definition: ACEDefinition in EventSheetPackReadingCheck.definitions_for_script(EventSheetSaveStudio.SAVE_SYSTEM_SCRIPT):
		var template: String = str(definition.metadata.get("codegen_template", ""))
		if template.contains("save_folder"):
			found[str(definition.id)] = [str(definition.provider_id), str(definition.display_name), template]
	var pack: Node = (load(EventSheetSaveStudio.SAVE_SYSTEM_SCRIPT) as GDScript).new()
	var desktop: bool = pack.call("can_open_save_folder")
	pack.free()
	# The reader's hide list, on a catalog of the test's own: an AUTHORED row is hidden by it too.
	EventSheetVocabularyCatalog.reset_for_tests(DIR + "vocabulary.tres")
	var key: String = EventSheetVocabularyCatalog.key_for(EventSheetSaveStudio.OPEN_FOLDER_PROVIDER, EventSheetSaveStudio.OPEN_FOLDER_ACE)
	EventSheetVocabularyCatalog.set_override(EventSheetSaveStudio.OPEN_FOLDER_PROVIDER, EventSheetSaveStudio.OPEN_FOLDER_ACE, {"hidden": true})
	var hidden: bool = EventSheetVocabularyCatalog.hidden_keys().has(key)
	EventSheetVocabularyCatalog.set_override(EventSheetSaveStudio.OPEN_FOLDER_PROVIDER, EventSheetSaveStudio.OPEN_FOLDER_ACE, {"hidden": null})
	var shown_again: bool = not EventSheetVocabularyCatalog.hidden_keys().has(key)
	EventSheetVocabularyCatalog.reset_for_tests()
	return SUPPORT.pins(NAME, [
		["the pack publishes Open Save Folder where the studio hides it", found.get(EventSheetSaveStudio.OPEN_FOLDER_ACE, []),
			[EventSheetSaveStudio.OPEN_FOLDER_PROVIDER, "Open Save Folder", "SaveSystem.open_save_folder()"]],
		["and its condition", found.get("method:can_open_save_folder", []),
			[EventSheetSaveStudio.OPEN_FOLDER_PROVIDER, "Can Open Save Folder", "SaveSystem.can_open_save_folder()"]],
		["a desktop has a save folder to show", desktop, not (OS.has_feature("web") or OS.has_feature("mobile"))],
		["switching players off hides the authored row", hidden, true],
		["and switching them on shows it again", shown_again, true],
	])


## Every row a Player settings card names is a row that ships, and each file card names the file
## those rows really write - the copy cannot drift from the vocabulary it teaches.
static func _player_settings_cards() -> bool:
	var words: String = ""
	for use: Array in EventSheetSaveStudio.settings_uses():
		for half: Array in [use[2], use[3]]:
			for line: Array in half:
				words += str(line[1]) + "\n"
	var game_settings: String = FileAccess.get_file_as_string(GAME_SETTINGS_PACK)
	var missing: Array = []
	# The pack's rows read in their own sentence case ("Declare setting ..."), so the name is matched
	# without regard to case.
	for row: String in ["Declare Setting", "Load All Settings", "Apply All Settings", "On Setting Changed", "Changed Setting Is",
			"Set Setting", "Save All Settings", "Apply Quality", "Apply With A Way Back", "Setting Value"]:
		if not words.to_lower().contains(row.to_lower()) or not game_settings.contains("@ace_name(\"%s\")" % row):
			missing.append(row)
	if not words.contains("Rebind Control To") or not FileAccess.get_file_as_string(REBIND_MODULE).contains("\"Rebind Control To\""):
		missing.append("Rebind Control To")
	var bindings: String = FileAccess.get_file_as_string(BINDINGS_MODULE)
	var files: Array = []
	var cards: Array = EventSheetSaveStudio.settings_files()
	for card: Array in cards:
		files.append(card[1])
	var uses: Array = EventSheetSaveStudio.settings_uses()
	var switch: EventSheetPopupUI.ViewSwitch = EventSheetPopupUI.ViewSwitch.new(EventSheetPopupUI.ViewSwitch.BOTH,
		{EventSheetPopupUI.ViewSwitch.SHEET: ["Events", "As rows."]})
	var switch_words: Array = [(switch.buttons[EventSheetPopupUI.ViewSwitch.SHEET] as Button).text, switch.view]
	switch.free()
	return SUPPORT.pins(NAME, [
		["every row the cards name ships", missing, []],
		["the three files", files, ["user://save_0.cfg", "user://settings.cfg", "user://bindings.cfg"]],
		["settings.cfg is the Game Settings pack's file", game_settings.contains("SETTINGS_FILE: String = \"user://settings.cfg\""), true],
		["bindings.cfg is the bindings rows' file", bindings.contains("const BINDINGS_FILE := \"\\\"user://bindings.cfg\\\"\""), true],
		["a view switch can say Events | Code | Both", switch_words, ["Events", "both"]],
		# The Game Settings rows are read off the pack: the sheet's own reading, the template's own code.
		["a pack row reads the way the sheet reads it", uses[0][3][0], ["Settings", "Declare setting \"master_volume\" default 80 kind percent"]],
		["and its code is what its template writes", uses[0][4].contains("Settings.declare_setting(\"master_volume\", 80, \"percent\", \"\", \"\", \"\")"), true],
		["a condition row becomes the use's if", uses[1][4], "func _on_setting_changed(setting_name: String, value: Variant) -> void:\n\tif Settings.changed_setting_is(\"master_volume\"):\n\t\tAudioServer.set_bus_volume_db(0, linear_to_db(value / 100.0))"],
		["the settings sample is the file Godot writes", cards[1][3], "[settings]\n\nmaster_volume=80\nfullscreen=true\nquality=\"High\""],
	])
