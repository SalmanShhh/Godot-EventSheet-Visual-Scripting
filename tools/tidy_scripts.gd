# Godot EventSheets - Tidy this script, run over files from the command line.
#
# The same engine as Sheet > Tidy This Script, for scripts nobody has open: a hand-written file that no pack
# builder generates, a folder of a team's own scripts. Each file is opened as a sheet, planned on a copy,
# and only the lines the engine can read back are changed. Without --write nothing is written and each
# file's lines are listed; with it the tidied text replaces the file, and the file is read again and must
# open and save back to the same bytes.
#
# A file whose verbs would stop opening as function rows after the move is left exactly as it is and named.
#
#   godot --headless --path . --script tools/tidy_scripts.gd -- <file or folder> [more...] [--write]
#
# Prints one line per file and a last line `tidy: files=N changed=N lines=N left=N held=N`.
extends SceneTree

const TIDY := preload("res://addons/eventsheet/editor/dock/tidy_script.gd")


func _init() -> void:
	var write: bool = false
	var paths: PackedStringArray = PackedStringArray()
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--write":
			write = true
		else:
			paths.append(argument)
	var files: PackedStringArray = PackedStringArray()
	for path: String in paths:
		_collect(path, files)
	files.sort()
	var changed: int = 0
	var lines: int = 0
	var left: int = 0
	var held: int = 0
	for file: String in files:
		var outcome: Dictionary = _tidy_file(file, write)
		if bool(outcome.get("held", false)):
			held += 1
		if int(outcome.get("lines", 0)) > 0 and not bool(outcome.get("held", false)):
			changed += 1
			lines += int(outcome["lines"])
		left += int(outcome.get("left", 0))
	print("tidy: files=%d changed=%d lines=%d left=%d held=%d%s" % [files.size(), changed, lines, left, held, "" if write else " (nothing written)"])
	quit(1 if held > 0 and write else 0)


func _collect(path: String, files: PackedStringArray) -> void:
	if DirAccess.dir_exists_absolute(path):
		for entry: String in DirAccess.get_files_at(path):
			if entry.ends_with(".gd"):
				files.append(path.path_join(entry))
		for folder: String in DirAccess.get_directories_at(path):
			_collect(path.path_join(folder), files)
	elif path.ends_with(".gd"):
		files.append(path)


## Tidies one file. Returns {lines, left, held}.
func _tidy_file(path: String, write: bool) -> Dictionary:
	var source: String = FileAccess.get_file_as_string(path)
	var sheet: EventSheetResource = EventSheetGDScriptImporter.new().import_external_source(source, true, path)
	if sheet == null:
		return {}
	sheet.external_source_path = path
	var made: Dictionary = TIDY.plan(sheet)
	var count: int = (made["changes"] as Array).size()
	if count == 0:
		return {"left": int(made["left"])}
	var after: String = str(made["after"])
	var reopened: EventSheetResource = EventSheetGDScriptImporter.new().import_external_source(after, true, path)
	if reopened == null or reopened.functions.size() < sheet.functions.size() or reopened.events.size() < sheet.events.size():
		print("%s: HELD - its verbs would stop opening as function rows (%d lines left as they are)" % [path, count])
		return {"held": true, "lines": count}
	print("%s: %d line(s)%s" % [path, count, "" if int(made["left"]) == 0 else ", %d left as they are" % int(made["left"])])
	if write:
		var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		file.store_string(after)
		file.close()
		if FileAccess.get_file_as_string(path) != after:
			print("%s: WRITE CHECK FAILED" % path)
			return {"held": true, "lines": count}
	else:
		for line: String in TIDY.preview_lines(made):
			print("    ", line)
	return {"lines": count, "left": int(made["left"])}
