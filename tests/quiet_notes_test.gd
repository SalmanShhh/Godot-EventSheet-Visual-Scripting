# Godot EventSheets - the actions Ctrl+Z cannot take back say so before they run.
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const TEST_NAME := "quiet_notes_test"


static func run() -> bool:
	var notes: Dictionary = {}
	for entry: Dictionary in EventSheetDocChores.chores():
		notes[str(entry["id"])] = str(entry["note"])
	return SUPPORT.pins(TEST_NAME, [
		["the manual chore says Ctrl+Z does not take it back",
			str(notes[EventSheetDocChores.CHORE_MANUAL]).contains("Ctrl+Z does not take that back"), true],
		["the drafts chore says so", str(notes[EventSheetDocChores.CHORE_DRAFTS]).contains("Ctrl+Z does not take that back"), true],
		["the missing keys chore says so", str(notes[EventSheetDocChores.CHORE_KEYS]).contains("Ctrl+Z does not take that back"), true],
		["the site chore says it leaves the reader's own files", str(notes[EventSheetDocChores.CHORE_SITE]).contains("leaves your own"), true],
	])
