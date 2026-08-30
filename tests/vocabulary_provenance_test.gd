# EventSheet - provenance for derived vocabulary. A user must be able to tell
# whether a verb's name was AUTHORED or INFERRED, and see that they can disagree with it.
# Pins the classification by value, the tooltip note that carries it into the picker, and the
# rule that only derived verbs offer overrides (an authored verb's identity lives in its
# script, and the catalog never overrules source).
@tool
class_name VocabularyProvenanceTest
extends RefCounted

const TEMP_PATH: String = "user://temp_provenance_catalog.tres"


static func run() -> bool:
	var ok: bool = true
	EventSheetVocabularyCatalog.reset_for_tests(TEMP_PATH)

	# Authored vocabulary (a builtin or an annotated provider) carries no mark: it is the
	# baseline, and labelling 900+ curated verbs would be pure noise.
	var authored: ACEDefinition = ACEDefinition.new()
	authored.provider_id = "Core"
	authored.id = "PlaySound"
	authored.display_name = "Play Sound"
	authored.metadata = {"codegen_template": "x()"}
	ok = _check("authored vocabulary has no provenance mark",
		EventSheetVocabularyCatalog.provenance_of(authored), "") and ok
	ok = _check("authored vocabulary gets no tooltip note",
		EventSheetVocabularyCatalog.provenance_note(authored), "") and ok
	ok = _check("a null definition is handled",
		EventSheetVocabularyCatalog.provenance_of(null), "") and ok

	# A reflected verb nobody has touched reads as inferred.
	var reflected: ACEDefinition = ACEDefinition.new()
	reflected.provider_id = "Enemy"
	reflected.id = "method:take_damage"
	reflected.display_name = "Take Damage"
	reflected.metadata = {"codegen_template": "{target.}take_damage({amount})", "reflected": true}
	ok = _check("a reflected verb reads as inferred",
		EventSheetVocabularyCatalog.provenance_of(reflected), "inferred") and ok
	var note: String = EventSheetVocabularyCatalog.provenance_note(reflected)
	ok = _check("the note names the source class", note.contains("Enemy"), true) and ok
	ok = _check("the note says it is not curated", note.contains("not curated"), true) and ok
	ok = _check("the note advertises that it can be changed", note.contains("rename"), true) and ok

	# After an override, the same verb reads as curated - through the REAL apply path.
	EventSheetVocabularyCatalog.set_override("Enemy", "method:take_damage", {"display_name": "Wound"})
	var applied: Array[ACEDefinition] = EventSheetVocabularyCatalog.apply([reflected])
	ok = _check("the override renames through apply", applied[0].display_name, "Wound") and ok
	ok = _check("an overridden verb reads as curated",
		EventSheetVocabularyCatalog.provenance_of(applied[0]), "curated") and ok
	ok = _check("the curated note says who renamed it",
		EventSheetVocabularyCatalog.provenance_note(applied[0]).contains("renamed by you"), true) and ok
	# The shared source definition keeps its own provenance (no mutation).
	ok = _check("the source definition still reads as inferred",
		EventSheetVocabularyCatalog.provenance_of(reflected), "inferred") and ok

	# Resetting every field drops the entry, restoring the inferred identity - this is what
	# the picker's "Reset to the inferred name" action does.
	EventSheetVocabularyCatalog.set_override("Enemy", "method:take_damage",
		{"display_name": null, "category": null, "hidden": null})
	var reset: Array[ACEDefinition] = EventSheetVocabularyCatalog.apply([reflected])
	ok = _check("resetting restores the inferred name", reset[0].display_name, "Take Damage") and ok
	ok = _check("resetting restores the inferred provenance",
		EventSheetVocabularyCatalog.provenance_of(reset[0]), "inferred") and ok

	if ResourceLoader.exists(TEMP_PATH):
		DirAccess.remove_absolute(TEMP_PATH)
	EventSheetVocabularyCatalog.reset_for_tests()
	return ok


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		return true
	print("[FAIL] vocabulary_provenance_test: %s - expected %s, got %s" % [label, str(expected), str(actual)])
	return false
