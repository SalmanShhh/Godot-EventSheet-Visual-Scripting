# Godot EventSheets - the required-fields Doctor check.
#
# A variable marked Required whose script default is empty must be overridden by every scene
# node / saved resource using the script; Godot omits default-equal properties, so a missing
# override line means the empty default ships. Pins the two pure halves: which variables a
# script puts under watch, and which container blocks are flagged.
@tool
class_name RequiredFieldsDoctorTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true

	# ── Which variables go under watch: Required AND empty-by-default. ──
	var source: String = "\n".join(PackedStringArray([
		"class_name WatchedThing",
		"extends Resource",
		"",
		"# @inspector_required",
		"@export var portrait: Texture2D = null",
		"# @inspector_required",
		"@export var title: String = \"\"",
		"# @inspector_required",
		"@export var motto: String = \"ready\"",
		"@export var optional_icon: Texture2D = null",
		""
	]))
	all_passed = _eq("required + empty defaults go under watch (a filled default and an optional var do not)",
		EventSheetProjectDoctor.required_empty_defaults(source), PackedStringArray(["portrait", "title"])) and all_passed
	all_passed = _eq("a clamped (setter-suffixed) empty default still counts",
		EventSheetProjectDoctor.required_empty_defaults("# @inspector_required\n@export var hp_icon: Texture2D = null:\n\tset(value):\n\t\thp_icon = value\n"),
		PackedStringArray(["hp_icon"])) and all_passed
	all_passed = _eq("a source without the marker watches nothing",
		EventSheetProjectDoctor.required_empty_defaults("@export var portrait: Texture2D = null\n"), PackedStringArray()) and all_passed

	# ── Which container blocks are flagged: uses the script + no override line. ──
	var watched: Dictionary = {"res://things/watched_thing.gd": PackedStringArray(["portrait", "title"])}
	var scene_text: String = "\n".join(PackedStringArray([
		"[gd_scene load_steps=2 format=3]",
		"",
		"[ext_resource type=\"Script\" path=\"res://things/watched_thing.gd\" id=\"1_abc\"]",
		"",
		"[node name=\"GoodThing\" type=\"Node2D\"]",
		"script = ExtResource(\"1_abc\")",
		"portrait = SubResource(\"tex\")",
		"title = \"The Good One\"",
		"",
		"[node name=\"BadThing\" type=\"Node2D\"]",
		"script = ExtResource(\"1_abc\")",
		"title = \"Named but faceless\"",
		"",
		"[node name=\"Unrelated\" type=\"Node2D\"]",
		""
	]))
	var gaps: Array[Dictionary] = EventSheetProjectDoctor.required_gaps_in_container(scene_text, watched)
	all_passed = _eq("only the block missing an override is flagged, for exactly that property",
		gaps, [{"script": "res://things/watched_thing.gd", "property": "portrait"}]) and all_passed
	all_passed = _eq("a container that never references the script is clean",
		EventSheetProjectDoctor.required_gaps_in_container("[gd_scene]\n[node name=\"X\" type=\"Node2D\"]\n", watched), []) and all_passed
	var resource_text: String = "\n".join(PackedStringArray([
		"[gd_resource type=\"Resource\" load_steps=2 format=3]",
		"",
		"[ext_resource type=\"Script\" path=\"res://things/watched_thing.gd\" id=\"1_r\"]",
		"",
		"[resource]",
		"script = ExtResource(\"1_r\")",
		"portrait = SubResource(\"tex\")",
		""
	]))
	all_passed = _eq("a saved resource missing one required override is flagged for it",
		EventSheetProjectDoctor.required_gaps_in_container(resource_text, watched),
		[{"script": "res://things/watched_thing.gd", "property": "title"}]) and all_passed

	return all_passed


static func _eq(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] required_fields_doctor_test: %s" % label)
		return true
	print("[FAIL] required_fields_doctor_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
