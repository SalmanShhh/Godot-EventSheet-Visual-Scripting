# EventForge - runtime truth for the Interaction behavior and the Phase Cycle autoload.
#
# Both packs are instantiated from their SHIPPED .gd and driven headless, so what is pinned here is
# the behavior a game actually gets, not a builder's intent.
#
# Interaction needs a scene tree to scan groups, and run_tests.gd has none (its _init runs before
# the main loop exists), so Focus Nearest Interactable itself is out of reach here - it is written to
# bail out when it is not inside a tree. Everything downstream of the pick IS treeless and is what
# matters: focus is owned by one internal (_set_focus), so this pins that the focus-changed trigger
# is an EDGE (once per real change, not once per frame - Focus Nearest Interactable re-picks the same
# node every tick), that Has Focus / Focused Node read it, and that Interact With Focus calls the
# thing's own interact() and fires On Interacted.
#
# Phase Cycle is fully treeless: advance() is the clock the autoload's own _process feeds, so calling
# it directly is the same code path a running game takes, one frame at a time.
@tool
class_name InteractionPhaseTest
extends RefCounted


## A stand-in interactable: the door/chest side of the story is a plain function named interact().
class InteractThing extends Node:
	var interact_count: int = 0

	func interact() -> void:
		interact_count += 1


static func run() -> bool:
	var ok: bool = true
	ok = _run_interaction(ok)
	ok = _run_phase_cycle(ok)
	return ok


static func _run_interaction(ok: bool) -> bool:
	var script: Script = load("res://eventsheet_addons/interaction/interaction_behavior.gd")
	ok = _check(ok, script != null, true, "the Interaction pack script loads")
	if script == null:
		return false
	var behavior: Node = script.new() as Node
	ok = _check(ok, behavior != null, true, "the Interaction behavior instantiates")
	if behavior == null:
		return false

	var focus_events: Array = []
	var interact_events: Array = []
	behavior.connect("on_focus_changed", func(node: Variant) -> void: focus_events.append(node))
	behavior.connect("on_interacted", func(node: Variant) -> void: interact_events.append(node))

	ok = _check(ok, behavior.call("has_focus"), false, "nothing is focused before anything is near")
	ok = _check(ok, behavior.call("focused_node"), null, "Focused Node reads nothing while unfocused")

	var chest: InteractThing = InteractThing.new()
	behavior.call("_set_focus", chest)
	ok = _check(ok, behavior.call("has_focus"), true, "focusing a thing turns Has Focus on")
	ok = _check(ok, behavior.call("focused_node"), chest, "Focused Node reads the focused thing")
	ok = _check(ok, focus_events.size(), 1, "focusing fires On Focus Changed once")
	ok = _check(ok, focus_events[0], chest, "On Focus Changed carries the newly focused node")

	# The edge: Focus Nearest Interactable re-picks the SAME node every frame it is run.
	behavior.call("_set_focus", chest)
	ok = _check(ok, focus_events.size(), 1, "re-focusing the same thing fires nothing")

	behavior.call("interact_with_focus")
	ok = _check(ok, chest.interact_count, 1, "Interact With Focus calls the thing's own interact()")
	ok = _check(ok, interact_events.size(), 1, "Interact With Focus fires On Interacted once")
	ok = _check(ok, interact_events[0], chest, "On Interacted carries the thing interacted with")

	# A thing with no interact() of its own is still a valid interaction - the sheet handles it.
	var plain: Node = Node.new()
	behavior.call("_set_focus", plain)
	ok = _check(ok, focus_events.size(), 2, "moving focus to another thing fires On Focus Changed")
	behavior.call("interact_with_focus")
	ok = _check(ok, interact_events.size(), 2, "a thing without interact() still fires On Interacted")
	ok = _check(ok, chest.interact_count, 1, "the thing left behind is not interacted with again")

	behavior.call("clear_focus")
	ok = _check(ok, behavior.call("has_focus"), false, "Clear Focus drops the focus")
	ok = _check(ok, focus_events.size(), 3, "Clear Focus fires On Focus Changed")
	ok = _check(ok, focus_events[2], null, "leaving range hands On Focus Changed nothing")
	behavior.call("interact_with_focus")
	ok = _check(ok, interact_events.size(), 2, "interacting with nothing does nothing")

	var source: String = FileAccess.get_file_as_string("res://eventsheet_addons/interaction/interaction_behavior.gd")
	ok = _check(ok, source.contains("class_name InteractionBehavior"), true, "the Interaction pack keeps its class name")
	ok = _check(ok, FileAccess.file_exists("res://docs/Addons/Interaction.md"), true, "the Interaction guide ships")

	plain.free()
	chest.free()
	behavior.free()
	return ok


static func _run_phase_cycle(ok: bool) -> bool:
	var script: Script = load("res://eventsheet_addons/phase_cycle/phase_cycle_addon.gd")
	ok = _check(ok, script != null, true, "the Phase Cycle pack script loads")
	if script == null:
		return false
	var phases: Node = script.new() as Node
	ok = _check(ok, phases != null, true, "the Phase Cycle addon instantiates")
	if phases == null:
		return false

	var changes: Array = []
	phases.connect("on_phase_changed", func(previous: Variant, next: Variant) -> void: changes.append([previous, next]))

	phases.call("cycle_phases", "day,night", 60.0)
	ok = _check(ok, phases.call("current_phase"), "day", "the cycle starts on the first phase")
	ok = _check(ok, phases.call("phases_count"), 2, "the comma-separated list parses into two phases")
	ok = _check(ok, changes.size(), 1, "starting the cycle announces the first phase")
	ok = _check(ok, changes[0][1], "day", "the opening announcement names the first phase")
	ok = _check(ok, phases.call("phase_is", "day"), true, "Phase Is matches the current phase")
	ok = _check(ok, phases.call("phase_is", "night"), false, "Phase Is rejects a phase that is not current")

	# One second short of the roll: still day, and nearly all the way through it.
	phases.call("advance", 59.0)
	ok = _check(ok, phases.call("current_phase"), "day", "the phase holds until its seconds are up")
	ok = _check(ok, changes.size(), 1, "no roll means no On Phase Changed")
	ok = _check(ok, snappedf(float(phases.call("phase_progress")), 0.001), 0.983, "Phase Progress reads 0-1 through the phase")

	phases.call("advance", 2.0)
	ok = _check(ok, phases.call("current_phase"), "night", "crossing the length rolls to the next phase")
	ok = _check(ok, changes.size(), 2, "the roll fires On Phase Changed exactly once")
	ok = _check(ok, changes[1][0], "day", "On Phase Changed carries the phase left behind")
	ok = _check(ok, changes[1][1], "night", "On Phase Changed carries the phase entered")
	ok = _check(ok, snappedf(float(phases.call("phase_progress")), 0.001), 0.017, "the leftover second carries into the new phase")

	phases.call("advance", 60.0)
	ok = _check(ok, phases.call("current_phase"), "day", "the last phase wraps back to the first")
	ok = _check(ok, changes.size(), 3, "the wrap is a phase change like any other")

	phases.call("stop_cycle")
	phases.call("advance", 600.0)
	ok = _check(ok, phases.call("current_phase"), "day", "Stop Cycle halts the clock")
	ok = _check(ok, changes.size(), 3, "a stopped cycle fires nothing")

	var source: String = FileAccess.get_file_as_string("res://eventsheet_addons/phase_cycle/phase_cycle_addon.gd")
	ok = _check(ok, source.contains("class_name PhaseCycleAddon"), true, "the Phase Cycle pack keeps its class name")
	ok = _check(ok, source.contains("func _process(delta: float) -> void:"), true, "the autoload drives its own clock")
	ok = _check(ok, FileAccess.file_exists("res://docs/Addons/Phase-Cycle.md"), true, "the Phase Cycle guide ships")

	phases.free()
	return ok


static func _check(ok: bool, actual: Variant, expected: Variant, label: String = "") -> bool:
	if actual == expected:
		return ok
	print("  [FAIL] interaction_phase_test: %s" % label)
	print("    expected: %s" % str(expected))
	print("    actual:   %s" % str(actual))
	return false
