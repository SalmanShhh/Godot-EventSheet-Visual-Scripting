# Godot EventSheets - the runtime half of shipping a game in more than one language.
#
# Twenty-five Translation verbs, and for each one this test asks the same two questions:
#   1. WHAT DOES IT EMIT? The pin is taken from the SHIPPED descriptor (ACERegistry), not the
#      authored one, so the three node-scoped rows are asserted in their post-transform form -
#      builtin_aces.gd prefixes every line with {target.} and appends the "On node" param, and a
#      test written against the authored string would pin a template nobody ships.
#   2. DOES IT DO WHAT THE ROW PROMISES? The emitted line is compiled into a throwaway script and
#      RUN against real catalogs registered here, so the value a player would see is the value
#      asserted. Each verb is pushed at the case it exists for: a plural language that is not
#      English, a locale with no catalog, a key nobody translated, a save name that must not be
#      looked up, a text write that goes stale the moment the language switches.
#
# Two deliberate compromises, both stated rather than hidden:
#   - run_tests.gd runs inside SceneTree._init, where Engine.get_main_loop() is still null, so there
#     is no live tree: SceneTree.new() builds one whose root never enters the tree, which means
#     get_nodes_in_group() answers nothing. Refresh Text That Follows Language is therefore run on a
#     RefCounted host that supplies its own get_tree(), returning the nodes that really are in the
#     "follows_language" group. Every other line of that template runs verbatim, and the group query
#     itself is pinned in the emission check.
#   - Nothing here can prove Godot re-renders an auto-translating Control, because rendering needs a
#     tree and a font. What IS proved is the half that matters to the verbs: atr() - the function a
#     Control renders through - answers differently before and after Keep This Text Untranslated,
#     and a text an event assigned does NOT change when the language does.
#
# The TranslationServer is process-global session state shared with every other test, so the entry
# locale, the pseudolocalization flag and the catalog list are captured on the way in and put back
# on the way out.
@tool
class_name TranslationRuntimeWordsTest
extends RefCounted


## Stands in for the SceneTree the emitted Refresh row asks for. It answers the group query for
## real - a node only comes back if it actually joined the group - so the pairing between
## Set Text (follows language) and the refresh loop is what is under test, not a hand-fed list.
class GroupTree:
	extends RefCounted

	var members: Array[Node] = []

	func get_nodes_in_group(group: StringName) -> Array:
		var found: Array = []
		for node: Node in members:
			if node.is_in_group(group):
				found.append(node)
		return found


static func run() -> bool:
	var entry_locale: String = TranslationServer.get_locale()
	var entry_pseudo: bool = TranslationServer.is_pseudolocalization_enabled()
	var catalogs: Array[Translation] = _register_catalogs()

	var passed: bool = true
	passed = _test_language_menu() and passed
	passed = _test_matching() and passed
	passed = _test_following_the_switch() and passed
	passed = _test_counted() and passed
	passed = _test_missing_keys() and passed
	passed = _test_sentences() and passed
	passed = _test_numbers() and passed

	for catalog: Translation in catalogs:
		TranslationServer.remove_translation(catalog)
	TranslationServer.set_pseudolocalization_enabled(entry_pseudo)
	TranslationServer.set_locale(entry_locale)
	return passed


# -- 1. The language menu that builds itself --


static func _test_language_menu() -> bool:
	var passed: bool = true

	# For Each Language is a LOOPING condition: its template returns the collection, and applying it
	# lands a pick filter whose iterator is named `language` (the name the row's sub-events read).
	var for_each: ACEDescriptor = _shipped("ForEachLanguage")
	passed = _check("For Each Language walks the loaded catalogs",
		for_each.codegen_template, "TranslationServer.get_loaded_locales()") and passed
	passed = _check("For Each Language is a looping condition", for_each.is_looping, true) and passed
	passed = _check("For Each Language names its iterator `language`", for_each.looping_iterator, "language") and passed

	# RUN: the catalogs registered here are exactly what the menu offers, and a language with no
	# catalog is not in the list - the reason a demo build shows fewer entries with no sheet edit.
	var listed: Variant = _value_of(for_each.codegen_template)
	var listed_array: Array = Array(listed as PackedStringArray)
	passed = _check("the menu lists a language that shipped", listed_array.has("de"), true) and passed
	passed = _check("the menu lists another language that shipped", listed_array.has("ja"), true) and passed
	passed = _check("the menu does not list a language with no catalog", listed_array.has("xx"), false) and passed

	# ADDING a language changes the menu with no sheet edit: the same emitted line, one catalog later.
	var late: Translation = Translation.new()
	late.locale = "it"
	late.add_message(&"MENU_TITLE", &"Menu principale")
	TranslationServer.add_translation(late)
	var relisted: Array = Array(_value_of(for_each.codegen_template) as PackedStringArray)
	passed = _check("a language added later joins the menu with no sheet edit", relisted.has("it"), true) and passed
	TranslationServer.remove_translation(late)

	# Language Name In Its Own Language: the catalog's own LANGUAGE_NAME row wins.
	var own_de: String = _emit_expression("LanguageOwnName", {"locale": "\"de\""})
	passed = _check("Language Name In Its Own Language guards the lookup before it reads it",
		own_de,
		"(str(TranslationServer.get_translation_object(\"de\").get_message(&\"LANGUAGE_NAME\")) if TranslationServer.has_translation_for_locale(\"de\", true) and not str(TranslationServer.get_translation_object(\"de\").get_message(&\"LANGUAGE_NAME\")).is_empty() else TranslationServer.get_locale_name(\"de\"))") and passed
	passed = _check("a catalog with a LANGUAGE_NAME row reads in its own language",
		str(_value_of(own_de)), "Deutsch") and passed
	# EDGE: the ja catalog deliberately has no LANGUAGE_NAME row, so Godot's English name stands in.
	passed = _check("a catalog without LANGUAGE_NAME falls back to the engine's name",
		str(_value_of(_emit_expression("LanguageOwnName", {"locale": "\"ja\""}))), "Japanese") and passed
	# EDGE: a language with no catalog at all must not null-deref - it reads back as the bare code.
	passed = _check("a language with no catalog is never blank",
		str(_value_of(_emit_expression("LanguageOwnName", {"locale": "\"xx\""}))), "xx") and passed

	# Language Is Available.
	var available: String = _emit_condition("LanguageIsAvailable", {"locale": "\"ru\""})
	passed = _check("Language Is Available asks the engine, loosely",
		available, "TranslationServer.has_translation_for_locale(\"ru\", false)") and passed
	passed = _check("a language that shipped is available", _value_of(available), true) and passed
	passed = _check("a language that did not ship is not available",
		_value_of(_emit_condition("LanguageIsAvailable", {"locale": "\"xx\""})), false) and passed
	# EDGE: loose matching is the point - a build that ships pt_BR answers true for plain "pt".
	var pt_br: Translation = Translation.new()
	pt_br.locale = "pt_BR"
	pt_br.add_message(&"MENU_TITLE", &"Menu principal")
	TranslationServer.add_translation(pt_br)
	passed = _check("a regional catalog answers for its bare language",
		_value_of(_emit_condition("LanguageIsAvailable", {"locale": "\"pt\""})), true) and passed
	# ...and the EXACT question is the one that must not be loose. A build shipping only Brazilian
	# Portuguese answering "yes, pt_PT is translated" is how a menu offers European Portuguese and
	# serves Brazilian strings; Godot's own get_translation_object fuzzy-matches and would.
	passed = _check("Godot's catalog lookup itself is loose enough to hand pt_BR back for pt_PT",
		_value_of("TranslationServer.get_translation_object(\"pt_PT\") != null"), true) and passed
	passed = _check("but Language Has Text For answers about that exact catalog",
		_value_of(_emit_condition("LanguageHasTextFor", {"locale": "\"pt_PT\"", "key": "\"MENU_TITLE\""})), false) and passed
	passed = _check("...and says yes for the catalog that really shipped",
		_value_of(_emit_condition("LanguageHasTextFor", {"locale": "\"pt_BR\"", "key": "\"MENU_TITLE\""})), true) and passed
	# The same exactness on the name a menu entry shows: pt_PT must not be labelled from pt_BR's row.
	pt_br.add_message(&"LANGUAGE_NAME", &"Portugues do Brasil")
	passed = _check("a variant with no catalog of its own is not named from another's catalog",
		str(_value_of(_emit_expression("LanguageOwnName", {"locale": "\"pt_PT\""}))), "Portuguese, Portugal") and passed
	passed = _check("...while the catalog that shipped still reads in its own words",
		str(_value_of(_emit_expression("LanguageOwnName", {"locale": "\"pt_BR\""}))), "Portugues do Brasil") and passed
	TranslationServer.remove_translation(pt_br)

	passed = _test_use_saved_language() and passed
	return passed


## Use Saved Language reads the same file the shipped Save Setting action writes, so the proof has
## to go through that real file. Any settings file already on disk is put back afterwards.
static func _test_use_saved_language() -> bool:
	var passed: bool = true
	var path: String = "user://settings.cfg"
	var backup: PackedByteArray = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()
	var had_file: bool = FileAccess.file_exists(path)

	var emitted: String = _emit_action("UseSavedLanguage", {"fallback": "\"de\"", "uid": "7"})
	passed = _check("Use Saved Language reads the settings file Save Setting writes",
		emitted,
		"var __lang_cfg_7 = ConfigFile.new()\n__lang_cfg_7.load(\"user://settings.cfg\")\nTranslationServer.set_locale(str(__lang_cfg_7.get_value(\"game\", \"language\", \"de\")))") and passed

	# A saved choice wins.
	var saved: ConfigFile = ConfigFile.new()
	saved.set_value("game", "language", "ja")
	saved.save(path)
	TranslationServer.set_locale("en")
	_perform(emitted)
	passed = _check("the saved language is applied at boot", TranslationServer.get_locale(), "ja") and passed

	# EDGE: a first run has no file at all, and must land on the fallback rather than an empty locale.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	TranslationServer.set_locale("en")
	_perform(emitted)
	passed = _check("a first run falls back instead of blanking the language",
		TranslationServer.get_locale(), "de") and passed

	if had_file:
		var restore: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		if restore != null:
			restore.store_buffer(backup)
			restore.close()
	return passed


# -- 2. Match a language, never compare it --


static func _test_matching() -> bool:
	var passed: bool = true

	var matches: String = _emit_condition("LanguageMatches", {"locale": "\"en\""})
	passed = _check("Language Matches scores the locale pair the way Godot does",
		matches, "TranslationServer.compare_locales(TranslationServer.get_locale(), \"en\") > 0") and passed
	# EDGE: the whole reason this exists - a regional player. "en" must match en_GB, where a string
	# comparison against Current Language answers false and the branch silently never runs.
	TranslationServer.set_locale("en_GB")
	passed = _check("a regional player still matches the bare language", _value_of(matches), true) and passed
	passed = _check("Current Language would NOT have matched by hand",
		_value_of("TranslationServer.get_locale() == \"en\""), false) and passed
	TranslationServer.set_locale("ja")
	passed = _check("a different language does not match", _value_of(matches), false) and passed

	var region: String = _emit_condition("RegionIs", {"country": "\"BR\""})
	passed = _check("Region Is reads the subtags after the language, and a country code is capitals",
		region, "(str(\"BR\") == str(\"BR\").to_upper() and Array(TranslationServer.get_locale().split(\"_\")).slice(1).has(\"BR\"))") and passed
	TranslationServer.set_locale("pt_BR")
	passed = _check("pt_BR is region BR", _value_of(region), true) and passed
	# EDGE: a locale with no region must answer false, not crash on a missing subtag.
	TranslationServer.set_locale("pt")
	passed = _check("plain pt has no region at all", _value_of(region), false) and passed
	# EDGE: a scripted locale carries three subtags and the country is the LAST one here.
	TranslationServer.set_locale("sr_Latn_RS")
	passed = _check("a scripted locale still reads its country",
		_value_of(_emit_condition("RegionIs", {"country": "\"RS\""})), true) and passed
	# EDGE: a locale whose country is NOT last. Reading only the last subtag answered "valencia" here
	# and silently hid a region-gated screen (an imprint page, an age gate) from every such player.
	TranslationServer.set_locale("ca_ES_valencia")
	passed = _check("the region of the locale is read, not merely its last subtag",
		_value_of(_emit_condition("RegionIs", {"country": "\"ES\""})), true) and passed
	# EDGE: a SCRIPT subtag is not a country. zh_Hans names no region at all, and must not answer true
	# for one - neither for a real country code nor for the script that happens to sit in that slot.
	TranslationServer.set_locale("zh_Hans")
	passed = _check("a script-only locale has no region", _value_of(_emit_condition("RegionIs", {"country": "\"CN\""})), false) and passed
	passed = _check("...and its script subtag is not mistaken for one",
		_value_of(_emit_condition("RegionIs", {"country": "\"Hans\""})), false) and passed

	var choices: String = "{\"ja\": \"JP\", \"pt\": \"PT\"}"
	var value_for: String = _emit_expression("ValueForLanguage", {"choices": choices, "fallback": "\"EN\""})
	passed = _check("Value For Language folds the record down to the best-scoring key",
		value_for,
		"%s.get(%s.keys().reduce(func(__best, __key): return __key if TranslationServer.compare_locales(TranslationServer.get_locale(), str(__key)) > TranslationServer.compare_locales(TranslationServer.get_locale(), str(__best)) else __best, \"\"), \"EN\")" % [choices, choices]) and passed
	TranslationServer.set_locale("ja")
	passed = _check("an exact language picks its own entry", str(_value_of(value_for)), "JP") and passed
	# EDGE: the case a plain Dictionary lookup gets wrong - pt_BR has no entry of its own and must
	# still land on "pt" rather than falling through to the default.
	TranslationServer.set_locale("pt_BR")
	passed = _check("a regional player gets the nearest entry, not the fallback",
		str(_value_of(value_for)), "PT") and passed
	# EDGE: a language nothing scores against leaves the fallback standing.
	TranslationServer.set_locale("en_GB")
	passed = _check("an unlisted language leaves the fallback standing",
		str(_value_of(value_for)), "EN") and passed

	TranslationServer.set_locale("pt_BR")
	var current_name: String = _emit_expression("CurrentLanguageName", {})
	passed = _check("Current Language Name asks the engine for the active locale",
		current_name, "TranslationServer.get_locale_name(TranslationServer.get_locale())") and passed
	passed = _check("the active language reads out in English, region and all",
		str(_value_of(current_name)), "Portuguese, Brazil") and passed

	var country: String = _emit_expression("CountryName", {"country": "\"DE\""})
	passed = _check("Country Name takes a country code", country, "TranslationServer.get_country_name(\"DE\")") and passed
	passed = _check("a country code reads out as its name", str(_value_of(country)), "Germany") and passed
	return passed


# -- 3. Text that follows the switch --


static func _test_following_the_switch() -> bool:
	var passed: bool = true

	# The SHIPPED template is the node-scoped one: every line prefixed with {target.} and an
	# "On node" param appended, so one row can retarget to any Label.
	var set_text: String = _emit_action("SetTextFollowsLanguage", {"key": "\"MENU_TITLE\"", "target": ""})
	passed = _check("Set Text (follows language) remembers the key on the node it wrote to",
		set_text,
		"set_meta(&\"follows_language_key\", \"MENU_TITLE\")\nadd_to_group(&\"follows_language\", true)\ntext = tr(\"MENU_TITLE\")") and passed
	passed = _check("a chosen target retargets the whole row",
		_emit_action("SetTextFollowsLanguage", {"key": "\"MENU_TITLE\"", "target": "$Title"}),
		"$Title.set_meta(&\"follows_language_key\", \"MENU_TITLE\")\n$Title.add_to_group(&\"follows_language\", true)\n$Title.text = tr(\"MENU_TITLE\")") and passed

	TranslationServer.set_locale("de")
	var title: Label = _perform_on(set_text, "Label") as Label
	passed = _check("the row sets the text in the current language", title.text, "Hauptmenue") and passed
	passed = _check("the row remembers the key", str(title.get_meta(&"follows_language_key")), "MENU_TITLE") and passed
	passed = _check("the row joins the refresh group", title.is_in_group(&"follows_language"), true) and passed

	# THE BUG THIS EXISTS FOR: a text an event assigned is a plain string from then on. Switching the
	# language leaves it in the old one, and auto-translation cannot rescue it either - the node no
	# longer holds the key, it holds last language's words.
	TranslationServer.set_locale("ja")
	passed = _check("text an event wrote does NOT follow a language switch", title.text, "Hauptmenue") and passed
	passed = _check("auto-translation cannot rescue it either", title.atr(title.text), "Hauptmenue") and passed

	# The refresh row: one line, every remembered key re-applied.
	var refresh: String = _emit_action("RefreshFollowingText", {"uid": "3"})
	passed = _check("Refresh Text That Follows Language walks the group and re-applies the meta",
		refresh,
		"for __text_3: Node in get_tree().get_nodes_in_group(&\"follows_language\"):\n\tif is_instance_valid(__text_3) and __text_3.has_meta(&\"follows_language_key\"):\n\t\t__text_3.text = tr(str(__text_3.get_meta(&\"follows_language_key\")))") and passed

	var untouched: Label = Label.new()
	untouched.text = "Hauptmenue"
	var tree: GroupTree = GroupTree.new()
	tree.members = [title, untouched]
	_perform_with_tree(refresh, tree)
	passed = _check("the remembered key comes back in the new language", title.text, "Menu-JA") and passed
	# EDGE: only nodes that joined the group are touched - a label the sheet never marked is left alone.
	passed = _check("a label that never joined the group is left alone", untouched.text, "Hauptmenue") and passed
	title.free()
	untouched.free()

	# Keep This Text Untranslated: for text that is DATA.
	var keep: String = _emit_action("KeepTextUntranslated", {"target": ""})
	passed = _check("Keep This Text Untranslated turns the Control's auto-translation off",
		keep, "auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED") and passed
	TranslationServer.set_locale("de")
	var save_slot: Label = _perform_on(keep, "Label") as Label
	save_slot.text = "MENU_TITLE"
	passed = _check("the mode is the disabled one", save_slot.auto_translate_mode, Node.AUTO_TRANSLATE_MODE_DISABLED) and passed
	# EDGE: the save named after a word the catalog happens to contain. Without the row it becomes
	# the German title; with it, the player's own text survives.
	passed = _check("a player-typed name is no longer looked up", save_slot.atr(save_slot.text), "MENU_TITLE") and passed
	var unprotected: Label = Label.new()
	unprotected.text = "MENU_TITLE"
	passed = _check("without the row the same text WOULD be translated",
		unprotected.atr(unprotected.text), "Hauptmenue") and passed
	save_slot.free()
	unprotected.free()
	return passed


# -- 4. Plurals that finish the sentence --


static func _test_counted() -> bool:
	var passed: bool = true

	var counted: String = _emit_expression("CountedText", {"singular": "\"%d apple\"", "plural": "\"%d apples\"", "count": "3"})
	passed = _check("Counted Text picks the form and fills the count into it",
		counted, "((tr(\"%d apple\") if int(3) == 1 else tr(\"%d apples\")) if tr(\"%d apples\") != \"%d apples\" else tr_n(\"%d apple\", \"%d apples\", int(3))).replace(\"%d\", str(int(3)))") and passed

	# The shipped Translate Plural stops one step short: this is the difference, in one language.
	TranslationServer.set_locale("en")
	passed = _check("Translate Plural leaves the %d standing",
		str(_value_of(_emit_expression("TranslatePlural", {"singular": "\"%d apple\"", "plural": "\"%d apples\"", "count": "3"}))),
		"%d apples") and passed
	passed = _check("Counted Text finishes the sentence", str(_value_of(counted)), "3 apples") and passed

	# EDGE: a language whose plural rules are not English's. Russian has THREE forms, and the row
	# has to reach all three without a single sheet edit, because the catalog's rules decide.
	TranslationServer.set_locale("ru")
	passed = _check("Russian rules are the three-form ones",
		TranslationServer.get_plural_rules("ru"),
		"nplurals=3; plural=(n%10==1 && n%100!=11 ? 0 : n%10>=2 && n%10<=4 && (n%100<10 || n%100>=20) ? 1 : 2);") and passed
	passed = _check("Russian one", str(_value_of(_counted_for(1))), "1 yabloko") and passed
	passed = _check("Russian few", str(_value_of(_counted_for(3))), "3 yabloka") and passed
	passed = _check("Russian many", str(_value_of(_counted_for(5))), "5 yablok") and passed
	# 21 is the case an if-chain gets wrong: it takes the SINGULAR form in Russian, not the many one.
	passed = _check("Russian twenty-one takes the singular form", str(_value_of(_counted_for(21))), "21 yabloko") and passed
	passed = _check("Russian zero takes the many form", str(_value_of(_counted_for(0))), "0 yablok") and passed

	# Counted Text From Pattern: the plural twin of the shipped pattern verb, slots and all.
	var pattern: String = _emit_expression("CountedTextFromPattern", {
		"singular": "\"{n} chapter left\"", "plural": "\"{n} chapters left\"", "count": "4", "values": "{\"n\": 4}"})
	passed = _check("Counted Text From Pattern looks the sentence up first and fills after",
		pattern, "((tr(\"{n} chapter left\") if int(4) == 1 else tr(\"{n} chapters left\")) if tr(\"{n} chapters left\") != \"{n} chapters left\" else tr_n(\"{n} chapter left\", \"{n} chapters left\", int(4))).format({\"n\": 4})") and passed
	# 4 takes the FEW form in Russian - a third form English does not have at all - so this proves the
	# catalog's own rules picked the sentence, and that the named slot filled AFTER that pick.
	passed = _check("the pattern's plural form fills its named slot",
		str(_value_of(pattern)), "4 glavy ostalos") and passed

	# Set Text (counted): the same job as a Label row, node-scoped like every other text write.
	var set_counted: String = _emit_action("SetTextCounted", {
		"singular": "\"%d apple\"", "plural": "\"%d apples\"", "count": "5", "target": ""})
	passed = _check("Set Text (counted) is the Label twin of Counted Text",
		set_counted, "text = ((tr(\"%d apple\") if int(5) == 1 else tr(\"%d apples\")) if tr(\"%d apples\") != \"%d apples\" else tr_n(\"%d apple\", \"%d apples\", int(5))).replace(\"%d\", str(int(5)))") and passed
	var basket: Label = _perform_on(set_counted, "Label") as Label
	passed = _check("the Label reads the finished counted sentence", basket.text, "5 yablok") and passed
	basket.free()
	passed = _test_counted_on_a_csv_catalog() and passed
	return passed


## THE catalog shape this plugin's own tooling writes, and the one the guide calls the fastest route:
## a CSV, where "%d apple" and "%d apples" are two ORDINARY rows with one form each. Godot takes the
## plural RULE from the locale (Czech has three forms) but the FORMS from the catalog, so asking
## tr_n for a Czech n=2 prints "Plural index returned or number of plural translations is not valid."
## once per call and hands back the untranslated English source. Checked on 4.7, and the reason the
## verb branches: with a CSV catalog the count picks between the two translated rows instead.
static func _test_counted_on_a_csv_catalog() -> bool:
	var passed: bool = true
	var csv: Translation = Translation.new()
	csv.locale = "cs"
	csv.add_message(&"%d apple", &"%d jablko")
	csv.add_message(&"%d apples", &"%d jablka")
	TranslationServer.add_translation(csv)
	TranslationServer.set_locale("cs")
	passed = _check("the language really does want three plural forms",
		TranslationServer.get_plural_rules("cs").begins_with("nplurals=3"), true) and passed
	passed = _check("a CSV catalog holds only one form per row",
		int(csv.messages.get([&"", &"%d apple"], PackedStringArray()).size()), 1) and passed
	passed = _check("one apple reads in Czech", str(_value_of(_counted_for(1))), "1 jablko") and passed
	passed = _check("two apples read in Czech rather than falling back to English",
		str(_value_of(_counted_for(2))), "2 jablka") and passed
	passed = _check("five apples too", str(_value_of(_counted_for(5))), "5 jablka") and passed
	# EDGE: a translator who drops the %d. The sentence must come back UNFILLED, which is what the
	# description promises - `form % count` would instead push a formatting error on every call.
	var dropped: Translation = Translation.new()
	dropped.locale = "sv"
	dropped.add_message(&"%d apple", &"ett apple")
	dropped.add_message(&"%d apples", &"manga applen")
	TranslationServer.add_translation(dropped)
	TranslationServer.set_locale("sv")
	passed = _check("a form that lost its %d comes back unfilled, not errored",
		str(_value_of(_counted_for(4))), "manga applen") and passed
	TranslationServer.remove_translation(dropped)
	TranslationServer.remove_translation(csv)
	TranslationServer.set_locale("ru")
	return passed


## Counted Text for one count, so the plural sweep reads as the five counts it is.
static func _counted_for(count: int) -> String:
	return _emit_expression("CountedText", {"singular": "\"%d apple\"", "plural": "\"%d apples\"", "count": str(count)})


# -- 5. Nothing falls back silently --


static func _test_missing_keys() -> bool:
	var passed: bool = true
	TranslationServer.set_locale("de")

	var is_translated: String = _emit_condition("TextIsTranslated", {"key": "\"MENU_TITLE\""})
	passed = _check("Text Is Translated compares the lookup against the key itself",
		is_translated, "tr(\"MENU_TITLE\") != \"MENU_TITLE\"") and passed
	passed = _check("a key the language has reads as translated", _value_of(is_translated), true) and passed
	# EDGE: the failure nobody sees - tr() hands a missing key straight back, so the KEY is what a
	# player reads on the title screen, and nothing errors, warns or logs.
	passed = _check("a missing key comes back unchanged from tr()",
		str(_value_of("tr(\"NO_SUCH_KEY\")")), "NO_SUCH_KEY") and passed
	passed = _check("and the condition catches it",
		_value_of(_emit_condition("TextIsTranslated", {"key": "\"NO_SUCH_KEY\""})), false) and passed

	var has_text: String = _emit_condition("LanguageHasTextFor", {"locale": "\"ja\"", "key": "\"MENU_TITLE\""})
	passed = _check("Language Has Text For asks one catalog directly, null-safe",
		has_text,
		"(TranslationServer.has_translation_for_locale(\"ja\", true) and not str(TranslationServer.get_translation_object(\"ja\").get_message(\"MENU_TITLE\")).is_empty())") and passed
	passed = _check("another language's catalog answers without switching to it",
		_value_of(has_text), true) and passed
	passed = _check("the active language is still the one we set", TranslationServer.get_locale(), "de") and passed
	passed = _check("a key that language has not filled answers false",
		_value_of(_emit_condition("LanguageHasTextFor", {"locale": "\"ja\"", "key": "\"TUTORIAL_HINT\""})), false) and passed
	# EDGE: a language with no catalog at all - the null the guard exists for.
	passed = _check("a language with no catalog answers false instead of crashing",
		_value_of(_emit_condition("LanguageHasTextFor", {"locale": "\"xx\"", "key": "\"MENU_TITLE\""})), false) and passed

	var or_fallback: String = _emit_expression("TranslatedTextOrFallback", {"key": "\"TUTORIAL_HINT\"", "fallback": "\"Press Space\""})
	passed = _check("Translated Text Or Fallback re-asks the same question it answers",
		or_fallback, "(tr(\"TUTORIAL_HINT\") if tr(\"TUTORIAL_HINT\") != \"TUTORIAL_HINT\" else \"Press Space\")") and passed
	passed = _check("a missing key shows the fallback, never the raw key",
		str(_value_of(or_fallback)), "Press Space") and passed
	passed = _check("a key that IS translated wins over the fallback",
		str(_value_of(_emit_expression("TranslatedTextOrFallback", {"key": "\"MENU_TITLE\"", "fallback": "\"Press Space\""}))),
		"Hauptmenue") and passed

	var fake: String = _emit_action("TestWithFakeTranslation", {"on": "true"})
	passed = _check("Test With Fake Translation flips Godot's pseudolocalization",
		fake, "TranslationServer.set_pseudolocalization_enabled(true)") and passed
	_perform(fake)
	passed = _check("the QA pass is on", TranslationServer.is_pseudolocalization_enabled(), true) and passed
	# EDGE: the point of the pass - a string nobody marked is the one that stays plain ASCII, while
	# everything that goes through tr() comes back accented and bracketed.
	var marked: String = str(_value_of("tr(\"MENU_TITLE\")"))
	passed = _check("a marked string is unmissably fake now", marked != "Hauptmenue", true) and passed
	passed = _check("and it is bracketed", marked.begins_with("[") and marked.ends_with("]"), true) and passed
	passed = _check("a string that never reaches tr() stays plain",
		str(_value_of("\"Ready\"")), "Ready") and passed
	_perform(_emit_action("TestWithFakeTranslation", {"on": "false"}))
	passed = _check("and it switches back off", TranslationServer.is_pseudolocalization_enabled(), false) and passed
	return passed


# -- 6. Gendered lines and a player-named hero --


static func _test_sentences() -> bool:
	var passed: bool = true
	TranslationServer.set_locale("fr")

	var in_context: String = _emit_expression("TranslatedTextFromPatternInContext", {
		"pattern": "\"{name} is ready.\"", "context": "\"f\"", "values": "{\"name\": \"Ilsa\"}"})
	passed = _check("Translated Text From Pattern In Context looks up WITH a context, then fills",
		in_context, "tr(\"{name} is ready.\", \"f\").format({\"name\": \"Ilsa\"})") and passed
	passed = _check("the feminine variant fills its slot",
		str(_value_of(in_context)), "Ilsa est prete.") and passed
	# The whole case for the verb: one key, three translations, and the context is an EXPRESSION -
	# so a gender read from a variable at runtime selects between them.
	passed = _check("the masculine variant is the same key",
		str(_value_of(_emit_expression("TranslatedTextFromPatternInContext", {
			"pattern": "\"{name} is ready.\"", "context": "\"m\"", "values": "{\"name\": \"Ilsa\"}"}))),
		"Ilsa est pret.") and passed
	# EDGE: a context the translator has not written yet falls back to the source sentence, so the
	# line still reads instead of coming back empty.
	passed = _check("an unwritten context falls back to the source sentence",
		str(_value_of(_emit_expression("TranslatedTextFromPatternInContext", {
			"pattern": "\"{name} is ready.\"", "context": "\"n\"", "values": "{\"name\": \"Ilsa\"}"}))),
		"Ilsa is ready.") and passed

	var words: String = "{\"they\": \"elle\", \"their\": \"sa\"}"
	var with_words: String = _emit_expression("TranslatedTextWithWords", {
		"pattern": "\"{name} drew {their} sword.\"", "words": words, "values": "{\"name\": \"Ilsa\"}"})
	passed = _check("Translated Text With Words merges the standing words with this line's values",
		with_words, "tr(\"{name} drew {their} sword.\").format(%s.merged({\"name\": \"Ilsa\"}, true))" % words) and passed
	passed = _check("the hero's pronouns land where the translator put them",
		str(_value_of(with_words)), "Ilsa a degaine sa epee.") and passed
	# EDGE: this line's values win over the standing set, which is what lets one line override a
	# pronoun without touching the character's word set.
	passed = _check("this line's values win over the standing words",
		str(_value_of(_emit_expression("TranslatedTextWithWords", {
			"pattern": "\"{name} drew {their} sword.\"", "words": words, "values": "{\"name\": \"Ilsa\", \"their\": \"son\"}"}))),
		"Ilsa a degaine son epee.") and passed
	return passed


# -- 7. Numbers the locale can actually read --


static func _test_numbers() -> bool:
	var passed: bool = true

	var local_digits: String = _emit_expression("NumberInLocalDigits", {"value": "1234", "locale": "\"ar\""})
	passed = _check("Number In Local Digits hands the number to the engine as text",
		local_digits, "TranslationServer.format_number(str(1234), \"ar\")") and passed
	passed = _check("an Arabic player reads Arabic-Indic numerals",
		str(_value_of(local_digits)), "١٢٣٤") and passed
	# EDGE (and the honest limit): a language Godot has no digit set for comes back UNCHANGED, and
	# this verb never groups thousands in any language.
	passed = _check("a language with no digit set of its own is untouched",
		str(_value_of(_emit_expression("NumberInLocalDigits", {"value": "1234567", "locale": "\"en\""}))),
		"1234567") and passed

	var from_digits: String = _emit_expression("NumberFromLocalDigits", {"text": "\"١٢٣٤\"", "locale": "\"ar\""})
	passed = _check("Number From Local Digits is the return trip",
		from_digits, "TranslationServer.parse_number(\"١٢٣٤\", \"ar\")") and passed
	passed = _check("what the player typed comes back as digits you can count with",
		str(_value_of(from_digits)), "1234") and passed
	passed = _check("and the round trip holds",
		str(_value_of(_emit_expression("NumberFromLocalDigits", {"text": local_digits, "locale": "\"ar\""}))),
		"1234") and passed

	var percent: String = _emit_expression("PercentSign", {"locale": "\"ar\""})
	passed = _check("Percent Sign takes the sign from the language",
		percent, "TranslationServer.get_percent_sign(\"ar\")") and passed
	passed = _check("Arabic writes its own percent sign", str(_value_of(percent)), "٪") and passed
	passed = _check("English writes the one you would have typed",
		str(_value_of(_emit_expression("PercentSign", {"locale": "\"en\""}))), "%") and passed

	var parts: String = _emit_expression("DateParts", {"unix": "1700000000"})
	passed = _check("Date Parts breaks a timestamp into named parts",
		parts, "Time.get_datetime_dict_from_unix_time(int(1700000000))") and passed
	var dict: Dictionary = _value_of(parts) as Dictionary
	passed = _check("the year is a named part", int(dict.get("year", 0)), 2023) and passed
	passed = _check("the month is a named part", int(dict.get("month", 0)), 11) and passed
	passed = _check("the day is a named part", int(dict.get("day", 0)), 14) and passed
	# The point of handing the catalog PARTS: the translator owns the order, and the same parts
	# produce a different date shape per language with no code change.
	passed = _check("a German pattern reads day first",
		str(_value_of("\"{day}.{month}.{year}\".format(%s)" % parts)), "14.11.2023") and passed
	passed = _check("an English pattern reads month first",
		str(_value_of("\"{month}/{day}/{year}\".format(%s)" % parts)), "11/14/2023") and passed
	return passed


# -- Catalogs --


## The catalogs every proof runs against, built in memory so the test owns its own data: German with
## an own-name row, Japanese deliberately WITHOUT one, Russian with three plural forms, French with
## gendered context variants. Returned so run() can take them back out of the shared server.
static func _register_catalogs() -> Array[Translation]:
	var catalogs: Array[Translation] = []

	var de: Translation = Translation.new()
	de.locale = "de"
	de.add_message(&"MENU_TITLE", &"Hauptmenue")
	de.add_message(&"LANGUAGE_NAME", &"Deutsch")
	catalogs.append(de)

	var ja: Translation = Translation.new()
	ja.locale = "ja"
	ja.add_message(&"MENU_TITLE", &"Menu-JA")
	catalogs.append(ja)

	var ru: Translation = Translation.new()
	ru.locale = "ru"
	ru.add_message(&"MENU_TITLE", &"Glavnoe menyu")
	ru.add_plural_message(&"%d apple", PackedStringArray(["%d yabloko", "%d yabloka", "%d yablok"]))
	ru.add_plural_message(&"{n} chapter left", PackedStringArray(["{n} glava ostalas", "{n} glavy ostalos", "{n} glav ostalos"]))
	catalogs.append(ru)

	var fr: Translation = Translation.new()
	fr.locale = "fr"
	fr.add_message(&"{name} drew {their} sword.", &"{name} a degaine {their} epee.")
	fr.add_message(&"{name} is ready.", &"{name} est pret.", &"m")
	fr.add_message(&"{name} is ready.", &"{name} est prete.", &"f")
	catalogs.append(fr)

	for catalog: Translation in catalogs:
		TranslationServer.add_translation(catalog)
	return catalogs


# -- Emission --


static func _shipped(ace_id: String) -> ACEDescriptor:
	return ACERegistry.find_descriptor("Core", ace_id)


## An ACTION's emitted statement(s), through the real compiler path.
static func _emit_action(ace_id: String, params: Dictionary) -> String:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = ace_id
	action.enabled = true
	action.params = params
	return ActionCodegen.generate_action(action, "", "")


## A CONDITION's emitted boolean expression, through the real compiler path.
static func _emit_condition(ace_id: String, params: Dictionary) -> String:
	var condition: ACECondition = ACECondition.new()
	condition.provider_id = "Core"
	condition.ace_id = ace_id
	condition.enabled = true
	condition.params = params
	return ConditionCodegen.generate_condition(condition, "")


## An EXPRESSION's emitted text. Expressions have no row of their own - the ƒx picker substitutes
## the shipped template into a field - so this is that substitution, on the SHIPPED descriptor.
static func _emit_expression(ace_id: String, params: Dictionary) -> String:
	return ActionCodegen._apply_template(_shipped(ace_id).codegen_template, params)


# -- Running the emitted code for real --


## Compiles the emitted expression into a throwaway script and returns what it evaluates to, so the
## assertion is about the code that actually ships rather than a re-typed copy of it. RefCounted is
## the host: tr() / tr_n() are Object methods, so every Translation expression resolves there.
static func _value_of(expression: String) -> Variant:
	var script: GDScript = _build("RefCounted", "\treturn (%s)" % expression, "Variant")
	if script == null:
		return "<did not compile>"
	return script.new().call("__run")


## Runs an emitted ACTION whose statements need no host of their own.
static func _perform(statements: String) -> void:
	var script: GDScript = _build("RefCounted", _indent(statements), "void")
	if script != null:
		script.new().call("__run")


## Runs an emitted ACTION inside its declared host and hands the host back, so the row's effect on
## the node (its text, its meta, its groups, its auto-translate mode) is what gets asserted. The
## caller frees it.
static func _perform_on(statements: String, host: String) -> Node:
	var script: GDScript = _build(host, _indent(statements), "void")
	if script == null:
		return Label.new()
	var node: Node = script.new()
	node.call("__run")
	return node


## Runs the emitted Refresh row against a stand-in tree. run_tests.gd has no live SceneTree (see the
## header), so the host is a RefCounted that answers get_tree() itself; every other line of the
## template - the validity guard, the meta check, the re-lookup, the assignment - runs verbatim.
static func _perform_with_tree(statements: String, tree: GroupTree) -> void:
	var script: GDScript = _build("RefCounted", _indent(statements), "void", "var host_tree\n\n\nfunc get_tree():\n\treturn host_tree\n\n\n")
	if script == null:
		return
	var runner: RefCounted = script.new()
	runner.set("host_tree", tree)
	runner.call("__run")


## One throwaway script: `extends <host>`, optional extra members, and a `__run` carrying the body.
static func _build(host: String, body: String, return_type: String, members: String = "") -> GDScript:
	var script: GDScript = GDScript.new()
	script.source_code = "@tool\nextends %s\n\n\n%sfunc __run() -> %s:\n%s\n" % [host, members, return_type, body]
	if script.reload() != OK:
		print("  translation_runtime_words_test: emitted code did not compile:\n%s" % script.source_code)
		return null
	return script


static func _indent(statements: String) -> String:
	var out: PackedStringArray = PackedStringArray()
	for line: String in statements.split("\n"):
		out.append("\t" + line)
	return "\n".join(out)


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] translation_runtime_words_test: %s" % label)
		return true
	print("[FAIL] translation_runtime_words_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
