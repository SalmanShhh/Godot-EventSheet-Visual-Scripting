# Godot EventSheets - the guide-coverage audit, and the promise that its two readers agree.
#
# The audit used to be a print statement inside the help-bundle builder. It is now a shared reader
# that the builder and the Doctor's Docs section both ask, and the reason that matters is exactly
# what this test pins: a project where the build log says one thing about a guide and the Doctor
# page says another has two answers to one question, which is worse than having had no page.
#
# What this catches, and nothing else in the suite does:
#   - the two callers drifting apart, pinned by feeding ONE report to both and comparing the words;
#   - a thin description that stops being noticed - including the placeholder the stub fix writes,
#     which is the whole reason that fix is safe to offer;
#   - the stub fix going quiet: a guide it has just written into must still report the stubbed verb,
#     or the chip turns a page green while documenting nothing;
#   - the nearest-name shortlist reordering, which would make a rename's answer machine-dependent;
#   - the changelog sweep firing for a pack that has not shipped, which would report every verb of
#     every unreleased pack as a missing release note.
#
# Every fixture here is written out rather than read off disk: the question is what the RULES say,
# not what this repository's ninety-four guides happen to hold this week.
@tool
class_name DocCoverageTest
extends RefCounted

## A pack guide with one of everything: a verb the tables describe properly, one whose description
## cell says nothing, and a name in the table that no verb answers to.
const FIXTURE_GUIDE := """# Grapple

Prose about the pack.

## ACE reference

### Actions

| Action | Parameters | Description |
|--------|-----------|-------------|
| Fire Hook | direction | Throws the hook along the given direction and pulls if it bites. |
| Release Hook | (none) |  |
| Retract Line | speed | - |

### Conditions

| Condition | Parameters | Description |
|-----------|-----------|-------------|
| Hook Is Attached | (none) | Whether the hook has bitten something solid right now. |

## Use cases

Not part of the reference.
"""

## A ledger in which the pack shipped. What makes the unwritten-change sweep a question about a
## release rather than about an unreleased folder.
const FIXTURE_CHANGELOG := """# Changelog

## [0.9.0]

- Added the grapple_hook pack, with Fire Hook and Hook Is Attached.
"""


static func run() -> bool:
	# The reader keeps one reduction of the ledger between questions. The suite runs serially in one
	# process on CI, so it is dropped on the way in and on the way out.
	EventSheetDocCoverage.clear_cache()
	var passed: bool = true
	var blocks: Array[Dictionary] = EventSheetDocMarkdown.parse(FIXTURE_GUIDE, "Packs/grapple_hook")
	passed = _thin_is_a_cell_that_says_nothing(blocks) and passed
	passed = _the_shortlist_is_the_same_everywhere() and passed
	passed = _the_ledger_sweep_needs_a_shipped_pack() and passed
	passed = _a_stub_stays_red_until_somebody_writes_it() and passed
	passed = _both_readers_say_the_same_sentence() and passed
	passed = _the_page_obeys_the_band_scale_law() and passed
	EventSheetDocCoverage.clear_cache()
	return passed


# ── A description that says nothing ───────────────────────────────────────────────────────────


static func _thin_is_a_cell_that_says_nothing(blocks: Array[Dictionary]) -> bool:
	var passed: bool = true
	var thin: Array[Dictionary] = EventSheetDocCoverage.thin_entries(blocks)
	var names: PackedStringArray = PackedStringArray()
	for entry: Dictionary in thin:
		names.append(str(entry.get("name", "")))
	passed = _check("an empty cell and a dash are both thin, a real sentence is not",
		str(names), str(PackedStringArray(["Release Hook", "Retract Line"]))) and passed
	passed = _check("the row's parameters ride along, so the draft can name them",
		str(thin[1].get("params", "")), "speed") and passed
	passed = _check("a table with no description column promises nothing and reports nothing",
		EventSheetDocCoverage.note_column_of(["Name", "Parameters"]), -1) and passed
	passed = _check("the description column is found wherever the corpus put it",
		EventSheetDocCoverage.note_column_of(["Expression", "Returns", "Description"]), 2) and passed
	# The draft is composed from the verb's own words and says so. It never claims behaviour.
	passed = _check("the draft is the verb's own name and parameters, marked as a draft",
		EventSheetDocCoverage.draft_note("Retract Line", "speed"),
		"Draft: Retract Line. Takes speed.") and passed
	return passed


# ── The shortlist a stale name is offered ─────────────────────────────────────────────────────


static func _the_shortlist_is_the_same_everywhere() -> bool:
	var candidates: PackedStringArray = PackedStringArray([
		"Fire Hook", "Release Hook", "Hook Is Attached", "Set Line Length"])
	return _check("the nearest three are ranked by likeness and tie-broken by name",
		str(EventSheetDocCoverage.nearest_names("Release The Hook", candidates)),
		str(PackedStringArray(["Release Hook", "Fire Hook", "Set Line Length"])))


# ── The release ritual, running continuously ──────────────────────────────────────────────────


static func _the_ledger_sweep_needs_a_shipped_pack() -> bool:
	var packs: PackedStringArray = PackedStringArray(["grapple_hook"])
	var verbs: PackedStringArray = PackedStringArray(["Fire Hook", "Release Hook", "Hook Is Attached"])
	var passed: bool = true
	passed = _check("a shipped pack's unmentioned verb is a line nobody wrote",
		str(EventSheetDocCoverage.unwritten_verbs(FIXTURE_CHANGELOG, packs, verbs)),
		str(PackedStringArray(["Release Hook"]))) and passed
	passed = _check("a pack the ledger never names has not shipped, so none of it is late",
		str(EventSheetDocCoverage.unwritten_verbs(FIXTURE_CHANGELOG,
			PackedStringArray(["zipline"]), verbs)),
		str(PackedStringArray())) and passed
	return passed


# ── The stub fix refuses to fake a green page ─────────────────────────────────────────────────


static func _a_stub_stays_red_until_somebody_writes_it() -> bool:
	var passed: bool = true
	var written: String = EventSheetDocCoverage.insert_stubs(FIXTURE_GUIDE,
		PackedStringArray(["Set Line Length"]), {"Set Line Length": "length"})
	passed = _check("the stub lands inside the reference and not after the use cases",
		written.find(EventSheetDocCoverage.STUB_NOTE) < written.find("## Use cases"), true) and passed
	passed = _check("the prose after the section is untouched",
		written.ends_with("Not part of the reference.\n"), true) and passed
	# The point of the whole design: the guide now LISTS the verb, so it leaves `missing` - and it
	# arrives thin, so it is still on the page. Nothing went green.
	var after: Array[Dictionary] = EventSheetDocMarkdown.parse(written, "Packs/grapple_hook")
	var still_thin: PackedStringArray = PackedStringArray()
	for entry: Dictionary in EventSheetDocCoverage.thin_entries(after):
		still_thin.append(str(entry.get("name", "")))
	passed = _check("the stubbed verb reports itself until the placeholder is replaced",
		still_thin.has("Set Line Length"), true) and passed
	passed = _check("writing the same stub twice writes the same bytes",
		EventSheetDocCoverage.insert_stubs(FIXTURE_GUIDE, PackedStringArray(["Set Line Length"]),
			{"Set Line Length": "length"}), written) and passed
	return passed


# ── One question, two callers, one sentence ───────────────────────────────────────────────────


static func _both_readers_say_the_same_sentence() -> bool:
	# The report a real page produces, written out here so the comparison is about the two readers
	# and not about whatever the vocabulary holds today.
	var report: Dictionary = {
		"page": "Addons/Grapple", "packs": PackedStringArray(["grapple_hook"]),
		"missing": PackedStringArray(["Set Line Length"]),
		"extra": PackedStringArray(["Reel In"]),
		"nearest": {"Reel In": PackedStringArray(["Retract Line"])},
		"thin": [{"name": "Release Hook", "note": "", "params": "(none)"}],
		"unwritten": PackedStringArray(["Release Hook"]),
	}
	var passed: bool = true
	passed = _check("the line names only the clauses that hold something",
		EventSheetDocCoverage.advisory_line(report),
		"Addons/Grapple: 1 verb(s) the guide does not list, 1 name(s) no verb answers to, "
		+ "1 description(s) that say nothing, 1 verb(s) the changelog never mentions") and passed
	passed = _check("everything the page holds is counted once",
		EventSheetDocCoverage.total_findings(report), 4) and passed
	# THE AGREEMENT: the build log's line for a guide is the Doctor headline for that guide, the
	# same String from the same function. Two readers cannot describe one guide differently.
	var findings: Array[Dictionary] = EventSheetDocsDoctor.page_findings(report)
	passed = _check("the Doctor headline is the build tool's line, character for character",
		str(findings[0].get("message", "")), EventSheetDocCoverage.advisory_line(report)) and passed
	passed = _check("a verb nobody documented is a warning, not a note",
		str(findings[1].get("severity", "")), "warning") and passed
	passed = _check("a stale name is offered what does exist",
		str(findings[2].get("message", "")).contains("Retract Line"), true) and passed
	passed = _check("a thin description is a note carrying its draft",
		str(findings[3].get("message", "")).contains("Draft: Release Hook."), true) and passed
	passed = _check("an unwritten change is filed under its own check",
		str(findings[4].get("check", "")), EventSheetDocCoverage.CHECK_UNWRITTEN) and passed
	# The identity the inbox marks "new" is the verb plus the guide it is in, never the wording.
	passed = _check("a line is identified by the verb it is about",
		str(findings[1].get("subject", "")), "Set Line Length") and passed
	return passed


# ── Counts are the truth, the listing is a sample ─────────────────────────────────────────────


static func _the_page_obeys_the_band_scale_law() -> bool:
	var report: Dictionary = {
		"page": "Addons/Grapple", "packs": PackedStringArray(["grapple_hook"]),
		"missing": PackedStringArray(["A Verb", "B Verb", "C Verb", "D Verb", "E Verb", "F Verb"]),
		"extra": PackedStringArray(), "nearest": {}, "thin": [],
		"unwritten": PackedStringArray(),
	}
	var findings: Array[Dictionary] = EventSheetDocsDoctor.page_findings(report)
	var passed: bool = true
	passed = _check("six missing verbs become the headline plus a capped sample",
		findings.size(), 1 + EventSheetDocsDoctor.LINES_PER_GUIDE_LIMIT) and passed
	passed = _check("the headline still states the true total",
		str(findings[0].get("message", "")).contains("6 verb(s)"), true) and passed
	# The chips a reader is offered on those lines, which is what makes a finding one people act on.
	passed = _check("the undocumented-verb line offers the stub chip",
		str(EventSheetQuickFixes.fixes_for(findings[1])[0].get("id", "")), "write_doc_stubs") and passed
	return passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] doc coverage: %s" % label)
		return true
	print("[FAIL] doc coverage: %s\n  expected: %s\n  actual:   %s" % [label, str(expected), str(actual)])
	return false
