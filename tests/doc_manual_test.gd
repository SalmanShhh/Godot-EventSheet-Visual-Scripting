# Godot EventSheets - THE MANUAL: what it is called, what it knows, and where a reader lands.
#
# Everything pinned here is a DECISION rather than a pixel, because no headless run lays anything
# out: what F1 answers for each kind of selected thing, how a reference id parses and what it
# resolves to, what a page is built out of, the words the search tags its results with, where the
# reader has been, and the footer sentence. The look those decisions produce is the harness's job.
#
# The one thing that CANNOT be tested here is the live vocabulary: there is no registry outside a
# running editor, so a reference page for a category legitimately lists nothing in the suite. The
# tests therefore pin the SHAPE of those pages (they exist, they are titled, they say so honestly)
# and the derived-from-scripts half - a behavior's reference, which the guide scaffolder's own
# derivation answers headlessly.
@tool
class_name DocManualTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
## A pack that ships in this repo, for the behavior-reference assertions.
const SAMPLE_PACK := "quest"


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _test_reference_ids() and all_passed
	all_passed = _test_reference_pages() and all_passed
	all_passed = _test_stub_offers_to_write_the_guide() and all_passed
	all_passed = _test_breadcrumb() and all_passed
	all_passed = _test_glossary() and all_passed
	all_passed = _test_help_target() and all_passed
	all_passed = _test_history() and all_passed
	all_passed = _test_usage() and all_passed
	all_passed = _test_search_tags() and all_passed
	all_passed = _test_footer_and_marks() and all_passed
	all_passed = _test_the_word_manual() and all_passed
	return all_passed


## The id scheme, both ways. An id that names a kind this build does not know must not parse, or a
## typo in a caller would draw an empty page instead of failing at the caller.
static func _test_reference_ids() -> bool:
	var all_passed: bool = true
	all_passed = _check("a pack id round-trips",
		EventSheetDocReference.doc_id("pack", SAMPLE_PACK), "reference:pack/quest") and all_passed
	all_passed = _check("and parses back",
		str(EventSheetDocReference.parse("reference:pack/quest").get("name", "")), "quest") and all_passed
	all_passed = _check("a one-page kind needs no name",
		EventSheetDocReference.doc_id("legend"), "reference:legend") and all_passed
	all_passed = _check("an unknown kind parses to nothing",
		EventSheetDocReference.parse("reference:sandwich/ham").is_empty(), true) and all_passed
	all_passed = _check("and so does another scheme",
		EventSheetDocReference.parse("guide:GUIDE-RECIPES").is_empty(), true) and all_passed
	all_passed = _check("a pack that is not installed names no page",
		EventSheetDocReference.has_page("reference:pack/no_such_pack_here"), false) and all_passed
	all_passed = _check("a glossary term that does not exist names no page",
		EventSheetDocReference.has_page("reference:glossary/zznotaword"), false) and all_passed
	# The router is what every caller goes through, so the scheme has to be valid THERE too.
	var route: Dictionary = EventSheetDocExplain.resolve("reference:glossary/pick")
	all_passed = _check("the router accepts it", bool(route.get("valid", false)), true) and all_passed
	all_passed = _check("and reports the kind", str(route.get("reference_kind", "")), "glossary") and all_passed
	all_passed = _check("and the term", str(route.get("reference_name", "")), "pick") and all_passed
	all_passed = _check("a reference page has no online page to send anyone to",
		str(route.get("target", "")), "") and all_passed
	return all_passed


## A reference page is a page: a title, a lead, and one table per group of verbs. The behavior
## reference is built from the pack's own scripts headlessly, so its rows are real here.
static func _test_reference_pages() -> bool:
	var all_passed: bool = true
	var blocks: Array[Dictionary] = EventSheetDocReference.blocks_for("pack", SAMPLE_PACK)
	all_passed = _check("a behavior reference draws", blocks.is_empty(), false) and all_passed
	all_passed = _check("titled as the reader names the pack",
		str(blocks[0].get("text", "")), "Quest") and all_passed
	all_passed = _check("and the title is the page's own H1",
		int(blocks[0].get("level", 0)), 1) and all_passed
	var tables: int = 0
	for block: Dictionary in blocks:
		if str(block.get("kind", "")) == "table":
			tables += 1
	all_passed = _check("with a table of verbs under it", tables > 0, true) and all_passed
	all_passed = _check("the legend is always drawable",
		EventSheetDocReference.legend_blocks().size(), 3) and all_passed
	all_passed = _check("an empty name draws nothing",
		EventSheetDocReference.blocks_for("pack", "").is_empty(), true) and all_passed
	# The columns are decided once for the whole page, so its tables stay the same shape down it.
	# Every table now leads with the row's own MARK (the fixed shape - see doc_tutorials_test),
	# so the counts here are one higher than they were before that landed.
	var noted: Dictionary = {"Actions": [{"name": "Do It", "params": "", "note": "Does it."}]}
	var bare: Dictionary = {"Actions": [{"name": "Do It", "params": "", "note": ""}]}
	all_passed = _check("a page with blurbs prints the last column",
		Array(EventSheetDocReference.table_columns(noted)).size(), 4) and all_passed
	all_passed = _check("a page without them does not",
		Array(EventSheetDocReference.table_columns(bare)).size(), 3) and all_passed
	# A row that knows its entry links to it, so a reference page is a way IN rather than a list.
	var linked: Array = EventSheetDocReference.table_rows(
		[{"name": "Do It", "params": "", "doc_id": "ace:P/do_it"}], false, "➜")
	all_passed = _check("a verb links to its entry",
		str((linked[0] as Array)[1]), "[url=ace:P/do_it]Do It[/url]") and all_passed
	return all_passed


## A behavior with no written guide is not a dead link: it is its reference page, with a sentence
## saying so and a button that writes the skeleton.
static func _test_stub_offers_to_write_the_guide() -> bool:
	var all_passed: bool = true
	# A pack whose guide the bundle DOES carry must not be stubbed - that would offer to write a
	# guide over one somebody already wrote.
	var documented: bool = not EventSheetDocReference.guide_page_for("pack", SAMPLE_PACK).is_empty()
	var blocks: Array[Dictionary] = EventSheetDocReference.blocks_for("pack", SAMPLE_PACK)
	var offers_writing: bool = false
	for block: Dictionary in blocks:
		if str(block.get("action", "")) == "write_guide":
			offers_writing = true
	all_passed = _check("a documented behavior is never offered a new guide",
		offers_writing and documented, false) and all_passed
	# And the stub itself, built from rows rather than from whatever happens to be installed.
	var stub: Array[Dictionary] = EventSheetDocReference.blocks_for("pack", "zz_no_such_pack")
	all_passed = _check("a pack that does not exist draws nothing at all",
		stub.is_empty(), true) and all_passed
	return all_passed


## Where am I. The trail starts at the Manual and names the PART of it the page belongs to.
static func _test_breadcrumb() -> bool:
	var all_passed: bool = true
	all_passed = _check("a behavior reference",
		" ▸ ".join(Array(EventSheetDocReference.breadcrumb("reference:pack/quest", "Quest"))),
		"Manual ▸ Behavior reference ▸ Quest") and all_passed
	all_passed = _check("a System reference page",
		" ▸ ".join(Array(EventSheetDocReference.breadcrumb("reference:section/Flow", "Flow"))),
		"Manual ▸ System reference ▸ Flow") and all_passed
	all_passed = _check("an object reference page",
		" ▸ ".join(Array(EventSheetDocReference.breadcrumb("reference:class/Timer", "Timer"))),
		"Manual ▸ Object reference ▸ Timer") and all_passed
	all_passed = _check("the index is just the Manual",
		" ▸ ".join(Array(EventSheetDocReference.breadcrumb("", ""))), "Manual") and all_passed
	# A crumb is never printed twice, which is what a page whose title IS its part would do.
	all_passed = _check("the page's own name is not repeated",
		" ▸ ".join(Array(EventSheetDocReference.breadcrumb("reference:legend",
			EventSheetDocReference.title_for("legend", "")))),
		"Manual ▸ What the marks on a sheet mean") and all_passed
	return all_passed


## The words another event-sheet editor spells differently. The naming rule is part of the test:
## nothing here, in code or in a string, may name the other editor.
static func _test_glossary() -> bool:
	var all_passed: bool = true
	all_passed = _check("the page is titled by what it is for",
		EventSheetDocGlossary.PAGE_TITLE, "Coming from another event-sheet editor") and all_passed
	all_passed = _check("a word is found by typing it",
		str((EventSheetDocGlossary.find("pick")[0] as Dictionary).get("term", "")), "Pick") and all_passed
	all_passed = _check("the word itself outranks the sentences that mention it",
		str((EventSheetDocGlossary.find("family")[0] as Dictionary).get("term", "")), "Family") and all_passed
	all_passed = _check("a term is addressable on its own",
		str(EventSheetDocGlossary.term("layout").get("term", "")), "Layout") and all_passed
	all_passed = _check("an unknown word is an empty answer",
		EventSheetDocGlossary.term("zznotaword").is_empty(), true) and all_passed
	# Every entry is a chapter of the page, so every term is a place the search can land.
	var chapters: int = 0
	for block: Dictionary in EventSheetDocGlossary.blocks():
		if str(block.get("kind", "")) == "heading" and int(block.get("level", 0)) == 2:
			chapters += 1
	all_passed = _check("one chapter per term", chapters, EventSheetDocGlossary.terms().size()) and all_passed
	return all_passed


## F1 answers for WHAT IS SELECTED, and that mapping is the whole point of the key.
static func _test_help_target() -> bool:
	var all_passed: bool = true
	var sheet: EventSheetResource = EventSheetResource.new()
	# A row with a verb answers with its entry.
	var event: EventRow = EventRow.new()
	var action: ACEAction = ACEAction.new()
	action.provider_id = "System"
	action.ace_id = "Wait"
	event.actions.append(action)
	all_passed = _check("an action row answers with its entry",
		EventSheetDocHelpTarget.doc_id_for(sheet, event), "ace:System/Wait") and all_passed
	# A band with children and nothing in either lane is a group, and a group has its own page.
	var group: EventRow = EventRow.new()
	group.sub_events.append(EventRow.new())
	all_passed = _check("a group is recognised", EventSheetDocHelpTarget.is_group(group), true) and all_passed
	all_passed = _check("an event with a verb is not",
		EventSheetDocHelpTarget.is_group(event), false) and all_passed
	all_passed = _check("a group answers with the Manual's page on groups",
		EventSheetDocHelpTarget.doc_id_for(sheet, group),
		EventSheetDocHelpTarget.groups_page_id()) and all_passed
	# A behavior's Include bar answers with the behavior's reference - decided by where the sheet
	# was opened from, which is the only thing that says "this file IS a pack".
	var pack_sheet: EventSheetResource = EventSheetResource.new()
	pack_sheet.external_source_path = "res://eventsheet_addons/quest/quest.gd"
	all_passed = _check("the pack directory is read off the file",
		EventSheetDocHelpTarget.pack_directory_of(pack_sheet), "quest") and all_passed
	all_passed = _check("and the Include bar answers with its reference",
		EventSheetDocHelpTarget.doc_id_for(pack_sheet, event, {"kind": "pack_include"}),
		"reference:pack/quest") and all_passed
	all_passed = _check("a plain script's Include bar is not a behavior",
		EventSheetDocHelpTarget.doc_id_for_include(sheet), "") and all_passed
	all_passed = _check("a row that names nothing answers nothing",
		EventSheetDocHelpTarget.doc_id_for(sheet, EventRow.new()), "") and all_passed
	return all_passed


## Back, forward, recents and bookmarks - the four things a reader reaches for without thinking.
static func _test_history() -> bool:
	var all_passed: bool = true
	EventSheetDocHistory.reset()
	EventSheetDocHistory.visit("guide:A")
	EventSheetDocHistory.visit("guide:B")
	EventSheetDocHistory.visit("guide:C")
	all_passed = _check("back walks the pages", EventSheetDocHistory.go_back(), "guide:B") and all_passed
	all_passed = _check("and again", EventSheetDocHistory.go_back(), "guide:A") and all_passed
	all_passed = _check("the start of the trail is the end of going back",
		EventSheetDocHistory.can_go_back(), false) and all_passed
	all_passed = _check("forward retraces it", EventSheetDocHistory.go_forward(), "guide:B") and all_passed
	# Navigating after a back truncates forward - the behaviour every browser has trained in.
	EventSheetDocHistory.visit("guide:D")
	all_passed = _check("a new page ends the forward trail",
		EventSheetDocHistory.can_go_forward(), false) and all_passed
	all_passed = _check("recents are newest first",
		EventSheetDocHistory.recent()[0], "guide:D") and all_passed
	all_passed = _check("and carry each page once",
		EventSheetDocHistory.recent().count("guide:B"), 1) and all_passed
	all_passed = _check("a star goes on", EventSheetDocHistory.toggle_bookmark("guide:D"), true) and all_passed
	all_passed = _check("and comes off", EventSheetDocHistory.toggle_bookmark("guide:D"), false) and all_passed
	EventSheetDocHistory.remember_scroll("guide:D", 240.0)
	all_passed = _check("a page remembers where it was read to",
		EventSheetDocHistory.scroll_for("guide:D"), 240.0) and all_passed
	all_passed = _check("and a page never read starts at the top",
		EventSheetDocHistory.scroll_for("guide:never"), 0.0) and all_passed
	# What outlives the editor is what was read and what was kept - never the stacks.
	var state: Dictionary = EventSheetDocHistory.state()
	all_passed = _check("the saved position carries the recents",
		(state.get("recent", []) as Array).is_empty(), false) and all_passed
	EventSheetDocHistory.reset()
	EventSheetDocHistory.restore(state)
	all_passed = _check("and restores them",
		EventSheetDocHistory.recent()[0], "guide:D") and all_passed
	all_passed = _check("while the back stack starts empty again",
		EventSheetDocHistory.can_go_back(), false) and all_passed
	EventSheetDocHistory.reset()
	return all_passed


## "Used in this sheet: N events" - the one thing a reference entry knows that a written page
## cannot, counted over a fixture sheet rather than over whatever happens to be open.
static func _test_usage() -> bool:
	var all_passed: bool = true
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.events.append(_event_using("System", "Wait"))
	sheet.events.append(_event_using("System", "Wait"))
	sheet.events.append(_event_using("System", "Print"))
	var nested: EventRow = EventRow.new()
	nested.sub_events.append(_event_using("System", "Wait"))
	sheet.events.append(nested)
	all_passed = _check("every use is counted, nested ones too",
		EventSheetDocUsage.count(sheet, "System", "Wait"), 3) and all_passed
	all_passed = _check("a verb this sheet does not use counts nothing",
		EventSheetDocUsage.count(sheet, "System", "Vibrate"), 0) and all_passed
	all_passed = _check("another provider's verb of the same name is not the same verb",
		EventSheetDocUsage.count(sheet, "OtherPack", "Wait"), 0) and all_passed
	all_passed = _check("the rows come back so they can be jumped to",
		EventSheetDocUsage.rows_using(sheet, "System", "Wait").size(), 3) and all_passed
	all_passed = _check("one use reads as one event",
		EventSheetDocUsage.usage_sentence(1), "Used in this sheet: 1 event") and all_passed
	all_passed = _check("two read as two",
		EventSheetDocUsage.usage_sentence(2), "Used in this sheet: 2 events") and all_passed
	all_passed = _check("and none says nothing at all",
		EventSheetDocUsage.usage_sentence(0), "") and all_passed
	# THE ONE-WALK MAP. A caller holding a LIST of verbs - the picker's 1,878 rows, the Manual's
	# search hits - asked the walk above once per verb, which is a whole-sheet job per row. The map
	# is built from one walk and has to answer the same thing the walk does, verb for verb,
	# including the asks that name no provider and the ones that name the wrong one.
	var trigger_event: EventRow = EventRow.new()
	trigger_event.trigger_provider_id = "System"
	trigger_event.trigger_id = "OnStart"
	var condition_event: EventRow = EventRow.new()
	var condition: ACECondition = ACECondition.new()
	condition.provider_id = "OtherPack"
	condition.ace_id = "Wait"
	condition_event.conditions.append(condition)
	sheet.events.append(trigger_event)
	sheet.events.append(condition_event)
	var counts: Dictionary = EventSheetDocUsage.counts_for(sheet)
	var asks: Array = [
		["System", "Wait"], ["System", "Print"], ["System", "Vibrate"], ["System", "OnStart"],
		["OtherPack", "Wait"], ["OtherPack", "OnStart"], ["", "Wait"], ["", "OnStart"], ["", "Nope"],
	]
	for ask: Array in asks:
		all_passed = _check("one walk answers what the per-verb walk answers: %s/%s" % [ask[0], ask[1]],
			EventSheetDocUsage.count_in(counts, str(ask[0]), str(ask[1])),
			EventSheetDocUsage.count(sheet, str(ask[0]), str(ask[1]))) and all_passed
	all_passed = _check("a provider-less ask sees every provider's copy",
		EventSheetDocUsage.count_in(counts, "", "Wait"), 4) and all_passed
	all_passed = _check("an empty sheet counts nothing rather than failing",
		EventSheetDocUsage.counts_for(null).is_empty(), true) and all_passed
	# And no id can be spelled into the map's own structure. The two buckets sit one level ABOVE the
	# ids, so an id that reads like a bucket name - or like a verb joined to a provider - reaches
	# nothing at all, which is what the walk says too.
	for forged: String in ["any", "per_provider", "Wait/System", "Wait System"]:
		all_passed = _check("an id shaped like the map's own keys counts nothing: %s" % forged,
			EventSheetDocUsage.count_in(counts, "", forged),
			EventSheetDocUsage.count(sheet, "", forged)) and all_passed
		all_passed = _check("and neither does it under a provider: %s" % forged,
			EventSheetDocUsage.count_in(counts, "System", forged),
			EventSheetDocUsage.count(sheet, "System", forged)) and all_passed
	return all_passed


## One box over the whole Manual, and every row TAGGED with what it is - in the Manual's own words.
static func _test_search_tags() -> bool:
	var all_passed: bool = true
	all_passed = _check("a condition is tagged as one",
		EventSheetDocSearch.kind_label("condition"), "condition") and all_passed
	all_passed = _check("a module page is System reference",
		EventSheetDocSearch.kind_label("reference"), "System reference") and all_passed
	all_passed = _check("a pack page is behavior reference",
		EventSheetDocSearch.kind_label("behavior"), "behavior reference") and all_passed
	all_passed = _check("a Godot class is engine reference",
		EventSheetDocSearch.kind_label("engine"), "engine reference") and all_passed
	all_passed = _check("and the words from another editor are the glossary",
		EventSheetDocSearch.kind_label("glossary"), "glossary") and all_passed
	all_passed = _check("a kind this build does not know is tagged with nothing",
		EventSheetDocSearch.kind_label("sandwich"), "") and all_passed
	# The corpus half answers headlessly, and the glossary rides in the same list.
	var results: Array[Dictionary] = EventSheetDocSearch.search_all("pick")
	var kinds: Dictionary = {}
	for result: Dictionary in results:
		kinds[str(result.get("kind", ""))] = true
	all_passed = _check("searching a glossary word finds it", kinds.has("glossary"), true) and all_passed
	all_passed = _check("an empty query is not a search at all",
		EventSheetDocSearch.search_all("").is_empty(), true) and all_passed
	# The row the reader reads.
	all_passed = _check("a verb row says what it is and how much this sheet uses it",
		EventSheetDocBrowser.result_row_text({"kind": "action", "title": "Wait For Signal", "used": 2}),
		"action  ·  Wait For Signal  ·  used 2× in this sheet") and all_passed
	all_passed = _check("and says nothing about a sheet that does not use it",
		EventSheetDocBrowser.result_row_text({"kind": "guide", "title": "Recipes", "used": 0}),
		"guide  ·  Recipes") and all_passed
	return all_passed


## The footer answers "is this current?", and the marks answer "what is that?".
static func _test_footer_and_marks() -> bool:
	var all_passed: bool = true
	all_passed = _check("the footer names the build, the source and the offline promise",
		EventSheetDocDock.manual_footer_text("1.2.3"),
		"Manual v1.2.3 · shipped with the plugin · offline") and all_passed
	all_passed = _check("and it is the installed version it names",
		EventSheetDocDock.manual_footer_text(EventSheets.docs_version()).contains(SheetCompiler.VERSION),
		true) and all_passed
	all_passed = _check("a mark explains itself",
		EventSheetDocReference.mark_help("⟳").begins_with("Runs every frame"), true) and all_passed
	all_passed = _check("a glyph that is not a mark says nothing",
		EventSheetDocReference.mark_help("Z"), "") and all_passed
	# Every mark the legend lists is one the hover can answer for, or the page and the sheet would
	# disagree about what a sheet draws.
	for entry: Dictionary in EventSheetDocReference.MARKS:
		all_passed = _check("the legend and the hover agree about %s" % str(entry.get("mark", "")),
			EventSheetDocReference.mark_help(str(entry.get("mark", ""))).is_empty(), false) and all_passed
	return all_passed


## The reader calls it the Manual, everywhere they can see it.
static func _test_the_word_manual() -> bool:
	var all_passed: bool = true
	var menu_code: String = _read("res://addons/eventsheet/editor/dock/menu_bar.gd")
	all_passed = _check("Tools opens the Manual",
		menu_code.contains("\"Manual…\", 22"), true) and all_passed
	var dock_code: String = _read("res://addons/eventsheet/editor/docs/doc_dock.gd")
	all_passed = _check("the dock is titled Manual",
		dock_code.contains("title = \"Manual\""), true) and all_passed
	all_passed = _check("and its layout key is untouched - renaming it loses every reader's layout",
		EventSheetDocDock.LAYOUT_KEY, "EventSheetsHelp") and all_passed
	var window_code: String = _read("res://addons/eventsheet/editor/docs/doc_window.gd")
	all_passed = _check("the window is titled Manual",
		window_code.contains("dialog.title = \"Manual\""), true) and all_passed
	all_passed = _check("and every trail starts there",
		EventSheetDocReference.MANUAL_TITLE, "Manual") and all_passed
	return all_passed


static func _event_using(provider_id: String, ace_id: String) -> EventRow:
	var event: EventRow = EventRow.new()
	var action: ACEAction = ACEAction.new()
	action.provider_id = provider_id
	action.ace_id = ace_id
	event.actions.append(action)
	return event


static func _read(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	return "" if file == null else file.get_as_text()


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("doc_manual_test", label, actual, expected)
