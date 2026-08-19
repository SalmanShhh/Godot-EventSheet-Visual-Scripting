# EventSheet - the Manual's COMMON GAME PATTERNS page: the hand-written shape and the events it
# reads as, side by side, one pair per pattern.
#
# A reader arrives at this page holding code in their other window and wanting to see it become
# events. So the page shows exactly that, and it shows it by DOING it: the left column is the
# pattern's fixture file printed verbatim, the right column is a live figure of the very same text
# read by the very same renderer the sheet uses. Nothing on this page is authored prose about what
# the reading would do, which is why it can never show a shape the sheet does not read - if the
# reading broke, the figure would refuse to draw and the reading test over the same fixture would
# already have failed.
#
# THE FIXTURES ARE THE SOURCE. tests/fixtures/patterns/<pattern_id>.gd, listed by
# EventSheetPatternVocabulary.documented_ids(); a pattern with no fixture has no section here and
# nothing to insert, deliberately.
@tool
class_name EventSheetPatternManual
extends RefCounted

## The page id, in the frozen "reference:" scheme: the whole page, and one pattern's section of it.
const PAGE_ID := "reference:patterns"
const PAGE_TITLE := "Common Game Patterns"

## The page action a section's Adopt button reports. The page cannot rewrite a sheet itself - it
## names what it wants and the browser hands it to the dock, which is what keeps the view
## host-agnostic.
const ACTION_ADOPT := "adopt_pattern"


## The doc id for one pattern's section - what the ⟡ chip opens and what "Patterns using this"
## links to.
static func doc_id_for(pattern: String) -> String:
	return EventSheetDocReference.doc_id(EventSheetDocReference.KIND_PATTERN, pattern.strip_edges())


## Open a pattern's section of the page, docked when the reader has docked the Manual. FALSE when
## the pattern has no section, which is exactly the patterns with no fixture.
static func open_page(pattern: String) -> bool:
	var wanted: String = pattern.strip_edges()
	if wanted.is_empty() or EventSheetPatternVocabulary.fixture_source(wanted).is_empty():
		return EventSheets.open_docs(PAGE_ID)
	return EventSheets.open_docs(doc_id_for(wanted))


## THE WHOLE PAGE: a lead, then one section per documented pattern, most common first.
static func blocks() -> Array[Dictionary]:
	var blocks: Array[Dictionary] = [
		{"kind": "heading", "level": 1, "text": PAGE_TITLE},
		{"kind": "paragraph", "bbcode": EventSheetL10n.translate(
			"The shapes a game is made of, each one written by hand on the left and read as events on the right. Every example is a real file this editor opens: press Insert to put the rows in your sheet, or Try it to open them in a scratch sheet.")}
	]
	for pattern: String in EventSheetPatternVocabulary.documented_ids():
		blocks.append_array(pattern_blocks(pattern))
	return blocks


## ONE PATTERN'S SECTION: its name, its one-line why, the two columns, and the offers under them.
## Empty when the pattern has no fixture - a section with nothing to show would be a promise the
## page cannot keep.
static func pattern_blocks(pattern: String) -> Array[Dictionary]:
	var source: String = EventSheetPatternVocabulary.fixture_source(pattern)
	if source.is_empty():
		return []
	var words: String = EventSheetPatternVocabulary.words(pattern)
	var lines: Array = []
	for line: String in source.split("\n"):
		lines.append(line)
	# A trailing newline in the file becomes an empty last entry; the columns are a listing, not a
	# byte gate, so it is dropped rather than drawn as a blank line under the code.
	if not lines.is_empty() and str(lines[lines.size() - 1]).is_empty():
		lines.remove_at(lines.size() - 1)
	var blocks: Array[Dictionary] = [
		{"kind": "heading", "level": 2, "text": words},
		{"kind": "paragraph", "bbcode": EventSheetPatternVocabulary.why(pattern)},
		{"kind": "columns", "columns": [
			[
				{"kind": "heading", "level": 3, "text": EventSheetL10n.translate("Hand-written")},
				{"kind": "code", "language": "gdscript", "no_figure": true, "lines": lines}
			],
			[
				{"kind": "heading", "level": 3, "text": EventSheetL10n.translate("As events")},
				{"kind": "code", "language": "eventsheet", "caption": words, "lines": lines}
			]
		]}
	]
	var adoptable: String = EventSheetPatternVocabulary.adoptable(pattern)
	if not adoptable.is_empty():
		blocks.append({"kind": "button",
			"label": EventSheetL10n.translate("Adopt behavior: %s") % EventSheetPatternVocabulary.pack_label(adoptable),
			"tooltip": EventSheetL10n.translate(
				"Shows what this sheet would look like with the shipped behavior doing the work, before changing anything."),
			"action": ACTION_ADOPT, "argument": pattern})
	return blocks


## S26 - the patterns a verb belongs to, as {title, doc_id} links, derived from the ace_ids the
## claims carry. Empty when the verb is in none of them, which is most verbs.
##
## The join is over the CLAIMS of the sheet the reader has open, not a hand-kept table: a verb is
## "used by the Cooldown pattern" precisely because a Cooldown claim in front of them says it is.
static func patterns_using(sheet: EventSheetResource, provider_id: String, ace_id: String) -> Array[Dictionary]:
	var wanted: String = "%s/%s" % [provider_id.strip_edges(), ace_id.strip_edges()]
	var seen: Dictionary = {}
	var found: Array[Dictionary] = []
	for claim: Variant in EventSheetPatternFacts.claims(sheet):
		var pattern: String = str((claim as Dictionary).get("pattern", ""))
		if seen.has(pattern):
			continue
		var uses: bool = false
		for entry: Variant in (claim as Dictionary).get("ace_ids", PackedStringArray()):
			if str(entry) == wanted:
				uses = true
				break
		if not uses:
			continue
		seen[pattern] = true
		var words: String = EventSheetPatternVocabulary.words(pattern)
		if words.is_empty():
			words = str((claim as Dictionary).get("words", ""))
		if words.is_empty():
			continue
		found.append({"title": "%s %s" % [ViewportRowBuilder.PATTERN_CHIP_MARK, words],
			"doc_id": doc_id_for(pattern)})
	return found
