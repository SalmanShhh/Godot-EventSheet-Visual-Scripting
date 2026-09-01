# EventForge - the one thing this plugin remembers about a project's own history.
#
# A sheet is a plain `.gd` file, and nothing about the plugin may be written into one: no version
# header, no tool marker, no comment a hand author would not have typed. So the single fact worth
# remembering across sessions - which vocabulary this project's sheets were last edited under -
# lives OUTSIDE the sheets entirely, as one line of `project.godot`:
#
#   eventsheets/project/vocabulary_version="0.17.0"
#
# One line, committed with the project, and trivially mergeable: two branches that disagree resolve
# by taking either side, because the value only ever moves forward and the next edit rewrites it.
# There is no sidecar file, no cache anybody has to keep, and nothing machine-local in it.
#
# WHAT IT IS FOR, AND WHAT IT IS NOT. The sheet head's band is derived from the ROWS - which of them
# have a newer spelling, counted where they are - and it says so with or without this record. The
# record only upgrades "these rows have a newer spelling" to "these rows have a newer spelling, since
# 0.14", which is the difference between a fact and a fact with a date on it. A project that has
# never carried the record still gets the band.
#
# It is a VERSION, never a date. A date says when a machine's clock read something; a version says
# which vocabulary the words in these sheets came from, which is the only thing a reader can act on.
@tool
class_name EventForgeVocabularyRecord
extends RefCounted

## The one project-level entry. Registered in Project Settings like every other, so it is visible and
## documented rather than an invisible get_setting() default.
const SETTING: String = "eventsheets/project/vocabulary_version"


## The vocabulary version this project's sheets were last edited under, or "" when the project has
## never carried the record (an older project, or one nobody has edited a sheet in yet).
static func recorded() -> String:
	return str(ProjectSettings.get_setting(SETTING, "")).strip_edges()


## The vocabulary version running right now - the compiler's own, because the compiler is what turns
## the vocabulary into code and its version is the one already stamped on everything else.
static func current() -> String:
	return SheetCompiler.VERSION


## Writes the record, and returns whether it actually wrote. Called when a sheet is SAVED from the
## editor, which is the moment "last edited under" becomes true - and only when the value would
## change, so a project.godot is touched once per version rather than once per save.
##
## Never runs outside a live editor session: a headless compile, a test run or an exported game has
## not edited anything, and writing a project file from one of those would be a surprise.
static func stamp() -> bool:
	if not Engine.is_editor_hint():
		return false
	var running: String = current()
	if recorded() == running:
		return false
	ProjectSettings.set_setting(SETTING, running)
	ProjectSettings.save()
	return true


## The head band's entry for one sheet: how many of its rows have a newer spelling, and the version
## the record says they were written under. The COUNT is the caller's - it comes from the rows
## themselves, which is what makes the band true in a project that has no record at all.
static func band_facts(count: int) -> Dictionary:
	return {"count": maxi(count, 0), "since": recorded()}


## The band's one line, or "" when nothing on this sheet has a newer spelling - which is every sheet
## in a project that is up to date, and the reason the band is normally absent rather than reassuring.
##
## One counting line and nothing else: the sentences and the doors are the Doctor's and the selected
## row's help strip's, and the sheet itself stays exactly as it looks with nothing to migrate.
static func band_reading(facts: Dictionary) -> String:
	var count: int = int(facts.get("count", 0))
	if count <= 0:
		return ""
	var since: String = str(facts.get("since", "")).strip_edges()
	if since.is_empty():
		return EventSheetL10n.translate("1 row has a newer spelling") if count == 1 \
			else EventSheetL10n.translate("%d rows have a newer spelling") % count
	if count == 1:
		return EventSheetL10n.translate("1 row has a newer spelling, since %s") % since
	return EventSheetL10n.translate("%d rows have a newer spelling, since %s") % [count, since]
