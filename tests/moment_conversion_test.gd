# Godot EventSheets - old moment files becoming Juice lists.
#
# THE ONE THING THIS FILE IS ABOUT: an old moment file is never rewritten until someone edits it or asks the Doctor,
# and then it becomes a Juice list IN PLACE - same path, same uid, every scene still pointing at it - in one undo step
# that puts the old bytes back. An old file and its converted file play the same cards.
@tool
class_name MomentConversionTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const CONVERSION := preload("res://addons/eventforge/moment_conversion.gd")
const PLAYER := preload("res://eventsheet_addons/juice/feedback_player.gd")
const MOMENT_SCRIPT := preload("res://eventsheet_addons/moment_resource/moment_resource.gd")
const LIST_SCRIPT := preload("res://eventsheet_addons/moment_resource/juice_list.gd")
const DOCTOR := preload("res://addons/eventforge/moment_files_doctor.gd")
const DRAWERS := preload("res://addons/eventsheet/editor/attribute_drawers.gd")
const MENU := preload("res://addons/eventforge/editor/context_menu_plugin.gd")

const TEST_NAME: String = "moment_conversion"


static func run() -> bool:
	var ok: bool = true
	ok = _untouched_file_stays_as_it_is() and ok
	ok = _first_edit_converts_in_place_and_undo_restores() and ok
	ok = _converted_file_plays_the_same() and ok
	ok = _bulk_conversion_counts_keeps_scenes_and_undoes() and ok
	ok = _the_doctor_names_the_count_and_offers_the_fix() and ok
	ok = _the_inspector_and_menu_know_an_old_file() and ok
	return ok


## An old file written the way Godot writes one, with a name and three cards of four keys, and a uid when one is given.
static func _write_old_file(name: String, uid_text: String = "") -> String:
	var file: Resource = MOMENT_SCRIPT.new()
	file.set("moment_name", "Smash")
	file.set("steps", [
		{"verb": "shake", "amount": 0.4, "effect": "", "seconds": 0.0},
		{"verb": "flash", "amount": 0.8, "effect": "", "seconds": 0.0},
		{"verb": "hold", "amount": 0.0, "effect": "vignette", "seconds": 0.0}] as Array[Dictionary])
	var path: String = SUPPORT.own_path(name)
	ResourceSaver.save(file, path)
	if not uid_text.is_empty():
		# Give the file the uid a project's own file has, by rewriting its header line.
		var text: String = FileAccess.get_file_as_string(path)
		var lines: PackedStringArray = text.split("\n")
		lines[0] = lines[0].replace("format=3", "format=3 uid=\"%s\"" % uid_text)
		var handle: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		handle.store_string("\n".join(lines))
		handle.close()
	return path


static func _bytes(path: String) -> PackedByteArray:
	return FileAccess.get_file_as_bytes(path)


static func _uid_of(path: String) -> String:
	var line: String = FileAccess.get_file_as_string(path).split("\n")[0]
	var at: int = line.find("uid=\"")
	return line.substr(at + 5, line.find("\"", at + 5) - at - 5) if at >= 0 else ""


static func _reload(path: String) -> Resource:
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)


## Loading, showing, reading and playing an old file leaves its bytes alone.
static func _untouched_file_stays_as_it_is() -> bool:
	var path: String = _write_old_file("untouched_moment.tres")
	var before: PackedByteArray = _bytes(path)
	var file: Resource = _reload(path)
	var player: Node = PLAYER.new()
	player.moment_file = file
	player.play(1.0)
	var cards: Array = player._steps_now()
	var told: bool = CONVERSION.is_old_moment(file)
	player.free()
	return SUPPORT.pins(TEST_NAME, [
		["an old file is known as one", told, true],
		["the player reads its cards as they are", cards.size(), 3],
		["and its bytes are the bytes it had", _bytes(path) == before, true]
	])


## The first edit makes the file a Juice list: same object, same path, same uid on disk after a save, the name kept,
## and one undo takes the old file back, down to its bytes.
static func _first_edit_converts_in_place_and_undo_restores() -> bool:
	var uid_text: String = ResourceUID.id_to_text(ResourceUID.create_id())
	var path: String = _write_old_file("edited_moment.tres", uid_text)
	var before: PackedByteArray = _bytes(path)
	var file: Resource = _reload(path)
	var edited: Array[Dictionary] = CONVERSION.cards_of(file.get("steps"))
	edited[0]["amount"] = 0.9
	var undo: UndoRedo = UndoRedo.new()
	var converted: bool = CONVERSION.edit_step(file, edited, "Edit", undo)
	var is_list: bool = file.get_script() == LIST_SCRIPT
	var amount_after: float = float((file.get("steps") as Array)[0].get("amount", 0.0))
	var same_path: String = file.resource_path
	var named: String = CONVERSION.name_of(file)
	var saved: int = CONVERSION.save_keeping_uid(file, path)
	var saved_bytes: PackedByteArray = _bytes(path)
	var uid_after: String = _uid_of(path)
	var header: String = FileAccess.get_file_as_string(path).split("\n")[0]
	var reread: Resource = _reload(path)
	var reread_is_list: bool = reread.get_script() == LIST_SCRIPT
	undo.undo()
	var back_script: bool = file.get_script() == MOMENT_SCRIPT
	var back_amount: float = float((file.get("steps") as Array)[0].get("amount", 0.0))
	var back_name: String = str(file.get("moment_name"))
	var meta_gone: bool = not file.has_meta("moment_name")
	CONVERSION.save_keeping_uid(file, path)
	var undone_bytes: PackedByteArray = _bytes(path)
	undo.free()
	return SUPPORT.pins(TEST_NAME, [
		["the edit converted", converted, true],
		["into a Juice list", is_list, true],
		["with the edit in it", snappedf(amount_after, 0.001), 0.9],
		["the object kept its path", same_path, path],
		["the old name is kept on the file", named, "Smash"],
		["it saved", saved, OK],
		["the file says it is a Juice list now", header.contains("script_class=\"JuiceList\""), true],
		["the uid in the file is the uid it had", uid_after, uid_text],
		["a fresh load is a Juice list", reread_is_list, true],
		["the file changed on disk only because it was saved", saved_bytes != before, true],
		["one undo gives the moment script back", back_script, true],
		["and the old amount", snappedf(back_amount, 0.001), 0.4],
		["and the old name", back_name, "Smash"],
		["and no leftover name on the list", meta_gone, true],
		["and saving it again writes the old bytes", undone_bytes == before, true]
	])


## A recorder that notes each card the way it is played.
class Recorder extends PLAYER:

	var played: Array = []

	func _do_step(card: Dictionary, at_strength: float, _skipping: bool = false) -> void:
		played.append([str(card.get("verb", "")), snappedf(float(card.get("amount", 1.0)), 0.001), str(card.get("effect", "")),
			snappedf(float(card.get("seconds", 0.0)), 0.001), snappedf(at_strength, 0.001)])


static func _played_from(file: Resource, strength: float) -> Array:
	var player: Recorder = Recorder.new()
	player.moment_file = file
	player.play(strength)
	var played: Array = player.played.duplicate(true)
	player.free()
	return played


## The old file and the file it became play the same cards, at every strength.
static func _converted_file_plays_the_same() -> bool:
	var path: String = _write_old_file("plays_moment.tres")
	var old_file: Resource = _reload(path)
	var old_light: Array = _played_from(old_file, 0.5)
	var old_full: Array = _played_from(old_file, 1.0)
	var other_path: String = _write_old_file("plays_moment_copy.tres")
	var converting: Resource = _reload(other_path)
	var converted: bool = CONVERSION.convert_in_place(converting)
	var new_light: Array = _played_from(converting, 0.5)
	var new_full: Array = _played_from(converting, 1.0)
	return SUPPORT.pins(TEST_NAME, [
		["the file converted", converted, true],
		["the old file plays its three cards", old_full.size(), 3],
		["the same cards play from the list, at full strength", var_to_str(new_full), var_to_str(old_full)],
		["and at half strength", var_to_str(new_light), var_to_str(old_light)]
	])


## All at once: the count is the files converted, a scene pointing at one is not touched, and one undo puts every
## file's bytes back.
static func _bulk_conversion_counts_keeps_scenes_and_undoes() -> bool:
	var uid_one: String = ResourceUID.id_to_text(ResourceUID.create_id())
	var uid_two: String = ResourceUID.id_to_text(ResourceUID.create_id())
	var one: String = _write_old_file("bulk/one.tres", uid_one)
	var two: String = _write_old_file("bulk/two.tres", uid_two)
	var folder: String = one.get_base_dir()
	var scene_path: String = SUPPORT.own_path("bulk/holder.tscn")
	var scene_text: String = "[gd_scene load_steps=2 format=3]\n\n[ext_resource type=\"Resource\" uid=\"%s\" path=\"%s\" id=\"1_moment\"]\n\n[node name=\"Holder\" type=\"Node\"]\n" % [uid_one, one]
	var handle: FileAccess = FileAccess.open(scene_path, FileAccess.WRITE)
	handle.store_string(scene_text)
	handle.close()
	var plain_path: String = SUPPORT.own_path("bulk/plain.tres")
	ResourceSaver.save(Resource.new(), plain_path)
	var originals: Dictionary = {one: _bytes(one), two: _bytes(two)}
	var scene_before: PackedByteArray = _bytes(scene_path)
	var plain_before: PackedByteArray = _bytes(plain_path)
	var found: PackedStringArray = CONVERSION.old_files_among(PackedStringArray([folder]))
	var undo: UndoRedo = UndoRedo.new()
	var count: int = CONVERSION.convert_files(PackedStringArray([folder]), "Convert", undo)
	var one_list: bool = _reload(one).get_script() == LIST_SCRIPT
	var two_list: bool = _reload(two).get_script() == LIST_SCRIPT
	var kept_uids: Array = [_uid_of(one), _uid_of(two)]
	var scene_after: PackedByteArray = _bytes(scene_path)
	var plain_after: PackedByteArray = _bytes(plain_path)
	var none_left: PackedStringArray = CONVERSION.old_files_among(PackedStringArray([folder]))
	undo.undo()
	var restored: bool = _bytes(one) == originals[one] and _bytes(two) == originals[two]
	var script_back: bool = _reload(one).get_script() == MOMENT_SCRIPT
	undo.free()
	return SUPPORT.pins(TEST_NAME, [
		["both old files are found and the plain resource is not", found.size(), 2],
		["the count is the files converted", count, 2],
		["the first is a Juice list", one_list, true],
		["and the second", two_list, true],
		["each kept its uid", kept_uids, [uid_one, uid_two]],
		["the scene pointing at one is the same bytes", scene_after == scene_before, true],
		["a resource that was never a moment file is untouched", plain_after == plain_before, true],
		["no old file is left", none_left.size(), 0],
		["one undo writes every old file back, byte for byte", restored, true],
		["and a load after it is the old class again", script_back, true]
	])


## The Doctor note: a count in plain words, naming the one thing that breaks, with the fix that converts them all.
static func _the_doctor_names_the_count_and_offers_the_fix() -> bool:
	var one: String = _write_old_file("doctor/one.tres")
	var two: String = _write_old_file("doctor/two.tres")
	var own: PackedStringArray = DOCTOR.own_old_files(PackedStringArray([one, two, SUPPORT.own_path("doctor/missing.tres"),
		"res://eventsheet_addons/juice/impact.tres", "res://addons/eventsheet_library/juice/calm.tres"]))
	var findings: Array[Dictionary] = DOCTOR.report(own)
	var finding: Dictionary = findings[0] if not findings.is_empty() else {}
	var message: String = str(finding.get("message", ""))
	var fix: Variant = finding.get("fix")
	var converted: int = 0
	if fix is Callable:
		converted = int((fix as Callable).call(finding))
	var after: PackedStringArray = DOCTOR.own_old_files(PackedStringArray([one, two]))
	return SUPPORT.pins(TEST_NAME, [
		["the two files of the reader's own are counted, the shipped starters are not", own.size(), 2],
		["one note", findings.size(), 1],
		["a note and not a warning", str(finding.get("severity", "")), "info"],
		["it is filed under its own check", str(finding.get("check", "")), "moment-files"],
		["it says how many", message.begins_with("2 old moment files can become Juice lists"), true],
		["it names the cast that gets nothing back", message.contains("casts it to the old class") or message.contains("cast it to the old class") or message.contains("casts one to the old class"), true],
		["the fix is a door with a label", str(finding.get("fix_label", "")), "Make all 2 Juice lists"],
		["the fix converts them all", converted, 2],
		["and the note is gone on the next look", DOCTOR.report(after).size(), 0],
		["a project with nothing old has no note", DOCTOR.report(PackedStringArray()).size(), 0],
		["one file is worded as one", DOCTOR.message_for(1).begins_with("1 old moment file can become a Juice list"), true]
	])


## The Inspector draws an old file's steps as cards before any edit, a list's own steps are left to their own marker,
## and the FileSystem entry is offered for an old file and not for anything else.
static func _the_inspector_and_menu_know_an_old_file() -> bool:
	var old_file: Resource = MOMENT_SCRIPT.new()
	var list_file: Resource = LIST_SCRIPT.new()
	var path: String = _write_old_file("menu_moment.tres")
	var plain_path: String = SUPPORT.own_path("menu_plain.tres")
	ResourceSaver.save(Resource.new(), plain_path)
	var slot: int = EditorContextMenuPlugin.CONTEXT_SLOT_FILESYSTEM
	return SUPPORT.pins(TEST_NAME, [
		["an old file's steps are drawn as juice cards", DRAWERS.old_moment_marker(old_file, TYPE_ARRAY, "steps").begins_with("eventsheet:cards:"), true],
		["its name is not", DRAWERS.old_moment_marker(old_file, TYPE_STRING, "moment_name"), ""],
		["a list's steps carry their own marker already", DRAWERS.old_moment_marker(list_file, TYPE_ARRAY, "steps"), ""],
		["the entry is offered for an old file", MENU.old_moment_files(slot, PackedStringArray([path])).size(), 1],
		["and not for a plain resource", MENU.old_moment_files(slot, PackedStringArray([plain_path])).size(), 0],
		["and not in another menu", MENU.old_moment_files(EditorContextMenuPlugin.CONTEXT_SLOT_SCENE_TREE, PackedStringArray([path])).size(), 0]
	])
