@tool
class_name EventSheetL10n
extends RefCounted

# Editor-UI localisation for the plugin itself (the sheets you MAKE have their own game-side
# l10n - the Translation module + tr()-wrapped params; this file never touches that).
#
# How it works, in one breath: the plugin owns a TranslationDomain ("eventsheets") and the dock
# root is assigned to it, so EVERY Control string under the dock - button text, menu items,
# tooltips, dialog titles - resolves through atr() automatically. Translators never touch code:
# drop a CSV into one of the translation folders (English source text in the first column, one
# column per locale) and that locale appears in the Language picker. English is the default and
# the permanent fallback - an untranslated string always shows its English source.
#
# The plugin's language is chosen INDEPENDENTLY of the editor's: whichever locale the user picks,
# its messages are loaded into a Translation stamped with the EDITOR's current locale, so domain
# lookups always hit. Custom-drawn text (canvas draw_string sites: empty states, banners, add
# affordances) can't auto-translate, so those few sites call EventSheetL10n.translate() explicitly.
#
# Drop-in translation files, scanned from BOTH folders (addon-bundled + project-local so user
# translations survive plugin updates):
#   res://addons/eventsheet/translations/*.csv   and   res://eventsheet_translations/*.csv
#   CSV shape (Godot's own convention):  keys,fr,es\n  Save,Enregistrer,Guardar
#   Ready-made Translation resources (*.translation / *.tres) are picked up too.
# The chosen language persists per-user per-project (user:// - never committed, like recents).

const DOMAIN := "eventsheets"
const SCAN_DIRS: Array[String] = [
	"res://addons/eventsheet/translations",
	"res://eventsheet_translations",
]
const LANGUAGE_FILE := "user://eventforge_editor_language.cfg"

## locale code -> {english_source: translated} - merged across every discovered file.
static var _catalogs: Dictionary = {}
static var _locale: String = "en"
static var _loaded: bool = false
## The Translation object currently installed in the domain (tracked so a locale switch can
## remove it before installing the next one).
static var _installed: Translation = null


## Hydrates catalogs + the saved language once per session. Safe headless (no editor, no UI).
static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	rescan()
	_load_language_preference()
	_apply_domain()


## Re-reads every translation file from the scan folders. Called on load and by the API's
## register hooks; cheap enough to run on demand (a handful of small files).
static func rescan() -> void:
	_catalogs.clear()
	for dir_path: String in SCAN_DIRS:
		if not DirAccess.dir_exists_absolute(dir_path):
			continue
		for file_name: String in DirAccess.get_files_at(dir_path):
			load_translation_file("%s/%s" % [dir_path, file_name])
	# Pack-local translations (the Construct lang.json idea): a pack ships
	# eventsheet_addons/<pack>/translations.csv - same drop-in CSV shape, one column per
	# locale - and its display names/descriptions/templates localise everywhere they show
	# (picker rows, tooltips, viewport sentences). Merged after the editor's own catalogs,
	# so a pack can only ADD messages, never re-word the editor UI.
	for pack_csv: String in _pack_translation_files():
		load_translation_file(pack_csv)
	_scan_stamp = scan_fingerprint()


const PACKS_DIR := "res://eventsheet_addons"


## Every pack-local translations.csv, sorted for a deterministic merge order.
static func _pack_translation_files() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if not DirAccess.dir_exists_absolute(PACKS_DIR):
		return out
	for pack_dir: String in DirAccess.get_directories_at(PACKS_DIR):
		var candidate: String = "%s/%s/translations.csv" % [PACKS_DIR, pack_dir]
		if FileAccess.file_exists(candidate):
			out.append(candidate)
	out.sort()
	return out


## What the scan folders currently hold (names + modified times), cheap enough to compare on
## every editor filesystem-changed ping. When it differs from the last rescan's stamp, a
## translation file was dropped in / edited / removed.
static var _scan_stamp: String = ""


static func scan_fingerprint() -> String:
	var parts: PackedStringArray = PackedStringArray()
	for dir_path: String in SCAN_DIRS:
		if not DirAccess.dir_exists_absolute(dir_path):
			continue
		for file_name: String in DirAccess.get_files_at(dir_path):
			var ext: String = file_name.get_extension().to_lower()
			if ext != "csv" and ext != "translation" and ext != "tres":
				continue
			var path: String = "%s/%s" % [dir_path, file_name]
			parts.append("%s|%d" % [path, FileAccess.get_modified_time(path)])
	for pack_csv: String in _pack_translation_files():
		parts.append("%s|%d" % [pack_csv, FileAccess.get_modified_time(pack_csv)])
	parts.sort()
	return "\n".join(parts)


## Drop-in live reload: when the scan folders changed since the last rescan, re-read every
## translation file, re-adopt the saved language preference (a preferred locale whose CSV was
## missing at boot activates the moment its file lands), and reinstall the active catalog so
## already-open UI re-translates. Returns true when a reload actually happened - the dock uses
## that to propagate NOTIFICATION_TRANSLATION_CHANGED. No-op (and false) when nothing changed.
static func reload_if_changed() -> bool:
	ensure_loaded()
	if scan_fingerprint() == _scan_stamp:
		return false
	rescan()
	_load_language_preference()
	if _locale != "en" and not _catalogs.has(_locale):
		_locale = "en"  # the active language's file was removed - fall back rather than dangle
	_apply_domain()
	return true


## Loads one translation file into the catalogs (merging; later files win on key collisions).
## Supports the drop-in CSV shape and ready-made Translation resources. Returns true when the
## file contributed at least one message - the API surfaces use this to confirm registration.
static func load_translation_file(path: String) -> bool:
	match path.get_extension().to_lower():
		"csv":
			return _load_csv(path)
		"translation", "tres":
			return _load_translation_resource(path)
	return false


static func _load_csv(path: String) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var header: PackedStringArray = file.get_csv_line()
	if header.size() < 2:
		return false
	var contributed: bool = false
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.size() < 2 or row[0].is_empty():
			continue
		var source: String = row[0]
		for column: int in range(1, header.size()):
			var locale: String = header[column].strip_edges()
			# Column 0's header is a label ("keys"), not a locale; an "en" column is meaningless
			# (English IS the key) - both are skipped rather than becoming ghost languages.
			if locale.is_empty() or locale.to_lower() == "en" or locale.to_lower() == "keys":
				continue
			if column >= row.size() or row[column].strip_edges().is_empty():
				continue
			if not _catalogs.has(locale):
				_catalogs[locale] = {}
			(_catalogs[locale] as Dictionary)[source] = row[column]
			contributed = true
	return contributed


static func _load_translation_resource(path: String) -> bool:
	if not ResourceLoader.exists(path):
		return false
	var resource: Resource = load(path)
	if not (resource is Translation):
		return false
	var translation: Translation = resource as Translation
	var locale: String = translation.locale.strip_edges()
	if locale.is_empty() or locale.to_lower() == "en":
		return false
	if not _catalogs.has(locale):
		_catalogs[locale] = {}
	var catalog: Dictionary = _catalogs[locale]
	var contributed: bool = false
	for key: StringName in translation.get_message_list():
		var message: String = translation.get_message(key)
		if not message.is_empty():
			catalog[str(key)] = message
			contributed = true
	return contributed


## Every language the picker offers: English first (the built-in default), then each locale a
## translation file provided, sorted for a stable menu.
static func available_locales() -> PackedStringArray:
	ensure_loaded()
	var locales: PackedStringArray = PackedStringArray(["en"])
	var discovered: Array = _catalogs.keys()
	discovered.sort()
	for locale: Variant in discovered:
		locales.append(str(locale))
	return locales


## Human-readable name for the picker ("fr" -> "French"); falls back to the code itself.
static func locale_display_name(locale: String) -> String:
	if locale == "en":
		return "English (default)"
	var language_name: String = TranslationServer.get_locale_name(locale)
	return language_name if not language_name.is_empty() else locale


static func get_locale() -> String:
	ensure_loaded()
	return _locale


## Switches the plugin's language: installs the locale's messages into the domain (auto-translated
## Controls pick it up via the translation-changed notification the caller propagates) and
## persists the choice per-user per-project. "en" empties the domain - source strings ARE English.
static func set_locale(locale: String) -> void:
	ensure_loaded()
	_locale = locale if locale == "en" or _catalogs.has(locale) else "en"
	_apply_domain()
	_save_language_preference()


## Explicit translation for strings that never pass through a Control property - the canvas
## draw_string sites (empty states, banner, add affordances) and any dynamic formatting.
## English default: pass-through when no translation exists. Named translate (not tr) because
## a static tr() would shadow Object's native method.
static func translate(text: String) -> String:
	ensure_loaded()
	if _locale == "en" or text.is_empty():
		return text
	var catalog: Dictionary = _catalogs.get(_locale, {})
	return str(catalog.get(text, text))


## Assigns the plugin's translation domain to a UI root (the dock, a detached window): every
## descendant Control's text/tooltip then auto-translates. Idempotent.
static func apply_to(node: Node) -> void:
	ensure_loaded()
	node.set_translation_domain(DOMAIN)


## Installs the active locale's catalog into the shared domain. The Translation is stamped with
## the EDITOR's current locale (not the plugin locale) because atr() looks messages up by the
## server locale - this is what lets the plugin speak French inside an English editor.
static func _apply_domain() -> void:
	var domain: TranslationDomain = TranslationServer.get_or_add_domain(DOMAIN)
	if _installed != null:
		domain.remove_translation(_installed)
		_installed = null
	if _locale == "en" or not _catalogs.has(_locale):
		return
	var translation: Translation = Translation.new()
	translation.locale = TranslationServer.get_locale()
	var catalog: Dictionary = _catalogs[_locale]
	for source: Variant in catalog:
		translation.add_message(str(source), str(catalog[source]))
	domain.add_translation(translation)
	_installed = translation


## One entry per project (keyed by a hash of the project path) in a single per-user file, so one
## machine's editors don't leak language choices between projects. Editor-only: the headless
## suite must stay side-effect-free.
static func _preference_key() -> String:
	return ProjectSettings.globalize_path("res://").sha1_text()


static func _load_language_preference() -> void:
	if not Engine.is_editor_hint():
		return
	var config: ConfigFile = ConfigFile.new()
	if config.load(LANGUAGE_FILE) != OK:
		return
	var stored: String = str(config.get_value("language", _preference_key(), "en"))
	if stored == "en" or _catalogs.has(stored):
		_locale = stored


static func _save_language_preference() -> void:
	if not Engine.is_editor_hint():
		return
	var config: ConfigFile = ConfigFile.new()
	config.load(LANGUAGE_FILE)  # preserve other projects' choices already in the file
	config.set_value("language", _preference_key(), _locale)
	if config.save(LANGUAGE_FILE) != OK:
		push_warning("EventSheets: couldn't save the language preference to %s - it lasts only this session." % LANGUAGE_FILE)
