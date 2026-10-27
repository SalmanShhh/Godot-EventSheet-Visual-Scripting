# EventSheets - every script and shader the repository ships carries its `.uid` sidecar, and the
# sidecars name nothing twice.
#
# Godot (4.4 and later) names a script or a shader by a uid kept in a `<file>.uid` sidecar beside it,
# and scenes, resources and project.godot refer to the file by that uid. A checkout or a user install
# that arrives without the sidecars invents new ids on its first import: every reference written
# against the old ids falls back to its path with a warning, a project that already had the plugin
# prints one "Missing .uid file" warning per script it had cached, and project.godot's autoload line
# churns on every machine. So the sidecars are committed, and this test holds the set to the tree:
#
#   * every tracked `.gd`, `.gdshader` and `.gdshaderinc` has a tracked `.uid`, and every tracked
#     `.uid` still has its source - a sidecar left behind by a rename names a file that is gone;
#   * no uid is spelled by two files, counting the uid a `.import` file carries in its own right.
#
# ONE EXEMPTION, and it is the engine's rule rather than a list: a folder holding a `.gdignore` is
# invisible to the importer, so nothing in it is ever given a sidecar (`script_templates/`, the
# runtime demo actor). `tests/fixtures/` is NOT exempt - its deliberately broken scripts are imported
# like any other file and get their sidecars like any other file.
#
# "Tracked" is git's answer (`git ls-files`), not the disk's: an ignored generated script sitting in
# a working copy is not shipped, and a sidecar the import just wrote is not shipped until it is
# committed.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "uid_sidecars_test"

## The file kinds Godot gives a `.uid` sidecar to, among the kinds this repository holds.
const SIDECAR_SOURCES: PackedStringArray = ["gd", "gdshader", "gdshaderinc"]

## The translators' template is kept as a plain file (`importer="keep"`), and its `.import` must NOT
## carry a `uid=` line: Godot 4.7 crashes mid-import when a project that already cached an id for the
## file meets a kept `.import` naming a different one, which is exactly what an update would ship.
const TEMPLATE_IMPORT: String = "addons/eventsheet/translations/TEMPLATE.csv.import"


static func run() -> bool:
	# The detectors, pinned by value FIRST: a sweep that matched nothing would report a clean tree
	# just as convincingly as a clean tree does.
	var ok: bool = SUPPORT.pins(P, [
		["a script without its sidecar is named", sidecar_problems(PackedStringArray(["a/b.gd"])),
			PackedStringArray(["a/b.gd has no a/b.gd.uid"])],
		["a shader without its sidecar is named",
			sidecar_problems(PackedStringArray(["s.gdshader", "s.gdshaderinc.uid", "s.gdshaderinc"])),
			PackedStringArray(["s.gdshader has no s.gdshader.uid"])],
		["a sidecar whose source is gone is named", sidecar_problems(PackedStringArray(["gone.gd.uid"])),
			PackedStringArray(["gone.gd.uid has no gone.gd"])],
		["a matched pair is no problem", sidecar_problems(PackedStringArray(["x.gd", "x.gd.uid"])),
			PackedStringArray()],
		["a folder holding .gdignore is exempt",
			sidecar_problems(PackedStringArray(["t/.gdignore", "t/n/x.gd", "y.gd", "y.gd.uid"])),
			PackedStringArray()],
		["a file beside a .gdignore'd folder is not exempt",
			sidecar_problems(PackedStringArray(["t/.gdignore", "tx/x.gd"])),
			PackedStringArray(["tx/x.gd has no tx/x.gd.uid"])],
		["a uid spelled twice is named, with both files",
			duplicate_uids({"a.gd.uid": "uid://abc", "b.gd.uid": "uid://abc", "c.gd.uid": "uid://xyz"}),
			PackedStringArray(["uid://abc: a.gd.uid, b.gd.uid"])],
		["the uid line of an .import file is read",
			import_uid("[remap]\n\nimporter=\"keep\"\nuid=\"uid://q1\"\n"), "uid://q1"],
		["an .import file without a uid line reads as none", import_uid("[remap]\n\nimporter=\"keep\"\n"), ""],
	])

	var tracked: PackedStringArray = tracked_files()
	ok = SUPPORT.check(P, "git lists the tracked files", tracked.has("project.godot"), true) and ok
	if tracked.is_empty():
		return false
	ok = SUPPORT.check(P, "every tracked script and shader has its tracked sidecar, and the reverse",
		sidecar_problems(tracked), PackedStringArray()) and ok
	ok = SUPPORT.check(P, "the translators' kept template names no uid an update would crash on",
		import_uid(_read(TEMPLATE_IMPORT)), "") and ok
	ok = SUPPORT.check(P, "no uid is spelled by two tracked files",
		duplicate_uids(_tracked_uids(tracked)), PackedStringArray()) and ok
	return ok


## Every problem with the sidecars of `paths` (repository-relative, `/`-separated), sorted: a source
## without its `.uid`, and a `.uid` without its source. Files under a folder that holds a `.gdignore`
## are skipped, because the importer never sees them.
static func sidecar_problems(paths: PackedStringArray) -> PackedStringArray:
	var present: Dictionary = {}
	var ignored_dirs: PackedStringArray = PackedStringArray()
	for path: String in paths:
		present[path] = true
		if path.get_file() == ".gdignore":
			ignored_dirs.append(path.get_base_dir() + "/")
	var problems: PackedStringArray = PackedStringArray()
	for path: String in paths:
		if _under_any(path, ignored_dirs):
			continue
		if SIDECAR_SOURCES.has(path.get_extension()) and not present.has(path + ".uid"):
			problems.append("%s has no %s.uid" % [path, path])
		elif path.get_extension() == "uid" and not present.has(path.get_basename()):
			problems.append("%s has no %s" % [path, path.get_basename()])
	problems.sort()
	return problems


## Each uid spelled by more than one file, as `<uid>: <file>, <file>` lines, sorted. `uids_by_file`
## maps a file to the uid it carries.
static func duplicate_uids(uids_by_file: Dictionary) -> PackedStringArray:
	var files_by_uid: Dictionary = {}
	for file: Variant in uids_by_file.keys():
		var uid: String = str(uids_by_file[file])
		# A PackedStringArray is copied on read, so the grown list is written back.
		var files: PackedStringArray = files_by_uid.get(uid, PackedStringArray())
		files.append(str(file))
		files_by_uid[uid] = files
	var lines: PackedStringArray = PackedStringArray()
	for uid: Variant in files_by_uid.keys():
		var files: PackedStringArray = files_by_uid[uid]
		if files.size() > 1:
			files.sort()
			lines.append("%s: %s" % [uid, ", ".join(files)])
	lines.sort()
	return lines


## The `uid="..."` an `.import` file carries, or "" when it carries none.
static func import_uid(text: String) -> String:
	for line: String in text.split("\n"):
		if line.begins_with("uid=\""):
			return line.trim_prefix("uid=\"").trim_suffix("\"").strip_edges()
	return ""


## The repository's tracked files, repository-relative. Empty when git cannot answer, which the
## caller reports as a failure rather than as a clean tree.
static func tracked_files() -> PackedStringArray:
	var output: Array = []
	var root: String = ProjectSettings.globalize_path("res://")
	var code: int = OS.execute("git", ["-C", root, "-c", "core.quotepath=off", "ls-files"], output, true)
	if code != 0:
		print("[uid_sidecars_test] git could not list the tracked files: %s" % "\n".join(PackedStringArray(output)))
		return PackedStringArray()
	var files: PackedStringArray = PackedStringArray()
	for line: String in "\n".join(PackedStringArray(output)).split("\n", false):
		files.append(line.strip_edges())
	return files


## Every uid a tracked file carries in its own right: each `.uid` sidecar's, and each `.import`
## file's own `uid=` line.
static func _tracked_uids(tracked: PackedStringArray) -> Dictionary:
	var uids: Dictionary = {}
	for path: String in tracked:
		if path.get_extension() == "uid":
			uids[path] = _read(path).strip_edges()
		elif path.get_extension() == "import":
			var uid: String = import_uid(_read(path))
			if not uid.is_empty():
				uids[path] = uid
	return uids


static func _read(relative_path: String) -> String:
	return FileAccess.get_file_as_string("res://" + relative_path)


static func _under_any(path: String, dirs: PackedStringArray) -> bool:
	for dir: String in dirs:
		if path.begins_with(dir):
			return true
	return false
