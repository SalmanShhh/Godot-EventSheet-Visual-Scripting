# EventForge - pack-local translations (the Construct lang.json idea): a pack ships
# eventsheet_addons/<pack>/translations.csv and its vocabulary localises everywhere it shows.
# Pins: the scanner discovers pack CSVs (the shipped health demo included), the fingerprint
# sees pack-file changes (hot-reload), translated display TEMPLATES substitute {slots} after
# translation (whole viewport sentences follow one key), English stays a pass-through, and a
# pack can never re-word the editor's own strings (editor catalogs merge first, packs add only).
@tool
class_name PackTranslationsTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true

	# ---- discovery: the shipped health demo is found and its messages land ----
	EventSheetL10n.rescan()
	var pack_files: PackedStringArray = EventSheetL10n._pack_translation_files()
	ok = _check(ok, pack_files.has("res://eventsheet_addons/health/translations.csv"), "the health pack CSV is discovered")
	var before_locale: String = EventSheetL10n.get_locale()
	EventSheetL10n.set_locale("fr")
	ok = _check(ok, EventSheetL10n.translate("Take Damage") == "Subir des Dégâts", "a pack display name translates (got %s)" % EventSheetL10n.translate("Take Damage"))
	ok = _check(ok, EventSheetL10n.translate("On Damaged") == "Sur Dégâts", "a pack trigger name translates")

	# ---- packs ADD, never re-word the editor: an editor key stays the editor's translation ----
	ok = _check(ok, EventSheetL10n.translate("Save") == "Enregistrer", "editor strings keep the editor catalog (got %s)" % EventSheetL10n.translate("Save"))

	# ---- translated templates: {slots} substitute AFTER translation ----
	var probe_csv: String = "user://pack_l10n_probe.csv"
	var file: FileAccess = FileAccess.open(probe_csv, FileAccess.WRITE)
	file.store_string("keys,fr\ntake {amount} damage,subir {amount} dégâts\n")
	file.close()
	EventSheetL10n.load_translation_file(probe_csv)
	EventSheetL10n.set_locale("fr")
	var viewport: EventSheetViewport = EventSheetViewport.new()
	var definition: ACEDefinition = ACEDefinition.new()
	definition.provider_id = "ProbePack"
	definition.id = "take_damage"
	definition.display_name = "Take Damage"
	definition.metadata = {"display_template": "take {amount} damage"}
	definition.parameters = [{"id": "amount", "default_value": "10"}]
	var sentence: String = viewport._row_builder._format_display_translated(definition, null, {"amount": "25"})
	ok = _check(ok, sentence == "subir 25 dégâts", "the sentence template translates then substitutes (got %s)" % sentence)

	# ---- English pass-through: byte-identical to the untranslated path ----
	EventSheetL10n.set_locale("en")
	var english: String = viewport._row_builder._format_display_translated(definition, null, {"amount": "25"})
	ok = _check(ok, english == definition.format_display({"amount": "25"}), "English is a pass-through (matches format_display)")

	# ---- the fingerprint watches pack files (hot-reload covers packs) ----
	var stamp_before: String = EventSheetL10n.scan_fingerprint()
	ok = _check(ok, stamp_before.contains("eventsheet_addons/health/translations.csv"), "the fingerprint covers pack CSVs")

	viewport.free()
	DirAccess.remove_absolute(probe_csv)
	EventSheetL10n.set_locale(before_locale)
	EventSheetL10n.rescan()  # drop the probe catalog entries
	return ok


static func _check(ok: bool, condition: bool, label: String) -> bool:
	if not condition:
		print("  [FAIL] ", label)
	return ok and condition
