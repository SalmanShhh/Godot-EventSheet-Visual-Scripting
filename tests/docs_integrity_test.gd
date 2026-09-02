# EventSheet - docs artifact regression checks
@tool
class_name DocsIntegrityTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const REQUIRED_DOCS := {
	"res://docs/GUIDE-THEMING.md": [
		"# EventSheet Theme + Editability Guide",
		"Switching themes",
		"Bundled example themes",
		"Custom theme import/install",
		"Hot-reload behavior",
		"CSS-like template path"
	],
	"res://docs/internal/SPEC-layout-alignment.md": [
		"# EventSheet Layout + Alignment Guide",
		"Layout model",
		"Key alignment settings",
		"Stacked-layout tuning recipe",
		"Theme token cross-reference"
	],
	"res://AGENTS.md": [
		"# AGENTS.md",
		"Repo overview",
		"Architecture notes",
		"EventSheet editor structure",
		"Theme system notes",
		"Docs map",
		"Current known gaps",
		"Guidance for future LLM-assisted work"
	],
	"res://demo/themes/designer_template_theme_manifest.cfg": [
		"Stacked event-sheet theme package template",
		"[package]",
		"[tokens]",
		"[designer_notes]"
	],
	"res://docs/internal/SPEC-gdscript-pairing.md": [
		"# GDScript Pairing Spec",
		"Principles",
		"Implemented pairing features",
		"Planned",
		"Testing"
	],
}


## Where the documentation index lives, and the folder it must account for. Derived, not listed:
## the check reads the folder, so a guide added tomorrow is covered without touching this file.
const DOCS_DIR := "res://docs"
const DOCS_INDEX := "res://docs/README.md"


static func run() -> bool:
	var passed: bool = true
	for doc_path in REQUIRED_DOCS.keys():
		var exists: bool = FileAccess.file_exists(doc_path)
		passed = _check("doc exists: %s" % doc_path, exists, true) and passed
		if not exists:
			continue
		var content: String = FileAccess.get_file_as_string(doc_path)
		for needle in REQUIRED_DOCS[doc_path]:
			passed = _check("doc content marker (%s): %s" % [doc_path.get_file(), needle], content.contains(needle), true) and passed
	passed = _test_index_lists_every_guide() and passed
	passed = _test_every_image_is_shown() and passed
	return passed


## Every guide in docs/ is reachable from the index, with a sentence saying what it is.
##
## The index is the front door in the repo AND in the editor (the Manual's contents are built from
## it), so a guide missing from it is a guide nobody finds. This used to be a habit; a habit is
## exactly what a parallel batch of doc work breaks. Pinned by NAME so the failure says which file.
static func _test_index_lists_every_guide() -> bool:
	var passed: bool = true
	var index: String = FileAccess.get_file_as_string(DOCS_INDEX)
	passed = _check("the documentation index reads", index.is_empty(), false) and passed
	var missing: PackedStringArray = PackedStringArray()
	var undescribed: PackedStringArray = PackedStringArray()
	var swept: int = 0
	for file_name: String in DirAccess.get_files_at(DOCS_DIR):
		if not file_name.ends_with(".md") or file_name == "README.md":
			continue
		swept += 1
		var link: String = "(%s)" % file_name
		if not index.contains(link):
			missing.append(file_name)
			continue
		# A bare link is not an entry: the reader has to be told what the page is before
		# clicking it, so the line has to carry prose after the link as well.
		for line: String in index.split("\n"):
			if not line.contains(link):
				continue
			if line.substr(line.find(link) + link.length()).strip_edges().length() < 20:
				undescribed.append(file_name)
			break
	# Without this the whole check passes vacuously the day the folder cannot be read.
	passed = _check("the guide folder was actually swept", swept > 30, true) and passed
	passed = _check("every docs/*.md guide is listed in the index", ", ".join(missing), "") and passed
	passed = _check("every listed guide carries a one-line description", ", ".join(undescribed), "") and passed
	# The check can say no: a name that is not a guide must not be found in the index.
	passed = _check("the lookup can say no", index.contains("(GUIDE-NO-SUCH-PAGE.md)"), false) and passed
	return passed


## Every screenshot in docs/images/ must be SHOWN by a guide, and every image a guide shows must
## exist. A picture nobody looks at is worse than no picture: it goes stale silently, and the next
## reader of the folder cannot tell which of two similar shots is the current one - which is exactly
## how four generations of the same three figures piled up in there. Naming a file in prose (the
## CHANGELOG says which harness writes which PNG) is not showing it, so only a real embed counts.
static func _test_every_image_is_shown() -> bool:
	var passed: bool = true
	var shown: Dictionary = {}
	var missing: Array[String] = []
	for doc_path: String in _every_guide():
		var body: String = FileAccess.get_file_as_string(doc_path)
		for name: String in _images_embedded_in(body):
			shown[name] = true
			if not FileAccess.file_exists("res://docs/images/%s" % name) \
					and not FileAccess.file_exists("res://docs/previews/%s" % name):
				missing.append("%s -> %s" % [doc_path.get_file(), name])
	var orphans: Array[String] = []
	for name: String in _images_on_disk():
		if not shown.has(name):
			orphans.append(name)
	orphans.sort()
	missing.sort()
	passed = _check("every image in docs/images/ is shown by a guide (orphans: %s)"
		% ", ".join(orphans), orphans.size(), 0) and passed
	passed = _check("every image a guide shows exists on disk (broken: %s)"
		% ", ".join(missing), missing.size(), 0) and passed
	return passed


## Every guide the reader can open: the .md corpus under docs/ plus the README.
static func _every_guide() -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray(["res://README.md"])
	_collect_markdown("res://docs", found)
	return found


static func _collect_markdown(directory_path: String, into: PackedStringArray) -> void:
	var directory: DirAccess = DirAccess.open(directory_path)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry: String = directory.get_next()
	while not entry.is_empty():
		var full_path: String = directory_path.path_join(entry)
		if directory.current_is_dir():
			_collect_markdown(full_path, into)
		elif entry.get_extension().to_lower() == "md":
			into.append(full_path)
		entry = directory.get_next()
	directory.list_dir_end()


static func _images_on_disk() -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var directory: DirAccess = DirAccess.open("res://docs/images")
	if directory == null:
		return found
	for name: String in directory.get_files():
		if name.get_extension().to_lower() == "png":
			found.append(name)
	return found


## The image file names a page really EMBEDS: Markdown `![alt](path.png)` and the HTML
## `<img src="path.png">` the corpus uses when a figure needs a width. Both forms ship in the
## guides, so a check that knew only one would call half the corpus orphaned.
static func _images_embedded_in(body: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for marker: String in ["](", "src=\""]:
		var closer: String = ")" if marker == "](" else "\""
		var at: int = body.find(marker)
		while at >= 0:
			var start: int = at + marker.length()
			var end: int = body.find(closer, start)
			if end > start:
				var target: String = body.substr(start, end - start).strip_edges()
				if target.to_lower().ends_with(".png"):
					found.append(target.get_file())
			at = body.find(marker, at + marker.length())
	return found


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("docs_integrity_test", label, actual, expected)
