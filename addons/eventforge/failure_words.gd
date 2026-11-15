# Godot EventSheets - the words for a file Godot would not write.
#
# Godot hands back a bare error NUMBER when a save, a copy or a delete fails, and a number tells a
# reader nothing. Every message that used to print one now goes through here, so each says what failed,
# names the file, gives Godot's own words for the cause and says what to try next. Reach it by path
# (`load("res://addons/eventforge/failure_words.gd")`); it has no class_name so loading it compiles
# nothing more and no boot-path script has to name it.
@tool
extends RefCounted


## "Could not save <file> - Godot says: <cause>. <what to do>". `error` is a Godot Error value.
static func save_failed(path: String, error: int) -> String:
	return EventSheetL10n.translate("Could not save %s - Godot says: %s. %s") % [path, error_string(error),
		EventSheetL10n.translate("Nothing was changed. Check that the file is not read-only or open in another program, that its folder exists and that the disk has room, then try again.")]


## The same for a delete.
static func delete_failed(path: String, error: int) -> String:
	return EventSheetL10n.translate("Could not delete %s - Godot says: %s. %s") % [path, error_string(error),
		EventSheetL10n.translate("Nothing was removed. Close anything that has the file open, then try again.")]


## The same for a copy that did not land at `destination`.
static func copy_failed(destination: String, error: int) -> String:
	return EventSheetL10n.translate("Could not copy to %s - Godot says: %s. %s") % [destination, error_string(error),
		EventSheetL10n.translate("The original is untouched. Check that the folder exists and is not read-only, then try again.")]


## The same for a web request that could not even start.
static func request_failed(address: String, error: int) -> String:
	return EventSheetL10n.translate("Could not reach %s - Godot says: %s. %s") % [address, error_string(error),
		EventSheetL10n.translate("Nothing was sent. Check the address and your internet connection, then try again.")]



## The compiler could not put the script it wrote at `path`: the usual causes are a file that is
## read-only, open in another program or held by a cloud-sync tool. The write goes through a temporary
## file and a rename, so the old file is still whole.
static func write_blocked(path: String) -> String:
	return EventSheetL10n.translate("Could not write %s. It may be read-only, open in another program, or held by a cloud-sync tool. Nothing was overwritten - the file is exactly as it was. Close whatever has it open, then save again.") % path


## The status line for a script sheet whose Save did not compile. When the only thing wrong is that the
## file could not be written there is nothing for the reader to fix in a row, so the line is the
## write failure alone; otherwise it is the compiler's errors after "fix the error, then save again".
static func compile_failed(errors: Array, path: String) -> String:
	if errors.size() == 1 and str(errors[0]) == write_blocked(path):
		return str(errors[0])
	return "This sheet doesn't compile yet - fix the error, then save again. (%s)" % ", ".join(PackedStringArray(errors))
