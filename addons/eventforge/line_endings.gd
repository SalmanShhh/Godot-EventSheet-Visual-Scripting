# Godot EventSheets - the advisory note about how this checkout stores its sheets.
#
# Sheets are written with Unix endings on every platform. That is Godot's own convention (the engine
# writes `\n` into every file it saves, on Windows as much as anywhere else), it is what the
# compiler emits, and it is what the byte-exact round-trip this whole plugin stands on assumes: open
# a `.gd`, save it untouched, get the same bytes.
#
# GIT CAN QUIETLY UNDO THAT. With `core.autocrlf = true` - which is what the Windows installer offers
# by default - git rewrites text files to CRLF as it writes them into the working tree. Every sheet
# in the checkout then has a `\r` on the end of every line that the plugin did not put there, the
# next save takes them all back out, and a one-row change arrives in review as a diff touching every
# line of the file. Worse, and the reason this is worth a note at all: two people whose git is set
# differently produce different bytes from the same edit, so the merge conflicts this pass's other
# half guards against become routine instead of rare.
#
# THE FIX IS ONE COMMITTED LINE, and it belongs to the project rather than to any machine: a
# `.gitattributes` entry pinning `.gd` to LF beats whatever any contributor's git is configured to
# do, on every platform, forever. So the note shows that line and says where to put it.
#
# THIS PLUGIN NEVER WRITES GIT CONFIGURATION. Not `.git/config`, not `.gitattributes`, not a global
# setting. A tool that reconfigures somebody's version control because it preferred a different
# answer is a tool nobody can trust with a repository, and the one-line fix is a line a person should
# see in their own diff. The note is a sentence and a line to copy, and that is the whole of it.
#
# ADVISORY, ALWAYS. It is a note and never a warning: a project that has lived happily with CRLF
# working copies is not broken, and a Doctor that accuses a working project gets switched off.
#
# PURE + STATIC over TEXT rather than over paths, so the rule is pinned against fixtures rather than
# against whatever the machine running the suite happens to have configured.
@tool
class_name EventSheetLineEndings
extends RefCounted

## The line to commit. One line, and the only thing this file ever asks anybody to write.
const SHEET_ATTRIBUTE := "*.gd text eol=lf"

## Where the two answers are read from, relative to the project root.
const ATTRIBUTES_FILE := "res://.gitattributes"
const GIT_CONFIG_FILE := "res://.git/config"
## What says this is a git checkout at all. No git, no note: there is nothing here to advise.
const GIT_DIRECTORY := "res://.git"

## The id the note is filed under. Frozen alongside the wording, like every other check id.
const CHECK_ID := "line-endings"


## True when `.gitattributes` already pins how `.gd` files are stored, in which case nothing else
## matters - an attribute beats every machine's own configuration, which is exactly why it is the fix
## this note asks for.
##
## Both spellings count. `eol=lf` says it outright; `-text` says "never translate this file's
## endings", which reaches the same place by refusing to convert at all. A pattern covering `.gd`
## means `*.gd` itself, or the `*` that covers everything.
static func attribute_pins_sheets(gitattributes_text: String) -> bool:
	for line: String in gitattributes_text.split("\n"):
		var text: String = line.strip_edges()
		if text.is_empty() or text.begins_with("#"):
			continue
		var parts: PackedStringArray = text.split(" ", false)
		if parts.size() < 2:
			continue
		if parts[0] != "*.gd" and parts[0] != "*":
			continue
		for index: int in range(1, parts.size()):
			if parts[index] == "-text" or parts[index].begins_with("eol="):
				return true
	return false


## What this checkout's own git config says `core.autocrlf` is: "true", "input", "false", or "" when
## the file does not set it at all.
##
## THE REPOSITORY'S CONFIG AND NOTHING ELSE. A global setting lives in the reader's home directory,
## which is not this project's business to read and would make the same project report differently on
## two machines - and the note's answer, the committed attribute, is the one that covers both cases
## anyway.
static func autocrlf_of(git_config_text: String) -> String:
	var in_core: bool = false
	for line: String in git_config_text.split("\n"):
		var text: String = line.strip_edges()
		if text.begins_with("["):
			in_core = text.begins_with("[core]")
			continue
		if not in_core or not text.to_lower().begins_with("autocrlf"):
			continue
		var equals: int = text.find("=")
		if equals >= 0:
			return text.substr(equals + 1).strip_edges().to_lower()
	return ""


## The note, or "" when there is nothing to say. Two readings, one note:
##
##   the attribute is there            -> silence, whatever any git is set to
##   the attribute is missing, autocrlf is on   -> this checkout is already being rewritten
##   the attribute is missing, autocrlf is off  -> the next contributor's git decides
##
## The second and third are the same fix and differ only in how urgent they sound, which is the
## honest difference between them.
static func note(gitattributes_text: String, git_config_text: String) -> String:
	if attribute_pins_sheets(gitattributes_text):
		return ""
	var autocrlf: String = autocrlf_of(git_config_text)
	if autocrlf == "true":
		return "This checkout has core.autocrlf=true, so git rewrites every .gd to CRLF as it writes it into your working tree. Sheets are written with Unix endings on every platform, so each save takes those endings back out and a one-row change arrives in review as a diff touching every line. Commit this one line to .gitattributes and the setting stops mattering:  %s" % SHEET_ATTRIBUTE
	return "Nothing in .gitattributes says how .gd files are stored, so each contributor's own git setting decides - and core.autocrlf=true (the Windows default) rewrites every sheet to CRLF on checkout, which turns a one-row change into a diff touching every line. Commit this one line and the answer stops depending on the machine:  %s" % SHEET_ATTRIBUTE


## The same reading, taken off the project itself. "" when this is not a git checkout, because a
## project that is not under git has nothing here to be advised about.
static func project_note() -> String:
	if not DirAccess.dir_exists_absolute(GIT_DIRECTORY):
		return ""
	return note(FileAccess.get_file_as_string(ATTRIBUTES_FILE),
		FileAccess.get_file_as_string(GIT_CONFIG_FILE))
