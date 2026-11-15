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
## Registered milestones by id, each with its target and whether it has been reached.
var _milestones: Dictionary = {}
# The milestone that just latched (read inside On Milestone Reached).
## Id of the milestone reached most recently.
var _last_reached_id: String = ""
## Names this node has already said it could not find, so a row that runs every frame says it once.
var _said_missing: Dictionary = {}

## @ace_action
## @ace_featured
## @ace_name("Define Milestone")
## @ace_category("Milestones")
## @ace_description("Creates (or resets) a milestone: the threshold to cross and the reward it grants once reached.")
## @ace_display_template("Define milestone [b]{id}[/b] at [b]{threshold}[/b] rewarding [b]{reward}[/b]")
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
	_ensure(id, "Set Threshold").threshold = threshold

## @ace_action
## @ace_featured
## @ace_name("Update Progress")
## @ace_category("Milestones")
## @ace_description("Reports the current value of the tracked number. The first time it reaches the threshold the milestone latches and On Milestone Reached fires (read Last Reached / Reward there).")
## @ace_display_template("Update [b]{id}[/b] progress to [b]{value}[/b]")
## @ace_icon("res://eventsheet_addons/milestones/icon.svg")
## @ace_codegen_template("Milestones.update_progress({id}, {value})")
func update_progress(id: String, value: float) -> void:
	var record: Dictionary = _ensure(id, "Update Progress")
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
	var record: Dictionary = _ensure(id, "Force Reach")
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

func _ensure(id: String, action: String = "") -> Dictionary:
	if not _milestones.has(id):
		if not action.is_empty():
			_say_once("milestone:" + id, "%s made a new milestone \"%s\" with a target of 0 because none is called that (%s) - use Define Milestone first, or check the spelling." % [action, id, _list_names(_milestones.keys())])
		_milestones[id] = {"threshold": 0.0, "reward": 0.0, "reached": false, "value": 0.0}
	return _milestones[id]

## Warns once per key that a row could not do what it was asked; the row itself does nothing more.
func _say_once(key: String, sentence: String) -> void:
	if _said_missing.has(key):
		return
	_said_missing[key] = true
	var where: String = str(get_path()) if is_inside_tree() else str(name)
	push_warning("Milestones on %s: %s" % [where, sentence])

## The names a row could have meant, as a phrase: the first eight, sorted, or that none exist yet.
func _list_names(known: Array) -> String:
	var names: PackedStringArray = PackedStringArray()
	for each: Variant in known:
		names.append(str(each))
	names.sort()
	if names.is_empty():
		return "none exist yet"
	return "there are: " + ", ".join(names.slice(0, 8)) + (", and more" if names.size() > 8 else "")

## Warns once per missing name that a row was given a name nothing here answers to, and lists the names that do exist.
func _say_missing(action: String, what: String, wrong: String, known: Array, advice: String) -> void:
	if _said_missing.has(what + ":" + wrong):
		return
	_say_once(what + ":" + wrong, "%s did nothing, because no %s is called \"%s\" (%s) - %s." % [action, what, wrong, _list_names(known), advice])

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
