# EventForge - the values scenes and resources store for an exported variable.
#
# Renaming an exported variable used to drop every value a scene had stored for it, with no message.
# The reader that finds those values (and rewrites only the name) is exercised here against real
# files: the right property lines move, the value text stays byte for byte, a different script with the
# same variable name is never touched, a scene that only inherits the value is not rewritten, and a file
# that cannot be rewritten with certainty is listed, not half-written.
@tool
class_name SceneValuesTest
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")
const READER_PATH: String = "res://addons/eventsheet/editor/dock/scene_values.gd"
const FOLDER: String = "user://scene_values_fixture"
const SCRIPT: String = "user://scene_values_fixture/mover.gd"
const OTHER: String = "user://scene_values_fixture/other.gd"
const UID: String = "uid://c1sceneval0001"

const LEVEL_TSCN: String = """[gd_scene load_steps=4 format=3 uid="uid://c1sceneval0100"]

[ext_resource type="Script" path="user://scene_values_fixture/mover.gd" id="1_mv"]
[ext_resource type="Script" path="user://scene_values_fixture/other.gd" id="2_ot"]
[ext_resource type="PackedScene" path="user://scene_values_fixture/enemy.tscn" id="3_en"]

[sub_resource type="Resource" id="Resource_a"]
script = ExtResource("1_mv")
speed = 12.5

[node name="Level" type="Node2D"]

[node name="A" type="Node2D" parent="."]
script = ExtResource("1_mv")
speed = 300.0
health = 3

[node name="B" type="Node2D" parent="."]
script = ExtResource("1_mv")
speed = 450.25

[node name="Decoy" type="Node2D" parent="."]
script = ExtResource("2_ot")
speed = 99.0

[node name="Plain" type="Node2D" parent="."]
speed = 1.0

[node name="Note" type="Label" parent="."]
text = "line one
speed = 5
line three"

[node name="Inherits" parent="." instance=ExtResource("3_en")]

[node name="Overrides" parent="." instance=ExtResource("3_en")]
speed = 7.0

[node name="Deep" parent="Overrides" index="0"]
speed = 8.0
"""

const ENEMY_TSCN: String = """[gd_scene load_steps=2 format=3 uid="uid://c1sceneval0200"]

[ext_resource type="Script" uid="uid://c1sceneval0001" path="user://scene_values_fixture/stale_name.gd" id="1_mv"]

[node name="Enemy" type="Node2D"]
script = ExtResource("1_mv")
speed = 60.0

[node name="Deep" type="Node2D" parent="."]
script = ExtResource("1_mv")
speed = 20.0
"""

const SETTINGS_TRES: String = """[gd_resource type="Resource" load_steps=2 format=3]

[ext_resource type="Script" path="user://scene_values_fixture/mover.gd" id="1_mv"]

[resource]
script = ExtResource("1_mv")
speed = 42.0
"""

const NEW_NAME_TSCN: String = """[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="user://scene_values_fixture/mover.gd" id="1_mv"]

[node name="Both" type="Node2D"]
script = ExtResource("1_mv")
speed = 1.0
move_speed = 2.0
"""


static func run() -> bool:
	var ok: bool = true
	if not ResourceLoader.exists(READER_PATH):
		return _check("the reader exists", false, true)
	var reader: GDScript = load(READER_PATH)
	DirAccess.make_dir_recursive_absolute(FOLDER)
	_write(FOLDER + "/level.tscn", LEVEL_TSCN)
	_write(FOLDER + "/enemy.tscn", ENEMY_TSCN)
	_write(FOLDER + "/settings.tres", SETTINGS_TRES)
	var scripts: Array = [{"path": SCRIPT, "uid": UID}]
	reader.roots = PackedStringArray([FOLDER])

	var found: Dictionary = reader.scan(scripts, "speed", "move_speed")
	var edits: Dictionary = found["edits"]
	ok = _check("it looked through the three files", found["looked"], 3) and ok

	# The level: A, B, the sub-resource, and the two nodes that override an inherited value.
	var level: String = str(edits[FOLDER + "/level.tscn"]["after"])
	ok = _check("a node's value keeps its name's place and its text", level.contains("\nmove_speed = 300.0\nhealth = 3\n"), true) and ok
	ok = _check("a value with decimals is copied as it was", level.contains("\nmove_speed = 450.25\n"), true) and ok
	ok = _check("a sub-resource's value is renamed", level.contains("script = ExtResource(\"1_mv\")\nmove_speed = 12.5\n"), true) and ok
	ok = _check("an override of an inherited value is renamed", level.contains("[node name=\"Overrides\" parent=\".\" instance=ExtResource(\"3_en\")]\nmove_speed = 7.0\n"), true) and ok
	ok = _check("an override of an inherited child is renamed", level.contains("[node name=\"Deep\" parent=\"Overrides\" index=\"0\"]\nmove_speed = 8.0\n"), true) and ok
	ok = _check("a different script's value is never touched", level.contains("script = ExtResource(\"2_ot\")\nspeed = 99.0\n"), true) and ok
	ok = _check("a node with no script is never touched", level.contains("[node name=\"Plain\" type=\"Node2D\" parent=\".\"]\nspeed = 1.0\n"), true) and ok
	ok = _check("a line inside a multi-line string is never touched", level.contains("line one\nspeed = 5\nline three"), true) and ok
	ok = _check("a scene that only inherits the value is not rewritten for it", level.contains("[node name=\"Inherits\" parent=\".\" instance=ExtResource(\"3_en\")]\n\n"), true) and ok
	ok = _check("five values moved in the level", found["counts"][FOLDER + "/level.tscn"], 5) and ok
	ok = _check("nothing but names changed: same line count", level.split("\n").size(), LEVEL_TSCN.split("\n").size()) and ok
	# Put the old name back on the five lines it was on: the file must be the original, byte for byte.
	ok = _check("the rest of the file is the original, byte for byte",
		level.replace("move_speed = ", "speed = "), LEVEL_TSCN) and ok

	# The enemy: found by its uid although its path is stale.
	var enemy: String = str(edits[FOLDER + "/enemy.tscn"]["after"])
	ok = _check("a script found by uid alone is followed", enemy.contains("script = ExtResource(\"1_mv\")\nmove_speed = 60.0\n"), true) and ok
	ok = _check("both nodes of the enemy moved", found["counts"][FOLDER + "/enemy.tscn"], 2) and ok

	var settings: String = str(edits[FOLDER + "/settings.tres"]["after"])
	ok = _check("a saved resource's value is renamed", settings.contains("[resource]\nscript = ExtResource(\"1_mv\")\nmove_speed = 42.0\n"), true) and ok

	# Another script's file stores the same name, and is not ours at all.
	_write(FOLDER + "/decoy.tscn", LEVEL_TSCN.replace("user://scene_values_fixture/mover.gd", "user://scene_values_fixture/something_else.gd").replace("enemy.tscn", "somebody_else.tscn"))
	found = reader.scan(scripts, "speed", "move_speed")
	ok = _check("a scene of another script is left out", found["edits"].has(FOLDER + "/decoy.tscn"), false) and ok
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FOLDER + "/decoy.tscn"))

	# A node that already has the new name stored: listed with the reason, never half-written.
	_write(FOLDER + "/both.tscn", NEW_NAME_TSCN)
	found = reader.scan(scripts, "speed", "move_speed")
	ok = _check("a node that already stores the new name is not rewritten", found["edits"].has(FOLDER + "/both.tscn"), false) and ok
	var why: String = ""
	for entry: Dictionary in found["unchanged"]:
		if str(entry["path"]) == FOLDER + "/both.tscn":
			why = str(entry["why"])
	ok = _check("and it says why", why.contains("already stores a value under the name move_speed"), true) and ok
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FOLDER + "/both.tscn"))

	# An open scene with edits not saved yet is not rewritten.
	found = reader.scan(scripts, "speed", "move_speed", PackedStringArray([FOLDER + "/settings.tres"]))
	ok = _check("a file open with unsaved changes is not rewritten", found["edits"].has(FOLDER + "/settings.tres"), false) and ok
	ok = _check("and it is named, with what to do", str(found["unchanged"][0]["why"]).contains("not saved"), true) and ok

	# A binary scene that holds the name and the script path is named, never touched.
	var binary: FileAccess = FileAccess.open(FOLDER + "/packed.scn", FileAccess.WRITE)
	binary.store_buffer(PackedByteArray([0, 1, 2]) + "speed".to_utf8_buffer() + PackedByteArray([0]) + SCRIPT.to_utf8_buffer())
	binary.close()
	found = reader.scan(scripts, "speed", "move_speed")
	var listed: bool = false
	for entry: Dictionary in found["unchanged"]:
		if str(entry["path"]) == FOLDER + "/packed.scn":
			listed = str(entry["why"]).contains("binary")
	ok = _check("a binary scene is named as not changed", listed, true) and ok
	ok = _check("and no edit is prepared for it", found["edits"].has(FOLDER + "/packed.scn"), false) and ok
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FOLDER + "/packed.scn"))

	# Looking only (a delete): the same files, nothing prepared to be written.
	found = reader.scan(scripts, "speed", "")
	ok = _check("looking only prepares no edit", found["edits"].size(), 0) and ok
	ok = _check("looking only still counts the values", found["counts"][FOLDER + "/level.tscn"], 5) and ok

	for name: String in ["level.tscn", "enemy.tscn", "settings.tres"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("%s/%s" % [FOLDER, name]))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FOLDER))
	reader.roots = PackedStringArray(["res://"])
	return ok


static func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("scene_values_test", label, actual, expected)
