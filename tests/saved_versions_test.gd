@tool
class_name SavedVersionsTest
extends RefCounted

## Two behaviours write a version number into what they save and used to ignore it on the way back.
## Drunken Walkers' saved state and Platformer Pathfinding's obstacle map JSON now say, when they are
## read, that a record from a NEWER version may lose parts of itself, and read it anyway: nothing a
## user already saved is refused, and a record with no version at all (an older save) is read as
## the current one.

const SUPPORT := preload("res://tests/support.gd")
const NAME: String = "saved_versions_test"
const WALKERS_PATH: String = "res://eventsheet_addons/drunken_walkers/drunken_walkers_addon.gd"
const PATHFINDING_PATH: String = "res://eventsheet_addons/platformer_pathfinding/platformer_pathfinding_behavior.gd"


static func run() -> bool:
	var passed: bool = true
	passed = _walkers() and passed
	passed = _obstacle_map() and passed
	return passed


static func _walkers() -> bool:
	var script: GDScript = load(WALKERS_PATH) as GDScript
	var rows: Array = []
	for label: String in ["no version", "this version", "a newer version"]:
		var state: Dictionary = {"width": 3, "height": 2, "cells": [1, 0, 1, 0, 1, 0]}
		if label == "this version":
			state["version"] = script.get_script_constant_map().get("STATE_VERSION")
		elif label == "a newer version":
			state["version"] = 99
		var walkers: Node = script.new() as Node
		walkers.call("load_state", state)
		rows.append(["%s: the grid is read" % label, [walkers.get("_width"), walkers.get("_height"), (walkers.get("_cells") as PackedInt32Array)[4]], [3, 2, 1]])
		walkers.free()
	var written: Node = script.new() as Node
	rows.append(["a saved state carries the version the behaviour reads", int((written.call("save_state") as Dictionary).get("version", 0)), int(script.get_script_constant_map().get("STATE_VERSION"))])
	written.free()
	return SUPPORT.pins(NAME, rows)


static func _obstacle_map() -> bool:
	var script: GDScript = load(PATHFINDING_PATH) as GDScript
	var nav: Node = script.new() as Node
	nav.call("create_obstacle_map", 10, 6, 16.0)
	nav.call("set_tile_state", 3, 5, "solid")
	var written: Dictionary = JSON.parse_string(str(nav.call("obstacle_map_json"))) as Dictionary
	var rows: Array = [["an exported map carries the version it reads", int(written.get("version", 0)), int(script.get_script_constant_map().get("OBSTACLE_MAP_VERSION"))]]
	for label: String in ["no version", "a newer version"]:
		var map: Dictionary = written.duplicate(true)
		if label == "no version":
			map.erase("version")
		else:
			map["version"] = 99
		var copy: Node = script.new() as Node
		copy.call("load_obstacle_map_json", JSON.stringify(map))
		rows.append(["%s: the map is read" % label, [copy.call("obstacle_map_source"), copy.call("tile_state", 3, 5)], ["custom", "solid"]])
		copy.free()
	nav.free()
	return SUPPORT.pins(NAME, rows)
