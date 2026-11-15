@tool
class_name ScriptRowsListingTest
extends RefCounted

# Godot EventSheets - which scripts of yours list themselves, and the one click for the rest.
#
# With no setup: Node scripts with a class_name, autoloads, Resource scripts with a class_name (and the
# scripts on nodes of the open scene, which the picker's own shelf already covers). Everything else - a
# helper of statics, a script with no class_name - takes one click on the FileSystem menu, "Use in
# event sheets", which writes the existing taught-scripts setting. Once a script is in use the entry
# reads "Use in event sheets…" and opens its page. A shipped behaviour or a plugin file is never offered.
#
# The new functions are asked by name and called only when present, and their answers are compared as
# text, so a missing function fails its pins instead of stopping the suite (bool == String is an error).

const SUPPORT := preload("res://tests/support.gd")
const DIR: String = "res://tests/fixtures/script_rows/"
const MENU_PATH: String = "res://addons/eventforge/editor/context_menu_plugin.gd"
const API_PATH: String = "res://addons/eventsheet/api/eventsheets.gd"
const TAUGHT: String = "eventsheets/vocabulary/taught_provider_scripts"
const MISSING: String = "<not written yet>"


static func run() -> bool:
	var ok: bool = _what_lists_itself()
	ok = _the_menu_entry() and ok
	ok = _the_one_click() and ok
	return ok


static func _call(script_path: String, method: String, args: Array) -> Variant:
	var script: GDScript = load(script_path)
	for entry: Dictionary in script.get_script_method_list():
		if str(entry.get("name", "")) == method:
			return script.callv(method, args)
	return MISSING


static func _names(entries: Variant) -> Array:
	if not (entries is Array):
		return [entries]
	var found: Array = []
	for entry: Variant in entries:
		var entry_name: String = str((entry as Dictionary).get("name", ""))
		if entry_name.begins_with("ScriptRows"):
			found.append(entry_name)
	found.sort()
	return found


static func _what_lists_itself() -> bool:
	EventSheetProjectScanner.reset_for_tests()
	var offered: Variant = _call("res://addons/eventsheet/ace/project_scanner.gd", "list_offered_scripts", [])
	return SUPPORT.pins("script_rows_listing_test", [
		# Today's shape stays: the picker's card list is the Node classes and the autoloads.
		["the class cards keep their shape", _names(EventSheetProjectScanner.list_project_classes()),
			["ScriptRowsAnnotatedTwin", "ScriptRowsNodeThing", "ScriptRowsSentenceThing"]],
		# The offered set adds the Resource script; the helper and the class-less script wait for the click.
		["what lists itself with no setup", _names(offered),
			["ScriptRowsAnnotatedTwin", "ScriptRowsNodeThing", "ScriptRowsResourceThing", "ScriptRowsSentenceThing"]],
	])


static func _the_menu_entry() -> bool:
	var slot: int = EditorContextMenuPlugin.CONTEXT_SLOT_FILESYSTEM
	var offer: Callable = func(path: String) -> Variant:
		return str(_call(MENU_PATH, "should_offer_use_in_sheets", [slot, PackedStringArray([path])]))
	var words: Callable = func(path: String) -> Variant:
		return _call(MENU_PATH, "use_in_sheets_text", [path])
	return SUPPORT.pins("script_rows_listing_test", [
		["a helper of yours is offered", offer.call(DIR + "static_only.gd"), "true"],
		["a script with no class_name is offered", offer.call(DIR + "loose_thing.gd"), "true"],
		["a shipped behaviour is not", offer.call("res://eventsheet_addons/juice/juice_behavior.gd"), "false"],
		["a plugin file is not", offer.call("res://addons/eventforge/plugin.gd"), "false"],
		["a scene is not", offer.call("res://demo/showcase/platformer/main.tscn"), "false"],
		["not yet in use, it acts at once", words.call(DIR + "static_only.gd"), "Use in event sheets"],
		["already listing itself, it opens the page", words.call(DIR + "node_thing.gd"), "Use in event sheets…"],
	])


static func _the_one_click() -> bool:
	var before: Variant = ProjectSettings.get_setting(TAUGHT, PackedStringArray())
	ProjectSettings.set_setting(TAUGHT, null)
	var helper: String = DIR + "static_only.gd"
	var first: String = str(_call(API_PATH, "use_script_in_sheets", [helper]))
	var second: String = str(_call(API_PATH, "use_script_in_sheets", [helper]))
	var taught: Array = Array(ProjectSettings.get_setting(TAUGHT, PackedStringArray()))
	var shipped: String = str(_call(API_PATH, "use_script_in_sheets", ["res://eventsheet_addons/juice/juice_behavior.gd"]))
	var taught_after_shipped: Array = Array(ProjectSettings.get_setting(TAUGHT, PackedStringArray()))
	var words_now: Variant = _call(MENU_PATH, "use_in_sheets_text", [helper])
	ProjectSettings.set_setting(TAUGHT, before)
	return SUPPORT.pins("script_rows_listing_test", [
		["the click says it worked", first, "true"],
		["a second click changes nothing", second, "false"],
		["the script is in the existing setting once", taught, [helper]],
		["a shipped behaviour is refused", shipped, "false"],
		["and never written", taught_after_shipped, [helper]],
		["once in use the entry opens the page", words_now, "Use in event sheets…"],
	])
