# Godot EventSheets - the GAME's languages, seen from the editor.
#
# Two jobs, both about the words the PLAYER reads (never the plugin's own UI):
#
#   1. PREVIEW IN LANGUAGE. Pick a locale and every globe-marked value in the open sheet renders in
#      it, so a row reads Set Text "Jouer" while you author it instead of the literal tr("Play").
#      Purely a display rule: nothing is written, the sheet is untouched, and clearing the preview
#      restores the rows exactly - the transform is the identity when no preview locale is set, so
#      the day this is off it costs nothing and changes nothing.
#   2. PSEUDO. A throwaway locale that finds three bugs before a translator is paid: labels that
#      clip (the expansion), text that was never marked (it stays plain ASCII on a page of accents),
#      and sentences built by concatenation (the brackets show the seams mid-sentence).
#
# THIS IS NOT THE EDITOR'S OWN LANGUAGE. View > Language switches the PLUGIN's interface through
# EventSheetL10n and its "eventsheets" TranslationDomain; reusing that domain here would let a
# French editor start rewriting the user's rows. These catalogs are the user's game files, kept
# entirely separate, and this class never touches the plugin domain.
#
# THE PSEUDOLOCALIZER IS GODOT'S. TranslationServer.pseudolocalize() is the engine's own, the very
# transform `use_pseudolocalization` ships, so the preview matches the build. Its skip_placeholders
# option only protects printf-style %s/%d - "{count} of {total}" really does come back as
# "{ćôüήŧ} ôf́ {ŧôŧáł}", which would break the format call it feeds - so the {slot} tokens the pattern
# verbs use are protected here instead, by borrowing the one escape the engine already honours.
@tool
class_name EventSheetGameCatalog
extends RefCounted

## The pseudo locale. Godot's CSV importer standardizes a header into a locale and drops a subtag it
## does not recognise, so "qps_ploc" lands as "qps" - which is what the column must be called for
## the imported .translation to answer to it.
const PSEUDO_LOCALE := "qps"
## How much longer pseudo text is than its source. 0.4 is the usual worst case for German, and the
## reason the preview finds clipped labels at all.
const DEFAULT_EXPANSION := 0.4
## Godot's own project settings this reads and writes - the exact ones Project Settings edits.
const TRANSLATIONS_SETTING := "internationalization/locale/translations"
const TEST_LOCALE_SETTING := "internationalization/locale/test"
const REMAPS_SETTING := "internationalization/locale/translation_remaps"
const PSEUDO_EXPANSION_SETTING := "internationalization/pseudolocalization/expansion_ratio"

## The locale the sheet currently renders in. Empty = off, and off is the identity.
static var _preview_locale: String = ""
## key -> translated text for the active preview locale (never the plugin's catalogs).
static var _preview_messages: Dictionary = {}
## The catalog file the preview was built from, so the window can say what it is showing.
static var _preview_source: String = ""
## "expansion|source text" -> pseudo text. See pseudolocalize().
static var _pseudo_cache: Dictionary = {}
## How many pseudo strings are remembered before the cache is dropped whole. A sheet has far fewer
## distinct marked strings than this; the cap is only there so a day-long session cannot grow it.
const PSEUDO_CACHE_LIMIT := 4096

# ── Preview state ────────────────────────────────────────────────────────────


## Turns the preview on for `locale`, using `messages` (key -> text) as its catalog. Pass the pseudo
## locale with no messages to preview generated pseudo text.
static func set_preview(locale: String, messages: Dictionary = {}, source: String = "") -> void:
	_preview_locale = locale.strip_edges()
	_preview_messages = messages.duplicate()
	_preview_source = source
	_pseudo_cache.clear()


## Turns the preview off. Every row goes back to reading exactly as it did - this is what makes the
## whole feature safe: it is a lens, not an edit.
static func clear_preview() -> void:
	_preview_locale = ""
	_preview_messages = {}
	_preview_source = ""
	_pseudo_cache.clear()


static func preview_locale() -> String:
	return _preview_locale


static func preview_source() -> String:
	return _preview_source


static func is_previewing() -> bool:
	return not _preview_locale.is_empty()


## One source string as the preview shows it. The identity when no preview is active, the pseudo
## transform under the pseudo locale, and the catalog's translation otherwise - falling back to the
## source string exactly as tr() does when a key is missing, so an untranslated row reads as the
## English it will really ship as rather than as an error.
static func preview(text: String) -> String:
	if _preview_locale.is_empty() or text.is_empty():
		return text
	if _preview_locale == PSEUDO_LOCALE:
		return pseudolocalize(text)
	var translated: String = str(_preview_messages.get(text, ""))
	return translated if not translated.is_empty() else text


## A stored ACE param value as the row should READ. Only a globe-marked value (the canonical
## tr("…") form the params dialog writes) is a translation; everything else is the author's own
## GDScript and passes through untouched, preview or no preview. The marked value comes back
## QUOTED, because that is what the row already shows around the words.
static func preview_param(value: Variant) -> String:
	var text: String = str(value)
	if _preview_locale.is_empty():
		return text
	var parts: Dictionary = ACEParamsDialog.translatable_parts(text)
	if not bool(parts.get("translatable", false)):
		return text
	return "\"%s\"" % preview(str(parts.get("text", "")))

# ── Pseudolocalization (the engine's own) ────────────────────────────────────


## Godot's pseudolocalizer, with the {slot} tokens protected. `expansion` overrides the project's
## expansion ratio for this call only and is put back afterwards, so previewing never leaves the
## project's own pseudolocalization settings changed.
##
## MEMOISED, because this is called once per PARAM per row while a sheet renders and the override is
## not free: setting the ratio means writing a ProjectSetting and calling reload_pseudolocalization,
## which broadcasts NOTIFICATION_TRANSLATION_CHANGED to every node in the editor's tree. Two of those
## per parameter on a sheet of a few hundred rows is thousands of tree-wide broadcasts per rebuild.
## The answer is a pure function of (text, expansion), so it is cached and the whole dance runs once
## per distinct string. The cache is dropped whenever the preview changes, and capped so a long
## session cannot grow it without bound.
static func pseudolocalize(text: String, expansion: float = DEFAULT_EXPANSION) -> String:
	if text.is_empty():
		return text
	var cache_key: String = "%s|%s" % [expansion, text]
	if _pseudo_cache.has(cache_key):
		return str(_pseudo_cache[cache_key])
	var masked: Dictionary = _mask_slots(text)
	var previous_expansion: Variant = ProjectSettings.get_setting(PSEUDO_EXPANSION_SETTING, 0.0)
	var override: bool = expansion >= 0.0 and not is_equal_approx(float(previous_expansion), expansion)
	if override:
		ProjectSettings.set_setting(PSEUDO_EXPANSION_SETTING, expansion)
		TranslationServer.reload_pseudolocalization()
	var pseudo: String = TranslationServer.pseudolocalize(str(masked.get("text", text)))
	if override:
		ProjectSettings.set_setting(PSEUDO_EXPANSION_SETTING, previous_expansion)
		TranslationServer.reload_pseudolocalization()
	var result: String = _restore_slots(pseudo, masked.get("restore", []) as Array)
	if _pseudo_cache.size() >= PSEUDO_CACHE_LIMIT:
		_pseudo_cache.clear()
	_pseudo_cache[cache_key] = result
	return result


## Replaces every {slot} with the ONE escape Godot's pseudolocalizer really passes through - a bare
## printf "%s". Verified against the engine rather than assumed: a control character is deleted
## outright, "%1$s" comes back as "%1$š", and only "%s"/"%d" survive a round trip intact.
##
## Returns {"text", "restore"}: `restore` is every protected token in source order, INCLUDING the
## "%s" the author wrote themselves - those survive too, so counting them in keeps the left-to-right
## walk back honest when a string mixes both kinds.
static func _mask_slots(text: String) -> Dictionary:
	var masked: String = ""
	var restore: Array = []
	var cursor: int = 0
	while cursor < text.length():
		var character: String = text[cursor]
		if character == "%" and cursor + 1 < text.length() and text[cursor + 1] == "s":
			masked += "%s"
			restore.append("%s")
			cursor += 2
			continue
		if character == "{":
			var close_brace: int = text.find("}", cursor)
			if close_brace != -1:
				masked += "%s"
				restore.append(text.substr(cursor, close_brace - cursor + 1))
				cursor = close_brace + 1
				continue
		masked += character
		cursor += 1
	return {"text": masked, "restore": restore}


## Puts the protected tokens back, one at a time, left to right. A plain replace() would turn every
## mask into the FIRST slot, silently rewriting "{a} of {b}" into "{a} of {a}".
static func _restore_slots(pseudo: String, restore: Array) -> String:
	var restored: String = pseudo
	var cursor: int = 0
	for token: Variant in restore:
		var at: int = restored.find("%s", cursor)
		if at == -1:
			break
		restored = restored.substr(0, at) + str(token) + restored.substr(at + 2)
		cursor = at + str(token).length()
	return restored


## Writes a pseudo column into a translator CSV. It REFUSES to write into a real language's column:
## pseudo text in a shipped locale is a bug nobody would ever find by reading the file, so the only
## column this will fill is a pseudo one.
static func write_pseudo_column(csv_path: String, locale: String = PSEUDO_LOCALE,
		expansion: float = DEFAULT_EXPANSION, separator: String = ",") -> Dictionary:
	var column: String = locale.strip_edges()
	if not is_pseudo_locale(column):
		return {"ok": false, "message": "\"%s\" is a real language - pseudo text only ever goes in a throwaway column (qps)." % column}
	var catalog: Dictionary = EventSheetTranslationScan.read_catalog(csv_path, separator)
	if not bool(catalog.get("ok", false)):
		return catalog
	var columns: PackedStringArray = catalog.get("columns", PackedStringArray())
	if not columns.has(column):
		columns.append(column)
	var rows: Array = []
	for row: Variant in (catalog.get("rows", []) as Array):
		var record: Dictionary = (row as Dictionary).duplicate()
		var key: String = str(record.get(EventSheetTranslationScan.KEY_COLUMN, ""))
		var source: String = str(record.get(EventSheetTranslationScan.SOURCE_COLUMN, ""))
		record[column] = pseudolocalize(source if not source.is_empty() else key, expansion)
		var out: Dictionary = {}
		for name: String in columns:
			out[name] = str(record.get(name, ""))
		rows.append(out)
	var column_specs: Array = []
	for name: String in columns:
		column_specs.append({"name": name, "type": "String"})
	var written: Dictionary = EventSheetGridCSV.write_csv(csv_path, rows, column_specs, separator)
	if not bool(written.get("ok", false)):
		return written
	return {"ok": true, "rows": rows.size(),
		"message": "Wrote a \"%s\" pseudo column for %d key(s) in %s - switch to it with Set Language to see what clips." % [column, rows.size(), csv_path]}


## True for a locale that is a test language rather than one a player ever picks. Godot standardizes
## "qps_ploc" down to "qps", and the whole q-prefixed range is reserved for exactly this.
static func is_pseudo_locale(locale: String) -> bool:
	var standardized: String = TranslationServer.standardize_locale(locale.strip_edges())
	return standardized.begins_with("qp") or standardized == PSEUDO_LOCALE

# ── The project's own localisation settings ──────────────────────────────────


## The translation files the project registers (Project Settings > Localization > Translations).
static func registered_translations() -> PackedStringArray:
	var setting: Variant = ProjectSettings.get_setting(TRANSLATIONS_SETTING, PackedStringArray())
	return PackedStringArray(setting) if setting is PackedStringArray or setting is Array else PackedStringArray()


## Registers every catalog in `folder` under Localization - the step everyone forgets after a
## translator sends a file back. Existing entries are kept and never duplicated. `save` writes
## project.godot; pass false to compute the list without touching the file.
static func register_catalogs(folder: String, save: bool = true) -> Dictionary:
	var directory: DirAccess = DirAccess.open(folder)
	if directory == null:
		return {"ok": false, "message": "There is no folder at %s to register." % folder}
	var registered: PackedStringArray = registered_translations()
	var added: PackedStringArray = PackedStringArray()
	var names: PackedStringArray = directory.get_files()
	names.sort()
	for name: String in names:
		if not ["translation", "po"].has(name.get_extension().to_lower()):
			continue
		var path: String = "%s/%s" % [folder.rstrip("/"), name]
		if registered.has(path):
			continue
		registered.append(path)
		added.append(path)
	ProjectSettings.set_setting(TRANSLATIONS_SETTING, registered)
	if save:
		ProjectSettings.save()
	if added.is_empty():
		return {"ok": true, "added": added, "registered": registered,
			"message": "Nothing new in %s - every catalog there is already registered." % folder}
	return {"ok": true, "added": added, "registered": registered,
		"message": "Registered %d catalog(s) under Localization: %s." % [added.size(), ", ".join(added)]}


## Godot's own "run the game in this language" setting, which is what makes the next Play speak the
## previewed language with no debug key to press. This WRITES project.godot when `save` is on - it is
## a real project setting, the same one Project Settings > Localization > Locale > Test edits, and
## every caller says so rather than claiming nothing was written.
##
## Empty REMOVES the setting rather than storing "": assigning null is how Godot erases a setting
## (checked on 4.7 - has_setting goes false), so going back to "As authored" leaves project.godot
## exactly as it was found instead of leaving an empty override behind in the user's VCS diff.
static func set_test_locale(locale: String, save: bool = true) -> Dictionary:
	if locale.strip_edges().is_empty():
		if ProjectSettings.has_setting(TEST_LOCALE_SETTING):
			ProjectSettings.set_setting(TEST_LOCALE_SETTING, null)
			if save:
				ProjectSettings.save()
		return {"ok": true, "message": "The next Play runs in the system language again."}
	ProjectSettings.set_setting(TEST_LOCALE_SETTING, locale)
	if save:
		ProjectSettings.save()
	return {"ok": true, "message": "The next Play runs in %s (Project Settings > Localization > Locale > Test)." % locale}


static func test_locale() -> String:
	return str(ProjectSettings.get_setting(TEST_LOCALE_SETTING, ""))

# ── Language variants of an asset (Godot's remap table) ──────────────────────


## The project's remap table: base path -> PackedStringArray of "variant_path:locale" entries. The
## setting Godot declares as a PackedStringArray default but stores as a Dictionary the moment
## Project Settings > Localization > Remaps holds anything.
static func remaps() -> Dictionary:
	var setting: Variant = ProjectSettings.get_setting(REMAPS_SETTING, {})
	return setting as Dictionary if setting is Dictionary else {}


## The locales a base asset already has a variant for.
static func remap_locales(base_path: String) -> PackedStringArray:
	var locales: PackedStringArray = PackedStringArray()
	var table: Dictionary = remaps()
	if not table.has(base_path):
		return locales
	for entry: Variant in PackedStringArray(table[base_path]):
		var text: String = str(entry)
		var separator: int = text.rfind(":")
		if separator > 0:
			locales.append(text.substr(separator + 1))
	return locales


## Writes `pairs` (locale -> variant path) as the remap table entry for `base_path`, the exact shape
## Project Settings > Localization > Remaps edits. An empty pairs dict removes the entry entirely.
static func set_remap(base_path: String, pairs: Dictionary, save: bool = true) -> Dictionary:
	if base_path.strip_edges().is_empty():
		return {"ok": false, "message": "Name the asset the variants belong to."}
	var table: Dictionary = remaps()
	if pairs.is_empty():
		table.erase(base_path)
	else:
		var entries: PackedStringArray = PackedStringArray()
		var locales: Array = pairs.keys()
		locales.sort()
		for locale: Variant in locales:
			entries.append("%s:%s" % [str(pairs[locale]), str(locale)])
		table[base_path] = entries
	ProjectSettings.set_setting(REMAPS_SETTING, table)
	if save:
		ProjectSettings.save()
	if pairs.is_empty():
		return {"ok": true, "message": "%s has no language variants any more." % base_path}
	return {"ok": true, "message": "%s now swaps for %d language(s) - the engine returns the variant from load() with no rows changed." % [base_path, pairs.size()]}


## The variant file that would sit beside `base_path` for `locale` ("art/sign.png" ->
## "art/sign.ja.png"), and whether it is really there. The dialog ticks the ones that exist.
static func variant_path(base_path: String, locale: String) -> String:
	if base_path.strip_edges().is_empty() or locale.strip_edges().is_empty():
		return ""
	var extension: String = base_path.get_extension()
	if extension.is_empty():
		return "%s.%s" % [base_path, locale]
	return "%s.%s.%s" % [base_path.get_basename(), locale, extension]


## THE finding nobody can see by looking: a remapped asset reached through preload resolves when the
## SCRIPT loads, so Set Language swaps the catalog and leaves the art in English. Returns the
## offending script paths for a base asset.
static func frozen_preloads(base_path: String, scripts: PackedStringArray) -> PackedStringArray:
	var offenders: PackedStringArray = PackedStringArray()
	if base_path.strip_edges().is_empty():
		return offenders
	var needle: String = "preload(\"%s\")" % base_path
	for path: String in scripts:
		if FileAccess.get_file_as_string(path).contains(needle):
			offenders.append(path)
	return offenders
