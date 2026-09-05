# Godot EventSheets - a spring under ANY property of the host (the Spring pack's breadth half).
#
# The pack's named springs are numbers a row reads back; these are springs that write themselves
# onto the host every frame, addressed by the property path the Inspector shows. This loads the
# COMPILED pack and drives the real integrator by hand - no scene tree, no physics - to prove the
# five things a row promises: a colour settles ON its target, a bump is velocity and nothing else,
# a clamp stops the value at the wall, a bank with nothing left to settle gives the frame back, and
# a spring that reaches its target says so by name, once, on the frame it got there.
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
	all_passed = _the_deadest_damping_still_settles(script) and all_passed
	all_passed = _a_landing_is_said_once_and_then_forgotten(script) and all_passed
	return all_passed


## The tick walks its three banks IN PLACE - no keys() and no values() per frame, because that was
## four fresh arrays every frame a spring was moving. Walking in place has one condition: the book
## may not be written while it is being walked, and a row answering On Spring Reached is allowed to
## start a spring or empty the bank. So the names that landed are collected into ONE list, made
## once and reused, and said after the parking decision has been taken.
##
## Which makes three things pinnable by value, and they are the three this walk could get wrong:
## the trigger still fires with the right name, the tick still parks, and the list is EMPTIED each
## frame rather than growing - a reused list that was never cleared would say every name it had ever
## held, every frame, for the rest of the scene.
static func _a_landing_is_said_once_and_then_forgotten(script: GDScript) -> bool:
	var behavior: Node = script.new()
	var host: Node2D = Node2D.new()
	behavior.host = host
	var said: Array = []
	behavior.spring_reached.connect(func(named: String) -> void: said.append(named))
	behavior.spring_property_to("rotation", 1.0)
	var widest: int = 0
	var landing_frame: PackedStringArray = PackedStringArray()
	var ticks: int = 0
	for _index: int in TICK_BUDGET:
		behavior._process(0.016)
		ticks += 1
		widest = maxi(widest, behavior._reached.size())
		if not behavior._reached.is_empty():
			landing_frame = behavior._reached.duplicate()
		if behavior.property_spring_is_settled("rotation"):
			break
	var parked: bool = behavior.is_processing()
	# One more frame with nothing left to settle: the list is emptied and nothing is said again.
	behavior._process(0.016)
	var after: PackedStringArray = behavior._reached.duplicate()
	var said_after: Array = said.duplicate()
	var passed: bool = SUPPORT.pins(PREFIX, [
		["a spring that reaches its target says so, by name and once", said, ["rotation"]],
		["the frame it landed on is the frame that named it", landing_frame,
			PackedStringArray(["rotation"])],
		["and never holds more than the names that landed on that one frame", widest, 1],
		["it settles inside the tick budget", ticks < TICK_BUDGET, true],
		["the node parks once everything has settled", parked, false],
		["the list is emptied at the top of the next frame rather than grown", after,
			PackedStringArray([])],
		["so a settled spring is never announced a second time", said_after, ["rotation"]],
	])
	behavior.free()
	host.free()
	return passed


## The heaviest damping the row offers - the 1 its own description calls "never overshoots" - is
## still a spring: it reaches the number it was pointed at, and the tick parks afterwards. The decay
## is exponential, so at exactly 1 nothing of the velocity survives a step and the spring would stand
## still for ever with the frame it is standing still in still being paid for.
static func _the_deadest_damping_still_settles(script: GDScript) -> bool:
	var behavior: Node = script.new()
	var host: Node2D = Node2D.new()
	behavior.host = host
	behavior.set_property_spring("rotation", 1.0, 2.0)
	behavior.spring_property_to("rotation", 1.0)
	var ticks: int = 0
	for _index: int in TICK_BUDGET:
		behavior._process(0.016)
		ticks += 1
		if behavior.property_spring_is_settled("rotation"):
			break
	var passed: bool = SUPPORT.pins(PREFIX, [
		["a spring damped to the top still settles", behavior.property_spring_is_settled("rotation"), true],
		["and lands on the number it was pointed at", snappedf(behavior.property_spring_value("rotation"), 0.001), 1.0],
		["and gives the frame back afterwards", behavior.is_processing(), false],
	])
	behavior.free()
	host.free()
	return passed


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
