## A small hand-written script whose whole job is to give the ACE picker's Functions page
## something real to enumerate: two PUBLISHED verbs (an action and a condition, each with one
## parameter) and two plain helpers that were never exposed as ACEs.
class_name PickerFunctionsFixture
extends Node

var score: int = 0
var round_open: bool = false


## @ace_action
## @ace_name("Award Points")
## @ace_description("Adds points to the score.")
## @ace_codegen_template("award_points({amount})")
func award_points(amount: float) -> void:
	score += int(amount)


## @ace_condition
## @ace_name("Round Is Ready")
## @ace_description("True when the round can start.")
## @ace_codegen_template("round_is_ready({enabled})")
func round_is_ready(enabled: bool) -> bool:
	return enabled and round_open


func reset_score() -> void:
	score = 0


func doubled_score() -> int:
	return score * 2
