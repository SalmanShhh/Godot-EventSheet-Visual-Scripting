# Godot EventSheets - a Manual module page wears the icon of its section.
#
# The sidebar gave every module page the one generic Object mark, so forty-eight pages read as the same
# thing. A page is written for a reader's question and its modules are files, so its section is found from
# a module's name where that names a section, and from a short override list where it does not. What this
# pins: every module page answers with an icon, the answer is a drawn file or an editor class the picker
# knows, and the pages that share nothing do not all share one mark.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const NAME: String = "manual_module_icons_test"


static func run() -> bool:
	var ok: bool = true
	var seen: Dictionary = {}
	var pages: PackedStringArray = EventSheetDocLibrary.ids_in_set(EventSheetDocLibrary.MODULES_DIR)
	ok = SUPPORT.check(NAME, "the Manual has module pages", pages.size() > 40, true) and ok
	for id: String in pages:
		if id.get_file() == "README":
			continue
		var named: String = EventSheetDocBrowser.module_section_icon_name(id)
		ok = SUPPORT.check(NAME, "%s wears a section's icon" % id.get_file(), named.is_empty(), false) and ok
		if named.begins_with("res://"):
			ok = SUPPORT.check(NAME, "the icon of %s is a file that is there" % id.get_file(), FileAccess.file_exists(named), true) and ok
		seen[named] = true
	ok = SUPPORT.check(NAME, "the pages do not all wear one mark", seen.size() > 15, true) and ok
	ok = SUPPORT.check(NAME, "a page that is no module page has no section icon", EventSheetDocBrowser.module_section_icon_name("Addons/Health"), "") and ok
	return ok
