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
	config.save(LANGUAGE_FILE)
