# Godot EventSheets - the one thing the plugin remembers about a project, and the band that reads it.
#
# The record is a single line of `project.godot` saying which vocabulary this project's sheets were
# last edited under. What it must never be is a line of anybody's `.gd`, so the first thing pinned
# here is the negative: nothing about a sheet's own bytes changes because of it, and a headless run -
# a test, a CI compile, an exported game - writes nothing at all.
#
# The band is derived from the ROWS. The record only upgrades "these rows have a newer spelling" to
# "these rows have a newer spelling, since 0.14", which is why a project that has never carried the
# record still gets a band and why a project that is up to date gets none.
@tool
class_name VocabularyRecordTest
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")


static func run() -> bool:
	var ok: bool = true
	ok = _test_the_record() and ok
	ok = _test_the_band_reading() and ok
	ok = _test_the_band_seam() and ok
	return ok


static func _test_the_record() -> bool:
	var ok: bool = _check("the record is one registered project entry",
		_setting_is_registered(EventForgeVocabularyRecord.SETTING), true)
	ok = _check("and it lives under the project's own settings, not in any file of the sheet",
		EventForgeVocabularyRecord.SETTING, "eventsheets/project/vocabulary_version") and ok
	ok = _check("the version it records is the compiler's own",
		EventForgeVocabularyRecord.current(), SheetCompiler.VERSION) and ok
	# THE LAW, pinned: a headless run has not edited anything, so it writes nothing. Every test in
	# this suite compiles sheets, and none of them may leave a project.godot behind.
	ok = _check("a run with no editor writes no record", EventForgeVocabularyRecord.stamp(), false) and ok
	ok = _check("the band facts carry the counts and the recorded version",
		EventForgeVocabularyRecord.band_facts(3),
		{"count": 3, "asking": 0, "since": EventForgeVocabularyRecord.recorded()}) and ok
	ok = _check("including how many rows hold a verb the vocabulary no longer has at all",
		EventForgeVocabularyRecord.band_facts(3, 2),
		{"count": 3, "asking": 2, "since": EventForgeVocabularyRecord.recorded()}) and ok
	ok = _check("and a negative count is no count", EventForgeVocabularyRecord.band_facts(-2, -1),
		{"count": 0, "asking": 0, "since": EventForgeVocabularyRecord.recorded()}) and ok
	return ok


static func _test_the_band_reading() -> bool:
	var ok: bool = _check("nothing to migrate reads as nothing at all",
		EventForgeVocabularyRecord.band_reading({"count": 0, "since": "0.14.0"}), "")
	ok = _check("a project with no record still gets the count",
		EventForgeVocabularyRecord.band_reading({"count": 3, "since": ""}),
		"3 rows have a newer spelling") and ok
	ok = _check("one row says so in the singular",
		EventForgeVocabularyRecord.band_reading({"count": 1, "since": ""}),
		"1 row has a newer spelling") and ok
	ok = _check("and the record upgrades it to a version",
		EventForgeVocabularyRecord.band_reading({"count": 3, "since": "0.14.0"}),
		"3 rows have a newer spelling, since 0.14.0") and ok
	ok = _check("in the singular too",
		EventForgeVocabularyRecord.band_reading({"count": 1, "since": "0.14.0"}),
		"1 row has a newer spelling, since 0.14.0") and ok
	# One counting line, and only one. The sentences and the doors belong elsewhere.
	ok = _check("the band is one line",
		EventForgeVocabularyRecord.band_reading({"count": 9, "since": "0.14.0"}).contains("\n"), false) and ok
	# A row holding a verb the vocabulary no longer has is the only half anybody must act on, so it
	# leads - and the version goes unsaid, because "how old are these words" is not the question
	# somebody with a gone verb is asking.
	ok = _check("a question leads, and the reassurance follows it",
		EventForgeVocabularyRecord.band_reading({"count": 12, "asking": 2, "since": "0.14.0"}),
		"2 rows ask you - 12 migrate cleanly") and ok
	ok = _check("in the singular on both halves",
		EventForgeVocabularyRecord.band_reading({"count": 1, "asking": 1, "since": ""}),
		"1 row asks you - 1 migrates cleanly") and ok
	ok = _check("and nothing to migrate cleanly leaves the question standing alone",
		EventForgeVocabularyRecord.band_reading({"count": 0, "asking": 2, "since": "0.14.0"}),
		"2 rows ask you") and ok
	ok = _check("the two-count band is still one line",
		EventForgeVocabularyRecord.band_reading({"count": 12, "asking": 2, "since": ""}).contains("\n"),
		false) and ok
	return ok


static func _test_the_band_seam() -> bool:
	var facts: Dictionary = EventSheetHeadBands.facts(EventSheetResource.new(), "extends Node")
	var ok: bool = _check("every sheet's facts can be asked the question",
		facts.has("migration"), true)
	ok = _check("and a sheet with nothing to migrate grows no band",
		_band_kinds(EventSheetHeadBands.bands(facts)).has(EventSheetHeadBands.BAND_MIGRATION), false) and ok
	facts["migration"] = {"count": 2, "since": "0.14.0"}
	var bands: Array[Dictionary] = EventSheetHeadBands.bands(facts)
	ok = _check("a count grows exactly one band",
		_band_kinds(bands).count(EventSheetHeadBands.BAND_MIGRATION), 1) and ok
	var band: Dictionary = _band_of(bands, EventSheetHeadBands.BAND_MIGRATION)
	ok = _check("whose words are the counting line",
		str(band.get("value", "")), "2 rows have a newer spelling, since 0.14.0") and ok
	# No echo: nothing in the file says this, and a band never invents a line the file does not have.
	ok = _check("and which echoes no line of the file", str(band.get("echo", "")), "") and ok
	ok = _check("it reads after the sheet's own lines",
		Array(EventSheetHeadBands.ORDER).find(EventSheetHeadBands.BAND_MIGRATION) \
			> Array(EventSheetHeadBands.ORDER).find(EventSheetHeadBands.BAND_INCLUDE), true) and ok
	# And still exactly one band when the sheet also holds rows whose verb is gone: two counts, one
	# line, one band. A second band for the second count would be two things to read at the head.
	facts["migration"] = {"count": 12, "asking": 2, "since": "0.14.0"}
	var asking_bands: Array[Dictionary] = EventSheetHeadBands.bands(facts)
	ok = _check("two counts still grow exactly one band",
		_band_kinds(asking_bands).count(EventSheetHeadBands.BAND_MIGRATION), 1) and ok
	ok = _check("whose words put the question first",
		str(_band_of(asking_bands, EventSheetHeadBands.BAND_MIGRATION).get("value", "")),
		"2 rows ask you - 12 migrate cleanly") and ok
	return ok


static func _band_kinds(bands: Array[Dictionary]) -> PackedStringArray:
	var kinds: PackedStringArray = PackedStringArray()
	for band: Dictionary in bands:
		kinds.append(str(band.get("kind", "")))
	return kinds


static func _band_of(bands: Array[Dictionary], kind: String) -> Dictionary:
	for band: Dictionary in bands:
		if str(band.get("kind", "")) == kind:
			return band
	return {}


static func _setting_is_registered(name: String) -> bool:
	for definition: Dictionary in EventSheetSettings.DEFINITIONS:
		if str(definition.get("name", "")) == name:
			return true
	return false


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("vocabulary_record_test", label, actual, expected)
