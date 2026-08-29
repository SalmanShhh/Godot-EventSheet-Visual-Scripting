# Godot EventSheets - the documentation chores from a terminal.
#
# Same chores as the Housekeeping dialog, same code, same report; this file is a door and nothing
# else. What it adds is an EXIT CODE, which is the only thing a commit hook, a Makefile or a CI job
# can read:
#
#   godot --headless --script addons/eventsheet/cli.gd -- docs-check     0 clean, 1 something to fix
#   godot --headless --script addons/eventsheet/cli.gd -- docs-export    writes the site
#   godot --headless --script addons/eventsheet/cli.gd -- docs-harvest   writes the engine reference
#
# Options, all optional: --out=<folder> for the export, --locale=<code> for a translated site,
# --limit=<n> to read only the first n guides (a faster local hook; CI should read them all).
#
# THE COST OF READING A PACK GUIDE OUTSIDE THE EDITOR, because it decides how you should use this:
# a pack's verbs come from the live vocabulary when a dock is open, and are REFLECTED off the pack's
# scripts when one is not. Reflection is seconds per guide, so a full docs-check over a large corpus
# is a CI-sized job rather than a keystroke-sized one. --limit exists for the hook; the workflow the
# editor writes for you uses the full read.
#
# It never edits a guide, a sheet or a commit, and it never publishes anything: a chore that would
# write prose writes it to a drafts file and says so.
@tool
extends SceneTree

## What the shell gets back. Frozen, because a hook is written against these:
##   0  the chore ran and found nothing to fix
##   1  the chore ran and found something (or could not finish)
##   2  the command line itself was wrong
const EXIT_OK: int = 0
const EXIT_FINDINGS: int = 1
const EXIT_USAGE: int = 2

## command -> the chores it runs, in the chores module's own order.
const COMMANDS := {
	"docs-check": [EventSheetDocChores.CHORE_CHECK],
	"docs-export": [EventSheetDocChores.CHORE_MANUAL, EventSheetDocChores.CHORE_SITE],
	"docs-harvest": [EventSheetDocChores.CHORE_HARVEST],
	# THE ONE COMMAND THAT USES A NETWORK, and it is its own command for that reason: nothing a
	# reader runs for another purpose can pull a download in behind it.
	"docs-engine-text": [EventSheetDocChores.CHORE_ENGINE_TEXT],
}


func _init() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	var command: String = ""
	var options: Dictionary = {}
	for argument: String in arguments:
		if argument.begins_with("--"):
			var body: String = argument.substr(2)
			var separator: int = body.find("=")
			var key: String = body if separator < 0 else body.substr(0, separator)
			var value: String = "" if separator < 0 else body.substr(separator + 1)
			match key:
				"out":
					options["site_dir"] = value
				"locale":
					options["locale"] = value
				"limit":
					options["coverage_limit"] = value.to_int()
			continue
		if command.is_empty():
			command = argument
	if command.is_empty() or not COMMANDS.has(command):
		print(_usage())
		quit(EXIT_USAGE)
		return
	var ids: PackedStringArray = PackedStringArray()
	for id: Variant in (COMMANDS[command] as Array):
		ids.append(str(id))
	var report: Dictionary = EventSheetDocChores.run(ids, options)
	print(EventSheetDocChores.report_text(report))
	quit(EXIT_OK if bool(report.get("ok", false)) else EXIT_FINDINGS)


## The help text, which is also the whole documentation of this door - a command line whose usage
## lives in a guide is a command line nobody runs correctly the first time.
func _usage() -> String:
	var lines: PackedStringArray = PackedStringArray([
		"Godot EventSheets - documentation chores.",
		"",
		"  godot --headless --script addons/eventsheet/cli.gd -- <command> [options]",
		"",
		"Commands:",
		"  docs-check     read the guides and report what they do not answer, and what has drifted",
		"  docs-export    rewrite the project manual, then export the Manual as a folder of HTML",
		"  docs-harvest   ask this engine to write its own class reference, once per version",
		"  docs-engine-text  DOWNLOADS: the reference descriptions for this exact version of Godot,",
		"                    which the harvest cannot write because the engine keeps them inside the",
		"                    editor. Once per version, kept on this machine, and asked for by name.",
		"",
		"Options:",
		"  --out=<folder>   where docs-export writes the site",
		"  --locale=<code>  export the site in a language, marking the pages nobody has translated",
		"  --limit=<n>      read only the first n guides (faster; a full read is the real gate)",
		"  --engine_text_limit=<n>  fetch only n classes this run, and continue where it stopped next time",
		"",
		"Exits 0 when there is nothing to fix, 1 when there is, 2 when the command was wrong.",
	])
	return "\n".join(lines)
