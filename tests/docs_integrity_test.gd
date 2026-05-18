# EventSheet — docs artifact regression checks
@tool
extends RefCounted
class_name DocsIntegrityTest

const REQUIRED_DOCS := {
	"res://docs/EVENTSHEET_THEME_EDITABILITY.md": [
		"# EventSheet Theme + Editability Guide",
		"Switching themes",
		"Bundled example themes",
		"Custom theme import/install",
		"Hot-reload behavior",
		"CSS-like template path"
	],
	"res://docs/EVENTSHEET_THEME_TOKEN_SPEC.md": [
		"# EventSheet Theme Token Spec",
		"Construct 3 mapping",
		"Token groups",
		"Workflow mapping",
		"Current renderer notes"
	],
	"res://docs/EVENTSHEET_ALIGNMENT_GUIDE.md": [
		"# EventSheet Layout + Alignment Guide",
		"Layout model",
		"Key alignment settings",
		"Construct 3-like tuning recipe",
		"Theme token cross-reference"
	],
	"res://docs/EVENTSHEET_EDITOR_PROGRESS_REPORT.md": [
		"# EventSheet Editor Progress Report",
		"Completed in this branch",
		"Gaps / partial",
		"Next steps"
	],
	"res://docs/EVENTSHEET_C3_WORKFLOW_ALIGNMENT_STATUS.md": [
		"# C3 Workflow Alignment Status",
		"Aligned",
		"Partial",
		"Missing"
	],
	"res://docs/EVENTSHEET_AUTO_ACE_ALIGNMENT_STATUS.md": [
		"# Auto-ACE Alignment Status",
		"Implemented",
		"Partial",
		"Missing"
	],
	"res://docs/elements/EVENT_VISUAL_ELEMENT.md": [
		"# Event Visual Element",
		"What this element is",
		"Visual controls",
		"Usage",
		"Designer notes"
	],
	"res://docs/elements/CONDITION_VISUAL_ELEMENT.md": [
		"# Condition Visual Element",
		"What this element is",
		"Visual controls",
		"Usage",
		"Designer notes"
	],
	"res://docs/elements/ACTION_VISUAL_ELEMENT.md": [
		"# Action Visual Element",
		"What this element is",
		"Visual controls",
		"Usage",
		"Designer notes"
	],
	"res://docs/elements/THEME_LAYOUT_VISUAL_EDITOR.md": [
		"# Theme Layout Visual Editor",
		"What this element is",
		"Visual controls",
		"Usage",
		"Designer notes"
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
		"Construct-inspired EventSheet theme package template",
		"[package]",
		"theme_layout_scene",
		"[tokens]",
		"[designer_notes]"
	]
}

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
	return passed

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] docs_integrity_test: %s" % label)
		return true
	print("[FAIL] docs_integrity_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
