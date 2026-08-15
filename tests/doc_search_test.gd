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
	if actual == expected:
		print("[PASS] doc_search_test: %s" % label)
		return true
	print("[FAIL] doc_search_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
