# Pack builder — htn_agent (one pack per file; run via tools/build_sample_behaviors.gd).
#
# Utility-driven Hierarchical Task Network agent — a Godot-native port of the author's C3
# DHTN addons (manager plugin + agent behavior), collapsed into ONE per-object behavior (the
# natural fit for event-sheet behaviors). It owns a world-state blackboard and a task network
# of primitive tasks + compound tasks whose methods carry preconditions, an ordered subtask
# list and a utility score. Request Plan decomposes the root task, choosing the highest-utility
# applicable method at each compound (with backtracking), and yields an ordered plan of
# primitive tasks. The gameplay layer runs the current task and calls Mark Complete / Mark
# Failed; On Task Started / On Plan Complete / On Plan Failed drive the sheet.
#
# Faithful-but-focused: squad coordination, slot reservation and decaying alert stimuli from
# the C3 manager are an honest scope cut. The reusable core — world state + utility HTN
# decomposition + plan execution — is what makes this useful to every kind of game.
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")

static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "Node2D"
	sheet.custom_class_name = "HTNAgent"
	sheet.addon_tags = PackedStringArray(["ai", "planning"])
	sheet.variables = {
		"root_task": {"type": "String", "default": "", "exported": true,
			"attributes": {"tooltip": "Goal to plan for — a compound or primitive task name."}},
		"auto_replan_on_fail": {"type": "bool", "default": true, "exported": true,
			"attributes": {"tooltip": "Mark Failed re-plans from the root instead of giving up."}},
		"world_state": {"type": "Dictionary", "default": {}, "exported": false},
		"primitives": {"type": "Dictionary", "default": {}, "exported": false},
		"compounds": {"type": "Dictionary", "default": {}, "exported": false},
		"plan": {"type": "Array", "default": [], "exported": false},
		"plan_index": {"type": "int", "default": 0, "exported": false}
	}

	var about: CommentRow = CommentRow.new()
	about.text = "Utility-driven HTN planner. In On Ready build a task network (Add Primitive / Add Compound / Add Method / Add Method Condition / Add Method Subtask) and set the Root Task. Feed facts with Set World State, call Request Plan, run the Current Task in your sheet, and call Mark Complete / Mark Failed. Highest-utility applicable method wins at each compound (with backtracking). Triggers: On Task Started, On Plan Complete, On Plan Failed."
	sheet.events.append(about)

	var block: RawCodeRow = RawCodeRow.new()
	block.code = "\n".join(PackedStringArray([
		"## @ace_trigger",
		"## @ace_name(\"On Task Started\")",
		"## @ace_category(\"HTN\")",
		"signal task_started(task_name: String)",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Plan Complete\")",
		"## @ace_category(\"HTN\")",
		"signal plan_complete",
		"",
		"## @ace_trigger",
		"## @ace_name(\"On Plan Failed\")",
		"## @ace_category(\"HTN\")",
		"signal plan_failed",
		"",
		"## @ace_condition",
		"## @ace_name(\"Has Plan\")",
		"## @ace_category(\"HTN\")",
		"## @ace_codegen_template(\"$HTNAgent.has_plan()\")",
		"func has_plan() -> bool:",
		"\treturn plan_index < plan.size()",
		"",
		"## @ace_condition",
		"## @ace_name(\"Current Task Is\")",
		"## @ace_category(\"HTN\")",
		"## @ace_codegen_template(\"$HTNAgent.current_task_is({task_name})\")",
		"func current_task_is(task_name: String) -> bool:",
		"\treturn current_task() == task_name",
		"",
		"## @ace_expression",
		"## @ace_name(\"Current Task\")",
		"## @ace_category(\"HTN\")",
		"func current_task() -> String:",
		"\treturn str(plan[plan_index]) if plan_index < plan.size() else \"\"",
		"",
		"## @ace_expression",
		"## @ace_name(\"Plan Length\")",
		"## @ace_category(\"HTN\")",
		"func plan_length() -> int:",
		"\treturn plan.size()",
		"",
		"## @ace_expression",
		"## @ace_name(\"World Value\")",
		"## @ace_category(\"HTN\")",
		"func world_value(key: String) -> Variant:",
		"\treturn world_state.get(key, 0)",
		"",
		"# ── Planner internals ──",
		"func _find_method(task_name: String, method_id: String) -> Dictionary:",
		"\tfor method: Dictionary in compounds.get(task_name, []):",
		"\t\tif str(method.get(\"id\", \"\")) == method_id:",
		"\t\t\treturn method",
		"\treturn {}",
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
		"\tfor condition: Dictionary in conditions:",
		"\t\tvar actual: Variant = world_state.get(str(condition.get(\"key\", \"\")), null)",
		"\t\tif not _compare_values(actual, str(condition.get(\"op\", \"==\")), condition.get(\"value\")):",
		"\t\t\treturn false",
		"\treturn true",
		"",
		"# Decompose a task into an ordered list of primitive task names. At each compound the",
		"# applicable methods (preconditions satisfied) are tried in descending utility order,",
		"# backtracking to the next method when a subtask cannot be decomposed.",
		"func _decompose(task_name: String, depth: int) -> Array:",
		"\tif depth > 64:",
		"\t\treturn []",
		"\tif primitives.has(task_name):",
		"\t\treturn [task_name]",
		"\tif not compounds.has(task_name):",
		"\t\treturn []",
		"\tvar applicable: Array = []",
		"\tfor method: Dictionary in compounds[task_name]:",
		"\t\tif _conditions_hold(method.get(\"conditions\", [])):",
		"\t\t\tapplicable.append(method)",
		"\tapplicable.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get(\"utility\", 0.0)) > float(b.get(\"utility\", 0.0)))",
		"\tfor method: Dictionary in applicable:",
		"\t\tvar result: Array = []",
		"\t\tvar ok: bool = true",
		"\t\tfor subtask: Variant in method.get(\"subtasks\", []):",
		"\t\t\tvar sub: Array = _decompose(str(subtask), depth + 1)",
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
	Lib.append_function(sheet, "set_world_state", "Set World State", "HTN", "Writes a fact the planner reads in method preconditions.",
		[["key", "String"], ["value", "Variant"]],
		"world_state[key] = value")
	Lib.append_function(sheet, "clear_world_state", "Clear World State", "HTN", "Removes a world-state key.",
		[["key", "String"]],
		"world_state.erase(key)")
	# ── Network building ──
	Lib.append_function(sheet, "add_primitive", "Add Primitive Task", "HTN", "Registers a leaf task your sheet executes directly.",
		[["task_name", "String"]],
		"primitives[task_name] = true")
	Lib.append_function(sheet, "add_compound", "Add Compound Task", "HTN", "Registers a task that decomposes via methods.",
		[["task_name", "String"]],
		"if not compounds.has(task_name):\n\tcompounds[task_name] = []")
	Lib.append_function(sheet, "add_method", "Add Method", "HTN", "Adds (or re-scores) a way to accomplish a compound task; highest utility wins.",
		[["task_name", "String"], ["method_id", "String"], ["utility", "float"]],
		"if not compounds.has(task_name):\n\tcompounds[task_name] = []\nvar method: Dictionary = _find_method(task_name, method_id)\nif method.is_empty():\n\tcompounds[task_name].append({\"id\": method_id, \"utility\": utility, \"conditions\": [], \"subtasks\": []})\nelse:\n\tmethod[\"utility\"] = utility")
	Lib.append_function(sheet, "add_method_condition", "Add Method Condition", "HTN", "A precondition (world-state key, operator, value) the method needs to be chosen.",
		[["task_name", "String"], ["method_id", "String"], ["key", "String"], ["op", "String"], ["value", "Variant"]],
		"var method: Dictionary = _find_method(task_name, method_id)\nif not method.is_empty():\n\tmethod[\"conditions\"].append({\"key\": key, \"op\": op, \"value\": value})")
	Lib.append_function(sheet, "add_method_subtask", "Add Method Subtask", "HTN", "Appends a subtask (primitive or compound) to a method, in order.",
		[["task_name", "String"], ["method_id", "String"], ["subtask", "String"]],
		"var method: Dictionary = _find_method(task_name, method_id)\nif not method.is_empty():\n\tmethod[\"subtasks\"].append(subtask)")
	Lib.append_function(sheet, "set_method_utility", "Set Method Utility", "HTN", "Updates a method's utility at runtime (utility-driven re-prioritising).",
		[["task_name", "String"], ["method_id", "String"], ["utility", "float"]],
		"var method: Dictionary = _find_method(task_name, method_id)\nif not method.is_empty():\n\tmethod[\"utility\"] = utility")
	Lib.append_function(sheet, "clear_network", "Clear Task Network", "HTN", "Wipes all tasks/methods (keeps world state).",
		[],
		"primitives.clear()\ncompounds.clear()")
	# ── Plan lifecycle ──
	Lib.append_function(sheet, "request_plan", "Request Plan", "HTN", "Decomposes the root task into a plan and starts the first task.",
		[],
		"plan = _decompose(root_task, 0)\nplan_index = 0\nif plan.is_empty():\n\tplan_failed.emit()\nelse:\n\ttask_started.emit(str(plan[0]))")
	Lib.append_function(sheet, "mark_complete", "Mark Task Complete", "HTN", "Advances to the next task, or fires On Plan Complete at the end.",
		[],
		"if plan_index >= plan.size():\n\treturn\nplan_index += 1\nif plan_index >= plan.size():\n\tplan = []\n\tplan_index = 0\n\tplan_complete.emit()\nelse:\n\ttask_started.emit(str(plan[plan_index]))")
	Lib.append_function(sheet, "mark_failed", "Mark Task Failed", "HTN", "Re-plans from the root (or fires On Plan Failed if auto-replan is off).",
		[],
		"if auto_replan_on_fail:\n\trequest_plan()\nelse:\n\tplan = []\n\tplan_index = 0\n\tplan_failed.emit()")
	Lib.append_function(sheet, "invalidate_plan", "Invalidate Plan", "HTN", "Drops the current plan so the next Request Plan rebuilds it.",
		[],
		"plan = []\nplan_index = 0")

	return Lib.save_pack(sheet, "res://eventsheet_addons/htn_agent/htn_agent_behavior")
