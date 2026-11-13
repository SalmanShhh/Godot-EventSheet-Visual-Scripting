@tool
class_name TableTagLookTest
extends RefCounted

## The tag look: the tags a table's rows carry are read from one comma separated column, a tag no row
## carries is found out, and a file wearing the look round-trips byte for byte (a plugin without the
## look carries the marker as text).

const SUPPORT := preload("res://tests/support.gd")
const TAGS_PATH: String = "res://addons/eventsheet/editor/inspector/table_tags.gd"
const ROWS: Array = [{"item": "coin", "tags": "common"}, {"item": "gem", "tags": "rare, shiny"}, {"item": "sword", "tags": " rare ,weapon,"}, {"item": "bare"}]
const LINE: String = "@export_custom(PROPERTY_HINT_NONE, \"eventsheet:table_tag:entries:tags\") var pity_tag: String = \"\""


static func run() -> bool:
	var tags: GDScript = load(TAGS_PATH)
	var found: PackedStringArray = tags.tags_in(ROWS, "tags")
	var result: bool = SUPPORT.pins("table_tag_look_test", [
		["each tag is listed once in the order it first appears", found, PackedStringArray(["common", "rare", "shiny", "weapon"])],
		["a cell is split on commas and trimmed", tags.words_of(" a , b,, c "), PackedStringArray(["a", "b", "c"])],
		["a row with no tags cell adds nothing", tags.tags_in([{"item": "bare"}], "tags").size(), 0],
		["a tag a row carries is found", tags.carries(ROWS, "tags", "rare"), true],
		["a tag no row carries is not", tags.carries(ROWS, "tags", "epic"), false],
		["an empty tag means none and is carried by no row", tags.carries(ROWS, "tags", ""), false],
	])
	var source: String = "extends Node\n\n" + LINE + "\n@export var entries: Array = []\n"
	result = SUPPORT.pins("table_tag_look_test", [
		["a file wearing the look re-saves byte for byte", SUPPORT.reemit(source, "user://table_tag_probe.gd"), source],
		["the look is in the catalogue as a shipped file", str(EventSheetInspectorLooks.by_id("table_tag").get("source", "")), "shipped"],
		["it asks which table and which column", (EventSheetInspectorLooks.by_id("table_tag").get("fields", []) as Array).map(func(field: Array) -> String: return str(field[0])), ["table", "tags_column"]],
		["it works on text", EventSheetInspectorLooks.by_id("table_tag").get("types"), ["String", "StringName"]],
	]) and result
	return result
