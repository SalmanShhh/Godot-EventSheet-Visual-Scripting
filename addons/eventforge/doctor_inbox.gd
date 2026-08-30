# Godot EventSheets - the Doctor's front page, as a triage inbox.
#
# The audit grew sections faster than it grew a way to read them. Every section is defensible on its
# own and the sum of them is a junk drawer: sixty findings in the order the checks happen to run, an
# error about a stale script sitting between two notes about a variable nobody uses, and no way to
# tell what appeared since the last time anybody looked. A report nobody reads is the same as no
# report, so the front page has to answer three questions before it answers anything else:
#
#   WHAT IS BROKEN     severity first, always. Errors, then warnings, then notes, and inside each the
#                      findings in a fixed order so two audits of an unchanged project read the same.
#   WHAT IS NEW        every finding carries an identity, and the identities of the last read are kept.
#                      A finding whose identity was not there last time is NEW, and that is the only
#                      thing on the page worth a mark.
#   WHERE DOES IT LIVE the check that raised it, so a reader can see at a glance that eleven of the
#                      twelve notes come from one sweep and judge the sweep rather than the notes.
#
# THE IDENTITY IS THE FINDING, NOT ITS POSITION: check id, file and subject, joined. So a finding
# that moves down the report because something above it was fixed is not new, and the same warning
# about a different file is. Nothing about the message text is in it on purpose - rewording a check
# tomorrow must not flood a reader's page with things they have already read.
#
# WHAT IS REMEMBERED, AND WHERE: the identities of the last read, in the project's own user
# directory. It is a reading position, not project data: it belongs to the person reading, never
# travels in a commit, and losing it costs one page that says everything is new.
@tool
class_name EventSheetDoctorInbox
extends RefCounted

## Where the last read is kept between editor sessions. One file per project, holding one list.
const SEEN_PATH := "user://eventsheets_doctor_seen.cfg"
const SEEN_SECTION := "read"
const SEEN_KEY := "identities"

## Severity, worst first. The order the page is in, and the only ordering rule that is not
## alphabetical - because it is the one a reader actually has.
const SEVERITY_ORDER: PackedStringArray = ["error", "warning", "info"]


## What each severity is called on the page. "Notes" rather than "info": the page is read by people
## shipping a game, not by people reading a log. Written out as literals rather than looked up in a
## table, because the translation sweep reads the words out of the call and a table's values are
## invisible to it - a heading nobody keyed is the one English line in a translated window.
static func severity_label(severity: String) -> String:
	match severity:
		"error":
			return EventSheetL10n.translate("Errors")
		"warning":
			return EventSheetL10n.translate("Warnings")
		"info":
			return EventSheetL10n.translate("Notes")
	return severity


## The identity of one finding: what it is about, never where it appeared. Two audits of an unchanged
## project produce the same identities, and a check reworded overnight produces the same ones too.
static func identity(finding: Dictionary) -> String:
	return "%s|%s|%s" % [
		str(finding.get("check", "")),
		str(finding.get("path", "")),
		str(finding.get("subject", "")),
	]


## The page: every finding of the audit, severity first, each carrying `is_new` against the
## identities of the last read. Ordering inside a severity is check, then file, then message - fixed,
## so a reader who scrolled to a line yesterday finds it in the same place today.
##
## Pure over its two arguments, which is what lets the panel, the CLI and a test all build the same
## page from the same findings.
static func triage(findings: Array, seen: PackedStringArray) -> Array[Dictionary]:
	var sorted: Array[Dictionary] = []
	for finding: Variant in findings:
		if finding is Dictionary:
			sorted.append((finding as Dictionary).duplicate())
	sorted.sort_custom(_before)
	var out: Array[Dictionary] = []
	for finding: Dictionary in sorted:
		var entry: Dictionary = finding.duplicate()
		entry["identity"] = identity(finding)
		entry["is_new"] = not seen.has(str(entry["identity"]))
		out.append(entry)
	return out


## The sections of the page: one per check that reported, with what it holds. Ordered by the worst
## thing in them and then by name, so the section a reader has to act on is the one at the top.
##
## THE BAND SCALE LAW applies to the page as a whole: a section says what it holds and how much, and
## the findings themselves are what is enumerated - never the checks that had nothing to say.
static func sections(triaged: Array[Dictionary]) -> Array[Dictionary]:
	var by_check: Dictionary = {}
	for finding: Dictionary in triaged:
		var check_id: String = str(finding.get("check", ""))
		if not by_check.has(check_id):
			by_check[check_id] = {
				"id": check_id, "label": label_for(check_id),
				"error": 0, "warning": 0, "info": 0, "new": 0,
			}
		var section: Dictionary = by_check[check_id]
		var severity: String = str(finding.get("severity", "info"))
		section[severity] = int(section.get(severity, 0)) + 1
		if bool(finding.get("is_new", false)):
			section["new"] = int(section["new"]) + 1
	var out: Array[Dictionary] = []
	for check_id: Variant in by_check.keys():
		out.append(by_check[check_id])
	out.sort_custom(_section_before)
	return out


## A check id, in words. Derived from the id rather than looked up in a table, so a section added
## tomorrow is titled the moment it reports and nobody has to remember to name it here - and derived
## titles are the reason this one is not written as a literal the way the severity headings above
## are: there is no list of them to write.
##
## It still goes through the catalog, so a heading a project has named in its own drop-in CSV comes
## back named. A heading nobody has keyed comes through in the check's own words, which the sweep
## cannot see because the argument is computed - so the words themselves have to be readable, and
## the sentence a reader acts on is the finding's own message under it, which IS keyed.
static func label_for(check_id: String) -> String:
	var words: String = check_id.replace("-", " ").strip_edges()
	if words.is_empty():
		return EventSheetL10n.translate("Other")
	return EventSheetL10n.translate(words.substr(0, 1).to_upper() + words.substr(1))


## The one line the status bar gets: what was found, and how much of it is new.
static func summary_line(triaged: Array[Dictionary]) -> String:
	var counts: Dictionary = {"error": 0, "warning": 0, "info": 0}
	var new_count: int = 0
	for finding: Dictionary in triaged:
		var severity: String = str(finding.get("severity", "info"))
		counts[severity] = int(counts.get(severity, 0)) + 1
		if bool(finding.get("is_new", false)):
			new_count += 1
	var line: String = EventSheetL10n.translate("Project Doctor: %d error(s), %d warning(s), %d note(s).") % [
		int(counts["error"]), int(counts["warning"]), int(counts["info"])]
	if new_count > 0:
		line += " " + EventSheetL10n.translate("%d new since you last looked.") % new_count
	return line


## Every identity on the page, sorted - what is written down when a reader has looked.
static func identities_of(triaged: Array[Dictionary]) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for finding: Dictionary in triaged:
		var found: String = str(finding.get("identity", identity(finding)))
		if not out.has(found):
			out.append(found)
	out.sort()
	return out


## The identities of the last read. Empty when nobody has ever looked, which is what makes a first
## page show everything as new.
static func load_seen(store_path: String = SEEN_PATH) -> PackedStringArray:
	var file: ConfigFile = ConfigFile.new()
	if file.load(store_path) != OK:
		return PackedStringArray()
	return PackedStringArray(file.get_value(SEEN_SECTION, SEEN_KEY, PackedStringArray()))


## Writes down what has now been read. Sorted, so the file is stable and a reader who diffs their own
## user directory sees the findings that changed rather than a reshuffle.
static func save_seen(identities: PackedStringArray, store_path: String = SEEN_PATH) -> bool:
	var sorted_identities: PackedStringArray = identities.duplicate()
	sorted_identities.sort()
	var file: ConfigFile = ConfigFile.new()
	file.set_value(SEEN_SECTION, SEEN_KEY, sorted_identities)
	return file.save(store_path) == OK


## Forgets the reading position - the next page shows everything as new again.
static func forget_seen(store_path: String = SEEN_PATH) -> void:
	if FileAccess.file_exists(store_path):
		DirAccess.remove_absolute(store_path)


static func _before(left: Dictionary, right: Dictionary) -> bool:
	var left_rank: int = _severity_rank(str(left.get("severity", "info")))
	var right_rank: int = _severity_rank(str(right.get("severity", "info")))
	if left_rank != right_rank:
		return left_rank < right_rank
	return _sort_key(left) < _sort_key(right)


## What a finding sorts by inside its severity: check, then file, then message - fixed, so a reader
## who scrolled to a line yesterday finds it in the same place today.
##
## A section may hand the page its OWN key in an `order` field, and one does: a ledger whose groups
## have to keep their own lines under them cannot survive being re-sorted by file and message, which
## would scatter a group's doors across the page and leave a heading above somebody else's rows. The
## key replaces this one whole, so a section using it must still begin with its own check id or it
## walks into the middle of another section. A finding without the field is ordered exactly as it
## always was, which is every finding but that ledger's.
static func _sort_key(finding: Dictionary) -> String:
	var own: String = str(finding.get("order", ""))
	if not own.is_empty():
		return own
	return "%s|%s|%s" % [finding.get("check", ""), finding.get("path", ""),
		finding.get("message", "")]


static func _section_before(left: Dictionary, right: Dictionary) -> bool:
	var left_worst: int = _worst_rank(left)
	var right_worst: int = _worst_rank(right)
	if left_worst != right_worst:
		return left_worst < right_worst
	return str(left.get("id", "")) < str(right.get("id", ""))


static func _worst_rank(section: Dictionary) -> int:
	for index: int in range(SEVERITY_ORDER.size()):
		if int(section.get(SEVERITY_ORDER[index], 0)) > 0:
			return index
	return SEVERITY_ORDER.size()


static func _severity_rank(severity: String) -> int:
	var found: int = SEVERITY_ORDER.find(severity)
	return found if found >= 0 else SEVERITY_ORDER.size()
