# Godot EventSheets - which tests a change could plausibly have broken.
#
# WHAT THIS IS FOR, AND WHAT IT IS NOT. The full suite is the verdict, always, and it runs before
# every commit. This is the ITERATION tool that comes before that: while a change is still moving,
# running four tests takes seconds and running six hundred takes minutes, and the difference decides
# how many times an idea gets tried. A green run here means nothing more than "the tests most likely
# to notice this did not notice it".
#
# HOW A CHANGE IS TURNED INTO A LIST. Two rules, in this order:
#   1. THE NAMING CONVENTION does most of it. `tests/<x>_test.gd` tests `<x>.gd`, wherever that file
#      lives, and a changed test picks itself. A changed file whose name is a compound (`multiplayer_
#      lift.gd`) also picks the family that shares its first word, as long as that word is a real
#      subject rather than one of the words half the plugin is called after (`sheet`, `event`, ...).
#   2. THE OVERRIDES fill in what a name cannot say: the compiler has no `sheet_compiler_test.gd`, it
#      has five tests that compile things. That table is an OVERRIDE LIST - it exists for the cases
#      the convention gets wrong, and every name in it is checked to be a real file by the test
#      beside this script, so it cannot rot into a list of tests that no longer exist.
#
# USAGE (the binary is Godot 4.7; keep the path out of anything committed):
#   "$GODOT" --headless --path . --script tools/pick_tests.gd              # what git says changed
#   "$GODOT" --headless --path . --script tools/pick_tests.gd -- run       # and run them
#   "$GODOT" --headless --path . --script tools/pick_tests.gd -- files a.gd b.gd [run]
@tool
extends SceneTree

## Where the suite keeps its tests, and what one is called.
const TESTS_DIR: String = "res://tests/"
const TEST_SUFFIX: String = "_test.gd"

## Words too many files are named after to say anything about which tests to run. A changed
## `sheet_compiler.gd` that picked every `sheet_*_test.gd` would pick a third of the suite and teach
## everyone to ignore the answer.
const CROWDED_WORDS: Array[String] = [
	"ace", "addon", "base", "code", "core", "data", "dock", "editor", "event", "eventsheet", "file",
	"helper", "main", "node", "param", "params", "plugin", "row", "rows", "sheet", "test", "tests",
	"tool", "tools", "ui", "util", "utils", "view"
]

## The overrides: a path fragment, and the tests that answer for anything under it. Reached for when
## the convention cannot know - a folder whose files have no same-named test, or a change that gates
## something written down elsewhere (a doc, a theme token, a pack recipe).
const OVERRIDES: Dictionary = {
	"addons/eventforge/compiler/": ["compile_demo_test", "compiler_state_leak_test",
		"external_sheet_test", "host_target_codegen_test", "subevent_compile_test"],
	"addons/eventforge/importer/": ["ace_lift_test", "handwritten_lift_gate_test", "importer_test",
		"lift_table_test", "lighting_lift_test", "per_function_lift_test"],
	"addons/eventforge/registration/": ["ace_descriptions_test", "builtin_ace_compile_test",
		"light_words_test", "vocabulary_l10n_test"],
	"addons/eventsheet/editor/": ["event_sheet_editor_test"],
	"addons/eventsheet/theme/": ["event_sheet_style_test", "ui_scale_test"],
	"addons/eventsheet/api/": ["api_extension_seams_test"],
	"tools/pack_builders/": ["addon_composition_test", "behavior_index_test"],
	"docs/": ["doc_library_test", "docs_integrity_test", "docs_links_test"],
	"CHANGELOG.md": ["docs_integrity_test"]
}

## The gates that read every file of a kind rather than any one feature, so any change to one picks
## them: the style guide sweeps `.gd`, the personal-path sweep reads every text file in the tree.
const EVERY_GDSCRIPT: Array[String] = ["style_guide_test"]
const EVERY_TEXT_FILE: Array[String] = ["personal_paths_test"]

## The text files the personal-path sweep reads. Anything else (an image, a `.import`) changes
## nothing a test can see.
const TEXT_SUFFIXES: Array[String] = [".gd", ".md", ".tres", ".tscn", ".cfg", ".csv", ".json", ".txt"]


func _init() -> void:
	var arguments: PackedStringArray = PackedStringArray(OS.get_cmdline_user_args())
	var changed: PackedStringArray = _requested_files(arguments)
	if changed.is_empty():
		changed = changed_files()
	var picked: PackedStringArray = pick(changed)
	print("changed: %d file(s)" % changed.size())
	for name: String in picked:
		print("  %s" % name)
	print("%d test(s) picked. This is an ITERATION list, never a verdict - the full suite is." % picked.size())
	if not arguments.has("run"):
		quit(0)
		return
	quit(1 if not _run(picked).is_empty() else 0)


## The tests a set of changed files could plausibly have broken, sorted and without repeats. The
## whole mapping, and the only thing the test beside this script needs to call.
static func pick(changed: PackedStringArray) -> PackedStringArray:
	var picked: Dictionary = {}
	var known: Dictionary = _known_tests()
	for path: String in changed:
		var relative: String = path.trim_prefix("res://").replace("\\", "/")
		for name: String in _named_by(relative, known):
			picked[name] = true
		for fragment: String in OVERRIDES.keys():
			if relative.contains(fragment):
				for name: String in OVERRIDES[fragment]:
					picked[name] = true
		if relative.ends_with(".gd"):
			for name: String in EVERY_GDSCRIPT:
				picked[name] = true
		for suffix: String in TEXT_SUFFIXES:
			if relative.ends_with(suffix):
				for name: String in EVERY_TEXT_FILE:
					picked[name] = true
				break
	var names: PackedStringArray = PackedStringArray()
	for name: String in picked.keys():
		if known.has(name):
			names.append(name)
	names.sort()
	return names


## The mapping asked BACKWARDS: which of these changed files would have picked `test_name`. One
## failing test plus an afternoon of edits is the moment this answers - "of the forty files you
## touched, these three are the ones that reach this test". Same rules, so an answer here and an
## answer from `pick` can never disagree.
static func blamed_files(test_name: String, changed: PackedStringArray) -> PackedStringArray:
	var blamed: PackedStringArray = PackedStringArray()
	var wanted: String = test_name.trim_suffix(".gd")
	for path: String in changed:
		if pick(PackedStringArray([path])).has(wanted):
			blamed.append(path)
	return blamed


## What git says has changed: staged, unstaged and UNTRACKED alike, which is why this reads `status`
## rather than `diff` - a brand-new test file is exactly the change most worth running. Empty (with a
## word about why) when git cannot be reached, so the tool says "I do not know" rather than "nothing".
static func changed_files() -> PackedStringArray:
	var output: Array = []
	var code: int = OS.execute("git", ["status", "--porcelain"], output, true)
	if code != 0:
		print("git could not be run here, so nothing is picked: %s" % ", ".join(PackedStringArray(output)))
		return PackedStringArray()
	return status_paths(str("\n".join(PackedStringArray(output))))


## The paths out of `git status --porcelain`: two status letters, a space, then the path - or, for a
## rename, `old -> new`, of which the new name is the one that exists to be tested.
static func status_paths(status_text: String) -> PackedStringArray:
	var changed: PackedStringArray = PackedStringArray()
	for line: String in status_text.split("\n"):
		if line.length() < 4:
			continue
		var path: String = line.substr(3).strip_edges().trim_prefix("\"").trim_suffix("\"")
		if path.contains(" -> "):
			path = path.get_slice(" -> ", 1)
		if not path.is_empty():
			changed.append(path)
	return changed


# ── the pieces ──────────────────────────────────────────────────────────────────


## Rule 1, the naming convention: the test named after this file, and the family that shares its
## first word when that word is its own subject.
static func _named_by(relative: String, known: Dictionary) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	var stem: String = relative.get_file().get_basename()
	if relative.begins_with("tests/") and relative.ends_with(TEST_SUFFIX):
		names.append(stem)
		return names
	if known.has(stem + "_test"):
		names.append(stem + "_test")
	var first_word: String = stem.get_slice("_", 0)
	if first_word.length() < 4 or CROWDED_WORDS.has(first_word):
		return names
	for name: String in known.keys():
		if name.begins_with(first_word + "_"):
			names.append(name)
	return names


## Every test the suite has, by name, so a pick can never name one that does not exist.
static func _known_tests() -> Dictionary:
	var known: Dictionary = {}
	var dir: DirAccess = DirAccess.open(TESTS_DIR)
	if dir == null:
		return known
	for file_name: String in dir.get_files():
		var name: String = file_name.trim_suffix(".remap")
		if name.ends_with(TEST_SUFFIX):
			known[name.trim_suffix(".gd")] = true
	return known


## Explicit files after `files`, for a synthetic diff or a change git has not been told about yet.
static func _requested_files(arguments: PackedStringArray) -> PackedStringArray:
	var requested: PackedStringArray = PackedStringArray()
	var collecting: bool = false
	for argument: String in arguments:
		if argument == "files":
			collecting = true
		elif argument == "run":
			collecting = false
		elif collecting:
			requested.append(argument)
	return requested


## Runs the picked tests in this process and returns the ones that failed. The same shape the suite
## uses: load the file, call run(), believe the boolean.
static func _run(names: PackedStringArray) -> PackedStringArray:
	var failed: PackedStringArray = PackedStringArray()
	for name: String in names:
		var script: GDScript = load("%s%s.gd" % [TESTS_DIR, name])
		if script == null or not script.has_method("run"):
			print("[SKIP] %s has no run()" % name)
			continue
		print("--- %s" % name)
		if not bool(script.call("run")):
			failed.append(name)
	print("failed: %s" % ", ".join(failed) if not failed.is_empty() else "all picked tests passed")
	return failed
