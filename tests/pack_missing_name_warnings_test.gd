# Godot EventSheets - a pack action given a name nothing has says so, once.
#
# Many packs keep things by name (abilities, pools, quests, rooms). An action given a name that does
# not exist used to return without a word, so a mistyped "dash" for "Dash" looked exactly like a row
# that ran. Each such action now pushes one plain warning naming the node, the action as the sheet
# words it and the name that was not found, and saying what to do next. This loads each COMPILED
# pack, runs the action with a name that does not exist under an ear on the engine's warnings, pins
# the exact text, and runs it again to pin that the second call is silent. The action itself still
# does nothing: that is pinned too.
@tool
class_name PackMissingNameWarningsTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const NAME := "pack_missing_name_warnings_test"
const ROOT := "res://eventsheet_addons/"


static func run() -> bool:
	var ok: bool = true
	ok = _abilities() and ok
	ok = _object_pool() and ok
	return ok


## Runs `action` with an ear on the engine's warnings and returns what was said.
static func _heard(action: Callable) -> Array:
	var ear: SUPPORT.WarningEar = SUPPORT.WarningEar.new()
	OS.add_logger(ear)
	action.call()
	OS.remove_logger(ear)
	return ear.heard


## One row of the table: the first call says `text`, the second says nothing.
static func _once(label: String, action: Callable, text: String) -> Array:
	var first: Array = _heard(action)
	var second: Array = _heard(action)
	return [[label + " says what it did not find", first, [text]], [label + " says it only once", second, []]]


static func _abilities() -> bool:
	var script: GDScript = load(ROOT + "abilities/abilities_behavior.gd")
	var pack: Node = script.new()
	pack.name = "Hero"
	pack.create_ability("Dash")
	pack.create_ability("Jump")
	var tail: String = " (there are: Dash, Jump) - add it with Create Ability first, or check the spelling."
	var rows: Array = []
	var actions: Array = [
		["Remove Ability After Duration", "dash", func() -> void: pack.remove_ability_after("dash", 1.0)],
		["Remove Ability", "dsah", func() -> void: pack.remove_ability("dsah")],
		["Activate Ability", "dsh", func() -> void: pack.activate_ability("dsh")],
		["Set Ability Cooldown", "dd", func() -> void: pack.set_cooldown("dd", 1.0)],
		["Reset Cooldown", "de", func() -> void: pack.reset_cooldown("de")],
		["Set Max Stacks", "df", func() -> void: pack.set_max_stacks("df", 2)],
		["Set Stacks", "dg", func() -> void: pack.set_stacks("dg", 2)],
		["Add Stacks", "dh", func() -> void: pack.add_stacks("dh", 2)],
		["Consume Ability Stack", "di", func() -> void: pack.consume_stack("di")],
		["Set Ability Enabled", "dj", func() -> void: pack.set_enabled("dj", false)],
		["Set Ability Active", "dk", func() -> void: pack.set_active("dk", true)],
		["Set Ability Data", "dl", func() -> void: pack.set_ability_data("dl", "k", "v")],
		["Add Tag", "dm", func() -> void: pack.add_tag("dm", "fire")],
		["Remove Tag", "dn", func() -> void: pack.remove_tag("dn", "fire")],
		["Clear All Tags", "do", func() -> void: pack.clear_tags("do")],
	]
	for entry: Array in actions:
		rows.append_array(_once(str(entry[0]), entry[2],
			"Simple Abilities on Hero: %s did nothing, because no ability is called \"%s\"%s" % [entry[0], entry[1], tail]))
	rows.append(["a missing name creates nothing", pack.get_ability_count(), 2])
	rows.append(["a real name says nothing", _heard(func() -> void: pack.activate_ability("Dash")), []])
	pack.free()
	return SUPPORT.pins(NAME, rows)



static func _object_pool() -> bool:
	var script: GDScript = load(ROOT + "object_pool/object_pool_addon.gd")
	var pool: Node = script.new()
	pool.name = "ObjectPool"
	pool.create_empty_pool("bullets")
	var tail: String = " (there are: bullets) - make it with Create Pool or Create Empty Pool first, or check the spelling."
	var rows: Array = []
	var actions: Array = [
		["Add To Pool", "bulets", func() -> void: pool.add_to_pool("bulets", Node.new())],
		["Prewarm", "bulet", func() -> void: pool.prewarm("bulet", 4)],
		["Despawn All", "bullet", func() -> void: pool.despawn_all("bullet")],
		["Clear Pool", "bullts", func() -> void: pool.clear_pool("bullts")],
		["Spawn", "bulllets", func() -> void: pool.spawn("bulllets")],
		["Spawn Safely", "bulletz", func() -> void: pool.spawn_safely("bulletz", Vector2.ZERO)],
	]
	for entry: Array in actions:
		rows.append_array(_once(str(entry[0]), entry[2],
			"Object Pool on ObjectPool: %s did nothing, because no pool is called \"%s\"%s" % [entry[0], entry[1], tail]))
	rows.append_array(_once("Create Pool with a path that is no scene", func() -> void: pool.create_pool("rocks", "res://nowhere.tscn", 2),
		"Object Pool on ObjectPool: Create Pool made the pool \"rocks\" with no scene, because \"res://nowhere.tscn\" is not a scene Godot can load - check the path in the FileSystem dock."))
	rows.append_array(_once("Prewarm of a pool with no scene", func() -> void: pool.prewarm("bullets", 4),
		"Object Pool on ObjectPool: Prewarm did nothing, because the pool \"bullets\" has no scene of its own - Prewarm only fills a pool made with Create Pool, so fill this one with Add To Pool."))
	rows.append(["a missing pool is still not made by a row that missed", pool.has_pool("bulets"), false])
	rows.append(["a real pool says nothing", _heard(func() -> void: pool.despawn_all("bullets")), []])
	pool.free()
	return SUPPORT.pins(NAME, rows)
