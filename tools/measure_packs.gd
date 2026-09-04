# Measures how many behaviour packs this repo actually ships, and (with --write) puts that number
# back into the two files that quote it. Run:
#   godot --headless --path . --script tools/measure_packs.gd
#   godot --headless --path . --script tools/measure_packs.gd -- --write
#
# WHY THIS EXISTS: README.md quotes the pack count in three sentences and CLAUDE.md in one, all as
# hand-typed literals. Nothing derived them, so they drifted every time a pack landed (121 -> 123 ->
# 125 in a single night, while the tree held more than any of those). This tool is the one place the
# number is computed, `tests/pack_count_records_test.gd` calls the SAME function and fails when a
# quoted literal disagrees, and the release ritual runs it with --write.
#
# THE RULE, EXACTLY. A pack is a FOLDER under `res://eventsheet_addons/` that a builder in
# `tools/pack_builders/` publishes. The builders are the source of truth, not the folders on disk,
# for the same reason `tools/build_sample_behaviors.gd` discovers them by glob: the shipped tree is
# COMPILER OUTPUT, and a stray folder somebody left behind is not a pack anybody can rebuild.
# Discovery mirrors that builder walk exactly - every `*.gd` in `tools/pack_builders/` except the
# leading-underscore shared helpers (`_lib.gd`) - and a builder counts when it hands `Lib.save_pack`
# or `Lib.publish` a destination that lies in a SUBFOLDER of `res://eventsheet_addons/`.
#
# WHAT COUNTS:
#   - Every folder pack, including the RESOURCE-ONLY ones (`ability_set_resource`,
#     `damage_type_set_resource`, `uhtn_plan_resource`, `touch_shape_library_resource`, ...). They
#     ship a folder under `eventsheet_addons/` and install exactly like any other pack, so a reader
#     counting the folder listing counts them, and so does this.
#   - A folder whose builder is named differently from it (`platformer.gd` publishes
#     `platformer_movement/`), because the destination string is read, not the file name.
#   - A folder published by more than one builder counts ONCE: the count is of DISTINCT folders. The
#     tool also prints the number of publishing builders beside it so the day those two diverge is
#     the day somebody sees it rather than the day a number quietly shifts.
#
# WHAT DOES NOT COUNT:
#   - The root runtime files `eventsheet_addons/free_spot.gd` and `eventsheet_addons/pooled_nodes.gd`.
#     Their builders publish to `res://eventsheet_addons/<name>` with no folder: they are single
#     scripts the packs lean on, not packs somebody attaches.
#   - `eventsheet_addons/demo_health_addon.gd` and `demo_note_block.gd`. Hand-written demonstrations
#     of the zero-config ACE seam, with no builder at all, so the builder walk never sees them.
#   - `tools/pack_builders/_lib.gd` and any future leading-underscore helper - shared code, not a pack.
#   - Anything under `eventsheet_addons/` with no builder behind it (today: `behavior.svg`, the icon
#     every pack shares).
#
# THE FILES --write REWRITES: `README.md` and `CLAUDE.md`, and in them only the pack-count sentences
# - the literal immediately before "behavior packs" / "behaviour packs". Nothing else moves. The
# CHANGELOG is deliberately NOT in the list: its entries are the count as it stood on a release day,
# which is history and must stay wrong-by-now.
#
# WHICH TREE IT MEASURES: the one on disk, which is what a working copy holds and what CI checks out.
# A builders folder that is not this project's can be measured with `-- builders=<path>` (an OS path
# is accepted, not only `res://`). That is the way to ask what a COMMIT holds while the working copy
# carries somebody's half-finished pack beside it: `git archive HEAD tools/pack_builders` into a
# scratch folder and point the tool at it. Without that, an uncommitted builder counts, the records
# get a number no clean checkout can reproduce, and the gate goes red on a runner instead of here.
@tool
extends SceneTree

## Where the pack builders live. The same folder `tools/build_sample_behaviors.gd` globs, walked the
## same way, so the two can never disagree about which files are builders.
const BUILDERS_DIR := "res://tools/pack_builders/"

## The files that quote the count in prose. Order is the order the run reports them in.
const RECORD_FILES: Array[String] = ["res://README.md", "res://CLAUDE.md"]

## The destination a builder hands to `Lib.save_pack` / `Lib.publish`, captured down to the FOLDER
## name. The trailing slash in the pattern is what separates a pack from a root runtime file:
## "res://eventsheet_addons/wrap/wrap_behavior" matches and yields "wrap", while
## "res://eventsheet_addons/free_spot" has nothing after the name and never matches.
const PUBLISH_PATTERN := "(?:save_pack|publish)\\(\\s*[A-Za-z_][A-Za-z0-9_]*\\s*,\\s*\"res://eventsheet_addons/([A-Za-z0-9_]+)/"

## A pack-count sentence in the prose files: a bare number directly before "behavior packs" (or the
## British spelling). Group 1 is the literal --write replaces. "the save-state seam on 18 packs"
## does NOT match, which is the point of requiring the word between them.
const RECORD_PATTERN := "([0-9]+)(\\s+behaviou?r packs)"

## The line a red gate prints so the reader never has to reconstruct the invocation.
const FIX_LINE := "\"$GODOT\" --headless --path . --script tools/measure_packs.gd -- --write"


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var write: bool = args.has("--write")
	var builders_dir: String = BUILDERS_DIR
	for arg: String in args:
		if arg.begins_with("builders="):
			builders_dir = arg.trim_prefix("builders=")
			if not builders_dir.ends_with("/"):
				builders_dir += "/"
	var folders: PackedStringArray = pack_folders(builders_dir)
	var count: int = folders.size()
	print("packs=%d builders=%d from=%s" % [count, publishing_builders(builders_dir), builders_dir])
	var stale: int = 0
	for path: String in RECORD_FILES:
		var quoted: PackedInt32Array = record_counts(path)
		if quoted.is_empty():
			print("%s: no pack-count sentence found" % path)
			stale += 1
			continue
		var wrong: int = 0
		for value: int in quoted:
			wrong += 1 if value != count else 0
		if write:
			var changed: int = rewrite_record(path, count)
			print("%s: %d sentence(s), %d rewritten to %d" % [path, quoted.size(), changed, count])
		else:
			print("%s: %d sentence(s), %d disagree with %d" % [path, quoted.size(), wrong, count])
			stale += wrong
	if not write and stale > 0:
		print("stale=%d - fix with: %s" % [stale, FIX_LINE])
	quit(0)


## Every pack folder under `res://eventsheet_addons/` that a builder publishes, sorted and without
## duplicates. This is THE measurement: `size()` is the number the README and CLAUDE.md quote, and
## `tests/pack_count_records_test.gd` calls this same function rather than counting anything itself.
##
## `builders_dir` is passed in rather than hard-coded so the test can pin the walk by VALUE against a
## small fixture folder instead of against the live tree, which moves under it every day.
static func pack_folders(builders_dir: String) -> PackedStringArray:
	var folders: PackedStringArray = PackedStringArray()
	var regex: RegEx = RegEx.new()
	regex.compile(PUBLISH_PATTERN)
	for source: String in _builder_sources(builders_dir):
		for found: RegExMatch in regex.search_all(source):
			var folder: String = found.get_string(1)
			if not folders.has(folder):
				folders.append(folder)
	folders.sort()
	return folders


## How many BUILDERS publish at least one pack folder. Equal to `pack_folders().size()` while every
## pack has exactly one builder and every builder exactly one pack; printed beside the count so a
## future two-packs-in-one-builder (or two-builders-one-folder) is visible instead of silent.
static func publishing_builders(builders_dir: String) -> int:
	var regex: RegEx = RegEx.new()
	regex.compile(PUBLISH_PATTERN)
	var publishing: int = 0
	for source: String in _builder_sources(builders_dir):
		publishing += 1 if regex.search(source) != null else 0
	return publishing


## Every pack-count literal quoted in one prose file, in the order they appear. Empty when the file
## is missing or quotes none, which callers treat as a failure rather than as agreement.
static func record_counts(path: String) -> PackedInt32Array:
	var quoted: PackedInt32Array = PackedInt32Array()
	if not FileAccess.file_exists(path):
		return quoted
	var regex: RegEx = RegEx.new()
	regex.compile(RECORD_PATTERN)
	for found: RegExMatch in regex.search_all(FileAccess.get_file_as_string(path)):
		quoted.append(found.get_string(1).to_int())
	return quoted


## Rewrites every pack-count literal in one prose file to `count` and returns how many it changed.
## Matches are replaced from the LAST one backwards so an earlier edit cannot shift a later match's
## offsets. A file whose literals already all read `count` is left untouched on disk, so a no-op run
## produces no diff and no modification time change.
static func rewrite_record(path: String, count: int) -> int:
	if not FileAccess.file_exists(path):
		push_error("[measure_packs] no such file: %s" % path)
		return 0
	var text: String = FileAccess.get_file_as_string(path)
	var regex: RegEx = RegEx.new()
	regex.compile(RECORD_PATTERN)
	var found: Array[RegExMatch] = regex.search_all(text)
	var changed: int = 0
	for index: int in range(found.size() - 1, -1, -1):
		var match_at: RegExMatch = found[index]
		if match_at.get_string(1).to_int() == count:
			continue
		var start: int = match_at.get_start(1)
		var end: int = match_at.get_end(1)
		text = text.substr(0, start) + str(count) + text.substr(end)
		changed += 1
	if changed == 0:
		return 0
	var handle: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if handle == null:
		push_error("[measure_packs] cannot write %s" % path)
		return 0
	handle.store_string(text)
	handle.close()
	return changed


## The source text of every builder in `builders_dir`, in sorted order. Leading-underscore files are
## shared helpers, not packs, and are skipped here exactly as the build script skips them.
static func _builder_sources(builders_dir: String) -> Array[String]:
	var sources: Array[String] = []
	var dir: DirAccess = DirAccess.open(builders_dir)
	if dir == null:
		push_error("[measure_packs] cannot open %s" % builders_dir)
		return sources
	var names: PackedStringArray = dir.get_files()
	names.sort()
	for file_name: String in names:
		if not file_name.ends_with(".gd") or file_name.begins_with("_"):
			continue
		sources.append(FileAccess.get_file_as_string(builders_dir.path_join(file_name)))
	return sources
