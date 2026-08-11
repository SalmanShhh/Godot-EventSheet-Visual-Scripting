# Pack builder - quest (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## Quest: quest and objective tracking as an AUTOLOAD sheet (Quests). A quest is a QuestResource
## (a .tres you fill in the Inspector: an id, a title, an objectives grid of name + needed, an
## optional next quest, a reward note). Start it, count progress with Advance Objective, and react
## through triggers - the counting, the clamping, the "are we done yet" sweep and the questline chain
## are the pack's job, not a wall of variables and if-rows.
##  - Objectives are counted, not booleans: "Collect 5 gems" is one row that advances to 5/5.
##  - Progress is clamped at the needed count, so an over-advance can never fire a trigger twice.
##  - Completing every objective moves the quest to the completed list, fires On Quest Completed, and
##    auto-starts the resource's Next Quest when it named one (chain a questline with no wiring).
##  - Save Quests / Load Quests persist the active + completed state through the same
##    user://remembered.cfg store the Remember Between Runs variable option writes to.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.autoload_mode = true
	sheet.autoload_name = "Quests"
	sheet.host_class = "Node"
	sheet.custom_class_name = "QuestPackAddon"
	sheet.class_description = "Quest and objective tracking as the Quests autoload singleton: start a quest from a QuestResource, count objectives up with Advance Objective, and react through On Objective Completed / On Quest Completed. Progress is clamped, completion is detected for you, and a quest that names a Next Quest chains into it automatically."
	sheet.addon_category = "Quest"
	sheet.addon_tags = PackedStringArray(["quest", "objective", "progression"])
	var about: CommentRow = CommentRow.new()
	about.text = "Quest: register as the Quests autoload. Author each quest as a QuestResource (.tres) in the Inspector, Start Quest to begin it, Advance Objective to count progress, and react with On Objective Completed / On Quest Completed. Save Quests and Load Quests carry the state between runs. This pack is an event sheet - extend it by editing it."
	sheet.events.append(about)

	# Triggers: real signals with their context as parameters, so a row reads the quest it fired for.
	var started_signal: SignalRow = SignalRow.new()
	started_signal.signal_name = "on_quest_started"
	started_signal.params = PackedStringArray(["quest_id: String"])
	started_signal.trigger = true
	started_signal.ace_name = "On Quest Started"
	started_signal.ace_category = "Quest"
	sheet.events.append(started_signal)

	var objective_signal: SignalRow = SignalRow.new()
	objective_signal.signal_name = "on_objective_completed"
	objective_signal.params = PackedStringArray(["quest_id: String", "objective: String"])
	objective_signal.trigger = true
	objective_signal.ace_name = "On Objective Completed"
	objective_signal.ace_category = "Quest"
	sheet.events.append(objective_signal)

	var completed_signal: SignalRow = SignalRow.new()
	completed_signal.signal_name = "on_quest_completed"
	completed_signal.params = PackedStringArray(["quest_id: String"])
	completed_signal.trigger = true
	completed_signal.ace_name = "On Quest Completed"
	completed_signal.ace_category = "Quest"
	sheet.events.append(completed_signal)

	var block: RawCodeRow = RawCodeRow.new()
	block.code = "\n".join(PackedStringArray([
		"# quest_id -> {objective_name -> {done, needed}} - only quests being tracked right now.",
		"var _active: Dictionary = {}",
		"# The quest ids finished this run (or restored by Load Quests), in completion order.",
		"var _completed: Array[String] = []",
		"# quest_id -> {title, next, reward, objectives: Array of {name, needed}} - every QuestResource",
		"# the pack has seen (Start Quest and Register Quest both remember one). The chain reads it, so a",
		"# quest can only auto-start a Next Quest that was registered or started at least once.",
		"var _library: Dictionary = {}",
		"",
		"# One field off a QuestResource as text. Object.get returns null for a property the resource does",
		"# not have, and str(null) would read as \"<null>\" - a blank is what a missing field means here.",
		"func _field(quest: Resource, key: String) -> String:",
		"\tvar value: Variant = quest.get(key)",
		"\treturn \"\" if value == null else str(value)",
		"",
		"# Copies a QuestResource into the library and returns its id (\"\" when there is nothing usable).",
		"# Purely a read of the asset - it never starts anything.",
		"func _remember(quest: Resource) -> String:",
		"\tif quest == null:",
		"\t\tpush_warning(\"Quests: was given no quest resource.\")",
		"\t\treturn \"\"",
		"\tvar quest_id: String = _field(quest, \"quest_id\")",
		"\tif quest_id.is_empty():",
		"\t\tpush_warning(\"Quests: a quest resource has a blank quest_id and cannot be tracked.\")",
		"\t\treturn \"\"",
		"\tvar goals: Array = []",
		"\tvar rows: Variant = quest.get(\"objectives\")",
		"\tif rows is Array:",
		"\t\tfor row: Variant in (rows as Array):",
		"\t\t\tif not (row is Dictionary):",
		"\t\t\t\tcontinue",
		"\t\t\tvar goal_name: String = str((row as Dictionary).get(\"name\", \"\"))",
		"\t\t\tif goal_name.is_empty():",
		"\t\t\t\tcontinue",
		"\t\t\tgoals.append({\"name\": goal_name, \"needed\": maxi(int((row as Dictionary).get(\"needed\", 1)), 1)})",
		"\t_library[quest_id] = {",
		"\t\t\"title\": _field(quest, \"title\"),",
		"\t\t\"next\": _field(quest, \"next_quest\"),",
		"\t\t\"reward\": _field(quest, \"reward_note\"),",
		"\t\t\"objectives\": goals",
		"\t}",
		"\treturn quest_id",
		"",
		"# Puts a remembered quest into the active list with every objective at 0 and fires its trigger.",
		"# Restarting a completed quest takes it back off the completed list, so the two never overlap.",
		"func _begin(quest_id: String) -> void:",
		"\tif not _library.has(quest_id):",
		"\t\tpush_warning(\"Quests: no quest named '%s' is registered - start it or register it first.\" % quest_id)",
		"\t\treturn",
		"\tvar goals: Dictionary = {}",
		"\tfor goal: Dictionary in (_library[quest_id] as Dictionary).objectives:",
		"\t\tgoals[str(goal.name)] = {\"done\": 0, \"needed\": maxi(int(goal.needed), 1)}",
		"\t_active[quest_id] = goals",
		"\t_completed.erase(quest_id)",
		"\ton_quest_started.emit(quest_id)",
		"",
		"# Whether every objective of an ACTIVE quest has reached its needed count.",
		"func _all_done(quest_id: String) -> bool:",
		"\tfor goal_name: String in (_active[quest_id] as Dictionary):",
		"\t\tvar goal: Dictionary = _active[quest_id][goal_name]",
		"\t\tif int(goal.done) < int(goal.needed):",
		"\t\t\treturn false",
		"\treturn true",
		"",
		"# Finishes an active quest: moves it to completed, fires the trigger, then chains into the",
		"# resource's Next Quest when it named one.",
		"func _finish(quest_id: String) -> void:",
		"\t_active.erase(quest_id)",
		"\tif not _completed.has(quest_id):",
		"\t\t_completed.append(quest_id)",
		"\ton_quest_completed.emit(quest_id)",
		"\tvar next_id: String = str((_library.get(quest_id, {}) as Dictionary).get(\"next\", \"\"))",
		"\tif not next_id.is_empty():",
		"\t\t_begin(next_id)"
	]))
	sheet.events.append(block)

	# --- Starting and ending quests ---
	Lib.append_function(sheet, "start_quest", "Start Quest", "Quest", "Begins a quest from a Quest resource (a .tres you filled in the Inspector): every objective starts at 0 and On Quest Started fires. Starting a quest again resets its progress.",
		[["quest", "Resource"]],
		"var quest_id: String = _remember(quest)\nif quest_id.is_empty():\n\treturn\n_begin(quest_id)")
	Lib.append_function(sheet, "register_quest", "Register Quest", "Quest", "Teaches the tracker a quest WITHOUT starting it, so another quest can chain into it through its Next Quest field (and so Quest Title / Quest Reward Note can read it). Register the later quests of a questline once at startup.",
		[["quest", "Resource"]],
		"_remember(quest)")
	Lib.append_function(sheet, "advance_objective", "Advance Objective", "Quest", "Counts progress on one objective of an active quest. Progress stops at the needed count, so an extra call can never double-fire: On Objective Completed fires the moment it fills, and once every objective is full the quest completes (On Quest Completed) and its Next Quest starts automatically.",
		[["quest_id", "String"], ["objective", "String"], ["amount", "int"]],
		"\n".join(PackedStringArray([
			"if not _active.has(quest_id):",
			"\treturn",
			"var goals: Dictionary = _active[quest_id]",
			"if not goals.has(objective):",
			"\treturn",
			"var goal: Dictionary = goals[objective]",
			"if int(goal.done) >= int(goal.needed):",
			"\treturn",
			"goal.done = mini(int(goal.done) + maxi(amount, 0), int(goal.needed))",
			"if int(goal.done) < int(goal.needed):",
			"\treturn",
			"on_objective_completed.emit(quest_id, objective)",
			"if _all_done(quest_id):",
			"\t_finish(quest_id)"
		])))
	Lib.append_function(sheet, "abandon_quest", "Abandon Quest", "Quest", "Drops an active quest and forgets its progress. It does NOT count as completed, and no trigger fires - start it again to try over.",
		[["quest_id", "String"]],
		"_active.erase(quest_id)")
	Lib.append_function(sheet, "reset_quests", "Reset All Quests", "Quest", "Clears every active quest and the completed list (e.g. on New Game). Registered quest definitions are kept, so a chain still works.",
		[],
		"_active.clear()\n_completed.clear()")

	# --- Persistence (the Remember Between Runs store) ---
	Lib.append_function(sheet, "save_quests", "Save Quests", "Quest", "Writes the active quests and the completed list into user://remembered.cfg (the same file the Remember Between Runs variable option uses) under a \"Quests\" section. Call it when the player saves or the level ends.",
		[],
		"\n".join(PackedStringArray([
			"var config: ConfigFile = ConfigFile.new()",
			"config.load(\"user://remembered.cfg\")",
			"config.set_value(\"Quests\", \"active\", _active.duplicate(true))",
			"config.set_value(\"Quests\", \"completed\", Array(_completed))",
			"config.save(\"user://remembered.cfg\")"
		])))
	Lib.append_function(sheet, "load_quests", "Load Quests", "Quest", "Reads the active quests and the completed list back out of user://remembered.cfg (the Remember Between Runs store), replacing whatever is tracked now. Nothing happens if there is no save yet. Register your quest resources first if you want chains to keep working.",
		[],
		"\n".join(PackedStringArray([
			"var config: ConfigFile = ConfigFile.new()",
			"if config.load(\"user://remembered.cfg\") != OK:",
			"\treturn",
			"_active = (config.get_value(\"Quests\", \"active\", {}) as Dictionary).duplicate(true)",
			"_completed.clear()",
			"for quest_id: Variant in (config.get_value(\"Quests\", \"completed\", []) as Array):",
			"\t_completed.append(str(quest_id))"
		])))

	# --- Conditions ---
	Lib.condition(sheet, "quest_is_active", "Quest Is Active", "Quest", "Whether this quest is being tracked right now (started, not yet completed or abandoned).", [["quest_id", "String"]],
		"return _active.has(quest_id)")
	Lib.condition(sheet, "quest_is_completed", "Quest Is Completed", "Quest", "Whether this quest has been finished (every objective filled).", [["quest_id", "String"]],
		"return _completed.has(quest_id)")
	Lib.condition(sheet, "objective_is_done", "Objective Is Done", "Quest", "Whether one objective of an active quest has reached its needed count.", [["quest_id", "String"], ["objective", "String"]],
		"var goals: Dictionary = _active.get(quest_id, {})\nif not goals.has(objective):\n\treturn false\nreturn int(goals[objective].done) >= int(goals[objective].needed)")

	# --- Expressions ---
	Lib.number(sheet, "objective_text", "Objective Text", "Quest", "An objective's progress as readable text, e.g. \"3/5\" - drop it straight into a quest-log label. \"\" if the quest is not active or has no such objective.", [["quest_id", "String"], ["objective", "String"]],
		"var goals: Dictionary = _active.get(quest_id, {})\nif not goals.has(objective):\n\treturn \"\"\nreturn \"%d/%d\" % [int(goals[objective].done), int(goals[objective].needed)]", TYPE_STRING)
	Lib.number(sheet, "objective_progress", "Objective Progress", "Quest", "An objective's progress as 0-1 - feed it straight to a progress bar's Progress Of. 0 if the quest is not active or has no such objective.", [["quest_id", "String"], ["objective", "String"]],
		"var goals: Dictionary = _active.get(quest_id, {})\nif not goals.has(objective):\n\treturn 0.0\nreturn clampf(float(goals[objective].done) / maxf(float(goals[objective].needed), 1.0), 0.0, 1.0)", TYPE_FLOAT)
	Lib.number(sheet, "active_quest_count", "Active Quest Count", "Quest", "How many quests are being tracked right now.", [],
		"return _active.size()", TYPE_INT)
	Lib.number(sheet, "completed_quest_count", "Completed Quest Count", "Quest", "How many quests have been finished.", [],
		"return _completed.size()", TYPE_INT)
	Lib.number(sheet, "quest_title", "Quest Title", "Quest", "The player-facing title of a started or registered quest (\"\" if the tracker has never seen it).", [["quest_id", "String"]],
		"return str((_library.get(quest_id, {}) as Dictionary).get(\"title\", \"\"))", TYPE_STRING)
	Lib.number(sheet, "quest_reward_note", "Quest Reward Note", "Quest", "The reward note written on the quest resource - show it in your log and hand the reward out yourself in On Quest Completed.", [["quest_id", "String"]],
		"return str((_library.get(quest_id, {}) as Dictionary).get(\"reward\", \"\"))", TYPE_STRING)

	# Save-state seam - deliberately unpublished; the Save System provides the user-facing verbs.
	var persistence: RawCodeRow = RawCodeRow.new()
	persistence.code = "\n".join(PackedStringArray([
		"# Save-state seam: the Save System walks any node in its persist group (or targeted",
		"# by Save/Load Node State) and duck-types these two methods. Plain data only.",
		"# The library is NOT part of the snapshot - it is rebuilt by starting or registering the",
		"# quest resources, which live in the project rather than in the save.",
		"## @ace_hidden",
		"func save_state() -> Dictionary:",
		"\treturn {",
		"\t\t\"active\": _active.duplicate(true),",
		"\t\t\"completed\": Array(_completed)",
		"\t}",
		"",
		"## @ace_hidden",
		"func load_state(state: Dictionary) -> void:",
		"\tif state.is_empty():",
		"\t\treturn",
		"\t_active = (state.get(\"active\", {}) as Dictionary).duplicate(true)",
		"\t_completed.clear()",
		"\tfor quest_id: Variant in (state.get(\"completed\", []) as Array):",
		"\t\t_completed.append(str(quest_id))"
	]))
	sheet.events.append(persistence)

	# The pack's hero verbs: starred + bold at the top of their picker section.
	Lib.verb_sentences(sheet, {
		"start_quest": "Start quest [b]{quest}[/b]",
		"advance_objective": "Advance [b]{objective}[/b] on quest [b]{quest_id}[/b] by [b]{amount}[/b]",
		"abandon_quest": "Abandon quest [b]{quest_id}[/b]",
	})
	Lib.feature_verbs(sheet, ["start_quest", "advance_objective"])
	return Lib.save_pack(sheet, "res://eventsheet_addons/quest/quest_addon")
