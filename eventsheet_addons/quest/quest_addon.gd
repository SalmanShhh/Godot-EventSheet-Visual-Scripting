## @ace_tags(quest, objective, progression)
## @ace_category("Quest")
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/quest/icon.svg")
class_name QuestPackAddon
extends Node
## Quest and objective tracking as the Quests autoload singleton: start a quest from a QuestResource, count objectives up with Advance Objective, and react through On Objective Completed / On Quest Completed. Progress is clamped, completion is detected for you, and a quest that names a Next Quest chains into it automatically.

## @ace_trigger
## @ace_name("On Quest Started")
## @ace_category("Quest")
signal on_quest_started(quest_id: String)
## @ace_trigger
## @ace_name("On Objective Completed")
## @ace_category("Quest")
signal on_objective_completed(quest_id: String, objective: String)
## @ace_trigger
## @ace_name("On Quest Completed")
## @ace_category("Quest")
signal on_quest_completed(quest_id: String)

# quest_id -> {objective_name -> {done, needed}} - only quests being tracked right now.
var _active: Dictionary = {}
# The quest ids finished this run (or restored by Load Quests), in completion order.
var _completed: Array[String] = []
# quest_id -> {title, next, reward, objectives: Array of {name, needed}} - every QuestResource
# the pack has seen (Start Quest and Register Quest both remember one). The chain reads it, so a
# quest can only auto-start a Next Quest that was registered or started at least once.
var _library: Dictionary = {}

## @ace_action
## @ace_featured
## @ace_name("Start Quest")
## @ace_category("Quest")
## @ace_description("Begins a quest from a Quest resource (a .tres you filled in the Inspector): every objective starts at 0 and On Quest Started fires. Starting a quest again resets its progress.")
## @ace_display_template("Start quest [b]{quest}[/b]")
## @ace_icon("res://eventsheet_addons/quest/icon.svg")
## @ace_codegen_template("Quests.start_quest({quest})")
func start_quest(quest: Resource) -> void:
	var quest_id: String = _remember(quest)
	if quest_id.is_empty():
		return
	_begin(quest_id)

## @ace_action
## @ace_name("Register Quest")
## @ace_category("Quest")
## @ace_description("Teaches the tracker a quest WITHOUT starting it, so another quest can chain into it through its Next Quest field (and so Quest Title / Quest Reward Note can read it). Register the later quests of a questline once at startup.")
## @ace_icon("res://eventsheet_addons/quest/icon.svg")
## @ace_codegen_template("Quests.register_quest({quest})")
func register_quest(quest: Resource) -> void:
	_remember(quest)

## @ace_action
## @ace_featured
## @ace_name("Advance Objective")
## @ace_category("Quest")
## @ace_description("Counts progress on one objective of an active quest. Progress stops at the needed count, so an extra call can never double-fire: On Objective Completed fires the moment it fills, and once every objective is full the quest completes (On Quest Completed) and its Next Quest starts automatically.")
## @ace_display_template("Advance [b]{objective}[/b] on quest [b]{quest_id}[/b] by [b]{amount}[/b]")
## @ace_icon("res://eventsheet_addons/quest/icon.svg")
## @ace_codegen_template("Quests.advance_objective({quest_id}, {objective}, {amount})")
func advance_objective(quest_id: String, objective: String, amount: int) -> void:
	if not _active.has(quest_id):
		return
	var goals: Dictionary = _active[quest_id]
	if not goals.has(objective):
		return
	var goal: Dictionary = goals[objective]
	if int(goal.done) >= int(goal.needed):
		return
	goal.done = mini(int(goal.done) + maxi(amount, 0), int(goal.needed))
	if int(goal.done) < int(goal.needed):
		return
	on_objective_completed.emit(quest_id, objective)
	if _all_done(quest_id):
		_finish(quest_id)

## @ace_action
## @ace_name("Abandon Quest")
## @ace_category("Quest")
## @ace_description("Drops an active quest and forgets its progress. It does NOT count as completed, and no trigger fires - start it again to try over.")
## @ace_display_template("Abandon quest [b]{quest_id}[/b]")
## @ace_icon("res://eventsheet_addons/quest/icon.svg")
## @ace_codegen_template("Quests.abandon_quest({quest_id})")
func abandon_quest(quest_id: String) -> void:
	_active.erase(quest_id)

## @ace_action
## @ace_name("Reset All Quests")
## @ace_category("Quest")
## @ace_description("Clears every active quest and the completed list (e.g. on New Game). Registered quest definitions are kept, so a chain still works.")
## @ace_icon("res://eventsheet_addons/quest/icon.svg")
## @ace_codegen_template("Quests.reset_quests()")
func reset_quests() -> void:
	_active.clear()
	_completed.clear()

## @ace_action
## @ace_name("Save Quests")
## @ace_category("Quest")
## @ace_description("Writes the active quests and the completed list into user://remembered.cfg (the same file the Remember Between Runs variable option uses) under a "Quests" section. Call it when the player saves or the level ends.")
## @ace_icon("res://eventsheet_addons/quest/icon.svg")
## @ace_codegen_template("Quests.save_quests()")
func save_quests() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.load("user://remembered.cfg")
	config.set_value("Quests", "active", _active.duplicate(true))
	config.set_value("Quests", "completed", Array(_completed))
	config.save("user://remembered.cfg")

## @ace_action
## @ace_name("Load Quests")
## @ace_category("Quest")
## @ace_description("Reads the active quests and the completed list back out of user://remembered.cfg (the Remember Between Runs store), replacing whatever is tracked now. Nothing happens if there is no save yet. Register your quest resources first if you want chains to keep working.")
## @ace_icon("res://eventsheet_addons/quest/icon.svg")
## @ace_codegen_template("Quests.load_quests()")
func load_quests() -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load("user://remembered.cfg") != OK:
		return
	_active = (config.get_value("Quests", "active", {}) as Dictionary).duplicate(true)
	_completed.clear()
	for quest_id: Variant in (config.get_value("Quests", "completed", []) as Array):
		_completed.append(str(quest_id))

## @ace_condition
## @ace_name("Quest Is Active")
## @ace_category("Quest")
## @ace_description("Whether this quest is being tracked right now (started, not yet completed or abandoned).")
## @ace_icon("res://eventsheet_addons/quest/icon.svg")
## @ace_codegen_template("Quests.quest_is_active({quest_id})")
func quest_is_active(quest_id: String) -> bool:
	return _active.has(quest_id)

## @ace_condition
## @ace_name("Quest Is Completed")
## @ace_category("Quest")
## @ace_description("Whether this quest has been finished (every objective filled).")
## @ace_icon("res://eventsheet_addons/quest/icon.svg")
## @ace_codegen_template("Quests.quest_is_completed({quest_id})")
func quest_is_completed(quest_id: String) -> bool:
	return _completed.has(quest_id)

## @ace_condition
## @ace_name("Objective Is Done")
## @ace_category("Quest")
## @ace_description("Whether one objective of an active quest has reached its needed count.")
## @ace_icon("res://eventsheet_addons/quest/icon.svg")
## @ace_codegen_template("Quests.objective_is_done({quest_id}, {objective})")
func objective_is_done(quest_id: String, objective: String) -> bool:
	var goals: Dictionary = _active.get(quest_id, {})
	if not goals.has(objective):
		return false
	return int(goals[objective].done) >= int(goals[objective].needed)

## @ace_expression
## @ace_name("Objective Text")
## @ace_category("Quest")
## @ace_description("An objective's progress as readable text, e.g. "3/5" - drop it straight into a quest-log label. "" if the quest is not active or has no such objective.")
## @ace_icon("res://eventsheet_addons/quest/icon.svg")
## @ace_codegen_template("Quests.objective_text({quest_id}, {objective})")
func objective_text(quest_id: String, objective: String) -> String:
	var goals: Dictionary = _active.get(quest_id, {})
	if not goals.has(objective):
		return ""
	return "%d/%d" % [int(goals[objective].done), int(goals[objective].needed)]

## @ace_expression
## @ace_name("Objective Progress")
## @ace_category("Quest")
## @ace_description("An objective's progress as 0-1 - feed it straight to a progress bar's Progress Of. 0 if the quest is not active or has no such objective.")
## @ace_icon("res://eventsheet_addons/quest/icon.svg")
## @ace_codegen_template("Quests.objective_progress({quest_id}, {objective})")
func objective_progress(quest_id: String, objective: String) -> float:
	var goals: Dictionary = _active.get(quest_id, {})
	if not goals.has(objective):
		return 0.0
	return clampf(float(goals[objective].done) / maxf(float(goals[objective].needed), 1.0), 0.0, 1.0)

## @ace_expression
## @ace_name("Active Quest Count")
## @ace_category("Quest")
## @ace_description("How many quests are being tracked right now.")
## @ace_icon("res://eventsheet_addons/quest/icon.svg")
## @ace_codegen_template("Quests.active_quest_count()")
func active_quest_count() -> int:
	return _active.size()

## @ace_expression
## @ace_name("Completed Quest Count")
## @ace_category("Quest")
## @ace_description("How many quests have been finished.")
## @ace_icon("res://eventsheet_addons/quest/icon.svg")
## @ace_codegen_template("Quests.completed_quest_count()")
func completed_quest_count() -> int:
	return _completed.size()

## @ace_expression
## @ace_name("Quest Title")
## @ace_category("Quest")
## @ace_description("The player-facing title of a started or registered quest ("" if the tracker has never seen it).")
## @ace_icon("res://eventsheet_addons/quest/icon.svg")
## @ace_codegen_template("Quests.quest_title({quest_id})")
func quest_title(quest_id: String) -> String:
	return str((_library.get(quest_id, {}) as Dictionary).get("title", ""))

## @ace_expression
## @ace_name("Quest Reward Note")
## @ace_category("Quest")
## @ace_description("The reward note written on the quest resource - show it in your log and hand the reward out yourself in On Quest Completed.")
## @ace_icon("res://eventsheet_addons/quest/icon.svg")
## @ace_codegen_template("Quests.quest_reward_note({quest_id})")
func quest_reward_note(quest_id: String) -> String:
	return str((_library.get(quest_id, {}) as Dictionary).get("reward", ""))

func _field(quest: Resource, key: String) -> String:
	# One field off a QuestResource as text. Object.get returns null for a property the resource does
	# not have, and str(null) would read as "<null>" - a blank is what a missing field means here.
	var value: Variant = quest.get(key)
	return "" if value == null else str(value)

func _remember(quest: Resource) -> String:
	# Copies a QuestResource into the library and returns its id ("" when there is nothing usable).
	# Purely a read of the asset - it never starts anything.
	if quest == null:
		push_warning("Quests: was given no quest resource.")
		return ""
	var quest_id: String = _field(quest, "quest_id")
	if quest_id.is_empty():
		push_warning("Quests: a quest resource has a blank quest_id and cannot be tracked.")
		return ""
	var goals: Array = []
	var rows: Variant = quest.get("objectives")
	if rows is Array:
		for row: Variant in (rows as Array):
			if not (row is Dictionary):
				continue
			var goal_name: String = str((row as Dictionary).get("name", ""))
			if goal_name.is_empty():
				continue
			goals.append({"name": goal_name, "needed": maxi(int((row as Dictionary).get("needed", 1)), 1)})
	_library[quest_id] = {
		"title": _field(quest, "title"),
		"next": _field(quest, "next_quest"),
		"reward": _field(quest, "reward_note"),
		"objectives": goals
	}
	return quest_id

func _begin(quest_id: String) -> void:
	# Puts a remembered quest into the active list with every objective at 0 and fires its trigger.
	# Restarting a completed quest takes it back off the completed list, so the two never overlap.
	if not _library.has(quest_id):
		push_warning("Quests: no quest named '%s' is registered - start it or register it first." % quest_id)
		return
	var goals: Dictionary = {}
	for goal: Dictionary in (_library[quest_id] as Dictionary).objectives:
		goals[str(goal.name)] = {"done": 0, "needed": maxi(int(goal.needed), 1)}
	_active[quest_id] = goals
	_completed.erase(quest_id)
	on_quest_started.emit(quest_id)

func _all_done(quest_id: String) -> bool:
	# Whether every objective of an ACTIVE quest has reached its needed count.
	for goal_name: String in (_active[quest_id] as Dictionary):
		var goal: Dictionary = _active[quest_id][goal_name]
		if int(goal.done) < int(goal.needed):
			return false
	return true

func _finish(quest_id: String) -> void:
	# Finishes an active quest: moves it to completed, fires the trigger, then chains into the
	# resource's Next Quest when it named one.
	_active.erase(quest_id)
	if not _completed.has(quest_id):
		_completed.append(quest_id)
	on_quest_completed.emit(quest_id)
	var next_id: String = str((_library.get(quest_id, {}) as Dictionary).get("next", ""))
	if not next_id.is_empty():
		_begin(next_id)

## @ace_hidden
func save_state() -> Dictionary:
	# Save-state seam: the Save System walks any node in its persist group (or targeted
	# by Save/Load Node State) and duck-types these two methods. Plain data only.
	# The library is NOT part of the snapshot - it is rebuilt by starting or registering the
	# quest resources, which live in the project rather than in the save.
	return {
		"active": _active.duplicate(true),
		"completed": Array(_completed)
	}

## @ace_hidden
func load_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	_active = (state.get("active", {}) as Dictionary).duplicate(true)
	_completed.clear()
	for quest_id: Variant in (state.get("completed", []) as Array):
		_completed.append(str(quest_id))

# Quest: register as the Quests autoload. Author each quest as a QuestResource (.tres) in the Inspector, Start Quest to begin it, Advance Objective to count progress, and react with On Objective Completed / On Quest Completed. Save Quests and Load Quests carry the state between runs. This pack is an event sheet - extend it by editing it.
