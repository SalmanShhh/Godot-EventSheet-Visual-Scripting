# EventForge - the name a script's own lines read under, for a script a user wrote.
#
# A line about the script itself leads with the class icon and then the script's NAME: its
# class_name when it has one, the singleton name of an autoload, else the file's name as written
# (`spike_ring`). The class it extends is the icon, never the word - a `Node2D` in the object column
# says nothing about which object it is. A behaviour pack's lines are about the node it sits on, so
# a pack names no object of its own.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "script_object_name_test"


static func run() -> bool:
	# The tab leads with the class icon, so the name stands alone after it - no second kind mark.
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	var tab: String = dock._format_tab_title(_sheet("a class_name"), "res://player.gd", false)
	dock.free()
	var ok: bool = SUPPORT.pin_value(P, "a custom node's tab is its name alone", tab, "Player")
	return SUPPORT.pin_table(P, {
		"a class_name": "Player",
		"a file with no class_name": "spike_ring",
		"an autoload": "GameState",
		"a behaviour pack": "",
		"a sheet with no file yet": "Node2D",
	}, func(key: String) -> String: return EventSheetViewportReadingRows.script_object_name(_sheet(key))) and ok


static func _sheet(key: String) -> EventSheetResource:
	var sheet := EventSheetResource.new()
	sheet.host_class = "Node2D"
	match key:
		"a class_name":
			sheet.custom_class_name = "Player"
			sheet.external_source_path = "res://player.gd"
		"a file with no class_name":
			sheet.external_source_path = "res://spike_ring.gd"
		"an autoload":
			sheet.host_class = "Node"
			sheet.autoload_mode = true
			sheet.autoload_name = "GameState"
			sheet.external_source_path = "res://game_state.gd"
		"a behaviour pack":
			sheet.behavior_mode = true
			sheet.external_source_path = "res://eventsheet_addons/sine/sine_behavior.gd"
	return sheet
