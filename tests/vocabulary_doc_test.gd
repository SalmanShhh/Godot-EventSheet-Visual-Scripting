# Godot EventSheets - project vocabulary doc: one committed markdown reference of
# everything the project's sheets and packs publish, deterministic by contract, kept
# honest by the Project Doctor's opt-in staleness note.
@tool
class_name VocabularyDocTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true

	# Script-pack parsing: @ace_* annotated members land in the shared surface shape.
	var source: String = FileAccess.get_file_as_string("res://eventsheet_addons/demo_health_addon.gd")
	var surface: Dictionary = EventSheetVocabularyDoc.script_pack_surface(source)
	var action_names: PackedStringArray = PackedStringArray()
	for entry: Dictionary in (surface.get("actions", []) as Array):
		action_names.append(str(entry.get("name")))
	all_passed = _check("annotated actions parse with display names",
		action_names.has("Heal") and action_names.has("Announce Heal"), true) and all_passed
	all_passed = _check("annotated signal parses as a trigger",
		str((surface.get("triggers", []) as Array)[0].get("name")), "On Healed") and all_passed
	all_passed = _check("conditions carry params and category",
		str((surface.get("conditions", []) as Array)[0].get("params")) == "threshold: int"
		and str((surface.get("conditions", []) as Array)[0].get("category")) == "Health", true) and all_passed
	var announce: Dictionary = {}
	for entry: Dictionary in (surface.get("actions", []) as Array):
		if str(entry.get("name")) == "Announce Heal":
			announce = entry
	all_passed = _check("multi-line descriptions flatten to one line",
		str(announce.get("description")).contains("instance-backed ACE")
		and not str(announce.get("description")).contains("\n"), true) and all_passed

	# Sheet sections: identity line + the publish surface, nested one heading deeper.
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.custom_class_name = "VocabFixture"
	sheet.behavior_mode = true
	sheet.host_class = "CharacterBody2D"
	sheet.variables = {"speed": {"type": "float", "default": 200.0, "exported": true}}
	var exposed: EventFunction = EventFunction.new()
	exposed.function_name = "boost"
	exposed.expose_as_ace = true
	exposed.ace_display_name = "Boost"
	exposed.return_type = TYPE_NIL
	sheet.functions.append(exposed)
	var section: String = "\n".join(EventSheetVocabularyDoc.sheet_section(sheet, "res://game/vocab_fixture.tres"))
	all_passed = _check("sheet section renders identity + surface",
		section.contains("### VocabFixture (`res://game/vocab_fixture.tres`)")
		and section.contains("Behavior - attach under any `CharacterBody2D` node.")
		and section.contains("#### Properties") and section.contains("- `speed: float` (default `200.0`)")
		and section.contains("#### Actions") and section.contains("- **Boost**"), true) and all_passed

	# The full document: sheets sorted, packs covered, generated scripts not duplicated.
	var document: String = EventSheetVocabularyDoc.generate()
	all_passed = _check("document covers pack sheets and the demo sheet",
		document.contains("### SpringBehavior (`res://eventsheet_addons/spring/spring_behavior.gd`)")
		and document.contains("res://demo/sheets/player.tres"), true) and all_passed
	all_passed = _check("hand-written script packs get their own section",
		document.contains("### DemoHealthAddon (`res://eventsheet_addons/demo_health_addon.gd`)"), true) and all_passed
	all_passed = _check("a pack .gd is listed once as a script pack (the .gd IS the sheet now)",
		document.contains("`res://eventsheet_addons/spring/spring_behavior.gd`"), true) and all_passed
	all_passed = _check("the document is deterministic",
		EventSheetVocabularyDoc.generate(), document) and all_passed

	# Doctor staleness note: opt-in (no doc, no note), clean right after writing,
	# noted once the project's surface and the doc disagree.
	ProjectSettings.set_setting("eventsheets/project/vocabulary_doc_path", "user://vocab_doc_test.md")
	if FileAccess.file_exists("user://vocab_doc_test.md"):
		DirAccess.remove_absolute("user://vocab_doc_test.md")
	var findings: Array[Dictionary] = []
	EventSheetProjectDoctor.check_vocabulary_doc(findings)
	all_passed = _check("no doc means no staleness note", findings.is_empty(), true) and all_passed
	all_passed = _check("write returns the configured path",
		EventSheetVocabularyDoc.write(), "user://vocab_doc_test.md") and all_passed
	findings = []
	EventSheetProjectDoctor.check_vocabulary_doc(findings)
	all_passed = _check("freshly written doc is clean", findings.is_empty(), true) and all_passed
	var tamper: FileAccess = FileAccess.open("user://vocab_doc_test.md", FileAccess.READ_WRITE)
	tamper.seek_end()
	tamper.store_string("\nstale tail\n")
	tamper.close()
	findings = []
	EventSheetProjectDoctor.check_vocabulary_doc(findings)
	all_passed = _check("edited doc gets the staleness note",
		findings.size() == 1 and str(findings[0].get("check")) == "vocabulary-doc", true) and all_passed
	ProjectSettings.set_setting("eventsheets/project/vocabulary_doc_path", null)
	DirAccess.remove_absolute("user://vocab_doc_test.md")

	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] vocabulary_doc_test: %s" % label)
		return true
	print("[FAIL] vocabulary_doc_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
