# Godot EventSheets - the Codex pack, driven directly.
#
# A codex is a SET, and a set is the one data structure whose bugs are invisible in a screenshot:
# the same page counted twice, the count that disagrees with the loop beside it, the celebration
# that fires on the second visit as well as the first, the whole collection lost because the save
# carried a Dictionary that arrived back as something else. So this file loads the COMPILED pack,
# drives the real director with no scene tree, writes real entry files under user:// and pins the
# values it produces.
#
# The traps it exists to catch, each one a rule the pack states and a reader would otherwise have
# to trust:
#   - the pack is the Codex autoload, and every row it emits addresses it by that name;
#   - discovering the same entry twice leaves the set at one, and the count says so;
#   - two sets never see each other's entries;
#   - On First Discovered fires on the first Discover of an entry and is silent on every one after,
#     which is what lets the row that fills the codex be the row that celebrates it;
#   - Total Entries counts the FILES in the set's folder, so a page added to the folder joins the
#     total with nothing else edited, and a folder that is not there counts zero rather than erroring;
#   - For Each Discovered hands back the entry RESOURCES, in name order, skipping a discovered id no
#     file answers to any more rather than passing null into the loop;
#   - the whole set round-trips through a real save file under the same __addons key Save All Addons
#     writes, which is the only persistence this pack claims.
@tool
class_name CodexPackTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const PACK := "res://eventsheet_addons/codex/codex_addon.gd"
const ENTRY_RESOURCE := "res://eventsheet_addons/codex_entry_resource/codex_entry_resource.gd"
const SAVE_PACK := "res://eventsheet_addons/save_system/save_system_addon.gd"
const TEST := "codex_pack_test"

## Where this test's entry files live. A folder of its own under user://, so the director's own
## folder-is-the-set lookup is exercised rather than a list handed straight to it.
const CODEX_FOLDER := "user://codex_pack_test"

## The key Save All Addons writes every autoload's snapshot under, and the slot this test uses -
## its own, so a real save is never touched.
const ADDONS_KEY := "__addons"
const TEST_SLOT := 8


static func run() -> bool:
	var script: GDScript = load(PACK)
	var passed: bool = SUPPORT.check(TEST, "the pack loads and parses", script != null, true)
	if script == null:
		return passed
	_write_entries()
	passed = _the_pack_ships_as_the_autoload(script) and passed
	passed = _the_set_counts_by_value(script) and passed
	passed = _the_way_back_out(script) and passed
	passed = _first_discovered_fires_once(script) and passed
	passed = _the_folder_is_the_set(script) and passed
	passed = _the_loop_hands_back_pages(script) and passed
	passed = _the_set_rides_a_real_save_file(script) and passed
	return passed


# ── One codex, reached from anywhere ──────────────────────────────────────────────────────────


## What has been found belongs to the game rather than to whichever scene noticed it, so this pack
## ships as the Codex AUTOLOAD. That is not a remark about the file: it is what every row the pack
## emits ADDRESSES, so it is pinned against the shipped bytes rather than against the builder.
static func _the_pack_ships_as_the_autoload(script: GDScript) -> bool:
	var source: String = FileAccess.get_file_as_string(PACK)
	var templates: int = 0
	var not_the_autoload: int = 0
	for line: String in source.split("\n"):
		if not line.begins_with("## @ace_codegen_template("):
			continue
		templates += 1
		if not line.begins_with("## @ace_codegen_template(\"Codex."):
			not_the_autoload += 1
	return SUPPORT.pins(TEST, [
		["the pack declares codegen templates", templates > 0, true],
		["every one of them addresses the Codex autoload", not_the_autoload, 0],
		["the pack answers the save seam", script.new().has_method(&"save_state"), true],
	])


# ── A set, not a list ─────────────────────────────────────────────────────────────────────────


## The whole point of a set: the same page found twice is one page. A count that walked a list
## instead would read two, and the codex screen would say "2 / 3" with one entry drawn on it.
static func _the_set_counts_by_value(script: GDScript) -> bool:
	var codex: Node = _director(script)
	codex.discover("enemies", "slime")
	codex.discover("enemies", "slime")
	codex.discover("enemies", "bat")
	codex.discover("items", "key")
	var pins: bool = SUPPORT.pins(TEST, [
		["the same entry twice is one entry", codex.discovered_count("enemies"), 2],
		["it is in", codex.has_discovered("enemies", "slime"), true],
		["one nobody found is not", codex.has_discovered("enemies", "ghost"), false],
		["a second set keeps its own entries", codex.discovered_count("items"), 1],
		["and does not see the first set's", codex.has_discovered("items", "slime"), false],
		["a set nothing has touched is empty", codex.discovered_count("rooms"), 0],
		["an entry with no name is refused", _discovered_after_empty_name(script), 0],
	])
	codex.free()
	return pins


## THE WAY BACK OUT. A set that can only ever grow leaks across saves: a New Game in the same
## session, a page a cheat menu locked again, a run-only discovery. Load All Addons deliberately
## leaves a codex alone when the save carries none of its own - the same empty-state rule every
## autoload pack here follows - so forgetting is a row rather than a side effect of loading.
static func _the_way_back_out(script: GDScript) -> bool:
	var codex: Node = _director(script)
	codex.discover("enemies", "slime")
	codex.discover("enemies", "bat")
	codex.discover("items", "key")
	var rows: Array = []

	codex.forget_entry("enemies", "slime")
	rows.append(["a forgotten entry is not discovered any more",
		codex.has_discovered("enemies", "slime"), false])
	rows.append(["and the rest of its set is left alone", codex.discovered_count("enemies"), 1])
	rows.append(["and so is the entry that is still in", codex.has_discovered("enemies", "bat"), true])

	codex.forget_entry("enemies", "ghost")
	rows.append(["forgetting one nobody ever found changes nothing",
		codex.discovered_count("enemies"), 1])

	codex.forget_set("enemies")
	rows.append(["forgetting a whole set empties it", codex.discovered_count("enemies"), 0])
	rows.append(["and the other set keeps everything it had", codex.discovered_count("items"), 1])

	codex.discover("enemies", "slime")
	rows.append(["a set that was emptied can be filled again",
		codex.has_discovered("enemies", "slime"), true])

	var pins: bool = SUPPORT.pins(TEST, rows)
	codex.free()
	return pins


## An empty name would otherwise land in the set as "", counted for ever and matching nothing.
static func _discovered_after_empty_name(script: GDScript) -> int:
	var codex: Node = _director(script)
	codex.discover("enemies", "")
	var count: int = codex.discovered_count("enemies")
	codex.free()
	return count


## The first Discover of an entry is a MOMENT - the toast, the page-turn, the achievement - and
## every one after it is not. Firing on both is what makes a sheet author keep a second boolean
## beside the codex, which is the whole thing this pack exists to remove.
static func _first_discovered_fires_once(script: GDScript) -> bool:
	var codex: Node = _director(script)
	var heard: Array = []
	codex.first_discovered.connect(func(set_name: String, entry_id: String) -> void:
		heard.append("%s/%s" % [set_name, entry_id]))
	codex.discover("enemies", "slime")
	codex.discover("enemies", "slime")
	codex.discover("enemies", "bat")
	var pins: bool = SUPPORT.pins(TEST, [
		["it fires once per entry, never twice", heard, ["enemies/slime", "enemies/bat"]],
	])
	codex.free()
	return pins


# ── The folder is the set ─────────────────────────────────────────────────────────────────────


## Total Entries counts the files, so a page added to the folder joins the total with no sheet
## edit and no list anywhere. A set with no folder counts zero instead of erroring, because this
## is the kind of row a menu asks every frame.
static func _the_folder_is_the_set(script: GDScript) -> bool:
	var codex: Node = _director(script)
	var pins: bool = SUPPORT.pins(TEST, [
		["the folder's files are the total", codex.total_entries("enemies"), 3],
		["a folder that is not there counts nothing", codex.total_entries("nowhere"), 0],
		["a set is counted before anything is found", codex.discovered_count("enemies"), 0],
	])
	codex.free()
	return pins


## The loop hands back the entry RESOURCES so a page can be drawn from one row - the name, the
## picture and the words are all on the thing the loop is standing on. A discovered id whose file
## has gone is skipped rather than arriving as null and taking the codex screen down with it.
static func _the_loop_hands_back_pages(script: GDScript) -> bool:
	var codex: Node = _director(script)
	codex.discover("enemies", "slime")
	codex.discover("enemies", "ghost")
	codex.discover("enemies", "bat")
	var names: Array = []
	for page: Resource in codex.each_discovered("enemies"):
		names.append(page.entry_name)
	var pins: bool = SUPPORT.pins(TEST, [
		["the pages come back in name order, and the one with no file is skipped",
			names, ["Brown Bat", "Green Slime"]],
		["a set nothing has been found in walks nothing", codex.each_discovered("items"), []],
	])
	codex.free()
	return pins


# ── The save ──────────────────────────────────────────────────────────────────────────────────


## The only persistence this pack claims: `save_state` / `load_state`, which Save All Addons puts
## under this autoload's own name in the slot. So the round trip is driven through a REAL save
## file written by the real Save System pack, under the real key - not through a Dictionary handed
## from one method to the other, which would pass while the file format quietly dropped it.
static func _the_set_rides_a_real_save_file(script: GDScript) -> bool:
	var save_script: GDScript = load(SAVE_PACK)
	if save_script == null:
		return SUPPORT.check(TEST, "the save pack loads", false, true)
	var keeper: Node = save_script.new()
	keeper.slot = TEST_SLOT
	var before: Node = _director(script)
	before.discover("enemies", "slime")
	before.discover("enemies", "bat")
	before.discover("items", "key")
	keeper.save_value(ADDONS_KEY, {"Codex": before.save_state()})

	var after: Node = _director(script)
	var states: Variant = keeper.load_value(ADDONS_KEY, {})
	after.load_state((states as Dictionary).get("Codex", {}))
	var pins: bool = SUPPORT.pins(TEST, [
		["the set comes back off disk", after.discovered_count("enemies"), 2],
		["entry by entry", after.has_discovered("enemies", "bat"), true],
		["and the other set with it", after.has_discovered("items", "key"), true],
		["a state nobody wrote leaves the codex alone", _loaded_from_nothing(script), 2],
	])
	keeper.delete_slot()
	keeper.free()
	before.free()
	after.free()
	return pins


## An empty state is a save that has no codex in it yet, not an instruction to forget one - the
## difference between a mid-run Load All Addons and a wiped collection.
static func _loaded_from_nothing(script: GDScript) -> int:
	var codex: Node = _director(script)
	codex.discover("enemies", "slime")
	codex.discover("enemies", "bat")
	codex.load_state({})
	var count: int = codex.discovered_count("enemies")
	codex.free()
	return count


# ── The fixtures ──────────────────────────────────────────────────────────────────────────────


## One director pointed at this test's own entry folder.
static func _director(script: GDScript) -> Node:
	var codex: Node = script.new()
	codex.codex_folder = CODEX_FOLDER
	return codex


## Two real entry files in one set folder, plus a third the set holds but nothing here discovers -
## so Total Entries and Discovered Count are measuring different things and cannot agree by
## accident. "ghost" is deliberately NOT written: it is the discovered id with no file behind it.
static func _write_entries() -> void:
	var entry_script: GDScript = load(ENTRY_RESOURCE)
	DirAccess.make_dir_recursive_absolute(CODEX_FOLDER.path_join("enemies"))
	_write_entry(entry_script, "slime", "Green Slime")
	_write_entry(entry_script, "bat", "Brown Bat")
	_write_entry(entry_script, "wolf", "Grey Wolf")


static func _write_entry(entry_script: GDScript, entry_id: String, entry_name: String) -> void:
	var page: Resource = entry_script.new()
	page.entry_name = entry_name
	page.text = "A page about the %s." % entry_name.to_lower()
	ResourceSaver.save(page, CODEX_FOLDER.path_join("enemies").path_join(entry_id + ".tres"))
