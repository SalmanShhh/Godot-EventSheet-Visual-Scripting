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
	ok = _quest() and ok
	ok = _proc_room() and ok
	ok = _utility_ai() and ok
	ok = _milestones() and ok
	ok = _stat_forge() and ok
	ok = _second_view() and ok
	ok = _combo_box() and ok
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


static func _quest() -> bool:
	var script: GDScript = load(ROOT + "quest/quest_addon.gd")
	var resource_script: GDScript = load(ROOT + "quest_resource/quest_resource.gd")
	var gems: Resource = resource_script.new()
	gems.quest_id = "gems"
	gems.objectives = [{"name": "collect_gem", "needed": 5}]
	var hoard: Resource = resource_script.new()
	hoard.quest_id = "hoard"
	hoard.objectives = [{"name": "deliver", "needed": 1}]
	var quests: Node = script.new()
	quests.name = "Quests"
	quests.register_quest(gems)
	quests.start_quest(hoard)
	var advice: String = " (there are: gems, hoard) - start or register it first, or check the spelling."
	var rows: Array = []
	rows.append_array(_once("Advance Objective on a quest nobody registered", func() -> void: quests.advance_objective("gem", "collect_gem", 1),
		"Quests on Quests: Advance Objective did nothing, because no quest is called \"gem\"" + advice))
	rows.append_array(_once("Advance Objective on a quest not started", func() -> void: quests.advance_objective("gems", "collect_gem", 1),
		"Quests on Quests: Advance Objective did nothing, because the quest \"gems\" has not been started - Start Quest first."))
	rows.append_array(_once("Advance Objective on an objective it does not have", func() -> void: quests.advance_objective("hoard", "delivr", 1),
		"Quests on Quests: Advance Objective did nothing, because no objective is called \"delivr\" (there are: deliver) - check the spelling against the quest's objectives."))
	rows.append_array(_once("Abandon Quest", func() -> void: quests.abandon_quest("hord"),
		"Quests on Quests: Abandon Quest did nothing, because no quest is called \"hord\"" + advice))
	quests.advance_objective("hoard", "deliver", 1)
	rows.append(["a finished quest is advanced again without a word", _heard(func() -> void: quests.advance_objective("hoard", "deliver", 1)), []])
	rows.append(["abandoning a finished quest says nothing", _heard(func() -> void: quests.abandon_quest("hoard")), []])
	quests.free()
	return SUPPORT.pins(NAME, rows)


static func _proc_room() -> bool:
	var script: GDScript = load(ROOT + "proc_room/proc_room_addon.gd")
	var rooms: Node = script.new()
	rooms.name = "ProcRoom"
	var tail: String = " (none exist yet) - Generate makes the rooms, so run it first, or check the spelling."
	var rows: Array = []
	var actions: Array = [
		["Enter Room", "d9_9", func() -> void: rooms.enter_room("d9_9")],
		["Force Enter Room", "d9_8", func() -> void: rooms.force_enter_room("d9_8")],
		["Lock Room", "d9_7", func() -> void: rooms.lock_room("d9_7")],
		["Unlock Room", "d9_6", func() -> void: rooms.unlock_room("d9_6")],
		["Reveal Room", "d9_5", func() -> void: rooms.reveal_room("d9_5")],
	]
	for entry: Array in actions:
		rows.append_array(_once(str(entry[0]), entry[2],
			"ProcRoom on ProcRoom: %s did nothing, because no room is called \"%s\"%s" % [entry[0], entry[1], tail]))
	rooms.generate("seed", 3, 2)
	var heard: Array = _heard(func() -> void: rooms.enter_room("d0_9"))
	rows.append(["with a map, a wrong room is named and the real ones listed", str(heard[0]).begins_with(
		"ProcRoom on ProcRoom: Enter Room did nothing, because no room is called \"d0_9\" (there are: d0_0"), true])
	rows.append(["a real room says nothing", _heard(func() -> void: rooms.lock_room("d0_0")), []])
	rooms.free()
	return SUPPORT.pins(NAME, rows)


static func _utility_ai() -> bool:
	var script: GDScript = load(ROOT + "utility_ai/utility_ai_addon.gd")
	var brain: Node = script.new()
	brain.name = "Brain"
	brain.add_action("Attack", 0.0, true, 1.0)
	brain.add_action("Flee", 0.0, true, 1.0)
	var tail: String = " (there are: Attack, Flee) - add it with Add Action first, or check the spelling."
	var rows: Array = []
	var actions: Array = [
		["Add Consideration", "attak", func() -> void: brain.add_consideration("attak", "hp", "linear", 1.0, 0.5, 1.0)],
		["Set Action Enabled", "fle", func() -> void: brain.set_action_enabled("fle", false)],
		["Force Action", "run", func() -> void: brain.force_action("run")],
	]
	for entry: Array in actions:
		rows.append_array(_once(str(entry[0]), entry[2],
			"Utility Brain on Brain: %s did nothing, because no action is called \"%s\"%s" % [entry[0], entry[1], tail]))
	rows.append(["a real action says nothing", _heard(func() -> void: brain.set_action_enabled("Flee", true)), []])
	brain.free()
	return SUPPORT.pins(NAME, rows)


static func _milestones() -> bool:
	var script: GDScript = load(ROOT + "milestones/milestones_addon.gd")
	var marks: Node = script.new()
	marks.name = "Milestones"
	marks.define_milestone("first", 10.0, 1.0)
	var rows: Array = []
	for entry: Array in [
		["Set Threshold", "frist", func() -> void: marks.set_threshold("frist", 5.0)],
		["Update Progress", "secnd", func() -> void: marks.update_progress("secnd", 1.0)],
		["Force Reach", "thrid", func() -> void: marks.force_reach("thrid")],
	]:
		var listing: String = "first" if entry[1] == "frist" else ("first, frist" if entry[1] == "secnd" else "first, frist, secnd")
		rows.append_array(_once(str(entry[0]), entry[2],
			"Milestones on Milestones: %s made a new milestone \"%s\" with a target of 0 because none is called that (there are: %s) - use Define Milestone first, or check the spelling." % [entry[0], entry[1], listing]))
	rows.append(["a defined milestone says nothing", _heard(func() -> void: marks.update_progress("first", 3.0)), []])
	marks.free()
	return SUPPORT.pins(NAME, rows)


static func _stat_forge() -> bool:
	var script: GDScript = load(ROOT + "stat_forge/stat_forge_behavior.gd")
	var forge: Node = script.new()
	forge.name = "StatForge"
	forge.add_buff("haste", "speed", 1.5)
	var tail: String = " (there are: haste) - add it with Add Buff first, or check the spelling."
	var rows: Array = []
	var actions: Array = [
		["Set Buff Active", "hast", func() -> void: forge.set_buff_active("hast", false)],
		["Set Buff Value", "hste", func() -> void: forge.set_buff_value("hste", 2.0)],
		["Refresh Buff", "haist", func() -> void: forge.refresh_buff("haist", 3.0)],
		["Set Buff Timer Paused", "hsate", func() -> void: forge.set_buff_timer_paused("hsate", true)],
	]
	for entry: Array in actions:
		rows.append_array(_once(str(entry[0]), entry[2],
			"Stat Forge on StatForge: %s did nothing, because no buff is called \"%s\"%s" % [entry[0], entry[1], tail]))
	rows.append_array(_once("Re-Arm Threshold Rule", func() -> void: forge.rearm_threshold_rule("low_hp"),
		"Stat Forge on StatForge: Re-Arm Threshold Rule did nothing, because no threshold rule is called \"low_hp\" (none exist yet) - add it with Add Threshold Rule first, or check the spelling."))
	rows.append(["a real buff says nothing", _heard(func() -> void: forge.set_buff_active("haste", true)), []])
	rows.append(["Remove Buff stays quiet, since removing what is gone is its documented no-op", _heard(func() -> void: forge.remove_buff("gone")), []])
	forge.free()
	return SUPPORT.pins(NAME, rows)


static func _second_view() -> bool:
	var script: GDScript = load(ROOT + "second_view/second_view_addon.gd")
	var views: Node = script.new()
	views.name = "SecondView"
	var tail: String = " (none exist yet) - make it with Make A View first, or check the spelling."
	var rows: Array = []
	rows.append_array(_once("Show View In", func() -> void: views.show_view_in("minimp", null),
		"Second View on SecondView: Show View In did nothing, because no view is called \"minimp\"" + tail))
	rows.append_array(_once("Set View Zoom", func() -> void: views.set_view_zoom("minmap", 0.5),
		"Second View on SecondView: Set View Zoom did nothing, because no view is called \"minmap\"" + tail))
	views.free()
	return SUPPORT.pins(NAME, rows)


static func _combo_box() -> bool:
	var script: GDScript = load(ROOT + "combo_box/combo_box_addon.gd")
	var combos: Node = script.new()
	combos.name = "Combos"
	combos.register_combo("hadouken", "down,forward,punch", 0.5)
	var tail: String = " (there are: hadouken) - register it with Register Combo first, or check the spelling."
	var rows: Array = []
	var actions: Array = [
		["Set Combo Tags", "hadoken", func() -> void: combos.set_combo_tags("hadoken", "ground")],
		["Set Combo Priority", "hadouke", func() -> void: combos.set_combo_priority("hadouke", 2)],
		["Set Combo Strict", "hadkuen", func() -> void: combos.set_combo_strict("hadkuen", true)],
		["Enable Combo", "hadoukn", func() -> void: combos.enable_combo("hadoukn")],
		["Disable Combo", "hadouen", func() -> void: combos.disable_combo("hadouen")],
	]
	for entry: Array in actions:
		rows.append_array(_once(str(entry[0]), entry[2],
			"Combo Box on Combos: %s did nothing, because no combo is called \"%s\"%s" % [entry[0], entry[1], tail]))
	rows.append(["a real combo says nothing", _heard(func() -> void: combos.disable_combo("hadouken")), []])
	combos.free()
	return SUPPORT.pins(NAME, rows)
