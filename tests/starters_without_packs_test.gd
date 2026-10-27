# Godot EventSheets - the starters a project offers when the packs folder is not there.
#
# Installing the plugin copies the two addon folders and nothing else, so a starter written in a
# pack's words cannot be made in such a project: it names the pack it needs, and the New menu and
# the Start page leave it out while that pack is missing.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "starters_without_packs_test"


static func run() -> bool:
	var needs: Dictionary = {}
	for starter: Dictionary in EventSheetStarterTemplates.MENU_STARTERS:
		if starter.has("needs"):
			needs[str(starter["label"])] = starter["needs"]
	return SUPPORT.pins(P, [
		["the two starters written in a pack's words name the packs they need", needs, {
			"Level Stats Screen": ["res://eventsheet_addons/hud_kit/hud_kit_behavior.gd"],
			"Skill Tree Screen": ["res://eventsheet_addons/upgrades/upgrades_addon.gd",
				"res://eventsheet_addons/hud_kit/hud_kit_behavior.gd"]}],
		["a starter whose pack is missing is not offered",
			EventSheetStarterTemplates.is_offered({"needs": ["res://zz_no_such_pack/zz_no_such_pack.gd"]}), false],
		["one that needs nothing always is", EventSheetStarterTemplates.is_offered({"label": "Blank Sheet"}), true],
		["and with the packs here, both pack starters are", [
			EventSheetStarterTemplates.is_offered({"needs": needs.get("Level Stats Screen", [])}),
			EventSheetStarterTemplates.is_offered({"needs": needs.get("Skill Tree Screen", [])})], [true, true]],
	])
