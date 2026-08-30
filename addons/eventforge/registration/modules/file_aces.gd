# EventForge module - File management (read / write / JSON, plus directory + file operations).
#
# Everyday on-disk work - save & load text, serialise to JSON, copy / move / delete files, and manage
# directories - so save systems, config files and level data never force a drop to GDScript. Each
# compiles to the exact native FileAccess / DirAccess call. Reads use the static, null-safe accessors
# (FileAccess.get_file_as_string / DirAccess.get_files_at - they return "" / [] on error rather than
# crashing); writes guard the FileAccess handle so a bad path can't null-deref. Grouped under
# Files / Files: Directories.
#
# EVERY PATH FIELD SAYS ITS PLACE. The path parameters carry the `file_path` hint, which takes any
# GDScript expression exactly as an ordinary expression field does and is spelled apart from it only
# so a muted lead can sit under the box naming the place the path is in - user:// (the player's
# folder: writable, per-player, survives updates) or res:// (the game's own files: READ-ONLY once
# exported). The reading of those places, and where user:// really is on each desktop platform, live
# once in EventForgeFilePlaces, which the lead, the help strip and the Doctor all ask.
@tool
class_name EventForgeFileACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	# ── Files - read / write / JSON / copy / move / delete (act on a path string or expression) ──
	descriptors.append(F.make_descriptor("Core", "FileExists", "File Exists", ACEDescriptor.ACEType.CONDITION, "FileAccess.file_exists({path})", "", [F.make_param("path", "String", "\"user://save.dat\"", "Path", "File path to test. Prefer user:// (res:// is read-only when exported).", "file_path")], "Files", "file {path} exists")
		.described("True when a file exists at that path, so you can check before reading or writing it."))
	descriptors.append(F.make_descriptor("Core", "ReadTextFile", "Read Text File", ACEDescriptor.ACEType.EXPRESSION, "FileAccess.get_file_as_string({path})", "", [F.make_param("path", "String", "\"user://save.dat\"", "Path", "File to read in full as a String (\"\" if it is missing or unreadable).", "file_path")], "Files", "text of file {path}")
		.described("Returns the whole file's contents as text (empty if it's missing or unreadable)."))
	descriptors.append(F.make_descriptor("Core", "GetFileSize", "File Size (bytes)", ACEDescriptor.ACEType.EXPRESSION, "FileAccess.get_file_as_bytes({path}).size()", "", [F.make_param("path", "String", "\"user://save.dat\"", "Path", "File to measure (0 bytes if missing).", "file_path")], "Files", "size of file {path}")
		.described("Returns a file's size in bytes, or zero if the file doesn't exist."))
	descriptors.append(F.make_descriptor("Core", "WriteTextFile", "Write Text File", ACEDescriptor.ACEType.ACTION, "var __file_{uid} = FileAccess.open({path}, FileAccess.WRITE)\nif __file_{uid}:\n\t__file_{uid}.store_string({text})\n\t__file_{uid}.close()", "", [F.make_param("path", "String", "\"user://save.dat\"", "Path", "File to write. OVERWRITES any existing file. Use user:// (res:// is read-only when exported).", "file_path"), F.make_param("text", "String", "\"\"", "Text", "Text content to store.", "expression")], "Files", "write {text} to file {path}")
		.described("Saves text to a file, overwriting anything already there (great for save data)."))
	descriptors.append(F.make_descriptor("Core", "AppendTextFile", "Append To File", ACEDescriptor.ACEType.ACTION, "var __file_{uid} = FileAccess.open({path}, FileAccess.READ_WRITE)\nif __file_{uid}:\n\t__file_{uid}.seek_end()\n\t__file_{uid}.store_string({text})\n\t__file_{uid}.close()", "", [F.make_param("path", "String", "\"user://log.txt\"", "Path", "Existing file to append to (no-op if it does not exist - Write it first).", "file_path"), F.make_param("text", "String", "\"\"", "Text", "Text to append at the end of the file.", "expression")], "Files", "append {text} to file {path}")
		.described("Adds text to the end of an existing file without erasing it (handy for logs)."))
	descriptors.append(F.make_descriptor("Core", "DeleteFile", "Delete File", ACEDescriptor.ACEType.ACTION, "DirAccess.remove_absolute({path})", "", [F.make_param("path", "String", "\"user://save.dat\"", "Path", "File (or empty directory) to delete.", "file_path")], "Files", "delete file {path}")
		.described("Permanently deletes a file (or an empty folder) from disk."))
	descriptors.append(F.make_descriptor("Core", "CopyFile", "Copy File", ACEDescriptor.ACEType.ACTION, "DirAccess.copy_absolute({from}, {to})", "", [F.make_param("from", "String", "\"user://save.dat\"", "From", "Source file path.", "file_path"), F.make_param("to", "String", "\"user://backup.dat\"", "To", "Destination file path.", "file_path")], "Files", "copy {from} to {to}")
		.described("Copies a file from one path to another, leaving the original in place."))
	descriptors.append(F.make_descriptor("Core", "MoveFile", "Move / Rename File", ACEDescriptor.ACEType.ACTION, "DirAccess.rename_absolute({from}, {to})", "", [F.make_param("from", "String", "\"user://old.dat\"", "From", "Current file (or directory) path.", "file_path"), F.make_param("to", "String", "\"user://new.dat\"", "To", "New path / name.", "file_path")], "Files", "move {from} to {to}")
		.described("Moves or renames a file (or folder) to a new path."))

	# ── Files: Directories - make / remove / test / list directories ──
	descriptors.append(F.make_descriptor("Core", "DirExists", "Directory Exists", ACEDescriptor.ACEType.CONDITION, "DirAccess.dir_exists_absolute({path})", "", [F.make_param("path", "String", "\"user://data\"", "Path", "Directory path to test.", "file_path")], "Files: Directories", "directory {path} exists")
		.described("True when a folder exists at that path, useful before creating or listing it."))
	descriptors.append(F.make_descriptor("Core", "MakeDir", "Make Directory", ACEDescriptor.ACEType.ACTION, "DirAccess.make_dir_recursive_absolute({path})", "", [F.make_param("path", "String", "\"user://data\"", "Path", "Directory to create (any missing parent directories are created too).", "file_path")], "Files: Directories", "make directory {path}")
		.described("Creates a folder, building any missing parent folders along the way."))
	descriptors.append(F.make_descriptor("Core", "RemoveDir", "Remove Directory", ACEDescriptor.ACEType.ACTION, "DirAccess.remove_absolute({path})", "", [F.make_param("path", "String", "\"user://data\"", "Path", "EMPTY directory to remove (delete its files first).", "file_path")], "Files: Directories", "remove directory {path}")
		.described("Deletes an empty folder (clear out its files first)."))
	descriptors.append(F.make_descriptor("Core", "ListFiles", "List Files", ACEDescriptor.ACEType.EXPRESSION, "DirAccess.get_files_at({path})", "", [F.make_param("path", "String", "\"user://\"", "Path", "Directory whose file names to list (PackedStringArray; [] if missing).", "file_path")], "Files: Directories", "files in {path}")
		.described("Returns the list of file names inside a folder (empty if the folder is missing)."))
	descriptors.append(F.make_descriptor("Core", "ListDirs", "List Subdirectories", ACEDescriptor.ACEType.EXPRESSION, "DirAccess.get_directories_at({path})", "", [F.make_param("path", "String", "\"user://\"", "Path", "Directory whose subdirectory names to list.", "file_path")], "Files: Directories", "subdirectories in {path}")
		.described("Returns the list of subfolder names inside a folder."))

	# ── The three that say the place out loud ─────────────────────────────────────────────────
	#
	# Beside the twelve above rather than inside them: their ace_ids and templates are a
	# compatibility promise, so a sentence that needs a different LINE needs a different word.
	#
	#   the guarded read      a read that says what to use when the file is not there. The second
	#                         parameter IS the fallback - the familiar default argument - and leaving
	#                         it blank emits the plain read, unchanged.
	#   the write that makes  Godot will not create a folder on the way to opening a file, so a path
	#   its folder            with folders in it fails until somebody makes them. The choice is
	#                         stated on the row and the prelude is in the echo.
	#   the folder door       where user:// really is, opened on the player's own machine.
	descriptors.append(F.make_descriptor("Core", "ReadTextFileOr", "Read Text File (or a fallback)", ACEDescriptor.ACEType.EXPRESSION, "FileAccess.get_file_as_string({path}){?fallback} if FileAccess.file_exists({path}) else {fallback}{/fallback}", "", [F.make_param("path", "String", "\"user://save.dat\"", "Path", "File to read in full as a String. Prefer user:// - res:// is read-only once the game is exported.", "file_path"), F.make_param("fallback", "String", "\"\"", "If missing", "What the expression reads as when there is no file at that path. Leave it blank to read the file plainly, exactly as Read Text File does.", "expression")], "Files", "text of file {path}, or {fallback}")
		.described("Reads a whole file as text, using the fallback you name when the file is not there. The guard is written into the line and shown on the row, so nothing happens that the code does not say."))
	descriptors.append(F.make_descriptor("Core", "WriteTextFileInFolder", "Write Text File (in a folder)", ACEDescriptor.ACEType.ACTION, "{?folder=make its folder first}DirAccess.make_dir_recursive_absolute({path}.get_base_dir())\n{/folder}var __file_{uid} = FileAccess.open({path}, FileAccess.WRITE)\nif __file_{uid}:\n\t__file_{uid}.store_string({text})\n\t__file_{uid}.close()", "", [F.make_param("path", "String", "\"user://runs/latest.txt\"", "Path", "File to write, inside one or more folders. OVERWRITES any existing file. Prefer user:// - res:// is read-only once the game is exported.", "file_path"), F.make_param("text", "String", "\"\"", "Text", "Text content to store.", "expression"), F.make_param("folder", "String", "make its folder first", "Folder", "Whether to create the folders in that path before writing. Godot does not make them on the way to opening a file, so a write into a folder that is not there fails.", "", [{"key": "make its folder first", "label": "Make the folder first"}, {"key": "its folder is already there", "label": "The folder is already there"}])], "Files", "write {text} to file {path} - {folder}")
		.described("Saves text to a file inside a folder, optionally creating the folders on the way. The folder line is emitted above the write and shown in the row, never behind your back."))
	descriptors.append(F.make_descriptor("Core", "OpenUserDataFolder", "Open The Player's Data Folder", ACEDescriptor.ACEType.ACTION, "OS.shell_open(ProjectSettings.globalize_path({path}))", "", [F.make_param("path", "String", "\"user://\"", "Path", "Folder to open, inside user://. The path is turned into a real one on the player's machine before it is handed to the desktop.", "file_path")], "Files", "open the player's data folder {path}")
		.described("Opens the player's own data folder in their desktop file browser - the real folder user:// stands for on that machine."))

	return descriptors
