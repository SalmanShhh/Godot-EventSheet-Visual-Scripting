# EventForge - editor-UI localisation (EventSheetL10n + the EventSheets l10n API)
#
# Guards the plugin-translation contract:
#   1. English is the default AND the fallback - with no translation active, every string
#      passes through unchanged.
#   2. A drop-in CSV contributes its locales; switching to one translates known strings and
#      passes unknown ones through in the original English.
#   3. The public API surface (EventSheets.translate / register_translation_file /
#      available_languages / set_editor_language) round-trips the same behavior.
#   4. Empty translation cells never create ghost languages, and "en" columns are ignored
#      (English IS the key).
# Headless-safe: language persistence is editor-only, and the test restores English + rescans
# so the static catalogs never leak into other tests.
@tool
class_name EditorL10nTest
extends RefCounted

const TEST_CSV := "user://eventforge_l10n_test.csv"


static func run() -> bool:
	var all_passed: bool = true

	# 1. English default: pass-through, and "en" is always offered.
	EventSheetL10n.rescan()
	EventSheetL10n.set_locale("en")
	all_passed = _check("default locale is English", EventSheetL10n.get_locale(), "en") and all_passed
	all_passed = _check("English passes strings through", EventSheetL10n.translate("Save"), "Save") and all_passed
	all_passed = _check("English is always offered", Array(EventSheetL10n.available_locales()).has("en"), true) and all_passed
	all_passed = _check("English display name says default", EventSheetL10n.locale_display_name("en").contains("default"), true) and all_passed

	# 2. Drop-in CSV: locales appear, translations apply, unknown strings fall back.
	var file: FileAccess = FileAccess.open(TEST_CSV, FileAccess.WRITE)
	file.store_csv_line(PackedStringArray(["keys", "fr", "es", "en"]))
	file.store_csv_line(PackedStringArray(["Save", "Enregistrer", "Guardar", "IGNORED"]))
	file.store_csv_line(PackedStringArray(["Add Event", "Ajouter un événement", "", ""]))
	file.close()
	all_passed = _check("CSV loads and contributes", EventSheetL10n.load_translation_file(TEST_CSV), true) and all_passed
	var locales: Array = Array(EventSheetL10n.available_locales())
	all_passed = _check("fr discovered from the CSV", locales.has("fr"), true) and all_passed
	all_passed = _check("es discovered from the CSV", locales.has("es"), true) and all_passed
	all_passed = _check("an en column never becomes a language", locales.count("en"), 1) and all_passed
	EventSheetL10n.set_locale("fr")
	all_passed = _check("French translates a known string", EventSheetL10n.translate("Save"), "Enregistrer") and all_passed
	all_passed = _check("French falls back on unknown strings", EventSheetL10n.translate("Never Translated"), "Never Translated") and all_passed
	EventSheetL10n.set_locale("es")
	all_passed = _check("Spanish translates its column", EventSheetL10n.translate("Save"), "Guardar") and all_passed
	all_passed = _check("an empty cell falls back to English", EventSheetL10n.translate("Add Event"), "Add Event") and all_passed
	EventSheetL10n.set_locale("xx_not_loaded")
	all_passed = _check("an unknown locale snaps back to English", EventSheetL10n.get_locale(), "en") and all_passed

	# 3. The public API round-trips the same behavior.
	all_passed = _check("API registers a translation file", EventSheets.register_translation_file(TEST_CSV), true) and all_passed
	EventSheets.set_editor_language("fr")
	all_passed = _check("API translate honors the language", EventSheets.translate("Save"), "Enregistrer") and all_passed
	all_passed = _check("API lists the languages", Array(EventSheets.available_languages()).has("fr"), true) and all_passed
	EventSheets.set_editor_language("en")
	all_passed = _check("API restores the English default", EventSheets.translate("Save"), "Save") and all_passed

	# 4. Cleanup: the catalogs are static session state - restore pristine English for the rest
	# of the suite (rescan drops the user:// test file's messages; only scan-dir files reload).
	DirAccess.remove_absolute(TEST_CSV)
	EventSheetL10n.set_locale("en")
	EventSheetL10n.rescan()
	all_passed = _check("cleanup restored pass-through", EventSheetL10n.translate("Save"), "Save") and all_passed

	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] editor_l10n_test: %s" % label)
		return true
	print("[FAIL] editor_l10n_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
