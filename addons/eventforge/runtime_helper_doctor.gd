# Godot EventSheets - the Doctor's Runtime scripts section.
#
# A few built-in rows (a spawn at a free spot, a retire, a bus mix, world look, haptics, a sequencer)
# emit a call to a small script that lives at the top of eventsheet_addons/. A project that took the
# plugin from addons/ holds none of them until a row that needs one is applied, and a script copied
# from another project, or a folder tidied by hand, can leave a call with nothing behind it - a
# parse error the first time the game runs. This section reads every script in the project as text
# (no game run), names each one that calls a runtime script the project does not hold, and offers
# the door that copies it in from the library the plugin carries.
@tool
class_name EventSheetRuntimeHelperDoctor
extends EventSheetDoctorSection

## The id the section is registered under, and the id each finding is filed as. Frozen: the fix
## door addresses a finding by its check id.
const CHECK_ID := "runtime-helper"
const HELPERS := preload("res://addons/eventforge/runtime_helpers.gd")


static func ensure_registered() -> void:
	EventSheetProjectDoctor.register_check(CHECK_ID, Callable(EventSheetRuntimeHelperDoctor, "check"))


## The section: one warning per script (not under addons/) that names a runtime script the project
## lacks. Never writes inside res://.
static func check(_sheet_paths: PackedStringArray, findings: Array[Dictionary]) -> void:
	if not DirAccess.dir_exists_absolute(HELPERS.LIBRARY_DIR):
		return
	var scripts: PackedStringArray = EventSheetProjectDoctor._list_files_with_extension("gd")
	scripts.sort()
	for script_path: String in scripts:
		if script_path.begins_with("res://addons/"):
			continue
		var lacking: PackedStringArray = HELPERS.lacking_for_text(EventSheetProjectDoctor.source_of(script_path))
		if lacking.is_empty():
			continue
		var found: Dictionary = _finding("warning", CHECK_ID, script_path,
			"%s calls %s, which this project does not hold - it will not run until the script is added." % [
				script_path.get_file(), ", ".join(lacking)], script_path.get_file())
		found["files"] = lacking
		found["kind"] = CHECK_ID
		findings.append(found)


## The door "Add it to the project": copies the scripts the finding names from the library.
static func add_to_project(finding: Dictionary) -> Dictionary:
	var wanted: PackedStringArray = PackedStringArray(finding.get("files", PackedStringArray()))
	if wanted.is_empty():
		return {"ok": false, "message": "Nothing to add - re-run the check."}
	var copied: PackedStringArray = HELPERS.copy_into_project(wanted)
	if copied.is_empty():
		return {"ok": false, "message": "The scripts could not be copied from the library."}
	if Engine.has_singleton("EditorInterface"):
		(Engine.get_singleton("EditorInterface") as Object).call("get_resource_filesystem").call("scan")
	return {"ok": true, "message": "Added %s to eventsheet_addons/." % ", ".join(copied)}
