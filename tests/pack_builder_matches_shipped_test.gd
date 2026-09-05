# Godot EventSheets - the shipped packs and the builders that produce them must agree.
# eventsheet_addons/ is compiler output: every file there is supposed to be exactly what
# tools/pack_builders/<name>.gd emits today. Nothing noticed when the two drifted apart, because
# the disagreement only surfaces when somebody runs the rebuild - and then it looks like their
# change, not like a debt that had been sitting there. So this gate rebuilds packs through the real
# builders (redirected to a temporary directory, so the repository is never touched) and compares
# the bytes against the shipped files.
#
# tools/audit_addons.gd does NOT answer this question. It opens each SHIPPED pack, recompiles it and
# compares it to itself - a round trip that never runs a builder, so it prints drifted=0 over a tree
# whose builders would today write something else. That is how sixteen packs sat stale behind a green
# gate: a lifter fix taught the round trip to keep the prose doc comment an author wrote above an
# annotated function instead of collapsing it into one @ace_description line, and every pack built
# before that fix still shipped the collapsed form.
#
# WHAT RUNS: three pinned packs every time, plus a rotating slice of every other builder chosen by
# the date, so the whole tree is swept over ROTATION_DAYS days without paying for 145 rebuilds in
# every run. The three pins cover what drifted before: member order with exported and internal
# variables interleaved (car), Inspector groups, whose headers move with the variables they precede
# (uhtn_plan_resource), and a builder that assembles its pack out of a source FOLDER rather than out
# of string literals (wrap), where a change to the reader of those folders - what a piece is, where
# it is dedented to, which of its blank lines belong to the pack - is a change to emitted bytes.
#
# Set EVENTFORGE_PACK_GATE=all to sweep every builder in one run (what to do before a release, and
# what a bisect wants), or to a comma-separated list of builder basenames to check just those.
#
# When this fails: the builder is the thing to change, never the shipped pack - member order is
# user-visible (the head bars read in file order, and a .tres stores properties in the script's
# declaration order), so reordering a builder's `sheet.variables` rewrites shipped files and any
# resource saved against them. When the builder is right and the shipped bytes are merely old, the
# fix is a regeneration: run tools/build_sample_behaviors.gd in a throwaway checkout and copy the
# pack files back.
@tool
class_name PackBuilderMatchesShippedTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const Lib := preload("res://tools/pack_builders/_lib.gd")

# Runs in the serial tail, for two reasons. `Lib.output_override_dir` is a shared static: a
# neighbouring test that publishes a pack while this one holds the override would write into this
# test's temporary directory, or read its own output from there. And a rotation slice rebuilds
# roughly two dozen packs, which is minutes of work that would make one shard much longer than the
# others.
const PARALLEL_UNSAFE := true

const PIN := "pack_builder_matches_shipped_test"
const TEMP_DIR := "user://eventsheets_pack_builder_gate"
const BUILDERS_DIR := "res://tools/pack_builders/"
const PACKS_DIR := "res://eventsheet_addons"

# Checked on EVERY run, whatever the date says - the three shapes that have actually drifted.
const PINNED_BUILDERS := ["car", "uhtn_plan_resource", "wrap"]

# How many days one full sweep of the remaining builders takes. Seven keeps a run near twenty packs
# while guaranteeing that a pack going stale is named within a week rather than at the next release.
const ROTATION_DAYS := 7


static func run() -> bool:
	var all_passed: bool = true
	DirAccess.make_dir_recursive_absolute(TEMP_DIR)
	var shipped_index: Dictionary = _shipped_by_file_name()
	if shipped_index.is_empty():
		return SUPPORT.check(PIN, "the shipped packs are readable", 0, 1)
	for builder_name: String in _builders_to_check():
		all_passed = _check_builder(builder_name, shipped_index) and all_passed
	return all_passed


## The builders this run rebuilds: the pins plus today's slice, or exactly what EVENTFORGE_PACK_GATE
## names. Sorted and duplicate-free, so the reported order is the same on every machine.
static func _builders_to_check() -> PackedStringArray:
	var requested: String = OS.get_environment("EVENTFORGE_PACK_GATE").strip_edges()
	var every: PackedStringArray = _all_builders()
	if requested.to_lower() == "all":
		return every
	if not requested.is_empty():
		var named: PackedStringArray = PackedStringArray()
		for entry: String in requested.split(",", false):
			var trimmed: String = entry.strip_edges()
			if not trimmed.is_empty() and not named.has(trimmed):
				named.append(trimmed)
		named.sort()
		return named
	var chosen: PackedStringArray = PackedStringArray()
	for pinned: String in PINNED_BUILDERS:
		if every.has(pinned) and not chosen.has(pinned):
			chosen.append(pinned)
	var slice: int = _rotation_slice()
	for index: int in range(every.size()):
		if index % ROTATION_DAYS == slice and not chosen.has(every[index]):
			chosen.append(every[index])
	chosen.sort()
	return chosen


## Which slice of the builder list today's run takes, 0 .. ROTATION_DAYS - 1. Derived from the date
## rather than from a random number so two machines running on the same day check the same packs and
## a failure is reproducible by anyone who reruns it that day (and by anyone, any day, with
## EVENTFORGE_PACK_GATE naming the pack).
##
## Counted in real days since the epoch, so consecutive days always take consecutive slices. Composing
## the number out of the calendar instead (year * 372 + month * 31 + day) skips a slice at the end of
## every short month and three at the end of February, which stretched the promised week to thirteen
## days for half the fleet.
static func _rotation_slice() -> int:
	return int(Time.get_unix_time_from_system() / 86400.0) % ROTATION_DAYS


## Every pack builder's basename, sorted. Leading-underscore files are shared helpers, not packs, and
## are skipped here exactly as tools/build_sample_behaviors.gd skips them.
static func _all_builders() -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	var dir: DirAccess = DirAccess.open(BUILDERS_DIR)
	if dir == null:
		return names
	for file_name: String in dir.get_files():
		if file_name.ends_with(".gd") and not file_name.begins_with("_"):
			names.append(file_name.get_basename())
	names.sort()
	return names


## Every shipped pack script, indexed by file name. `Lib.output_override_dir` flattens a rebuild into
## one directory, so the file name is all a rebuilt file carries - which is sound here because the
## shipped names are unique across the whole tree, and a name that ever stopped being unique is
## reported as an ambiguity rather than silently compared against whichever came first.
##
## The walk is RECURSIVE, at any depth. A pack whose scripts sit in a folder of its own inside the
## pack folder (the post-processing kit ships seven effects under `post_kit/effects/`) is invisible
## to a two-level walk, and every one of its scripts would then be reported as a file no pack ships.
static func _shipped_by_file_name() -> Dictionary:
	var index: Dictionary = {}
	_index_scripts(PACKS_DIR, index)
	return index


## Adds every `.gd` under `dir_path` to `index`, descending into subfolders. Dot-folders are Godot's
## own bookkeeping and hold no pack.
static func _index_scripts(dir_path: String, index: Dictionary) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	for file_name: String in dir.get_files():
		if not file_name.ends_with(".gd"):
			continue
		index[file_name] = "AMBIGUOUS" if index.has(file_name) else "%s/%s" % [dir_path, file_name]
	for folder: String in dir.get_directories():
		if not folder.begins_with("."):
			_index_scripts("%s/%s" % [dir_path, folder], index)


## Rebuilds one pack through its real builder and compares every script it writes, byte for byte,
## with the shipped file of that name.
static func _check_builder(builder_name: String, shipped_index: Dictionary) -> bool:
	var builder: GDScript = load("%s%s.gd" % [BUILDERS_DIR, builder_name])
	if builder == null or not builder.has_method("build"):
		return SUPPORT.check(PIN, "%s: the builder loads" % builder_name, false, true)
	_empty_temp_dir()
	# The override is a shared static, so it is cleared the moment the build returns - a later
	# test that publishes a pack must not inherit this test's temporary directory.
	Lib.output_override_dir = TEMP_DIR
	var built: bool = bool(builder.call("build"))
	Lib.output_override_dir = ""
	var passed: bool = SUPPORT.check(PIN, "%s: the builder compiles" % builder_name, built, true)
	var rebuilt_names: PackedStringArray = _temp_script_names()
	passed = SUPPORT.check(PIN, "%s: the builder writes at least one pack script" % builder_name,
		rebuilt_names.size() > 0, true) and passed
	for file_name: String in rebuilt_names:
		passed = _compare_one(builder_name, file_name, shipped_index) and passed
	_empty_temp_dir()
	return passed


## One rebuilt script against its shipped counterpart.
static func _compare_one(builder_name: String, file_name: String, shipped_index: Dictionary) -> bool:
	var shipped_path: String = str(shipped_index.get(file_name, ""))
	if shipped_path == "AMBIGUOUS":
		return SUPPORT.check(PIN, "%s: %s names exactly one shipped pack script" % [builder_name, file_name], false, true)
	if shipped_path.is_empty():
		# A builder writing a script no pack ships is a pack that was never committed - the same
		# drift in the other direction, and just as invisible until somebody runs the rebuild.
		return SUPPORT.check(PIN, "%s: %s is a shipped pack script" % [builder_name, file_name], false, true)
	var shipped: String = FileAccess.get_file_as_string(shipped_path)
	var rebuilt: String = FileAccess.get_file_as_string(TEMP_DIR.path_join(file_name))
	if rebuilt == shipped:
		return SUPPORT.check(PIN, "%s: the builder reproduces %s" % [builder_name, file_name], true, true)
	return SUPPORT.check(PIN, "%s: the builder reproduces %s (%s)" % [builder_name, file_name,
		_first_difference(shipped, rebuilt)], false, true)


## The script names the last rebuild left in the temporary directory, sorted so the reported order is
## the same on every machine.
static func _temp_script_names() -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	var dir: DirAccess = DirAccess.open(TEMP_DIR)
	if dir == null:
		return names
	for file_name: String in dir.get_files():
		if file_name.ends_with(".gd"):
			names.append(file_name)
	names.sort()
	return names


## Clears the temporary directory between builders, so one builder's output can never be read as the
## next one's (a builder that writes nothing would otherwise be compared against its predecessor).
static func _empty_temp_dir() -> void:
	var dir: DirAccess = DirAccess.open(TEMP_DIR)
	if dir == null:
		return
	for file_name: String in dir.get_files():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_DIR.path_join(file_name)))


## The first line that differs, so a failure names the drift instead of dumping two files.
static func _first_difference(shipped: String, rebuilt: String) -> String:
	var shipped_lines: PackedStringArray = shipped.split("\n")
	var rebuilt_lines: PackedStringArray = rebuilt.split("\n")
	for index: int in range(max(shipped_lines.size(), rebuilt_lines.size())):
		var left: String = shipped_lines[index] if index < shipped_lines.size() else "<end of file>"
		var right: String = rebuilt_lines[index] if index < rebuilt_lines.size() else "<end of file>"
		if left != right:
			return "line %d: shipped %s, rebuilt %s" % [index + 1, left, right]
	return "no line differs (trailing bytes)"
