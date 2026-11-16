# Godot EventSheets - The Doctor notices groups used as states.
#
# A reader from another event-sheet editor often keeps an object's state as group membership: every
# place that puts it in "jumping" takes it out of "running" and "idle", so exactly one of the groups
# is true at a time. That is a state machine written the long way, and the Doctor says so once per
# script, quietly, naming the groups, with the States window as the way out. Groups that are not
# swapped against each other (an "enemies" group, a "pickups" group) are not states and are never
# named.
@tool
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")
const P := "groups_as_states_note_test"
const DETECTOR := "groups_used_as_states"
const SWAPPED := "extends CharacterBody2D\n\n\nfunc _physics_process(_delta: float) -> void:\n\tif is_on_floor():\n\t\tadd_to_group(\"running\")\n\t\tremove_from_group(\"jumping\")\n\telse:\n\t\tadd_to_group(\"jumping\")\n\t\tremove_from_group(\"running\")\n"
const ONCE := "extends Node\n\n\nfunc _ready() -> void:\n\tadd_to_group(\"a\")\n\tremove_from_group(\"b\")\n"
const APART := "extends Node\n\n\nfunc _ready() -> void:\n\tadd_to_group(\"a\")\n\n\nfunc _exit_tree() -> void:\n\tremove_from_group(\"b\")\n\n\nfunc _process(_delta: float) -> void:\n\tadd_to_group(\"b\")\n\n\nfunc _input(_event: InputEvent) -> void:\n\tremove_from_group(\"a\")\n"
const PLAIN := "extends Node2D\n\n\nfunc _ready() -> void:\n\tadd_to_group(\"enemies\", true)\n\tadd_to_group(\"pickups\", true)\n"


static func run() -> bool:
	var detector: GDScript = EventSheetDoctorTidiness
	var ok: bool = SUPPORT.check(P, "the Doctor's tidiness sweep can tell groups used as states", detector.has_method(DETECTOR), true)
	if not detector.has_method(DETECTOR):
		return ok
	ok = SUPPORT.check(P, "two groups swapped against each other are named as states",
		Array(detector.call(DETECTOR, SWAPPED)), ["jumping", "running"]) and ok
	ok = SUPPORT.check(P, "groups that are only joined are not states", Array(detector.call(DETECTOR, PLAIN)), []) and ok
	ok = SUPPORT.check(P, "one swap on its own is not named", Array(detector.call(DETECTOR, ONCE)), []) and ok
	ok = SUPPORT.check(P, "joining and leaving in different blocks is not a swap", Array(detector.call(DETECTOR, APART)), []) and ok
	ok = SUPPORT.check(P, "a script with no groups names none", Array(detector.call(DETECTOR, "extends Node\n")), []) and ok
	return ok
