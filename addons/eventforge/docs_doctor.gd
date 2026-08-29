# Godot EventSheets - the Doctor's Docs section: whether the guides still describe the packs.
#
# The audit that answers this already existed and had no reader. It ran inside the help-bundle
# builder and printed its verdict as build noise on a tool you only run while editing a guide, which
# means the one moment it was visible was the one moment you did not need telling. Documentation
# rots quietly - a renamed verb leaves a sentence that still reads perfectly - so the answer belongs
# somewhere a person passes anyway, beside the other things about this project that are drifting.
#
# ONE READER, TWO CALLERS. Every question here is asked of EventSheetDocCoverage, which is also what
# the builder now asks. There is no second implementation of "does this guide match its pack", and a
# test hands both callers the same fixture and pins that they answer identically - so the page and
# the build output cannot say different things about the same guide.
#
# WHAT IT REPORTS, and what each one is worth:
#   a verb the guide never lists       a note. The reader searched and concluded it does not exist.
#   a name no verb answers to          a note, with the nearest three that DO exist, because the
#                                      overwhelmingly common cause is a rename and the answer is
#                                      usually one of the three.
#   a description that says nothing    a note, with a draft composed from the verb's own name and
#                                      parameters. Left as a draft on purpose.
#   a verb the changelog never names   a note. The pack is in the ledger, so it shipped; this verb of
#                                      it was never written about. That is the release ritual's
#                                      remember-at-tag-time step, running continuously.
#
# EVERY LINE IS A NOTE, AND THE FIRST TWO ESPECIALLY. Both of those are decided by comparing two
# SPELLINGS of a verb - the vocabulary's and the guide author's - and the two are allowed to differ:
# a guide documents a verb under a friendlier name than the raw member all over the shipped corpus,
# which is exactly the freedom the paragraph below promises writers. A comparison that is
# deliberately loose must not be the thing that turns somebody's Doctor page amber: a section that
# arrives amber on a stock install is a section its reader learns to scroll past, and then the one
# genuinely renamed verb it was built to catch scrolls past with it.
#
# NOTHING HERE FAILS A BUILD. A guide legitimately documents a verb under a friendlier name and
# legitimately leaves plumbing out, so every line is something a human decides about. What the
# section refuses to do is manufacture the appearance of documentation: the stub-inserting fix
# writes rows that keep reporting themselves until somebody replaces the placeholder, because a page
# that went green while nothing was written is worse than the gap it hid.
@tool
class_name EventSheetDocsDoctor
extends RefCounted

## The id the section registers under. The individual lines file under the coverage module's own
## check ids, so the quick-fix chips and the inbox identities are addressed by what the line IS
## rather than by which runner produced it.
const CHECK_ID := "docs"

## How many guides one audit reads. A ceiling, not a target, and the summary line always states how
## many of how many it got through - so the cap costs completeness of the LISTING and never honesty
## about the count.
##
## TWO NUMBERS, because the same question costs two very different amounts, and the second one is
## zero. Inside a running editor the vocabulary is already loaded and asking a guide's packs what
## they publish is a lookup. Outside one - CI, the command line, the suite - there is no registry, so
## every script of every pack a guide is about has to be read and its members reflected, which is
## seconds per guide: reading a corpus that way turned a sixty-second audit into a six-minute one.
##
## So headless, the section reads nothing and says so, naming the tool that DOES answer the question
## there: the help-bundle build prints the same lines from the same reader, and the suite gates them.
## The answer is not lost, it is asked where it is affordable.
const GUIDES_READ_LIMIT: int = 12
const GUIDES_READ_LIMIT_HEADLESS: int = 0

const GUIDES_LISTED_LIMIT: int = 12

## How many individual lines one guide contributes. A guide missing thirty-eight verbs needs a
## person to sit down with it, not thirty-eight rows in an inbox.
const LINES_PER_GUIDE_LIMIT: int = 4


## How many guides THIS process can afford to read. See the two constants: the editor holds the
## vocabulary already, and nothing else does.
static func guides_read_limit() -> int:
	return GUIDES_READ_LIMIT if Engine.is_editor_hint() else GUIDES_READ_LIMIT_HEADLESS


## Registers the section, replacing any previous registration - so a plugin reload, a second Doctor
## run and a test that registers it by hand all leave exactly one.
static func ensure_registered() -> void:
	EventSheets.register_doctor_check(CHECK_ID, Callable(EventSheetDocsDoctor, "check"))


## The section, with the contract every registered check has: append findings, never write inside
## res://. The guides are the corpus this editor has loaded - the shipped pack guides plus any guide
## a pack in this project ships beside itself - so a studio's own packs are audited exactly like the
## ones that came in the box.
static func check(_sheet_paths: PackedStringArray, findings: Array[Dictionary]) -> void:
	findings.append_array(report(guide_pages(), _changelog_text()))


## Every page the section audits, sorted: the bundled addon guides and the guides packs ship beside
## themselves. Sorted rather than walk-ordered, because a directory walk hands back a different
## order on a different filesystem and a report that reshuffles is a report whose "what is new"
## marks are noise.
static func guide_pages() -> PackedStringArray:
	var ids: PackedStringArray = PackedStringArray()
	ids.append_array(EventSheetDocLibrary.ids_in_set(EventSheetDocLibrary.ADDONS_DIR))
	ids.append_array(EventSheetDocLibrary.ids_in_set(EventSheetDocLibrary.PACKS_SET))
	ids.sort()
	return ids


## The whole section, as findings. Pure over the page ids and the ledger text, so a test can hand it
## a fixture corpus and pin every word without a bundle on disk.
static func report(page_ids: PackedStringArray, changelog: String,
		limit: int = -1) -> Array[Dictionary]:
	var read_limit: int = guides_read_limit() if limit < 0 else limit
	var findings: Array[Dictionary] = []
	var reports: Array[Dictionary] = []
	var read: int = 0
	var skipped: int = 0
	for page_id: String in page_ids:
		if read >= read_limit:
			skipped += 1
			continue
		var blocks: Array[Dictionary] = EventSheetDocLibrary.page_blocks(page_id)
		if blocks.is_empty():
			continue
		read += 1
		var page: Dictionary = EventSheetDocCoverage.page_report(page_id, blocks, changelog)
		if EventSheetDocCoverage.has_findings(page):
			reports.append(page)
	# Worst first, ties by page id: the listing below the summary is a SAMPLE, so which guides it
	# spends its dozen lines on has to be the ones holding the most, and has to be the same dozen on
	# every machine.
	reports.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_total: int = EventSheetDocCoverage.total_findings(left)
		var right_total: int = EventSheetDocCoverage.total_findings(right)
		if left_total != right_total:
			return left_total > right_total
		return str(left.get("page", "")) < str(right.get("page", "")))
	findings.append(_summary(reports, read, read + skipped))
	for index: int in range(reports.size()):
		if index >= GUIDES_LISTED_LIMIT:
			break
		findings.append_array(page_findings(reports[index]))
	return findings


## The section's one always-present line: how many guides were read of how many, and what they hold.
## The band scale law in its plainest form - the count is the whole truth, the enumeration below it
## is a sample, and the line says which is which.
static func _summary(reports: Array[Dictionary], read: int, total: int) -> Dictionary:
	var counts: Dictionary = {"missing": 0, "extra": 0, "thin": 0, "unwritten": 0}
	for page: Dictionary in reports:
		counts["missing"] = int(counts["missing"]) + (page.get("missing", PackedStringArray()) as PackedStringArray).size()
		counts["extra"] = int(counts["extra"]) + (page.get("extra", PackedStringArray()) as PackedStringArray).size()
		counts["thin"] = int(counts["thin"]) + (page.get("thin", []) as Array).size()
		counts["unwritten"] = int(counts["unwritten"]) + (page.get("unwritten", PackedStringArray()) as PackedStringArray).size()
	if read == 0:
		return _finding(CHECK_ID, "info", "", EventSheetL10n.translate("Docs: guides are checked in the editor, where the vocabulary is already loaded. Outside it the help bundle build prints the same report."), "summary")
	var message: String = EventSheetL10n.translate("Docs: %d of %d guide(s) read, %d out of step.") % [
		read, total, reports.size()]
	message += " " + EventSheetL10n.translate("%d verb(s) undocumented, %d name(s) no verb answers to, %d description(s) that say nothing, %d verb(s) the changelog never mentions.") % [
		int(counts["missing"]), int(counts["extra"]), int(counts["thin"]), int(counts["unwritten"])]
	if reports.size() > GUIDES_LISTED_LIMIT:
		message += " " + EventSheetL10n.translate("The %d worst are listed below.") % GUIDES_LISTED_LIMIT
	return _finding(CHECK_ID, "info", "", message, "summary")


## One guide's lines: the headline for the page, then at most a few of the things it holds, worst
## question first. What a reader needs from a line is the ONE verb to go and look at, not the list.
##
## Public and pure over one coverage report, which is what lets a test hand the SAME report to this
## and to the build tool's listing and pin that the two say the same sentence about the guide. The
## headline IS the build tool's line: there is one sentence, not two that have to be kept in step.
static func page_findings(page: Dictionary) -> Array[Dictionary]:
	var page_id: String = str(page.get("page", ""))
	var path: String = EventSheetDocLibrary.page_path(page_id)
	var out: Array[Dictionary] = []
	out.append(_finding(CHECK_ID, "info", path, EventSheetDocCoverage.advisory_line(page), page_id))
	var missing: PackedStringArray = page.get("missing", PackedStringArray())
	for index: int in range(mini(missing.size(), LINES_PER_GUIDE_LIMIT)):
		out.append(_finding(EventSheetDocCoverage.CHECK_UNLISTED, "info", path,
			EventSheetL10n.translate("%s publishes %s and the guide never names it. A reader who searched the guide concluded it does not exist.") % [
				page_id.get_file(), missing[index]],
			missing[index]))
	var extra: PackedStringArray = page.get("extra", PackedStringArray())
	var nearest: Dictionary = page.get("nearest", {}) as Dictionary
	for index: int in range(mini(extra.size(), LINES_PER_GUIDE_LIMIT)):
		var name: String = extra[index]
		var closest: PackedStringArray = nearest.get(name, PackedStringArray())
		out.append(_finding(EventSheetDocCoverage.CHECK_UNANSWERED, "info", path,
			EventSheetL10n.translate("%s documents \"%s\" and no verb answers to it. Nearest that do: %s.") % [
				page_id.get_file(), name, ", ".join(closest)] if not closest.is_empty()
			else EventSheetL10n.translate("%s documents \"%s\" and no verb answers to it, nor anything near it.") % [
				page_id.get_file(), name],
			name))
	var thin: Array = page.get("thin", []) as Array
	for index: int in range(mini(thin.size(), LINES_PER_GUIDE_LIMIT)):
		var entry: Dictionary = thin[index] as Dictionary
		out.append(_finding(EventSheetDocCoverage.CHECK_THIN, "info", path,
			EventSheetL10n.translate("%s lists %s with nothing under \"what it does\". Draft: \"%s\"") % [
				page_id.get_file(), str(entry.get("name", "")),
				EventSheetDocCoverage.draft_note(str(entry.get("name", "")), str(entry.get("params", "")))],
			str(entry.get("name", ""))))
	var unwritten: PackedStringArray = page.get("unwritten", PackedStringArray())
	for index: int in range(mini(unwritten.size(), LINES_PER_GUIDE_LIMIT)):
		out.append(_finding(EventSheetDocCoverage.CHECK_UNWRITTEN, "info", path,
			EventSheetL10n.translate("%s shipped, but nothing in the changelog ever mentions %s. Write the line while you still remember what changed.") % [
				page_id.get_file(), unwritten[index]],
			unwritten[index]))
	return out


## The ledger this project keeps, or "" when it keeps none. An installed plugin has no CHANGELOG.md
## beside it, and the unwritten-change question simply does not arise there - which is correct: it is
## a question about a repository, and a project without one has nothing to be behind on.
static func _changelog_text() -> String:
	var file: FileAccess = FileAccess.open(EventSheetDocWhatsNew.SOURCE_PATH, FileAccess.READ)
	return "" if file == null else file.get_as_text()


static func _finding(check_id: String, severity: String, path: String, message: String,
		subject: String) -> Dictionary:
	return {
		"severity": severity, "check": check_id, "path": path, "message": message,
		"subject": subject,
	}
