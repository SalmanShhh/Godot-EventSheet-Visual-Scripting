# Godot EventSheets - a project made before the Feedback Player became the Juice Player keeps working.
#
# THE PROMISE: a name people READ may change, nothing they SAVED may. The fixture folder holds what
# such a project has on disk: a scene with two players and a script that names the old class, a
# `.gd` sheet with the exact bytes the plugin wrote for four rows (stored as `old_sheet.gd.txt`, so the
# style gate does not read compiler bytes as hand-written code), and a `.tres` sheet with one row.
# Every pin here is green on the code from before the rename and must stay green after every commit
# of it. How the reopened rows READ is not pinned here (a later fix gives them their own sentence);
# only the bytes are, because the bytes are the promise.
class_name JuiceRenameOldProjectTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")

const TEST_NAME: String = "juice_rename_old_project"
const DIR: String = "res://tests/fixtures/juice_rename_old/"
const OLD_PATH: String = "res://eventsheet_addons/juice/feedback_player.gd"
const OLD_UID: String = "uid://cgxg3u53yyxu"

## The cards the scene was saved with, key for key.
const SAVED_CARDS: Array = [
	{"label": "hit", "verb": "emit_signal", "word": "bang"},
	{"active": false, "amount": 0.4, "label": "kick", "verb": "shake"},
	{"amount": 0.5, "label": "other", "verb": "play_player"},
]

## Every member a saved scene, a script or a placed row may name. Never renamed.
const METHODS: Array[String] = ["add_feedback", "clear_feedbacks", "copy_feedbacks_from",
	"current_feedback", "disable_feedback", "duplicate_feedback", "enable_feedback", "feedback_count",
	"feedback_duration", "feedback_field", "feedback_is_enabled", "feedback_is_playing",
	"feedback_label_at", "feedback_progress", "feedbacks_duration", "feedbacks_progress",
	"for_each_feedback", "has_feedback", "has_played", "hold_here", "insert_feedback_before",
	"is_playing", "jump_to_feedback", "load_moment_file", "loops_left", "move_feedback_to",
	"mute_category_on_channel", "mute_feedback_category", "pause_feedbacks", "pick_one_feedback_of",
	"play_and_wait", "play_backwards", "play_feedbacks_from_channel", "play_on_channel", "play",
	"release_hold", "remove_feedback", "replace_feedback", "restore", "resume_feedbacks",
	"retime_feedbacks", "revert", "save_moment_file", "scale_feedback_amounts",
	"set_can_play_while_playing", "set_feedback_chance", "set_feedback_field", "set_feedback_label",
	"set_feedback_timing", "set_loop_count", "set_player_cooldown", "set_player_strength",
	"shuffle_feedbacks_between", "skip_feedback_once", "skip_to_end", "stop",
	"duration_of", "schedule_of", "editor_preview_sample"]
const SIGNALS: Array[String] = ["on_feedback_finished", "on_feedback_signal", "on_feedback_skipped",
	"on_feedback_started", "on_feedbacks_finished", "on_feedbacks_started", "on_hold_reached", "on_loop"]
const PROPERTIES: Array[String] = ["acts_on", "steps", "strength", "direction", "while_playing",
	"cooldown", "moment_file"]
const WORDS: Dictionary = {"TOP_TO_BOTTOM": "top to bottom", "BOTTOM_TO_TOP": "bottom to top",
	"RESTART": "restart", "IGNORE": "ignore", "OVERLAP": "overlap", "PAUSE": "pause",
	"HOLD_UNTIL": "hold_until", "LOOP_START": "loop_start", "LOOP_BACK": "loop_back",
	"TWEEN_PROPERTY": "tween_property", "EMIT_SIGNAL": "emit_signal", "PLAY_PLAYER": "play_player"}


static func run() -> bool:
	var ok: bool = _file_pins()
	ok = _scene_pins() and ok
	ok = _script_pins() and ok
	ok = _sheet_pins() and ok
	ok = _frozen_name_pins() and ok
	return ok


## The old file is still where scenes look for it, under the same uid, and still answers to the old name.
static func _file_pins() -> bool:
	var old_class_path: String = ""
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		if str(entry.get("class", "")) == "FeedbackPlayer":
			old_class_path = str(entry.get("path", ""))
	return SUPPORT.pins(TEST_NAME, [
		["the old file is still there", FileAccess.file_exists(OLD_PATH), true],
		["under its old uid", ResourceUID.id_to_text(ResourceLoader.get_resource_uid(OLD_PATH)), OLD_UID],
		["the library copy keeps the same sidecar",
			FileAccess.get_file_as_string("res://addons/eventsheet_library/juice/feedback_player.gd.uid").strip_edges(), OLD_UID],
		["the old class name still names that file", old_class_path, OLD_PATH],
	])


## The scene loads, both players carry a working script, the cards are the saved ones, a play plays,
## and saving the scene again keeps every value.
static func _scene_pins() -> bool:
	var root: Node = (load(DIR + "old_scene.tscn") as PackedScene).instantiate()
	var player: Node = root.get_node("FeedbackPlayer")
	var hit: Node = root.get_node("HitFeedback")
	var heard: Array = []
	player.connect("on_feedbacks_finished", func() -> void: heard.append("finished"))
	player.call("play", 1.0)
	var again: PackedScene = PackedScene.new()
	again.pack(root)
	ResourceSaver.save(again, "user://juice_rename_old_scene.tscn")
	var back: Node = (ResourceLoader.load("user://juice_rename_old_scene.tscn", "",
		ResourceLoader.CACHE_MODE_IGNORE) as PackedScene).instantiate()
	var back_player: Node = back.get_node("FeedbackPlayer")
	var ok: bool = SUPPORT.pins(TEST_NAME, [
		["the player keeps the old script path", player.get_script().resource_path, OLD_PATH],
		["so does the second one", hit.get_script().resource_path, OLD_PATH],
		["both can play", [player.has_method("play"), hit.has_method("play")], [true, true]],
		["the cards are the saved ones, key for key", player.get("steps"), SAVED_CARDS],
		["the saved strength and while-playing word load",
			[player.get("strength"), player.get("while_playing")], [0.75, "overlap"]],
		["a play plays the list", [player.call("has_played"), heard], [true, ["finished"]]],
		["saved again, the cards are the same", back_player.get("steps"), SAVED_CARDS],
		["and so are the other values",
			[back_player.get("strength"), back_player.get("while_playing")], [0.75, "overlap"]],
		["and the node still wears the old path", back_player.get_script().resource_path, OLD_PATH],
	])
	back.free()
	root.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://juice_rename_old_scene.tscn"))
	return ok


## A script that names the old class three ways still compiles and still answers yes.
static func _script_pins() -> bool:
	var script: GDScript = load(DIR + "old_user.gd") as GDScript
	var root: Node = (load(DIR + "old_scene.tscn") as PackedScene).instantiate()
	var answers: Dictionary = root.get_node("User").call("answers")
	root.free()
	return SUPPORT.pins(TEST_NAME, [
		["the script that names the old class compiles", script.reload(true), OK],
		["it asks the old class and hears yes",
			[answers.get("p_is_feedback_player"), answers.get("made_is_feedback_player")], [true, true]],
	])


## The `.gd` sheet re-saves byte for byte, and the `.tres` row still compiles to the same line.
static func _sheet_pins() -> bool:
	var source: String = FileAccess.get_file_as_string(DIR + "old_sheet.gd.txt")
	var tres: EventSheetResource = ResourceLoader.load(DIR + "old_sheet.tres", "",
		ResourceLoader.CACHE_MODE_IGNORE) as EventSheetResource
	var compiled: String = SUPPORT.compile_output(tres, "user://juice_rename_old_sheet_tres.gd")
	var action: ACEAction = (tres.events[0] as EventRow).actions[0] as ACEAction
	return SUPPORT.pins(TEST_NAME, [
		["the old .gd sheet re-saves byte for byte",
			SUPPORT.reemit(source, "user://juice_rename_old_sheet.gd"), source],
		["the old .tres row keeps its provider and id",
			[action.provider_id, action.ace_id], ["FeedbackPlayer", "method:play"]],
		["and still compiles to the old line", compiled.contains("\t$FeedbackPlayer.play(0.6)\n"), true],
	])


## Every member and word saved data may name, asked of the code through the old file.
static func _frozen_name_pins() -> bool:
	var script: GDScript = load(OLD_PATH) as GDScript
	var player: Node = script.new()
	var missing: Array[String] = []
	for method: String in METHODS:
		if not player.has_method(method):
			missing.append("method " + method)
	for signal_name: String in SIGNALS:
		if not player.has_signal(signal_name):
			missing.append("signal " + signal_name)
	var properties: Dictionary = {}
	for entry: Dictionary in player.get_property_list():
		properties[str(entry.get("name", ""))] = true
	for property: String in PROPERTIES:
		if not properties.has(property):
			missing.append("property " + property)
	for word: String in WORDS.keys():
		if str(_constant(script, word)) != str(WORDS[word]):
			missing.append("word %s=%s" % [word, str(_constant(script, word))])
	player.free()
	return SUPPORT.pins(TEST_NAME, [
		["every frozen member and word is still answered through the old file", missing, [] as Array[String]],
	])


## A constant asked of a script or of the script it extends, the way `is` and a member access see it.
static func _constant(script: Script, constant_name: String) -> Variant:
	while script != null:
		var declared: Dictionary = script.get_script_constant_map()
		if declared.has(constant_name):
			return declared[constant_name]
		script = script.get_base_script()
	return null
