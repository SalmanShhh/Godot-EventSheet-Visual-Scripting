# Godot EventSheets - the project's own files, found by one directory walk.
#
# The Project Doctor's sweeps and the editor's project-wide indexes all start from the same
# question - which files does this project hold - and the answer used to live inside the Doctor. A
# sheet's first rows ask it too: the "called by" band starts the share index, and the share index
# needs the project's scripts. Asking the Doctor compiled it, and every section it names, into the
# first open of the workspace - four and a half to five seconds of compiling, measured, for a list of
# file paths. So the walk lives here, in a file that names no plugin class, and the Doctor
# walks through it like everybody else.
#
# DELIBERATELY NO `class_name`, so loading it compiles nothing more: reach it with a const preload.
@tool
extends RefCounted

## The directories no sweep steps into: this plugin's own code, which the reader did not write.
## `.godot` and every other dot-directory are skipped by the walk itself.
const PLUGIN_DIRECTORIES: PackedStringArray = ["addons"]

## Every project GDScript outside `addons/`, held between asks - see `all_scripts`.
static var _all_scripts: PackedStringArray = PackedStringArray()
static var _all_scripts_walked: bool = false


## Every project GDScript outside `addons/`, INCLUDING any folders the project declared out of its
## Doctor audit. The whole project, as the filesystem has it.
##
## THE AUDIT IS NOT THE ONLY READER OF THIS WALK, and that is why it is not narrowed. The Doctor's
## own corpus is narrowed, because a finding about a folder the reader called uninteresting is the
## noise the setting removes. The readers here are not the audit, and narrowing them would make the
## editor and the compiler WRONG rather than a report quieter:
##
##   - the baked-local token index, where a name colliding with one in a skipped folder is still a
##     collision the emitted code has to avoid;
##   - the project share index behind the "called by" band and the rename notes, where a caller the
##     editor cannot see is a rename that silently breaks working code;
##   - the sheet-contract gate, which asks whether files round-trip rather than whether they are
##     worth advising about;
##   - the language-variants dialog, which lists what the project actually preloads.
##
## Held between asks and dropped by `clear()`, which the Doctor calls at the top of every run and
## the editor calls on every filesystem change.
static func all_scripts() -> PackedStringArray:
	if not _all_scripts_walked:
		_all_scripts = walk(PLUGIN_DIRECTORIES, func(path: String) -> bool: return path.ends_with(".gd"))
		_all_scripts_walked = true
	return _all_scripts


## Forgets the held list, so the next ask walks the directories again.
static func clear() -> void:
	_all_scripts = PackedStringArray()
	_all_scripts_walked = false


## Every file under res:// that `keeps` says yes to, in path order, stepping over any directory
## named in `skipped_directories` and every dot-directory.
##
## PATH ORDER, ALWAYS. A directory walk hands files back in filesystem order (near-alphabetical on
## NTFS, hash order on ext4), and every list derived from this one - a finding order, a "first
## user" pick, a band's count - would otherwise reorder itself between two machines.
static func walk(skipped_directories: PackedStringArray, keeps: Callable) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var pending: PackedStringArray = PackedStringArray(["res://"])
	while not pending.is_empty():
		var directory_path: String = pending[pending.size() - 1]
		pending.remove_at(pending.size() - 1)
		var directory: DirAccess = DirAccess.open(directory_path)
		if directory == null:
			continue
		directory.list_dir_begin()
		var entry: String = directory.get_next()
		while not entry.is_empty():
			var full_path: String = directory_path.path_join(entry)
			if directory.current_is_dir():
				if not entry.begins_with(".") and not skipped_directories.has(entry):
					pending.append(full_path)
			elif keeps.call(full_path):
				found.append(full_path)
			entry = directory.get_next()
		directory.list_dir_end()
	found.sort()
	return found
