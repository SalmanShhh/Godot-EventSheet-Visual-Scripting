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
const HOME_LEASH := "res://eventsheet_addons/home_leash/home_leash_behavior.gd"
const PLATFORMER := "res://eventsheet_addons/platformer_pathfinding/platformer_pathfinding_behavior.gd"
const ROTATE := "res://eventsheet_addons/rotate/rotate_behavior.gd"
const STAT_FORGE := "res://eventsheet_addons/stat_forge/stat_forge_behavior.gd"
const STORYLETS := "res://eventsheet_addons/storylet_weaver/storylet_weaver_addon.gd"
const TILE_MOVEMENT := "res://eventsheet_addons/tile_movement/tile_movement_behavior.gd"
const UTILITY_AI := "res://eventsheet_addons/utility_ai/utility_ai_addon.gd"
const WRAP := "res://eventsheet_addons/wrap/wrap_behavior.gd"
const PACKS_DIR := "res://eventsheet_addons"

## The one hint whose dropdown is a LIVE list rather than a fixed vocabulary: the input-action
## picker reads the project's own Input Map, so its words differ per project and its starting value
## names the action a game is expected to have ("jump"). A project that has that action selects it;
## this one, having only Godot's ui_* defaults, does not - which is a reading of THIS repo's Input
## Map and not a row anybody ships broken. Every other dropdown is a fixed list the pack or the
## module wrote down, and the sweep below holds all of them to their own words.
const LIVE_LIST_HINT := "input_action"

## The dropdown parameters still inserted BARE, as "<pack script>:<param id>" - an OVERRIDE list, not
## a permission. Every line here is the same defect this file is named for: a row that picks one of
## the words emits an undefined identifier and the game does not parse. They are recorded so the
## sweep below can walk the WHOLE fleet - a hand-written list of five packs is exactly why Is At
## Bound and Grade Is shipped broken - and each is asserted to be STILL bare, so quoting one turns
## this gate red until its line is deleted. Delete lines from here; never add one.
##
## It is EMPTY, and staying empty is the point: every pack that offers a word dropdown quotes it in
## the template. A name back on this list is a pack shipping a row that emits an undefined
## identifier, and the answer is to quote that template rather than to write the name down.
const KNOWN_BARE := [
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
	[GAME_SETTINGS,
		"Settings.declare_setting({setting_name}, {default_value}, \"{kind}\", {choices}, {page}, {label})",
		"Settings.declare_setting(\"music\", 80.0, \"percent\", \"\", \"audio\", \"Music\")",
		{"setting_name": "\"music\"", "default_value": "80.0", "kind": "percent", "choices": "\"\"",
			"page": "\"audio\"", "label": "\"Music\""}],
	[GAME_SETTINGS, "Settings.listen_for_binding({action}, \"{device}\")",
		"Settings.listen_for_binding(\"jump\", \"pad\")", {"action": "\"jump\"", "device": "pad"}],
	[NAV_AGENT_3D, "$NavAgent3D.find_path_to({x}, {y}, {z}, \"{mode}\")",
		"$NavAgent3D.find_path_to(4.0, 0.0, 9.0, \"reach\")",
		{"x": "4.0", "y": "0.0", "z": "9.0", "mode": "reach"}],
	[PIN, "$PinBehavior.set_pin_mode(\"{mode}\")",
		"$PinBehavior.set_pin_mode(\"position and angle\")", {"mode": "position and angle"}],
	[PIN, "$PinBehavior.set_pin_axes(\"{axes}\")",
		"$PinBehavior.set_pin_axes(\"x only\")", {"axes": "x only"}],
	[PIN_3D, "$Pin3DBehavior.set_pin_mode(\"{mode}\")",
		"$Pin3DBehavior.set_pin_mode(\"spring\")", {"mode": "spring"}],
	[PIN_3D, "$Pin3DBehavior.set_pin_axes(\"{axes}\")",
		"$Pin3DBehavior.set_pin_axes(\"z only\")", {"axes": "z only"}],
	[PLATFORMER, "$PlatformerPathfinding.find_path_to({x}, {y}, \"{mode}\")",
		"$PlatformerPathfinding.find_path_to(4.0, 9.0, \"reach\")",
		{"x": "4.0", "y": "9.0", "mode": "reach"}],
	[ROTATE, "$RotateBehavior.set_rotation_type(\"{type}\")",
		"$RotateBehavior.set_rotation_type(\"2d\")", {"type": "2d"}],
	[STAT_FORGE,
		"$StatForge.add_buff({buff_id}, {stat}, {value}, \"{mode}\", {tags}, {source}, {duration})",
		"$StatForge.add_buff(\"rage\", \"attack\", 5.0, \"multiply\", \"combat\", \"potion\", 8.0)",
		{"buff_id": "\"rage\"", "stat": "\"attack\"", "value": "5.0", "mode": "multiply",
			"tags": "\"combat\"", "source": "\"potion\"", "duration": "8.0"}],
	[STAT_FORGE,
		"$StatForge.add_threshold_rule({rule_id}, {stat}, {value}, \"{direction}\", {repeating})",
		"$StatForge.add_threshold_rule(\"low_hp\", \"health\", 25.0, \"falling\", true)",
		{"rule_id": "\"low_hp\"", "stat": "\"health\"", "value": "25.0", "direction": "falling",
			"repeating": "true"}],
	[STORYLETS, "Storylets.add_requirement({id}, {quality_key}, \"{op}\", {value})",
		"Storylets.add_requirement(\"tavern\", \"courage\", \">=\", 3)",
		{"id": "\"tavern\"", "quality_key": "\"courage\"", "op": ">=", "value": "3"}],
	[STORYLETS, "Storylets.add_recency_requirement({id}, \"{mode}\", {within})",
		"Storylets.add_recency_requirement(\"tavern\", \"not_recent\", 5)",
		{"id": "\"tavern\"", "mode": "not_recent", "within": "5"}],
	[TILE_MOVEMENT, "$TileMovementBehavior.simulate_step(\"{direction}\")",
		"$TileMovementBehavior.simulate_step(\"up\")", {"direction": "up"}],
	[UTILITY_AI,
		"$UtilityBrain.add_consideration({action_name}, {input_key}, \"{curve}\", {weight}, {curve_center}, {curve_slope})",
		"$UtilityBrain.add_consideration(\"flee\", \"health\", \"inverse\", 1.0, 0.5, 1.0)",
		{"action_name": "\"flee\"", "input_key": "\"health\"", "curve": "inverse", "weight": "1.0",
			"curve_center": "0.5", "curve_slope": "1.0"}],
	[WRAP, "$WrapBehavior.set_wrap_space(\"{space}\")",
		"$WrapBehavior.set_wrap_space(\"custom\")", {"space": "custom"}],
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


## The dropdowns whose starting word is REFLECTED from the method signature rather than written as an
## `@ace_param(default: …)`, as [pack script, ace id suffix, param id, the word the method names].
##
## A reflected default arrives as SOURCE TEXT - `func is_at_bound(side: String = "any")` gives the
## six characters `"any"`, quotes included - while an annotation default arrives already unquoted.
## An option key is a bare word, and `ACEParamsDialog._create_options_field` selects an index only on
## an exact key match, so the quoted form matched nothing and the OptionButton stayed on item 0: Is
## At Bound opened on "left" while its own signature said "any". The generator now takes one pair of
## quotes off a String default the moment the parameter has options, and these five are the shipped
## rows that were reading the wrong word.
const REFLECTED_DEFAULTS := [
	[BOUND_TO, "is_at_bound", "side", "any"],
	[FOLLOW_PATH, "follow_path", "mode", "once"],
	[GAME_SETTINGS, "declare_setting", "kind", "percent"],
	[STAT_FORGE, "add_buff", "mode", "add"],
	[STAT_FORGE, "add_threshold_rule", "direction", "rising"],
]


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _test_the_shipped_annotations() and all_passed
	all_passed = _test_the_emitted_calls() and all_passed
	all_passed = _test_no_bare_word_dropdown_is_left() and all_passed
	all_passed = _test_a_dropdown_opens_on_the_word_its_method_names() and all_passed
	all_passed = _test_no_dropdown_holds_a_word_it_does_not_offer() and all_passed
	all_passed = _test_a_blank_first_option_is_still_the_blank() and all_passed
	all_passed = _test_a_numbered_dropdown_answers_with_the_number() and all_passed
	return all_passed


## NO DROPDOWN HOLDS A WORD ITS OWN LIST DOES NOT OFFER - asked of every option-bearing parameter
## the project publishes, the packs through the generator and the builtins through their descriptors.
##
## The five rows pinned above had a reflected default that arrived QUOTED. The same defect had a
## bigger and quieter half: forty-two pack parameters named no default at all, so the picker fell
## through to the type-zero fallback and the row stored the empty string while the OptionButton
## showed item 0. A row dropped without opening the dialog emitted `$PinBehavior.set_pin_mode("")` -
## a word the pack does not understand, under a dialog reading a word it does. The generator now
## reads a dropdown's FIRST key as the value a parameter with no default opens on, which is the
## dialog's own rule spelled once instead of twice, and this sweep is what keeps the shown word and
## the stored word agreeing across the whole fleet rather than across a list somebody remembered to
## extend.
##
## Pinned as the JOINED LIST rather than a count, so a red run names the parameter, the word it
## holds and the words it offers.
static func _test_no_dropdown_holds_a_word_it_does_not_offer() -> bool:
	var found: PackedStringArray = PackedStringArray()
	var generator: EventSheetACEGenerator = EventSheetACEGenerator.new()
	for script_path: String in EventSheetAddonScanner.list_addon_scripts():
		var script: Script = load(script_path) as Script
		if script == null or not script.can_instantiate():
			continue
		var instance: Object = script.new()
		if instance == null:
			continue
		for definition: ACEDefinition in generator.generate_from_object(instance):
			for entry: Variant in definition.parameters:
				if not (entry is Dictionary):
					continue
				var parameter: Dictionary = entry as Dictionary
				var options: Array = parameter.get("options", []) as Array
				if options.is_empty() or str(parameter.get("hint", "")) == LIVE_LIST_HINT:
					continue
				var keys: Array = _option_keys(options)
				var held: String = str(parameter.get("default_value", ""))
				if not keys.has(held):
					found.append("%s %s %s holds \"%s\", offers %s" % [
						script_path.trim_prefix(PACKS_DIR + "/"), definition.id,
						str(parameter.get("id", "")), held, ", ".join(PackedStringArray(keys))])
		if instance is Node:
			(instance as Node).free()
	for descriptor: ACEDescriptor in EventForgeBuiltinACEs.get_descriptors():
		for parameter: ACEParam in descriptor.params:
			if parameter.options.is_empty() or parameter.hint == LIVE_LIST_HINT:
				continue
			var builtin_keys: Array = _option_keys(parameter.options)
			var builtin_held: String = str(parameter.get_initial_value())
			if not builtin_keys.has(builtin_held):
				found.append("%s:%s %s holds \"%s\", offers %s" % [
					descriptor.provider_id, descriptor.ace_id, parameter.id, builtin_held,
					", ".join(PackedStringArray(builtin_keys))])
	found.sort()
	return _check("the dropdowns holding a word their own list does not offer",
		"\n".join(found), "")


## A BLANK IS STILL A BLANK. The rule above reads the first option key, and some verbs are built
## around a first option that is deliberately empty ("no filter", "leave it where it is"). Reading
## the first key answers "" for those, which is the blank the author wrote and not a fallback that
## happens to look like one - so the rule cannot quietly promote such a row onto the second word.
## Pinned on a parameter built here, because the shipped fleet's blank-first dropdowns would make
## the pin depend on which packs happen to ship one.
static func _test_a_blank_first_option_is_still_the_blank() -> bool:
	var generator: EventSheetACEGenerator = EventSheetACEGenerator.new()
	var built: Array = generator._build_parameter_definitions(
		[{"name": "family", "type": TYPE_STRING}],
		{"param_options": {"family": [{"key": "", "label": "every card"}, {"key": "heroes"}]}})
	var parameter: Dictionary = built[0] if not built.is_empty() else {}
	return _check("a dropdown whose first word is blank opens on the blank",
		str(parameter.get("default_value", "unset")), "")


## The word a freshly dropped row shows, pinned twice: as the descriptor's own `default_value`, and
## as the INDEX the params dialog's OptionButton would land on, which is the number the designer
## actually sees. The index is the dialog's own rule spelled out - select the option whose key equals
## the default, and otherwise leave item 0 - so a default matching no key pins as 0 and names the
## defect rather than hiding it behind a value that merely looks reasonable.
static func _test_a_dropdown_opens_on_the_word_its_method_names() -> bool:
	var all_passed: bool = true
	var generator: EventSheetACEGenerator = EventSheetACEGenerator.new()
	for pinned: Array in REFLECTED_DEFAULTS:
		var pack: String = str(pinned[0])
		var method_name: String = str(pinned[1])
		var param_id: String = str(pinned[2])
		var expected_word: String = str(pinned[3])
		var parameter: Dictionary = _parameter_of(generator, pack, method_name, param_id)
		var keys: Array = _option_keys(parameter.get("options", []) as Array)
		all_passed = _check("%s %s opens on the word its method names" % [method_name, param_id],
			str(parameter.get("default_value", "")), expected_word) and all_passed
		all_passed = _check("%s %s selects the item that word is" % [method_name, param_id],
			_selected_index(keys, str(parameter.get("default_value", ""))),
			keys.find(expected_word)) and all_passed
	return all_passed


## A NUMBERED DROPDOWN ANSWERS WITH THE NUMBER. Home & Leash's distance metric is an `int`
## parameter whose five words are keyed `0` to `4`, and its slot is not quoted - so the value its
## row opens on has to be the first key read as the number it is, and the call it writes has to be
## `distance_from_home(0)`: not the empty string a type-zero fallback would leave inside a bare
## slot, and not a quoted `"0"` no int argument accepts. Pinned as BOTH the stored value and the
## emitted line, because only the second one is what the game has to build.
static func _test_a_numbered_dropdown_answers_with_the_number() -> bool:
	var all_passed: bool = true
	var generator: EventSheetACEGenerator = EventSheetACEGenerator.new()
	var parameter: Dictionary = _parameter_of(generator, HOME_LEASH, "distance_from_home", "metric")
	var value: String = str(parameter.get("default_value", ""))
	all_passed = _check("distance_from_home metric opens on its first number", value, "0") and all_passed
	return _check("the number reaches the call bare",
		ActionCodegen._apply_template("$HomeLeashBehavior.distance_from_home({metric})",
			{"metric": value}),
		"$HomeLeashBehavior.distance_from_home(0)") and all_passed


## The item the params dialog's OptionButton lands on, spelled as `_create_options_field` spells it:
## it calls `select(index)` only for the option whose key equals the default, and an OptionButton
## with items and no `select` call shows item 0. So a default matching no key answers 0 - which is
## what made this a bug the designer could see rather than a value only a test would notice.
static func _selected_index(keys: Array, default_value: String) -> int:
	var index: int = keys.find(default_value)
	return index if index >= 0 else 0


## One parameter of one reflected method ACE, read through the same generator the live picker uses.
## An empty dictionary when the pack, the method or the parameter is not there, which fails the pins
## above by value rather than by crashing on a missing key.
static func _parameter_of(generator: EventSheetACEGenerator, pack: String, method_name: String,
		param_id: String) -> Dictionary:
	var script: Script = load(pack) as Script
	if script == null or not script.can_instantiate():
		return {}
	var instance: Object = script.new()
	var found: Dictionary = {}
	for definition: ACEDefinition in generator.generate_from_object(instance):
		if definition.id != "method:%s" % method_name:
			continue
		for entry: Variant in definition.parameters:
			if entry is Dictionary and str((entry as Dictionary).get("id", "")) == param_id:
				found = entry
				break
	if instance is Node:
		(instance as Node).free()
	return found


## An options array as the bare keys it offers, in the order the OptionButton adds them.
##
## WHICH FIELD NAMES THE KEY is decided by which one is PRESENT, exactly as the generator and the
## descriptor adapter decide it - `key`, else `value`, else `label`. A generated parameter always
## spells `key`, but a descriptor may carry either of the other two, and reading past a present
## `key` of "" would turn a deliberate blank into the words beside it.
static func _option_keys(options: Array) -> Array:
	var keys: Array = []
	for option: Variant in options:
		if not (option is Dictionary):
			keys.append(str(option))
			continue
		var option_dict: Dictionary = option as Dictionary
		if option_dict.has("key"):
			keys.append(str(option_dict["key"]))
		elif option_dict.has("value"):
			keys.append(str(option_dict["value"]))
		elif option_dict.has("label"):
			keys.append(str(option_dict["label"]))
	return keys


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
