# Godot EventSheets - a showcase says what it is in its class description.
#
# The showcases used to close on a bold-titled `#` paragraph, a comment row at the bottom of the file that
# only the sheet could read. Godot reads a `##` description right under `extends` as the class's own
# documentation (the Create Node tooltip and the script's Help page), so the showcases now say it there. The
# start page reads either spelling, a file written the old way still opens and saves back byte for byte,
# and a script that already had a short description keeps it as the first paragraph.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "showcase_class_description_test"
const OLD_SPELLING: String = "extends Node2D\n\nfunc _ready() -> void:\n\tprint(\"hi\")\n\n# [b]Old Showcase[/b] - what it does, written as a closing note at the bottom of the file.\n"
const NEW_SPELLING: String = "extends Node2D\n## [b]New Showcase[/b] - what it does, written as the class description.\n\nfunc _ready() -> void:\n\tprint(\"hi\")\n"
const TWO_PARAGRAPHS: String = "extends Node2D\n## A short line the script always had.\n##\n## [b]Both[/b] - the showcase's own words.\n\nfunc _ready() -> void:\n\tprint(\"hi\")\n"


static func run() -> bool:
	var ok: bool = true
	for pair: Array in [["a file that closes on a note", OLD_SPELLING], ["a file with a class description", NEW_SPELLING], ["a file with two paragraphs", TWO_PARAGRAPHS]]:
		ok = SUPPORT.check(P, "%s opens and saves back byte for byte" % pair[0], EventSheets.round_trips(str(pair[1])), true) and ok
	ok = SUPPORT.check(P, "the new spelling is read as the class description", SUPPORT.reopen(NEW_SPELLING).class_description, "[b]New Showcase[/b] - what it does, written as the class description.") and ok
	ok = SUPPORT.check(P, "the start page reads the class description", EventSheetStartPage.pitch_from_about(EventSheetStartPage._class_doc_about(NEW_SPELLING)), "What it does, written as the class description.") and ok
	ok = SUPPORT.check(P, "with two paragraphs it reads the showcase's own", EventSheetStartPage._class_doc_about(TWO_PARAGRAPHS), "[b]Both[/b] - the showcase's own words.") and ok
	ok = SUPPORT.check(P, "a description with no bold title is not the page's line", EventSheetStartPage._class_doc_about("extends Node\n## A script's own words.\n"), "") and ok
	ok = SUPPORT.check(P, "no description reads as nothing", EventSheetStartPage._class_doc_about("extends Node\n\nvar x: int = 0\n"), "") and ok
	# The showcases themselves: each folder's own script says what it is, once, as its class description.
	var missing: PackedStringArray = PackedStringArray()
	var closing_notes: PackedStringArray = PackedStringArray()
	for folder: String in EventSheetStartPage.showcase_folders():
		if EventSheetStartPage.showcase_about(folder).is_empty():
			missing.append(folder)
		var main_script: String = FileAccess.get_file_as_string("res://demo/showcase/%s/%s.gd" % [folder, folder])
		if main_script.contains("\n# [b]"):
			closing_notes.append(folder)
	ok = SUPPORT.check(P, "every showcase folder has a description for the start page, except the two whose descriptions never opened with a bold title", missing, PackedStringArray(["boomer_level", "fps_arena"])) and ok
	ok = SUPPORT.check(P, "no showcase closes on a note any more", closing_notes, PackedStringArray()) and ok
	return ok
