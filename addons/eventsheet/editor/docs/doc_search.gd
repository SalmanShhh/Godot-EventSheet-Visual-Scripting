# EventSheet - EventSheetDocSearch: finding a page, and finding it ON the page.
#
# RichTextLabel has no find(): a reader who searches a guide gets whatever this file builds and
# nothing else. So search is two halves that never share state:
#
#   1. THE INDEX. One entry per page - its title, every heading with its slug, and a blob of the
#      page's unique words. The blob is the whole reason this is affordable: the corpus is about
#      4 MB of Markdown, and keeping the prose would cost that for the life of the editor, while
#      the unique words of a page are a fraction of it and answer the only question a body match
#      asks ("does this page talk about that word").
#   2. THE HIGHLIGHT. A hit is shown by RE-EMITTING the page's BBCode with [bgcolor] around the
#      matches. There is no post-hoc highlight API, and there is no way to ask a label to find
#      anything, so the search term is wrapped before the label ever sees the text.
#
# RANKING is the shape the command palette already established (prefix beats substring beats
# subsequence), extended with the one rule a doc corpus needs: WHERE the hit landed outranks HOW
# it matched. A page titled "Working with Lists" beats a page that merely mentions lists, and a
# heading beats body prose, because a reader searching "lists" wants the guide about them.
#
# Everything here is static and pure over its inputs. rank_pages() takes the index as an argument
# rather than reading it, so the suite pins the ORDER against a fixture of three pages instead of
# against whatever the corpus happens to contain this week.
@tool
class_name EventSheetDocSearch
extends RefCounted

## The scores, best first. They are ordinals, never weights: a caller sorts by them and the suite
## pins the resulting ORDER, so the gaps between them mean nothing and can be renumbered.
const SCORE_TITLE_PREFIX := 0
const SCORE_TITLE_SUBSTRING := 1
const SCORE_HEADING_PREFIX := 2
const SCORE_HEADING_SUBSTRING := 3
const SCORE_BODY := 4
const SCORE_TITLE_SUBSEQUENCE := 5
const SCORE_HEADING_SUBSEQUENCE := 6

## How many headings of one page a search may offer before the page starts crowding out the rest
## of the corpus. A reader looking for a word that appears in nine headings of one guide wants the
## guide, not nine rows of it.
const MAX_HEADINGS_PER_PAGE := 3

## The wrap a match gets in the page. Amber at 40% alpha on purpose: it is ALPHA, so it tints
## whatever the reader's editor theme paints behind it instead of assuming a dark background and
## turning light-theme prose into an unreadable block of colour.
const HIGHLIGHT_BGCOLOR := "#c8a13a66"

## Built on the first search of a session and dropped by reload(), the same discipline the library
## uses for its manifest. Building it reads every page once.
static var _index: Array[Dictionary] = []
static var _index_built: bool = false
## How many pages the library offered when the index was built. A corpus that grew or shrank since
## - a pack guide dropped in, a rebuilt bundle - rebuilds rather than searching a stale list, and
## the check itself is a walk over ids the library already has in hand.
static var _indexed_page_count: int = 0


## The whole corpus as search entries, built once per session:
##   {id, title, title_lower, headings:[{text, slug, lower}], words}
## `words` is a blob of the page's unique lowercase words, each surrounded by spaces, so a
## word-prefix test is one native find() instead of a loop over a Dictionary.
## The SHIPPED half of it is BAKED (addons/eventsheet/help/search.esdoc, written by the bundle
## build): a keystroke then searches a table that was read once, rather than paying for ~4 MB of
## Markdown to be read and split into words on the reader's first keypress. Only the pages the
## bundle cannot know about - a pack's own guide.md, the project's own notes - are indexed live,
## and there are a handful of those.
static func index() -> Array[Dictionary]:
	var ids: PackedStringArray = EventSheetDocLibrary.page_ids()
	if _index_built and _indexed_page_count == ids.size():
		return _index
	_index_built = true
	_indexed_page_count = ids.size()
	_index = []
	var baked: Dictionary = {}
	for entry: Variant in EventSheetDocLibrary.search_entries():
		var page: Dictionary = rehydrated(entry as Dictionary)
		var id: String = str(page.get("id", ""))
		if not id.is_empty():
			baked[id] = page
	for id: String in ids:
		if baked.has(id):
			_index.append(baked[id] as Dictionary)
			continue
		var source: String = EventSheetDocLibrary.page_source(id)
		if source.is_empty():
			continue
		_index.append(entry_for(id, EventSheetDocLibrary.page_title(id), source))
	return _index


## One baked entry, with the lowercase copies the ranking compares against put back. They are
## DERIVED rather than baked because they are exactly the title and the heading text again: baking
## them would nearly double the file to store a fact it already carries, and a baked lowercase copy
## that disagreed with its own source would be a second store of the same fact.
static func rehydrated(entry: Dictionary) -> Dictionary:
	var headings: Array[Dictionary] = []
	for found: Variant in (entry.get("headings", []) as Array):
		var heading: Dictionary = (found as Dictionary).duplicate()
		heading["lower"] = str(heading.get("text", "")).to_lower()
		headings.append(heading)
	var title: String = str(entry.get("title", ""))
	return {
		"id": str(entry.get("id", "")),
		"title": title,
		"title_lower": title.to_lower(),
		"headings": headings,
		"words": str(entry.get("words", "")),
	}


## The inverse: one index entry stripped to what the bundle stores.
static func baked(entry: Dictionary) -> Dictionary:
	var headings: Array = []
	for found: Variant in (entry.get("headings", []) as Array):
		var heading: Dictionary = found as Dictionary
		headings.append({"text": str(heading.get("text", "")), "slug": str(heading.get("slug", ""))})
	return {
		"id": str(entry.get("id", "")),
		"title": str(entry.get("title", "")),
		"headings": headings,
		"words": str(entry.get("words", "")),
	}


## The baked index's exact bytes: the frozen header line, then the payload. `entries` is expected in
## the order the caller wants them stored, and every collection inside one entry is already built in
## document (headings) or sorted (words) order, so two builds over the same corpus write the same
## file.
static func bundle_text(entries: Array) -> String:
	var pages: Array = []
	for entry: Variant in entries:
		pages.append(baked(entry as Dictionary))
	return "%s\n%s\n" % [EventSheetDocLibrary.SEARCH_HEADER,
		var_to_str({"version": 1, "pages": pages})]


## ONE page's entry, rebuilt in place - the whole cost of saving a sheet whose page changed.
##
## The alternative is dropping the index and paying for the whole corpus to be re-read on the next
## keystroke, which is a project-sized cost for a one-page edit and gets worse the bigger the project
## grows. Nothing else about the index moves: the entry keeps its position, so the search's tie-break
## by document order is unchanged.
##
## An index that has not been built yet is left alone: it will read the new page when it is built,
## and building it here would pay the whole cost this function exists to avoid.
static func refresh_page(page_id: String, title: String, source: String) -> bool:
	var id: String = page_id.strip_edges()
	if id.is_empty() or not _index_built:
		return false
	var entry: Dictionary = entry_for(id, title, source)
	for index: int in range(_index.size()):
		if str(_index[index].get("id", "")) == id:
			_index[index] = entry
			return true
	_index.append(entry)
	# The guard in index() counts the ids the LIBRARY offers, not the entries this array holds, and
	# the two are not the same number: an id whose file cannot be read is skipped when the index is
	# built, so a corpus with one of those has fewer entries than ids. Recording the entry count
	# here would therefore leave the two disagreeing, and the very next read would decide the corpus
	# had changed, rebuild, and throw this refresh away - which is the whole thing this function
	# exists to avoid. The library's own count is what the guard compares against, so that is what
	# is recorded.
	_indexed_page_count = EventSheetDocLibrary.page_ids().size()
	return true


## Drops the index, so a rebuilt bundle (or a pack guide dropped into the project) is searchable
## without an editor restart.
static func reload() -> void:
	_index_built = false
	_indexed_page_count = 0
	_index = []


## One page's index entry. Public and pure so a test can build an entry from a fixture string
## rather than from whatever ships.
static func entry_for(id: String, title: String, source: String) -> Dictionary:
	var headings: Array[Dictionary] = []
	var used: Dictionary = {}
	for line: String in source.replace("\r\n", "\n").split("\n"):
		var stripped: String = line.strip_edges()
		if not stripped.begins_with("##"):
			continue
		var level: int = 0
		while level < stripped.length() and stripped[level] == "#":
			level += 1
		if level >= stripped.length() or stripped[level] != " ":
			continue
		var text: String = EventSheetDocMarkdown.plain_text(stripped.substr(level + 1).strip_edges())
		var slug: String = EventSheetDocMarkdown.slug_in_page(stripped.substr(level + 1).strip_edges(), used)
		if text.is_empty():
			continue
		headings.append({"text": text, "slug": slug, "lower": text.to_lower()})
	return {
		"id": id,
		"title": title,
		"title_lower": title.to_lower(),
		"headings": headings,
		"words": word_blob(source),
	}


## Everything that is not a letter, a digit or an underscore, compiled once. See word_blob.
static var _word_splitter: RegEx = null


## The unique lowercase words of a page, each padded with spaces (" list append "), so
## `blob.find(" " + token)` answers "does any word here start with that". Everything that is not
## a letter, a digit or an underscore separates words, which is what makes "arr.append(x)" index
## as `arr`, `append` and `x`.
##
## The split is done by a RegEx rather than by a per-character loop, and that is not a style
## choice: the corpus is megabytes of Markdown, and walking it one GDScript String index at a time
## costs over a second of frozen editor on the reader's FIRST keystroke - the one moment the whole
## index gets built. The engine's own scanner does the same work in a fraction of it.
static func word_blob(text: String) -> String:
	if _word_splitter == null:
		_word_splitter = RegEx.create_from_string("[^a-z0-9_]+")
	var seen: Dictionary = {}
	for word: String in _word_splitter.sub(text.to_lower(), " ", true).split(" ", false):
		seen[word] = true
	var words: PackedStringArray = PackedStringArray()
	for word: Variant in seen:
		words.append(str(word))
	words.sort()
	return " %s " % " ".join(words)


## The corpus, searched. Each result is a row a caller can act on without asking anything else:
##   {doc_id, page_id, title, heading, anchor, score}
## `doc_id` is the frozen public form ("guide:<page id>"), so a result feeds straight into
## EventSheets.open_docs(doc_id, anchor).
static func search(query: String, limit: int = 25) -> Array[Dictionary]:
	return rank_pages(index(), query, limit)


## The ranking, pure over a supplied index. A caller passes the live index; the suite passes three
## fixture pages and pins the order they come back in.
##
## An EMPTY query is not a miss - it lists every page by title, which is what makes the palette's
## "?" show the guide list the moment it is typed.
static func rank_pages(pages: Array[Dictionary], query: String, limit: int = 25) -> Array[Dictionary]:
	var wanted: String = query.strip_edges().to_lower()
	var results: Array[Dictionary] = []
	for order: int in range(pages.size()):
		var page: Dictionary = pages[order]
		if wanted.is_empty():
			results.append(_result(page, {}, SCORE_TITLE_PREFIX, order))
			continue
		results.append_array(_results_for_page(page, wanted, order))
	results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["score"]) != int(b["score"]):
			return int(a["score"]) < int(b["score"])
		if int(a["order"]) != int(b["order"]):
			return int(a["order"]) < int(b["order"])
		return str(a["heading"]) < str(b["heading"]))
	if limit > 0 and results.size() > limit:
		results.resize(limit)
	return results


## Every way one page answers a query, best first: its title, then up to MAX_HEADINGS_PER_PAGE of
## its headings, then its body words.
##
## The body hit is not simply "the fallback when nothing else matched", and getting that wrong is
## subtle: a SUBSEQUENCE match on a title or a heading scores WORSE than a body hit (scattered
## letters are the weakest evidence there is), and almost any short query subsequence-matches
## almost any title. So a page that is genuinely about the word - it says it, spelled out, in its
## prose - would be demoted below pages that merely contain its letters in order. When the only
## thing a page offered was that scattered-letter match, the body hit REPLACES it.
static func _results_for_page(page: Dictionary, wanted: String, order: int) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var title_score: int = match_score(str(page.get("title_lower", "")), wanted)
	if title_score >= 0:
		found.append(_result(page, {}, _title_score(title_score), order))
	var headings: Array = page.get("headings", []) as Array
	var heading_hits: int = 0
	for entry: Variant in headings:
		if heading_hits >= MAX_HEADINGS_PER_PAGE:
			break
		var heading: Dictionary = entry as Dictionary
		var score: int = match_score(str(heading.get("lower", "")), wanted)
		if score < 0:
			continue
		heading_hits += 1
		found.append(_result(page, heading, _heading_score(score), order))
	if not matches_body(str(page.get("words", "")), wanted):
		return found
	if found.is_empty():
		found.append(_result(page, {}, SCORE_BODY, order))
		return found
	if _best_score(found) > SCORE_BODY:
		return [_result(page, {}, SCORE_BODY, order)] as Array[Dictionary]
	return found


## The best (numerically lowest) score among a page's results.
static func _best_score(found: Array[Dictionary]) -> int:
	var best: int = SCORE_HEADING_SUBSEQUENCE
	for result: Dictionary in found:
		best = mini(best, int(result.get("score", SCORE_HEADING_SUBSEQUENCE)))
	return best


## True when every word of the query starts a word somewhere on the page. Whole tokens rather than
## a raw substring: "set var" must not match a page merely because it contains "offset variance".
static func matches_body(words: String, wanted: String) -> bool:
	if wanted.is_empty():
		return true
	for token: String in wanted.split(" ", false):
		if words.find(" %s" % token) < 0:
			return false
	return true


## Prefix (0), substring (1), subsequence (2) or miss (-1) - the palette's own scoring, so the two
## surfaces agree about what "matching" means.
static func match_score(haystack: String, wanted: String) -> int:
	if wanted.is_empty():
		return 0
	if haystack.begins_with(wanted):
		return 0
	if haystack.contains(wanted):
		return 1
	var index: int = 0
	for position: int in range(wanted.length()):
		var found: bool = false
		while index < haystack.length():
			if haystack[index] == wanted[position]:
				found = true
				index += 1
				break
			index += 1
		if not found:
			return -1
	return 2


static func _title_score(kind: int) -> int:
	match kind:
		0:
			return SCORE_TITLE_PREFIX
		1:
			return SCORE_TITLE_SUBSTRING
	return SCORE_TITLE_SUBSEQUENCE


static func _heading_score(kind: int) -> int:
	match kind:
		0:
			return SCORE_HEADING_PREFIX
		1:
			return SCORE_HEADING_SUBSTRING
	return SCORE_HEADING_SUBSEQUENCE


static func _result(page: Dictionary, heading: Dictionary, score: int, order: int) -> Dictionary:
	var id: String = str(page.get("id", ""))
	return {
		"doc_id": "guide:%s" % id,
		"page_id": id,
		"title": str(page.get("title", id)),
		"heading": str(heading.get("text", "")),
		"anchor": str(heading.get("slug", "")),
		"score": score,
		"order": order,
	}


# ── One box over the whole Manual ─────────────────────────────────────────────────────────────
#
# The corpus search above answers "which PAGE talks about this". A reader typing into the Manual is
# usually asking something narrower and more useful - "what is the thing called" - and the answer
# is as often a condition, an action or a word from another editor's vocabulary as it is a page.
# So one box searches all of it and TAGS what it found, in the Manual's own words: condition,
# action, expression, guide, System reference, behavior reference, engine reference, glossary.
#
# Each row carries everything a caller needs to act without asking anything else - the doc id to
# open, and (for a verb) the definition, so the result can draw the example rows inline and add
# them to the sheet at the caret.


## The result kinds, in the order a tie between two equally good matches is broken. Verbs first
## because they are what a reader is usually naming, and the glossary last because it translates a
## word rather than answering with one.
const KIND_ORDER: Array[String] = [
	"trigger", "condition", "action", "expression", "guide", "reference", "behavior",
	"glossary", "engine", "ask",
]

## The kinds that sort BELOW every answer this plugin has of its own, whatever they scored. The
## engine's class reference is a real answer and often an exact one - a reader who types "Node2D"
## gets a perfect prefix match on the class - but it is one hop further out than the sheet's own
## words, so a guide about the thing wins over the class the thing is built on. The offer to ask for
## a page that does not exist yet sorts under everything, because it is the answer of last resort.
const DEMOTED_KINDS: Array[String] = ["engine", "ask"]

## How many rows at the foot of a full list are kept for the demoted kinds. Without it, ranking them
## below the plugin's own answers and then cutting the list to a screenful means they are never seen
## at all: a corpus this size answers a common word with a dozen guides before the engine's class
## for it gets a look in.
const DEMOTED_RESERVE := 3

## The row a query with no answers gets: an offer to ask for the page, filed through the same
## channel the foot of every page already uses. `doc_id` is empty on purpose - there is no page to
## open, and a caller tells this row apart by its kind rather than by a magic address.
const KIND_ASK := "ask"

## How many nearest sections a query with no real hits is offered before the offer to ask. Enough to
## be a direction, few enough that a reader can see they are guesses.
const MAX_NEAREST := 5

## How alike a page title or heading has to be to a query with no hits before it is offered as a
## nearest section. Below this the row is noise wearing the shape of an answer.
const NEAREST_SIMILARITY := 0.35

## The words the result rows are tagged with, per kind. The Manual's own vocabulary: these are the
## same words its tree uses, so a tag names a place the reader can go rather than a category only
## this file knows about.
const KIND_LABELS := {
	"trigger": "trigger", "condition": "condition", "action": "action", "expression": "expression",
	"guide": "guide", "reference": "System reference", "behavior": "behavior reference",
	"engine": "engine reference", "glossary": "glossary", "ask": "ask for this page",
}

## How many engine classes and glossary terms one query may offer. Both lists are long and neither
## is what the reader is usually after; a couple of rows is a pointer, ten is a wall.
const MAX_ENGINE_HITS := 4
const MAX_GLOSSARY_HITS := 4
## The same budget for the behavior index: a pointer, never a wall.
const MAX_BEHAVIOR_INDEX_HITS := 4


## The whole Manual, searched. Each row is {kind, title, subtitle, doc_id, anchor, definition,
## used, score}: `kind` is one of KIND_ORDER, `used` is how many events of `sheet` already use that
## verb (0 for everything else), and `definition` is the ACEDefinition for a verb row so the
## caller can draw its example and add it.
static func search_all(query: String, sheet: EventSheetResource = null, limit: int = 30) -> Array[Dictionary]:
	var wanted: String = query.strip_edges().to_lower()
	var results: Array[Dictionary] = []
	if wanted.is_empty():
		return results
	results.append_array(_vocabulary_hits(wanted, sheet))
	results.append_array(_page_hits(query))
	results.append_array(_reference_hits(wanted))
	results.append_array(_engine_hits(wanted))
	results.append_array(_glossary_hits(wanted))
	results.append_array(_godot_word_hits(query))
	results.append_array(_behavior_index_hits(wanted))
	results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		# The demoted kinds sort below everything this plugin can answer itself, whatever they
		# scored: an exact hit on an engine class name is still one hop further out than a guide
		# that talks about the same thing in the sheet's own words.
		var demoted_a: bool = DEMOTED_KINDS.has(str(a["kind"]))
		var demoted_b: bool = DEMOTED_KINDS.has(str(b["kind"]))
		if demoted_a != demoted_b:
			return demoted_b
		if int(a["score"]) != int(b["score"]):
			return int(a["score"]) < int(b["score"])
		var kind_a: int = KIND_ORDER.find(str(a["kind"]))
		var kind_b: int = KIND_ORDER.find(str(b["kind"]))
		if kind_a != kind_b:
			return kind_a < kind_b
		return str(a["title"]) < str(b["title"]))
	# NO EMPTY RESULTS, EVER. A search box that answers a real question with a blank panel tells the
	# reader the question was wrong; it is far likelier the corpus is. So a query nothing matched
	# gets the sections that come nearest, and under them the offer to ask for the page.
	if results.is_empty():
		results.append_array(nearest_sections(wanted))
		results.append(ask_row(query))
	return _trimmed(results, limit)


## The list cut to `limit`, with room KEPT for the demoted kinds. Ranking them below the plugin's
## own answers is right; dropping them off the end of the list is not, and a corpus this size makes
## that the normal outcome - "timer" alone answers with fourteen guides and pack references before
## the engine's Timer class gets a look in. So the last few rows belong to the demoted kinds
## whenever there are any, and it is the weakest of the plugin's own answers that goes instead.
static func _trimmed(results: Array[Dictionary], limit: int) -> Array[Dictionary]:
	if limit <= 0 or results.size() <= limit:
		return results
	var own: Array[Dictionary] = []
	var demoted: Array[Dictionary] = []
	for row: Dictionary in results:
		if DEMOTED_KINDS.has(str(row.get("kind", ""))):
			demoted.append(row)
		else:
			own.append(row)
	if demoted.is_empty():
		own.resize(limit)
		return own
	if demoted.size() > DEMOTED_RESERVE:
		demoted.resize(DEMOTED_RESERVE)
	if own.size() > limit - demoted.size():
		own.resize(limit - demoted.size())
	own.append_array(demoted)
	return own


## The sections that come NEAREST a query nothing matched, best first. Similarity rather than the
## matching above on purpose: the matching has already said no, and what is left to offer is "this
## is the closest thing the corpus has" - a misspelling, a plural, a word from another editor.
##
## Pure over a supplied index for the same reason rank_pages is, so the suite pins which fixture
## page a misspelling reaches for.
static func nearest_sections(query: String, pages: Array[Dictionary] = index()) -> Array[Dictionary]:
	var wanted: String = query.strip_edges().to_lower()
	if wanted.is_empty():
		return []
	var scored: Array[Dictionary] = []
	for order: int in range(pages.size()):
		var page: Dictionary = pages[order]
		var best: float = str(page.get("title_lower", "")).similarity(wanted)
		var heading: Dictionary = {}
		for found: Variant in (page.get("headings", []) as Array):
			var candidate: float = str((found as Dictionary).get("lower", "")).similarity(wanted)
			if candidate > best:
				best = candidate
				heading = found as Dictionary
		if best < NEAREST_SIMILARITY:
			continue
		var title: String = str(page.get("title", ""))
		var heading_text: String = str(heading.get("text", ""))
		scored.append({
			"kind": _kind_for_page(str(page.get("id", ""))),
			"title": title if heading_text.is_empty() else "%s ▸ %s" % [title, heading_text],
			"subtitle": "nothing matched exactly - this is the nearest section",
			"doc_id": "guide:%s" % str(page.get("id", "")),
			"anchor": str(heading.get("slug", "")),
			"definition": null, "used": 0, "score": SCORE_BODY,
			# Sorted on, then dropped: a caller reads `score` like every other row.
			"similarity": best, "order": order,
		})
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if not is_equal_approx(float(a["similarity"]), float(b["similarity"])):
			return float(a["similarity"]) > float(b["similarity"])
		return int(a["order"]) < int(b["order"]))
	if scored.size() > MAX_NEAREST:
		scored.resize(MAX_NEAREST)
	for row: Dictionary in scored:
		row.erase("similarity")
		row.erase("order")
	return scored


## The offer of last resort: ask for the page that does not exist. It carries the query the reader
## typed so the caller files THAT rather than making them type it again, and it goes through the
## channel the foot of every page already uses - there is one way to answer this documentation back,
## not two.
static func ask_row(query: String) -> Dictionary:
	return {
		"kind": KIND_ASK,
		"title": "Ask for a page about \"%s\"" % query.strip_edges(),
		"subtitle": "opens the tracker with your search already in the title",
		"doc_id": "", "anchor": "", "definition": null, "used": 0,
		"score": SCORE_HEADING_SUBSEQUENCE, "query": query.strip_edges(),
	}


## The word a result kind is tagged with. "" for a kind this build does not know, so a caller
## draws no tag rather than an invented one.
static func kind_label(kind: String) -> String:
	return str(KIND_LABELS.get(kind.strip_edges(), ""))


## The live vocabulary. Empty outside the editor, where there is no registry - which is exactly
## when the corpus half of the search is the whole answer.
static func _vocabulary_hits(wanted: String, sheet: EventSheetResource) -> Array[Dictionary]:
	var hits: Array[Dictionary] = []
	for definition: ACEDefinition in EventSheets.all_verbs():
		var title: String = EventSheetL10n.translate(definition.display_name)
		var score: int = match_score(title.to_lower(), wanted)
		if score < 0:
			continue
		var pack_dir: String = EventSheets.addon_pack_directory(definition.provider_id)
		var home: String = EventSheetDocReference.PACK_TREE_TITLE if not pack_dir.is_empty() \
			else EventSheetDocReference.SECTION_TREE_TITLE
		hits.append({
			"kind": EventSheetDocExplain.type_label(definition.ace_type).to_lower(),
			"title": title,
			"subtitle": "%s ▸ %s" % [home, EventSheetDocExplain.category_of(definition)],
			"doc_id": EventSheetDocExplain.doc_id_for_definition(definition),
			"anchor": "",
			"definition": definition,
			"used": EventSheetDocUsage.count(sheet, definition.provider_id, definition.id),
			"score": score,
		})
	return hits


## The written corpus, tagged by what kind of page each hit lives on: a pack's guide reads as
## behavior reference, a module's as System reference, and everything else as a guide.
static func _page_hits(query: String) -> Array[Dictionary]:
	var hits: Array[Dictionary] = []
	for result: Dictionary in search(query):
		var page_id: String = str(result.get("page_id", ""))
		var heading: String = str(result.get("heading", ""))
		var title: String = str(result.get("title", page_id))
		hits.append({
			"kind": _kind_for_page(page_id),
			"title": title if heading.is_empty() else "%s ▸ %s" % [title, heading],
			"subtitle": "",
			"doc_id": str(result.get("doc_id", "")),
			"anchor": str(result.get("anchor", "")),
			"definition": null,
			"used": 0,
			"score": int(result.get("score", SCORE_BODY)),
		})
	return hits


## The derived reference pages - one per category, one per behavior - so a reader typing a pack's
## name lands on its reference even when it ships no written guide at all.
static func _reference_hits(wanted: String) -> Array[Dictionary]:
	var hits: Array[Dictionary] = []
	for section: String in EventSheetDocReference.section_names():
		var score: int = match_score(section.to_lower(), wanted)
		# Substring and better only. A reference page is named after a category or a behavior, and a
		# SUBSEQUENCE match against ninety of those answers "wait" with every name that happens to
		# carry a w, an a, an i and a t in order - which buries the four rows the reader wanted.
		if score >= 0 and score <= 1:
			hits.append(_reference_row("reference", section,
				EventSheetDocReference.SECTION_TREE_TITLE,
				EventSheetDocReference.doc_id(EventSheetDocReference.KIND_SECTION, section), score))
	for pack_dir: String in EventSheetDocReference.pack_names():
		var title: String = EventSheetDocReference.pack_title(pack_dir)
		var score: int = match_score(title.to_lower(), wanted)
		if score >= 0 and score <= 1:
			hits.append(_reference_row("behavior", title,
				EventSheetDocReference.PACK_TREE_TITLE,
				EventSheetDocReference.doc_id(EventSheetDocReference.KIND_PACK, pack_dir), score))
	return hits


static func _reference_row(kind: String, title: String, home: String, doc_id: String, score: int) -> Dictionary:
	return {
		"kind": kind, "title": title, "subtitle": home, "doc_id": doc_id, "anchor": "",
		"definition": null, "used": 0, "score": score,
	}


## The engine's own class reference, one hop further out. Class NAMES only: a reader who types
## "create_timer" is helped by being pointed at SceneTree, and walking every method of every class
## on a keystroke is not a search box, it is a stall.
static func _engine_hits(wanted: String) -> Array[Dictionary]:
	var hits: Array[Dictionary] = []
	if wanted.length() < 3:
		return hits
	for class_id: String in ClassDB.get_class_list():
		var score: int = match_score(class_id.to_lower(), wanted)
		# Substring and better only: a subsequence match against a thousand class names offers
		# rows that share nothing with the query but their letters.
		if score < 0 or score > 1:
			continue
		# The engine's OWN one-line description when this machine has harvested it, and the plain
		# label when it has not. The harvest is started here rather than waited on: a reader who
		# searches for a class gets the row now and its text the next time they ask.
		var brief: String = str(EventSheetDocEngineReference.class_doc(class_id).get("brief", ""))
		hits.append({
			"kind": "engine", "title": class_id,
			"subtitle": brief if not brief.is_empty() else "Godot class reference",
			"doc_id": EventSheetDocEngineReference.doc_id(class_id), "anchor": "",
			"definition": null, "used": 0, "score": score,
			# THE CREDIT RIDES WITH THE TEXT. `brief` is the engine's own sentence, published under
			# CC BY 4.0, and attribution is a term of that licence rather than a courtesy. A row
			# showing the plain fallback label quotes nothing, so it carries no credit either.
			"credit": EventSheetDocEngineReference.CREDIT_LINE if not brief.is_empty() else "",
		})
		if hits.size() >= MAX_ENGINE_HITS:
			break
	if not hits.is_empty():
		EventSheetDocEngineReference.begin_harvest()
	return hits


## The words another event-sheet editor spells differently.
static func _glossary_hits(wanted: String) -> Array[Dictionary]:
	var hits: Array[Dictionary] = []
	for entry: Dictionary in EventSheetDocGlossary.find(wanted):
		var term: String = str(entry.get("term", ""))
		hits.append({
			"kind": "glossary", "title": "\"%s\" - the same word here" % term.to_lower(),
			"subtitle": str(entry.get("here", "")),
			"doc_id": EventSheetDocReference.doc_id(EventSheetDocReference.KIND_GLOSSARY,
				str(entry.get("key", ""))),
			"anchor": str(entry.get("key", "")), "definition": null, "used": 0,
			"score": match_score(term.to_lower(), wanted),
		})
		if hits.size() >= MAX_GLOSSARY_HITS:
			break
	return hits


## The glossary answers GODOT words too. A reader who types `queue_free` is asking the same
## question the glossary answers for someone arriving from another event-sheet editor ("what is
## this called here"), so the answer wears the same tag: the rows that write that call, named the
## way the sheet names them, with the reading's own idiom words when a table names it as well.
static func _godot_word_hits(query: String) -> Array[Dictionary]:
	var hits: Array[Dictionary] = []
	if not EventSheetCodeSearch.is_code_query(query):
		return hits
	var call: String = EventSheetCodeSearch.normalize(query)
	for definition: ACEDefinition in EventSheetCodeSearch.matching_definitions(
			EventSheets.all_verbs(), call):
		hits.append({
			"kind": "glossary",
			"title": "\"%s\" - the same call here" % call,
			"subtitle": "%s   %s" % [EventSheetL10n.translate(definition.display_name),
				EventSheetCodeSearch.gdscript_hint(definition, call)],
			"doc_id": EventSheetDocExplain.doc_id_for_definition(definition),
			"anchor": "", "definition": definition, "used": 0,
			"score": SCORE_TITLE_PREFIX,
		})
		if hits.size() >= MAX_GLOSSARY_HITS:
			break
	var words: String = EventSheetCodeSearch.idiom_words(call)
	if not words.is_empty():
		hits.append({
			"kind": "glossary",
			"title": "\"%s\" - the same call here" % call,
			"subtitle": "the sheet reads it \"%s\"" % words,
			"doc_id": EventSheetDocReference.doc_id(EventSheetDocReference.KIND_DICTIONARY, ""),
			"anchor": "", "definition": null, "used": 0,
			"score": SCORE_TITLE_PREFIX,
		})
	return hits


## The behaviors another event-sheet editor's user arrives holding the names of. Tagged with the
## SAME "glossary" kind as the words above, deliberately: to the reader typing "8 Direction" both
## lists are answering one question - "what is this called here?" - and splitting them into two
## result groups would only ask them to know which half their word lived in.
static func _behavior_index_hits(wanted: String) -> Array[Dictionary]:
	var hits: Array[Dictionary] = []
	if wanted.strip_edges().is_empty():
		return hits
	for behavior: Dictionary in EventSheetDocBehaviorIndex.find(wanted):
		var name_text: String = str(behavior.get("name", ""))
		hits.append({
			"kind": "glossary", "title": "\"%s\" - the behavior here" % name_text,
			"subtitle": str(behavior.get("here", "")),
			"doc_id": EventSheetDocReference.doc_id(EventSheetDocReference.KIND_BEHAVIOR_INDEX,
				str(behavior.get("key", ""))),
			"anchor": str(behavior.get("key", "")), "definition": null, "used": 0,
			"score": match_score(name_text.to_lower(), wanted),
		})
		if hits.size() >= MAX_BEHAVIOR_INDEX_HITS:
			break
	return hits


## Which result kind a shipped page belongs to, from its id alone - a pack's guide is behavior
## reference, a module's is System reference, everything else is a guide. Spelled out here rather
## than asked of the sidebar on purpose: the sidebar reads this file, and a class that read it back
## would be a cycle.
static func _kind_for_page(page_id: String) -> String:
	var id: String = page_id.strip_edges()
	if id.begins_with("%s/" % EventSheetDocLibrary.ADDONS_DIR) or id.begins_with("%s/" % EventSheetDocLibrary.PACKS_SET):
		return "behavior"
	if id.begins_with("%s/" % EventSheetDocLibrary.MODULES_DIR):
		return "reference"
	return "guide"


# ── Highlighting ──────────────────────────────────────────────────────────────────────────────


## A whole parsed page, re-emitted with every hit wrapped. Blocks are copied rather than edited:
## the library hands out freshly parsed blocks, but a caller that cached a page would otherwise
## find its cache permanently highlighted for a query nobody is searching any more.
static func highlight_blocks(blocks: Array[Dictionary], query: String) -> Array[Dictionary]:
	var wanted: String = query.strip_edges()
	if wanted.is_empty():
		return blocks
	var out: Array[Dictionary] = []
	for block: Dictionary in blocks:
		var copy: Dictionary = block.duplicate(true)
		match str(copy.get("kind", "")):
			"paragraph", "quote":
				copy["bbcode"] = highlight_bbcode(str(copy.get("bbcode", "")), wanted)
			"list":
				var items: Array = copy.get("items", []) as Array
				for index: int in range(items.size()):
					var item: Dictionary = items[index] as Dictionary
					item["bbcode"] = highlight_bbcode(str(item.get("bbcode", "")), wanted)
			"table":
				copy["headers"] = _highlight_cells(copy.get("headers", []) as Array, wanted)
				var rows: Array = copy.get("rows", []) as Array
				for index: int in range(rows.size()):
					rows[index] = _highlight_cells(rows[index] as Array, wanted)
		out.append(copy)
	return out


static func _highlight_cells(cells: Array, wanted: String) -> Array:
	var out: Array = []
	for cell: Variant in cells:
		out.append(highlight_bbcode(str(cell), wanted))
	return out


## One run of BBCode with `wanted` wrapped in [bgcolor], case-insensitively.
##
## The scan steps OVER tags: a bracketed run is copied verbatim and never searched, so a query
## like "b" cannot land inside [b] and split it into nonsense, and the [lb] / [rb] escapes the
## parser writes for literal brackets stay whole. That also means a match is never inserted
## between a tag and the text it opens.
static func highlight_bbcode(bbcode: String, query: String) -> String:
	var wanted: String = query.strip_edges().to_lower()
	if wanted.is_empty() or bbcode.is_empty():
		return bbcode
	var out: String = ""
	var index: int = 0
	while index < bbcode.length():
		if bbcode[index] == "[":
			var close: int = bbcode.find("]", index)
			if close < 0:
				out += bbcode.substr(index)
				break
			out += bbcode.substr(index, close - index + 1)
			index = close + 1
			continue
		var next_tag: int = bbcode.find("[", index)
		var run_end: int = bbcode.length() if next_tag < 0 else next_tag
		out += _highlight_run(bbcode.substr(index, run_end - index), wanted)
		index = run_end
	return out


## A plain (tag-free) run with every case-insensitive occurrence of `wanted` wrapped. The ORIGINAL
## text is what gets wrapped, never the lowercased copy the search ran on, so highlighting a word
## never changes how it is spelled.
static func _highlight_run(run: String, wanted: String) -> String:
	var lowered: String = run.to_lower()
	if not lowered.contains(wanted):
		return run
	var out: String = ""
	var index: int = 0
	while index < run.length():
		var hit: int = lowered.find(wanted, index)
		if hit < 0:
			out += run.substr(index)
			break
		out += run.substr(index, hit - index)
		out += "[bgcolor=#%s]%s[/bgcolor]" % [_highlight_hex(), run.substr(hit, wanted.length())]
		index = hit + wanted.length()
	return out


## The amber behind a search hit, as the hex BBCode wants. The Manual's theme token wins when the
## reader picked a theme that has an opinion; otherwise the shipped amber stands.
static func _highlight_hex() -> String:
	var themed: Color = EventSheetActiveTheme.manual().resolve_search_hit(Color(HIGHLIGHT_BGCOLOR))
	return themed.to_html(true)
