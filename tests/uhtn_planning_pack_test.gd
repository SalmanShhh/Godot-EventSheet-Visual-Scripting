# Godot EventSheets - UHTN Planning: the combined addon where Utility AI ranks HTN methods. Pins the
# core promise: methods bound to a response-curve scorer are ranked by the LIVE world state at plan time
# (the same agent flips strategy when the world changes, with NO re-authoring), static utility stays the
# fallback, decomposition backtracks past un-decomposable methods, and the whole network - tasks, methods,
# preconditions, scorers - loads from a UHTNPlanResource (.tres) authored in Inspector grids.
@tool
class_name UHTNPlanningPackTest
extends RefCounted

const PLANNER := "res://eventsheet_addons/uhtn_planning/uhtn_planning_behavior.gd"
const RES := "res://eventsheet_addons/uhtn_plan_resource/uhtn_plan_resource.gd"


static func run() -> bool:
	var ok: bool = true
	var planner_script: GDScript = load(PLANNER)
	var res_script: GDScript = load(RES)
	ok = _check("UHTNPlanner + UHTNPlanResource load + parse", planner_script != null and res_script != null, true) and ok
	if planner_script == null or res_script == null:
		return ok

	# ── Utility-scored method ranking: the SAME network flips strategy with the world state ──
	var agent: Node = planner_script.new()
	agent.set("root_task", "root")
	agent.add_primitive("patrol_step")
	agent.add_primitive("chase_step")
	agent.add_compound("root")
	agent.add_method("root", "m_patrol", 0.2)
	agent.add_method_subtask("root", "m_patrol", "patrol_step")
	agent.add_method("root", "m_chase", 0.0)
	agent.add_method_subtask("root", "m_chase", "chase_step")
	# The chase method is ranked by a LIVE scorer: closeness (inverse distance) drives aggression.
	agent.add_scorer_input("aggro", "closeness", "linear", 1.0, 0.5, 0.2)
	agent.set_method_scorer("root", "m_chase", "aggro")
	agent.set_world_state("closeness", 0.1)
	agent.request_plan()
	ok = _check("far away, the fixed-utility patrol wins (scorer 0.1 < 0.2)", agent.current_task(), "patrol_step") and ok
	agent.set_world_state("closeness", 0.9)
	agent.request_plan()
	ok = _check("up close, the SAME network flips to chase (scorer 0.9 > 0.2)", agent.current_task(), "chase_step") and ok

	# ── Curve shapes: threshold + inverse read from live world state via Scorer Value ──
	agent.add_scorer_input("fear", "health", "inverse", 1.0, 0.5, 0.2)
	agent.set_world_state("health", 0.25)
	ok = _check("an inverse curve scores 1 - x", is_equal_approx(agent.scorer_value("fear"), 0.75), true) and ok
	agent.add_scorer_input("panic", "health", "threshold", 1.0, 0.5, 0.2)
	ok = _check("a threshold curve is 0 below center", is_equal_approx(agent.scorer_value("panic"), 0.0), true) and ok

	# ── Preconditions + backtracking: a top-ranked method that cannot decompose falls through ──
	agent.clear_network()
	agent.add_primitive("hide_step")
	agent.add_compound("root")
	agent.add_method("root", "m_broken", 9.0)
	agent.add_method_subtask("root", "m_broken", "no_such_task")
	agent.add_method("root", "m_hide", 1.0)
	agent.add_method_subtask("root", "m_hide", "hide_step")
	agent.request_plan()
	ok = _check("backtracking skips the un-decomposable top method", agent.current_task(), "hide_step") and ok

	# ── Multi-step plan + lifecycle signals ──
	agent.clear_network()
	agent.add_primitive("take_cover")
	agent.add_primitive("shoot")
	agent.add_compound("root")
	agent.add_method("root", "m_cover_then_shoot", 1.0)
	agent.add_method_subtask("root", "m_cover_then_shoot", "take_cover")
	agent.add_method_subtask("root", "m_cover_then_shoot", "shoot")
	var fired: Array = []
	agent.plan_complete.connect(func() -> void: fired.append("complete"))
	agent.request_plan()
	ok = _check("a multi-subtask method plans in order", [agent.plan_task_at(0), agent.plan_task_at(1)], ["take_cover", "shoot"]) and ok
	agent.mark_complete()
	ok = _check("Mark Complete advances to the next task", agent.current_task(), "shoot") and ok
	agent.force_task("flinch")
	ok = _check("Force Task pushes a scripted task to the front", agent.current_task(), "flinch") and ok
	agent.mark_complete()
	agent.mark_complete()
	ok = _check("finishing the last task fires On Plan Complete", fired, ["complete"]) and ok

	# ── The data-driven path: a UHTNPlanResource loads the WHOLE network, scorers included ──
	var plan_res: Resource = res_script.new()
	plan_res.set("plan_name", "guard")
	plan_res.set("root_task", "root")
	plan_res.set("tasks", [
		{"name": "patrol_step", "kind": "primitive"},
		{"name": "chase_step", "kind": "primitive"},
		{"name": "root", "kind": "compound"}
	])
	plan_res.set("methods", [
		{"task": "root", "method": "m_patrol", "subtasks": "patrol_step", "scorer": "", "utility": 0.2},
		{"task": "root", "method": "m_chase", "subtasks": "chase_step", "scorer": "aggro", "utility": 0.0}
	])
	plan_res.set("conditions", [
		{"method": "m_chase", "key": "target_seen", "op": "==", "value": "1"}
	])
	plan_res.set("scorer_inputs", [
		{"scorer": "aggro", "input": "closeness", "curve": "linear", "weight": 1.0, "center": 0.5, "slope": 0.2}
	])
	var loader: Node = planner_script.new()
	var loaded_names: Array = []
	loader.plan_loaded.connect(func(plan_name: String) -> void: loaded_names.append(plan_name))
	loader.load_plan(plan_res)
	ok = _check("Load Plan Resource fires On Plan Loaded with the plan name", loaded_names, ["guard"]) and ok
	ok = _check("the resource's root task becomes the goal", str(loader.get("root_task")), "root") and ok
	loader.set_world_state("closeness", 0.9)
	loader.set_world_state("target_seen", 0)
	loader.request_plan()
	ok = _check("a failed precondition gates the chase method even at high score", loader.current_task(), "patrol_step") and ok
	loader.set_world_state("target_seen", 1)
	loader.request_plan()
	ok = _check("with the precondition met, the scorer-ranked chase wins", loader.current_task(), "chase_step") and ok

	agent.free()
	loader.free()
	return ok


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if str(actual) == str(expected):
		print("[PASS] uhtn_planning_pack_test: %s" % label)
		return true
	print("[FAIL] uhtn_planning_pack_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
