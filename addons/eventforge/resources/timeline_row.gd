# Godot EventSheets - TimelineRow resource
# A schedule as a block: "at 0.0s show Ready, at 1.0s show GO, at 1.2s start the round". Each
# step is a TimelineStep (time + one action); the compiler emits the steps in order with an
# `await get_tree().create_timer(<gap>).timeout` between beats, so the generated code is the
# plain await-chain a GDScript author would write - and reads top to bottom as the schedule.
# The whole block therefore suspends: it belongs inside a trigger event (the same rule as Wait).
@tool
class_name TimelineRow
extends Resource

@export var enabled: bool = true
## The beats, in schedule order (authoring keeps them sorted by `at`; emission trusts the order
## and only awaits FORWARD gaps, so an out-of-order step simply runs with no extra wait).
@export var steps: Array[TimelineStep] = []


## Returns the stable row kind identifier.
func get_row_kind() -> String:
	return "timeline"


## Appends a beat and keeps the schedule sorted by time (stable for equal times).
func add_step(at_seconds: float, action: Resource) -> TimelineStep:
	var step: TimelineStep = TimelineStep.new()
	step.at = at_seconds
	step.action = action
	steps.append(step)
	steps.sort_custom(func(left: TimelineStep, right: TimelineStep) -> bool: return left.at < right.at)
	return step
