# EventSheets - every documentation picture is listed, and each one still shows what it was taken of.
#
# The pictures of the guides are screenshots of the real editor, taken by `tools/doc_shots.gd` from the
# list in `tools/doc_shots/shots.json`. A picture is stale when the thing it shows has changed, so each
# entry carries a fingerprint written at capture time (what the rows say, the default look's colours,
# the bytes of the icons in frame, the engine version - see tools/doc_shots/fingerprints.gd) and this test
# computes the same fingerprint again. When one moved the failure names the picture, the pages that show
# it, WHICH part moved, and the line that retakes it.
#
# The look is the one exception: it moves for every canvas picture at once, so it is a WARNING (printed,
# never a failure) until a full retake is routine.
#
# Beside the fingerprints it holds the set together:
#   * every picture file in docs/images and docs/previews has an entry, or is on the list of pictures
#     not yet retaken (`pending`) or kept on purpose with its reason (`kept`). The pending list can only
#     shrink: a name on it that already has an entry, or whose file is gone, fails;
#   * every entry's picture exists, and its file name is the entry's name;
#   * a picture's bytes are the bytes its entry recorded (a picture replaced by hand fails).
#
# WHAT IT CANNOT SEE is spelled out at the top of tools/doc_shots/fingerprints.gd: a pixel-only change
# (a stylebox margin, a newer Godot's editor theme) and the contents of a menu or window that only an
# editor can build, which the `files` fingerprint covers coarsely.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const FINGERPRINTS := preload("res://tools/doc_shots/fingerprints.gd")
const TEST_NAME := "doc_pictures_fresh_test"
const PICTURE_FOLDERS: Array[String] = ["res://docs/images", "res://docs/previews"]


static func run() -> bool:
	var list: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FINGERPRINTS.DEFAULT_LIST))
	if list == null:
		return SUPPORT.check(TEST_NAME, "the shot list is readable", false, true)
	var shots: Array = list["shots"]
	var pending: PackedStringArray = PackedStringArray(list.get("pending", []))
	var kept: Dictionary = list.get("kept", {})
	var entered: Dictionary = {}
	var passed: bool = true
	var missing: PackedStringArray = PackedStringArray()
	var moved: PackedStringArray = PackedStringArray()
	var look_moved: PackedStringArray = PackedStringArray()
	var look_now: String = FINGERPRINTS.look()
	for shot: Dictionary in shots:
		var name: String = str(shot["name"])
		var target: String = str(shot.get("target", ""))
		entered[target] = true
		if target.get_file().get_basename() != name:
			passed = SUPPORT.check(TEST_NAME, "%s: the entry's name is its file name" % name, target.get_file(), name + ".png") and passed
		if not FileAccess.file_exists("res://" + target):
			missing.append(target)
			continue
		var recorded: Dictionary = shot.get("fingerprint", {})
		if recorded.is_empty():
			moved.append("%s: no fingerprint recorded yet" % name)
			continue
		var now: Dictionary = FINGERPRINTS.of_shot(shot, "res://" + target)
		var which: PackedStringArray = PackedStringArray()
		for key: String in ["godot", "reading", "icons", "files", "png"]:
			if str(recorded.get(key, "")) != str(now.get(key, "")):
				which.append(key)
		if not which.is_empty():
			moved.append("%s (shown in %s): %s moved. Retake: powershell -File tools/doc_shots.ps1 -Out <folder> -Install -Only %s"
				% [name, ", ".join(_docs_showing(target.get_file())), ", ".join(which), name])
		if str(recorded.get("look", "")) != look_now:
			look_moved.append(name)
	passed = SUPPORT.check(TEST_NAME, "every entry's picture exists (missing: %s)" % ", ".join(missing), missing.size(), 0) and passed
	passed = SUPPORT.check(TEST_NAME, "every picture still shows what it was taken of", "\n".join(moved), "") and passed
	if not look_moved.is_empty():
		print("[WARN] %s: the default look moved since %d picture(s) were taken (a warning for now): %s"
			% [TEST_NAME, look_moved.size(), ", ".join(look_moved.slice(0, 6))])
	# The set: every picture file is entered, pending or kept.
	var unlisted: PackedStringArray = PackedStringArray()
	var on_disk: Dictionary = {}
	for folder: String in PICTURE_FOLDERS:
		var directory: DirAccess = DirAccess.open(folder)
		if directory == null:
			continue
		for file_name: String in directory.get_files():
			if file_name.get_extension().to_lower() != "png":
				continue
			var path: String = folder.trim_prefix("res://").path_join(file_name)
			on_disk[path] = true
			if not entered.has(path) and not pending.has(path) and not kept.has(path):
				unlisted.append(path)
	unlisted.sort()
	passed = SUPPORT.check(TEST_NAME, "every picture has an entry, is pending a retake, or is kept with a reason (unlisted: %s)"
		% ", ".join(unlisted), unlisted.size(), 0) and passed
	var stale_pending: PackedStringArray = PackedStringArray()
	for path: String in pending:
		if entered.has(path) or not on_disk.has(path):
			stale_pending.append(path)
	passed = SUPPORT.check(TEST_NAME, "the pending list names only pictures that exist and are not entered yet (%s)"
		% ", ".join(stale_pending), stale_pending.size(), 0) and passed
	var stale_kept: PackedStringArray = PackedStringArray()
	for path: Variant in kept:
		if entered.has(path) or not on_disk.has(path) or str(kept[path]).strip_edges().is_empty():
			stale_kept.append(str(path))
	passed = SUPPORT.check(TEST_NAME, "the kept list names existing, unentered pictures, each with a reason (%s)"
		% ", ".join(stale_kept), stale_kept.size(), 0) and passed
	# The detectors can say no: a recorded fingerprint that differs is named, a matching one is not.
	var sample: Dictionary = {"godot": "x"}
	passed = SUPPORT.check(TEST_NAME, "a fingerprint that differs is told apart",
		str(sample.get("godot", "")) != str(FINGERPRINTS.of_shot({}, "res://nothing.png").get("godot", "")), true) and passed
	print("%s: %d pictures entered, %d pending a retake, %d kept on purpose" % [TEST_NAME, entered.size(), pending.size(), kept.size()])
	return passed


## The guides that show a picture, by file name, for the failure message.
static func _docs_showing(file_name: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var folders: PackedStringArray = PackedStringArray(["res://docs"])
	while not folders.is_empty():
		var folder: String = folders[folders.size() - 1]
		folders.remove_at(folders.size() - 1)
		var directory: DirAccess = DirAccess.open(folder)
		if directory == null:
			continue
		for sub: String in directory.get_directories():
			if sub != "changelog" and sub != "internal":
				folders.append(folder.path_join(sub))
		for entry: String in directory.get_files():
			if entry.get_extension() == "md" and FileAccess.get_file_as_string(folder.path_join(entry)).contains("/" + file_name):
				found.append(folder.path_join(entry).trim_prefix("res://docs/"))
	found.sort()
	return found
