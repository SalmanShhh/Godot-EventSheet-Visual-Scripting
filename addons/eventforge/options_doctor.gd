# Godot EventSheets - the Doctor's Options section.
#
# Three findings, and what they have in common is that each is about a promise the PROJECT makes and
# no row can keep:
#
#   AN ACTION WITH NO BINDING   the Input Map declares a control the player cannot press. It is what
#                     a rebinding screen leaves behind when somebody takes a key away from another
#                     action, and it is also just a half-finished Project Settings page. Either way
#                     the game ships with a verb nobody can reach.
#   A PRESET THAT DOES NOT ANSWER   a quality preset file that says nothing about a setting its
#                     neighbours answer for. Picking it then leaves that setting wherever the last
#                     preset put it, so Low after High is not the same Low as Low after Medium - the
#                     one bug that makes quality presets feel haunted.
#   A DIFFICULTY NOTHING READS   a project that puts a difficulty in force while no row anywhere
#                     multiplies by a factor out of it. The menu offers a choice, the choice is
#                     saved, and the game plays exactly the same either way - which nothing warns
#                     about, because every part of it is working.
#
# THE FIRST TWO ARE READ FROM SMALL FILES ON PURPOSE. The audit already reads every project script
# once and every scene once, and a section that added a third corpus would pay for itself in seconds.
# They ask Project Settings (already in memory) and the three or four resources in the quality folder,
# so a project with neither pays almost nothing and reports nothing at all. The third does read the
# scripts, and pays for it with two substring tests per file before anything is opened properly.
#
# THE DIFFICULTY QUESTION IS ASKED OF CALLS, never of definitions: the words it looks for carry the
# autoload's own name (`Settings.difficulty_factor(`), because the pack that DEFINES those verbs is a
# project script too, and a check that counted `func difficulty_factor` as a reading would be answered
# by the pack itself and never fire for anybody. The one reading it cannot see is the Health pack's
# Scaled By field, which names a factor without naming the verb - a project whose only use of the
# difficulty is that field is told about a menu that does something. That is the safe direction to be
# wrong in: a note nobody needed is worse than a note that never came.
#
# THE QUIET SHEET: none of the three draws anything in the sheet. The row wears the amber state, and
# the words live in the triage inbox and in the row's help strip when it is selected.
#
# NOTHING IS STORED and nothing is written: every answer is derived on every ask, so a fixed project
# stops reporting with no state to clean up.
@tool
class_name EventSheetOptionsDoctor
extends EventSheetDoctorSection

## The id the section is registered under, and the id each finding is filed as. Frozen alongside the
## wording: the tests and the panel address a finding by these.
const CHECK_ID := "options"
const CHECK_UNBOUND := "options-unbound-action"
const CHECK_PRESET_GAP := "options-preset-gap"
const CHECK_DIFFICULTY_UNREAD := "options-difficulty-unread"

## The call sites that put a difficulty in force, and the one that reads a factor back out of it.
## Both are spelled with the autoload's name in front, so the pack that DEFINES the verbs is never
## mistaken for a project that uses them.
const DIFFICULTY_CHOSEN_WORDS: PackedStringArray = ["Settings.use_difficulty(",
	"Settings.use_difficulty_from("]
const DIFFICULTY_READ_WORD := "Settings.difficulty_factor("

## Where Project Settings keeps one input action, and the key its bindings live under.
const INPUT_PREFIX := "input/"
const EVENTS_KEY := "events"

## The file an unbound action is a line of, so double-clicking the finding opens the right thing.
const PROJECT_FILE := "res://project.godot"

## The engine's own actions. They are bound by the editor rather than by this project, and a game
## that leaves ui_home unbound has done nothing wrong.
const ENGINE_ACTION_PREFIX := "ui_"


## Registers the section, replacing any previous registration - so a plugin reload, a second Doctor
## run and a test that registers it by hand all leave exactly one.
static func ensure_registered() -> void:
	EventSheets.register_doctor_check(CHECK_ID, Callable(EventSheetOptionsDoctor, "check"))


## The section, with the contract every registered check has: append findings, never write inside
## res://.
static func check(_sheet_paths: PackedStringArray, findings: Array[Dictionary]) -> void:
	var sources: Array[Dictionary] = []
	for script_path: String in EventSheets.project_scripts():
		var source: String = EventSheetProjectDoctor.source_of(script_path)
		if _says_difficulty(source):
			sources.append({"path": script_path, "source": source})
	findings.append_array(report(project_actions(), EventSheetQualityPresets.preset_paths(), sources))


## Whether a script is worth keeping for the difficulty question at all - the pre-read, deliberately
## looser than the rule behind it: it decides what is carried, not what is reported.
static func _says_difficulty(source: String) -> bool:
	if source.contains(DIFFICULTY_READ_WORD):
		return true
	for word: String in DIFFICULTY_CHOSEN_WORDS:
		if source.contains(word):
			return true
	return false


## Every input action this project declares, in the order Project Settings holds them. The engine's
## own ui_ actions are left out: they belong to the editor, not to the game.
static func project_actions() -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for entry: Dictionary in ProjectSettings.get_property_list():
		var setting_name: String = str(entry.get("name", ""))
		if not setting_name.begins_with(INPUT_PREFIX):
			continue
		var action: String = setting_name.trim_prefix(INPUT_PREFIX)
		if not action.begins_with(ENGINE_ACTION_PREFIX) and not action.is_empty():
			found.append(action)
	return found


## The whole section as findings: the actions nobody can press, the presets that leave a setting
## wherever they found it, then the difficulty nothing reads. Pure over its three corpora - two lists
## and a list of {path, source} - so a test hands it actions, paths and two scripts and this never
## touches the filesystem. The third defaults to nothing, because a caller that has no scripts to
## offer is asking the two questions that were here first.
static func report(actions: PackedStringArray, preset_paths: PackedStringArray,
		sources: Array[Dictionary] = []) -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	for action: String in actions:
		if bindings_of(action).is_empty():
			findings.append(_finding("warning", CHECK_UNBOUND, PROJECT_FILE,
				EventSheetL10n.translate("%s has no binding on any device - nobody can press it. Bind it in Project Settings, or let a Controls page bind it.") % action, action))
	var answered: PackedStringArray = settings_every_preset_should_answer(preset_paths)
	for path: String in preset_paths:
		var missing: PackedStringArray = EventSheetQualityPresets.missing_fields(
			EventSheetQualityPresets.values_of(path), answered)
		if missing.is_empty():
			continue
		findings.append(_finding("warning", CHECK_PRESET_GAP, path,
			EventSheetL10n.translate("%s says nothing about %s, so picking it leaves that where the last preset put it.") % [
				path.get_file(), ", ".join(missing)], missing[0]))
	findings.append_array(_difficulty_findings(sources))
	return findings


## The difficulty question, asked of the project as a whole: something PUTS a difficulty in force and
## nothing READS a factor out of one. It is asked only once a project chooses a difficulty at all, so
## a game that has never heard of the idea says nothing - and the first script that chooses one is
## what the finding points at, because that is the file worth opening.
static func _difficulty_findings(sources: Array[Dictionary]) -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	var chooses: String = ""
	for entry: Dictionary in sources:
		var source: String = str(entry["source"])
		if source.contains(DIFFICULTY_READ_WORD):
			return findings
		if chooses.is_empty():
			for word: String in DIFFICULTY_CHOSEN_WORDS:
				if source.contains(word):
					chooses = str(entry["path"])
					break
	if chooses.is_empty():
		return findings
	findings.append(_finding("info", CHECK_DIFFICULTY_UNREAD, chooses,
		EventSheetL10n.translate("%s chooses a difficulty, but nothing in this project reads a factor out of one - the menu changes nothing. Multiply by Difficulty Factor where the difficulty is meant to be felt.") % chooses.get_file(), ""))
	return findings


## What one action is bound to, straight out of Project Settings. An action declared with no events
## at all, and one whose events were all removed, are the same answer here - which is the point.
static func bindings_of(action: String) -> Array:
	var declared: Variant = ProjectSettings.get_setting("%s%s" % [INPUT_PREFIX, action], null)
	if not (declared is Dictionary):
		return []
	var events: Variant = (declared as Dictionary).get(EVENTS_KEY, [])
	return events if events is Array else []


## The settings every preset ought to answer for: the ones ANY preset answers for. Derived from the
## folder rather than from a list of graphics settings this file would otherwise have to keep, which
## is also what makes a project's own declared option (motion blur, colour blindness) part of the
## question the moment one preset mentions it.
static func settings_every_preset_should_answer(preset_paths: PackedStringArray) -> PackedStringArray:
	var wanted: PackedStringArray = PackedStringArray()
	for path: String in preset_paths:
		for setting_name: Variant in EventSheetQualityPresets.values_of(path).keys():
			if not wanted.has(str(setting_name)):
				wanted.append(str(setting_name))
	return wanted
