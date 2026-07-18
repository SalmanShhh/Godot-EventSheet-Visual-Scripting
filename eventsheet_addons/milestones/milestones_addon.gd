## @ace_tags(incremental, idle, achievement)
## @ace_category("Milestones")
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/milestones/icon.svg")
class_name MilestonesAddon
extends Node
## A threshold-achievement engine for incremental games, shipped as the Milestones autoload. Define milestones by id with a threshold and a reward, report the tracked number to Update Progress as it changes, and each milestone latches reached and fires a trigger once - Total Reward sums every reached reward into one number you fold into your production multiplier.

## @ace_trigger
## @ace_name("On Milestone Reached")
## @ace_category("Milestones")
signal on_milestone_reached

# id -> {threshold, reward, reached, value (last reported)}.
var _milestones: Dictionary = {}
# The milestone that just latched (read inside On Milestone Reached).
var _last_reached_id: String = ""

## @ace_action
## @ace_featured
## @ace_name("Define Milestone")
## @ace_category("Milestones")
## @ace_description("Creates (or resets) a milestone: the threshold to cross and the reward it grants once reached.")
## @ace_icon("res://eventsheet_addons/milestones/icon.svg")
## @ace_codegen_template("Milestones.define_milestone({id}, {threshold}, {reward})")
func define_milestone(id: String, threshold: float, reward: float) -> void:
	_milestones[id] = {"threshold": threshold, "reward": reward, "reached": false, "value": 0.0}

## @ace_action
## @ace_name("Set Threshold")
## @ace_category("Milestones")
## @ace_description("Changes a milestone's threshold (does not un-reach it if already reached).")
## @ace_icon("res://eventsheet_addons/milestones/icon.svg")
## @ace_codegen_template("Milestones.set_threshold({id}, {threshold})")
func set_threshold(id: String, threshold: float) -> void:
	_ensure(id).threshold = threshold

## @ace_action
## @ace_featured
## @ace_name("Update Progress")
## @ace_category("Milestones")
## @ace_description("Reports the current value of the tracked number. The first time it reaches the threshold the milestone latches and On Milestone Reached fires (read Last Reached / Reward there).")
## @ace_icon("res://eventsheet_addons/milestones/icon.svg")
## @ace_codegen_template("Milestones.update_progress({id}, {value})")
func update_progress(id: String, value: float) -> void:
	var record: Dictionary = _ensure(id)
	record.value = value
	if not record.reached and value >= float(record.threshold):
		record.reached = true
		_last_reached_id = id
		on_milestone_reached.emit()

## @ace_action
## @ace_name("Force Reach")
## @ace_category("Milestones")
## @ace_description("Marks a milestone reached immediately (for a load) - fires On Milestone Reached if it was not already reached.")
## @ace_icon("res://eventsheet_addons/milestones/icon.svg")
## @ace_codegen_template("Milestones.force_reach({id})")
func force_reach(id: String) -> void:
	var record: Dictionary = _ensure(id)
	if not record.reached:
		record.reached = true
		_last_reached_id = id
		on_milestone_reached.emit()

## @ace_action
## @ace_name("Reset")
## @ace_category("Milestones")
## @ace_description("Un-reaches every milestone and zeroes progress (keeps the definitions).")
## @ace_icon("res://eventsheet_addons/milestones/icon.svg")
## @ace_codegen_template("Milestones.reset_milestones()")
func reset_milestones() -> void:
	for id: String in _milestones:
		_milestones[id].reached = false
		_milestones[id].value = 0.0

## @ace_condition
## @ace_name("Is Reached")
## @ace_category("Milestones")
## @ace_description("Whether a milestone has been reached.")
## @ace_icon("res://eventsheet_addons/milestones/icon.svg")
## @ace_codegen_template("Milestones.is_reached({id})")
func is_reached(id: String) -> bool:
	return _milestones.has(id) and bool(_milestones[id].reached)

## @ace_expression
## @ace_name("Progress")
## @ace_category("Milestones")
## @ace_description("How close a milestone is, 0 to 1 (for a progress bar).")
## @ace_icon("res://eventsheet_addons/milestones/icon.svg")
## @ace_codegen_template("Milestones.progress({id})")
func progress(id: String) -> float:
	if not _milestones.has(id):
		return 0.0
	var record: Dictionary = _milestones[id]
	# A reached milestone is permanent - stay at full even if the tracked value later drops
	# (e.g. "reach 1000 gold" then the player spends it).
	if bool(record.reached):
		return 1.0
	if float(record.threshold) <= 0.0:
		return 1.0
	return clampf(float(record.value) / float(record.threshold), 0.0, 1.0)

## @ace_expression
## @ace_name("Threshold")
## @ace_category("Milestones")
## @ace_description("A milestone's threshold value.")
## @ace_icon("res://eventsheet_addons/milestones/icon.svg")
## @ace_codegen_template("Milestones.threshold_of({id})")
func threshold_of(id: String) -> float:
	return float(_milestones[id].threshold) if _milestones.has(id) else 0.0

## @ace_expression
## @ace_name("Reward")
## @ace_category("Milestones")
## @ace_description("A milestone's reward value.")
## @ace_icon("res://eventsheet_addons/milestones/icon.svg")
## @ace_codegen_template("Milestones.reward_of({id})")
func reward_of(id: String) -> float:
	return float(_milestones[id].reward) if _milestones.has(id) else 0.0

## @ace_expression
## @ace_name("Reached Count")
## @ace_category("Milestones")
## @ace_description("How many milestones have been reached.")
## @ace_icon("res://eventsheet_addons/milestones/icon.svg")
## @ace_codegen_template("Milestones.reached_count()")
func reached_count() -> int:
	var count: int = 0
	for id: String in _milestones:
		if bool(_milestones[id].reached):
			count += 1
	return count

## @ace_expression
## @ace_name("Milestone Count")
## @ace_category("Milestones")
## @ace_description("How many milestones are defined.")
## @ace_icon("res://eventsheet_addons/milestones/icon.svg")
## @ace_codegen_template("Milestones.milestone_count()")
func milestone_count() -> int:
	return _milestones.size()

## @ace_expression
## @ace_name("Total Reward")
## @ace_category("Milestones")
## @ace_description("The sum of the rewards of every reached milestone - fold this into your production multiplier.")
## @ace_icon("res://eventsheet_addons/milestones/icon.svg")
## @ace_codegen_template("Milestones.total_reward()")
func total_reward() -> float:
	var total: float = 0.0
	for id: String in _milestones:
		if bool(_milestones[id].reached):
			total += float(_milestones[id].reward)
	return total

## @ace_expression
## @ace_name("Last Reached")
## @ace_category("Milestones")
## @ace_description("The id of the milestone that just latched (read inside On Milestone Reached).")
## @ace_icon("res://eventsheet_addons/milestones/icon.svg")
## @ace_codegen_template("Milestones.last_reached()")
func last_reached() -> String:
	return _last_reached_id

## @ace_expression
## @ace_name("Nearest Unreached")
## @ace_category("Milestones")
## @ace_description("The id of the unreached milestone closest to its threshold (for a "next goal" display); "" if all reached.")
## @ace_icon("res://eventsheet_addons/milestones/icon.svg")
## @ace_codegen_template("Milestones.nearest_unreached()")
func nearest_unreached() -> String:
	var best_id: String = ""
	var best_ratio: float = -1.0
	for id: String in _milestones:
		var record: Dictionary = _milestones[id]
		if bool(record.reached):
			continue
		var ratio: float = float(record.value) / float(record.threshold) if float(record.threshold) > 0.0 else 1.0
		if ratio > best_ratio:
			best_ratio = ratio
			best_id = id
	return best_id

func _ensure(id: String) -> Dictionary:
	if not _milestones.has(id):
		_milestones[id] = {"threshold": 0.0, "reward": 0.0, "reached": false, "value": 0.0}
	return _milestones[id]

## @ace_hidden
func save_state() -> Dictionary:
	# Save-state seam: the Save System walks any node in its persist group (or targeted
	# by Save/Load Node State) and duck-types these two methods. Plain data only.
	# The whole dict is saved (definitions + reached flags + last values); a later Define
	# Milestone on ready resets that entry, so sheets should Define BEFORE loading.
	return {
		"milestones": _milestones.duplicate(true)
	}

## @ace_hidden
func load_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	_milestones = (state.get("milestones", {}) as Dictionary).duplicate(true)

# Milestones: register as the Milestones autoload. Define Milestone(id, threshold, reward), then Update Progress(id, value) as the tracked number grows. Crossing the threshold latches the milestone reached and fires On Milestone Reached once. Total Reward adds up every reached milestone's reward so the achievements grant a real, permanent bonus. This pack is an event sheet - extend it by editing it.
