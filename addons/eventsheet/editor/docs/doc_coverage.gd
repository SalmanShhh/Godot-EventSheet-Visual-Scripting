# Godot EventSheets - what a pack guide SAYS about its verbs, measured against what the pack
# actually publishes.
#
# This question already had an answer and no reader. The bundle builder computed a per-guide diff
# and printed it as build noise ("Weapon-Kit: 6 verb(s) the guide does not list..."), which is a
# line nobody sees on a tool nobody runs unless they are already editing a guide. The answer is
# worth a page, and a page needs the SAME answer the build tool prints - so the question lives here,
# once, and both the builder and the Doctor's Docs section ask it. There is no second implementation
# of "is this guide honest", and a test feeds one fixture bundle to both and pins identical answers.
#
# FOUR QUESTIONS, ONE WALK OVER A PAGE:
#
#   VERB NOT IN THE GUIDE   the pack publishes it; the guide's tables never name it. The reader who
#                           searched the guide concluded it does not exist.
#   A NAME NO VERB ANSWERS  the guide's tables name it; nothing in the vocabulary answers to it. A
#                           renamed or deleted verb leaves this behind, and it is the shape of
#                           staleness a reader cannot detect - the sentence still reads fine.
#   A THIN DESCRIPTION      the row is there and its "what it does" cell says nothing (blank, or a
#                           stub nobody filled in). A table of names is an index, not documentation.
#   AN UNWRITTEN CHANGE     the pack is in the CHANGELOG, so it shipped; this verb of it is not,
#                           anywhere in the ledger. That is the release ritual's "did we write down
#                           what changed" running continuously instead of being remembered at tag
#                           time, when the diff is a month wide and nobody can reconstruct it.
#
# NOTHING HERE IS A GATE, and the reason is not squeamishness. A guide legitimately documents a
# verb under a friendlier name than the raw member, and legitimately leaves plumbing out. Every
# finding is a note or a warning that a human decides about.
#
# EVERY ANSWER IS DETERMINISTIC AND OFFLINE: the same guide and the same vocabulary produce the same
# findings in the same order, on any machine, with no model and no clock involved. The drafts this
# offers are composed out of the verb's own name and parameters, which is why they are honestly
# labelled drafts rather than presented as documentation somebody wrote.
@tool
class_name EventSheetDocCoverage
extends RefCounted

## The check ids the four questions file under. Frozen alongside their wording: a quick-fix chip and
## the tests address a finding by its check id, and the inbox's "is this new" identity carries it.
const CHECK_UNLISTED := "docs-undocumented-verb"
const CHECK_UNANSWERED := "docs-stale-name"
const CHECK_THIN := "docs-empty-description"
const CHECK_UNWRITTEN := "docs-unwritten-change"

## The head of the column a verb table's "what it does" lives in. The corpus writes it four ways,
## and a table with none of them is a table that never promised a description - its rows are not
## thin, they are a bare index, and reporting every one of them would bury the guides that meant to
## explain themselves and left a cell empty.
const NOTE_TABLE_HEADS := ["description", "what it does", "note", "notes"]

## Under this many characters, a description is doing no work. Measured against the corpus: the
## shortest genuine description a shipped guide carries is "Whether the quest is being tracked right
## now." at 44, and the cells this catches are blanks, dashes and unfilled stubs.
const THIN_LENGTH: int = 20

## What an unfilled description says, and what the stub-inserting fix writes. It is deliberately the
## word a search finds and a reviewer refuses to merge: the fix hands a guide a row per undocumented
## verb, and every one of those rows keeps reporting itself here until a human replaces this text.
## A fix that wrote a plausible sentence instead would turn a red page green while documenting
## nothing, which is the one outcome worse than the gap.
const STUB_NOTE := "TODO: describe what this does."

## How many alternatives a stale name is offered. Three is the number a person can weigh at a
## glance; a list of every verb in the pack is the picker, which they already have.
const NEAREST_LIMIT: int = 3

## The shortest normalized verb name the CHANGELOG sweep will trust. "Add" collapses to three
## characters that appear inside a thousand English words, and a substring search on it would report
## every short verb in the corpus as written about when nothing wrote about it.
const UNWRITTEN_MIN_LENGTH: int = 6

## The ledger, reduced to letters and digits, kept beside the hash of the text it came from. A
## corpus audit asks the same question of the same CHANGELOG once per guide, and reducing a
## hundred-kilobyte file character by character ninety-four times is most of what an audit costs.
## Keyed by content, so a stale answer is not possible - and dropped by `clear_cache` on the way out
## of a test, because a serial run must not hand the next test a cache this one built.
static var _ledger_text: String = ""
static var _ledger_hash: int = 0


## Drops what this reader remembers between questions. The audit is a pure function of a guide and a
## vocabulary; the cache only saves the same reduction being done ninety-four times in a row.
static func clear_cache() -> void:
	_ledger_text = ""
	_ledger_hash = 0
	EventSheetDocAceReference.reload()


## The whole coverage answer for one page, as
## {page, packs, missing, extra, nearest, thin, unwritten}:
##   missing    verbs the packs publish that the guide's tables never name
##   extra      names the tables carry that no verb answers to
##   nearest    extra name -> the closest verbs that DO exist, so a rename is one glance away
##   thin       {name, note} for every listed verb whose description cell says nothing
##   unwritten  verbs the CHANGELOG has never named, for a pack the CHANGELOG does name
##
## Pure over the page's blocks and the vocabulary this process loaded, which is what lets the build
## tool, the Doctor and a test all ask the same question and get the same words back.
static func page_report(page_id: String, blocks: Array[Dictionary],
		changelog: String = "") -> Dictionary:
	var diff: Dictionary = EventSheetDocAceReference.diff_for_page(page_id, blocks)
	var packs: PackedStringArray = diff.get("packs", PackedStringArray())
	var report: Dictionary = {
		"page": page_id, "packs": packs,
		"missing": diff.get("missing", PackedStringArray()),
		"extra": diff.get("extra", PackedStringArray()),
		"nearest": {}, "thin": [], "unwritten": PackedStringArray(),
	}
	if packs.is_empty():
		return report
	var derived: PackedStringArray = derived_names(page_id)
	var nearest: Dictionary = {}
	for name: String in (report["extra"] as PackedStringArray):
		nearest[name] = nearest_names(name, derived)
	report["nearest"] = nearest
	report["thin"] = thin_entries(blocks)
	if not changelog.is_empty():
		report["unwritten"] = unwritten_verbs(changelog, packs, derived)
	return report


## Every verb name the packs of this page publish, de-duplicated in group order. The other half of
## the diff, exposed because the nearest-name suggestions and the CHANGELOG sweep both need the same
## list and neither should rebuild it from the registry a second time.
static func derived_names(page_id: String) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	var grouped: Dictionary = EventSheetDocAceReference.verb_rows_for_page(page_id)
	for group: String in EventSheetDocAceReference.GROUP_ORDER:
		for entry: Variant in (grouped.get(group, []) as Array):
			var name: String = str((entry as Dictionary).get("name", ""))
			if not name.is_empty() and not names.has(name):
				names.append(name)
	return names


## The rows of the page's verb tables whose description cell says nothing, as {name, note, params}.
## A table with no description column at all is skipped rather than reported: it never promised one.
##
## Ordered by the page's own reading order and then de-duplicated by name, so two audits of an
## unchanged guide list the same rows in the same places.
static func thin_entries(blocks: Array[Dictionary]) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var seen: Dictionary = {}
	for block: Dictionary in blocks:
		if str(block.get("kind", "")) != "table":
			continue
		var headers: Array = block.get("headers", []) as Array
		var name_column: int = EventSheetDocAceReference.verb_name_column(headers)
		var note_column: int = note_column_of(headers)
		if name_column < 0 or note_column < 0:
			continue
		for entry: Variant in (block.get("rows", []) as Array):
			var cells: Array = entry as Array
			if cells.size() <= maxi(name_column, note_column):
				continue
			var name: String = _bare(str(cells[name_column]))
			var note: String = _bare(str(cells[note_column]))
			if name.is_empty() or seen.has(name) or not is_thin(note):
				continue
			seen[name] = true
			found.append({"name": name, "note": note,
				"params": _bare(str(cells[1])) if cells.size() > 1 and name_column != 1 else ""})
	return found


## Whether a description cell is doing no work: empty, a placeholder dash, or an unfilled stub.
## Length alone is not the whole rule - "TODO: describe what this does." is long and says nothing,
## and it is exactly what the stub fix writes, which is what keeps a stubbed guide red.
static func is_thin(note: String) -> bool:
	var text: String = note.strip_edges()
	if text.begins_with("TODO"):
		return true
	var stripped: String = text.replace("-", "").replace(".", "").strip_edges()
	return stripped.length() < THIN_LENGTH


## Which column of a verb table holds the description, or -1 when the table has none.
static func note_column_of(headers: Array) -> int:
	for index: int in range(headers.size()):
		if NOTE_TABLE_HEADS.has(_bare(str(headers[index])).to_lower()):
			return index
	return -1


## The verbs closest to a name nothing answers to, best first. Similarity over the normalized
## spellings, so "Set Ability Cooldown" reaches "Set Cooldown" past the punctuation and the case;
## ties break alphabetically, so the same stale name is always offered the same three.
static func nearest_names(wanted: String, candidates: PackedStringArray,
		limit: int = NEAREST_LIMIT) -> PackedStringArray:
	var target: String = _normalize(wanted)
	var scored: Array = []
	for name: String in candidates:
		scored.append({"name": name, "score": target.similarity(_normalize(name))})
	scored.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_score: float = float(left.get("score", 0.0))
		var right_score: float = float(right.get("score", 0.0))
		if not is_equal_approx(left_score, right_score):
			return left_score > right_score
		return str(left.get("name", "")) < str(right.get("name", "")))
	var out: PackedStringArray = PackedStringArray()
	for entry: Variant in scored:
		if out.size() >= limit:
			break
		out.append(str((entry as Dictionary).get("name", "")))
	return out


## The verbs of these packs the CHANGELOG has never named, for a pack the CHANGELOG DOES name. The
## second half is the whole point: a pack absent from the ledger has not shipped yet and its verbs
## are not late, while a pack that shipped and then grew four verbs in silence is precisely the gap
## the release ritual used to catch by memory at tag time.
##
## Matching is loose in the same direction the guide diff is - normalized to letters and digits - so
## a ledger line that wrote "Advance Objective" answers for `advance_objective`, and one that wrote
## the sentence around it answers too. Short names are skipped rather than guessed at.
static func unwritten_verbs(changelog: String, packs: PackedStringArray,
		derived: PackedStringArray) -> PackedStringArray:
	var ledger: String = _normalized_ledger(changelog)
	var shipped: bool = false
	for pack_dir: String in packs:
		if ledger.contains(_normalize(pack_dir)):
			shipped = true
	var out: PackedStringArray = PackedStringArray()
	if not shipped:
		return out
	for name: String in derived:
		var normalized: String = _normalize(name)
		if normalized.length() < UNWRITTEN_MIN_LENGTH:
			continue
		if not ledger.contains(normalized):
			out.append(name)
	return out


## Whether this page's report has anything to say. The one question the build tool's listing and the
## Doctor's section both ask before spending a line on a guide.
static func has_findings(report: Dictionary) -> bool:
	return total_findings(report) > 0


## How many things this page's report holds, across all four questions. The number the summary line
## states, and the reason it is computed here: a page counted one way in the build output and
## another way on the Doctor page is two answers to one question.
static func total_findings(report: Dictionary) -> int:
	return (report.get("missing", PackedStringArray()) as PackedStringArray).size() \
		+ (report.get("extra", PackedStringArray()) as PackedStringArray).size() \
		+ (report.get("thin", []) as Array).size() \
		+ (report.get("unwritten", PackedStringArray()) as PackedStringArray).size()


## One page's report in one sentence - the line the build tool prints and the line the Doctor's
## per-guide finding carries. Clauses appear only when they hold something, so a guide with one
## stale name says one thing rather than four, three of them zero.
static func advisory_line(report: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	var missing: int = (report.get("missing", PackedStringArray()) as PackedStringArray).size()
	var extra: int = (report.get("extra", PackedStringArray()) as PackedStringArray).size()
	var thin: int = (report.get("thin", []) as Array).size()
	var unwritten: int = (report.get("unwritten", PackedStringArray()) as PackedStringArray).size()
	if missing > 0:
		parts.append(EventSheetL10n.translate("%d verb(s) the guide does not list") % missing)
	if extra > 0:
		parts.append(EventSheetL10n.translate("%d name(s) no verb answers to") % extra)
	if thin > 0:
		parts.append(EventSheetL10n.translate("%d description(s) that say nothing") % thin)
	if unwritten > 0:
		parts.append(EventSheetL10n.translate("%d verb(s) the changelog never mentions") % unwritten)
	return "%s: %s" % [str(report.get("page", "")), ", ".join(parts)]


## A description drafted from the verb's own name and parameters. Deterministic and deliberately
## plain: it is a starting sentence a person edits, never a claim about behaviour nobody wrote. A
## draft that guessed at what a verb DOES would be a lie in the reader's own guide.
static func draft_note(name: String, params: String) -> String:
	var subject: String = name.strip_edges()
	if subject.is_empty():
		return ""
	var sentence: String = EventSheetL10n.translate("Draft: %s.") % subject
	var arguments: String = params.strip_edges()
	if not arguments.is_empty() and arguments.to_lower() != "(none)":
		sentence += " " + EventSheetL10n.translate("Takes %s.") % arguments
	return sentence


## The Markdown rows a guide gains for the verbs it never listed: one stub per verb, each carrying
## the unfilled description that keeps reporting itself here. Sorted by name, so applying the fix
## twice to a guide somebody half-filled produces the same file.
static func stub_rows(missing: PackedStringArray, params_by_name: Dictionary = {}) -> PackedStringArray:
	var names: PackedStringArray = missing.duplicate()
	names.sort()
	var rows: PackedStringArray = PackedStringArray()
	for name: String in names:
		rows.append("| %s | %s | %s |" % [name, str(params_by_name.get(name, "")), STUB_NOTE])
	return rows


## A guide's Markdown with a stub table appended for the verbs it never listed. A pure text
## transform, so the fix that writes a file and the test that pins what it would write are looking
## at the same bytes.
##
## The stubs go in their OWN subsection at the end of the ACE reference rather than into an existing
## table: which of a guide's three tables a verb belongs in is a judgement (an action that reads
## like a condition is common), and a fix that guessed would file verbs wrongly under a heading a
## reader trusts. An honest heading naming what these are is better than a confident wrong one.
static func insert_stubs(source: String, missing: PackedStringArray,
		params_by_name: Dictionary = {}) -> String:
	var rows: PackedStringArray = stub_rows(missing, params_by_name)
	if rows.is_empty():
		return source
	var section: PackedStringArray = PackedStringArray([
		"### Not written yet",
		"",
		"These verbs are published by the pack and were never described here. Replace every %s below." % STUB_NOTE,
		"",
		"| Name | Parameters | Description |",
		"|------|-----------|-------------|",
	])
	section.append_array(rows)
	var text: String = source.replace("\r\n", "\n")
	var at: int = _ace_section_end(text)
	var head: String = text.substr(0, at).rstrip("\n")
	var tail: String = text.substr(at)
	return "%s\n\n%s\n%s" % [head, "\n".join(section), tail]


## Where the ACE reference section ends in raw Markdown: the next heading at "## " or above after
## it, or the end of the file. Found on the text rather than on parsed blocks because the fix has to
## give back a FILE, and re-emitting a guide from its blocks would rewrite prose nobody asked it to
## touch - the lossless rule the whole plugin runs on, applied to somebody's documentation.
static func _ace_section_end(text: String) -> int:
	var lines: PackedStringArray = text.split("\n")
	var offset: int = 0
	var inside: bool = false
	for line: String in lines:
		var stripped: String = line.strip_edges()
		if stripped.begins_with("## "):
			if inside:
				return offset
			inside = EventSheetDocMarkdown.slug(stripped.substr(3).strip_edges()) \
				== EventSheetDocAceReference.SECTION_SLUG
		offset += line.length() + 1
	return text.length()


## The ledger reduced once. The reduction is the same one every name goes through, which is what
## lets a substring test stand in for "does the changelog talk about this verb".
static func _normalized_ledger(changelog: String) -> String:
	var key: int = changelog.hash()
	if key != _ledger_hash or _ledger_text.is_empty():
		_ledger_hash = key
		_ledger_text = _normalize_bulk(changelog)
	return _ledger_text


## Everything that is not a letter or a digit, compiled once. See _normalize_bulk.
static var _reducer: RegEx = null


## The same reduction as _normalize, done by the engine's own scanner instead of by a GDScript loop
## over one character at a time. It has to be: a shipped CHANGELOG is over a megabyte, and reducing a
## megabyte an index at a time costs MINUTES - long enough that a command line reading the corpus
## looks hung rather than slow. The per-name reduction below stays as it is, because it is the
## definition the two spellings of a name are compared through and it runs on a handful of
## characters; this is the same answer for a large input, and the suite pins that they agree.
static func _normalize_bulk(text: String) -> String:
	if _reducer == null:
		_reducer = RegEx.create_from_string("[^a-z0-9]+")
	return _reducer.sub(text.to_lower(), "", true)


## A table cell back to its bare words: the code span the guides write names in, stripped.
static func _bare(cell: String) -> String:
	return cell.replace("[code]", "").replace("[/code]", "").replace("`", "").strip_edges()


## A name reduced to what two spellings of it have in common: letters and digits, lower case. The
## same reduction the guide diff uses, so "is this listed" and "which is it closest to" can never
## disagree about whether two names are the same name.
static func _normalize(name: String) -> String:
	var out: String = ""
	for index: int in range(name.length()):
		var character: String = name[index].to_lower()
		if (character >= "a" and character <= "z") or (character >= "0" and character <= "9"):
			out += character
	return out
