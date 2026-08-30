# EventSheet - the Publish New Version ritual. Pins the bump core's VALUES (patch/minor/major
# resets, the missing-version and short-version reads, the note line's exact placement and
# sanitisation), the write path through the API, and the pickup that matters to a user: the
# republished source imports with the NEW addon_version, so the banner chip reads it.
@tool
class_name PublishVersionTest
extends RefCounted

const SOURCE: String = """## @ace_category(\"Waves\")
## @ace_version(1.2.3)
class_name TempWaves
extends Node


@export var strength: float = 1.0
"""


static func run() -> bool:
	var all_passed: bool = true

	var patch: Dictionary = EventSheetACEAnnotationWriter.bump_version(SOURCE, "patch", "fixed the wobble")
	all_passed = _check("patch bumps the last digit", str(patch.get("new_version")), "1.2.4") and all_passed
	all_passed = _check("old version is reported", str(patch.get("old_version")), "1.2.3") and all_passed
	all_passed = _check("the annotation is rewritten in place",
		str(patch.get("source")).contains("## @ace_version(1.2.4)"), true) and all_passed
	all_passed = _check("only ONE version annotation remains",
		str(patch.get("source")).count("@ace_version"), 1) and all_passed
	# The note sits DIRECTLY under the version line, as a plain doc comment.
	var lines: PackedStringArray = str(patch.get("source")).split("\n")
	var version_line: int = -1
	for i: int in range(lines.size()):
		if lines[i].contains("@ace_version"):
			version_line = i
			break
	all_passed = _check("the note line follows the version annotation",
		lines[version_line + 1], "## 1.2.4: fixed the wobble") and all_passed

	all_passed = _check("minor resets patch",
		str(EventSheetACEAnnotationWriter.bump_version(SOURCE, "minor", "x").get("new_version")), "1.3.0") and all_passed
	all_passed = _check("major resets both",
		str(EventSheetACEAnnotationWriter.bump_version(SOURCE, "major", "x").get("new_version")), "2.0.0") and all_passed

	# No version yet: reads as 1.0.0, bumps from there, and the identity block opens the file.
	var fresh: Dictionary = EventSheetACEAnnotationWriter.bump_version("extends Node\n", "patch", "first cut")
	all_passed = _check("missing version reads as 1.0.0 then bumps", str(fresh.get("new_version")), "1.0.1") and all_passed
	all_passed = _check("the new identity block opens the file",
		str(fresh.get("source")).begins_with("## @ace_version(1.0.1)\n## 1.0.1: first cut"), true) and all_passed
	# A short version pads instead of erroring; a multiline note flattens to one line.
	var short_version: Dictionary = EventSheetACEAnnotationWriter.bump_version(
		SOURCE.replace("1.2.3", "2.1"), "patch", "a\nb")
	all_passed = _check("a short version pads to semver", str(short_version.get("new_version")), "2.1.1") and all_passed
	all_passed = _check("a multiline note flattens", str(short_version.get("source")).contains("## 2.1.1: a b"), true) and all_passed

	# The API write path, against a temporary file (backup + rewrite + reporting).
	var temp_path: String = "user://publish_version_temp.gd"
	var out: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	out.store_string(SOURCE)
	out.close()
	var published: Dictionary = EventSheets.publish_pack_version(temp_path, "minor", "new wave shapes")
	all_passed = _check("the API publishes", bool(published.get("ok")), true) and all_passed
	var rewritten: String = FileAccess.get_file_as_string(temp_path)
	all_passed = _check("the file now declares the new version", rewritten.contains("## @ace_version(1.3.0)"), true) and all_passed
	all_passed = _check("the note is in the file", rewritten.contains("## 1.3.0: new wave shapes"), true) and all_passed
	all_passed = _check("a missing file fails closed",
		bool(EventSheets.publish_pack_version("user://nope.gd", "patch", "x").get("ok")), false) and all_passed

	# The pickup a user actually sees: importing the republished source reads the NEW version
	# (the banner's Addon Pack chip renders sheet.addon_version).
	var imported: EventSheetResource = GDScriptImporter.new().import_external_source(rewritten)
	all_passed = _check("the reimported sheet carries the new addon_version",
		imported.addon_version, "1.3.0") and all_passed
	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		return true
	print("[FAIL] publish_version_test: %s - expected %s, got %s" % [label, str(expected), str(actual)])
	return false
