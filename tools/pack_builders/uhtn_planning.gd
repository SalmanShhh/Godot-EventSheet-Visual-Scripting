# Pack builder - uhtn_planning (one pack per file; run via tools/build_sample_behaviors.gd).
#
# UHTN Planning - the utility-driven Hierarchical Task Network the author's C3 addons were built
# around, as ONE per-node behavior with BOTH halves finally combined: HTN decomposition chooses HOW
# to do things (methods with ordered subtasks + preconditions, with backtracking) and Utility AI
# chooses WHICH way is best RIGHT NOW (response-curve scorers evaluated against live world state
# rank the methods at plan time). A fixed utility number is the fallback when a method names no
# scorer, so simple networks stay simple.
#
# Two equally-supported authoring paths, matching the C3 guides' Path A/B:
#  - DATA-DRIVEN: drop a UHTNPlanResource (.tres authored in Inspector grids) onto the Plan Resource
#    slot - loaded automatically on ready. Same asset drives any number of agents.
#  - BUILDER ACEs: Add Primitive / Add Compound / Add Method / Add Method Condition / Add Method
#    Subtask / Add Scorer Input / Set Method Scorer, straight from the event sheet.
#
# Honest scope (unchanged from the HTN Agent pack this supersedes): squad coordination, slot
# reservation, and decaying alert stimuli from the C3 manager stay out - the per-node core is what
# every kind of game reuses. The shipped htn_agent + utility_ai packs remain for compatibility.
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")

const CAT := "UHTN Planning"


static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "Node2D"
	sheet.custom_class_name = "UHTNPlanner"
	sheet.addon_category = CAT
	sheet.ace_expose_all_mode = "node"
	sheet.addon_tags = PackedStringArray(["ai", "planning", "utility"])
	sheet.variables = {
		"plan_resource": {"type": "Resource", "default": null, "exported": true,
			"attributes": {"tooltip": "Optional: a UHTNPlanResource (.tres) holding the whole plan - tasks, methods, preconditions, and utility scorers - authored in Inspector grids. Loaded automatically on ready; leave empty to build the network with the Add ... actions instead."}},
		"root_task": {"type": "String", "default": "", "exported": true,
			"attributes": {"tooltip": "Goal to plan for - a compound or primitive task name. A loaded Plan Resource overrides this with its own root task."}},
		"auto_replan_on_fail": {"type": "bool", "default": true, "exported": true,
			"attributes": {"tooltip": "Mark Failed re-plans from the root instead of giving up."}},
		"world_state": {"type": "Dictionary", "default": {}, "exported": false},
		"primitives": {"type": "Dictionary", "default": {}, "exported": false},
		"compounds": {"type": "Dictionary", "default": {}, "exported": false},
		"scorers": {"type": "Dictionary", "default": {}, "exported": false},
		"plan": {"type": "Array", "default": [], "exported": false},
		"plan_index": {"type": "int", "default": 0, "exported": false}
	}

	var about: CommentRow = CommentRow.new()
	about.text = "UHTN Planning: utility-driven HTN in one behavior. EITHER drop a UHTNPlanResource (.tres of Inspector grids) onto Plan Resource, OR build in events (Add Primitive / Add Compound / Add Method / Add Method Condition / Add Method Subtask). Rank methods LIVE with Utility AI: Add Scorer Input feeds a world-state key through a response curve into a named scorer, Set Method Scorer binds it - the best-scoring applicable method wins at each compound (with backtracking); a method without a scorer uses its fixed utility. Feed facts with Set World State, call Request Plan, run the Current Task, then Mark Complete / Mark Failed. Triggers: On Task Started, On Plan Complete, On Plan Failed, On Plan Loaded."
	sheet.events.append(about)

	var block: RawCodeRow = RawCodeRow.new()
	block.code = "\n".join(PackedStringArray([
		"## @ace_trigger",
		"## @ace_name(\"On Task Started\")",
		"signal task_started(task_name: String)",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Plan Complete\")",
		"signal plan_complete",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Plan Failed\")",
		"signal plan_failed",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Plan Loaded\")",
		"signal plan_loaded(plan_name: String)",
		"",
		"## @ace_condition",
		"## @ace_name(\"Has Plan\")",
		"func has_plan() -> bool:",
		"\treturn plan_index < plan.size()",
		"",
		"## @ace_condition",
		"## @ace_name(\"Current Task Is\")",
		"func current_task_is(task_name: String) -> bool:",
		"\treturn current_task() == task_name",
		"",
		"## @ace_expression",
		"## @ace_name(\"Current Task\")",
		"func current_task() -> String:",
		"\treturn str(plan[plan_index]) if plan_index < plan.size() else \"\"",
		"",
		"## @ace_expression",
		"## @ace_name(\"Plan Length\")",
		"func plan_length() -> int:",
		"\treturn plan.size()",
		"",
		"## @ace_expression",
		"## @ace_name(\"Plan Task At\")",
		"func plan_task_at(index: int) -> String:",
		"\treturn str(plan[index]) if index >= 0 and index < plan.size() else \"\"",
		"",
		"## @ace_expression",
		"## @ace_name(\"World Value\")",
		"func world_value(key: String) -> Variant:",
		"\treturn world_state.get(key, 0)",
		"",
		"## @ace_expression",
		"## @ace_name(\"Scorer Value\")",
		"func scorer_value(scorer_id: String) -> float:",
		"\treturn _evaluate_scorer(scorer_id)",
		"",
		"func _ready() -> void:",
		"\tif plan_resource != null:",
		"\t\tload_plan(plan_resource)",
		"",
		"## An HTN method - a way to accomplish a compound task: preconditions, an ordered subtask list,",
		"## and its rank source (a live utility scorer when `scorer` is set, else the fixed `utility`).",
		"class HTNMethod:",
		"\tvar id: String = \"\"",
		"\tvar utility: float = 0.0",
		"\tvar scorer: String = \"\"",
		"\tvar conditions: Array = []",
		"\tvar subtasks: Array = []",
		"",
		"## A precondition (world-state key, operator, expected value) a method needs to be chosen.",
		"class HTNCondition:",
		"\tvar key: String = \"\"",
		"\tvar op: String = \"==\"",
		"\tvar value: Variant = null",
		"",
		"# ── Planner internals ──",
		"func _find_method(task_name: String, method_id: String) -> HTNMethod:",
		"\tfor method: HTNMethod in compounds.get(task_name, []):",
		"\t\tif method.id == method_id:",
		"\t\t\treturn method",
		"\treturn null",
		"",
		"func _find_method_anywhere(method_id: String) -> HTNMethod:",
		"\tfor task_name: String in compounds:",
		"\t\tvar found: HTNMethod = _find_method(task_name, method_id)",
		"\t\tif found != null:",
		"\t\t\treturn found",
		"\treturn null",
		"",
		"func _to_number(value: Variant) -> float:",
		"\tif value is float or value is int:",
		"\t\treturn float(value)",
		"\treturn str(value).to_float()",
		"",
		"func _loose_equal(a: Variant, b: Variant) -> bool:",
		"\tif (a is float or a is int) and (b is float or b is int):",
		"\t\treturn is_equal_approx(float(a), float(b))",
		"\treturn str(a) == str(b)",
		"",
		"func _compare_values(a: Variant, op: String, b: Variant) -> bool:",
		"\tif op == \"==\": return _loose_equal(a, b)",
		"\tif op == \"!=\": return not _loose_equal(a, b)",
		"\tif op == \"<\": return _to_number(a) < _to_number(b)",
		"\tif op == \"<=\": return _to_number(a) <= _to_number(b)",
		"\tif op == \">\": return _to_number(a) > _to_number(b)",
		"\tif op == \">=\": return _to_number(a) >= _to_number(b)",
		"\treturn false",
		"",
		"func _conditions_hold(conditions: Array) -> bool:",
		"\tfor condition: HTNCondition in conditions:",
		"\t\tvar actual: Variant = world_state.get(condition.key, null)",
		"\t\tif not _compare_values(actual, condition.op, condition.value):",
		"\t\t\treturn false",
		"\treturn true",
		"",
		"# Maps a world-state input (clamped 0-1) through a named response curve - the Utility AI half.",
		"func _curve_score(curve: String, x: float, center: float, slope: float) -> float:",
		"\tvar v: float = clampf(x, 0.0, 1.0)",
		"\tmatch curve:",
		"\t\t\"linear\": return v",
		"\t\t\"inverse\": return 1.0 - v",
		"\t\t\"quadratic\": return v * v",
		"\t\t\"inverse_quadratic\": return 1.0 - v * v",
		"\t\t\"logistic\": return 1.0 / (1.0 + exp(-maxf(slope, 0.001) * 10.0 * (v - center)))",
		"\t\t\"threshold\": return 1.0 if v >= center else 0.0",
		"\t\t\"bell\":",
		"\t\t\tvar d: float = (v - center) / maxf(slope, 0.001)",
		"\t\t\treturn exp(-d * d)",
		"\treturn v",
		"",
		"# A scorer's live value: the weighted average of its inputs, each read from world state and",
		"# mapped through its curve. Unknown scorer or zero total weight scores 0.",
		"func _evaluate_scorer(scorer_id: String) -> float:",
		"\tvar inputs: Array = scorers.get(scorer_id, [])",
		"\tif inputs.is_empty():",
		"\t\treturn 0.0",
		"\tvar total: float = 0.0",
		"\tvar weight_sum: float = 0.0",
		"\tfor entry: Dictionary in inputs:",
		"\t\tvar weight: float = _to_number(entry.get(\"weight\", 1.0))",
		"\t\tvar x: float = _to_number(world_state.get(str(entry.get(\"input\", \"\")), 0.0))",
		"\t\ttotal += _curve_score(str(entry.get(\"curve\", \"linear\")), x, _to_number(entry.get(\"center\", 0.5)), _to_number(entry.get(\"slope\", 0.2))) * weight",
		"\t\tweight_sum += absf(weight)",
		"\treturn total / weight_sum if weight_sum > 0.0 else 0.0",
		"",
		"# A method's rank at plan time: its scorer's live value when one is bound, else its fixed utility.",
		"func _method_rank(method: HTNMethod) -> float:",
		"\tif not method.scorer.is_empty() and scorers.has(method.scorer):",
		"\t\treturn _evaluate_scorer(method.scorer)",
		"\treturn method.utility",
		"",
		"# Decompose a task into an ordered list of primitive task names. At each compound the",
		"# applicable methods (preconditions satisfied) are tried in descending RANK order - the",
		"# utility-driven part - backtracking to the next method when a subtask cannot decompose.",
		"func _decompose(task_name: String, depth: int) -> Array:",
		"\tif depth > 64:",
		"\t\treturn []",
		"\tif primitives.has(task_name):",
		"\t\treturn [task_name]",
		"\tif not compounds.has(task_name):",
		"\t\treturn []",
		"\tvar applicable: Array = []",
		"\tfor method: HTNMethod in compounds[task_name]:",
		"\t\tif _conditions_hold(method.conditions):",
		"\t\t\tapplicable.append(method)",
		"\tapplicable.sort_custom(func(a: HTNMethod, b: HTNMethod) -> bool: return _method_rank(a) > _method_rank(b))",
		"\tfor method: HTNMethod in applicable:",
		"\t\tvar result: Array = []",
		"\t\tvar ok: bool = true",
		"\t\tfor subtask: String in method.subtasks:",
		"\t\t\tvar sub: Array = _decompose(subtask, depth + 1)",
		"\t\t\tif sub.is_empty():",
		"\t\t\t\tok = false",
		"\t\t\t\tbreak",
		"\t\t\tresult.append_array(sub)",
		"\t\tif ok:",
		"\t\t\treturn result",
		"\treturn []"
	]))
	sheet.events.append(block)

	# ── World state ──
	Lib.append_function(sheet, "set_world_state", "Set World State", CAT, "Writes a fact - preconditions and scorer inputs read it.",
		[["key", "String"], ["value", "Variant"]],
		"world_state[key] = value")
	Lib.append_function(sheet, "clear_world_state", "Clear World State", CAT, "Removes a world-state key.",
		[["key", "String"]],
		"world_state.erase(key)")
	# ── Network building (the builder-ACE path) ──
	Lib.append_function(sheet, "add_primitive", "Add Primitive Task", CAT, "Registers a leaf task your sheet executes directly.",
		[["task_name", "String"]],
		"primitives[task_name] = true")
	Lib.append_function(sheet, "add_compound", "Add Compound Task", CAT, "Registers a task that decomposes via methods.",
		[["task_name", "String"]],
		"if not compounds.has(task_name):\n\tcompounds[task_name] = []")
	Lib.append_function(sheet, "add_method", "Add Method", CAT, "Adds (or re-scores) a way to accomplish a compound task; the best-ranked applicable method wins.",
		[["task_name", "String"], ["method_id", "String"], ["utility", "float"]],
		"if not compounds.has(task_name):\n\tcompounds[task_name] = []\nvar method: HTNMethod = _find_method(task_name, method_id)\nif method == null:\n\tvar m: HTNMethod = HTNMethod.new()\n\tm.id = method_id\n\tm.utility = utility\n\tcompounds[task_name].append(m)\nelse:\n\tmethod.utility = utility")
	Lib.append_function(sheet, "add_method_condition", "Add Method Condition", CAT, "A precondition (world-state key, operator, value) the method needs to be chosen.",
		[["task_name", "String"], ["method_id", "String"], ["key", "String"], ["op", "String"], ["value", "Variant"]],
		"var method: HTNMethod = _find_method(task_name, method_id)\nif method != null:\n\tvar c: HTNCondition = HTNCondition.new()\n\tc.key = key\n\tc.op = op\n\tc.value = value\n\tmethod.conditions.append(c)")
	Lib.append_function(sheet, "add_method_subtask", "Add Method Subtask", CAT, "Appends a subtask (primitive or compound) to a method, in order.",
		[["task_name", "String"], ["method_id", "String"], ["subtask", "String"]],
		"var method: HTNMethod = _find_method(task_name, method_id)\nif method != null:\n\tmethod.subtasks.append(subtask)")
	# ── Utility scoring (the Utility AI half) ──
	Lib.append_function(sheet, "add_scorer_input", "Add Scorer Input", CAT, "Feeds a world-state key through a response curve (linear / inverse / quadratic / inverse_quadratic / logistic / threshold / bell) into a named scorer. A scorer is the weighted average of its inputs.",
		[["scorer_id", "String"], ["input_key", "String"], ["curve", "String"], ["weight", "float"], ["center", "float"], ["slope", "float"]],
		"if not scorers.has(scorer_id):\n\tscorers[scorer_id] = []\nscorers[scorer_id].append({\"input\": input_key, \"curve\": curve, \"weight\": weight, \"center\": center, \"slope\": slope})")
	Lib.append_function(sheet, "set_method_scorer", "Set Method Scorer", CAT, "Binds a utility scorer to a method - the method is then ranked by the scorer's LIVE value at plan time instead of its fixed utility.",
		[["task_name", "String"], ["method_id", "String"], ["scorer_id", "String"]],
		"var method: HTNMethod = _find_method(task_name, method_id)\nif method != null:\n\tmethod.scorer = scorer_id")
	Lib.append_function(sheet, "clear_network", "Clear Task Network", CAT, "Wipes all tasks, methods, and scorers (keeps world state).",
		[],
		"primitives.clear()\ncompounds.clear()\nscorers.clear()")
	# ── The data-driven path ──
	Lib.append_function(sheet, "load_plan", "Load Plan Resource", CAT, "Loads a UHTNPlanResource (.tres): its tasks, methods, preconditions, and scorer inputs replace the current network, and its root task becomes the goal. Fires On Plan Loaded.",
		[["resource", "Resource"]],
		"\n".join(PackedStringArray([
			"if resource == null:",
			"\treturn",
			"clear_network()",
			"for row: Dictionary in resource.get(\"tasks\") if resource.get(\"tasks\") is Array else []:",
			"\tif str(row.get(\"kind\", \"primitive\")) == \"compound\":",
			"\t\tadd_compound(str(row.get(\"name\", \"\")))",
			"\telse:",
			"\t\tadd_primitive(str(row.get(\"name\", \"\")))",
			"for row: Dictionary in resource.get(\"methods\") if resource.get(\"methods\") is Array else []:",
			"\tvar task: String = str(row.get(\"task\", \"\"))",
			"\tvar method_id: String = str(row.get(\"method\", \"\"))",
			"\tadd_compound(task)",
			"\tadd_method(task, method_id, _to_number(row.get(\"utility\", 0.0)))",
			"\tvar scorer: String = str(row.get(\"scorer\", \"\")).strip_edges()",
			"\tif not scorer.is_empty():",
			"\t\tset_method_scorer(task, method_id, scorer)",
			"\tfor subtask: String in str(row.get(\"subtasks\", \"\")).split(\",\", false):",
			"\t\tadd_method_subtask(task, method_id, subtask.strip_edges())",
			"for row: Dictionary in resource.get(\"conditions\") if resource.get(\"conditions\") is Array else []:",
			"\tvar bound: HTNMethod = _find_method_anywhere(str(row.get(\"method\", \"\")))",
			"\tif bound != null:",
			"\t\tvar c: HTNCondition = HTNCondition.new()",
			"\t\tc.key = str(row.get(\"key\", \"\"))",
			"\t\tc.op = str(row.get(\"op\", \"==\"))",
			"\t\tc.value = row.get(\"value\", null)",
			"\t\tbound.conditions.append(c)",
			"for row: Dictionary in resource.get(\"scorer_inputs\") if resource.get(\"scorer_inputs\") is Array else []:",
			"\tadd_scorer_input(str(row.get(\"scorer\", \"\")), str(row.get(\"input\", \"\")), str(row.get(\"curve\", \"linear\")), _to_number(row.get(\"weight\", 1.0)), _to_number(row.get(\"center\", 0.5)), _to_number(row.get(\"slope\", 0.2)))",
			"var loaded_root: String = str(resource.get(\"root_task\")) if resource.get(\"root_task\") != null else \"\"",
			"if not loaded_root.strip_edges().is_empty():",
			"\troot_task = loaded_root",
			"plan_loaded.emit(str(resource.get(\"plan_name\")) if resource.get(\"plan_name\") != null else \"\")"
		])))
	# ── Plan lifecycle ──
	Lib.append_function(sheet, "request_plan", "Request Plan", CAT, "Decomposes the root task into a plan (best-ranked methods win) and starts the first task.",
		[],
		"plan = _decompose(root_task, 0)\nplan_index = 0\nif plan.is_empty():\n\tplan_failed.emit()\nelse:\n\ttask_started.emit(str(plan[0]))")
	Lib.append_function(sheet, "mark_complete", "Mark Task Complete", CAT, "Advances to the next task, or fires On Plan Complete at the end.",
		[],
		"if plan_index >= plan.size():\n\treturn\nplan_index += 1\nif plan_index >= plan.size():\n\tplan = []\n\tplan_index = 0\n\tplan_complete.emit()\nelse:\n\ttask_started.emit(str(plan[plan_index]))")
	Lib.append_function(sheet, "mark_failed", "Mark Task Failed", CAT, "Re-plans from the root (or fires On Plan Failed if auto-replan is off).",
		[],
		"if auto_replan_on_fail:\n\trequest_plan()\nelse:\n\tplan = []\n\tplan_index = 0\n\tplan_failed.emit()")
	Lib.append_function(sheet, "force_task", "Force Task", CAT, "Pushes a task to the front of the plan and starts it - the scripted-override escape hatch (cutscene beats, staggers).",
		[["task_name", "String"]],
		"plan.insert(plan_index, task_name)\ntask_started.emit(task_name)")
	Lib.append_function(sheet, "invalidate_plan", "Invalidate Plan", CAT, "Drops the current plan so the next Request Plan rebuilds it.",
		[],
		"plan = []\nplan_index = 0")

	return Lib.save_pack(sheet, "res://eventsheet_addons/uhtn_planning/uhtn_planning_behavior")
