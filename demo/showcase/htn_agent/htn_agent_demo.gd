class_name ChefPlannerDemo
extends Node2D
## [b]Chef Planner (HTN Agent)[/b] - a self-driving planner, no input. The compound task make_meal decomposes (via a method whose world-state condition holds) into an ordered plan gather -> cook -> serve; a tick marks each primitive task complete and walks the plan to the end. Add tasks + methods, Request Plan, Mark Task Complete - the whole hierarchical-planning loop. Attach an HTN Agent to any node and give it your own task network.

@onready var planner: HTNAgent = $Chef/Planner

var __every_chef: float = 0.0

func _ready() -> void:
	planner.set_world_state("has_kitchen", true)
	planner.add_compound("make_meal")
	planner.add_primitive("gather")
	planner.add_primitive("cook")
	planner.add_primitive("serve")
	planner.add_method("make_meal", "cook_it", 1.0)
	planner.add_method_condition("make_meal", "cook_it", "has_kitchen", "==", true)
	planner.add_method_subtask("make_meal", "cook_it", "gather")
	planner.add_method_subtask("make_meal", "cook_it", "cook")
	planner.add_method_subtask("make_meal", "cook_it", "serve")
	planner.request_plan()

func _process(delta: float) -> void:
	__every_chef += delta
	if __every_chef >= 1.0 and planner.has_plan():
		__every_chef = fmod(__every_chef, 1.0)
		planner.mark_complete()
	$Screen.text = "CHEF PLANNER (HTN)
	task: %s
	steps left: %d" % [$Chef/Planner.current_task(), $Chef/Planner.plan_length()]
