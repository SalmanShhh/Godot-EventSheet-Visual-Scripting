# Godot EventSheets - the Doctor's note for a scene slot that is empty where it is spawned from.
#
# A script that declares `@export var star_scene: PackedScene` and runs `star_scene.instantiate()` does
# nothing useful until a scene node fills that slot in the Inspector. Godot leaves an unset slot out of the
# scene file, and the game then stops on a line that reads fine. This note says so, once per slot and scene,
# in two short sentences: which slot, which scene, and where to fill it. The script is the finding's own file.
#
# It reads text and nothing else. A slot counts only when it is a typed PackedScene export with no value and
# its own name is followed by `.instantiate()` in the same script; a scene counts only when a node in it runs
# the script and writes no value for the slot. A script the plugin ships is never named. A note, never a
# warning. Registered by path, with no class_name of its own.
@tool
extends "res://addons/eventforge/doctor_section.gd"

const CHECK_ID := "scene-slot-empty"
const THIS_SCRIPT := "res://addons/eventforge/scene_slot_doctor.gd"

static var _slot_re: RegEx = null


## Registers the section, replacing any earlier registration.
static func ensure_registered() -> void:
	EventSheetProjectDoctor.register_check(CHECK_ID, Callable(load(THIS_SCRIPT), "check"))


## The section, with the contract every registered check has: append findings, never write inside res://.
static func check(_sheet_paths: PackedStringArray, findings: Array[Dictionary]) -> void:
	var watched: Dictionary = {}
	for script_path: String in own_paths(EventSheetProjectDoctor._project_scripts()):
		var source: String = EventSheetProjectDoctor.source_of(script_path)
		if not source.contains("PackedScene") or not source.contains(".instantiate()"):
			continue
		var empty: Dictionary = empty_slots(source)
		if not empty.is_empty():
			watched[script_path] = empty.keys()
	if watched.is_empty():
		return
	for scene_path: String in EventSheetProjectDoctor._list_files_with_extension("tscn"):
		if scene_path.begins_with(PLUGIN_DIRECTORY):
			continue
		var text: String = EventSheetProjectDoctor.source_of(scene_path)
		for script_path: Variant in watched.keys():
			for slot: String in gaps_in_scene(text, str(script_path), watched[script_path]):
				findings.append(report(str(script_path), slot, scene_path))


## The finding for one empty slot: two short sentences. Filed under the script that spawns from it, with the
## slot's name as its subject.
static func report(script_path: String, slot: String, scene_path: String) -> Dictionary:
	var message: String = EventSheetL10n.translate("%s is empty in %s. Set it in the Inspector.") \
		% [slot, scene_path.get_file()]
	return _finding("info", CHECK_ID, script_path, message, slot)


## {slot name: true} for the PackedScene slots of `source` that hold no value and that the script spawns
## from. A slot given a value (`= preload(...)`) is filled already, and one the script never instantiates has
## nothing to spawn.
static func empty_slots(source: String) -> Dictionary:
	if _slot_re == null:
		_slot_re = RegEx.create_from_string("(?m)^@export(?:_[a-z_]+\\([^)]*\\))?[ \\t]+var[ \\t]+([A-Za-z_][A-Za-z0-9_]*)[ \\t]*:[ \\t]*PackedScene[ \\t]*(?:=[ \\t]*null[ \\t]*)?$")
	var found: Dictionary = {}
	for hit: RegExMatch in _slot_re.search_all(source):
		var slot: String = hit.get_string(1)
		if source.contains("%s.instantiate()" % slot):
			found[slot] = true
	return found


## The slots of `slots` that the scene text leaves unset on a node running `script_path`. Godot leaves a value
## that equals the default out of the scene file, so a node with no line for the slot has it empty.
static func gaps_in_scene(text: String, script_path: String, slots: Array) -> Array:
	var gaps: Array = []
	if not text.contains(script_path):
		return gaps
	var id_match: RegExMatch = RegEx.create_from_string("\\[ext_resource[^\\]]*path=\"%s\"[^\\]]*id=\"([^\"]+)\"" % script_path.replace("/", "\\/")).search(text)
	if id_match == null:
		return gaps
	var script_ref: String = "script = ExtResource(\"%s\")" % id_match.get_string(1)
	for block: String in text.split("\n["):
		if not block.contains(script_ref):
			continue
		for slot: Variant in slots:
			if not block.contains("\n%s = " % str(slot)) and not gaps.has(slot):
				gaps.append(slot)
	return gaps
