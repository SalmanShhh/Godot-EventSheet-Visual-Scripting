# EventSheet - EventSheetDocTeaches: the other two depths of a verb's answer.
#
# A reader who points at a row and asks what it is wants one of three things, and which one depends
# on how much they already know:
#
#   the entry     what this verb IS - its description, its syntax, its values. Already assembled by
#                 EventSheetDocExplain, and the depth a reader who knows the vocabulary wants.
#   the section   the part of a written guide that TEACHES it, for a reader who does not yet know
#                 why they would reach for it.
#   the strip     what the Parameters dialog says about each of its fields, for a reader who is
#                 about to fill one in.
#
# The three are one panel rather than three places to look, and NONE of them is stored twice. The
# section is a join against the Manual's own baked search index - the same table a keystroke in the
# search box ranks - so a guide that renames a heading renames it here. The strip's sentences are
# read out of the very table the dialog reads, so the dialog's foot and this panel can never say
# different things about the same field.
#
# Everything here is STATIC and PURE over its inputs where it can be: the ranking takes results as
# an argument, so the choice of section is pinned by the suite with no bundle around it.
@tool
class_name EventSheetDocTeaches
extends RefCounted

## How many ranked results the section join looks at. The answer is the best one; reading past the
## first handful only ever picks a worse page.
const SECTION_CANDIDATES := 8

## The weakest evidence a section is allowed to be chosen on. A subsequence match on a title (the
## query's letters scattered through it, in order) matches almost every page for almost every
## query, so a section chosen on one would be a confident-looking wrong answer.
const WEAKEST_ACCEPTED_SCORE := EventSheetDocSearch.SCORE_BODY


## The guide section that teaches a verb, as {doc_id, page_id, title, heading, anchor}, or {} when
## the written corpus does not cover it. Never invents a landing: an empty answer draws no row
## rather than a "Learn more" that opens a page with nothing about this verb on it.
static func teaching_section(definition: ACEDefinition) -> Dictionary:
	if definition == null:
		return {}
	return best_section(EventSheetDocSearch.search(definition.display_name, SECTION_CANDIDATES))


## The best teaching section among ranked search results. Pure, so the choice is pinned by the
## suite over a fixture list.
##
## A HEADING hit wins over a title-only hit at the same strength, because a heading is a section and
## a title is a whole page: "Learn more" that lands on the paragraph which teaches the verb is worth
## more than one that lands at the top of a guide and leaves the reader scrolling.
static func best_section(results: Array[Dictionary]) -> Dictionary:
	var best: Dictionary = {}
	var best_score: int = WEAKEST_ACCEPTED_SCORE + 1
	var best_has_heading: bool = false
	for result: Dictionary in results:
		var score: int = int(result.get("score", WEAKEST_ACCEPTED_SCORE + 1))
		if score > WEAKEST_ACCEPTED_SCORE:
			continue
		var has_heading: bool = not str(result.get("heading", "")).strip_edges().is_empty()
		if not best.is_empty():
			if score > best_score:
				continue
			if score == best_score and (best_has_heading or not has_heading):
				continue
		best = {
			"doc_id": str(result.get("doc_id", "")),
			"page_id": str(result.get("page_id", "")),
			"title": str(result.get("title", "")),
			"heading": str(result.get("heading", "")),
			"anchor": str(result.get("anchor", "")),
		}
		best_score = score
		best_has_heading = has_heading
	return best


## Where a section sits, as the one line the panel and the dialog both print: the page, and the
## heading inside it when the landing is a heading rather than the top of the page. "" for no
## section, so a caller draws nothing rather than an empty caption.
static func section_line(section: Dictionary) -> String:
	if section.is_empty():
		return ""
	var title: String = str(section.get("title", "")).strip_edges()
	var heading: String = str(section.get("heading", "")).strip_edges()
	if title.is_empty():
		return heading
	return title if heading.is_empty() else "%s  ·  %s" % [title, heading]


# ── What the dialog says about each field ─────────────────────────────────────────────────────


## The Parameters dialog's own sentences for a verb's fields, as [{heading, body}] in declaration
## order. The heading is the field's name and what kind of value it takes; the body is its blurb
## followed by what THIS kind of box takes - the half the parameters table does not carry, because
## a table column holds a description and not a paragraph about a colour picker.
##
## Only the parameters the dialog itself builds a row for are read: it skips anything that is not a
## declared Dictionary, and a page that described fields the dialog never draws would be describing
## a form nobody sees.
static func strip_items(definition: ACEDefinition) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	if definition == null:
		return items
	for parameter: Variant in definition.parameters:
		if not (parameter is Dictionary):
			continue
		var param: Dictionary = parameter as Dictionary
		var body: String = EventSheetParamFieldFactory.strip_body(param).strip_edges()
		if body.is_empty():
			continue
		items.append({
			"heading": EventSheetParamFieldFactory.strip_heading(param).strip_edges(),
			"body": body,
		})
	return items
