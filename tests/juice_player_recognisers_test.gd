# Godot EventSheets - every place the editor recognises a player knows both shapes of the pack.
#
# An old project keeps its own copy of the pack: ONE file, `feedback_player.gd`, `class_name
# FeedbackPlayer`. A new one has the pair: `juice_player.gd` (`class_name JuicePlayer`, the code) and
# the old name extending it. The Inspector strip, the toolbar's segment, the saved-scene finding, the
# Doctor's scan and the card families must answer for a node of EITHER file. The old single-file
# copy cannot be loaded beside the new pair (two scripts would claim one class name), so the old
# shape is the old-name file itself, which is what an old copy's nodes wear.
class_name JuicePlayerRecognisersTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const INSPECTOR := preload("res://addons/eventsheet/editor/inspector/feedback_player_inspector_plugin.gd")
const SEGMENT := preload("res://addons/eventsheet/editor/dock/toolbar_moment_segment.gd")
const FINDINGS := preload("res://addons/eventsheet/editor/interaction/feedback_findings.gd")
const SCHEMA := preload("res://addons/eventsheet/editor/inspector/feedback_card_schema.gd")
const NAMES := preload("res://addons/eventsheet/editor/inspector/juice_player_names.gd")

const TEST_NAME: String = "juice_player_recognisers"
const NEW_PATH: String = "res://eventsheet_addons/juice/juice_player.gd"
const OLD_PATH: String = "res://eventsheet_addons/juice/feedback_player.gd"
const SCENE_PATH: String = "user://juice_player_recognisers.tscn"


static func run() -> bool:
	var made: String = NEW_PATH if ResourceLoader.exists(NEW_PATH) else "<no juice_player.gd>"
	var fresh: Node = (load(NEW_PATH) as GDScript).new() if ResourceLoader.exists(NEW_PATH) else Node.new()
	var old: Node = (load(OLD_PATH) as GDScript).new()
	fresh.name = "JuicePlayer"
	fresh.set("steps", [{"verb": "shake", "label": "kick", "amount": 0.4}] as Array[Dictionary])
	var root: Node2D = Node2D.new()
	root.name = "Level"
	root.add_child(fresh)
	fresh.owner = root
	var packed: PackedScene = PackedScene.new()
	packed.pack(root)
	ResourceSaver.save(packed, SCENE_PATH)
	var ok: bool = SUPPORT.pins(TEST_NAME, [
		# The three shapes a project can hold, as (file name, global name): an old single-file copy, the new
		# code file, and the old name's file that now extends it. A script that is neither is not claimed.
		["an old single-file copy is a player", NAMES.is_player_names("feedback_player.gd", "FeedbackPlayer"), true],
		["the new code file is a player", NAMES.is_player_names("juice_player.gd", "JuicePlayer"), true],
		["the old name's file is a player", NAMES.is_player_names("feedback_player.gd", ""), true],
		["a script that is neither is not", NAMES.is_player_names("juice_behavior.gd", "JuiceBehavior"), false],
		["the code file is where the pack is read from", NAMES.pack_path(), NEW_PATH],
		["the new file exists", made, NEW_PATH],
		["the Inspector strip claims a new node", INSPECTOR.is_feedback_player(fresh), true],
		["and an old one", INSPECTOR.is_feedback_player(old), true],
		["the toolbar segment claims a new node", SEGMENT.is_player(fresh), true],
		["and an old one", SEGMENT.is_player(old), true],
		["a saved scene's new node is read for its labels", FINDINGS.labels_in_scene(SCENE_PATH), PackedStringArray(["kick"])],
		["the card families are read off the class that declares them", SCHEMA.family_of().get("shake", ""), "camera"],
	])
	root.free()
	old.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SCENE_PATH))
	return ok
