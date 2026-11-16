# Godot EventSheets - The collapsible block reads as a Section everywhere, and no door names a menu
# or a tab that is gone.
#
# The block was renamed Section (Group under the Familiar words), the sheet other sheets include was
# renamed Shared sheet, the Settings menu was retired (its Words page is under Tools now) and the
# Debugger's Profile tab was removed. A label or sentence that still says the old word points a reader
# at nothing.
@tool
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")
const P := "section_words_everywhere_test"
## Strings a reader sees that must no longer be written as literals.
const STALE: Array[String] = [
	"Settings ▸ Words",
	"translate(\"Edit Group…\")",
	"translate(\"Group Color…\")",
	"translate(\"Ungroup - Keep The Rows\")",
	"Select an include to preview",
	"Pick an include to see what it brings",
	"Group the selection (or add an empty group)",
	"busiest rows of its Profile tab",
]


static func run() -> bool:
	var found: Array[String] = []
	for path: String in _files("res://addons/", ".gd"):
		var source: String = FileAccess.get_file_as_string(path)
		for stale: String in STALE:
			if source.contains(stale):
				found.append("%s: %s" % [path.get_file(), stale])
	for path: String in _files("res://addons/eventsheet/help/", ".md"):
		if FileAccess.get_file_as_string(path).contains("Settings ▸ Words"):
			found.append("%s: Settings ▸ Words" % path.get_file())
	found.sort()
	var ok: bool = SUPPORT.check(P, "no label or sentence names the old words or a door that is gone", found, [])
	# The Familiar preset keeps its own words: the block reads as a Group there.
	ok = SUPPORT.check(P, "the Familiar words still call the block a Group", EventSheetWords.familiar_default("section_block"), "Group") and ok
	return ok


static func _files(dir_path: String, extension: String) -> Array[String]:
	var out: Array[String] = []
	for file_name: String in DirAccess.get_files_at(dir_path):
		if file_name.ends_with(extension):
			out.append(dir_path.path_join(file_name))
	for sub: String in DirAccess.get_directories_at(dir_path):
		out.append_array(_files(dir_path.path_join(sub), extension))
	return out
