@tool
class_name ShooterTourTest
extends RefCounted

# EventForge - the top-down shooter tour: ten steps, each checked against the line its rows write.
#
# The finished showcase's own main sheet is the proof: every step that has a check must pass on it,
# and none may pass on an empty sheet - so a check can neither be satisfied by nothing nor miss the
# row it teaches. The showcase the last step opens must ship.

const SUPPORT := preload("res://tests/support.gd")


static func run() -> bool:
	var finished: EventSheetResource = GDScriptImporter.new().import_external(
		"res://demo/showcase/top_down_shooter/top_down_shooter.gd")
	var empty: EventSheetResource = EventSheetResource.new()
	empty.host_class = "Node2D"
	var passed_on_finished: Array = []
	var passed_on_empty: Array = []
	var checked: int = 0
	for step: Dictionary in EventSheetShooterTour.steps():
		var check: Callable = step.get("check", Callable())
		if not check.is_valid():
			continue
		checked += 1
		if bool(check.call(finished)):
			passed_on_finished.append(str(step["title"]))
		if bool(check.call(empty)):
			passed_on_empty.append(str(step["title"]))
	var titles: Array = []
	for step: Dictionary in EventSheetShooterTour.steps():
		titles.append(str(step["title"]))
	return SUPPORT.pins("shooter_tour_test", [
		["ten steps, in the order the game is built", titles, ["The player faces the mouse", "Click fires",
			"A bullet appears at the player", "Monsters keep coming", "Keep a score",
			"A monster with no health explodes", "Boom, and a point", "Show the score",
			"Read what you wrote", "Play the finished game"]],
		["every checked step passes on the finished game", passed_on_finished.size(), checked],
		["none passes on an empty sheet", passed_on_empty, []],
		["the showcase it ends at ships", ResourceLoader.exists(EventSheetShooterTour.SHOWCASE_SCENE), true],
	])
