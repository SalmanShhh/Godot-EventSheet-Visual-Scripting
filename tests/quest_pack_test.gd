# Godot EventSheets - Quest pack runtime behaviour.
#
# Loads the COMPILED Quests autoload pack and drives it treeless (signals still emit on a bare
# instance, so the triggers are counted for real): starting a quest from a QuestResource, counting an
# objective up, the completion sweep, the clamp that stops a double trigger, abandoning, the Next
# Quest chain, and the user://remembered.cfg round-trip into a FRESH instance.
@tool
class_name QuestPackTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const PACK := "res://eventsheet_addons/quest/quest_addon.gd"
const RESOURCE_PACK := "res://eventsheet_addons/quest_resource/quest_resource.gd"
const REMEMBER_PATH := "user://remembered.cfg"


static func run() -> bool:
	var all_passed: bool = true
	var script: GDScript = load(PACK)
	all_passed = _check("quest pack loads + parses", script != null, true) and all_passed
	var resource_script: GDScript = load(RESOURCE_PACK)
	all_passed = _check("quest resource pack loads + parses", resource_script != null, true) and all_passed
	if script == null or resource_script == null:
		return all_passed

	# Two quests: a 5-gem hunt that chains into a one-step delivery.
	var gem_quest: Resource = resource_script.new()
	gem_quest.quest_id = "gems"
	gem_quest.title = "Gem Hunt"
	gem_quest.objectives = [{"name": "collect_gem", "needed": 5}]
	gem_quest.next_quest = "hoard"
	gem_quest.reward_note = "200 gold"
	var hoard_quest: Resource = resource_script.new()
	hoard_quest.quest_id = "hoard"
	hoard_quest.title = "Hand It In"
	hoard_quest.objectives = [{"name": "deliver", "needed": 1}]

	var quests: Node = script.new()
	var seen: Dictionary = {"started": [], "objective": [], "completed": []}
	quests.on_quest_started.connect(func(quest_id: String) -> void: (seen.started as Array).append(quest_id))
	quests.on_objective_completed.connect(func(quest_id: String, objective: String) -> void: (seen.objective as Array).append("%s/%s" % [quest_id, objective]))
	quests.on_quest_completed.connect(func(quest_id: String) -> void: (seen.completed as Array).append(quest_id))

	# --- Start ---
	quests.register_quest(hoard_quest)
	quests.start_quest(gem_quest)
	all_passed = _check("started quest is active", quests.quest_is_active("gems"), true) and all_passed
	all_passed = _check("On Quest Started fired for it", seen.started, ["gems"]) and all_passed
	all_passed = _check("a fresh objective reads 0/5", quests.objective_text("gems", "collect_gem"), "0/5") and all_passed
	all_passed = _check("the quest title comes off the resource", quests.quest_title("gems"), "Gem Hunt") and all_passed
	all_passed = _check("the reward note comes off the resource", quests.quest_reward_note("gems"), "200 gold") and all_passed
	all_passed = _check("registering did not start the second quest", quests.quest_is_active("hoard"), false) and all_passed

	# --- Partial progress ---
	for _i: int in 4:
		quests.advance_objective("gems", "collect_gem", 1)
	all_passed = _check("four advances read 4/5", quests.objective_text("gems", "collect_gem"), "4/5") and all_passed
	all_passed = _check("progress is 0.8 of the way", is_equal_approx(quests.objective_progress("gems", "collect_gem"), 0.8), true) and all_passed
	all_passed = _check("an unfilled objective has not completed", seen.objective, []) and all_passed
	all_passed = _check("an unfinished quest has not completed", seen.completed, []) and all_passed
	all_passed = _check("Objective Is Done is false while short", quests.objective_is_done("gems", "collect_gem"), false) and all_passed

	# --- The advance that finishes it ---
	quests.advance_objective("gems", "collect_gem", 1)
	all_passed = _check("On Objective Completed fired once", seen.objective, ["gems/collect_gem"]) and all_passed
	all_passed = _check("On Quest Completed fired once", seen.completed, ["gems"]) and all_passed
	all_passed = _check("the finished quest left the active list", quests.quest_is_active("gems"), false) and all_passed
	all_passed = _check("the finished quest counts as completed", quests.quest_is_completed("gems"), true) and all_passed
	all_passed = _check("the Next Quest auto-started", quests.quest_is_active("hoard"), true) and all_passed
	all_passed = _check("the chain fired On Quest Started too", seen.started, ["gems", "hoard"]) and all_passed
	all_passed = _check("only the chained quest is active", quests.active_quest_count(), 1) and all_passed

	# --- Over-advance is clamped ---
	quests.advance_objective("gems", "collect_gem", 3)
	all_passed = _check("advancing a finished quest fires nothing", seen.objective, ["gems/collect_gem"]) and all_passed
	quests.advance_objective("hoard", "deliver", 9)
	all_passed = _check("an over-sized advance still completes once", seen.completed, ["gems", "hoard"]) and all_passed
	all_passed = _check("the completed quest stopped reporting objective text", quests.objective_text("hoard", "deliver"), "") and all_passed
	quests.advance_objective("hoard", "deliver", 9)
	all_passed = _check("advancing again does not double-fire the objective", seen.objective, ["gems/collect_gem", "hoard/deliver"]) and all_passed
	all_passed = _check("advancing again does not double-fire the quest", seen.completed, ["gems", "hoard"]) and all_passed
	all_passed = _check("nothing is active once both are done", quests.active_quest_count(), 0) and all_passed

	# --- Restart resets progress; abandon drops it ---
	quests.start_quest(gem_quest)
	all_passed = _check("restarting a quest resets its objective", quests.objective_text("gems", "collect_gem"), "0/5") and all_passed
	all_passed = _check("restarting takes it back off the completed list", quests.quest_is_completed("gems"), false) and all_passed
	quests.advance_objective("gems", "collect_gem", 2)
	quests.abandon_quest("gems")
	all_passed = _check("an abandoned quest is no longer active", quests.quest_is_active("gems"), false) and all_passed
	all_passed = _check("an abandoned quest did not complete", quests.quest_is_completed("gems"), false) and all_passed
	all_passed = _check("abandoning fired no completion trigger", seen.completed, ["gems", "hoard"]) and all_passed

	# --- Save, then load into a FRESH instance ---
	quests.reset_quests()
	all_passed = _check("Reset All Quests empties the completed list", quests.completed_quest_count(), 0) and all_passed
	quests.start_quest(gem_quest)
	quests.advance_objective("gems", "collect_gem", 3)
	quests.start_quest(hoard_quest)
	quests.advance_objective("hoard", "deliver", 1)
	all_passed = _check("the saved state has one quest mid-flight", quests.objective_text("gems", "collect_gem"), "3/5") and all_passed
	quests.save_quests()

	var restored: Node = script.new()
	restored.load_quests()
	all_passed = _check("the active quest is restored", restored.quest_is_active("gems"), true) and all_passed
	all_passed = _check("its objective progress is restored", restored.objective_text("gems", "collect_gem"), "3/5") and all_passed
	all_passed = _check("its progress fraction is restored", is_equal_approx(restored.objective_progress("gems", "collect_gem"), 0.6), true) and all_passed
	all_passed = _check("the completed quest is restored", restored.quest_is_completed("hoard"), true) and all_passed
	all_passed = _check("exactly one quest is active after the load", restored.active_quest_count(), 1) and all_passed
	all_passed = _check("exactly one quest is completed after the load", restored.completed_quest_count(), 1) and all_passed

	all_passed = _check("the Quest guide ships", FileAccess.file_exists("res://docs/Addons/Quest.md"), true) and all_passed

	_forget_saved_quests()
	restored.free()
	quests.free()
	return all_passed


## Leaves the shared Remember Between Runs file as it was found, so this test cannot colour any
## other test (or a later run of itself) through user://remembered.cfg.
static func _forget_saved_quests() -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load(REMEMBER_PATH) != OK or not config.has_section("Quests"):
		return
	config.erase_section("Quests")
	config.save(REMEMBER_PATH)


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("quest_pack_test", label, actual, expected)
