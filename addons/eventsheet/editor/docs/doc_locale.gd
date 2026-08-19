# EventSheet - EventSheetDocLocale: the Manual in the reader's own language, page by page.
#
# The plugin's UI ships in nine languages; the Manual shipped in one, so a reader with Spanish menus
# read English help. This is the seam that fixes it, and the whole mechanism is a folder:
#
#   docs/<locale>/GUIDE-RECIPES.md      ->  addons/eventsheet/help/<locale>/GUIDE-RECIPES.md
#
# The bundle builder walks those folders exactly as it walks Addons/ and Modules/ - by DIRECTORY,
# never by a list - so a translated page ships by existing. Nothing is required to exist: a page
# with no translation for the reader's locale is drawn in English with a one-line note asking for
# help translating it, and the note opens the translations folder in the file manager rather than
# a web form nobody can act on.
#
# NO MACHINE TRANSLATION. A page is translated by a person or it is in English; there is no third
# state, and this file will not invent one.
#
# THE FIGURES ARE ALREADY TRANSLATED and that is not extra work: a figure is real rows drawn by the
# real renderer, and the renderer's own words go through the plugin's translation domain. So a
# Spanish reader of an English page still sees Spanish rows in every illustration on it.
#
# Everything here is static and PURE over its inputs (a locale, a page id, the ids that exist), so
# the fallback rule is pinned by the suite rather than inferred from whatever happens to be
# installed.
@tool
class_name EventSheetDocLocale
extends RefCounted

## The locale every page is guaranteed to exist in, and the one a missing translation falls back to.
const BASE_LOCALE := "en"

## Where a translator drops their pages, in the repository and in an installed plugin. The note's
## button opens the first of these that exists.
const SOURCE_DIR := "res://docs"
const PROJECT_DIR := "res://eventsheet_docs"


## The locale the Manual reads in: whatever language the reader chose for the plugin's UI, so the
## menus and the help are never in two different languages. "en" outside the editor.
static func locale() -> String:
	var chosen: String = EventSheetL10n.get_locale().strip_edges()
	return BASE_LOCALE if chosen.is_empty() else chosen


## The page id a reader in `locale_code` should be shown for `page_id`, given the ids that exist.
## PURE over that list, which is what lets the suite pin the fallback against three fixture ids
## instead of against whatever the bundle happens to carry this week.
##
## The rule, in one line: the locale's own copy when it ships, and the English page otherwise. A
## page id that is ALREADY locale-prefixed is answered as itself, so following a link inside a
## translated page does not prefix it twice.
static func page_for(page_id: String, locale_code: String, available: PackedStringArray) -> String:
	var id: String = base_page_id(page_id)
	if id.is_empty():
		return ""
	var wanted: String = locale_code.strip_edges()
	if wanted.is_empty() or wanted == BASE_LOCALE:
		return id
	var localized: String = "%s/%s" % [wanted, id]
	return localized if Array(available).has(localized) else id


## The page id under a locale prefix, stripped back to the page it is a translation OF
## ("fr/GUIDE-RECIPES" -> "GUIDE-RECIPES"). A page that carries no known locale prefix is itself.
static func base_page_id(page_id: String) -> String:
	var id: String = page_id.strip_edges()
	var separator: int = id.find("/")
	if separator <= 0:
		return id
	return id.substr(separator + 1) if is_locale_prefix(id.substr(0, separator)) else id


## The locale a page id is written in ("fr/GUIDE-RECIPES" -> "fr"), and "en" for an unprefixed one.
static func locale_of(page_id: String) -> String:
	var id: String = page_id.strip_edges()
	var separator: int = id.find("/")
	if separator <= 0:
		return BASE_LOCALE
	var prefix: String = id.substr(0, separator)
	return prefix if is_locale_prefix(prefix) else BASE_LOCALE


## Whether a top-level bundle directory names a LOCALE rather than a doc set. Decided by shape
## rather than by a list of languages, so a translator who ships pt_BR needs no entry anywhere:
## a locale directory is two lowercase letters, optionally followed by _ and a region code. The
## shipped doc sets ("Addons", "Modules") are Title Case and can never match.
static func is_locale_prefix(directory: String) -> bool:
	var name: String = directory.strip_edges()
	var language: String = name.get_slice("_", 0)
	if language.length() != 2 or language != language.to_lower():
		return false
	for index: int in range(language.length()):
		if language[index] < "a" or language[index] > "z":
			return false
	if not name.contains("_"):
		return true
	var region: String = name.substr(language.length() + 1)
	return not region.is_empty() and region == region.to_upper()


## True when the reader is being shown English because their locale has no copy of this page - the
## one condition the note below is drawn for.
static func is_untranslated(page_id: String, locale_code: String) -> bool:
	var wanted: String = locale_code.strip_edges()
	if wanted.is_empty() or wanted == BASE_LOCALE:
		return false
	return locale_of(page_id) != wanted


## The note's own sentence. Pure, so the words are pinned rather than screenshotted, and phrased as
## an invitation because that is what it is: nobody owes anybody a translation.
static func note_text() -> String:
	return "This page is not translated yet - help translate it"


## And the hover, which says where the work would go.
static func note_tooltip(locale_code: String) -> String:
	return "Opens the folder where the Manual's translated pages live. A page for %s goes in docs/%s/ with the same file name as the English one." % [
		locale_code.strip_edges(), locale_code.strip_edges()]


## The note as a page block, or an empty Dictionary when the page IS in the reader's language. It
## goes at the TOP of the page for the same reason the missing-guide stub does: a reader deciding
## whether to trust what they are reading is deciding it now, not after nine screens.
static func note_block(page_id: String, locale_code: String) -> Dictionary:
	if not is_untranslated(page_id, locale_code):
		return {}
	return {"kind": "quote", "bbcode": EventSheetDocMarkdown.escape_brackets(note_text())}


## The folder a translator's pages go in, for the button beside the note: the repository's own docs
## folder when the reader has a checkout, and the project's docs folder otherwise. "" when neither
## exists, which is what makes the caller hide the button rather than open nothing.
static func translations_dir() -> String:
	for path: String in [SOURCE_DIR, PROJECT_DIR]:
		if DirAccess.dir_exists_absolute(path):
			return path
	return ""
