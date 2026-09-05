# Godot EventSheets - the pack audit's parse gate (tools/audit_addons.gd).
#
# The audit's job is to fail the build when a shipped pack drifts OR stops compiling. The second
# half was blind: it asked `load(path) == null`, and in Godot 4 a script with a parse error still
# loads as a non-null (invalid) GDScript, so a pack that does not compile was counted healthy and
# the exit-1 branch never fired. These pins hold both sides of that: the blind check's own answer
# on a deliberately broken script, and the real verdict the gate reads now.
#
# The fixture pack folders live under `user://`, so nothing here touches the shipped tree. The
# "Parse Error" lines this test prints are the fixture being read on purpose, not a suite failure.
@tool
class_name PackAuditTest
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")
const AUDIT := preload("res://tools/audit_addons.gd")
const PREFIX := "pack_audit_test"

const FIXTURE_ROOT := "user://_pack_audit_fixture"

## A pack script that does not compile: the initializer's expression is missing.
const BROKEN_SOURCE := "extends Node\n\n\nfunc go() -> void:\n\tvar broken: int = \n"

## The same pack, whole - the control the broken one is only different from in one way.
const GOOD_SOURCE := "extends Node\n\n\nfunc go() -> void:\n\tvar whole: int = 1\n\tprint(whole)\n"


static func run() -> bool:
	var all_passed: bool = true
	var broken_folder: String = _write_fixture_pack("broken_pack", "broken_pack_addon.gd", BROKEN_SOURCE)
	var good_folder: String = _write_fixture_pack("good_pack", "good_pack_addon.gd", GOOD_SOURCE)
	var broken_script: String = AUDIT._find_pack_script(broken_folder)
	var good_script: String = AUDIT._find_pack_script(good_folder)
	all_passed = SUPPORT.pins(PREFIX, [
		["the folder walk finds the pack's one script", broken_script, "%s/broken_pack_addon.gd" % broken_folder],
		["and finds the whole pack's too", good_script, "%s/good_pack_addon.gd" % good_folder],
		# The defect itself, pinned as a value so nobody restores the blind check by accident: a
		# script that cannot compile still loads, so load() alone can never be the parse gate.
		["a script with a parse error still loads as non-null", load(broken_script) != null, true],
		["the audit reports the broken pack as not compiling", AUDIT.script_compiles(broken_script), false],
		["and the whole pack as compiling", AUDIT.script_compiles(good_script), true],
		# A path with no script behind it is a failure, never a silent pass.
		["a missing script cannot compile", AUDIT.script_compiles("%s/nothing_here.gd" % FIXTURE_ROOT), false],
	]) and all_passed
	_remove_fixture()
	return all_passed


## Writes one fixture pack folder (`user://_pack_audit_fixture/<folder>/<file>`) and returns the
## folder path, shaped exactly like a shipped pack: one folder, one `.gd` inside it.
static func _write_fixture_pack(folder: String, file_name: String, source: String) -> String:
	var path: String = "%s/%s" % [FIXTURE_ROOT, folder]
	DirAccess.make_dir_recursive_absolute(path)
	var handle: FileAccess = FileAccess.open("%s/%s" % [path, file_name], FileAccess.WRITE)
	if handle != null:
		handle.store_string(source)
		handle.close()
	return path


## Leaves nothing behind: a fixture that survives the run would be read again by the next one, and
## a cached invalid script is exactly the state these pins are trying to describe.
static func _remove_fixture() -> void:
	for folder: String in ["broken_pack", "good_pack"]:
		var path: String = "%s/%s" % [FIXTURE_ROOT, folder]
		var dir: DirAccess = DirAccess.open(path)
		if dir == null:
			continue
		dir.list_dir_begin()
		var entry: String = dir.get_next()
		while not entry.is_empty():
			DirAccess.remove_absolute("%s/%s" % [path, entry])
			entry = dir.get_next()
		DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(FIXTURE_ROOT)
