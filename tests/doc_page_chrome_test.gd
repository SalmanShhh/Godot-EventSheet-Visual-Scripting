# EventSheet - the reading surface's CHROME: the sidebar, the folds and the chapter strip.
#
# Everything pinned here is a DECISION rather than a pixel: which kind a page id belongs to (the
# sidebar's icons hang off it), how a group label is spelled, the width at which a host folds its
# sidebar away, whether a page is long enough to fold at all, and what folding then does to the
# page's own structure. The look those decisions produce is the harness's job
# (tools/render_docs_slice_preview.gd), because no headless run lays anything out or draws.
@tool
class_name DocPageChromeTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _test_sidebar_kinds() and all_passed
	all_passed = _test_compact_breakpoint() and all_passed
	all_passed = _test_long_page_decision() and all_passed
	all_passed = _test_folding() and all_passed
	all_passed = _test_outline_and_anchor() and all_passed
	all_passed = _test_nav_bearing() and all_passed
	return all_passed


## Which chapter the sticky strip lights up, as a pure function of where the headings are and where
## the reader is. The trap it exists for: before layout every Control reports position zero, so a
## naive "is this heading above me?" is true for EVERY heading at once and the last chapter of a
## freshly opened guide gets the highlight - the one place in the page the reader is definitely not.
static func _test_nav_bearing() -> bool:
	var all_passed: bool = true
	var tops: Array = [{"slug": "one", "top": 40.0}, {"slug": "two", "top": 300.0}, {"slug": "three", "top": 700.0}]
	all_passed = _check("a reader in the lead is heading into the first chapter",
		EventSheetDocPageView.section_for_offset(tops, 0.0), "one") and all_passed
	all_passed = _check("and in the first chapter once past its heading",
		EventSheetDocPageView.section_for_offset(tops, 120.0), "one") and all_passed
	all_passed = _check("the middle chapter is the one they are in",
		EventSheetDocPageView.section_for_offset(tops, 350.0), "two") and all_passed
	all_passed = _check("a heading exactly at the top counts as reached",
		EventSheetDocPageView.section_for_offset(tops, 300.0), "two") and all_passed
	all_passed = _check("the last chapter is only reached at the bottom",
		EventSheetDocPageView.section_for_offset(tops, 9000.0), "three") and all_passed
	all_passed = _check("a page with no chapters lights nothing",
		EventSheetDocPageView.section_for_offset([], 0.0), "") and all_passed
	# The guard itself: a page that has never been laid out has no bearing to give, and must say so
	# rather than answer from positions that are all zero.
	var page: EventSheetDocPageView = EventSheetDocPageView.new()
	page.show_blocks(_blocks(6, 8), "fixture-bearing")
	all_passed = _check("an unlaid-out page reports no bearing at all",
		page.section_at(0.0), "") and all_passed
	page.free()
	return all_passed


## The sidebar groups by KIND, and the kind comes from the page id alone - so a pack that ships a
## guide, a module guide and a shipped guide can never draw each other's icon.
static func _test_sidebar_kinds() -> bool:
	var all_passed: bool = true
	all_passed = _check("a shipped guide", EventSheetDocBrowser.kind_for_page("GUIDE-RECIPES"), "guide") and all_passed
	all_passed = _check("an addon guide", EventSheetDocBrowser.kind_for_page("Addons/Quest"), "addon") and all_passed
	all_passed = _check("a module guide", EventSheetDocBrowser.kind_for_page("Modules/Collections"), "module") and all_passed
	all_passed = _check("a pack's own guide", EventSheetDocBrowser.kind_for_page("Packs/grapple_hook"), "pack") and all_passed
	all_passed = _check("the reader's own notes", EventSheetDocBrowser.kind_for_page("Project/design"), "project") and all_passed
	all_passed = _check("group labels are small caps",
		EventSheetDocBrowser.group_label("  Getting started "), "GETTING STARTED") and all_passed
	# Every kind the mapping can answer has icon candidates, or a row would silently lose its mark.
	var firsts: Dictionary = {}
	for kind: String in ["guide", "addon", "module", "pack", "project"]:
		var candidates: Array = EventSheetDocBrowser.KIND_ICONS.get(kind, []) as Array
		all_passed = _check("icons offered for kind %s" % kind, candidates.is_empty(), false) and all_passed
		if not candidates.is_empty():
			firsts[str(candidates[0])] = true
	# And every kind's BEST icon is its own. A mark two kinds share is a mark that says nothing: the
	# reason the rows carry one is so the kind reads without reading the name.
	all_passed = _check("no two kinds wear the same best icon", firsts.size(), 5) and all_passed
	return all_passed


## The breakpoint a self-sizing host folds its sidebar at, as a pure function of width: a dock slot
## folds, a floated or dragged-wide one does not, and a host that has not been laid out yet (width
## zero) is not asked to decide anything.
static func _test_compact_breakpoint() -> bool:
	var all_passed: bool = true
	var edge: float = EventSheetPalette.scaled_f(EventSheetDocBrowser.AUTO_COMPACT_WIDTH)
	all_passed = _check("a dock-width column folds", EventSheetDocBrowser.wants_compact(edge - 1.0), true) and all_passed
	all_passed = _check("a wide host does not", EventSheetDocBrowser.wants_compact(edge + 1.0), false) and all_passed
	all_passed = _check("an unlaid-out host decides nothing",
		EventSheetDocBrowser.wants_compact(0.0), false) and all_passed
	return all_passed


## "Long enough to fold" is measured in estimated LINES, because a page is built before it is laid
## out and its real height does not exist at the moment the decision is made.
static func _test_long_page_decision() -> bool:
	var all_passed: bool = true
	var short_page: Array[Dictionary] = _blocks(2, 1)
	all_passed = _check("a short page is drawn whole",
		EventSheetDocPageView.is_long_page(short_page), false) and all_passed
	var long_page: Array[Dictionary] = _blocks(6, 8)
	all_passed = _check("a long page folds", EventSheetDocPageView.is_long_page(long_page), true) and all_passed
	all_passed = _check("an empty page is never long",
		EventSheetDocPageView.estimated_lines([] as Array[Dictionary]), 0) and all_passed
	# The estimate counts the blocks it is given, so a page that grew is never quietly still "short".
	all_passed = _check("more chapters is more page",
		EventSheetDocPageView.estimated_lines(long_page) > EventSheetDocPageView.estimated_lines(short_page),
		true) and all_passed
	return all_passed


## What folding does to the page: the chapter the reader lands in is open, the rest are closed, a
## toggle is remembered for the session, and expand_all opens everything (which is what a live
## search term asks for).
static func _test_folding() -> bool:
	var all_passed: bool = true
	var page: EventSheetDocPageView = EventSheetDocPageView.new()
	all_passed = _check("a short page draws no folds",
		page.show_blocks(_blocks(2, 1), "fixture-short") and page.is_folding(), false) and all_passed
	all_passed = _check("though it still knows its chapters", page.outline().size(), 2) and all_passed

	all_passed = _check("a long page draws", page.show_blocks(_blocks(6, 8), "fixture-long"), true) and all_passed
	all_passed = _check("it folds", page.is_folding(), true) and all_passed
	all_passed = _check("the chapter the reader lands in is open",
		page.is_section_expanded("chapter-1"), true) and all_passed
	all_passed = _check("the ones below the fold are closed",
		page.is_section_expanded("chapter-4"), false) and all_passed
	page.set_section_expanded("chapter-4", true)
	all_passed = _check("a chapter opens when asked", page.is_section_expanded("chapter-4"), true) and all_passed
	# Re-drawing the same page is what happens when the reader navigates away and back.
	page.show_blocks(_blocks(6, 8), "fixture-long")
	all_passed = _check("and is remembered for the session",
		page.is_section_expanded("chapter-4"), true) and all_passed
	all_passed = _check("while the rest stay as they were",
		page.is_section_expanded("chapter-3"), false) and all_passed
	page.expand_all()
	all_passed = _check("a search opens the whole page", page.is_section_expanded("chapter-3"), true) and all_passed
	page.free()
	return all_passed


## The chapter strip is built from the page's own outline, and a jump into a folded chapter opens
## it - including a jump to a deeper heading INSIDE one, which is what a link between guides does.
static func _test_outline_and_anchor() -> bool:
	var all_passed: bool = true
	var page: EventSheetDocPageView = EventSheetDocPageView.new()
	page.show_blocks(_blocks(6, 8), "fixture-outline")
	var outline: Array[Dictionary] = page.outline()
	all_passed = _check("one entry per chapter", outline.size(), 6) and all_passed
	all_passed = _check("in page order", str(outline[0].get("slug", "")), "chapter-1") and all_passed
	all_passed = _check("carrying the heading text", str(outline[2].get("text", "")), "Chapter 3") and all_passed
	all_passed = _check("a deeper heading is not a chapter",
		str(outline[1].get("slug", "")), "chapter-2") and all_passed

	page.set_section_expanded("chapter-5", false)
	# No scroll host, so the jump reports false - what is pinned here is the FOLD it opened, which
	# is the half that would otherwise land the reader on a title with nothing under it.
	page.jump_to_anchor("chapter-5-detail")
	all_passed = _check("a jump inside a folded chapter opens it",
		page.is_section_expanded("chapter-5"), true) and all_passed
	page.free()
	return all_passed


## A fixture page: a title, then `chapters` H2 chapters, each carrying `paragraphs` paragraphs and
## one deeper heading. Slugs are spelled the way the parser spells them, so the fold and the anchor
## assertions above are about real ids.
static func _blocks(chapters: int, paragraphs: int) -> Array[Dictionary]:
	var blocks: Array[Dictionary] = [
		{"kind": "heading", "level": 1, "text": "Fixture", "slug": "fixture"},
		{"kind": "paragraph", "bbcode": "The lead paragraph, which is never folded away."},
	]
	for index: int in range(chapters):
		var number: int = index + 1
		blocks.append({"kind": "heading", "level": 2, "text": "Chapter %d" % number, "slug": "chapter-%d" % number})
		for line: int in range(paragraphs):
			blocks.append({"kind": "paragraph", "bbcode": "Body text %d of chapter %d." % [line, number]})
		blocks.append({"kind": "heading", "level": 3, "text": "Detail %d" % number,
			"slug": "chapter-%d-detail" % number})
	return blocks


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] doc_page_chrome_test: %s" % label)
		return true
	print("[FAIL] doc_page_chrome_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
