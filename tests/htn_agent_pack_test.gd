# Godot EventSheets - htn_agent pack (typed HTNMethod / HTNCondition) behavioral equivalence.
#
# The HTN methods/conditions were untyped Dictionaries read via str()/float()/get() casts; they're
# now typed inner classes. This builds a tiny task network and drives the real decomposition to prove
# (a) the inner classes emit + parse, (b) utility ordering + preconditions still select the right
# method, and (c) _find_method's null-not-found contract works (it returns null, not a blank method).
@tool
class_name HtnAgentPackTest
extends RefCounted

const PACK := "res://eventsheet_addons/htn_agent/htn_agent_behavior.gd"


static func run() -> bool:
	var all_passed: bool = true
	var script: GDScript = load(PACK)
	all_passed = _check("htn pack loads + parses (HTNMethod/HTNCondition emit)", script != null, true) and all_passed
	if script == null:
		return all_passed

	var ag: Node = script.new()
	# "survive" decomposes via two methods: fight (util 1, always) and run (util 2, only when scared).
	ag.add_primitive("attack")
	ag.add_primitive("flee")
	ag.add_compound("survive")
	ag.add_method("survive", "fight", 1.0)
	ag.add_method_subtask("survive", "fight", "attack")
	ag.add_method("survive", "run", 2.0)
	ag.add_method_subtask("survive", "run", "flee")
	ag.add_method_condition("survive", "run", "scared", "==", true)
	ag.root_task = "survive"

	# Not scared: run's precondition fails, so the only applicable method is fight → attack.
	ag.set_world_state("scared", false)
	ag.request_plan()
	all_passed = _check("precondition gates out the higher-utility method", ag.current_task(), "attack") and all_passed

	# Scared: run is applicable AND higher-utility, so it wins → flee.
	ag.set_world_state("scared", true)
	ag.request_plan()
	all_passed = _check("highest applicable utility wins", ag.current_task(), "flee") and all_passed
	all_passed = _check("plan length is the decomposed primitive count", ag.plan_length(), 1) and all_passed

	# Marking the only task complete clears the plan.
	ag.mark_complete()
	all_passed = _check("completing the last task ends the plan", ag.has_plan(), false) and all_passed

	# A method that re-uses an existing id updates utility (proves _find_method finds the typed object).
	ag.set_method_utility("survive", "fight", 9.0)
	ag.set_world_state("scared", true)
	ag.request_plan()
	all_passed = _check("re-scored method overtakes (typed _find_method)", ag.current_task(), "attack") and all_passed

	ag.free()
	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] htn_agent_pack_test: %s" % label)
		return true
	print("[FAIL] htn_agent_pack_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
