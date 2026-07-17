# Pack builder - milestones (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## Milestones: threshold achievements that also GRANT a permanent reward, as an AUTOLOAD sheet - the "reach
## a million cookies for +5% forever" loop. Define a milestone by id with a threshold and a reward value,
## then Update Progress(id, current_value) wherever the tracked number changes; the first time it crosses
## the threshold the milestone latches reached and fires On Milestone Reached. Total Reward sums the reward
## of every reached milestone into one number you fold into your multiplier - so the achievements actually
## make the player stronger, not just light up. Plain Godot, zero plugin dependency.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.autoload_mode = true
	sheet.autoload_name = "Milestones"
	sheet.host_class = "Node"
	sheet.custom_class_name = "MilestonesAddon"
	sheet.class_description = "A threshold-achievement engine for incremental games, shipped as the Milestones autoload. Define milestones by id with a threshold and a reward, report the tracked number to Update Progress as it changes, and each milestone latches reached and fires a trigger once - Total Reward sums every reached reward into one number you fold into your production multiplier."
	sheet.addon_category = "Milestones"
	sheet.addon_tags = PackedStringArray(["incremental", "idle", "achievement"])
	var about: CommentRow = CommentRow.new()
	about.text = "Milestones: register as the Milestones autoload. Define Milestone(id, threshold, reward), then Update Progress(id, value) as the tracked number grows. Crossing the threshold latches the milestone reached and fires On Milestone Reached once. Total Reward adds up every reached milestone's reward so the achievements grant a real, permanent bonus. This pack is an event sheet - extend it by editing it."
	sheet.events.append(about)

	var block: RawCodeRow = RawCodeRow.new()
	block.code = "\n".join(PackedStringArray([
		"## @ace_trigger",
		"## @ace_name(\"On Milestone Reached\")",
		"## @ace_category(\"Milestones\")",
		"signal on_milestone_reached",
		"",
		"# id -> {threshold, reward, reached, value (last reported)}.",
		"var _milestones: Dictionary = {}",
		"# The milestone that just latched (read inside On Milestone Reached).",
		"var _last_reached_id: String = \"\"",
		"",
		"func _ensure(id: String) -> Dictionary:",
		"\tif not _milestones.has(id):",
		"\t\t_milestones[id] = {\"threshold\": 0.0, \"reward\": 0.0, \"reached\": false, \"value\": 0.0}",
		"\treturn _milestones[id]"
	]))
	sheet.events.append(block)

	# --- Setup ---
	Lib.append_function(sheet, "define_milestone", "Define Milestone", "Milestones", "Creates (or resets) a milestone: the threshold to cross and the reward it grants once reached.",
		[["id", "String"], ["threshold", "float"], ["reward", "float"]], "\n".join(PackedStringArray([
			"_milestones[id] = {\"threshold\": threshold, \"reward\": reward, \"reached\": false, \"value\": 0.0}"
		])))
	Lib.append_function(sheet, "set_threshold", "Set Threshold", "Milestones", "Changes a milestone's threshold (does not un-reach it if already reached).",
		[["id", "String"], ["threshold", "float"]],
		"_ensure(id).threshold = threshold")

	# --- Reporting progress ---
	Lib.append_function(sheet, "update_progress", "Update Progress", "Milestones", "Reports the current value of the tracked number. The first time it reaches the threshold the milestone latches and On Milestone Reached fires (read Last Reached / Reward there).",
		[["id", "String"], ["value", "float"]], "\n".join(PackedStringArray([
			"var record: Dictionary = _ensure(id)",
			"record.value = value",
			"if not record.reached and value >= float(record.threshold):",
			"\trecord.reached = true",
			"\t_last_reached_id = id",
			"\ton_milestone_reached.emit()"
		])))
	Lib.append_function(sheet, "force_reach", "Force Reach", "Milestones", "Marks a milestone reached immediately (for a load) - fires On Milestone Reached if it was not already reached.",
		[["id", "String"]], "\n".join(PackedStringArray([
			"var record: Dictionary = _ensure(id)",
			"if not record.reached:",
			"\trecord.reached = true",
			"\t_last_reached_id = id",
			"\ton_milestone_reached.emit()"
		])))
	Lib.append_function(sheet, "reset_milestones", "Reset", "Milestones", "Un-reaches every milestone and zeroes progress (keeps the definitions).",
		[], "\n".join(PackedStringArray([
			"for id: String in _milestones:",
			"\t_milestones[id].reached = false",
			"\t_milestones[id].value = 0.0"
		])))

	# --- Conditions ---
	Lib.condition(sheet, "is_reached", "Is Reached", "Milestones", "Whether a milestone has been reached.",
		[["id", "String"]],
		"return _milestones.has(id) and bool(_milestones[id].reached)")

	# --- Expressions ---
	Lib.number(sheet, "progress", "Progress", "Milestones", "How close a milestone is, 0 to 1 (for a progress bar).",
		[["id", "String"]], "\n".join(PackedStringArray([
			"if not _milestones.has(id):",
			"\treturn 0.0",
			"var record: Dictionary = _milestones[id]",
			"# A reached milestone is permanent - stay at full even if the tracked value later drops",
			"# (e.g. \"reach 1000 gold\" then the player spends it).",
			"if bool(record.reached):",
			"\treturn 1.0",
			"if float(record.threshold) <= 0.0:",
			"\treturn 1.0",
			"return clampf(float(record.value) / float(record.threshold), 0.0, 1.0)"
		])), TYPE_FLOAT)
	Lib.number(sheet, "threshold_of", "Threshold", "Milestones", "A milestone's threshold value.",
		[["id", "String"]], "return float(_milestones[id].threshold) if _milestones.has(id) else 0.0", TYPE_FLOAT)
	Lib.number(sheet, "reward_of", "Reward", "Milestones", "A milestone's reward value.",
		[["id", "String"]], "return float(_milestones[id].reward) if _milestones.has(id) else 0.0", TYPE_FLOAT)
	Lib.number(sheet, "reached_count", "Reached Count", "Milestones", "How many milestones have been reached.",
		[], "\n".join(PackedStringArray([
			"var count: int = 0",
			"for id: String in _milestones:",
			"\tif bool(_milestones[id].reached):",
			"\t\tcount += 1",
			"return count"
		])), TYPE_INT)
	Lib.number(sheet, "milestone_count", "Milestone Count", "Milestones", "How many milestones are defined.",
		[], "return _milestones.size()", TYPE_INT)
	Lib.number(sheet, "total_reward", "Total Reward", "Milestones", "The sum of the rewards of every reached milestone - fold this into your production multiplier.",
		[], "\n".join(PackedStringArray([
			"var total: float = 0.0",
			"for id: String in _milestones:",
			"\tif bool(_milestones[id].reached):",
			"\t\ttotal += float(_milestones[id].reward)",
			"return total"
		])), TYPE_FLOAT)
	Lib.number(sheet, "last_reached", "Last Reached", "Milestones", "The id of the milestone that just latched (read inside On Milestone Reached).",
		[], "return _last_reached_id", TYPE_STRING)
	Lib.number(sheet, "nearest_unreached", "Nearest Unreached", "Milestones", "The id of the unreached milestone closest to its threshold (for a \"next goal\" display); \"\" if all reached.",
		[], "\n".join(PackedStringArray([
			"var best_id: String = \"\"",
			"var best_ratio: float = -1.0",
			"for id: String in _milestones:",
			"\tvar record: Dictionary = _milestones[id]",
			"\tif bool(record.reached):",
			"\t\tcontinue",
			"\tvar ratio: float = float(record.value) / float(record.threshold) if float(record.threshold) > 0.0 else 1.0",
			"\tif ratio > best_ratio:",
			"\t\tbest_ratio = ratio",
			"\t\tbest_id = id",
			"return best_id"
		])), TYPE_STRING)

	var persistence: RawCodeRow = RawCodeRow.new()
	persistence.code = "\n".join(PackedStringArray([
		"# Save-state seam: the Save System walks any node in its persist group (or targeted",
		"# by Save/Load Node State) and duck-types these two methods. Plain data only.",
		"# The whole dict is saved (definitions + reached flags + last values); a later Define",
		"# Milestone on ready resets that entry, so sheets should Define BEFORE loading.",
		"## @ace_hidden",
		"func save_state() -> Dictionary:",
		"\treturn {",
		"\t\t\"milestones\": _milestones.duplicate(true)",
		"\t}",
		"",
		"## @ace_hidden",
		"func load_state(state: Dictionary) -> void:",
		"\tif state.is_empty():",
		"\t\treturn",
		"\t_milestones = (state.get(\"milestones\", {}) as Dictionary).duplicate(true)"
	]))
	sheet.events.append(persistence)

	# The pack's hero verbs: starred + bold at the top of their picker section.
	Lib.feature_verbs(sheet, ["define_milestone", "update_progress"])
	return Lib.save_pack(sheet, "res://eventsheet_addons/milestones/milestones_addon")
