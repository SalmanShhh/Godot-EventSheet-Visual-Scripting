# Godot EventSheets - the rebind capture's seams, the settings file path, the new wait row, the
# Save Studio's two bindings paths and the Doctor's note about a Settings global that is not the pack.
@tool
extends RefCounted


const NAME := "rebind_and_settings_file_test"
const SUPPORT := preload("res://tests/support.gd")
const PACK_PATH := "res://eventsheet_addons/game_settings/game_settings_addon.gd"


static func run() -> bool:
	var pack_source: String = FileAccess.get_file_as_string(PACK_PATH)
	var ok: bool = _pack_text(pack_source)
	ok = _row_pins() and ok
	ok = _file_round_trip() and ok
	ok = _cancel_signal() and ok
	ok = _studio_card() and ok
	ok = _doctor_note(pack_source) and ok
	ok = _saving_showcase_reads_back() and ok
	return ok


static func _pack_text(pack_source: String) -> bool:
	return SUPPORT.pins(NAME, [
		["the capture is taken before the controls", pack_source.contains("func _input(event: InputEvent) -> void:"), true],
		["and no longer waits for what nothing used", pack_source.contains("func _unhandled_input("), false],
		["the new trigger is a real signal", pack_source.contains("signal binding_cancelled(action: String)"), true],
		["the file path is an exported property with the old default", pack_source.contains("@export var settings_file: String = \"user://settings.cfg\""), true],
		["no save or load names the constant any more", pack_source.contains("config.load(SETTINGS_FILE)") or pack_source.contains("config.save(SETTINGS_FILE)"), false],
		["the constant stays as the documented default", pack_source.contains("const SETTINGS_FILE: String = \"user://settings.cfg\""), true],
		["the property is described", pack_source.contains("## File every save and load uses"), true],
	])


static func _row_pins() -> bool:
	var fresh: ACEDescriptor = ACERegistry.find_descriptor("Core", "InputWaitForNextPress")
	var old: ACEDescriptor = ACERegistry.find_descriptor("Core", "InputWaitForNextKey")
	var save_row: ACEDescriptor = ACERegistry.find_descriptor("Core", "InputSaveBindings")
	var load_row: ACEDescriptor = ACERegistry.find_descriptor("Core", "InputLoadBindings")
	return SUPPORT.pins(NAME, [
		["the new wait row ships", fresh != null, true],
		["and is not deprecated", fresh.is_deprecated if fresh != null else true, false],
		["the old wait row is deprecated, not removed", [old != null, old.is_deprecated if old != null else false], [true, true]],
		["the old row's template is untouched", old.codegen_template if old != null else "", "var {name} = await get_window().window_input"],
		["the new row waits for a press, not a release or a mouse move", fresh.codegen_template.contains("{name}.is_pressed()") and fresh.codegen_template.contains("InputEventJoypadButton") and not fresh.codegen_template.contains("InputEventMouseMotion"), true],
		["and marks the press handled", fresh.codegen_template.ends_with("get_viewport().set_input_as_handled()"), true],
		["Save bindings names its file", save_row.description.contains("user://bindings.cfg") and save_row.description.contains("user://settings.cfg"), true],
		["Load bindings names its file", load_row.description.contains("user://bindings.cfg"), true],
	])


## Two Settings nodes pointed at the same file: what one saves the other loads, and the default path is untouched.
static func _file_round_trip() -> bool:
	var script: GDScript = load(PACK_PATH)
	var path: String = SUPPORT.own_path("settings_probe.cfg")
	var first: Node = script.new()
	var second: Node = script.new()
	var third: Node = script.new()
	var default_path: Variant = first.get("settings_file")
	first.set("settings_file", path)
	second.set("settings_file", path)
	first.call("declare_setting", "rc_volume", 80, "percent")
	second.call("declare_setting", "rc_volume", 80, "percent")
	first.call("set_setting", "rc_volume", 30)
	first.call("save_all_settings")
	second.call("load_all_settings")
	InputMap.add_action("rc_jump")
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = KEY_J
	InputMap.action_add_event("rc_jump", key)
	first.call("save_bindings")
	InputMap.action_erase_events("rc_jump")
	second.call("load_bindings")
	var back: String = str(first.call("key_binding_of", "rc_jump"))
	InputMap.erase_action("rc_jump")
	# A third node left on its default file never sees the value.
	third.call("declare_setting", "rc_volume", 80, "percent")
	third.call("load_all_settings")
	var ok: bool = SUPPORT.pins(NAME, [
		["the default path is the old file", default_path, "user://settings.cfg"],
		["a value saved to the chosen file loads from it", second.call("setting_value", "rc_volume"), 30],
		["a binding saved to the chosen file comes back", back, "J"],
		["the chosen file is the one written", FileAccess.file_exists(path), true],
		["a node on the default file does not read it", third.call("setting_value", "rc_volume"), 80],
	])
	DirAccess.remove_absolute(path)
	first.free()
	second.free()
	third.free()
	return ok


static func _cancel_signal() -> bool:
	var settings: Node = (load(PACK_PATH) as GDScript).new()
	var heard: Array = []
	settings.connect("binding_cancelled", func(action: String) -> void: heard.append(action))
	InputMap.add_action("rc_dash")
	settings.call("listen_for_binding", "rc_dash", "keyboard")
	settings.call("cancel_listening")
	settings.call("cancel_listening")
	var waiting: Variant = settings.call("waiting_for_a_key")
	InputMap.erase_action("rc_dash")
	settings.free()
	return SUPPORT.pins(NAME, [
		["stopping a listen says which control it was for, once", heard, ["rc_dash"]],
		["and nothing is waiting afterwards", waiting, false],
	])


static func _studio_card() -> bool:
	var cards: Array = EventSheetSaveStudio.settings_files()
	var card: Array = cards[2]
	return SUPPORT.pins(NAME, [
		["the key bindings card names the Keyboard row's file", card[1], "user://bindings.cfg"],
		["and the Settings pack's file and section", card[7], "user://settings.cfg [bindings]"],
		["and says both in words", str(card[2]).contains("user://bindings.cfg") and str(card[2]).contains("user://settings.cfg") and str(card[2]).contains("[bindings]"), true],
		["the other two cards stay as they were", [cards.size(), cards[1].size(), cards[0].size()], [3, 7, 7]],
	])


## The saving showcase opens with its three variables set to Manually, and the block that writes that choice is
## not shown as a variable of its own: a file the importer cannot read back byte for byte would show Never.
static func _saving_showcase_reads_back() -> bool:
	var save_choices: GDScript = load("res://addons/eventforge/compiler/save_choices.gd")
	var sheet: EventSheetResource = EventSheetGDScriptImporter.new().import_external("res://demo/showcase/options_and_quick_save/options_and_quick_save.gd")
	var choices: Dictionary = {}
	for entry: Variant in sheet.events:
		if entry is LocalVariable:
			choices[(entry as LocalVariable).name] = save_choices.choice_of((entry as LocalVariable).attributes)
	return SUPPORT.pins(NAME, [
		["the saving showcase reads back its three Manual choices", choices, {"coins": "manual", "player_spot": "manual", "picked_coins": "manual"}],
	])


static func _doctor_note(pack_source: String) -> bool:
	var uses_pack: String = "func _ready() -> void:\n\tSettings.declare_setting(\"a\", 1)\n"
	var other: String = "extends Node\nfunc volume() -> int:\n\treturn 1\n"
	var answering: String = "extends Node\nfunc declare_setting(name, value) -> void:\n\tpass\n"
	var note: String = EventSheetProjectDoctor.settings_global_message("res://own/settings.gd", other, pack_source, uses_pack)
	return SUPPORT.pins(NAME, [
		["another script behind Settings, with the pack's rows in use, is noted", note.contains("res://own/settings.gd"), true],
		["in two short sentences", note.count(". ") + 1, 2],
		["the pack itself is quiet", EventSheetProjectDoctor.settings_global_message(PACK_PATH, pack_source, pack_source, uses_pack), ""],
		["a global that answers every call is quiet", EventSheetProjectDoctor.settings_global_message("res://own/settings.gd", answering, pack_source, uses_pack), ""],
		["a script that never uses the rows is quiet", EventSheetProjectDoctor.settings_global_message("res://own/settings.gd", other, pack_source, "var x = 1\n"), ""],
	])
