# Godot EventSheets - the Doctor's Damage section.
#
# Typed damage is two lists that have to agree and nothing forces them to: the kinds a project DEALS,
# written into rows one at a time as the game grows, and the kinds it has WRITTEN DOWN in a
# DamageTypeSet. A single mistyped word splits them, and the game goes on running - "fier" resists
# nothing, "fire" resistance protects against nothing - because a damage type is only ever a word.
# Nothing crashes, nothing warns, and the enemy that was supposed to shrug off flame simply does not.
#
# Two findings, and they are the two directions the lists can disagree in:
#
#   A KIND NOBODY DECLARED   a row deals "fier" and no set in the project names it. Almost always a
#                          typo, occasionally a set nobody has written yet; either way the author
#                          is the only one who can tell, so this is a note rather than an error.
#   A GUARD AGAINST NOTHING  a node resists, is immune to or is weak to a kind no row in the project
#                          ever deals. The armour of a build that will never be tested.
#
# BOTH ARE SILENT ON A PROJECT THAT HAS WRITTEN NOTHING DOWN. Types are optional - a game may deal
# them without ever making a set - so the first finding is only asked once a set exists, and the
# second only once some row deals something. A list that is missing an entry must never become a
# finding claiming the entry does not exist.
#
# It ships as an EXTENSION check, registered through the very seam a pack uses
# (`EventSheets.register_doctor_check`), so a pack that adds damage of its own - an elements kit, a
# status system - joins this same section rather than inventing a second report. Registering from the
# Doctor's own run is what makes it show up in all four runners (the panel, the headless CLI, CI and
# the MCP server) without the plugin having to be loaded first.
#
# THE QUIET SHEET: neither finding draws anything in the sheet. The row wears the amber state, and
# the words live in the triage inbox and in the row's help strip when it is selected.
#
# NOTHING is written and nothing is stored: a script is read as text, measured and dropped. A project
# that deals no typed damage pays one substring test per script and reports nothing at all.
@tool
class_name EventSheetDamageDoctor
extends EventSheetDoctorSection

## The id the section is registered under, and the id each of the two findings is filed as. Frozen
## alongside the wording: the quick-fix chips and the tests address a finding by its check id.
const CHECK_ID := "damage"
const CHECK_UNKNOWN_TYPE := "damage-unknown-type"
const CHECK_GUARD_UNUSED := "damage-guard-against-nothing"

## The words a script must say before it is worth reading properly. The pre-read, and deliberately
## looser than the rules behind it: it decides what is opened, not what is reported.
const DAMAGE_WORDS: PackedStringArray = ["take_typed_damage(", "resist(", "immune_to(", "weak_to("]


## Registers the section, replacing any previous registration - so a plugin reload, a second Doctor
## run and a test that registers it by hand all leave exactly one.
static func ensure_registered() -> void:
	EventSheets.register_doctor_check(CHECK_ID, Callable(EventSheetDamageDoctor, "check"))


## The section itself, with the contract every registered check has: append findings, never write
## inside res://.
static func check(_sheet_paths: PackedStringArray, findings: Array[Dictionary]) -> void:
	var sources: Array[Dictionary] = []
	for script_path: String in EventSheets.project_scripts():
		var source: String = EventSheetProjectDoctor.source_of(script_path)
		if _says_any(source, DAMAGE_WORDS):
			sources.append({"path": script_path, "source": source})
	findings.append_array(report(sources, EventForgeDamageTypeFacts.project_type_names(),
		EventForgeDamageTypeFacts.has_any_set()))


## The whole section as findings, the summary first. Pure over its corpus - a list of
## {path, source} and the project's declared names - so a test hands it two scripts and a set and
## never touches the filesystem.
##
## The two passes are in the order the questions can be answered: a kind is unknown per SCRIPT, but a
## guard is against nothing only across the WHOLE project, so every script has to be read before the
## second question can be asked of any of them.
static func report(sources: Array[Dictionary], declared: PackedStringArray,
		any_set_exists: bool) -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	if sources.is_empty():
		return findings
	var dealt_anywhere: Dictionary = {}
	# WHO ACTUALLY SAYS A KIND. The pre-read admits any script holding one of the four words, which
	# includes the packs that DEFINE them - the Health behaviour's own `func take_typed_damage` is a
	# hit on `take_typed_damage(`. A script that names no kind has nothing in either list, so it is
	# not one of the scripts this section is counting, and a report of nothing but definitions says
	# nothing at all rather than "2 scripts deal typed damage" about the plugin itself.
	var speaking: int = 0
	var first_speaking: String = ""
	for entry: Dictionary in sources:
		var text: String = str(entry["source"])
		if not (EventForgeDamageTypeFacts.types_dealt(text).is_empty()
				and EventForgeDamageTypeFacts.types_opined(text).is_empty()):
			speaking += 1
			if first_speaking.is_empty():
				first_speaking = str(entry["path"])
		for kind: String in EventForgeDamageTypeFacts.types_dealt(text):
			dealt_anywhere[kind] = true
	if speaking == 0:
		return findings
	var undeclared: int = 0
	var unguarded: int = 0
	# The summary points at the FIRST script with something to say, because that is the one worth
	# opening - double-clicking the line in the panel is what takes the reader there.
	var first_path: String = first_speaking
	for entry: Dictionary in sources:
		var path: String = str(entry["path"])
		var source: String = str(entry["source"])
		if any_set_exists:
			for kind: String in EventForgeDamageTypeFacts.types_dealt(source):
				if declared.has(kind):
					continue
				if undeclared == 0 and unguarded == 0:
					first_path = path
				undeclared += 1
				findings.append(_finding("info", CHECK_UNKNOWN_TYPE, path,
					EventSheetL10n.translate("%s deals damage of type \"%s\", which no DamageTypeSet in this project names. A misspelling resists nothing and is never reported by the game itself.") % [
						path.get_file(), kind], kind))
		if dealt_anywhere.is_empty():
			continue
		for kind: String in EventForgeDamageTypeFacts.types_opined(source):
			if dealt_anywhere.has(kind):
				continue
			if undeclared == 0 and unguarded == 0:
				first_path = path
			unguarded += 1
			findings.append(_finding("info", CHECK_GUARD_UNUSED, path,
				EventSheetL10n.translate("%s guards against damage of type \"%s\", which nothing in this project deals. The guard will never be tested.") % [
					path.get_file(), kind], kind))
	findings.insert(0, _finding("info", CHECK_ID, first_path,
		EventSheetL10n.translate("Damage: %d script(s) deal or guard against typed damage, %d type(s) no set names, %d guard(s) against a type nothing deals.") % [
			speaking, undeclared, unguarded], ""))
	return findings
