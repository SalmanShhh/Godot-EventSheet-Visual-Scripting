# Godot EventSheets - the Doctor's Save Memory section.
#
# One finding, and it describes a row that runs today, raises nothing, and answers a DIFFERENT
# question from the one it says it answers. First Time In This Save, Has Seen, Mark Seen and Forget
# Seen keep their memory in the save slot when the Save System pack is registered as the SaveSystem
# autoload, and in user://remembered.cfg when it is not - which means one answer for the whole
# computer instead of one per save, and nothing to clear it, because Start New Run belongs to that
# pack. The rows still work; they are just per-machine, exactly like Only Once Ever beside them.
#
# That is a NOTE and never a warning. Falling back is a documented behaviour a project may have
# chosen deliberately - a single-save game has no slots to tell apart - so the section says what is
# true and offers the two ways out, and the sheet does what the quiet sheet always does: the amber
# state on the row, and these words in the triage inbox and the row's help strip.
#
# It ships as an EXTENSION check, registered through the very seam a pack uses
# (`EventSheets.register_doctor_check`), so a pack shipping a save of its own lands in this same
# section rather than inventing a second report. Registering from the Doctor's own run is what makes
# it show up in all four runners (the panel, the headless CLI, CI and the MCP server) without the
# plugin having to be loaded first.
#
# IT READS EMITTED SCRIPTS, not sheet resources, for the reason every section here does: `.gd` is
# the default sheet format, and a `.tres` walk misses most real projects. The words it looks for are
# the ones these rows compile to, so a hand-written call to the same helper is audited exactly like
# a row - which is right, because it IS the same line.
#
# NOTHING is written and nothing is stored. A project that never asks the save what it has seen pays
# one substring test per script and reports nothing at all.
@tool
class_name EventSheetSaveMemoryDoctor
extends EventSheetDoctorSection

## The id the section is registered under, and the id the finding is filed as. Frozen alongside the
## wording: the quick-fix chips and the tests address a finding by its check id.
const CHECK_ID := "save-memory"
const CHECK_NO_SAVE_PACK := "save-memory-no-save-pack"

## The autoload the per-save rows look for at run time. A project that registers the Save System
## pack under a different name falls back exactly as one without the pack does, which is why the
## question asked here is this setting rather than whether the pack's file is on disk.
const SAVE_AUTOLOAD := "SaveSystem"

## The cheap first question asked of a script's text: the helper names and the store words these
## four rows compile to. A file saying none of them cannot hold one of these rows, and a project
## full of ordinary scripts should not pay to be searched properly to find that out.
const SHEET_WORDS: PackedStringArray = ["__first_time_in_save_", "__seen_in_save_",
	"__seenstore_", "\"SeenInSave\""]


## Registers the section, replacing any previous registration - so a plugin reload, a second Doctor
## run and a test that registers it by hand all leave exactly one.
static func ensure_registered() -> void:
	EventSheets.register_doctor_check(CHECK_ID, Callable(EventSheetSaveMemoryDoctor, "check"))


## The section itself, with the contract every registered check has: append findings, never write
## inside res://.
static func check(_sheet_paths: PackedStringArray, findings: Array[Dictionary]) -> void:
	if save_pack_is_registered():
		return
	var paths: PackedStringArray = PackedStringArray()
	for script_path: String in EventSheets.project_scripts():
		if script_path.begins_with(PLUGIN_DIRECTORY):
			continue
		if _says_any(EventSheetProjectDoctor.source_of(script_path), SHEET_WORDS):
			paths.append(script_path)
	findings.append_array(report(paths))


## Whether this project registers the Save System pack as an autoload under the name the rows look
## for. Its own function so a test can say what it means without editing ProjectSettings.
static func save_pack_is_registered() -> bool:
	return ProjectSettings.has_setting("autoload/%s" % SAVE_AUTOLOAD)


## The whole section as findings, over the scripts that hold one of these rows. Pure over the paths,
## so a test hands it two names and pins the words without a project around it.
static func report(paths: PackedStringArray) -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	if paths.is_empty():
		return findings
	var sorted: PackedStringArray = paths.duplicate()
	sorted.sort()
	for path: String in sorted:
		# The sentence goes through the editor's own translator like every other Doctor note, so
		# the one line this section says is not the one English line in a translated inbox.
		findings.append(_finding("info", CHECK_NO_SAVE_PACK, path,
			EventSheetL10n.translate("%s asks the save what it has already seen, and this project registers no %s autoload - so the memory goes to user://remembered.cfg instead: one answer for the whole computer rather than one per save, and nothing clears it, because Start New Run belongs to that pack. Install the Save System pack and register it, or use Only Once Ever, which says per-machine on the label.") % [
				path.get_file(), SAVE_AUTOLOAD], path))
	return findings
