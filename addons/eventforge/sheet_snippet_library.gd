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
	return EventSheetTemplates.files_under(snippets_dir(), ".txt")


## Writes serialized snippet text under the given name; an existing name gets a
## -2/-3 suffix (templates rule: never overwrite silently). Returns the path, or "".
## The name becomes a FILENAME inside the snippets dir only: to_snake_case leaves "/",
## "\" and "." alone, so a name like "enemies/spawn" or "../notes" quietly wrote the
## file outside the folder (then never showed in the list). Path-ish characters
## collapse to underscores instead.
static func save_snippet(snippet_name: String, snippet_text: String) -> String:
	var target: String = free_path_for(snippet_name)
	DirAccess.make_dir_recursive_absolute(snippets_dir())
	var file: FileAccess = FileAccess.open(target, FileAccess.WRITE)
	if file == null:
		return ""
	file.store_string(snippet_text)
	file.close()
	return target


## The file save_snippet would write for this name: its own file, or name-2 / name-3 … when that one
## is taken - so a window can say which before anything is written.
static func free_path_for(snippet_name: String) -> String:
	var target: String = snippet_path_for(snippet_name)
	var base_name: String = target.get_file().get_basename()
	var suffix: int = 2
	while FileAccess.file_exists(target):
		target = snippets_dir().path_join("%s-%d.txt" % [base_name, suffix])
		suffix += 1
	return target


## The file a snippet of this name is written to, before any clash suffix - so a caller can ask
## whether the name is already taken before it saves.
static func snippet_path_for(snippet_name: String) -> String:
	var base_name: String = snippet_name.to_snake_case()
	var sanitizer: RegEx = RegEx.new()
	sanitizer.compile("[\\\\/:*?\"<>|.]+")
	base_name = sanitizer.sub(base_name, "_", true)
	while base_name.begins_with("_"):
		base_name = base_name.substr(1)
	while base_name.ends_with("_"):
		base_name = base_name.substr(0, base_name.length() - 1)
	if base_name.is_empty():
		base_name = "snippet"
	return snippets_dir().path_join(base_name + ".txt")


static func read_snippet(snippet_path: String) -> String:
	return FileAccess.get_file_as_string(snippet_path)
