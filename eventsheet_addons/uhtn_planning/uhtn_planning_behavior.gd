## @ace_tags(ai, planning, utility)
## @ace_category("UHTN Planning")
## @ace_expose_all(node)
@icon("res://eventsheet_addons/behavior.svg")
class_name UHTNPlanner
extends Node

## The node this behavior acts on (its parent). Required host: Node2D.
var host: Node2D = null

func _enter_tree() -> void:
	host = get_parent() as Node2D
	if host == null:
		push_warning("UHTNPlanner behavior requires a Node2D parent.")

## @ace_trigger
## @ace_name("On Task Started")
signal task_started(task_name: String)
## @ace_trigger
## @ace_name("On Plan Complete")
signal plan_complete
## @ace_trigger
## @ace_name("On Plan Failed")
signal plan_failed
## @ace_trigger
## @ace_name("On Plan Loaded")
signal plan_loaded(plan_name: String)

## Mark Failed re-plans from the root instead of giving up.
@export var auto_replan_on_fail: bool = true
var compounds: Dictionary = {}
var plan: Array = []
var plan_index: int = 0
## Optional: a UHTNPlanResource (.tres) holding the whole plan - tasks, methods, preconditions, and utility scorers - authored in Inspector grids. Loaded automatically on ready; leave empty to build the network with the Add ... actions instead.
@export var plan_resource: Resource = null
var primitives: Dictionary = {}
## Goal to plan for - a compound or primitive task name. A loaded Plan Resource overrides this with its own root task.
@export var root_task: String = ""
var scorers: Dictionary = {}
var world_state: Dictionary = {}

## An HTN method - a way to accomplish a compound task: preconditions, an ordered subtask list,
## and its rank source (a live utility scorer when `scorer` is set, else the fixed `utility`).
class HTNMethod:
	var id: String = ""
	var utility: float = 0.0
	var scorer: String = ""
	var conditions: Array = []
	var subtasks: Array = []

## A precondition (world-state key, operator, expected value) a method needs to be chosen.
class HTNCondition:
	var key: String = ""
	var op: String = "=="
	var value: Variant = null
# ── Planner internals ──
func _find_method(task_name: String, method_id: String) -> HTNMethod:
	for method: HTNMethod in compounds.get(task_name, []):
		if method.id == method_id:
			return method
	return null
func _find_method_anywhere(method_id: String) -> HTNMethod:
	for task_name: String in compounds:
		var found: HTNMethod = _find_method(task_name, method_id)
		if found != null:
			return found
	return null

## @ace_action
## @ace_name("Set World State")
## @ace_category("UHTN Planning")
## @ace_description("Writes a fact - preconditions and scorer inputs read it.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$UHTNPlanner.set_world_state({key}, {value})")
func set_world_state(key: String, value) -> void:
	world_state[key] = value

## @ace_action
## @ace_name("Clear World State")
## @ace_category("UHTN Planning")
## @ace_description("Removes a world-state key.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$UHTNPlanner.clear_world_state({key})")
func clear_world_state(key: String) -> void:
	world_state.erase(key)

## @ace_action
## @ace_name("Add Primitive Task")
## @ace_category("UHTN Planning")
## @ace_description("Registers a leaf task your sheet executes directly.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$UHTNPlanner.add_primitive({task_name})")
func add_primitive(task_name: String) -> void:
	primitives[task_name] = true

## @ace_action
## @ace_name("Add Compound Task")
## @ace_category("UHTN Planning")
## @ace_description("Registers a task that decomposes via methods.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$UHTNPlanner.add_compound({task_name})")
func add_compound(task_name: String) -> void:
	if not compounds.has(task_name):
		compounds[task_name] = []

## @ace_action
## @ace_name("Add Method")
## @ace_category("UHTN Planning")
## @ace_description("Adds (or re-scores) a way to accomplish a compound task; the best-ranked applicable method wins.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$UHTNPlanner.add_method({task_name}, {method_id}, {utility})")
func add_method(task_name: String, method_id: String, utility: float) -> void:
	if not compounds.has(task_name):
		compounds[task_name] = []
	var method: HTNMethod = _find_method(task_name, method_id)
	if method == null:
		var m: HTNMethod = HTNMethod.new()
		m.id = method_id
		m.utility = utility
		compounds[task_name].append(m)
	else:
		method.utility = utility

## @ace_action
## @ace_name("Add Method Condition")
## @ace_category("UHTN Planning")
## @ace_description("A precondition (world-state key, operator, value) the method needs to be chosen.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$UHTNPlanner.add_method_condition({task_name}, {method_id}, {key}, {op}, {value})")
func add_method_condition(task_name: String, method_id: String, key: String, op: String, value) -> void:
	var method: HTNMethod = _find_method(task_name, method_id)
	if method != null:
		var c: HTNCondition = HTNCondition.new()
		c.key = key
		c.op = op
		c.value = value
		method.conditions.append(c)

## @ace_action
## @ace_name("Add Method Subtask")
## @ace_category("UHTN Planning")
## @ace_description("Appends a subtask (primitive or compound) to a method, in order.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$UHTNPlanner.add_method_subtask({task_name}, {method_id}, {subtask})")
func add_method_subtask(task_name: String, method_id: String, subtask: String) -> void:
	var method: HTNMethod = _find_method(task_name, method_id)
	if method != null:
		method.subtasks.append(subtask)

## @ace_action
## @ace_name("Add Scorer Input")
## @ace_category("UHTN Planning")
## @ace_description("Feeds a world-state key through a response curve (linear / inverse / quadratic / inverse_quadratic / logistic / threshold / bell) into a named scorer. A scorer is the weighted average of its inputs.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$UHTNPlanner.add_scorer_input({scorer_id}, {input_key}, {curve}, {weight}, {center}, {slope})")
func add_scorer_input(scorer_id: String, input_key: String, curve: String, weight: float, center: float, slope: float) -> void:
	if not scorers.has(scorer_id):
		scorers[scorer_id] = []
	scorers[scorer_id].append({"input": input_key, "curve": curve, "weight": weight, "center": center, "slope": slope})

## @ace_action
## @ace_name("Set Method Scorer")
## @ace_category("UHTN Planning")
## @ace_description("Binds a utility scorer to a method - the method is then ranked by the scorer's LIVE value at plan time instead of its fixed utility.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$UHTNPlanner.set_method_scorer({task_name}, {method_id}, {scorer_id})")
func set_method_scorer(task_name: String, method_id: String, scorer_id: String) -> void:
	var method: HTNMethod = _find_method(task_name, method_id)
	if method != null:
		method.scorer = scorer_id

## @ace_action
## @ace_name("Clear Task Network")
## @ace_category("UHTN Planning")
## @ace_description("Wipes all tasks, methods, and scorers (keeps world state).")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$UHTNPlanner.clear_network()")
func clear_network() -> void:
	primitives.clear()
	compounds.clear()
	scorers.clear()

## @ace_action
## @ace_name("Load Plan Resource")
## @ace_category("UHTN Planning")
## @ace_description("Loads a UHTNPlanResource (.tres): its tasks, methods, preconditions, and scorer inputs replace the current network, and its root task becomes the goal. Fires On Plan Loaded.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$UHTNPlanner.load_plan({resource})")
func load_plan(resource: Resource) -> void:
	if resource == null:
		return
	clear_network()
	for row: Dictionary in resource.get("tasks") if resource.get("tasks") is Array else []:
		if str(row.get("kind", "primitive")) == "compound":
			add_compound(str(row.get("name", "")))
		else:
			add_primitive(str(row.get("name", "")))
	for row: Dictionary in resource.get("methods") if resource.get("methods") is Array else []:
		var task: String = str(row.get("task", ""))
		var method_id: String = str(row.get("method", ""))
		add_compound(task)
		add_method(task, method_id, _to_number(row.get("utility", 0.0)))
		var scorer: String = str(row.get("scorer", "")).strip_edges()
		if not scorer.is_empty():
			set_method_scorer(task, method_id, scorer)
		for subtask: String in str(row.get("subtasks", "")).split(",", false):
			add_method_subtask(task, method_id, subtask.strip_edges())
	for row: Dictionary in resource.get("conditions") if resource.get("conditions") is Array else []:
		var bound: HTNMethod = _find_method_anywhere(str(row.get("method", "")))
		if bound != null:
			var c: HTNCondition = HTNCondition.new()
			c.key = str(row.get("key", ""))
			c.op = str(row.get("op", "=="))
			c.value = row.get("value", null)
			bound.conditions.append(c)
	for row: Dictionary in resource.get("scorer_inputs") if resource.get("scorer_inputs") is Array else []:
		add_scorer_input(str(row.get("scorer", "")), str(row.get("input", "")), str(row.get("curve", "linear")), _to_number(row.get("weight", 1.0)), _to_number(row.get("center", 0.5)), _to_number(row.get("slope", 0.2)))
	var loaded_root: String = str(resource.get("root_task")) if resource.get("root_task") != null else ""
	if not loaded_root.strip_edges().is_empty():
		root_task = loaded_root
	plan_loaded.emit(str(resource.get("plan_name")) if resource.get("plan_name") != null else "")

## @ace_action
## @ace_name("Request Plan")
## @ace_category("UHTN Planning")
## @ace_description("Decomposes the root task into a plan (best-ranked methods win) and starts the first task.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$UHTNPlanner.request_plan()")
func request_plan() -> void:
	plan = _decompose(root_task, 0)
	plan_index = 0
	if plan.is_empty():
		plan_failed.emit()
	else:
		task_started.emit(str(plan[0]))

## @ace_action
## @ace_name("Mark Task Complete")
## @ace_category("UHTN Planning")
## @ace_description("Advances to the next task, or fires On Plan Complete at the end.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$UHTNPlanner.mark_complete()")
func mark_complete() -> void:
	if plan_index >= plan.size():
		return
	plan_index += 1
	if plan_index >= plan.size():
		plan = []
		plan_index = 0
		plan_complete.emit()
	else:
		task_started.emit(str(plan[plan_index]))

## @ace_action
## @ace_name("Mark Task Failed")
## @ace_category("UHTN Planning")
## @ace_description("Re-plans from the root (or fires On Plan Failed if auto-replan is off).")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$UHTNPlanner.mark_failed()")
func mark_failed() -> void:
	if auto_replan_on_fail:
		request_plan()
	else:
		plan = []
		plan_index = 0
		plan_failed.emit()

## @ace_action
## @ace_name("Force Task")
## @ace_category("UHTN Planning")
## @ace_description("Pushes a task to the front of the plan and starts it - the scripted-override escape hatch (cutscene beats, staggers).")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$UHTNPlanner.force_task({task_name})")
func force_task(task_name: String) -> void:
	plan.insert(plan_index, task_name)
	task_started.emit(task_name)

## @ace_action
## @ace_name("Invalidate Plan")
## @ace_category("UHTN Planning")
## @ace_description("Drops the current plan so the next Request Plan rebuilds it.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$UHTNPlanner.invalidate_plan()")
func invalidate_plan() -> void:
	plan = []
	plan_index = 0

## @ace_condition
## @ace_name("Has Plan")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$UHTNPlanner.has_plan()")
func has_plan() -> bool:
	return plan_index < plan.size()

## @ace_condition
## @ace_name("Current Task Is")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$UHTNPlanner.current_task_is({task_name})")
func current_task_is(task_name: String) -> bool:
	return current_task() == task_name

## @ace_expression
## @ace_name("Current Task")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$UHTNPlanner.current_task()")
func current_task() -> String:
	return str(plan[plan_index]) if plan_index < plan.size() else ""

## @ace_expression
## @ace_name("Plan Length")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$UHTNPlanner.plan_length()")
func plan_length() -> int:
	return plan.size()

## @ace_expression
## @ace_name("Plan Task At")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$UHTNPlanner.plan_task_at({index})")
func plan_task_at(index: int) -> String:
	return str(plan[index]) if index >= 0 and index < plan.size() else ""

## @ace_expression
## @ace_name("World Value")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$UHTNPlanner.world_value({key})")
func world_value(key: String) -> Variant:
	return world_state.get(key, 0)

## @ace_expression
## @ace_name("Scorer Value")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$UHTNPlanner.scorer_value({scorer_id})")
func scorer_value(scorer_id: String) -> float:
	return _evaluate_scorer(scorer_id)

func _ready() -> void:
	if plan_resource != null:
		load_plan(plan_resource)

func _to_number(value) -> float:
	if value is float or value is int:
		return float(value)
	return str(value).to_float()

func _loose_equal(a, b) -> bool:
	if (a is float or a is int) and (b is float or b is int):
		return is_equal_approx(float(a), float(b))
	return str(a) == str(b)

func _compare_values(a, op: String, b) -> bool:
	if op == "==": return _loose_equal(a, b)
	if op == "!=": return not _loose_equal(a, b)
	if op == "<": return _to_number(a) < _to_number(b)
	if op == "<=": return _to_number(a) <= _to_number(b)
	if op == ">": return _to_number(a) > _to_number(b)
	if op == ">=": return _to_number(a) >= _to_number(b)
	return false

func _conditions_hold(conditions: Array) -> bool:
	for condition: HTNCondition in conditions:
		var actual: Variant = world_state.get(condition.key, null)
		if not _compare_values(actual, condition.op, condition.value):
			return false
	return true

func _curve_score(curve: String, x: float, center: float, slope: float) -> float:
	# Maps a world-state input (clamped 0-1) through a named response curve - the Utility AI half.
	var v: float = clampf(x, 0.0, 1.0)
	match curve:
		"linear": return v
		"inverse": return 1.0 - v
		"quadratic": return v * v
		"inverse_quadratic": return 1.0 - v * v
		"logistic": return 1.0 / (1.0 + exp(-maxf(slope, 0.001) * 10.0 * (v - center)))
		"threshold": return 1.0 if v >= center else 0.0
		"bell":
			var d: float = (v - center) / maxf(slope, 0.001)
			return exp(-d * d)
	return v

func _evaluate_scorer(scorer_id: String) -> float:
	# A scorer's live value: the weighted average of its inputs, each read from world state and
	# mapped through its curve. Unknown scorer or zero total weight scores 0.
	var inputs: Array = scorers.get(scorer_id, [])
	if inputs.is_empty():
		return 0.0
	var total: float = 0.0
	var weight_sum: float = 0.0
	for entry: Dictionary in inputs:
		var weight: float = _to_number(entry.get("weight", 1.0))
		var x: float = _to_number(world_state.get(str(entry.get("input", "")), 0.0))
		total += _curve_score(str(entry.get("curve", "linear")), x, _to_number(entry.get("center", 0.5)), _to_number(entry.get("slope", 0.2))) * weight
		weight_sum += absf(weight)
	return total / weight_sum if weight_sum > 0.0 else 0.0

func _method_rank(method: HTNMethod) -> float:
	# A method's rank at plan time: its scorer's live value when one is bound, else its fixed utility.
	if not method.scorer.is_empty() and scorers.has(method.scorer):
		return _evaluate_scorer(method.scorer)
	return method.utility

func _decompose(task_name: String, depth: int) -> Array:
	# Decompose a task into an ordered list of primitive task names. At each compound the
	# applicable methods (preconditions satisfied) are tried in descending RANK order - the
	# utility-driven part - backtracking to the next method when a subtask cannot decompose.
	if depth > 64:
		return []
	if primitives.has(task_name):
		return [task_name]
	if not compounds.has(task_name):
		return []
	var applicable: Array = []
	for method: HTNMethod in compounds[task_name]:
		if _conditions_hold(method.conditions):
			applicable.append(method)
	applicable.sort_custom(func(a: HTNMethod, b: HTNMethod) -> bool: return _method_rank(a) > _method_rank(b))
	for method: HTNMethod in applicable:
		var result: Array = []
		var ok: bool = true
		for subtask: String in method.subtasks:
			var sub: Array = _decompose(subtask, depth + 1)
			if sub.is_empty():
				ok = false
				break
			result.append_array(sub)
		if ok:
			return result
	return []

# UHTN Planning: utility-driven HTN in one behavior. EITHER drop a UHTNPlanResource (.tres of Inspector grids) onto Plan Resource, OR build in events (Add Primitive / Add Compound / Add Method / Add Method Condition / Add Method Subtask). Rank methods LIVE with Utility AI: Add Scorer Input feeds a world-state key through a response curve into a named scorer, Set Method Scorer binds it - the best-scoring applicable method wins at each compound (with backtracking); a method without a scorer uses its fixed utility. Feed facts with Set World State, call Request Plan, run the Current Task, then Mark Complete / Mark Failed. Triggers: On Task Started, On Plan Complete, On Plan Failed, On Plan Loaded.
