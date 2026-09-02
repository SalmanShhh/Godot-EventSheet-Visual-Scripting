# EventForge - the rescue offers ("the tools find you") and the raw-error-note sweep.
#
# Pinned here:
#   1. The TIPS table: one entry per rescue moment, each with a feature, a stable moment key and
#      offer words - and the words translated in every shipped locale.
#   2. ONE offer per moment per session, the global "don't offer tips" switch honoured, and an
#      unknown moment answering nothing.
#   3. The stutter reading: one measured event self time at the threshold flips the last-window
#      worst, and reset() forgets it.
#   4. The Doctor's raw-error-note sweep: a note row carrying Godot's own error text is pointed
#      at; a note a person wrote is never accused.
@tool
class_name RescueTipsTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const TEMPLATE_PATH := "res://addons/eventsheet/translations/TEMPLATE.csv"
const TRANSLATIONS_DIR := "res://addons/eventsheet/translations"
const SHIPPED_LOCALES: PackedStringArray = ["de", "es", "fr", "it", "ja", "ko", "ru", "zh_CN"]


static func run() -> bool:
	var ok: bool = true
	ok = _test_table_and_translations() and ok
	ok = _test_once_per_session_and_switch() and ok
	ok = _test_stutter_reading() and ok
	ok = _test_raw_error_notes() and ok
	# Statics touched here are dropped so a serial run's later tests see cold state.
	EventSheetRescueTips.reset_session()
	EventSheetRescueTips.set_offers_enabled(true)
	EventSheetTraceTimings.reset()
	return ok


static func _test_table_and_translations() -> bool:
	var ok: bool = true
	ok = _check("the tips table is not empty", EventSheetRescueTips.TIPS.is_empty(), false) and ok
	var template_keys: Dictionary = _csv_keys(TEMPLATE_PATH)
	var catalogs: Dictionary = {}
	for locale: String in SHIPPED_LOCALES:
		catalogs[locale] = _csv_translations("%s/%s.csv" % [TRANSLATIONS_DIR, locale])
	for tip: Dictionary in EventSheetRescueTips.TIPS:
		var moment: String = str(tip.get("moment", ""))
		ok = _check("tip %s names its feature" % moment, str(tip.get("feature", "")).is_empty(), false) and ok
		ok = _check("tip %s has a moment key" % moment, moment.is_empty(), false) and ok
		var offer: String = str(tip.get("offer", ""))
		ok = _check("tip %s has offer words" % moment, offer.is_empty(), false) and ok
		ok = _check("TEMPLATE.csv carries the %s offer" % moment, template_keys.has(offer), true) and ok
		for locale: String in SHIPPED_LOCALES:
			ok = _check("%s.csv translates the %s offer" % [locale, moment],
				not str((catalogs[locale] as Dictionary).get(offer, "")).strip_edges().is_empty(), true) and ok
	return ok


static func _test_once_per_session_and_switch() -> bool:
	var ok: bool = true
	EventSheetRescueTips.reset_session()
	EventSheetRescueTips.set_offers_enabled(true)
	var first: String = EventSheetRescueTips.offer("first_slow_run")
	ok = _check("the first ask is answered", first.is_empty(), false) and ok
	ok = _check("the second ask of the same moment is silence",
		EventSheetRescueTips.offer("first_slow_run"), "") and ok
	ok = _check("a different moment still answers",
		EventSheetRescueTips.offer("first_never_fired_trigger").is_empty(), false) and ok
	EventSheetRescueTips.reset_session()
	ok = _check("a new session's ask is answered again",
		EventSheetRescueTips.offer("first_slow_run").is_empty(), false) and ok
	EventSheetRescueTips.reset_session()
	EventSheetRescueTips.set_offers_enabled(false)
	ok = _check("the switch silences everything",
		EventSheetRescueTips.offer("first_slow_run"), "") and ok
	ok = _check("…and reads back off", EventSheetRescueTips.offers_enabled(), false) and ok
	EventSheetRescueTips.set_offers_enabled(true)
	ok = _check("an unknown moment answers nothing",
		EventSheetRescueTips.offer("no_such_moment"), "") and ok
	return ok


static func _test_stutter_reading() -> bool:
	var ok: bool = true
	EventSheetTraceTimings.reset()
	# Two fires in one frame: the first is measured against the second's stamp - 20 ms of self
	# time, well over the stutter line.
	EventSheetTraceTimings.note_window(PackedStringArray(["slow_row", "next_row"]),
		PackedInt64Array([0, 20000]), PackedInt32Array(), 25000)
	ok = _check("a 20 ms row reads as the window's worst",
		EventSheetTraceTimings.last_window_worst_usec() >= EventSheetTraceTimings.STUTTER_USEC, true) and ok
	EventSheetTraceTimings.note_window(PackedStringArray(["quick_row", "next_row"]),
		PackedInt64Array([0, 500]), PackedInt32Array(), 600)
	ok = _check("a quiet window reads quiet again",
		EventSheetTraceTimings.last_window_worst_usec() < EventSheetTraceTimings.STUTTER_USEC, true) and ok
	EventSheetTraceTimings.reset()
	ok = _check("reset forgets the worst", EventSheetTraceTimings.last_window_worst_usec(), 0) and ok
	return ok


static func _test_raw_error_notes() -> bool:
	var ok: bool = true
	ok = _check("the engine's null-instance spelling is recognised",
		EventSheetRuntimeErrorWords.looks_like_engine_error(
			"Invalid call. Nonexistent function 'hit' in base 'null instance'."), true) and ok
	ok = _check("a pasted SCRIPT ERROR line is recognised",
		EventSheetRuntimeErrorWords.looks_like_engine_error(
			"SCRIPT ERROR: Parse Error: Expected end of statement"), true) and ok
	ok = _check("a note a person wrote is never accused",
		EventSheetRuntimeErrorWords.looks_like_engine_error(
			"Remember to balance the boss fight before the jam deadline."), false) and ok
	ok = _check("an empty note is never accused",
		EventSheetRuntimeErrorWords.looks_like_engine_error(""), false) and ok

	var sheet: EventSheetResource = EventSheetResource.new()
	var raw_note: CommentRow = CommentRow.new()
	raw_note.text = "Invalid call. Nonexistent function 'take_hit' in base 'null instance'."
	var clean_note: CommentRow = CommentRow.new()
	clean_note.text = "Spawns speed up every wave on purpose."
	sheet.events = [raw_note, clean_note]
	var findings: Array[Dictionary] = []
	EventSheetProjectDoctor._scan_raw_error_notes(sheet.events, "res://fake_sheet.tres", findings)
	ok = _check("the sweep finds exactly the raw note", findings.size(), 1) and ok
	if findings.size() == 1:
		ok = _check("…as the raw-error-note check", str(findings[0].get("check", "")), "raw-error-note") and ok
		ok = _check("…as a note, never an error", str(findings[0].get("severity", "")), "info") and ok
	return ok


static func _csv_keys(path: String) -> Dictionary:
	var keys: Dictionary = {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return keys
	file.get_csv_line()
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.size() >= 1 and not row[0].is_empty():
			keys[row[0]] = true
	return keys


static func _csv_translations(path: String) -> Dictionary:
	var catalog: Dictionary = {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return catalog
	file.get_csv_line()
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.size() >= 2 and not row[0].is_empty():
			catalog[row[0]] = row[1]
	return catalog


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("rescue_tips_test", label, actual, expected)
