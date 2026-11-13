@tool
class_name SeedLookTest
extends RefCounted

## The seed look: a fresh seed is a positive whole number and never 0 (0 means a new one every run),
## the quiet line shows exactly while the value means that, and a file wearing the look re-saves
## byte for byte.

const SUPPORT := preload("res://tests/support.gd")
const LOOK_PATH: String = "res://addons/eventsheet/looks/seed.gd"
const LINE: String = "@export_custom(PROPERTY_HINT_NONE, \"eventsheet:seed\") var seed_on_start: int = 0"


static func run() -> bool:
	var look: GDScript = load(LOOK_PATH)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 11
	var seeds: Array = []
	var all_fine: bool = true
	for _step: int in 200:
		var picked: int = look.fresh_seed(rng)
		seeds.append(picked)
		all_fine = all_fine and picked > 0
	var source: String = "extends Node\n\n" + LINE + "\n"
	return SUPPORT.pins("seed_look_test", [
		["every fresh seed is positive", all_fine, true],
		["the seeds are not all the same", seeds.has(seeds[0]) and seeds.count(seeds[0]) < seeds.size(), true],
		["a seed of 0 says it means a new one every run", look.zero_note(0), "0: different every run."],
		["a seed of 5 says nothing", look.zero_note(5), ""],
		["an empty text seed says it means a new one every run", look.zero_note(""), "Empty: different every run."],
		["a text seed says nothing", look.zero_note("abc"), ""],
		["a file wearing the look re-saves byte for byte", SUPPORT.reemit(source, "user://seed_probe.gd"), source],
		["the look is a shipped file with no questions", [str(EventSheetInspectorLooks.by_id("seed").get("source", "")), (EventSheetInspectorLooks.by_id("seed").get("fields", []) as Array).size()], ["shipped", 0]],
		["it works on a number and on text", EventSheetInspectorLooks.by_id("seed").get("types"), ["int", "String"]],
	])
