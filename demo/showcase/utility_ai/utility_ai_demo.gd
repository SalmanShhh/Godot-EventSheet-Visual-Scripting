class_name GuardBrainDemo
extends Node2D

@export var t: float = 0.0
@export var threat: float = 0.0
@export var stamina: float = 1.0

func _ready() -> void:
	$Guard/Brain.add_action("patrol", 0.0, true, 0.3)
	$Guard/Brain.add_action("chase", 0.0, true, 1.0)
	$Guard/Brain.add_action("flee", 0.0, false, 1.2)
	$Guard/Brain.add_consideration("patrol", "threat", "inverse", 1.0, 0.5, 1.0)
	$Guard/Brain.add_consideration("chase", "threat", "quadratic", 1.0, 0.5, 1.0)
	$Guard/Brain.add_consideration("flee", "threat", "logistic", 1.0, 0.8, 8.0)
	$Guard/Brain.add_consideration("flee", "stamina", "inverse", 0.6, 0.5, 1.0)

func _process(delta: float) -> void:
	t += delta
	threat = 0.5 + 0.5 * sin(t * 0.8)
	stamina = 0.5 + 0.5 * cos(t * 0.5)
	$Guard/Brain.set_input("threat", threat)
	$Guard/Brain.set_input("stamina", stamina)
	$Guard/Brain.evaluate()
	$Screen.text = "GUARD BRAIN (Utility AI)
	action: %s  (score %.2f)
	threat %.2f   stamina %.2f" % [$Guard/Brain.current_action(), $Guard/Brain.decision_score(), threat, stamina]

# [b]Guard Brain (Utility AI)[/b] - a self-driving guard with no input. The UtilityBrain scores three actions (patrol / chase / flee) from a threat signal that rises and falls plus a stamina wave; a response curve shapes each score, and the highest wins. Set Input -> Evaluate -> read Current Action is the whole loop - the addon drives a real decision maker, not a fixed state machine. Attach a UtilityBrain to any node and score your own actions the same way.
