# Godot EventSheets - a dropdown over words emits a quoted word, never an identifier.
#
# Several packs offer a dropdown on a String argument whose keys are bare words: the scene transition
# and its ease, the car's keyboard-style direction, the slide direction on a verb and a condition, and
# the two Juice packs' chromatic-shake mode and slowmo clock.
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
const JUICE := "res://eventsheet_addons/juice/juice_behavior.gd"
const JUICE_3D := "res://eventsheet_addons/juice_3d/juice_3d_behavior.gd"
const BOUND_TO := "res://eventsheet_addons/bound_to/bound_to_behavior.gd"
const PROMPTS := "res://eventsheet_addons/prompts/prompts_addon.gd"
const ANCHOR := "res://eventsheet_addons/anchor/anchor_behavior.gd"
const DRUNKEN_WALKERS := "res://eventsheet_addons/drunken_walkers/drunken_walkers_addon.gd"
const FOLLOW_PATH := "res://eventsheet_addons/follow_path/path_follow_behavior.gd"
const GAME_SETTINGS := "res://eventsheet_addons/game_settings/game_settings_addon.gd"
const NAV_AGENT_3D := "res://eventsheet_addons/nav_agent_3d/nav_agent_3d_behavior.gd"
const PIN := "res://eventsheet_addons/pin/pin_behavior.gd"
const PIN_3D := "res://eventsheet_addons/pin_3d/pin_3d_behavior.gd"
const PLATFORMER := "res://eventsheet_addons/platformer_pathfinding/platformer_pathfinding_behavior.gd"
const ROTATE := "res://eventsheet_addons/rotate/rotate_behavior.gd"
const STAT_FORGE := "res://eventsheet_addons/stat_forge/stat_forge_behavior.gd"
const STORYLETS := "res://eventsheet_addons/storylet_weaver/storylet_weaver_addon.gd"
const TILE_MOVEMENT := "res://eventsheet_addons/tile_movement/tile_movement_behavior.gd"
const UTILITY_AI := "res://eventsheet_addons/utility_ai/utility_ai_addon.gd"
const WRAP := "res://eventsheet_addons/wrap/wrap_behavior.gd"
const PACKS_DIR := "res://eventsheet_addons"

## The dropdown parameters still inserted BARE, as "<pack script>:<param id>" - an OVERRIDE list, not
## a permission. Every line here is the same defect this file is named for: a row that picks one of
## the words emits an undefined identifier and the game does not parse. They are recorded so the
## sweep below can walk the WHOLE fleet - a hand-written list of five packs is exactly why Is At
## Bound and Grade Is shipped broken - and each is asserted to be STILL bare, so quoting one turns
## this gate red until its line is deleted. Delete lines from here; never add one.
const KNOWN_BARE := [
	"game_settings/game_settings_addon.gd:device",
	"game_settings/game_settings_addon.gd:kind",
	"nav_agent_3d/nav_agent_3d_behavior.gd:mode",
	"pin/pin_behavior.gd:axes",
	"pin/pin_behavior.gd:mode",
	"pin_3d/pin_3d_behavior.gd:axes",
	"pin_3d/pin_3d_behavior.gd:mode",
	"platformer_pathfinding/platformer_pathfinding_behavior.gd:mode",
	"rotate/rotate_behavior.gd:type",
	"stat_forge/stat_forge_behavior.gd:direction",
	"stat_forge/stat_forge_behavior.gd:mode",
	"storylet_weaver/storylet_weaver_addon.gd:mode",
	"storylet_weaver/storylet_weaver_addon.gd:op",
	"tile_movement/tile_movement_behavior.gd:direction",
	"utility_ai/utility_ai_addon.gd:curve",
	"wrap/wrap_behavior.gd:space",
]

## [pack, the template the pack ships, what a row picking an option emits] and, optionally, a fourth
## entry naming the words THIS row picks. The picked values are what a designer sees in the dropdown,
## spelled exactly as the option keys are; a plain String argument beside them carries its own quotes
## in the VALUE, which is the difference the whole file is about. Rows without a fourth entry take
## PICKED as it stands.
const ACTIONS := [
	[SCENE_FLOW, "$SceneFlowBehavior.go_to_scene_with({path}, \"{transition}\", {seconds}, \"{ease}\")",
		"$SceneFlowBehavior.go_to_scene_with(\"res://levels/forest.tscn\", \"wipe\", 1.0, \"smooth\")"],
	[SCENE_FLOW, "$SceneFlowBehavior.reload_scene_with(\"{transition}\", {seconds}, \"{ease}\")",
		"$SceneFlowBehavior.reload_scene_with(\"wipe\", 1.0, \"smooth\")"],
	[PHYSICS_CAR, "$PhysicsCar.simulate_control(\"{direction}\")",
		"$PhysicsCar.simulate_control(\"left\")"],
	[SLIDE_MOVE, "$SlideMove.slide(\"{direction}\")",
		"$SlideMove.slide(\"left\")"],
	[JUICE, "$JuiceBehavior.chromatic_shake({magnitude}, {duration}, \"{mode}\", {angle_degrees})",
		"$JuiceBehavior.chromatic_shake(12.0, 0.3, \"reducing\", -1.0)"],
	[JUICE, "$JuiceBehavior.slowmo({target_scale}, {hold_duration}, \"{duration_clock}\")",
		"$JuiceBehavior.slowmo(0.15, 0.25, \"realtime\")"],
	[JUICE_3D, "$Juice3DBehavior.chromatic_shake({magnitude}, {duration}, \"{mode}\", {angle_degrees})",
		"$Juice3DBehavior.chromatic_shake(12.0, 0.3, \"reducing\", -1.0)"],
	[ANCHOR, "$AnchorBehavior.anchor_to(\"{corner}\")",
		"$AnchorBehavior.anchor_to(\"top left\")", {"corner": "top left"}],
	[DRUNKEN_WALKERS, "DrunkenWalkers.set_random_source(\"{source}\")",
		"DrunkenWalkers.set_random_source(\"shared\")", {"source": "shared"}],
	[DRUNKEN_WALKERS,
		"DrunkenWalkers.add_walker_from_preset(\"{preset}\", {id}, {start_x}, {start_y}, {tag}, {carve_value})",
		"DrunkenWalkers.add_walker_from_preset(\"ore_vein\", \"veins\", 4, 6, \"ore\", 2)",
		{"preset": "ore_vein", "id": "\"veins\"", "start_x": "4", "start_y": "6", "tag": "\"ore\"",
			"carve_value": "2"}],
	[DRUNKEN_WALKERS,
		"DrunkenWalkers.scatter_marks({count}, {tag}, {value}, \"{placement}\", {min_spacing})",
		"DrunkenWalkers.scatter_marks(12, \"ore\", 1, \"interior\", 2.0)",
		{"count": "12", "tag": "\"ore\"", "value": "1", "placement": "interior", "min_spacing": "2.0"}],
	[FOLLOW_PATH, "$PathFollowBehavior.follow_path({path}, {speed}, \"{mode}\")",
		"$PathFollowBehavior.follow_path($Route, 120.0, \"loop\")",
		{"path": "$Route", "speed": "120.0", "mode": "loop"}],
]

const CONDITIONS := [
	[SLIDE_MOVE, "$SlideMove.can_slide(\"{direction}\")", "$SlideMove.can_slide(\"left\")"],
	[BOUND_TO, "$BoundToBehavior.is_at_bound(\"{side}\")", "$BoundToBehavior.is_at_bound(\"left\")"],
	[PROMPTS, "Prompts.grade_is(\"{grade}\")", "Prompts.grade_is(\"perfect\")"],
]

const PICKED := {"path": "\"res://levels/forest.tscn\"", "transition": "wipe", "seconds": "1.0",
	"ease": "smooth", "direction": "left", "magnitude": "12.0", "duration": "0.3",
	"mode": "reducing", "angle_degrees": "-1.0", "target_scale": "0.15",
	"hold_duration": "0.25", "duration_clock": "realtime", "side": "left", "grade": "perfect"}


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
		action.params = _picked(pinned)
		all_passed = _check("a picked option emits a word: %s" % str(pinned[2]),
			ActionCodegen.generate_action(action), str(pinned[2])) and all_passed
	for pinned: Array in CONDITIONS:
		var condition: ACECondition = ACECondition.new()
		condition.provider_id = "Pinned"
		condition.ace_id = "method:pinned"
		condition.codegen_template = str(pinned[1])
		condition.params = _picked(pinned)
		all_passed = _check("a picked option asks with a word: %s" % str(pinned[2]),
			ConditionCodegen.generate_condition(condition), str(pinned[2])) and all_passed
	return all_passed


## The shape that caused the bug must not come back, and the question is asked of the WHOLE FLEET
## rather than of a list somebody remembered to extend: every pack script under eventsheet_addons/
## is walked, and the bare dropdown parameters it finds must be exactly the ones KNOWN_BARE already
## names. A new one is a new defect; a name that has been quoted since is a line to delete.
##
## The walk pairs each options line with the next template line below it, which is how a pack lays
## them out. Options whose keys are all NUMBERS are left alone: those index an int parameter (the
## home leash's distance metric), and a number belongs in the call bare.
static func _test_no_bare_word_dropdown_is_left() -> bool:
	var found: PackedStringArray = PackedStringArray()
	for pack: String in _pack_scripts():
		for param_id: String in _bare_word_params(pack):
			found.append("%s:%s" % [pack.trim_prefix(PACKS_DIR + "/"), param_id])
	found.sort()
	var expected: PackedStringArray = PackedStringArray(KNOWN_BARE)
	expected.sort()
	return _check("the dropdown parameters left bare across every pack",
		"\n".join(found), "\n".join(expected))


## Every pack script under eventsheet_addons/ - one per folder, plus the root single-file packs,
## the same population the drift audit walks.
static func _pack_scripts() -> PackedStringArray:
	var paths: PackedStringArray = PackedStringArray()
	var packs_dir: DirAccess = DirAccess.open(PACKS_DIR)
	if packs_dir == null:
		return paths
	for file_name: String in packs_dir.get_files():
		if file_name.ends_with(".gd"):
			paths.append("%s/%s" % [PACKS_DIR, file_name])
	for folder: String in packs_dir.get_directories():
		if folder.begins_with("."):
			continue
		var inner: DirAccess = DirAccess.open("%s/%s" % [PACKS_DIR, folder])
		if inner == null:
			continue
		for file_name: String in inner.get_files():
			if file_name.ends_with(".gd"):
				paths.append("%s/%s/%s" % [PACKS_DIR, folder, file_name])
	paths.sort()
	return paths


## The parameter ids this pack offers a word dropdown for and then inserts into the call BARE,
## deduplicated (one parameter spelled the same way in three functions is one defect to fix).
static func _bare_word_params(pack: String) -> PackedStringArray:
	var bare: PackedStringArray = PackedStringArray()
	var pending: Array[String] = []
	for line: String in FileAccess.get_file_as_string(pack).split("\n"):
		var text: String = line.strip_edges()
		if text.begins_with("## @ace_param_options("):
			var inside: String = text.trim_prefix("## @ace_param_options(").trim_suffix(")")
			var param_id: String = inside.get_slice(" ", 0)
			if not _keys_are_all_numbers(inside.substr(param_id.length())):
				pending.append(param_id)
		elif text.begins_with("## @ace_codegen_template("):
			for param_id: String in pending:
				var quoted: bool = text.contains("\\\"{%s}\\\"" % param_id) \
					or text.contains("\"{%s}\"" % param_id)
				if not quoted and not bare.has(param_id):
					bare.append(param_id)
			pending.clear()
	bare.sort()
	return bare


## Whether every key in an options list is a number - "0=Straight line, 1=Horizontal only" indexes
## an int parameter, so its call is right to be bare and the sweep must not ask it for quotes.
static func _keys_are_all_numbers(options: String) -> bool:
	for entry: String in options.split(","):
		var key: String = entry.strip_edges()
		if key.contains("="):
			key = key.get_slice("=", 0).strip_edges()
		if key.is_empty() or not (key.is_valid_int() or key.is_valid_float()):
			return false
	return true


## The words one pinned row picks: PICKED, overlaid with the row's own fourth entry when it has one.
## A shared table alone could not spell both Pin's "position and angle" and Juice's "reducing" for the
## same parameter name, and pinning one of them wrong would have hidden which pack the row was about.
static func _picked(pinned: Array) -> Dictionary:
	var params: Dictionary = PICKED.duplicate()
	if pinned.size() > 3:
		params.merge(pinned[3] as Dictionary, true)
	return params


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("quoted_dropdown_options_test", label, actual, expected)
