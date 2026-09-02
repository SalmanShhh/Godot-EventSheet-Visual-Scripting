# EventSheets - the documentation is findable, and open to packs (Phase 5)
#
# Three things ship in this phase and all three are pinnable headlessly, because all three are
# pure functions over data:
#
#   SEARCH      ranking is a static function over an index the caller supplies, so the ORDER is
#               pinned against a three-page fixture rather than against whatever the corpus
#               happens to say this week. Highlighting is a string transform, pinned the same way.
#   DISCOVERY   a pack becomes a documented pack by shipping eventsheet_addons/<pack>/guide.md,
#               and a project's own guides join from a settings-named folder. The discovery takes
#               its roots as arguments, so this test points it at a fixture tree under user://
#               and pins the DECISION - one directory with the file, one without.
#   ACE REFERENCE  a pack guide's hand-written verb tables are replaced at render time by the
#               vocabulary's own. Pinned as a block-list transform: the section is swapped, the
#               prose around it is not, and a page without the section is returned untouched.
#
# What it deliberately does NOT test: that a [bgcolor] run is visibly highlighted, that the
# results tree draws, or that Ctrl+P "?" opens anything - those need a laid-out tree and a real
# window, and live in tools/render_docs_slice_preview.gd instead.
@tool
class_name DocSearchTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
## The fixture tree, written under user:// on purpose: writing a guide.md into a real pack would
## be indistinguishable from a shipped one and would break the addon drift gate for whoever ran it
## next.
const FIXTURE_ROOT := "user://doc_search_test"


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _test_ranking() and all_passed
	all_passed = _test_matching() and all_passed
	all_passed = _test_highlight() and all_passed
	all_passed = _test_corpus_search() and all_passed
	all_passed = _test_discovery() and all_passed
	all_passed = _test_user_docs_setting() and all_passed
	all_passed = _test_ace_reference() and all_passed
	all_passed = _test_baked_index() and all_passed
	all_passed = _test_never_empty() and all_passed
	all_passed = _test_older_bundle_degrades() and all_passed
	return all_passed


## AN OLDER BUNDLE REGENERATES, IT DOES NOT CRASH. The bundle format grows - the search index was
## added beside the manifest that shipped before it - so a plugin can be handed a bundle written by
## an older build, or one whose header this build does not know. Every baked file is read through
## one reader, and its contract is that either case answers "there is no baked table here" so the
## caller falls back to the live path.
##
## Written against files under user:// rather than against the shipped bundle, because the assertion
## is about the RULE. Moving the installed bundle aside to test it would leave a repository without
## one if the process died mid-test.
static func _test_older_bundle_degrades() -> bool:
	var all_passed: bool = true
	var header := "[eventsheet-search v1]"
	var missing := "user://doc_search_test_absent.esdoc"
	if FileAccess.file_exists(missing):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(missing))
	all_passed = _check("a baked file that is not there reads as no payload",
		EventSheetDocLibrary.payload_of(missing, header) == null, true) and all_passed

	# A bundle from a LATER format: the payload is perfectly good text, and the header is the only
	# thing that says this reader must not trust it.
	var newer := "user://doc_search_test_newer.esdoc"
	var newer_file: FileAccess = FileAccess.open(newer, FileAccess.WRITE)
	if newer_file == null:
		return _check("the fixture bundle is writable", false, true) and all_passed
	newer_file.store_string("[eventsheet-search v2]\n{\n\"pages\": []\n}")
	newer_file.close()
	all_passed = _check("a header this build does not know reads as no payload",
		EventSheetDocLibrary.payload_of(newer, header) == null, true) and all_passed

	# And the header this build DOES know still parses, so the guard is about the version rather
	# than about refusing everything.
	var current := "user://doc_search_test_current.esdoc"
	var current_file: FileAccess = FileAccess.open(current, FileAccess.WRITE)
	if current_file == null:
		return _check("the fixture bundle is writable", false, true) and all_passed
	current_file.store_string("%s\n{\n\"pages\": []\n}" % header)
	current_file.close()
	var payload: Variant = EventSheetDocLibrary.payload_of(current, header)
	all_passed = _check("the header this build knows still parses", payload is Dictionary, true) and all_passed
	if payload is Dictionary:
		all_passed = _check("the parsed payload is the one the file carried",
			(payload as Dictionary).has("pages"), true) and all_passed

	DirAccess.remove_absolute(ProjectSettings.globalize_path(newer))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(current))
	return all_passed


## THE BAKED INDEX. The bundle carries the search table so a keystroke never reads the corpus, and
## the two halves of that are pinned here: the round trip loses nothing that the ranking compares
## against, and what ships is what a rebuild would write - byte for byte, or a reader searches a
## corpus that is not the one installed.
static func _test_baked_index() -> bool:
	var all_passed: bool = true
	var entry: Dictionary = EventSheetDocSearch.entry_for("SAMPLE", "Lists and Arrays",
		"# Lists and Arrays\n\n## Appending\n\nAppend, insert, remove.\n")
	var round_tripped: Dictionary = EventSheetDocSearch.rehydrated(EventSheetDocSearch.baked(entry))
	all_passed = _check("a baked entry keeps its title", str(round_tripped.get("title", "")),
		"Lists and Arrays") and all_passed
	all_passed = _check("a baked entry rebuilds the lowercase title the ranking compares against",
		str(round_tripped.get("title_lower", "")), "lists and arrays") and all_passed
	all_passed = _check("a baked entry keeps its words",
		str(round_tripped.get("words", "")), str(entry.get("words", ""))) and all_passed
	var headings: Array = round_tripped.get("headings", []) as Array
	all_passed = _check("a baked entry keeps its headings", headings.size(), 1) and all_passed
	if headings.size() == 1:
		var heading: Dictionary = headings[0] as Dictionary
		all_passed = _check("a baked heading keeps its slug and rebuilds its lowercase copy",
			"%s|%s" % [str(heading.get("slug", "")), str(heading.get("lower", ""))],
			"appending|appending") and all_passed
	# A rehydrated entry ranks the same way an entry built from the page does. Pinned as ORDER
	# against the freshly built one, because that is the only property the bake has to preserve.
	var pages: Array[Dictionary] = [round_tripped]
	all_passed = _check("a rehydrated entry still answers a heading query",
		EventSheetDocSearch.rank_pages(pages, "appending").size(), 1) and all_passed

	# The shipped file itself: it parses, it covers the corpus, and it is what the build would
	# write. The last one is the gate - a stale index is a search over a corpus nobody installed.
	var shipped: Array = EventSheetDocLibrary.search_entries()
	all_passed = _check("the bundle ships a search index", shipped.size() > 0, true) and all_passed
	var builder: GDScript = load("res://tools/build_help_bundle.gd")
	if builder == null:
		return _check("the build tool loads", false, true) and all_passed
	var corpus: Dictionary = builder.collect_pages()
	all_passed = _check("the baked index covers every shipped page", shipped.size(), corpus.size()) and all_passed
	all_passed = _check("the baked index is what a rebuild would write",
		FileAccess.get_file_as_string(EventSheetDocLibrary.SEARCH_PATH), builder.search_text(corpus)) and all_passed
	return all_passed


## NO EMPTY RESULTS, EVER. A query nothing matches gets the nearest sections and then the offer to
## ask for the page - never a blank panel, which reads to a reader as "you asked the wrong thing".
##
## The nearest-section half is pinned against a fixture so the assertion is about the RULE (the
## closest title wins) rather than about whatever the corpus happens to contain this week.
static func _test_never_empty() -> bool:
	var all_passed: bool = true
	var pages: Array[Dictionary] = [
		EventSheetDocSearch.entry_for("LISTS", "Lists and Arrays", "# Lists and Arrays\n\nAppend.\n"),
		EventSheetDocSearch.entry_for("SAVING", "Saving and Loading", "# Saving and Loading\n\nSlots.\n"),
	]
	var nearest: Array[Dictionary] = EventSheetDocSearch.nearest_sections("listz and arrays", pages)
	all_passed = _check("a misspelling reaches the nearest section", nearest.size() > 0, true) and all_passed
	if not nearest.is_empty():
		all_passed = _check("the nearest section is the page the query nearly spells",
			str(nearest[0].get("doc_id", "")), "guide:LISTS") and all_passed
		all_passed = _check("a nearest row says it is a near miss rather than a hit",
			str(nearest[0].get("subtitle", "")),
			"nothing matched exactly - this is the nearest section") and all_passed
		all_passed = _check("a nearest row carries no leftover sorting keys",
			nearest[0].has("similarity"), false) and all_passed
	all_passed = _check("a query nothing resembles at all offers no nearest section",
		EventSheetDocSearch.nearest_sections("qqqqzzzz", pages).size(), 0) and all_passed

	# The row of last resort: it names the reader's own words, it opens no page, and it carries the
	# query so the caller files THAT rather than making them type it again.
	var ask: Dictionary = EventSheetDocSearch.ask_row("  widget frobnication  ")
	all_passed = _check("the ask row names what was searched for", str(ask.get("title", "")),
		"Ask for a page about \"widget frobnication\"") and all_passed
	all_passed = _check("the ask row opens no page", str(ask.get("doc_id", "")), "") and all_passed
	all_passed = _check("the ask row carries the query", str(ask.get("query", "")),
		"widget frobnication") and all_passed
	all_passed = _check("the ask row is tagged in the Manual's own words",
		EventSheetDocSearch.kind_label(EventSheetDocSearch.KIND_ASK), "ask for this page") and all_passed
	# It files through the SAME channel the foot of every page uses - one address, not two.
	all_passed = _check("asking for a page files through the tracker with the search in the title",
		EventSheetDocFeedback.ask_url("https://example.com/repo/", "widget frobnication"),
		"https://example.com/repo/issues/new?title=Manual%3A%20no%20page%20about%20widget%20frobnication") and all_passed
	all_passed = _check("an empty search files nothing",
		EventSheetDocFeedback.ask_url("https://example.com/repo", "  "), "") and all_passed

	# The whole search, end to end: a query nothing in this corpus answers still comes back with
	# rows, and the last of them is the offer to ask.
	var results: Array[Dictionary] = EventSheetDocSearch.search_all("zzqqxwv frobnication")
	all_passed = _check("a search nothing answers is never empty", results.is_empty(), false) and all_passed
	if not results.is_empty():
		all_passed = _check("the last row offered is the offer to ask",
			str(results[results.size() - 1].get("kind", "")), EventSheetDocSearch.KIND_ASK) and all_passed
	return all_passed


## Three fixture pages, and the one ordering rule that matters: WHERE a hit landed outranks HOW it
## matched. The page titled after the query comes first, the page with a matching heading second,
## the page that merely mentions the word last.
static func _test_ranking() -> bool:
	var all_passed: bool = true
	var pages: Array[Dictionary] = [
		EventSheetDocSearch.entry_for("BODY", "Saving and Loading", "# Saving and Loading\n\nA sheet keeps lists of slots.\n"),
		EventSheetDocSearch.entry_for("HEADING", "Working with Text", "# Working with Text\n\n## Lists of words\n\nSplit a sentence.\n"),
		EventSheetDocSearch.entry_for("TITLE", "Lists and Arrays", "# Lists and Arrays\n\nAppend, insert, remove.\n"),
	]
	var order: PackedStringArray = PackedStringArray()
	for result: Dictionary in EventSheetDocSearch.rank_pages(pages, "lists"):
		order.append(str(result.get("page_id", "")))
	all_passed = _check("a title hit, a heading hit and a body hit rank in that order",
		", ".join(order), "TITLE, HEADING, BODY") and all_passed

	var ranked_pages: Array[Dictionary] = EventSheetDocSearch.rank_pages(pages, "lists")
	all_passed = _check("all three pages answered", ranked_pages.size(), 3) and all_passed
	if ranked_pages.size() < 3:
		return false
	var heading_result: Dictionary = ranked_pages[1]
	all_passed = _check("a heading result carries its heading", str(heading_result.get("heading", "")), "Lists of words") and all_passed
	all_passed = _check("and the anchor that jumps to it", str(heading_result.get("anchor", "")), "lists-of-words") and all_passed
	all_passed = _check("and the public doc id that opens it", str(heading_result.get("doc_id", "")), "guide:HEADING") and all_passed

	# Prefix beats substring beats subsequence, the palette's own rule, applied to titles.
	var titles: Array[Dictionary] = [
		EventSheetDocSearch.entry_for("SUB", "The Save Studio", "# The Save Studio\n"),
		EventSheetDocSearch.entry_for("SEQ", "Sheets and variables", "# Sheets and variables\n"),
		EventSheetDocSearch.entry_for("PRE", "Save games", "# Save games\n"),
	]
	var ranked: PackedStringArray = PackedStringArray()
	for result: Dictionary in EventSheetDocSearch.rank_pages(titles, "save"):
		ranked.append(str(result.get("page_id", "")))
	all_passed = _check("prefix, then substring, then subsequence", ", ".join(ranked), "PRE, SUB, SEQ") and all_passed

	# A SUBSEQUENCE hit ranks WORSE than a body hit, so a page whose title merely contains the
	# query's letters in order must not shoulder aside its own prose - which says the word outright.
	# Two pages, one query: the page that is about the word wins, and the letter-match follows.
	var letters: Array[Dictionary] = [
		EventSheetDocSearch.entry_for("LETTERS", "Sheets and variables", "# Sheets and variables\n\nNothing to see.\n"),
		EventSheetDocSearch.entry_for("WORDS", "Working with slots", "# Working with slots\n\nYou save the game here.\n"),
	]
	var by_word: PackedStringArray = PackedStringArray()
	for result: Dictionary in EventSheetDocSearch.rank_pages(letters, "save"):
		by_word.append("%s:%d" % [str(result.get("page_id", "")), int(result.get("score", -1))])
	all_passed = _check("a page that says the word outranks one that merely spells it out",
		", ".join(by_word), "WORDS:%d, LETTERS:%d" % [
			EventSheetDocSearch.SCORE_BODY, EventSheetDocSearch.SCORE_TITLE_SUBSEQUENCE]) and all_passed

	var everything: Array[Dictionary] = EventSheetDocSearch.rank_pages(pages, "")
	all_passed = _check("an empty query lists every page", everything.size(), 3) and all_passed
	all_passed = _check("a query nothing answers returns nothing",
		EventSheetDocSearch.rank_pages(pages, "zzqqx").size(), 0) and all_passed
	all_passed = _check("the limit is honoured", EventSheetDocSearch.rank_pages(pages, "", 2).size(), 2) and all_passed
	return all_passed


static func _test_matching() -> bool:
	var all_passed: bool = true
	all_passed = _check("a prefix scores best", EventSheetDocSearch.match_score("save games", "save"), 0) and all_passed
	all_passed = _check("a substring scores next", EventSheetDocSearch.match_score("the save studio", "save"), 1) and all_passed
	all_passed = _check("a subsequence scores last", EventSheetDocSearch.match_score("sheets and variables", "save"), 2) and all_passed
	all_passed = _check("a miss is a miss", EventSheetDocSearch.match_score("nothing here", "zzq"), -1) and all_passed

	var blob: String = EventSheetDocSearch.word_blob("Append a value to arr[0], then print(total_count).")
	all_passed = _check("punctuation separates words, and only punctuation",
		blob, " 0 a append arr print then to total_count value ") and all_passed
	all_passed = _check("a word prefix matches the body", EventSheetDocSearch.matches_body(blob, "app"), true) and all_passed
	all_passed = _check("every token has to land", EventSheetDocSearch.matches_body(blob, "append missing"), false) and all_passed
	all_passed = _check("a match INSIDE a word is not a body hit",
		EventSheetDocSearch.matches_body(blob, "ppend"), false) and all_passed
	return all_passed


## The highlight is a re-emit, because there is no way to ask a RichTextLabel to find anything.
## The rule that keeps it safe: the scan steps over tags, so a query can never land inside one.
static func _test_highlight() -> bool:
	var all_passed: bool = true
	all_passed = _check("a hit is wrapped in bgcolor",
		EventSheetDocSearch.highlight_bbcode("append a value", "value"),
		"append a [bgcolor=%s]value[/bgcolor]" % EventSheetDocSearch.HIGHLIGHT_BGCOLOR) and all_passed
	all_passed = _check("the match keeps its own spelling",
		EventSheetDocSearch.highlight_bbcode("Append it", "append"),
		"[bgcolor=%s]Append[/bgcolor] it" % EventSheetDocSearch.HIGHLIGHT_BGCOLOR) and all_passed
	all_passed = _check("a tag is never searched",
		EventSheetDocSearch.highlight_bbcode("[b]bold[/b]", "b"),
		"[b][bgcolor=%s]b[/bgcolor]old[/b]" % EventSheetDocSearch.HIGHLIGHT_BGCOLOR) and all_passed
	all_passed = _check("an escaped bracket survives",
		EventSheetDocSearch.highlight_bbcode("arr[lb]0[rb]", "zz"), "arr[lb]0[rb]") and all_passed
	all_passed = _check("an empty query changes nothing",
		EventSheetDocSearch.highlight_bbcode("append a value", ""), "append a value") and all_passed

	var blocks: Array[Dictionary] = EventSheetDocMarkdown.parse("A list of values.\n\n| Verb | Note |\n|---|---|\n| Append | adds a value |\n")
	var lit: Array[Dictionary] = EventSheetDocSearch.highlight_blocks(blocks, "value")
	all_passed = _check("a paragraph is highlighted",
		str(lit[0].get("bbcode", "")).contains("[bgcolor=%s]value" % EventSheetDocSearch.HIGHLIGHT_BGCOLOR), true) and all_passed
	all_passed = _check("and a table cell is too",
		str((lit[1].get("rows", [])[0] as Array)[1]).contains("[bgcolor=%s]value" % EventSheetDocSearch.HIGHLIGHT_BGCOLOR), true) and all_passed
	all_passed = _check("the blocks it was given are left alone",
		str(blocks[0].get("bbcode", "")), "A list of values.") and all_passed
	return all_passed


## The same search, over the corpus that actually ships. Pinned by what a result IS rather than by
## how many there are: every row has to be openable, or the palette offers dead entries.
static func _test_corpus_search() -> bool:
	var all_passed: bool = true
	EventSheetDocSearch.reload()
	var results: Array[Dictionary] = EventSheets.search_docs("event sheet", 10)
	all_passed = _check("the corpus answers a plain question", results.is_empty(), false) and all_passed
	var unopenable: PackedStringArray = PackedStringArray()
	for result: Dictionary in results:
		if not bool(EventSheetDocExplain.resolve(str(result.get("doc_id", ""))).get("valid", false)):
			unopenable.append(str(result.get("doc_id", "")))
	all_passed = _check("every result opens through the public id scheme", ", ".join(unopenable), "") and all_passed
	var anchored: PackedStringArray = PackedStringArray()
	for result: Dictionary in results:
		var anchor: String = str(result.get("anchor", ""))
		if anchor.is_empty():
			continue
		var page_id: String = str(result.get("page_id", ""))
		if not _slugs_of(EventSheetDocLibrary.page_source(page_id)).has(anchor):
			anchored.append("%s -> %s" % [page_id, anchor])
	all_passed = _check("every result anchor is a real heading on its page", ", ".join(anchored), "") and all_passed
	all_passed = _check("the index covers the whole corpus",
		EventSheetDocSearch.index().size(), EventSheetDocLibrary.page_ids().size()) and all_passed
	return all_passed


## Discovery, against a fixture tree: a pack directory carrying guide.md becomes a page, one
## without it does not, and a project docs folder contributes its .md files.
static func _test_discovery() -> bool:
	var all_passed: bool = true
	var packs_root: String = "%s/packs" % FIXTURE_ROOT
	var docs_dir: String = "%s/project_docs" % FIXTURE_ROOT
	DirAccess.make_dir_recursive_absolute("%s/with_guide" % packs_root)
	DirAccess.make_dir_recursive_absolute("%s/without_guide" % packs_root)
	DirAccess.make_dir_recursive_absolute(docs_dir)
	_write("%s/with_guide/guide.md" % packs_root, "# Grapple Hook\n\nSwing from anything.\n")
	_write("%s/without_guide/notes.txt" % packs_root, "not a guide")
	_write("%s/TEAM-NOTES.md" % docs_dir, "# How we build levels\n")

	var found: Dictionary = EventSheetDocLibrary.discover_pages(packs_root, docs_dir)
	all_passed = _check("a pack that ships guide.md is a page", found.has("Packs/with_guide"), true) and all_passed
	all_passed = _check("a pack that does not is not", found.has("Packs/without_guide"), false) and all_passed
	all_passed = _check("the pack page is read from the pack's own folder",
		str((found.get("Packs/with_guide", {}) as Dictionary).get("path", "")), "%s/with_guide/guide.md" % packs_root) and all_passed
	all_passed = _check("its tree label is the guide's own H1",
		str((found.get("Packs/with_guide", {}) as Dictionary).get("title", "")), "Grapple Hook") and all_passed
	all_passed = _check("a project guide joins under its own set", found.has("Project/TEAM-NOTES"), true) and all_passed
	all_passed = _check("a folder with no guides contributes nothing",
		EventSheetDocLibrary.discover_pages("%s/nowhere" % FIXTURE_ROOT, "%s/nowhere" % FIXTURE_ROOT).size(), 0) and all_passed

	# The shipped corpus is unaffected: no pack in this repo ships a guide.md, so an "addon:" id
	# still resolves to the bundled docs/Addons page rather than to a discovered one.
	all_passed = _check("no bundled pack ships its own guide today",
		EventSheetDocLibrary.pack_page_id("quest"), "") and all_passed
	all_passed = _check("so the addon id still names the bundled page",
		str(EventSheetDocExplain.resolve("addon:quest").get("page_id", "")), "Addons/Quest") and all_passed
	return all_passed


static func _test_user_docs_setting() -> bool:
	var all_passed: bool = true
	var registered: bool = false
	for definition: Dictionary in EventSheetSettings.DEFINITIONS:
		if str(definition.get("name", "")) == EventSheetDocLibrary.USER_DOCS_SETTING:
			registered = true
			all_passed = _check("the docs folder setting carries its default",
				str(definition.get("default", "")), EventSheetDocLibrary.USER_DOCS_DEFAULT) and all_passed
			all_passed = _check("and is picked in Project Settings as a directory",
				int(definition.get("hint", PROPERTY_HINT_NONE)), PROPERTY_HINT_DIR) and all_passed
	all_passed = _check("the project docs folder is a registered setting", registered, true) and all_passed
	all_passed = _check("the API answers with the same folder",
		EventSheets.user_docs_dir(), EventSheetDocLibrary.USER_DOCS_DEFAULT) and all_passed
	return all_passed


## The ACE reference a reader sees is the vocabulary's, not the guide author's.
static func _test_ace_reference() -> bool:
	var all_passed: bool = true
	# One guide legitimately documents several pack directories, and a reference built from only
	# one of them would drop half the vocabulary the page is about.
	all_passed = _check("a bundled addon guide names every pack it documents",
		", ".join(EventSheetDocAceReference.packs_for_page("Addons/Quest")), "quest, quest_resource") and all_passed
	all_passed = _check("a pack's own discovered guide names itself",
		", ".join(EventSheetDocAceReference.packs_for_page("Packs/grapple_hook")), "grapple_hook") and all_passed
	all_passed = _check("a guide that is not a pack's names none",
		EventSheetDocAceReference.packs_for_page("GUIDE-RECIPES").size(), 0) and all_passed

	var rows: Dictionary = EventSheetDocAceReference.verb_rows("quest")
	all_passed = _check("the pack's actions are derived", _has_verb(rows, "Actions", "advance_objective"), true) and all_passed
	all_passed = _check("its conditions land in their own group", _has_verb(rows, "Conditions", "quest_is_active"), true) and all_passed
	all_passed = _check("and a condition is not filed as an action", _has_verb(rows, "Actions", "quest_is_active"), false) and all_passed

	# A COLUMN OF BLANK CELLS reads as a broken table. A pack whose reflected verbs declare no notes
	# must therefore ship two columns, not three with an empty one, and the decision is taken for the
	# whole page so the Actions, Conditions and Expressions tables stay the same shape as each other.
	var silent: Dictionary = {"Actions": [{"name": "a", "params": "x", "note": ""}],
		"Conditions": [{"name": "b", "params": "", "note": "   "}]}
	all_passed = _check("a pack that documents nothing draws no description column",
		", ".join(EventSheetDocAceReference.reference_columns(silent)), "Name, Parameters") and all_passed
	var spoken: Dictionary = {"Actions": [{"name": "a", "params": "x", "note": ""}],
		"Expressions": [{"name": "c", "params": "", "note": "What it does."}]}
	all_passed = _check("one documented verb anywhere on the page brings the column back",
		", ".join(EventSheetDocAceReference.reference_columns(spoken)), "Name, Parameters, What it does") and all_passed
	all_passed = _check("an empty page asks for no description column",
		", ".join(EventSheetDocAceReference.reference_columns({})), "Name, Parameters") and all_passed
	# Every derived table on a page carries the SAME headers, and every row fills every one of them.
	var derived: Array[Dictionary] = EventSheetDocAceReference.blocks_for_page("Addons/Quest")
	var wanted: int = EventSheetDocAceReference.reference_columns(
		EventSheetDocAceReference.verb_rows_for_page("Addons/Quest")).size()
	var ragged: int = 0
	var tables: int = 0
	for block: Dictionary in derived:
		if str(block.get("kind", "")) != "table":
			continue
		tables += 1
		if (block.get("headers", []) as Array).size() != wanted:
			ragged += 1
		for entry: Variant in (block.get("rows", []) as Array):
			if (entry as Array).size() != wanted:
				ragged += 1
	all_passed = _check("a real pack draws its reference tables", tables > 0, true) and all_passed
	all_passed = _check("with no ragged header or row anywhere in them", ragged, 0) and all_passed

	var page: String = "# Quest\n\n## Setup\n\nAttach it.\n\n## ACE reference\n\n| Verb | Parameters | Notes |\n|---|---|---|\n| `advance_objective` | quest_id: String | (when) |\n\n## Use cases\n\nEarn a reward.\n"
	var blocks: Array[Dictionary] = EventSheetDocMarkdown.parse(page, "Addons/Quest")
	all_passed = _check("the guide's own tables name the verbs it wrote down",
		", ".join(EventSheetDocAceReference.markdown_verbs(blocks)), "advance_objective") and all_passed

	var swapped: Array[Dictionary] = EventSheetDocAceReference.replace_section(blocks, "Addons/Quest")
	all_passed = _check("the section is still the section",
		str(swapped[3].get("text", "")), EventSheetDocAceReference.SECTION_TITLE) and all_passed
	all_passed = _check("its anchor still resolves",
		str(swapped[3].get("slug", "")), EventSheetDocAceReference.SECTION_SLUG) and all_passed
	all_passed = _check("the prose before it is untouched", str(swapped[1].get("text", "")), "Setup") and all_passed
	all_passed = _check("the section after it survives", _last_heading(swapped), "Use cases") and all_passed
	all_passed = _check("the swapped section lists more verbs than the guide did",
		EventSheetDocAceReference.markdown_verbs(swapped).size() > 1, true) and all_passed

	# THE OTHER TABLE SHAPE. Six shipped guides write the whole reference as ONE table under the
	# bare heading - kind in the first column, name in the second, no "### Actions" subsection to
	# recognise. A reader that only knew the first shape printed those verbs twice (the stale
	# Markdown table AND the live ones) while the advisory diff reported every one of them as
	# undocumented. Both halves are the same question, so both are pinned here.
	var kind_page: String = "# Quest\n\n## ACE reference\n\nOn the canvas these read as sentences:\n\n| Kind | Name | Parameters | Description |\n|---|---|---|---|\n| Action | advance_objective | `quest_id` | Move it on. |\n\n### Inspector properties\n\n| Property | Default | What it does |\n|---|---|---|\n| `quest_id` | `\"\"` | Which quest. |\n"
	var kind_blocks: Array[Dictionary] = EventSheetDocMarkdown.parse(kind_page, "Addons/Quest")
	all_passed = _check("the kind-first table is read as a verb table",
		", ".join(EventSheetDocAceReference.markdown_verbs(kind_blocks)), "advance_objective") and all_passed
	all_passed = _check("its name column is the second one",
		EventSheetDocAceReference.verb_name_column(["Kind", "Name", "Parameters", "Description"]), 1) and all_passed
	all_passed = _check("a properties table is not a verb table",
		EventSheetDocAceReference.verb_name_column(["Property", "Default", "What it does"]), -1) and all_passed
	var kind_swapped: Array[Dictionary] = EventSheetDocAceReference.replace_section(kind_blocks, "Addons/Quest")
	all_passed = _check("the stale table is dropped, never printed beside the live ones",
		_table_count(kind_swapped, "Kind"), 0) and all_passed
	all_passed = _check("while the Inspector table it is not allowed to touch survives",
		_table_count(kind_swapped, "Property"), 1) and all_passed
	all_passed = _check("and the prose that opened the section survives with it",
		_has_paragraph(kind_swapped, "On the canvas"), true) and all_passed

	var untouched: Array[Dictionary] = EventSheetDocMarkdown.parse("# Quest\n\n## Setup\n\nAttach it.\n", "Addons/Quest")
	all_passed = _check("a page with no ACE reference is returned unchanged",
		EventSheetDocAceReference.replace_section(untouched, "Addons/Quest").size(), untouched.size()) and all_passed
	all_passed = _check("and a page that documents no pack never blanks a written section",
		EventSheetDocAceReference.replace_section(blocks, "GUIDE-RECIPES").size(), blocks.size()) and all_passed

	var diff: Dictionary = EventSheetDocAceReference.diff_for_page("Addons/Quest", blocks)
	all_passed = _check("the advisory diff names the packs it compared",
		", ".join(diff.get("packs", PackedStringArray())), "quest, quest_resource") and all_passed
	all_passed = _check("the verb the guide DID list is not reported missing",
		(diff.get("missing", PackedStringArray()) as PackedStringArray).has("advance_objective"), false) and all_passed
	all_passed = _check("and the ones it left out are",
		(diff.get("missing", PackedStringArray()) as PackedStringArray).is_empty(), false) and all_passed
	return all_passed


## How many tables in a page carry `first_header` as their first column head.
static func _table_count(blocks: Array[Dictionary], first_header: String) -> int:
	var count: int = 0
	for block: Dictionary in blocks:
		if str(block.get("kind", "")) != "table":
			continue
		var headers: Array = block.get("headers", []) as Array
		if not headers.is_empty() and str(headers[0]).strip_edges() == first_header:
			count += 1
	return count


static func _has_paragraph(blocks: Array[Dictionary], fragment: String) -> bool:
	for block: Dictionary in blocks:
		if str(block.get("kind", "")) == "paragraph" and str(block.get("bbcode", "")).contains(fragment):
			return true
	return false


static func _has_verb(rows: Dictionary, group: String, wanted: String) -> bool:
	for entry: Variant in (rows.get(group, []) as Array):
		if str((entry as Dictionary).get("name", "")) == wanted:
			return true
	return false


static func _last_heading(blocks: Array[Dictionary]) -> String:
	var found: String = ""
	for block: Dictionary in blocks:
		if str(block.get("kind", "")) == "heading" and int(block.get("level", 0)) == 2:
			found = str(block.get("text", ""))
	return found


static func _slugs_of(source: String) -> Dictionary:
	var slugs: Dictionary = {}
	for block: Dictionary in EventSheetDocMarkdown.parse(source):
		if str(block.get("kind", "")) == "heading":
			slugs[str(block.get("slug", ""))] = true
	return slugs


static func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(text)


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("doc_search_test", label, actual, expected)
