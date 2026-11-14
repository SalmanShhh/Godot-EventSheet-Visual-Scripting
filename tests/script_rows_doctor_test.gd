@tool
class_name ScriptRowsDoctorTest
extends RefCounted

# Godot EventSheets - the Doctor's Script Rows section names the lines of a user's script that read as
# nothing, and leaves the plugin's own files and scripts that never opted in alone.

const SUPPORT := preload("res://tests/support.gd")
const SECTION := preload("res://addons/eventforge/script_rows_doctor.gd")


static func run() -> bool:
	var source: String = "extends Node\n\n## @ace_nmae(\"Hurt\")\nfunc hurt() -> void:\n\tpass\n"
	var found: Array[Dictionary] = SECTION.report("res://game/hero.gd", source)
	var first: Dictionary = found[0] if not found.is_empty() else {}
	var ok: bool = SUPPORT.pins("script_rows_doctor_test", [
		["one finding for the one typo", found.size(), 1],
		["it is a warning filed under the section's check", "%s/%s" % [first.get("severity", ""), first.get("check", "")], "warning/script-rows"],
		["it opens the script it is about", first.get("path", ""), "res://game/hero.gd"],
		["it names the file and the line", str(first.get("message", "")).begins_with("hero.gd: Line 3"), true],
		["the subject is the line's own word", first.get("subject", ""), "@ace_nmae"],
		["a script with no words of its own is not read", SECTION.reads_words("extends Node\nfunc a():\n\tpass\n"), false],
		["a script with a word is", SECTION.reads_words("## @ace_name(\"x\")\nfunc a():\n\tpass\n"), true],
		["a misspelt word still makes the file worth reading", SECTION.reads_words("## @acr_name(\"x\")\nfunc a():\n\tpass\n"), true],
		["a plugin file is shipped", SECTION._is_shipped("res://addons/eventsheet/ace/ace_generator.gd"), true],
		["a pack the plugin ships is shipped", SECTION._is_shipped("res://eventsheet_addons/flash/flash_behavior.gd"), true],
		["the reader's own script is not", SECTION._is_shipped("res://game/hero.gd"), false],
		["the finding carries the line its chip jumps to", first.get("line", 0), 3],
		["the one chip is Go to the line", EventSheetQuickFixes.fixes_for(first).map(func(offer: Dictionary) -> String: return str(offer["id"])), ["go_to_the_line"]],
	])
	return ok
