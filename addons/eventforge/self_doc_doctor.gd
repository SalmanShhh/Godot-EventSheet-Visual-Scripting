# Godot EventSheets - the Doctor's "describe the undescribed" page, and the drift note beside it.
#
# The gap this closes is not that people refuse to write descriptions. It is that the moment writing
# one is cheap - while the function is being made - is not the moment anybody wants to stop and write
# prose, and by the time somebody wants the prose the function is six weeks old. So the page collects
# every public thing that has no description, drafts one for each out of its own rows, and lets the
# whole list be accepted one line at a time.
#
# NOTHING HERE IS AN ERROR. Every line is a note. A project with no descriptions at all is a working
# project, and the Doctor saying otherwise would only teach people to ignore the Doctor. Nothing here
# writes either: the section reports, and the accepting happens where the user is, one undoable edit
# at a time, showing the words before and the words after.
#
# THE DRIFT NOTE is the other half, and the one a stale document could never do for itself. A
# description a person accepted describes the rows as they were. When those rows are replaced by
# different ones, the words go on sounding authoritative while being wrong - which is worse than the
# gap, because a reader believes them. So a description whose function no longer names ANY of the
# things the description talks about is listed, with a fresh draft beside the old words, and the
# person decides. Rewording is not drift; only losing the subject is.
@tool
class_name EventSheetSelfDocDoctor
extends EventSheetDoctorSection

## The id the section is registered under, and the ids its two kinds of line are filed as. Frozen
## alongside the wording, because a quick-fix chip and the tests address a finding by its check id.
const CHECK_ID := "self-doc"
const CHECK_UNDESCRIBED := "self-doc-undescribed"
const CHECK_DRIFTED := "self-doc-drifted"

## How many undescribed things one page lists by name before it counts the rest. A list of two
## hundred lines is a list nobody reads; the summary line always states the true total.
const LISTED_LIMIT: int = 20

## How many sheets one audit reads for this section. A ceiling, not a target: the section says how
## many of how many it read, so a big project gets a useful page in a moment rather than a complete
## one nobody waits for.
const SHEETS_READ_LIMIT: int = 6


## Registers the section, replacing any previous registration - so a plugin reload, a second Doctor
## run and a test that registers it by hand all leave exactly one.
static func ensure_registered() -> void:
	EventSheets.register_doctor_check(CHECK_ID, Callable(EventSheetSelfDocDoctor, "check"))


## The section itself, with the contract every registered check has: append findings, never write
## inside res://.
static func check(sheet_paths: PackedStringArray, findings: Array[Dictionary]) -> void:
	# The walk is CAPPED, and says so. Cataloguing a sheet and drafting for each gap is cheap per
	# sheet and not free, and a project of two hundred sheets would otherwise pay for all of them on
	# every audit - which is how a section becomes one nobody runs. The first few in path order are
	# read, the rest are counted, and the count is the whole truth about what was skipped.
	var sorted: PackedStringArray = sheet_paths.duplicate()
	sorted.sort()
	var read: int = 0
	for sheet_path: String in sorted:
		if read >= SHEETS_READ_LIMIT:
			findings.append(_finding("info", CHECK_ID, "",
				EventSheetL10n.translate("Descriptions: %d sheet(s) read of %d. Open the rest and the page will have them too.") % [
					read, sorted.size()], ""))
			return
		var sheet: Resource = ResourceLoader.load(sheet_path)
		if sheet is EventSheetResource:
			read += 1
			findings.append_array(report(sheet as EventSheetResource, sheet_path))


## The whole section for ONE sheet, as findings. Pure over a sheet and the path to call it by, so a
## test can hand it a sheet built in memory and pin every word.
static func report(sheet: EventSheetResource, sheet_path: String) -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	if sheet == null:
		return findings
	var undescribed: Array[Dictionary] = undescribed_entries(sheet)
	if not undescribed.is_empty():
		var numbers: Dictionary = EventSheetDescriptions.coverage(sheet)
		findings.append(_finding("info", CHECK_ID, sheet_path,
			EventSheetL10n.translate("%s: %s. Each line below drafts a description out of the thing's own rows - accept it, edit it, or write your own.") % [
				sheet_path.get_file(), EventSheetDescriptions.coverage_sentence(sheet)],
			str(numbers.get("described", 0))))
	for index: int in range(undescribed.size()):
		if index >= LISTED_LIMIT:
			break
		var entry: Dictionary = undescribed[index]
		findings.append(_finding("info", CHECK_UNDESCRIBED, sheet_path, _undescribed_line(entry),
			"%s:%s" % [str(entry.get("kind", "")), str(entry.get("name", ""))]))
	for drifted: Dictionary in drifted_entries(sheet):
		findings.append(_finding("info", CHECK_DRIFTED, sheet_path, _drifted_line(drifted),
			str(drifted.get("name", ""))))
	return findings


## Every describable thing of this sheet that has no description, in catalog order, each carrying the
## draft its own rows compose. Entries whose rows compose nothing keep an empty draft: the page still
## lists them, because a thing nobody can draft for is exactly the thing a person has to write.
static func undescribed_entries(sheet: EventSheetResource) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for entry: Dictionary in EventSheetDescriptions.catalog(sheet):
		if bool(entry.get("described", false)):
			continue
		var listed: Dictionary = entry.duplicate()
		listed["draft"] = EventSheetDescriptionDrafts.for_entry(sheet, entry)
		found.append(listed)
	return found


## Every function whose accepted description no longer names anything its rows do, each carrying the
## words that stand and the draft that would replace them. Sheet order, so the note reads down the
## page the way the sheet does.
static func drifted_entries(sheet: EventSheetResource) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	if sheet == null:
		return found
	for function_entry: Variant in sheet.functions:
		if not function_entry is EventFunction:
			continue
		var event_function: EventFunction = function_entry as EventFunction
		if not EventSheetDescriptionDrafts.function_description_drifted(event_function):
			continue
		found.append({
			"name": event_function.function_name,
			"described": EventSheetDescriptions.for_function(event_function),
			"draft": EventSheetDescriptionDrafts.for_function(event_function),
		})
	return found


## One undescribed thing in a sentence: what it is, and what its rows would say for it. The draft is
## quoted so a reader can see where the plugin's words stop.
static func _undescribed_line(entry: Dictionary) -> String:
	var draft: String = str(entry.get("draft", "")).strip_edges()
	if draft.is_empty():
		return EventSheetL10n.translate("%s %s has no description, and its rows do not compose one - this is a line only you can write.") % [
			str(entry.get("kind", "")), str(entry.get("name", ""))]
	return EventSheetL10n.translate("%s %s has no description. Draft from its own rows: \"%s\"") % [
		str(entry.get("kind", "")), str(entry.get("name", "")), draft]


## One drifted description in a sentence: the words that stand, then the words the rows say now, so
## the choice is visible without opening anything.
static func _drifted_line(entry: Dictionary) -> String:
	return EventSheetL10n.translate("%s still says \"%s\", but its rows no longer mention any of that. Fresh draft: \"%s\"") % [
		str(entry.get("name", "")), str(entry.get("described", "")), str(entry.get("draft", ""))]
