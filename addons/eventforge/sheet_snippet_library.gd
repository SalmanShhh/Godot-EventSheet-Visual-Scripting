# Godot EventSheets - project-local row snippets
#
# The shareable text-snippet format (EventSheetSnippet - what Copy already puts on
# the system clipboard) IS the file format: one serializer, no new dialect. Drop the
# files in res://eventsheet_snippets/ (override: eventsheets/project/snippets_dir),
# commit them, and the team shares every-X-seconds-spawn / fade-and-free / knockback
# patterns the same way templates and packs are shared. Insert goes through the
# normal paste path, so fresh event uids re-bake exactly like a paste.
@tool
class_name EventSheetSnippetLibrary
extends RefCounted

const DEFAULT_DIR := "res://eventsheet_snippets"


static func snippets_dir() -> String:
	return str(ProjectSettings.get_setting("eventsheets/project/snippets_dir", DEFAULT_DIR)).trim_suffix("/")


## Every .txt under the snippets dir (recursive), sorted for stable menus.
static func list_snippets() -> PackedStringArray:
	var snippets: PackedStringArray = PackedStringArray()
	var pending: PackedStringArray = PackedStringArray([snippets_dir()])
	while not pending.is_empty():
		var directory_path: String = pending[pending.size() - 1]
		pending.remove_at(pending.size() - 1)
		var dir: DirAccess = DirAccess.open(directory_path)
		if dir == null:
			continue
		dir.list_dir_begin()
		var entry: String = dir.get_next()
		while not entry.is_empty():
			var full_path: String = directory_path.path_join(entry)
			if dir.current_is_dir():
				if not entry.begins_with("."):
					pending.append(full_path)
			elif entry.ends_with(".txt"):
				snippets.append(full_path)
			entry = dir.get_next()
		dir.list_dir_end()
	snippets.sort()
	return snippets


## Writes serialized snippet text under the given name; an existing name gets a
## -2/-3 suffix (templates rule: never overwrite silently). Returns the path, or "".
static func save_snippet(snippet_name: String, snippet_text: String) -> String:
	var base_name: String = snippet_name.to_snake_case()
	if base_name.is_empty():
		base_name = "snippet"
	DirAccess.make_dir_recursive_absolute(snippets_dir())
	var target: String = snippets_dir().path_join(base_name + ".txt")
	var suffix: int = 2
	while FileAccess.file_exists(target):
		target = snippets_dir().path_join("%s-%d.txt" % [base_name, suffix])
		suffix += 1
	var file: FileAccess = FileAccess.open(target, FileAccess.WRITE)
	if file == null:
		return ""
	file.store_string(snippet_text)
	file.close()
	return target


static func read_snippet(snippet_path: String) -> String:
	return FileAccess.get_file_as_string(snippet_path)
