# Call Method and Connect Signal read the target's own script.
#
# The rows shipped years of Godot ago and their names are still typed strings: a row says
# `"grant_xp"`, nothing checks it, and a designer has to go and read somebody's script to find out
# what to type. The reading behind both fixes that - it works out which script a row is AIMED at, and
# lists what that script offers with the arguments as written and the `##` comment above the
# declaration as the description. The programmers' own doc comments become the designer's tooltips.
#
# What it cannot resolve, it says nothing about: a target worked out at run time keeps its typed
# string, because a guessed list is worse than no list at all. That is the half that keeps the frozen
# free-string rows honest rather than pretending everything is pickable.
@tool
class_name TargetScriptMembersTest
extends RefCounted

const PROGRESS: String = "res://tests/fixtures/interop_corpus/progress.gd"
const ROOM: String = "res://tests/fixtures/interop_corpus/room.gd"


static func run() -> bool:
	var ok: bool = true
	EventSheetScriptMembers.clear_cache()

	# ── What one script declares, docs and all ──────────────────────────────────────────────
	var declared: Dictionary = EventSheetScriptMembers.of_script(PROGRESS)
	ok = _check("its public methods, in file order", _names(declared["methods"]),
		PackedStringArray(["grant_xp", "complete_quest", "reset"])) and ok
	ok = _check("with the arguments as the file writes them",
		_member(declared["methods"], "complete_quest").get("args", ""), "quest_id, reward") and ok
	ok = _check("and the ## line above the declaration as its description",
		_member(declared["methods"], "grant_xp").get("doc", ""),
		"Grants experience, and levels up when due.") and ok
	ok = _check("its signals too", _names(declared["signals"]),
		PackedStringArray(["leveled_up", "quest_completed"])) and ok
	ok = _check("with their parameters", _member(declared["signals"], "leveled_up").get("args", ""),
		"new_level") and ok
	ok = _check("and their descriptions",
		_member(declared["signals"], "leveled_up").get("doc", ""),
		"Fires after the experience bar rolls over into a new level.") and ok
	ok = _check("a file that is not there declares nothing",
		_names(EventSheetScriptMembers.of_script("res://nothing/here.gd")["methods"]),
		PackedStringArray()) and ok

	# ── Which script a row's target names ───────────────────────────────────────────────────
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(ROOM)
	ok = _check("`self` is the sheet's own script",
		str(EventSheetScriptMembers.target_of(sheet, "self").get("script_path", "")), ROOM) and ok
	ok = _check("a $node of the scene is the script that node wears",
		str(EventSheetScriptMembers.target_of(sheet, "$Hero").get("script_path", "")),
		"res://tests/fixtures/interop_corpus/player.gd") and ok
	ok = _check("and so is the same node written as a get_node call",
		str(EventSheetScriptMembers.target_of(sheet, "get_node(\"Hero\")").get("script_path", "")),
		"res://tests/fixtures/interop_corpus/player.gd") and ok
	ok = _check("a target nothing answers to resolves to nothing",
		EventSheetScriptMembers.target_of(sheet, "whatever_this_is"), {}) and ok

	# ── The list a Call Method field offers ─────────────────────────────────────────────────
	var hero: Array[Dictionary] = EventSheetScriptMembers.methods_for(sheet, "$Hero")
	ok = _check("the node's own methods lead the list",
		_names(hero).slice(0, 3), PackedStringArray(["take_damage", "heal", "die"])) and ok
	ok = _check("and what its engine class adds follows, named with the class it came from",
		_member(hero, "move_and_slide").get("from", ""), "CharacterBody2D") and ok
	ok = _check("a target nothing answers to offers nothing",
		_names(EventSheetScriptMembers.methods_for(sheet, "whatever_this_is")),
		PackedStringArray()) and ok
	ok = _check("the detail line is the arguments then the description",
		EventSheetScriptMembers.detail_of(_member(
			EventSheetScriptMembers.of_script(PROGRESS)["methods"], "grant_xp")),
		"amount · Grants experience, and levels up when due.") and ok
	# The completion seam carries the target as the field kind's argument, so two rows aimed at two
	# objects get two lists and neither is a guess.
	ok = _check("the completion seam answers for the target the kind names",
		_completion_names(sheet, "method_reference:$Hero").has("take_damage"), true) and ok
	ok = _check("and answers differently for a different target",
		_completion_names(sheet, "method_reference:self").has("take_damage"), false) and ok

	# ── Add event: the signals the project's own scripts declare ────────────────────────────
	var sources: Array[Dictionary] = EventSheetScriptMembers.signal_sources(sheet)
	ok = _check("the scene's scripted nodes are listenable sources",
		_source_names(sources).has("Hero"), true) and ok
	var registry: EventSheetACERegistry = EventSheetACERegistry.new()
	registry.refresh_from_sources([] as Array[Object], true)
	var offered: Array[ACEDefinition] = ACEPickerDialog.scene_signal_definitions(sheet, registry)
	var health_changed: ACEDefinition = _definition_for(offered, "health_changed")
	ok = _check("every declared signal is an event waiting to be picked",
		health_changed != null, true) and ok
	if health_changed != null:
		ok = _check("named the way every other trigger is",
			health_changed.display_name, "On health changed") and ok
		ok = _check("described with the script's own line",
			health_changed.description.contains("so the bar can follow"), true) and ok
		ok = _check("carrying the object that emits it",
			str(health_changed.metadata.get(ACEPickerDialog.SIGNAL_SOURCE_META, "")), "Hero") and ok
		ok = _check("and the signal's own argument signature",
			str((health_changed.metadata.get(ACEPickerDialog.SCENE_PREFILL_META, {}) as Dictionary).get("args", "")),
			"current") and ok
		ok = _check("filed under the node it belongs to",
			ACEPickerDialog.scene_lighting_group_key(health_changed).begins_with(
				ACEPickerDialog.SIGNALS_GROUP), true) and ok

	# ── The amber re-pick: a name the target no longer has ──────────────────────────────────
	ok = _check("the nearest name is what a typo is offered",
		ACEParamsDialog.closest_of("take_damag", PackedStringArray(["take_damage", "heal"])),
		"take_damage") and ok
	ok = _check("and nothing is offered when nothing is near",
		ACEParamsDialog.closest_of("explode", PackedStringArray(["take_damage", "heal"])), "") and ok

	return ok


static func _names(members: Array) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	for member: Variant in members:
		names.append(str((member as Dictionary)["name"]))
	return names


static func _member(members: Array, name: String) -> Dictionary:
	for member: Variant in members:
		if str((member as Dictionary)["name"]) == name:
			return member as Dictionary
	return {}


static func _source_names(sources: Array[Dictionary]) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	for source: Dictionary in sources:
		names.append(str(source["label"]))
	return names


static func _completion_names(sheet: EventSheetResource, kind: String) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	for entry: Dictionary in EventSheetCompletions.for_field(sheet, kind, ""):
		names.append(str(entry["text"]))
	return names


static func _definition_for(offered: Array[ACEDefinition], signal_name: String) -> ACEDefinition:
	for definition: ACEDefinition in offered:
		if str((definition.metadata.get(ACEPickerDialog.SCENE_PREFILL_META, {}) as Dictionary).get(
				"signal_name", "")) == signal_name:
			return definition
	return null


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] target_script_members_test: %s" % label)
		return true
	print("[FAIL] target_script_members_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
