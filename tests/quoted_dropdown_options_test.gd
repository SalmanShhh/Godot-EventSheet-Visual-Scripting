# Godot EventSheets - a dropdown over words emits a quoted word, never an identifier.
#
# Three packs offer a dropdown on a String argument whose keys are bare words: the scene transition
# and its ease, the car's keyboard-style direction, and the slide direction on a verb and a condition.
# A dropdown key is inserted into the call verbatim, so the shipped template has to carry the quotes
# itself - a row that picked "wipe" emitted `go_to_scene_with(path, wipe, 1.0, smooth)`, and the game
# did not parse. Quoting the KEY does not survive the annotation round trip (the emitter wraps a key
# that already starts with a quote in a second pair, and the scanner strips one pair back off), which
# is why the quotes live in the TEMPLATE, the way the Camera Rail packs already do.
#
# Every template is read off the SHIPPED pack and then put through the compiler's own emitter, because
# a pin on the annotation text alone would not notice the emitter changing under it.
@tool
class_name QuotedDropdownOptionsTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const SCENE_FLOW := "res://eventsheet_addons/scene_flow/scene_flow_behavior.gd"
const PHYSICS_CAR := "res://eventsheet_addons/physics_car/physics_car_behavior.gd"
const SLIDE_MOVE := "res://eventsheet_addons/slide_move/slide_move_behavior.gd"

## [pack, the template the pack ships, what a row picking the first option emits]. The picked values
## are the words a designer sees in the dropdown, spelled exactly as the option keys are.
const ACTIONS := [
	[SCENE_FLOW, "$SceneFlowBehavior.go_to_scene_with({path}, \"{transition}\", {seconds}, \"{ease}\")",
		"$SceneFlowBehavior.go_to_scene_with(\"res://levels/forest.tscn\", \"wipe\", 1.0, \"smooth\")"],
	[SCENE_FLOW, "$SceneFlowBehavior.reload_scene_with(\"{transition}\", {seconds}, \"{ease}\")",
		"$SceneFlowBehavior.reload_scene_with(\"wipe\", 1.0, \"smooth\")"],
	[PHYSICS_CAR, "$PhysicsCar.simulate_control(\"{direction}\")",
		"$PhysicsCar.simulate_control(\"left\")"],
	[SLIDE_MOVE, "$SlideMove.slide(\"{direction}\")",
		"$SlideMove.slide(\"left\")"],
]

const CONDITIONS := [
	[SLIDE_MOVE, "$SlideMove.can_slide(\"{direction}\")", "$SlideMove.can_slide(\"left\")"],
]

const PICKED := {"path": "\"res://levels/forest.tscn\"", "transition": "wipe", "seconds": "1.0",
	"ease": "smooth", "direction": "left"}


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _test_the_shipped_annotations() and all_passed
	all_passed = _test_the_emitted_calls() and all_passed
	all_passed = _test_no_bare_word_dropdown_is_left() and all_passed
	return all_passed


## The pack ships the quoted template as its annotation, so a sheet that opens the pack reads it.
static func _test_the_shipped_annotations() -> bool:
	var all_passed: bool = true
	for pinned: Array in ACTIONS + CONDITIONS:
		var shipped: String = FileAccess.get_file_as_string(str(pinned[0]))
		all_passed = _check("the pack ships %s" % str(pinned[1]),
			shipped.contains("## @ace_codegen_template(\"%s\")" % str(pinned[1])), true) and all_passed
	return all_passed


## The call a picked row emits, through the compiler's own emitters for an action and a condition.
static func _test_the_emitted_calls() -> bool:
	var all_passed: bool = true
	for pinned: Array in ACTIONS:
		var action: ACEAction = ACEAction.new()
		action.provider_id = "Pinned"
		action.ace_id = "method:pinned"
		action.codegen_template = str(pinned[1])
		action.params = PICKED.duplicate()
		all_passed = _check("a picked option emits a word: %s" % str(pinned[2]),
			ActionCodegen.generate_action(action), str(pinned[2])) and all_passed
	for pinned: Array in CONDITIONS:
		var condition: ACECondition = ACECondition.new()
		condition.provider_id = "Pinned"
		condition.ace_id = "method:pinned"
		condition.codegen_template = str(pinned[1])
		condition.params = PICKED.duplicate()
		all_passed = _check("a picked option asks with a word: %s" % str(pinned[2]),
			ConditionCodegen.generate_condition(condition), str(pinned[2])) and all_passed
	return all_passed


## The shape that caused the bug must not come back: in these three packs, every parameter that has
## an options annotation is quoted inside the template of the function it belongs to. The walk pairs
## each options line with the next template line below it, which is how the pack lays them out.
static func _test_no_bare_word_dropdown_is_left() -> bool:
	var all_passed: bool = true
	for pack: String in [SCENE_FLOW, PHYSICS_CAR, SLIDE_MOVE]:
		var lines: PackedStringArray = FileAccess.get_file_as_string(pack).split("\n")
		var pending: Array[String] = []
		for line: String in lines:
			var text: String = line.strip_edges()
			if text.begins_with("## @ace_param_options("):
				var inside: String = text.trim_prefix("## @ace_param_options(").trim_suffix(")")
				pending.append(inside.get_slice(" ", 0))
			elif text.begins_with("## @ace_codegen_template("):
				for param_id: String in pending:
					all_passed = _check("%s quotes {%s} in %s" % [pack.get_file(), param_id, text],
						text.contains("\\\"{%s}\\\"" % param_id) or text.contains("\"{%s}\"" % param_id), true) and all_passed
				pending.clear()
	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("quoted_dropdown_options_test", label, actual, expected)
