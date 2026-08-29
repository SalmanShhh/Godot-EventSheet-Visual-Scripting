# EventSheets - the one action in this plugin that is allowed to want a network.
#
# WHAT IS PINNED HERE IS EVERYTHING EXCEPT THE CONNECTION. A suite that fetched a thousand files
# from a code host would need a network to be green, would be a different test on a train, and would
# hammer somebody else's server on every push. So the download itself is not run, and everything
# that decides what it would ask for and whether it may keep the answer is - which is where the bugs
# live anyway:
#
#   THE TAG      the running engine's version folds to the repository tag whose text is that build's
#                text, and a development build folds to nothing rather than to the nearest release.
#   THE URL      a harvested file's path inside the cache IS its path inside the repository, which
#                is why there is no list of classes to maintain anywhere.
#   THE RESUME   what still needs fetching is derived from the files themselves, so an interrupted
#                run continues and a finished one costs nothing.
#   THE GUARD    a body that is not this class's reference text is refused rather than written, so a
#                404 page or a redirect can never end up in the cache wearing a class's file name.
@tool
class_name DocEngineFetchTest
extends RefCounted

const FIXTURE_ROOT := "user://doc_engine_fetch_test"

## The two states a class file is in: written by `--doctool` on the reader's machine (structure, no
## words) and published by the engine's repository (the same structure with the words in it).
const SKELETON := """<?xml version="1.0" encoding="UTF-8" ?>
<class name="Node2D" inherits="CanvasItem">
	<brief_description>
	</brief_description>
	<members>
		<member name="position" type="Vector2" setter="set_position" getter="get_position">
		</member>
	</members>
</class>
"""

const WITH_TEXT := """<?xml version="1.0" encoding="UTF-8" ?>
<class name="Node2D" inherits="CanvasItem">
	<brief_description>
		A 2D game object.
	</brief_description>
	<members>
		<member name="position" type="Vector2" setter="set_position" getter="get_position">
			Position, relative to the node's parent.
		</member>
	</members>
</class>
"""


static func run() -> bool:
	_clean_up()
	var all_passed: bool = true
	all_passed = _test_the_tag() and all_passed
	all_passed = _test_the_url() and all_passed
	all_passed = _test_what_is_still_missing() and all_passed
	all_passed = _test_what_may_be_kept() and all_passed
	_clean_up()
	return all_passed


## The tag. Two builds must never share one, and a build with no published reference of its own must
## resolve to no tag at all rather than to somebody else's sentences.
static func _test_the_tag() -> bool:
	var all_passed: bool = true
	all_passed = _check("a zero patch is left off, the way the engine tags it",
		EventSheetDocEngineFetch.tag_for({"major": 4, "minor": 7, "patch": 0, "status": "stable"}),
		"4.7-stable") and all_passed
	all_passed = _check("a patch release names itself",
		EventSheetDocEngineFetch.tag_for({"major": 4, "minor": 7, "patch": 2, "status": "stable"}),
		"4.7.2-stable") and all_passed
	# THE REFUSAL IS THE POINT: a beta has no published reference that is knowably its own, and
	# quietly fetching 4.7's would put one build's sentences on another build's classes.
	all_passed = _check("a development build fetches nothing rather than the nearest release",
		EventSheetDocEngineFetch.tag_for({"major": 4, "minor": 8, "patch": 0, "status": "beta3"}),
		"") and all_passed
	all_passed = _check("and neither does a version that names no engine",
		EventSheetDocEngineFetch.tag_for({"status": "stable"}), "") and all_passed
	all_passed = _check("the receipt carries the frozen header",
		EventSheetDocEngineFetch.receipt_text("4.7-stable", 3).begins_with(
			EventSheetDocEngineFetch.RECEIPT_HEADER), true) and all_passed
	return all_passed


## The URL, which is the reason this feature needs no list of classes: `--doctool` writes each
## class into the repository's OWN relative path, so the harvest is the manifest.
static func _test_the_url() -> bool:
	var all_passed: bool = true
	all_passed = _check("a core class comes from the tag's own doc folder",
		EventSheetDocEngineFetch.url_for("4.7-stable", "doc/classes/Node2D.xml"),
		"https://raw.githubusercontent.com/godotengine/godot/4.7-stable/doc/classes/Node2D.xml") and all_passed
	# The classes a built-in module owns live under that module, and the harvest already knows which
	# folder each one landed in - which is the whole reason the path is reused rather than rebuilt.
	all_passed = _check("a module's class comes from that module's own doc folder",
		EventSheetDocEngineFetch.url_for("4.7-stable", "modules/gdscript/doc_classes/GDScript.xml"),
		"https://raw.githubusercontent.com/godotengine/godot/4.7-stable/modules/gdscript/doc_classes/GDScript.xml") and all_passed
	all_passed = _check("no tag means no URL to ask for",
		EventSheetDocEngineFetch.url_for("", "doc/classes/Node2D.xml"), "") and all_passed
	return all_passed


## The resume rule, which is a question about the FILES and not about a progress file that could go
## stale: a class file with no text in it has not been fetched.
static func _test_what_is_still_missing() -> bool:
	var all_passed: bool = true
	all_passed = _check("a file the harvest wrote has no text in it",
		EventSheetDocEngineFetch.xml_has_text(SKELETON), false) and all_passed
	all_passed = _check("a file from the repository does",
		EventSheetDocEngineFetch.xml_has_text(WITH_TEXT), true) and all_passed

	DirAccess.make_dir_recursive_absolute("%s/doc/classes" % FIXTURE_ROOT)
	DirAccess.make_dir_recursive_absolute("%s/modules/gdscript/doc_classes" % FIXTURE_ROOT)
	_write("%s/doc/classes/Node2D.xml" % FIXTURE_ROOT, SKELETON)
	_write("%s/doc/classes/Sprite2D.xml" % FIXTURE_ROOT, WITH_TEXT.replace("Node2D", "Sprite2D"))
	_write("%s/modules/gdscript/doc_classes/GDScript.xml" % FIXTURE_ROOT,
		SKELETON.replace("Node2D", "GDScript"))
	_write("%s/doc/classes/notes.txt" % FIXTURE_ROOT, "not a class")
	all_passed = _check("every class file is found, in every folder, sorted and XML only",
		", ".join(EventSheetDocEngineFetch.relative_paths(FIXTURE_ROOT)),
		"doc/classes/Node2D.xml, doc/classes/Sprite2D.xml, modules/gdscript/doc_classes/GDScript.xml") and all_passed
	# The one that already carries its text is not asked for again - which is what makes a second run
	# after an interrupted one cost nothing.
	all_passed = _check("only the files with no text in them are still to fetch",
		", ".join(EventSheetDocEngineFetch.pending(FIXTURE_ROOT)),
		"doc/classes/Node2D.xml, modules/gdscript/doc_classes/GDScript.xml") and all_passed
	all_passed = _check("a folder with no harvest in it needs nothing fetched",
		EventSheetDocEngineFetch.pending("%s/nowhere" % FIXTURE_ROOT).size(), 0) and all_passed
	return all_passed


## The guard on what may be written. A cache half full of error pages is worse than one that is
## merely empty: it would be indistinguishable from harvested text to every reader after it.
static func _test_what_may_be_kept() -> bool:
	var all_passed: bool = true
	all_passed = _check("this class's own reference text is kept",
		EventSheetDocEngineFetch.body_is_usable("doc/classes/Node2D.xml", WITH_TEXT), true) and all_passed
	all_passed = _check("a body for another class is refused",
		EventSheetDocEngineFetch.body_is_usable("doc/classes/Sprite2D.xml", WITH_TEXT), false) and all_passed
	all_passed = _check("a page that is not a class reference is refused",
		EventSheetDocEngineFetch.body_is_usable("doc/classes/Node2D.xml",
			"<html><body>404: Not Found</body></html>"), false) and all_passed
	all_passed = _check("and so is an answer with nothing in it",
		EventSheetDocEngineFetch.body_is_usable("doc/classes/Node2D.xml", "   "), false) and all_passed
	# A file with the right name and the right shape and no words in it is exactly what the reader
	# already has, so keeping it would turn a finished fetch into a fetch that changed nothing.
	all_passed = _check("a body with no text in it is not worth keeping",
		EventSheetDocEngineFetch.body_is_usable("doc/classes/Node2D.xml", SKELETON), false) and all_passed
	return all_passed


static func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(text)


## The fixture tree, removed on the way in as well as out: CI runs the whole suite in one process,
## and a test that left files under user:// would be handing whatever runs next a folder it did not
## make.
static func _clean_up() -> void:
	_remove_tree(FIXTURE_ROOT)


static func _remove_tree(directory: String) -> void:
	if not DirAccess.dir_exists_absolute(directory):
		return
	for name: String in DirAccess.get_directories_at(directory):
		_remove_tree(directory.path_join(name))
	for name: String in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(name))
	DirAccess.remove_absolute(directory)


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] doc_engine_fetch_test: %s" % label)
		return true
	print("[FAIL] doc_engine_fetch_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
