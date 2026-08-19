# EventForge module - Translation vocabulary (localisation the Godot way).
#
# Thin verbs over Godot's own localisation runtime: TranslationServer swaps locales,
# tr()/tr_n() look up the current language, and Project Settings > Localization owns
# the catalogs (its POT generation reads tr() calls straight out of the compiled .gd).
# Nothing here adds runtime - every emission is a bare native call (parity-clean).
#
# On Language Changed compiles to the _notification virtual (the engine has no signal
# for it); applying the trigger auto-adds the "Language Just Changed" gate condition
# so the event only runs for NOTIFICATION_TRANSLATION_CHANGED - visible in the sheet,
# deletable, and round-tripping as the plain event + condition it is.
#
# Everything AROUND the lookup, in the order a shipped game meets it:
#
#  - WHAT ACTUALLY SHIPPED. For Each Language walks the catalogs Godot loaded, so a language
#    menu builds itself instead of rotting one hand-written button at a time. Language Name In
#    Its Own Language reads a LANGUAGE_NAME row out of that language's own catalog, so the entry
#    reads "Deutsch" and not "German", and falls back to Godot's English name when the row is
#    missing. Language Is Available gates a button; Use Saved Language restores last time's pick.
#  - MATCHING, NOT COMPARING. compare_locales scores a pair of locales 0..10 (pt_BR against pt
#    scores 5), so Language Matches is true for an en_US player asked about "en" - which a string
#    comparison against Current Language is not. Region Is reads the subtags after the language, so
#    a variant or a script subtag cannot shift which one is the country; Value For Language picks
#    the best entry of a record in one row.
#  - FOLLOWING A SWITCH. Godot re-renders text a Control still holds as its SOURCE string; text a
#    sheet computed and assigned does NOT follow, so half the screen switches and half stays.
#    Set Text (follows language) remembers the key on the node it wrote to, Refresh Text That
#    Follows Language re-applies every remembered key in one row, and Keep This Text Untranslated
#    protects the strings that are data (a player's name, a save-slot label) from being looked up.
#  - PLURALS THAT FINISH THE SENTENCE. The chosen form still carries its %d; Counted Text fills the
#    count into it and Counted Text From Pattern does the same with named slots. Which form is
#    chosen depends on what the catalog can carry (see _PLURAL_FORM): a .po catalog's own three
#    Russian forms when it has them, the two translated keys of a CSV catalog when it does not -
#    never tr_n on a catalog that would make it error.
#  - MISSING KEYS. tr() returns the key itself when nothing matches, so a player reads
#    "MENU_TITLE" and nothing errors. Text Is Translated / Language Has Text For / Translated Text
#    Or Fallback make that visible and survivable; Test With Fake Translation flips Godot's
#    pseudolocalization on, so any string that stays plain ASCII is one nobody marked.
#  - GENDER AND NAMES. Translated Text From Pattern In Context looks a whole sentence up WITH a
#    context (which is an expression, so it can be a gender variable) and fills its slots after;
#    Translated Text With Words fills from a standing word set merged with this line's values.
#  - NUMBERS THE LOCALE CAN READ. Local digits both ways, the language's own percent sign, and a
#    date handed to the catalog as PARTS so the translator owns the order without a build.
#
# ace_ids and codegen_templates are a compatibility covenant: frozen once shipped (deprecate,
# never rename).
@tool
class_name EventForgeTranslationACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

const CAT := "Translation"
const CAT_LOOPS := "Loops"

## The pair that makes text follow a language switch: Set Text (follows language) stamps the key it
## used into this meta and joins the node to this group; Refresh Text That Follows Language walks
## the group and re-applies the meta. Written out here so the two verbs can never drift apart - in
## the emitted code they are plain strings, so a hand-written node can join the group the same way.
const FOLLOWS_GROUP := "&\"follows_language\""
const FOLLOWS_META := "&\"follows_language_key\""

## The own-name lookup, three times over: a catalog for that locale exists, its LANGUAGE_NAME row is
## filled, and only then is it used. Composed once because the guard and the value must stay the
## same expression - a guard that drifts from what it guards is a null call waiting to happen.
const _OWN_NAME := "str(TranslationServer.get_translation_object({locale}).get_message(&\"LANGUAGE_NAME\"))"

## "This exact catalog is loaded", which is NOT what get_translation_object answers: that one
## fuzzy-matches, so a build shipping only pt_BR hands its catalog back for "pt_PT" as well
## (checked on 4.7: get_translation_object("pt_PT") returns the pt_BR object while
## has_translation_for_locale("pt_PT", true) is false). Every verb that promises one NAMED
## language's own catalog gates on this first, so the fuzzy object is only ever read once the exact
## one is known to exist.
const _EXACT_CATALOG := "TranslationServer.has_translation_for_locale({locale}, true)"

## Choosing the plural form WITHOUT ever handing tr_n a form index its catalog cannot answer.
##
## Godot derives the plural RULE from the locale (ru: nplurals=3) but the forms come from the
## catalog, and Godot's CSV importer - the route the guide calls the fastest, and the one this
## plugin's own tooling writes - stores "%d apple" and "%d apples" as two ORDINARY keys with one
## form each. Asking tr_n for a Russian n=2 then prints "Plural index returned or number of plural
## translations is not valid." (core/string/translation.cpp) once per call and hands back the
## untranslated English. Verified on 4.7, not assumed.
##
## So: when the catalog holds the many-items form as a key of its own, it is a two-form catalog and
## the count picks between the two translated keys directly; otherwise nothing translated the plural
## source, which is the gettext/.po shape, and tr_n is asked - where the catalog really does carry
## three Russian forms and picks correctly. Both branches are plain native calls.
const _PLURAL_FORM := "((tr({singular}) if int({count}) == 1 else tr({plural})) if tr({plural}) != {plural} else tr_n({singular}, {plural}, int({count})))"

## Filling the count into the chosen form. `replace` rather than `%`: a translator who drops the %d
## makes `form % count` raise "String formatting error: not all arguments converted during string
## formatting" on EVERY evaluation (once a frame under On Process), while replace simply leaves the
## sentence as the translator wrote it - which is what the descriptions have always promised.
const _FILL_COUNT := ".replace(\"%d\", str(int({count})))"


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	descriptors.append(F.make_descriptor("Core", "SetLocale", "Set Language", ACEDescriptor.ACEType.ACTION,
		"TranslationServer.set_locale({locale})", "",
		[F.make_param("locale", "String", "\"en\"", "Locale", "Language code to switch to, e.g. \"en\", \"es\", \"ja\".", "expression")],
		CAT, "set language to {locale}")
		.described("Switches the game's language live. Auto-translated Controls and every later tr() lookup follow immediately."))

	descriptors.append(F.make_descriptor("Core", "GetLocale", "Current Language", ACEDescriptor.ACEType.EXPRESSION,
		"TranslationServer.get_locale()", "", [],
		CAT, "current language")
		.described("The active locale code, e.g. \"en\" or \"es\"."))

	descriptors.append(F.make_descriptor("Core", "Translate", "Translate", ACEDescriptor.ACEType.EXPRESSION,
		"tr({text})", "",
		[F.make_param("text", "String", "\"HELLO\"", "Text", "The source string (or key) to look up.", "expression")],
		CAT, "translate {text}")
		.described("Looks the text up in the current language (tr). For a fixed label, the field's globe toggle does this without an expression."))

	descriptors.append(F.make_descriptor("Core", "TranslateWithContext", "Translate With Context", ACEDescriptor.ACEType.EXPRESSION,
		"tr({text}, {context})", "",
		[
			F.make_param("text", "String", "\"May\"", "Text", "The source string (or key) to look up.", "expression"),
			F.make_param("context", "String", "\"month\"", "Context", "Disambiguates identical strings, e.g. \"May\" the month vs the verb.", "expression"),
		], CAT, "translate {text} as {context}")
		.described("tr() with a translation context, for strings that read the same but translate differently."))

	descriptors.append(F.make_descriptor("Core", "TranslatePlural", "Translate Plural", ACEDescriptor.ACEType.EXPRESSION,
		"tr_n({singular}, {plural}, {count})", "",
		[
			F.make_param("singular", "String", "\"%d apple\"", "Singular", "The one-item form.", "expression"),
			F.make_param("plural", "String", "\"%d apples\"", "Plural", "The many-items form.", "expression"),
			F.make_param("count", "String", "2", "Count", "How many - picks the right form per language.", "expression"),
		], CAT, "translate plural for {count}")
		.described("Picks the singular or plural form for the count in the current language (tr_n); languages with more plural forms use their catalog's rules. It returns the chosen form as it stands, so a \"%d apples\" form still carries its %d - Counted Text is the one that fills the number in."))

	descriptors.append(F.make_descriptor("Core", "IsLocaleChangeNotification", "Language Just Changed", ACEDescriptor.ACEType.CONDITION,
		"what == NOTIFICATION_TRANSLATION_CHANGED", "", [],
		CAT, "language just changed")
		.described("The gate under On Language Changed: true only for the engine's translation-changed notification."))

	descriptors.append(F.make_descriptor("Core", "OnLocaleChanged", "On Language Changed", ACEDescriptor.ACEType.TRIGGER,
		"", "", [],
		CAT, "on language changed")
		.described("Runs when the game's language switches. Compiles to the _notification virtual with the Language Just Changed gate added for you."))

	descriptors.append_array(_menu_descriptors())
	descriptors.append_array(_matching_descriptors())
	descriptors.append_array(_following_descriptors())
	descriptors.append_array(_counted_descriptors())
	descriptors.append_array(_missing_key_descriptors())
	descriptors.append_array(_sentence_descriptors())
	descriptors.append_array(_number_descriptors())
	return descriptors


static func section_descriptions() -> Dictionary:
	return {CAT: "Shipping the game in more than one language: switch and match a locale, look text up, finish a plural, survive a missing key, and write numbers the way the language does."}


# -- The language menu that builds itself --


## Enumerating what the build ACTUALLY ships, so a language list is read rather than hand-written.
static func _menu_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	descriptors.append(F.make_descriptor("Core", "ForEachLanguage", "For Each Language", ACEDescriptor.ACEType.CONDITION,
		"TranslationServer.get_loaded_locales()", "", [],
		CAT_LOOPS, "for each language")
		.described("Runs this event's actions once per language your project actually ships - the catalogs Godot loaded from Project Settings > Localization. Read the current one as `language`. A language you add later joins the menu with no sheet edit, and a demo build that ships fewer catalogs shows fewer entries. Only languages WITH a catalog are listed, so English usually appears only when it has one of its own.")
		.looping("language").featured())

	descriptors.append(F.make_descriptor("Core", "LanguageOwnName", "Language Name In Its Own Language", ACEDescriptor.ACEType.EXPRESSION,
		"(%s if %s and not %s.is_empty() else TranslationServer.get_locale_name({locale}))" % [_OWN_NAME, _EXACT_CATALOG, _OWN_NAME], "",
		[F.make_param("locale", "String", "\"de\"", "Language", "A locale code, e.g. \"de\" - usually the loop's `language`.", "expression")],
		CAT, "name of [b]{locale}[/b] in its own language")
		.described("The language's name as its own speakers write it: put a LANGUAGE_NAME row in each catalog (LANGUAGE_NAME,Deutsch,Espanol) and a German player reads \"Deutsch\". It reads THAT language's own catalog and no other, so a build shipping only pt_BR does not label a pt_PT entry with the Brazilian name. Falls back to Godot's English name when the row is missing, and to the bare code when the language has no catalog of its own, so a menu entry is never blank."))

	descriptors.append(F.make_descriptor("Core", "LanguageIsAvailable", "Language Is Available", ACEDescriptor.ACEType.CONDITION,
		"TranslationServer.has_translation_for_locale({locale}, false)", "",
		[F.make_param("locale", "String", "\"es\"", "Language", "The locale code to check for.", "expression")],
		CAT, "[b]{locale}[/b] is available")
		.described("True when a catalog for that language is registered in this build. Gate a flag button on it and a demo build hides the languages it did not ship. Matched the way Godot matches, not letter for letter, so a build that ships pt_BR answers true for \"pt\" as well - ask Language Has Text For when you need one exact catalog."))

	descriptors.append(F.make_descriptor("Core", "UseSavedLanguage", "Use Saved Language", ACEDescriptor.ACEType.ACTION,
		"var __lang_cfg_{uid} = ConfigFile.new()\n__lang_cfg_{uid}.load(\"user://settings.cfg\")\nTranslationServer.set_locale(str(__lang_cfg_{uid}.get_value(\"game\", \"language\", {fallback})))", "",
		[F.make_param("fallback", "String", "OS.get_locale()", "Otherwise", "What to use on a first run, before the player has chosen - the system locale is the friendly default.", "expression")],
		CAT, "use the saved language, otherwise [b]{fallback}[/b]")
		.described("Applies the language the player picked last time, reading the same user://settings.cfg the Save Setting action writes - section \"game\", key \"language\". A first run has no file yet and falls back to whatever you pass, so pair it with a Save Setting on the button that switches."))

	return descriptors


# -- Match a language, never compare it --


## Branching on the locale through Godot's own matcher, so a regional player is not a special case.
static func _matching_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	descriptors.append(F.make_descriptor("Core", "LanguageMatches", "Language Matches", ACEDescriptor.ACEType.CONDITION,
		"TranslationServer.compare_locales(TranslationServer.get_locale(), {locale}) > 0", "",
		[F.make_param("locale", "String", "\"ja\"", "Language", "A locale code: \"ja\", \"pt\", or a full \"pt_BR\" when the region matters.", "expression")],
		CAT, "language matches [b]{locale}[/b]")
		.described("True when the game is running in that language, region or not - \"en\" matches a player on en_US and on en_GB, which is what a content branch almost always wants. Comparing Current Language to a string by hand is right for \"en\" exactly and wrong for every regional player.").featured())

	descriptors.append(F.make_descriptor("Core", "RegionIs", "Region Is", ACEDescriptor.ACEType.CONDITION,
		"(str({country}) == str({country}).to_upper() and Array(TranslationServer.get_locale().split(\"_\")).slice(1).has({country}))", "",
		[F.make_param("country", "String", "\"BR\"", "Region", "A country code in capitals: \"BR\", \"DE\", \"US\".", "expression")],
		CAT, "region is [b]{country}[/b]")
		.described("True when the active locale names that country - pt_BR is region BR, plain pt is no region at all and answers false. It looks at every subtag after the language rather than only the last one, so sr_Latn_RS reads RS and a locale carrying a variant (ca_ES_valencia) still reads ES; and a country code is capitals, so a script subtag like the Hans in zh_Hans can never be mistaken for one. For a region-gated screen (an imprint page, an age gate, a storefront link) rather than a translation."))

	descriptors.append(F.make_descriptor("Core", "ValueForLanguage", "Value For Language", ACEDescriptor.ACEType.EXPRESSION,
		"{choices}.get({choices}.keys().reduce(func(__best, __key): return __key if TranslationServer.compare_locales(TranslationServer.get_locale(), str(__key)) > TranslationServer.compare_locales(TranslationServer.get_locale(), str(__best)) else __best, \"\"), {fallback})", "",
		[
			F.make_param("choices", "Dictionary", "{\"ja\": 0, \"pt\": 1}", "Choices", "A record keyed by locale code: {\"ja\": JP_SPLASH, \"zh\": CN_SPLASH}. Values can be anything - a texture, a folder, a number.", "expression"),
			F.make_param("fallback", "Variant", "null", "Otherwise", "What to use when no entry is close enough to the player's language.", "expression"),
		], CAT, "value for the language from [b]{choices}[/b]")
		.described("Picks the entry whose language BEST matches the player's, not the one that matches exactly - so a pt_BR player gets the \"pt\" entry and a zh_Hans player gets \"zh\". One row for a splash image, a voice folder, a name order, a currency shape or a regional variant. An entry that scores nothing leaves the fallback standing, so an unlisted language is never a wrong pick."))

	descriptors.append(F.make_descriptor("Core", "CurrentLanguageName", "Current Language Name", ACEDescriptor.ACEType.EXPRESSION,
		"TranslationServer.get_locale_name(TranslationServer.get_locale())", "", [],
		CAT, "current language name")
		.described("The language the game is running in, written out in ENGLISH - \"Russian\", or \"Portuguese, Brazil\" when the locale carries a region. For the name its own speakers would recognise, use Language Name In Its Own Language."))

	descriptors.append(F.make_descriptor("Core", "CountryName", "Country Name", ACEDescriptor.ACEType.EXPRESSION,
		"TranslationServer.get_country_name({country})", "",
		[F.make_param("country", "String", "\"DE\"", "Region", "A country code in capitals, e.g. \"DE\" or \"BR\".", "expression")],
		CAT, "name of country [b]{country}[/b]")
		.described("Turns a country code into its readable name in English - \"DE\" reads \"Germany\". Pair it with Region Is when a screen has to name the region it is showing."))

	return descriptors


# -- Text that follows the switch, with no scene reload --


## The half of a language switch Godot does NOT do for you: re-applying text an event wrote.
static func _following_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	descriptors.append(F.make_descriptor("Core", "SetTextFollowsLanguage", "Set Text (follows language)", ACEDescriptor.ACEType.ACTION,
		"set_meta(%s, {key})\nadd_to_group(%s, true)\ntext = tr({key})" % [FOLLOWS_META, FOLLOWS_GROUP], "",
		[F.make_param("key", "String", "\"MENU_TITLE\"", "Key", "The source string or key. It is remembered ON this node, so a language switch can re-apply it.", "expression")],
		CAT, "set text to [b]{key}[/b], following the language", "Label")
		.described("Sets the text AND remembers which key it came from, so one Refresh row re-applies it when the language switches. Godot only re-renders text a Control still HOLDS as its source string; the moment a sheet looks a key up and assigns the result, that node stops following - this is the fix. The key is kept in the node's \"follows_language_key\" meta and the node joins the \"follows_language\" group. Plain keys only: for a sentence with values in it use Set Text (translated pattern) and re-run it from a function."))

	descriptors.append(F.make_descriptor("Core", "RefreshFollowingText", "Refresh Text That Follows Language", ACEDescriptor.ACEType.ACTION,
		"for __text_{uid}: Node in get_tree().get_nodes_in_group(%s):\n\tif is_instance_valid(__text_{uid}) and __text_{uid}.has_meta(%s):\n\t\t__text_{uid}.text = tr(str(__text_{uid}.get_meta(%s)))" % [FOLLOWS_GROUP, FOLLOWS_META, FOLLOWS_META], "", [],
		CAT, "refresh text that follows the language")
		.described("Re-applies every remembered key in the current language. One row under On Language Changed and every label written by Set Text (follows language) switches in place - no scene reload, no per-label wiring. Nodes are found through the \"follows_language\" group, so a node you tagged yourself is refreshed too."))

	descriptors.append(F.make_descriptor("Core", "KeepTextUntranslated", "Keep This Text Untranslated", ACEDescriptor.ACEType.ACTION,
		"auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED", "", [],
		CAT, "keep this text untranslated", "Control")
		.described("Stops Godot auto-translating this Control and everything under it - for text that is DATA, not writing: a player's name, chat, a save-slot label, a mod's item name, a debug overlay. Without it a save named \"Play\" turns into \"Jouer\" the moment a catalog happens to contain that word."))

	return descriptors


# -- Plurals that finish the sentence --


## tr_n picks the form; these put the number INTO it, which is the step Translate Plural stops short of.
static func _counted_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	descriptors.append(F.make_descriptor("Core", "CountedText", "Counted Text", ACEDescriptor.ACEType.EXPRESSION,
		_PLURAL_FORM + _FILL_COUNT, "",
		[
			_singular_param("\"%d apple\"", "The one-item form, with %d where the number goes. This exact string is the catalog key."),
			_plural_param("\"%d apples\"", "The many-items form."),
			_count_param("How many - picks the form AND fills the number in."),
		], CAT, "[b]{count}[/b] as counted text")
		.described("Picks the form the player's language uses for this count AND fills the number into it, so \"%d apple\" / \"%d apples\" reads \"3 apples\". Translate Plural stops one step short: it returns the chosen form with the %d still in it, which is why a label built from it reads \"%d apples\". A gettext (.po) catalog carrying three Russian forms uses all three; a CSV catalog holds the two forms as two ordinary rows and the count picks between them, which is as far as that file format can go. Both forms must keep their %d - a translation that drops it comes back unfilled, and nothing errors.").featured())

	descriptors.append(F.make_descriptor("Core", "CountedTextFromPattern", "Counted Text From Pattern", ACEDescriptor.ACEType.EXPRESSION,
		_PLURAL_FORM + ".format({values})", "",
		[
			_singular_param("\"{n} chapter left\"", "The one-item sentence, with {name} slots. Slots and all, it is the catalog key."),
			_plural_param("\"{n} chapters left\"", "The many-items sentence."),
			_count_param("How many - picks which sentence the language uses."),
			F.make_param("values", "String", "{\"n\": 1}", "Values", "What fills the slots: {\"n\": left, \"total\": total}.", "expression"),
		], CAT, "counted text from [b]{singular}[/b]")
		.described("The plural twin of Translated Text From Pattern: the language picks the form FIRST, then the slots fill. Use it when the sentence carries more than the count, so a translator can move {n} and {total} where their grammar wants them."))

	descriptors.append(F.make_descriptor("Core", "SetTextCounted", "Set Text (counted)", ACEDescriptor.ACEType.ACTION,
		"text = " + _PLURAL_FORM + _FILL_COUNT, "",
		[
			_singular_param("\"%d apple\"", "The one-item form, with %d where the number goes. This exact string is the catalog key."),
			_plural_param("\"%d apples\"", "The many-items form."),
			_count_param("How many - picks the form AND fills the number in."),
		], CAT, "set text to [b]{singular}[/b] / [b]{plural}[/b] for [b]{count}[/b]", "Label")
		.described("Sets this Label to the counted sentence in one row: the language picks the form and the number is filled in. The same action as Counted Text without an expression to nest, down to keeping both forms' %d - a form that lost its %d comes back unfilled rather than erroring. Re-run it under On Language Changed so the line follows a live switch."))

	return descriptors


# -- Nothing falls back silently --


## A missing key is what a PLAYER reads, because tr() hands the key back unchanged.
static func _missing_key_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	descriptors.append(F.make_descriptor("Core", "TextIsTranslated", "Text Is Translated", ACEDescriptor.ACEType.CONDITION,
		"tr({key}) != {key}", "",
		[F.make_param("key", "String", "\"MENU_TITLE\"", "Key", "The source string or key to look for.", "expression")],
		CAT, "[b]{key}[/b] is translated")
		.described("True when the active language has text for this key. A key with no entry comes back unchanged from tr(), which is exactly what a player then sees on screen - this is the row that catches it first. Note that a translation IDENTICAL to the source reads as untranslated; use Language Has Text For when that matters."))

	descriptors.append(F.make_descriptor("Core", "LanguageHasTextFor", "Language Has Text For", ACEDescriptor.ACEType.CONDITION,
		"(%s and not str(TranslationServer.get_translation_object({locale}).get_message({key})).is_empty())" % _EXACT_CATALOG, "",
		[
			F.make_param("locale", "String", "\"ja\"", "Language", "The locale code to ask.", "expression"),
			F.make_param("key", "String", "\"MENU_TITLE\"", "Key", "The source string or key.", "expression"),
		], CAT, "[b]{locale}[/b] has text for [b]{key}[/b]")
		.described("Asks one language's catalog directly, without switching to it - the exact check, so a translation identical to its source still counts. Exact in the OTHER sense too: it answers about the catalog for that very locale, so a build shipping pt_BR answers false for \"pt_PT\" rather than handing back Brazilian text. A language with no catalog of its own answers false. Use it to offer a language only when the screen the player is about to see is actually translated."))

	descriptors.append(F.make_descriptor("Core", "TranslatedTextOrFallback", "Translated Text Or Fallback", ACEDescriptor.ACEType.EXPRESSION,
		"(tr({key}) if tr({key}) != {key} else {fallback})", "",
		[
			F.make_param("key", "String", "\"TUTORIAL_HINT\"", "Key", "The key to look up first.", "expression"),
			F.make_param("fallback", "String", "tr(\"HINT_GENERIC\")", "Otherwise", "What to show when the key is missing - another translated key, a plain English line, or \"\" to show nothing.", "expression"),
		], CAT, "[b]{key}[/b], or [b]{fallback}[/b]")
		.described("Looks the key up and falls back when the active language has no entry, so a half-finished catalog never shows a raw key to a player. Chain them by putting another Translated Text Or Fallback in the Otherwise field."))

	descriptors.append(F.make_descriptor("Core", "TestWithFakeTranslation", "Test With Fake Translation", ACEDescriptor.ACEType.ACTION,
		"TranslationServer.set_pseudolocalization_enabled({on})", "",
		[F.make_param("on", "bool", "true", "On", "Turn the test mode on or off.", "expression")],
		CAT, "test with fake translation: [b]{on}[/b]")
		.described("Turns Godot's pseudolocalization on: every translatable string comes back accented and bracketed (\"Ready\" reads \"[Ready]\" with accents on every letter), so text that stays PLAIN is text you never marked. Length expansion is a separate Project Settings knob under Internationalization > Pseudolocalization - turn it up and a layout that overflows here will overflow in German. Gate it on a debug build."))

	return descriptors


# -- Gendered lines and a player-named hero --


## The two shipped halves - a context lookup, and a pattern with slots - finally in one row each.
static func _sentence_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	descriptors.append(F.make_descriptor("Core", "TranslatedTextFromPatternInContext", "Translated Text From Pattern In Context", ACEDescriptor.ACEType.EXPRESSION,
		"tr({pattern}, {context}).format({values})", "",
		[
			F.make_param("pattern", "String", "\"{name} is ready.\"", "Pattern", "The source sentence, with {name} slots. This exact string, slots and all, is the translation key that goes in the catalog.", "expression"),
			F.make_param("context", "String", "\"f\"", "Context", "Which variant to look up - \"f\" / \"m\" / \"n\" for a speaker's gender, \"formal\" / \"casual\" for register. It is an expression, so a variable works.", "expression"),
			F.make_param("values", "String", "{\"name\": \"Ilsa\"}", "Values", "What fills the slots: {\"name\": value, ...} - e.g. {\"name\": hero_name}.", "expression"),
		], CAT, "translated [b]{pattern}[/b] as [b]{context}[/b]")
		.described("The two shipped halves in one row: the whole sentence is looked up in the current language WITH a context, then its {slots} fill. One key can hold a masculine, feminine and neutral translation, and the context can be read from a variable at runtime. A context with no entry falls back to the source sentence, so an unwritten variant still reads."))

	descriptors.append(F.make_descriptor("Core", "TranslatedTextWithWords", "Translated Text With Words", ACEDescriptor.ACEType.EXPRESSION,
		"tr({pattern}).format({words}.merged({values}, true))", "",
		[
			F.make_param("pattern", "String", "\"{name} drew {their} sword.\"", "Pattern", "The source sentence with {name} slots. This exact string, slots and all, is the translation key.", "expression"),
			F.make_param("words", "String", "{\"they\": \"she\", \"them\": \"her\", \"their\": \"her\"}", "Standing words", "A dictionary of words that stay the same all game - a character's pronouns, their title, their home town. Usually a sheet variable.", "expression"),
			F.make_param("values", "String", "{\"name\": \"Ilsa\"}", "This line's values", "What this line adds, e.g. {\"name\": hero_name}. Same-named entries win over the standing words.", "expression"),
		], CAT, "translated [b]{pattern}[/b] with the character's words")
		.described("Fills a translated sentence from a standing word set plus this line's values, so a player-named, player-gendered character reads correctly everywhere without an if-chain per line. Keep the word set in one variable and every line follows a change to it. The translator receives one key with {name} and {they} slots and decides where they land in their own grammar."))

	return descriptors


# -- Numbers the locale can actually read --


## The locale-aware neighbours of the English-by-construction formatters in the Text vocabulary.
static func _number_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	descriptors.append(F.make_descriptor("Core", "NumberInLocalDigits", "Number In Local Digits", ACEDescriptor.ACEType.EXPRESSION,
		"TranslationServer.format_number(str({value}), {locale})", "",
		[
			F.make_param("value", "String", "1234", "Value", "The number to write out.", "expression"),
			_in_language_param("Which language's digits. Leave it as the active language."),
		], CAT, "[b]{value}[/b] in local digits")
		.described("Writes a number in the digits the language uses, so an Arabic player reads Arabic-Indic numerals and an English one reads 1234. Digits ONLY - it does not group thousands (that is With Thousands Separators, which is comma-only). A language Godot has no digit set for comes back unchanged, which is most of them, so this is safe to leave on everywhere."))

	descriptors.append(F.make_descriptor("Core", "NumberFromLocalDigits", "Number From Local Digits", ACEDescriptor.ACEType.EXPRESSION,
		"TranslationServer.parse_number({text}, {locale})", "",
		[
			F.make_param("text", "String", "\"\"", "Text", "What the player typed - a field's text.", "expression"),
			_in_language_param("Which language's digits it is written in."),
		], CAT, "[b]{text}[/b] from local digits")
		.described("Turns digits the player typed in their own numeral system back into plain ASCII ones you can put through Whole Number From Text - the return trip for Number In Local Digits, so a quantity field works for every player."))

	descriptors.append(F.make_descriptor("Core", "PercentSign", "Percent Sign", ACEDescriptor.ACEType.EXPRESSION,
		"TranslationServer.get_percent_sign({locale})", "",
		[_in_language_param("Which language's percent sign. Leave it as the active language.")],
		CAT, "percent sign")
		.described("The percent sign the language writes - Arabic and Persian use their own. Pair it with Number In Local Digits instead of typing \"%\" into a label."))

	descriptors.append(F.make_descriptor("Core", "DateParts", "Date Parts", ACEDescriptor.ACEType.EXPRESSION,
		"Time.get_datetime_dict_from_unix_time(int({unix}))", "",
		[F.make_param("unix", "String", "Time.get_unix_time_from_system()", "Unix time", "A timestamp in seconds, e.g. the shipped Unix Time expression or one you saved.", "expression")],
		CAT, "date parts of [b]{unix}[/b]")
		.described("A date broken into {year}, {month}, {day}, {hour}, {minute}, {second} and {weekday}, ready to fill a translated pattern - so DATE_FORMAT reads \"{month}/{day}/{year}\" in English and \"{day}.{month}.{year}\" in German, and a translator fixes the order without a build. Drop it into the Values field of Set Text (translated pattern). The parts are UTC, the same clock Unix Time reads."))

	return descriptors


## The one-item form of a counted sentence, which is also its catalog key.
static func _singular_param(default_value: String, description: String) -> ACEParam:
	return F.make_param("singular", "String", default_value, "Singular", description, "expression")


## The many-items form. The language may never use it (Japanese) or use it for two of three
## forms (Russian) - the catalog's rules decide, not this parameter.
static func _plural_param(default_value: String, description: String) -> ACEParam:
	return F.make_param("plural", "String", default_value, "Plural", description, "expression")


## How many there are: the number that both picks the form and, for the %d verbs, fills it.
static func _count_param(description: String) -> ACEParam:
	return F.make_param("count", "String", "1", "Count", description, "expression")


## Which language's numerals a number verb reads or writes. Defaults to the active one, so the
## row is correct with nothing typed and still lets a preview screen name another language.
static func _in_language_param(description: String) -> ACEParam:
	return F.make_param("locale", "String", "TranslationServer.get_locale()", "In language", description, "expression")
