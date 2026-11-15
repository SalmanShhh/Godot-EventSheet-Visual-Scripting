# Godot EventSheets - trying a list in the editor: one card, from a card down, or all, honestly.
#
# THE ONE THING THIS FILE IS ABOUT: the editor preview plays what it can play for real, shows as
# time what is about time, and names what it skips, and it reads the same plan the running game
# reads. The pack stays a plain script: everything here is a static the editor may call, or the
# preview file the plugin loads by path.
#
# The toolbar's beat segment drives the Inspector strip by its four public doors (Play, Stop, Skip,
# Restore). Those four are pinned here because a strip rebuilt for this work must keep them.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const NEW_PACK: String = "res://eventsheet_addons/juice/juice_player.gd"
const OLD_PACK: String = "res://eventsheet_addons/juice/feedback_player.gd"
const STRIP_PATH: String = "res://addons/eventsheet/editor/inspector/feedback_player_strip.gd"
const PREVIEW_PATH: String = "res://addons/eventsheet/editor/inspector/juice_preview.gd"

const TEST_NAME: String = "juice_card_preview"


static func run() -> bool:
	var ok: bool = true
	ok = _strip_door_pins() and ok
	ok = _footer_pins() and ok
	return ok


static func _pack() -> Script:
	return load(NEW_PACK if ResourceLoader.exists(NEW_PACK) else OLD_PACK) as Script


static func _has_static(script: Script, method: String) -> bool:
	if script == null:
		return false
	for listed: Dictionary in script.get_script_method_list():
		if str(listed.get("name")) == method:
			return true
	return false


## The four doors the toolbar segment calls, still on the strip.
static func _strip_door_pins() -> bool:
	var strip: Script = load(STRIP_PATH) as Script
	var doors: PackedStringArray = PackedStringArray()
	for door: String in ["play", "stop", "skip", "restore"]:
		if _has_method(strip, door):
			doors.append(door)
	return SUPPORT.pins(TEST_NAME, [
		["the strip keeps the four doors the toolbar segment presses", doors, PackedStringArray(["play", "stop", "skip", "restore"])]
	])


static func _has_method(script: Script, method: String) -> bool:
	for listed: Dictionary in script.get_script_method_list():
		if str(listed.get("name")) == method:
			return true
	return false


## The strip sits under the list it plays: the list's schema declares it as a footer, the drawer builds
## it for the object it is editing, and the Inspector plugin no longer puts one at the top.
static func _footer_pins() -> bool:
	var schema: Dictionary = load("res://addons/eventsheet/editor/inspector/feedback_card_schema.gd").call("schema")
	var player: Node = _pack().new()
	var drawer: EventSheetCardListDrawer = EventSheetCardListDrawer.new({"schema_dict": schema, "kind_key": "verb", "stripe_key": "category"})
	drawer.set_edited_object(player)
	var footer: Control = drawer.footer()
	var script_path: String = footer.get_script().resource_path if footer != null else ""
	var plugin: Script = load("res://addons/eventsheet/editor/inspector/feedback_player_inspector_plugin.gd") as Script
	var adds_at_top: bool = _has_method(plugin, "_parse_begin")
	var again: Control = drawer.footer()
	drawer.set_edited_object(player)
	var kept: bool = drawer.footer() == again
	var parent_is_drawer: bool = footer != null and drawer.is_ancestor_of(footer)
	var plain: EventSheetCardListDrawer = EventSheetCardListDrawer.new({"schema_dict": {"kinds": []}})
	plain.set_edited_object(player)
	var plain_footer: Control = plain.footer()
	var result: bool = SUPPORT.pins(TEST_NAME, [
		["the juice list declares a footer", schema.get("footer") is Callable, true],
		["the drawer builds the strip for the object it edits", script_path, STRIP_PATH],
		["and puts it under its own cards", parent_is_drawer, true],
		["asking again keeps the one strip", kept, true],
		["the Inspector plugin adds nothing at the top any more", adds_at_top, false],
		["a list whose schema declares no footer gets none", plain_footer == null, true]
	])
	drawer.free()
	plain.free()
	player.free()
	return result
