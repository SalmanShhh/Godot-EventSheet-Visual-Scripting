# Godot EventSheets - the iteration list: which tests a change could plausibly have broken.
#
# `tools/pick_tests.gd` is what makes trying an idea cheap - four tests in seconds instead of six
# hundred in minutes - and the one way it can do harm is by being quietly wrong: a list that misses
# the test that would have caught the mistake buys speed with confidence. So the mapping is pinned
# here by VALUE, on synthetic diffs, in both directions: what a change picks, and what it does not.
#
# The override table is checked against the tests folder as well, because a list of tests that no
# longer exist is the way this kind of tool rots. Nothing here runs the suite; the full suite is the
# verdict and this file says nothing about that.
@tool
class_name ImpactedTestsTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const PICKER_PATH: String = "res://tools/pick_tests.gd"


static func run() -> bool:
	var ok: bool = true
	ok = _test_the_naming_convention() and ok
	ok = _test_the_overrides() and ok
	ok = _test_the_sweeping_gates() and ok
	ok = _test_git_status_is_read() and ok
	return ok


## Rule 1. A test picks itself; a source file picks the test named after it, and the family that
## shares its first word - unless that word is one half the plugin is named after.
static func _test_the_naming_convention() -> bool:
	var ok: bool = _check("a changed test picks itself, and nothing else it is not named after",
		_pick(["tests/lift_table_test.gd"]),
		PackedStringArray(["lift_table_test", "personal_paths_test", "style_guide_test"]))
	ok = _check("a source file picks the test named after it, wherever the file lives",
		_pick(["addons/eventsheet/editor/popup_ui.gd"]),
		PackedStringArray(["event_sheet_editor_test", "personal_paths_test", "popup_ui_test",
			"style_guide_test"])) and ok
	ok = _check("and the family that shares its first word",
		_pick(["addons/eventforge/importer/multiplayer_lift.gd"]).has("multiplayer_vocabulary_test"), true) and ok
	# `sheet_compiler.gd` sharing a first word with `sheet_*_test.gd` would pick a third of the suite,
	# which is the same as picking nothing: nobody waits for it.
	ok = _check("a crowded first word drags nothing in with it",
		_pick(["addons/eventforge/compiler/sheet_compiler.gd"]),
		PackedStringArray(["compile_demo_test", "compiler_state_leak_test", "external_sheet_test",
			"host_target_codegen_test", "personal_paths_test", "style_guide_test",
			"subevent_compile_test"])) and ok
	return ok


## Rule 2. The overrides, and the check that keeps them honest: every test they name is a file.
static func _test_the_overrides() -> bool:
	var picker: Object = load(PICKER_PATH)
	var missing: PackedStringArray = PackedStringArray()
	var overrides: Dictionary = picker.get("OVERRIDES")
	for fragment: String in overrides.keys():
		for name: String in overrides[fragment]:
			if not FileAccess.file_exists("res://tests/%s.gd" % name):
				missing.append("%s -> %s" % [fragment, name])
	# Without this the check above passes vacuously the day the table is renamed out from under it.
	var ok: bool = _check("the override table was actually read", overrides.size() > 5, true)
	ok = _check("every test the overrides name is a real one", missing, PackedStringArray()) and ok
	ok = _check("a documentation change picks the documentation gates, and no code gate",
		_pick(["docs/GUIDE-THEMING.md"]),
		PackedStringArray(["doc_library_test", "docs_integrity_test", "docs_links_test",
			"personal_paths_test"])) and ok
	return ok


## The gates that read every file of a kind, and the change that is not a file any test reads.
static func _test_the_sweeping_gates() -> bool:
	var ok: bool = _check("a binary picks nothing at all",
		_pick(["addons/eventsheet/icons/torch.png"]), PackedStringArray())
	ok = _check("a theme resource picks the sweep that reads every text file, not the GDScript one",
		_pick(["demo/sheets/example.tres"]), PackedStringArray(["personal_paths_test"])) and ok
	# The picker names tests, so a name that is not a test would be a command nobody can run.
	var invented: PackedStringArray = PackedStringArray()
	for name: String in _pick(["addons/eventforge/importer/multiplayer_lift.gd", "docs/README.md"]):
		if not FileAccess.file_exists("res://tests/%s.gd" % name):
			invented.append(name)
	ok = _check("nothing is ever picked that is not a test in the folder", invented, PackedStringArray()) and ok
	return ok


## The reading of `git status --porcelain`, which is where a real run's file list comes from: staged,
## unstaged and untracked, plus the rename that names two paths.
static func _test_git_status_is_read() -> bool:
	var picker: Object = load(PICKER_PATH)
	var status: String = " M addons/eventforge/importer/lift_table.gd\n?? tests/lift_table_test.gd\nR  tools/old_name.gd -> tools/new_name.gd\n"
	return _check("every changed path is read, and a rename by its new name",
		picker.call("status_paths", status),
		PackedStringArray(["addons/eventforge/importer/lift_table.gd", "tests/lift_table_test.gd",
			"tools/new_name.gd"]))


static func _pick(changed: Array) -> PackedStringArray:
	var picker: Object = load(PICKER_PATH)
	return picker.call("pick", PackedStringArray(changed))


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("impacted_tests_test", label, actual, expected)
