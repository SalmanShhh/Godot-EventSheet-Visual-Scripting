# Godot EventSheets - lists of instances: Push back once, Set to the instances in a group, Drop freed.
#
# Each row is plain Array code; written by hand, each opens as its row and saves back byte for byte.
@tool
class_name InstanceListRowsTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const ROWS := preload("res://tests/stack_queue_rows_test.gd")
const NAME := "instance_list_rows"


static func run() -> bool:
	var ok: bool = true
	ok = SUPPORT.check(NAME, "Push back, once guards the append with has",
		ROWS.compiled("ArrayAppendOnce", {"var_name": "selected", "value": "unit"}).contains("\tif not selected.has(unit):\n\t\tselected.append(unit)\n"), true) and ok
	ok = SUPPORT.check(NAME, "Set to the instances in a group writes assign over a filtered group",
		ROWS.compiled("ArraySetFromGroup", {"var_name": "selected", "group": "\"units\"", "test": "one.visible"}).contains(
			"\tselected.assign(get_tree().get_nodes_in_group(\"units\").filter(func(one): return one.visible))\n"), true) and ok
	ok = SUPPORT.check(NAME, "Drop freed instances filters by is_instance_valid",
		ROWS.compiled("ArrayDropFreed", {"var_name": "selected"}).contains("\tselected.assign(selected.filter(is_instance_valid))\n"), true) and ok
	for case: Array in [
		["Push back, once", "\tif not selected.has(unit):\n\t\tselected.append(unit)\n", "ArrayAppendOnce"],
		["Set to the instances in a group", "\tselected.assign(get_tree().get_nodes_in_group(\"units\").filter(func(one): return box.has_point(one.position)))\n", "ArraySetFromGroup"],
		["Drop freed instances", "\tselected.assign(selected.filter(is_instance_valid))\n", "ArrayDropFreed"],
	]:
		var opened: Dictionary = ROWS.reopened(str(case[1]))
		ok = SUPPORT.check(NAME, "a hand-written %s opens as %s" % [case[0], case[2]], opened["ids"], PackedStringArray([case[2]])) and ok
		ok = SUPPORT.check(NAME, "...and saves back byte for byte (%s)" % case[0], opened["again"], opened["source"]) and ok
	var plain: Dictionary = ROWS.reopened("\tif not selected.has(unit):\n\t\tprint(unit)\n")
	ok = SUPPORT.check(NAME, "an if-not-has with another body is not claimed", plain["ids"].has("ArrayAppendOnce"), false) and ok
	ok = SUPPORT.check(NAME, "...and still saves back byte for byte", plain["again"], plain["source"]) and ok
	return ok
