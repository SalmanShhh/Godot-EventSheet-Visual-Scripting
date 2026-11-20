# Godot EventSheets - a tutorial's step texts, hint lines and fixed lines read in the reader's language.
#
# A step's English sentence is the key of a row in every translation file, so a step edited by one character
# loses its eight translations and falls back to English. This test is what notices: it names every step that
# lacks a filled row. It also holds each translation to the English one - the same placeholders, the same
# bracket markup, the same arrows, and every identifier, file name and key name carried over untouched - and
# it checks that every menu or button name a step shows is the very word the editor shows in that language
# (taken from the name's own row, or left in English when the editor itself shows it in English).
@tool
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")
const P := "tutorial_steps_translated_test"
const FOLDER := "res://addons/eventsheet/translations"
const LOCALES: Array[String] = ["de", "es", "fr", "it", "ja", "ko", "ru", "zh_CN"]
## The fixed lines a tutorial page and the list page print besides the step.
const FIXED_LINES: Array[String] = [
	"These are done, not read. Each step names a control this editor really has, highlights it until you use it, and completes when the sheet contains what the step asked for. They run in the sheet you have open, and every step is one ordinary undo.",
	"%s stays highlighted in the toolbar until you use it.",
	"This step completes on its own the moment the sheet contains it.",
	"Walks this tutorial step by step, in the sheet you have open.",
	"The step before this one.",
	"Leaves the tutorial and goes back to the list.",
	"The next step. Never waits for the check - a step you have already done your own way is a step you can walk past.",
	"Start", "Carry on", "Skip", "Finish", "◀ Back", "Next ▶",
]
## The names a step shows on screen, by the first words of the step: each is looked up in the language's own
## table and must appear in the translated step as that table spells it (or as English when it has no row).
const NAMES: Array[Array] = [
	["Start with the tour", ["Tools", "Start the Tour…", "Next"]],
	["Add an event", ["Add Event", "On ready"]],
	["Now add an action", ["Add Action", "Move"]],
	["Give the event a condition", ["Add Condition"]],
	["Give the sheet some memory", ["Add", "Global Variable…"]],
	["Open a script of your own", ["Sheet", "Open…", "Script block"]],
	["Open Sheet ▸ Manage Includes", ["Sheet", "Manage Includes…"]],
	["Two habits worth having", ["Tools", "Project Doctor"]],
	["Attach it for real", ["Tools", "Attach to Selected Node"]],
	["Add ▸ Function…, name", ["Add", "Function…"]],
	["Call it from an event", ["Functions", "Call"]],
	["Read the word list first", ["Coming from another event-sheet editor"]],
	["A scene is what other", ["System", "On ready"]],
	["A sheet variable belongs", ["Add", "Variable…", "Global Variable…", "Local Variable…"]],
	["A family is a group", ["Sheet", "Sheet Type…", "Family"]],
	["Choose the shape first", ["Sheet", "Sheet Type…", "Editor Tool", "Editor Plugin", "Import Tool", "Export Hook"]],
	["Now give it something to do", ["Editor Tools"]],
	["Run it without leaving", ["Run now", "Output"]],
	["To make it a plugin instead", ["Sheet Type…", "Editor Plugin", "Enable plugin"]],
	["Every networked game starts", ["On ready"]],
	["Ask which copy this is", ["Multiplayer", "Started As"]],
	["Open the game: press A", ["Multiplayer", "Host A Game"]],
	["Now the copy that knocks", ["Add", "Add 'Else'", "Multiplayer", "Join A Game"]],
	["Hear the other player", ["Multiplayer", "Players", "On Player Joined"]],
	["Give the game something to say", ["Add", "Function…", "Make It A Message…"]],
	["Send it: press A", ["Multiplayer", "Send Message To Everyone", "To"]],
	["Say who runs what", ["Put Selection into New Section", "Runs On", "The host"]],
	["Give the players a value", ["Add", "Variable…", "Keep in Step", "Always"]],
	["Now play it as two players", ["Play as host + client"]],
	["Open the Start page", ["Start page", "This editor"]],
	["Start with Plugin", ["Plugin", "Enabled", "Reload", "Output"]],
	["Now open Workspace", ["Workspace"]],
	["Open a file under Tests", ["Tests"]],
	["Open a file under Pack recipes", ["Pack recipes"]],
	["If you want to change something", ["Edit anyway"]],
	["Open core_aces.gd", ["Define"]],
	["Press Edit anyway", ["Edit anyway", "Define"]],
]


static func run() -> bool:
	var rows: Array = []
	var steps: Array[String] = _all_steps()
	rows.append(["the tutorials hold fifty steps", steps.size(), 50])
	var keys: Array[String] = steps.duplicate()
	keys.append_array(FIXED_LINES)
	var template: Dictionary = _read("TEMPLATE")
	var tables: Dictionary = {}
	for locale: String in LOCALES:
		tables[locale] = _read(locale)
	var missing_template: PackedStringArray = PackedStringArray()
	for key: String in keys:
		if not template.has(key):
			missing_template.append(key.left(40))
	rows.append(["the template has a row for every step and line (missing: %s)" % ", ".join(missing_template), missing_template.size(), 0])
	for locale: String in LOCALES:
		var table: Dictionary = tables[locale]
		var missing: PackedStringArray = PackedStringArray()
		var damaged: PackedStringArray = PackedStringArray()
		for key: String in keys:
			var cell: String = str(table.get(key, ""))
			if cell.strip_edges().is_empty():
				missing.append(key.left(40))
				continue
			var problem: String = _mismatch(key, cell)
			if not problem.is_empty():
				damaged.append("%s (%s)" % [key.left(30), problem])
		rows.append(["%s has a filled row for every step and line (missing: %s)" % [locale, ", ".join(missing)], missing.size(), 0])
		rows.append(["%s keeps placeholders, markup, arrows and identifiers (damaged: %s)" % [locale, "; ".join(damaged)], damaged.size(), 0])
		rows.append(["%s: every step is not its English self" % locale, _untranslated(steps, table), 0])
		var unnamed: PackedStringArray = PackedStringArray()
		for entry: Array in NAMES:
			var step: String = _step_starting(steps, str(entry[0]))
			if step.is_empty():
				unnamed.append("no step starts " + str(entry[0]))
				continue
			var shown: String = str(table.get(step, ""))
			for name: String in (entry[1] as Array):
				var on_screen: String = str(table.get(name, "")).strip_edges()
				if on_screen.is_empty():
					on_screen = name
				if not shown.contains(on_screen):
					unnamed.append("%s: %s" % [str(entry[0]).left(24), name])
		rows.append(["%s: every menu and button name in a step is the word the editor shows (off: %s)" % [locale, "; ".join(unnamed)], unnamed.size(), 0])
	# Every step that names a menu path is covered by the NAMES table, so a step added later is noticed.
	var uncovered: PackedStringArray = PackedStringArray()
	for step: String in steps:
		if step.contains(" ▸ ") and not _covered(step):
			uncovered.append(step.left(40))
	rows.append(["every step that names a menu path is in the names table (not: %s)" % ", ".join(uncovered), uncovered.size(), 0])
	# The page itself reads the rows: a translated editor shows the Spanish sentence, English stays untouched.
	EventSheetL10n.rescan()
	var first: String = str(EventSheetDocTutorials.tutorials()[0].get("id", ""))
	EventSheetL10n.set_locale("en")
	rows.append(["English: the first step reads as written", _quote_text(first, 0), steps[0]])
	for locale: String in LOCALES:
		EventSheetL10n.set_locale(locale)
		rows.append(["%s: the first step's card shows the translated sentence" % locale, _quote_text(first, 0), str(tables[locale].get(steps[0], ""))])
		var last_index: int = EventSheetDocTutorials.step_count(first) - 1
		rows.append(["%s: the last step's card shows the translated sentence" % locale, _quote_text(first, last_index) != EventSheetDocTutorials.step(first, last_index).get("text", ""), true])
		var list_text: String = str(EventSheetDocTutorials.list_blocks()[1].get("bbcode", ""))
		rows.append(["%s: the list page's intro is translated" % locale, list_text != FIXED_LINES[0], true])
	EventSheetL10n.set_locale("en")
	rows.append(["a step with no row reads in English, never as a key", EventSheetDocTutorials.step_text_of({"text": "A step added later"}), "A step added later"])
	return SUPPORT.pins(P, rows)


static func _all_steps() -> Array[String]:
	var steps: Array[String] = []
	for entry: Dictionary in EventSheetDocTutorials.tutorials():
		var id: String = str(entry.get("id", ""))
		for index: int in EventSheetDocTutorials.step_count(id):
			steps.append(str(EventSheetDocTutorials.step(id, index).get("text", "")))
	return steps


static func _quote_text(tutorial_id: String, index: int) -> String:
	for block: Dictionary in EventSheetDocTutorials.step_blocks(tutorial_id, index):
		if str(block.get("kind", "")) == "quote":
			return str(block.get("bbcode", "")).replace("[lb]", "[")
	return ""


static func _step_starting(steps: Array[String], start: String) -> String:
	for step: String in steps:
		if step.begins_with(start):
			return step
	return ""


static func _covered(step: String) -> bool:
	for entry: Array in NAMES:
		if step.begins_with(str(entry[0])):
			return true
	return false


static func _untranslated(steps: Array[String], table: Dictionary) -> int:
	var same: int = 0
	for step: String in steps:
		if str(table.get(step, "")) == step:
			same += 1
	return same


## What differs between an English line and its translation that must not: placeholders, bracket tags, arrows,
## backticks and every identifier, file name or key name. An empty string is a match.
static func _mismatch(english: String, translated: String) -> String:
	for pattern: String in ["%[sd]", "\\[/?[a-z]+\\]", "▸", "`"]:
		var regex: RegEx = RegEx.create_from_string(pattern)
		if regex.search_all(english).size() != regex.search_all(translated).size():
			return "count of " + pattern
	var code: RegEx = RegEx.create_from_string("[A-Za-z_][A-Za-z0-9_]*(?:[._/][A-Za-z0-9_]+)+|Ctrl\\+[A-Za-z+]+|F1")
	for hit: RegExMatch in code.search_all(english):
		if not translated.contains(hit.get_string()):
			return "lost " + hit.get_string()
	return ""


static func _read(file_name: String) -> Dictionary:
	var table: Dictionary = {}
	var file: FileAccess = FileAccess.open("%s/%s.csv" % [FOLDER, file_name], FileAccess.READ)
	if file == null:
		return table
	while not file.eof_reached():
		var line: PackedStringArray = file.get_csv_line()
		if line.size() >= 1 and not line[0].is_empty():
			table[line[0]] = line[1] if line.size() > 1 else ""
	return table
