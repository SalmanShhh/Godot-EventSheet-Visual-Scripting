# EventSheet - docs artifact regression checks
@tool
class_name DocsIntegrityTest
extends RefCounted

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


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] docs_integrity_test: %s" % label)
		return true
	print("[FAIL] docs_integrity_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
