# Godot EventSheets - the Doctor's Behaviour hosts section.
#
# THE ONE THING THIS FILE IS ABOUT: a behaviour under the wrong kind of node is reported from the
# scene's TEXT, in one plain sentence, with the node that would fit named when the scene has one.
# A behaviour under the right node is silent, an "Acts on" that points at the right node is silent,
# and the move door rewrites only the one node's line.
@tool
class_name BehaviourHostDoctorTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const TEST_NAME: String = "behaviour_host_doctor"
const SCRIPT_PATH: String = "res://eventsheet_addons/platformer_movement/platformer_movement_behavior.gd"

const HEAD := "[gd_scene load_steps=2 format=3]\n\n[ext_resource type=\"Script\" path=\"res://eventsheet_addons/platformer_movement/platformer_movement_behavior.gd\" id=\"1\"]\n\n"

const WRONG := HEAD + "[node name=\"World\" type=\"Node2D\"]\n\n[node name=\"Crate\" type=\"Node2D\" parent=\".\"]\n\n[node name=\"PlatformerMovement\" type=\"Node\" parent=\"Crate\"]\nscript = ExtResource(\"1\")\n\n[node name=\"Player\" type=\"CharacterBody2D\" parent=\".\"]\n"

const RIGHT := HEAD + "[node name=\"World\" type=\"Node2D\"]\n\n[node name=\"Player\" type=\"CharacterBody2D\" parent=\".\"]\n\n[node name=\"PlatformerMovement\" type=\"Node\" parent=\"Player\"]\nscript = ExtResource(\"1\")\n"

const ACTS_ON_RIGHT := HEAD + "[node name=\"World\" type=\"Node2D\"]\n\n[node name=\"Player\" type=\"CharacterBody2D\" parent=\".\"]\n\n[node name=\"Behaviours\" type=\"Node\" parent=\".\"]\n\n[node name=\"PlatformerMovement\" type=\"Node\" parent=\"Behaviours\"]\nscript = ExtResource(\"1\")\nacts_on = NodePath(\"../../Player\")\n"

const ACTS_ON_WRONG := ACTS_ON_RIGHT + "\n[node name=\"Crate\" type=\"Node2D\" parent=\".\"]\n"


static func run() -> bool:
	var ok: bool = true
	var cache: Dictionary = {}
	var info: Dictionary = EventSheetBehaviourHostDoctor.behaviour_info(SCRIPT_PATH, cache)
	ok = SUPPORT.check(TEST_NAME, "the pack is read as a behaviour that needs a CharacterBody2D",
		[str(info.get("host", "")), str(info.get("label", ""))], ["CharacterBody2D", "Platformer Movement"]) and ok

	var wrong: Array[Dictionary] = EventSheetBehaviourHostDoctor.report_for_scene("res://wrong.tscn", WRONG, cache)
	ok = SUPPORT.check(TEST_NAME, "a behaviour under a Node2D is one finding", wrong.size(), 1) and ok
	if wrong.size() == 1:
		ok = SUPPORT.check(TEST_NAME, "its sentence names the behaviour, the node it is under and the type it needs",
			str(wrong[0]["message"]).begins_with("Platformer Movement is under a Node2D; it needs a CharacterBody2D: put it under one, or set Acts on."), true) and ok
		ok = SUPPORT.check(TEST_NAME, "it names the nearest node that fits",
			[str(wrong[0].get("to_path", "")), str(wrong[0].get("to", ""))], ["Player", "Player"]) and ok
		ok = SUPPORT.check(TEST_NAME, "it carries the five keys every runner reads",
			[wrong[0]["check"], wrong[0]["severity"], wrong[0]["path"], wrong[0]["subject"]],
			["behaviour-host", "warning", "res://wrong.tscn", "PlatformerMovement"]) and ok

	ok = SUPPORT.check(TEST_NAME, "a behaviour under the right node says nothing",
		EventSheetBehaviourHostDoctor.report_for_scene("res://right.tscn", RIGHT, cache).size(), 0) and ok
	ok = SUPPORT.check(TEST_NAME, "Acts on pointing at the right node says nothing",
		EventSheetBehaviourHostDoctor.report_for_scene("res://acts.tscn", ACTS_ON_RIGHT, cache).size(), 0) and ok
	var behind: Array[Dictionary] = EventSheetBehaviourHostDoctor.report_for_scene("res://acts.tscn",
		ACTS_ON_WRONG.replace("../../Player", "../../Crate"), cache)
	ok = SUPPORT.check(TEST_NAME, "Acts on pointing at the wrong type is reported with its own sentence",
		str(behind[0]["message"]).begins_with("Platformer Movement acts on a Node2D; it needs a CharacterBody2D.") if behind.size() == 1 else false, true) and ok

	# Without the scene's evidence there is silence: an instanced scene's type is not in the file.
	ok = SUPPORT.check(TEST_NAME, "a parent that is an instanced scene is never called wrong",
		EventSheetBehaviourHostDoctor.report_for_scene("res://instanced.tscn", WRONG.replace("name=\"Crate\" type=\"Node2D\"", "name=\"Crate\""), cache).size(), 0) and ok

	ok = _move_pins(cache) and ok
	ok = SUPPORT.pins(TEST_NAME, [
		["class names read as words", [EventSheetCompiler.spaced_class_name("PlatformerMovement"), EventSheetCompiler.spaced_class_name("FPSController"), EventSheetCompiler.spaced_class_name("Camera3DRig")], ["Platformer Movement", "FPS Controller", "Camera3D Rig"]],
		["the run-time sentence is the same words", EventSheetCompiler.host_warning_sentence("PlatformerMovement", "CharacterBody2D"), "Platformer Movement needs a CharacterBody2D: put it under one, or set Acts on."],
		["an Area host reads with 'an'", EventSheetCompiler.host_phrase("Area2D"), "an Area2D"],
	]) and ok
	return ok


## The move door: the behaviour hangs under the node that fits, the rest of the file is the same
## text, and the scene then reads clean.
static func _move_pins(cache: Dictionary) -> bool:
	var path: String = "user://behaviour_host_doctor_scene.tscn"
	var handle: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	handle.store_string(WRONG)
	handle.close()
	var moved: Dictionary = EventSheetBehaviourHostDoctor.move_under(path, "Crate/PlatformerMovement", "Player")
	var after: String = FileAccess.get_file_as_string(path)
	var ok: bool = SUPPORT.check(TEST_NAME, "the move door reports success", moved.get("ok", false), true)
	ok = SUPPORT.check(TEST_NAME, "the moved scene reads clean",
		EventSheetBehaviourHostDoctor.report_for_scene(path, after, cache).size(), 0) and ok
	ok = SUPPORT.check(TEST_NAME, "only the parent of that one node changed",
		after.replace("parent=\"Player\"]\nscript", "parent=\"Crate\"]\nscript").length() == WRONG.length(), true) and ok
	DirAccess.remove_absolute(path)
	return ok
