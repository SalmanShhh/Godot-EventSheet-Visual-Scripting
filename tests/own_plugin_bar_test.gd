@tool
extends RefCounted

# A user's own editor plugin, opened as a sheet. Its head bar used to offer "Enable plugin" while the
# project already ran it, and pressing it wrote a fresh plugin.cfg over theirs - author and version
# gone. A plugin the project enables offers no Enable plugin, and a folder that has its own
# plugin.cfg keeps it as written; only a folder with none gets one.

const SUPPORT := preload("res://tests/support.gd")
const P := "own_plugin_bar_test"

const SCRIPT_PATH := "res://addons/own_plugin_bar_probe/plugin.gd"
const USERS_CFG := """[plugin]

name="Level Tools"
description="Small helpers for building levels."
author="Me"
version="0.1"
script="plugin.gd"
"""


static func run() -> bool:
	var plugin: EventSheetResource = EventSheetStarterTemplates.build_starter(12)
	var before: Variant = ProjectSettings.get_setting("editor_plugins/enabled", PackedStringArray())
	var offered_off: String = _texts(plugin)
	ProjectSettings.set_setting("editor_plugins/enabled",
		PackedStringArray(["res://addons/own_plugin_bar_probe/plugin.cfg"]))
	var offered_on: String = _texts(plugin)
	ProjectSettings.set_setting("editor_plugins/enabled", before)
	return SUPPORT.pins(P, [
		["a plugin the project does not run yet offers Enable plugin", offered_off,
			"▶ Run now|↻ Reload|Output ▾ no output yet|Enable plugin"],
		["one the project already runs does not", offered_on, "▶ Run now|↻ Reload|Output ▾ no output yet"],
		["a folder with its own plugin.cfg keeps it as written",
			EventSheetEditorToolBar.plugin_cfg_to_write(USERS_CFG, "Level Tools", "", "plugin.gd"), ""],
		["a folder with none gets the one the sheet describes",
			EventSheetEditorToolBar.plugin_cfg_to_write("", "Level Tools", "", "plugin.gd"),
			EventSheetEditorToolBar.plugin_cfg_text("Level Tools", "", "plugin.gd")],
	])


static func _texts(sheet: EventSheetResource) -> String:
	var texts: PackedStringArray = PackedStringArray()
	for button: Dictionary in EventSheetEditorToolBar.buttons_for(sheet, SCRIPT_PATH):
		texts.append(str(button["text"]))
	return "|".join(texts)
