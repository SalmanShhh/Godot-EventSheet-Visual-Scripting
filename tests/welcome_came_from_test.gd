@tool
class_name WelcomeCameFromTest
extends RefCounted

# EventForge - the Welcome window's one question: how do you usually make games?
#
# Each answer sets settings the editor already owns - the words preset, the sheet theme, the
# Project bar, the GDScript panel - and says so in one line. These pins hold the table and the line
# to each other, by value, so the card can never promise one thing and set another:
#   1. what each answer sets;
#   2. the sentence under the answers, word for word;
#   3. the theme an answer names is a file that ships, and the guide it opens is a page that ships.

const SUPPORT := preload("res://tests/support.gd")


static func run() -> bool:
	var sheets: Dictionary = EventSheetWelcomeWindow.choice_settings(EventSheetWelcomeWindow.CAME_FROM_SHEETS)
	var godot: Dictionary = EventSheetWelcomeWindow.choice_settings(EventSheetWelcomeWindow.CAME_FROM_GDSCRIPT)
	var fresh: Dictionary = EventSheetWelcomeWindow.choice_settings(EventSheetWelcomeWindow.CAME_FROM_NEW)
	return SUPPORT.pins("welcome_came_from_test", [
		["from another event-sheet editor: its words", sheets["words"], EventSheetWords.PRESET_SHEET],
		["and the Classic sheet look", sheets["theme"], "res://addons/eventsheet/themes/classic_sheet_theme.tres"],
		["and the Project bar", sheets["project_bar"], true],
		["and the migration guide", sheets["guide"], "GUIDE-MOVING-FROM-ANOTHER-EVENT-SHEET-EDITOR"],
		["from GDScript: Godot's words and the code beside the sheet", [godot["words"], godot["code_panel"]],
			[EventSheetWords.PRESET_GODOT, true]],
		["new: familiar words and the tour", [fresh["words"], fresh["tour"]],
			[EventSheetWords.PRESET_FAMILIAR, true]],
		["the sentence for another event-sheet editor",
			EventSheetWelcomeWindow.choice_summary(EventSheetWelcomeWindow.CAME_FROM_SHEETS),
			"Sets: Event-sheet-editor words, Classic sheet theme, Project bar on, the migration guide open in the Manual. Change any of it later in Settings ▸ Words and the View menu."],
		["the sentence for GDScript",
			EventSheetWelcomeWindow.choice_summary(EventSheetWelcomeWindow.CAME_FROM_GDSCRIPT),
			"Sets: Godot words, the editor-matching theme, the GDScript panel beside every sheet. Change any of it later in Settings ▸ Words and the View menu."],
		["the sentence for someone new",
			EventSheetWelcomeWindow.choice_summary(EventSheetWelcomeWindow.CAME_FROM_NEW),
			"Sets: Familiar words, the editor-matching theme, the tour. Change any of it later in Settings ▸ Words and the View menu."],
		["the theme it names ships", ResourceLoader.exists(str(sheets["theme"])), true],
		["the guide it opens ships in the Manual", EventSheetDocLibrary.has_page(str(sheets["guide"])), true],
	])
