@tool
class_name HostMemberProbesTest
extends RefCounted

## Five behaviours drive a sibling or a named node through members they reach by text. Each now checks
## every member it uses, once, when it finds that node, and says which is missing. This pins the two
## halves: the list a behaviour checks is the list the shipped partner really has (so the shipped pairs
## never warn), and the check itself runs exactly once and leaves a node that lacks a member usable.

const SUPPORT := preload("res://tests/support.gd")
const NAME: String = "host_member_probes_test"
const PATHFINDING_PATH: String = "res://eventsheet_addons/platformer_pathfinding/platformer_pathfinding_behavior.gd"
const MOVEMENT_PATH: String = "res://eventsheet_addons/platformer_movement/platformer_movement_behavior.gd"
const JUICE_PATH: String = "res://eventsheet_addons/juice/juice_behavior.gd"
const SCREEN_FX_PATH: String = "res://eventsheet_addons/screen_fx/screen_fx.gd"
const HUD_PATH: String = "res://eventsheet_addons/hud_kit/hud_kit_behavior.gd"
const STYLES_PATH: String = "res://eventsheet_addons/floating_text_styles_resource/floating_text_styles.gd"
const DIALOGUE_PATH: String = "res://eventsheet_addons/dialogue_kit/dialogue_kit_behavior.gd"
const NAV_PATH: String = "res://eventsheet_addons/nav_agent_3d/nav_agent_3d_behavior.gd"
const FPS_PATH: String = "res://eventsheet_addons/fps_controller/fps_controller_behavior.gd"


static func run() -> bool:
	var passed: bool = true
	passed = _movement_members() and passed
	passed = _screen_layer_methods() and passed
	passed = _text_styles_methods() and passed
	passed = _dialogue_labels() and passed
	passed = _driver_members() and passed
	return passed


## The names a script declares as variables, constants excluded.
static func _properties(script: GDScript) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for info: Dictionary in script.get_script_property_list():
		found.append(str(info.name))
	return found


## The names a script declares as functions.
static func _methods(script: GDScript) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for info: Dictionary in script.get_script_method_list():
		found.append(str(info.name))
	return found


static func _missing(wanted: PackedStringArray, have: PackedStringArray) -> PackedStringArray:
	var gap: PackedStringArray = PackedStringArray()
	for word: String in wanted:
		if not have.has(word):
			gap.append(word)
	return gap


## Platformer Pathfinding: every member it drives on the movement sibling is on the shipped movement,
## and the one-shot check reports a sibling that lacks one without refusing it.
static func _movement_members() -> bool:
	var pathfinding: GDScript = load(PATHFINDING_PATH) as GDScript
	var movement: GDScript = load(MOVEMENT_PATH) as GDScript
	var wanted: PackedStringArray = pathfinding.get_script_constant_map().get("MOVEMENT_MEMBERS", PackedStringArray())
	var agent: Node = pathfinding.new() as Node
	var bare: Node = Node.new()
	var before: bool = bool(agent.get("_movement_members_checked"))
	agent.call("_check_movement_members", bare)
	var after: bool = bool(agent.get("_movement_members_checked"))
	agent.free()
	bare.free()
	return SUPPORT.pins(NAME, [
		["the pathfinding behaviour names the movement members it drives", wanted.size() > 0, true],
		["the shipped movement has every one of them", _missing(wanted, _properties(movement)), PackedStringArray()],
		["the check has not run before a sibling is found", before, false],
		["it runs once a sibling is found, even one that has nothing", after, true],
	])


## Juice: the six methods a moment calls on the Screen FX layer are all on the shipped layer.
static func _screen_layer_methods() -> bool:
	var juice: GDScript = load(JUICE_PATH) as GDScript
	var screen: GDScript = load(SCREEN_FX_PATH) as GDScript
	var wanted: PackedStringArray = juice.get_script_constant_map().get("SCREEN_FX_METHODS", PackedStringArray())
	return SUPPORT.pins(NAME, [
		["juice names the layer methods a moment calls", wanted.size(), 6],
		["the shipped Screen FX layer has every one of them", _missing(wanted, _methods(screen)), PackedStringArray()],
	])


## HUD Kit: the six methods a floating number asks of a styles file are all on the shipped styles file,
## and the check is once per behaviour.
static func _text_styles_methods() -> bool:
	var styles: GDScript = load(STYLES_PATH) as GDScript
	var source: String = FileAccess.get_file_as_string(HUD_PATH)
	var wanted: PackedStringArray = PackedStringArray(["has_style", "colour_of", "size_of", "rise_of", "shake_of", "lifetime_of"])
	return SUPPORT.pins(NAME, [
		["the shipped styles file has every method a floating number asks of it", _missing(wanted, _methods(styles)), PackedStringArray()],
		["the HUD checks the same six, once", source.contains("for method: String in [\"has_style\", \"colour_of\", \"size_of\", \"rise_of\", \"shake_of\", \"lifetime_of\"]:"), true],
		["a set-text on a node with no text says so once, by name", source.contains("if not (\"text\" in target):"), true],
	])


## Dialogue Kit: a label with no text member is reported once and still handed back, and a real label is
## not reported at all.
static func _dialogue_labels() -> bool:
	var script: GDScript = load(DIALOGUE_PATH) as GDScript
	var kit: Node = script.new() as Node
	var host: Node = Node.new()
	var plain: Node = Node.new()
	plain.name = "Plain"
	var label: Label = Label.new()
	label.name = "Real"
	host.add_child(plain)
	host.add_child(label)
	kit.set("host", host)
	var first: Node = kit.call("_ui_label", "Plain", ["text", "visible_characters"]) as Node
	var checked_once: Dictionary = (kit.get("ui_checked") as Dictionary).duplicate()
	var again: Node = kit.call("_ui_label", "Plain", ["text", "visible_characters"]) as Node
	var real: Node = kit.call("_ui_label", "Real", ["text", "visible_characters"]) as Node
	var passed: bool = SUPPORT.pins(NAME, [
		["a node that has no text is still handed back", first, plain],
		["and it is marked as checked", checked_once.has("Plain"), true],
		["asking again hands it back without checking again", again, plain],
		["a real Label carries both members the dialogue writes", "text" in label and "visible_characters" in label, true],
		["a real Label is found", real, label],
		["a missing name is no label and no error", kit.call("_ui_label", "Nothing", ["text"]), null],
	])
	kit.free()
	host.free()
	return passed


## NavAgent3D: the driver seam it writes (ai_controlled and both axes) is on the shipped controller.
static func _driver_members() -> bool:
	var fps: GDScript = load(FPS_PATH) as GDScript
	var nav: GDScript = load(NAV_PATH) as GDScript
	var wanted: PackedStringArray = PackedStringArray(["ai_controlled", "ai_move_x", "ai_move_z"])
	var agent: Node = nav.new() as Node
	var before: bool = bool(agent.get("_driver_checked"))
	var host: CharacterBody3D = CharacterBody3D.new()
	var plain: Node = Node.new()
	host.add_child(plain)
	agent.set("host", host)
	var nothing: Node = agent.call("_find_driver") as Node
	var seam: GDScript = GDScript.new()
	seam.source_code = "extends Node
var ai_move_z: float = 0.0
var ai_controlled: bool = false
"
	seam.reload()
	var driver: Node = Node.new()
	driver.set_script(seam)
	host.add_child(driver)
	var found: Node = agent.call("_find_driver") as Node
	var after: bool = bool(agent.get("_driver_checked"))
	agent.free()
	host.free()
	return SUPPORT.pins(NAME, [
		["the shipped controller has every member the agent writes", _missing(wanted, _properties(fps)), PackedStringArray()],
		["the driver check has not run before one is found", before, false],
		["a node without the seam is not taken for a driver", nothing, null],
		["a node with the seam but no ai_move_x is still the driver", found, driver],
		["and the check has run", after, true],
	])
