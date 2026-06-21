# EventForge module — File management (read / write / JSON, plus directory + file operations).
#
# Everyday on-disk work — save & load text, serialise to JSON, copy / move / delete files, and manage
# directories — so save systems, config files and level data never force a drop to GDScript. Each
# compiles to the exact native FileAccess / DirAccess call. Reads use the static, null-safe accessors
# (FileAccess.get_file_as_string / DirAccess.get_files_at — they return "" / [] on error rather than
# crashing); writes guard the FileAccess handle so a bad path can't null-deref. Grouped under
# Files / Files: Directories.
#
# Path tip (surfaced in the param hints): write to user:// — res:// is READ-ONLY in an exported game.
@tool
extends RefCounted
class_name EventForgeFileACEs

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	# ── Files — read / write / JSON / copy / move / delete (act on a path string or expression) ──
	descriptors.append(F.make_descriptor("Core", "FileExists", "File Exists", ACEDescriptor.ACEType.CONDITION, "FileAccess.file_exists({path})", "", [F.make_param("path", "String", "\"user://save.dat\"", "Path", "File path to test. Prefer user:// (res:// is read-only when exported).", "expression")], "Files", "file {path} exists"))
	descriptors.append(F.make_descriptor("Core", "ReadTextFile", "Read Text File", ACEDescriptor.ACEType.EXPRESSION, "FileAccess.get_file_as_string({path})", "", [F.make_param("path", "String", "\"user://save.dat\"", "Path", "File to read in full as a String (\"\" if it is missing or unreadable).", "expression")], "Files", "text of file {path}"))
	descriptors.append(F.make_descriptor("Core", "GetFileSize", "File Size (bytes)", ACEDescriptor.ACEType.EXPRESSION, "FileAccess.get_file_as_bytes({path}).size()", "", [F.make_param("path", "String", "\"user://save.dat\"", "Path", "File to measure (0 bytes if missing).", "expression")], "Files", "size of file {path}"))
	descriptors.append(F.make_descriptor("Core", "WriteTextFile", "Write Text File", ACEDescriptor.ACEType.ACTION, "var __file_{uid} = FileAccess.open({path}, FileAccess.WRITE)\nif __file_{uid}:\n\t__file_{uid}.store_string({text})\n\t__file_{uid}.close()", "", [F.make_param("path", "String", "\"user://save.dat\"", "Path", "File to write. OVERWRITES any existing file. Use user:// (res:// is read-only when exported).", "expression"), F.make_param("text", "String", "\"\"", "Text", "Text content to store.", "expression")], "Files", "write {text} to file {path}"))
	descriptors.append(F.make_descriptor("Core", "AppendTextFile", "Append To File", ACEDescriptor.ACEType.ACTION, "var __file_{uid} = FileAccess.open({path}, FileAccess.READ_WRITE)\nif __file_{uid}:\n\t__file_{uid}.seek_end()\n\t__file_{uid}.store_string({text})\n\t__file_{uid}.close()", "", [F.make_param("path", "String", "\"user://log.txt\"", "Path", "Existing file to append to (no-op if it does not exist — Write it first).", "expression"), F.make_param("text", "String", "\"\"", "Text", "Text to append at the end of the file.", "expression")], "Files", "append {text} to file {path}"))
	descriptors.append(F.make_descriptor("Core", "DeleteFile", "Delete File", ACEDescriptor.ACEType.ACTION, "DirAccess.remove_absolute({path})", "", [F.make_param("path", "String", "\"user://save.dat\"", "Path", "File (or empty directory) to delete.", "expression")], "Files", "delete file {path}"))
	descriptors.append(F.make_descriptor("Core", "CopyFile", "Copy File", ACEDescriptor.ACEType.ACTION, "DirAccess.copy_absolute({from}, {to})", "", [F.make_param("from", "String", "\"user://save.dat\"", "From", "Source file path.", "expression"), F.make_param("to", "String", "\"user://backup.dat\"", "To", "Destination file path.", "expression")], "Files", "copy {from} to {to}"))
	descriptors.append(F.make_descriptor("Core", "MoveFile", "Move / Rename File", ACEDescriptor.ACEType.ACTION, "DirAccess.rename_absolute({from}, {to})", "", [F.make_param("from", "String", "\"user://old.dat\"", "From", "Current file (or directory) path.", "expression"), F.make_param("to", "String", "\"user://new.dat\"", "To", "New path / name.", "expression")], "Files", "move {from} to {to}"))

	# ── Files: Directories — make / remove / test / list directories ──
	descriptors.append(F.make_descriptor("Core", "DirExists", "Directory Exists", ACEDescriptor.ACEType.CONDITION, "DirAccess.dir_exists_absolute({path})", "", [F.make_param("path", "String", "\"user://data\"", "Path", "Directory path to test.", "expression")], "Files: Directories", "directory {path} exists"))
	descriptors.append(F.make_descriptor("Core", "MakeDir", "Make Directory", ACEDescriptor.ACEType.ACTION, "DirAccess.make_dir_recursive_absolute({path})", "", [F.make_param("path", "String", "\"user://data\"", "Path", "Directory to create (any missing parent directories are created too).", "expression")], "Files: Directories", "make directory {path}"))
	descriptors.append(F.make_descriptor("Core", "RemoveDir", "Remove Directory", ACEDescriptor.ACEType.ACTION, "DirAccess.remove_absolute({path})", "", [F.make_param("path", "String", "\"user://data\"", "Path", "EMPTY directory to remove (delete its files first).", "expression")], "Files: Directories", "remove directory {path}"))
	descriptors.append(F.make_descriptor("Core", "ListFiles", "List Files", ACEDescriptor.ACEType.EXPRESSION, "DirAccess.get_files_at({path})", "", [F.make_param("path", "String", "\"user://\"", "Path", "Directory whose file names to list (PackedStringArray; [] if missing).", "expression")], "Files: Directories", "files in {path}"))
	descriptors.append(F.make_descriptor("Core", "ListDirs", "List Subdirectories", ACEDescriptor.ACEType.EXPRESSION, "DirAccess.get_directories_at({path})", "", [F.make_param("path", "String", "\"user://\"", "Path", "Directory whose subdirectory names to list.", "expression")], "Files: Directories", "subdirectories in {path}"))

	return descriptors
