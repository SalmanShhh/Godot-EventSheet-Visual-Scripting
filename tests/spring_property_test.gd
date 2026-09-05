# Godot EventSheets - a spring under ANY property of the host (the Spring pack's breadth half).
#
# The pack's named springs are numbers a row reads back; these are springs that write themselves
# onto the host every frame, addressed by the property path the Inspector shows. This loads the
# COMPILED pack and drives the real integrator by hand - no scene tree, no physics - to prove the
# four things a row promises: a colour settles ON its target, a bump is velocity and nothing else,
# a clamp stops the value at the wall, and a bank with nothing left to settle gives the frame back.
@tool
class_name SpringPropertyTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const PACK := "res://eventsheet_addons/spring/spring_behavior.gd"
const PREFIX := "spring_property_test"

## The most ticks a settle is given before the test calls it stuck. Generous on purpose: the point
## of the row is that it settles at all and lands on the target, not that it does so in a set frame.
const TICK_BUDGET: int = 600


static func run() -> bool:
	var script: GDScript = load(PACK)
	if script == null:
		return SUPPORT.check(PREFIX, "the spring pack loads", false, true)
	var all_passed: bool = true
	all_passed = _a_colour_settles(script) and all_passed
	all_passed = _a_bump_returns(script) and all_passed
	all_passed = _a_clamp_holds(script) and all_passed
	return all_passed


## A spring on the host's modulate: four channels, one entry, and it lands on the colour asked for.
## The tick parks itself the moment nothing is left moving, which is what makes a settled spring
## cost a phone nothing.
static func _a_colour_settles(script: GDScript) -> bool:
	var behavior: Node = script.new()
	var host: Node2D = Node2D.new()
	behavior.host = host
	behavior.spring_property_to("modulate", Color(1.0, 0.0, 0.0, 1.0))
	var moving_at_once: bool = not behavior.property_spring_is_settled("modulate")
	var ticks: int = 0
	for _index: int in TICK_BUDGET:
		behavior._process(0.016)
		ticks += 1
		if behavior.property_spring_is_settled("modulate"):
			break
	var landed: Color = host.modulate
	var passed: bool = SUPPORT.pins(PREFIX, [
		["a sprung property is not settled", moving_at_once, true],
		["the property lands on the target", landed.is_equal_approx(Color(1.0, 0.0, 0.0, 1.0)), true],
		["it settles inside the tick budget", ticks < TICK_BUDGET, true],
		["a settled bank gives the frame back", behavior.is_processing(), false],
		["Spring Value Of reads the first number", snappedf(behavior.property_spring_value("modulate"), 0.001), 1.0],
		["nothing is left moving", snappedf(behavior.property_spring_velocity("modulate"), 0.001), 0.0],
		["a property nothing sprang is settled", behavior.property_spring_is_settled("scale"), true],
	])
	behavior.free()
	host.free()
	return passed


## A bump is velocity and nothing else: the property leaves where it was, and comes back to it,
## because a bump never moves the target.
static func _a_bump_returns(script: GDScript) -> bool:
	var behavior: Node = script.new()
	var host: Node2D = Node2D.new()
	behavior.host = host
	host.rotation_degrees = 12.0
	behavior.bump_property("rotation_degrees", 30.0)
	var kicked: float = behavior.property_spring_velocity("rotation_degrees")
	behavior._process(0.016)
	var left_home: bool = host.rotation_degrees > 12.0
	for _index: int in TICK_BUDGET:
		behavior._process(0.016)
		if behavior.property_spring_is_settled("rotation_degrees"):
			break
	var passed: bool = SUPPORT.pins(PREFIX, [
		["a bump is velocity", snappedf(kicked, 0.001), 30.0],
		["the property leaves where it was", left_home, true],
		["and comes back to it", snappedf(host.rotation_degrees, 0.01), 12.0],
	])
	behavior.free()
	host.free()
	return passed


## A clamped spring stops at the wall rather than pushing through it - and the same number on both
## sides is how a row takes the fence off again.
static func _a_clamp_holds(script: GDScript) -> bool:
	var behavior: Node = script.new()
	var host: Node2D = Node2D.new()
	behavior.host = host
	behavior.clamp_property_spring("position:x", 0.0, 10.0)
	behavior.spring_property_to("position:x", 100.0)
	for _index: int in TICK_BUDGET:
		behavior._process(0.016)
		if behavior.property_spring_is_settled("position:x"):
			break
	var held: float = host.position.x
	behavior.clamp_property_spring("position:x", 0.0, 0.0)
	behavior.spring_property_to("position:x", 40.0)
	for _index: int in TICK_BUDGET:
		behavior._process(0.016)
		if behavior.property_spring_is_settled("position:x"):
			break
	var passed: bool = SUPPORT.pins(PREFIX, [
		["a clamped spring stops at the wall", snappedf(held, 0.01), 10.0],
		["a clamped spring still settles", behavior.property_spring_is_settled("position:x"), true],
		["one number on both sides takes the fence off", snappedf(host.position.x, 0.01), 40.0],
	])
	behavior.free()
	host.free()
	return passed
