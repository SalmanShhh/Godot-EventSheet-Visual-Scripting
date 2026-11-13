# Godot EventSheets - the line that says what a behaviour changes on its parent.
#
# THE ONE THING THIS FILE IS ABOUT: a behaviour that writes into its host says so in its class
# description, in the same words everywhere, and one that never writes says nothing. The line is read
# off the compiled text, so these pins compile a small behaviour rather than trust a shipped one.
@tool
class_name BehaviourHostContractTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const TEST_NAME: String = "behaviour_host_contract"


static func run() -> bool:
	var writer: String = _compile("var speed: float = 1.0\n\nfunc nudge() -> void:\n\thost.velocity = Vector2.ZERO\n\thost.global_position.x += 1.0\n\thost.move_and_slide()\n\tif host.velocity == Vector2.ZERO:\n\t\tpass")
	var reader: String = _compile("func where() -> Vector2:\n\treturn host.global_position")
	var ok: bool = SUPPORT.pins(TEST_NAME, [
		["a writer lists what it writes, then move_and_slide", writer.contains("\n## Changes on its parent: velocity, global_position, move_and_slide().\n"), true],
		["a comparison is not a write", writer.contains("Changes on its parent: velocity, global_position, move_and_slide()."), true],
		["the line is written once", writer.count("Changes on its parent:"), 1],
		["a behaviour that only reads says nothing", reader.contains("Changes on its parent"), false],
	])
	var platformer: String = FileAccess.get_file_as_string("res://eventsheet_addons/platformer_movement/platformer_movement_behavior.gd")
	ok = SUPPORT.check(TEST_NAME, "the shipped Platformer Movement carries its contract",
		platformer.contains("## Changes on its parent: up_direction, velocity, move_and_slide().\n"), true) and ok
	return ok


static func _compile(body: String) -> String:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "CharacterBody2D"
	sheet.custom_class_name = "ContractProbe"
	sheet.class_description = "A probe."
	var block: RawCodeRow = RawCodeRow.new()
	block.code = body
	sheet.events.append(block)
	return str(EventSheetCompiler.compile(sheet, "user://contract_probe.gd").get("output", ""))
