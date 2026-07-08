class_name ChefPlannerDemo
extends Node2D

var __every_chef: float = 0.0

func _ready() -> void:
	$Chef/Planner.set_world_state("has_kitchen", true)
	$Chef/Planner.add_compound("make_meal")
	$Chef/Planner.add_primitive("gather")
	$Chef/Planner.add_primitive("cook")
	$Chef/Planner.add_primitive("serve")
	$Chef/Planner.add_method("make_meal", "cook_it", 1.0)
	$Chef/Planner.add_method_condition("make_meal", "cook_it", "has_kitchen", "==", true)
	$Chef/Planner.add_method_subtask("make_meal", "cook_it", "gather")
	$Chef/Planner.add_method_subtask("make_meal", "cook_it", "cook")
	$Chef/Planner.add_method_subtask("make_meal", "cook_it", "serve")
	$Chef/Planner.request_plan()

func _process(delta: float) -> void:
	__every_chef += delta
	if __every_chef >= maxf(1.0, 0.001) and $Chef/Planner.has_plan():
		__every_chef = fmod(__every_chef, maxf(1.0, 0.001))
		$Chef/Planner.mark_complete()
	$Screen.text = "CHEF PLANNER (HTN)
	task: %s
	steps left: %d" % [$Chef/Planner.current_task(), $Chef/Planner.plan_length()]

# [b]Chef Planner (HTN Agent)[/b] - a self-driving planner, no input. The compound task make_meal decomposes (via a method whose world-state condition holds) into an ordered plan gather -> cook -> serve; a tick marks each primitive task complete and walks the plan to the end. Add tasks + methods, Request Plan, Mark Task Complete - the whole hierarchical-planning loop. Attach an HTN Agent to any node and give it your own task network.
