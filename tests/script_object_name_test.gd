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
	ok = _a_line_aimed_at_another_body_keeps_its_class() and ok
	return SUPPORT.pin_table(P, {
		"a class_name": "Player",
		"a file with no class_name": "spike_ring",
		"an autoload": "GameState",
		"a behaviour pack": "",
		"a sheet with no file yet": "Node2D",
	}, func(key: String) -> String: return EventSheetViewportReadingRows.script_object_name(_sheet(key))) and ok


## A player script's own Move and slide is the player's line; the same verb aimed at an enemy body
## (`enemy.move_and_slide()`) is the enemy's, and must not read under the player's name - the object
## column would claim the wrong object. The object summary of the sheet asks the same question.
static func _a_line_aimed_at_another_body_keeps_its_class() -> bool:
	var viewport: EventSheetViewport = EventSheetViewport.new()
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "CharacterBody2D"
	sheet.custom_class_name = "Player"
	sheet.external_source_path = "res://player.gd"
	viewport._sheet = sheet
	viewport._ace_registry.refresh_from_sources([], true)
	var builder: Variant = viewport._row_builder
	var aimed: ACEAction = ACEAction.new()
	aimed.provider_id = "Core"
	aimed.ace_id = "MoveAndSlide"
	aimed.params = {"target": "enemy"}
	var row: EventRow = EventRow.new()
	row.actions.append(aimed)
	var labels: PackedStringArray = PackedStringArray()
	builder._collect_group_object_labels([row], labels, {})
	var ok: bool = SUPPORT.pin_table(P, {
		"its own line, no target": "Player",
		"its own line, target self": "Player",
		"another body's line": "CharacterBody2D",
		"another body's line, through the object column": "CharacterBody2D",
		"another body's line, in a folded group's object summary": "CharacterBody2D",
	}, func(key: String) -> String:
		match key:
			"its own line, no target":
				return builder._object_label_for("Core", "MoveAndSlide", {})
			"its own line, target self":
				return builder._object_label_for("Core", "MoveAndSlide", {"target": "self"})
			"another body's line":
				return builder._object_label_for("Core", "MoveAndSlide", {"target": "enemy"})
			"another body's line, through the object column":
				return builder._object_label_or_pending("Core", "MoveAndSlide", builder._row_params(aimed))
		return ",".join(labels))
	viewport.free()
	return ok


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
