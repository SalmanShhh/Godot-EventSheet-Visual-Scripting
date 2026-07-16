class_name GuardPostDemo
extends Node2D

var __every_uhtn_replan: float = 0.0
var __every_uhtn_walk: float = 0.0
var __every_uhtn_salute: float = 0.0

func _process(delta: float) -> void:
	$Guard/Planner.set_world_state("closeness", 1.0 - clampf($Guard.position.distance_to($Prowler.position) / 600.0, 0.0, 1.0))
	$Guard/Planner.set_world_state("health", 0.5 + 0.5 * sin(Time.get_ticks_msec() / 4000.0))
	$Guard/Planner.set_world_state("hurt", 1 if $Guard/Planner.world_value("health") < 0.3 else 0)
	__every_uhtn_replan += delta
	if __every_uhtn_replan >= maxf(1.0, 0.001):
		__every_uhtn_replan = fmod(__every_uhtn_replan, maxf(1.0, 0.001))
		$Guard/Planner.request_plan()
	__every_uhtn_walk += delta
	if __every_uhtn_walk >= maxf(3.0, 0.001) and $Guard/Planner.has_plan():
		__every_uhtn_walk = fmod(__every_uhtn_walk, maxf(3.0, 0.001))
		$Guard/Planner.mark_complete()
	__every_uhtn_salute += delta
	if __every_uhtn_salute >= maxf(9.0, 0.001):
		__every_uhtn_salute = fmod(__every_uhtn_salute, maxf(9.0, 0.001))
		$Guard/Planner.force_task("salute")
	$Prowler.position = Vector2(576.0 + 500.0 * sin(Time.get_ticks_msec() / 3000.0), 360.0)
	$Screen.text = "GUARD POST (UHTN PLANNING)
	task: %s
	aggro: %.2f   fear: %.2f" % [$Guard/Planner.current_task(), $Guard/Planner.scorer_value("aggro"), $Guard/Planner.scorer_value("fear")]

# [b]Guard Post (UHTN Planning)[/b] - Utility AI steering an HTN, fully data-driven. The whole plan lives in guard_plan.tres (Inspector grids: tasks, methods, preconditions, scorer curves) dropped on the planner's Plan Resource slot. The prowler sweeps in and out; a closeness fact through a linear curve ranks the chase method LIVE, so far = watch (fixed utility 0.25) and near = chase, with no re-authoring. Oscillating health feeds a fear scorer (inverse curve) whose flee method only competes while the hurt precondition holds. Every 9s Force Task pushes a scripted salute beat. The HUD shows both scorer values ticking - tune the curves in the .tres and watch behavior change.
