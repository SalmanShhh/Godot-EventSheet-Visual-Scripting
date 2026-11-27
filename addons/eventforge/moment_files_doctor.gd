# Godot EventSheets - the Doctor's Moment files section.
#
# One note, and one door: how many of this project's own old moment files can become Juice lists, and a fix that
# makes every one of them a Juice list in place - same path, same uid, so every scene and script pointing at the
# file keeps working - as ONE undo step that writes the old bytes back.
#
# A NOTE AND NOT A WARNING. An old file plays exactly as it always did; nothing is wrong with it. The first edit of
# one in the Inspector converts it anyway, so this is only the way to do the rest at once.
#
# THE WORDS SAY THE ONE THING THAT CAN BITE: a script that loads such a file and casts it to the old class
# (`load("x.tres") as MomentResource`) gets nothing back once the file is a Juice list. A game that hands the file
# to a Juice Player's Moment File slot, or reads its `steps`, notices nothing.
#
# Read from each file's first line only, so a project with thousands of resources pays for a list and a line each.
# Nothing is written until the fix is chosen. It rides the same extension seam a pack's check does.
@tool
class_name EventSheetMomentFilesDoctor
extends EventSheetDoctorSection

## The id the section is registered under and the check id its finding is filed as.
const CHECK_ID := "moment-files"

## By path: it is loaded the first time the section reads or fixes, not at editor boot.
const CONVERSION_PATH: String = "res://addons/eventforge/moment_conversion.gd"


static func ensure_registered() -> void:
	EventSheetProjectDoctor.register_check(CHECK_ID, Callable(EventSheetMomentFilesDoctor, "check"))


static func check(_sheet_paths: PackedStringArray, findings: Array[Dictionary]) -> void:
	findings.append_array(report(own_old_files(EventSheetProjectDoctor._list_files_with_extension("tres"))))


## The old moment files among a list of .tres paths that are the reader's own, in path order. The packs' starter
## files and the plugin's own folder are left out like every section leaves them out.
static func own_old_files(tres_paths: PackedStringArray) -> PackedStringArray:
	var conversion: GDScript = load(CONVERSION_PATH)
	var found: PackedStringArray = PackedStringArray()
	for path: String in own_paths(tres_paths):
		if conversion.is_old_moment_file(path):
			found.append(path)
	found.sort()
	return found


## The section as findings: nothing when there is nothing to convert or the project has no Juice list script,
## else one note with a fix. Pure over a list of paths, so a test can hand it a corpus.
static func report(old_files: PackedStringArray) -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	if old_files.is_empty() or not load(CONVERSION_PATH).can_convert():
		return findings
	var finding: Dictionary = _finding("info", CHECK_ID, old_files[0], message_for(old_files.size()), "")
	finding["fix"] = Callable(EventSheetMomentFilesDoctor, "convert_all").bind(old_files)
	finding["fix_label"] = fix_label_for(old_files.size())
	findings.append(finding)
	return findings


static func message_for(count: int) -> String:
	if count == 1:
		return EventSheetL10n.translate("1 old moment file can become a Juice list. It plays the same either way and keeps its path, so scenes and scripts pointing at it keep working; only a script that loads it and casts it to the old class gets nothing back.")
	return EventSheetL10n.translate("%d old moment files can become Juice lists. They play the same either way and keep their paths, so scenes and scripts pointing at them keep working; only a script that loads one and casts it to the old class gets nothing back.") % count


static func fix_label_for(count: int) -> String:
	return EventSheetL10n.translate("Make it a Juice list") if count == 1 else EventSheetL10n.translate("Make all %d Juice lists") % count


## The fix: every file becomes a Juice list in one undo step. The finding the panel hands back is ignored.
static func convert_all(_finding_arg: Dictionary, old_files: PackedStringArray) -> int:
	return load(CONVERSION_PATH).convert_files(old_files, EventSheetL10n.translate("Turn old moment files into Juice lists"))
