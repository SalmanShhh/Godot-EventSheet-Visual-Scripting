# Godot EventSheets — HTN Agent behavior planner test.
# Drives the generated HTNAgent at runtime: builds a tiny task network, then checks that
# decomposition picks the highest-utility APPLICABLE method (with preconditions), executes
# the plan task-by-task with the right triggers, and fails cleanly when nothing applies.
@tool
class_name HTNAgentTest
extends RefCounted

const PACK := "res://eventsheet_addons/htn_agent/htn_agent_behavior.gd"


static func run() -> bool:
	var passed: bool = true
	var script: GDScript = load(PACK) as GDScript
	if not _check("HTN pack loads", script != null, true):
		return false
	var agent: Node = script.new()

	# Network: "engage" decomposes into the fight method (draw + attack) normally, OR the
	# higher-utility retreat method (flee) when health < 30.
	agent.add_primitive("draw_weapon")
	agent.add_primitive("attack")
	agent.add_primitive("flee")
	agent.add_compound("engage")
	agent.add_method("engage", "fight", 1.0)
	agent.add_method_subtask("engage", "fight", "draw_weapon")
	agent.add_method_subtask("engage", "fight", "attack")
	agent.add_method("engage", "retreat", 5.0)
	agent.add_method_condition("engage", "retreat", "health", "<", 30)
	agent.add_method_subtask("engage", "retreat", "flee")
	agent.root_task = "engage"

	var started: Array = []
	agent.task_started.connect(func(task_name: String) -> void: started.append(task_name))
	var completed: Array = [false]
	agent.plan_complete.connect(func() -> void: completed[0] = true)

	# Healthy: retreat's precondition fails, so the fight method is the only applicable one.
	agent.set_world_state("health", 100)
	agent.request_plan()
	passed = _check("healthy agent decomposes to the fight method", agent.plan, ["draw_weapon", "attack"]) and passed
	passed = _check("first task started is draw_weapon", agent.current_task(), "draw_weapon") and passed
	passed = _check("On Task Started fired for the first task", started, ["draw_weapon"]) and passed
	agent.mark_complete()
	passed = _check("Mark Complete advances to attack", agent.current_task(), "attack") and passed
	agent.mark_complete()
	passed = _check("finishing the last task fires On Plan Complete", completed[0], true) and passed
	passed = _check("has no plan once complete", agent.has_plan(), false) and passed

	# Hurt: retreat is now applicable AND higher-utility, so it wins over fight.
	agent.set_world_state("health", 10)
	agent.invalidate_plan()
	agent.request_plan()
	passed = _check("hurt agent picks the higher-utility applicable retreat", agent.plan, ["flee"]) and passed

	# A compound with no applicable method fails the plan.
	var failed: Array = [false]
	agent.plan_failed.connect(func() -> void: failed[0] = true)
	agent.clear_network()
	agent.add_compound("engage")
	agent.request_plan()
	passed = _check("a dead-end compound fires On Plan Failed", failed[0], true) and passed

	agent.free()
	return passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] htn_agent_test: %s" % label)
		return true
	print("[FAIL] htn_agent_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
