# Godot EventSheets - the Doctor's Files section: three path mistakes the editor never mentions, and
# two readings of the one trust boundary nothing else in the engine draws.
#
# The first three are the same shape of bug. The line is correct GDScript, it runs, and the editor is
# silent - and then it behaves differently, or not at all, on the machine the game is sent to.
#
#   A WRITE AIMED AT res://    THE EXPORT TRAP. `res://` is a folder while you are in the editor and
#                              a packed archive afterwards, so a write there works every time you
#                              test it and fails in every exported build. Nothing reports it: the
#                              open simply returns null and the guarded row does nothing. The fix
#                              rewrites the path under `user://`, which is the place that is
#                              writable, per-player, and survives the game being updated.
#
#   AN ABSOLUTE OS PATH        A drive letter or a POSIX root names a folder on exactly one
#                              computer. It is usually a path pasted out of a file browser while
#                              somebody was testing, and it is invisible until somebody else runs
#                              the game. The fix rewrites it under `user://` (a file the game
#                              writes) or `res://` (a file the game ships with) - the reader picks,
#                              because only they know which of the two they meant.
#
#   AN UNGUARDED READ OF user:// A read of the player's folder is a read of a file that may not be
#                              there yet: the first run has no save, no settings and no log. Godot
#                              answers with "" rather than an error, so the game reads an empty
#                              string as data and goes wrong later, somewhere else. This one is a
#                              NOTE, not a warning - an empty string is a perfectly good answer if
#                              that is what the sheet meant - and its door is a respelling: the same
#                              read with the fallback said out loud.
#
# The last two are not bugs at all, which is exactly why nothing reports them:
#
#   A LOAD OF OUTSIDE CONTENT   A path that came in through one of the game's own doors - a drop on
#                               the window, the player's file chooser, a watched folder, an unpacked
#                               archive - handed to `load()` or `ResourceLoader.load()`. That line
#                               works. It also builds whatever the file describes, and a scene or a
#                               resource file may name a SCRIPT, so a file somebody else made can run
#                               its author's code inside this game. The doors beside it are the same
#                               file read as DATA - as an image, as text, as a table - and data
#                               cannot carry behaviour. Which reading was meant is the reader's call,
#                               so this one names the line and offers three doors rather than a fix.
#
#   A SCENE BUILT UNASKED       The same boundary, read the other way round: a line that builds a
#                               SCENE file whose path is written in the line and is not under
#                               `res://` - the player's folder, or a folder on one computer - with no
#                               Scene File Is Data-Only question over that same file anywhere around
#                               it. A `.tscn` is a table that may name a script, so this is a
#                               stranger's code running as this game. The file is named and the
#                               question is one row, so unlike the check above this one has a door:
#                               the question, asked first.
#
# EVERY CHECK IS A PURE FUNCTION OVER TEXT, and the gathering is separate, so the tests pin the exact
# words a reader meets rather than a count. The corpus is EMITTED SCRIPTS rather than sheets, for the
# reason the release-build console check is: the line is in the file whoever typed it, and a check
# built on sheet resources alone would skip every project whose sheets are `.gd`.
#
# NOTHING IS STORED and nothing is written inside res://. Every answer is derived on each ask, so a
# fixed project stops reporting with no state to clean up.
#
# THE FIXES ARE ELSEWHERE. This file says what is wrong and offers the before/after RECEIPT of what a
# fix would do; the fixes themselves are the dock's, applied through its undo funnel, because a
# report is not a place from which to rewrite somebody's sheet.
@tool
class_name EventSheetFilesDoctor
extends EventSheetDoctorSection

## The id the section is registered under, and the ids each kind of line is filed as. Frozen
## alongside the wording: the tests and the quick-fix chips address a finding by these.
const CHECK_ID := "files"
const CHECK_RES_WRITE := "files-write-to-res"
const CHECK_ABSOLUTE_PATH := "files-absolute-path"
const CHECK_UNGUARDED_READ := "files-unguarded-read"
const CHECK_LOADS_OUTSIDE := "files-loads-outside-content"
const CHECK_UNTRUSTED_SCENE := "files-untrusted-scene-load"

## Folders whose scripts are not this project's to answer for: the plugin itself, the shipped packs,
## the suite and the tools. The same list the Ship It section keeps, for the same reason.
const NOT_MINE: PackedStringArray = [
	"res://addons/", "res://eventsheet_addons/", "res://tests/", "res://tools/",
]

## How many lines one finding NAMES before it starts counting. A finding that lists forty lines is a
## wall nobody reads; one and a number is a sentence.
const NAMED_LIMIT: int = 1


## Registers the section, replacing any previous registration - so a plugin reload, a second Doctor
## run and a test that registers it by hand all leave exactly one.
static func ensure_registered() -> void:
	EventSheets.register_doctor_check(CHECK_ID, Callable(EventSheetFilesDoctor, "check"))


## The section, with the contract every registered check has: append findings, never write inside
## res://.
static func check(_sheet_paths: PackedStringArray, findings: Array[Dictionary]) -> void:
	findings.append_array(report(project_sources()))


## The whole section over one corpus of {script path: source text}. Pure, so a test hands it two
## made-up scripts and reads back the exact sentences.
static func report(sources: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.append_array(res_write_findings(sources))
	out.append_array(absolute_path_findings(sources))
	out.append_array(unguarded_read_findings(sources))
	out.append_array(loads_outside_findings(sources))
	out.append_array(untrusted_scene_findings(sources))
	return out


## The project's own scripts and their text, read ONCE for the whole section, through the audit's
## shared listing and its shared read - so this adds no walk of the tree and no second read.
static func project_sources() -> Dictionary:
	var sources: Dictionary = {}
	for script_path: String in EventSheetProjectDoctor._project_scripts():
		if _is_someone_elses(script_path):
			continue
		var text: String = EventSheetProjectDoctor.source_of(script_path)
		if not text.is_empty():
			sources[script_path] = text
	return sources


# ── The export trap ──────────────────────────────────────────────────────────────────────────


## One finding per script that writes to a `res://` path, naming the first line and counting the
## rest. Scripts are walked in sorted order so two audits of an unchanged project read identically.
static func res_write_findings(sources: Dictionary) -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	for script_path: String in _sorted_keys(sources):
		var lines: PackedStringArray = res_write_lines(str(sources[script_path]))
		if lines.is_empty():
			continue
		var message: String = EventSheetL10n.translate("%s writes to a res:// path, which works here and fails in every exported build - res:// is a packed archive once the game is built, not a folder. First: %s.") % [
			script_path.get_file(), lines[0]]
		message += _and_more(lines)
		message += " " + EventSheetL10n.translate("A game writes to user:// - the player's folder, which is writable, one per player, and survives the game being updated.")
		message += " " + _read_off_the_literal()
		findings.append(_finding("warning", CHECK_RES_WRITE, script_path, message, lines[0]))
	return findings


## The lines of this source that write to a literal `res://` path, trimmed, in the order they appear.
## A READ of res:// is never here: reading the game's own files is what res:// is for.
static func res_write_lines(source: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var statements: PackedStringArray = _statements_of(source)
	var packers: PackedStringArray = _packer_names(statements)
	for line: String in statements:
		var literals: PackedStringArray = _write_path_literals(line)
		literals.append_array(_packer_open_literals(line, packers))
		for literal: String in literals:
			if EventForgeFilePlaces.place_of("\"%s\"" % literal) == EventForgeFilePlaces.PLACE_RES:
				found.append(line)
				break
	return found


## The names this source binds to a `ZIPPacker`, in the order they are bound. An archive is written
## through a NAME - `var zip := ZIPPacker.new()` on one line, `zip.open(path)` on another - so the
## write is followed by the name, which is also what keeps a ZIPReader's identical `open(` out of the
## answer. Only a plain `<name> = ZIPPacker.new()` is followed; a packer held in an array or a field
## is one this check has nothing to say about, exactly as a built path is.
static func _packer_names(statements: PackedStringArray) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	for line: String in statements:
		if not line.contains(EventForgeFilePlaces.PACKER_CLASS):
			continue
		var equals_at: int = line.find("=")
		if equals_at < 0 or equals_at > line.find(EventForgeFilePlaces.PACKER_CLASS):
			continue
		var left: String = line.substr(0, equals_at).strip_edges().trim_suffix(":")
		left = left.trim_prefix("var ").split(":")[0].strip_edges()
		if not left.is_empty() and not left.contains(" ") and not names.has(left):
			names.append(left)
	return names


## The path literals one line hands to a packer's `open`, which is the line that WRITES the archive.
static func _packer_open_literals(line: String, packers: PackedStringArray) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for packer_name: String in packers:
		var mark: String = packer_name + EventForgeFilePlaces.OPEN_CALL
		var at: int = line.find(mark)
		while at >= 0:
			for literal: String in _quoted_literals(_arguments_after(line, at + mark.length())):
				found.append(literal)
			at = line.find(mark, at + mark.length())
	return found


## The path literals one line hands to a WRITE. `FileAccess.open(p, FileAccess.WRITE)` writes and
## `FileAccess.open(p, FileAccess.READ)` does not, so the mode is read rather than assumed; every
## DirAccess call named here writes by existing.
static func _write_path_literals(line: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for call_text: String in EventForgeFilePlaces.WRITE_CALLS:
		var at: int = line.find(call_text)
		while at >= 0:
			var arguments: String = _arguments_after(line, at + call_text.length())
			if call_text != "FileAccess.open(" or _opens_for_writing(arguments):
				for literal: String in _quoted_literals(arguments):
					found.append(literal)
			at = line.find(call_text, at + call_text.length())
	return found


## True when a `FileAccess.open` names one of the two modes that can write. READ is the third, and a
## read of res:// is correct.
static func _opens_for_writing(arguments: String) -> bool:
	return arguments.contains("FileAccess.WRITE") or arguments.contains("FileAccess.READ_WRITE")


# ── A folder on one computer ─────────────────────────────────────────────────────────────────


## One finding per script holding an absolute OS path in a file call.
static func absolute_path_findings(sources: Dictionary) -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	for script_path: String in _sorted_keys(sources):
		var lines: PackedStringArray = absolute_path_lines(str(sources[script_path]))
		if lines.is_empty():
			continue
		var message: String = EventSheetL10n.translate("%s reaches a file by an absolute path, which names a folder on one computer and on no other. First: %s.") % [
			script_path.get_file(), lines[0]]
		message += _and_more(lines)
		message += " " + EventSheetL10n.translate("A file the game WRITES belongs under user://; a file it SHIPS WITH belongs under res:// and inside the project.")
		message += " " + _read_off_the_literal()
		findings.append(_finding("warning", CHECK_ABSOLUTE_PATH, script_path, message, lines[0]))
	return findings


## The lines of this source that hand an absolute OS path to a file call, trimmed, in the order they
## appear.
static func absolute_path_lines(source: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for line: String in _statements_of(source):
		for literal: String in _file_call_literals(line):
			if EventForgeFilePlaces.is_absolute_os_path(literal):
				found.append(line)
				break
	return found


## The classes whose every method reaches the filesystem, and the three lone calls that do. Absolute
## looking text is everywhere in a game - a node path, a URL, a regular expression - so the question
## is only ever asked of what a file call was actually HANDED.
const FILE_CLASSES: PackedStringArray = ["FileAccess.", "DirAccess."]
const FILE_CALLS: PackedStringArray = [
	"ProjectSettings.globalize_path(", "OS.shell_open(", "OS.shell_show_in_file_manager(",
]


## The quoted literals one line hands to a file call, in the order they appear - never every quoted
## string ON the line. A trailing comment sits on the same line and is an argument to nothing, so
## `FileAccess.open(path, FileAccess.READ)  # was "C:/temp/x.txt"` is a line about a path the code
## does not use, and reading it as one was a warning nobody could act on.
static func _file_call_literals(line: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for class_mark: String in FILE_CLASSES:
		var at: int = line.find(class_mark)
		while at >= 0:
			var from: int = at + class_mark.length()
			var open_at: int = line.find("(", from)
			# Only when the bracket really belongs to THIS call: `FileAccess.open(` is a call and
			# `FileAccess.WRITE` is a constant whose line may hold somebody else's brackets.
			if open_at >= 0 and _is_identifier(line.substr(from, open_at - from)):
				found.append_array(_quoted_literals(_arguments_after(line, open_at + 1)))
			at = line.find(class_mark, from)
	for call_text: String in FILE_CALLS:
		var call_at: int = line.find(call_text)
		while call_at >= 0:
			found.append_array(_quoted_literals(
				_arguments_after(line, call_at + call_text.length())))
			call_at = line.find(call_text, call_at + call_text.length())
	return found


# ── A read of a file that is not there yet ───────────────────────────────────────────────────


## One NOTE per script that reads a `user://` path without saying what to use when the file is not
## there. A note rather than a warning: an empty string is a perfectly good answer when that is what
## the sheet meant, and the door beside it is a respelling rather than a correction.
static func unguarded_read_findings(sources: Dictionary) -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	for script_path: String in _sorted_keys(sources):
		var lines: PackedStringArray = unguarded_read_lines(str(sources[script_path]))
		if lines.is_empty():
			continue
		var message: String = EventSheetL10n.translate("%s reads a user:// file without saying what to use when it is not there, and the first run of a game has no save, no settings and no log. Godot answers with empty text rather than an error, so the game reads nothing as data. First: %s.") % [
			script_path.get_file(), lines[0]]
		message += _and_more(lines)
		message += " " + EventSheetL10n.translate("Read Text File (or a fallback) says the answer out loud, and the guard is written into the line.")
		message += " " + _read_off_the_literal()
		findings.append(_finding("info", CHECK_UNGUARDED_READ, script_path, message, lines[0]))
	return findings


## The lines of this source that read a literal `user://` path with no guard on them. A line already
## carrying the file_exists question is the guarded shape and is never reported - which is also what
## makes the fix's own output stop reporting itself.
static func unguarded_read_lines(source: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for line: String in _statements_of(source):
		var at: int = line.find(EventForgeFilePlaces.READ_CALL)
		if at < 0:
			continue
		var arguments: String = _arguments_after(line, at + EventForgeFilePlaces.READ_CALL.length())
		if _guarded_paths(line).has(arguments.strip_edges()):
			continue
		for literal: String in _quoted_literals(arguments):
			if EventForgeFilePlaces.place_of("\"%s\"" % literal) == EventForgeFilePlaces.PLACE_USER:
				found.append(line)
				break
	return found


## The path expressions one line asks `file_exists` about, exactly as they are written. A guard is
## only a guard over the path it NAMES: a line asking about one file and reading another is the
## unguarded read it looks like, and reporting it is the whole point of the check.
static func _guarded_paths(line: String) -> PackedStringArray:
	var asked: PackedStringArray = PackedStringArray()
	var at: int = line.find(EventForgeFilePlaces.EXISTS_CALL)
	while at >= 0:
		asked.append(_arguments_after(line,
			at + EventForgeFilePlaces.EXISTS_CALL.length()).strip_edges())
		at = line.find(EventForgeFilePlaces.EXISTS_CALL,
			at + EventForgeFilePlaces.EXISTS_CALL.length())
	return asked


# ── A file from outside the game, handed to the loader that can run code ─────────────────────


## One finding per script that hands an outside path to a call that builds what the file describes -
## the loaders, the threaded pair, `change_scene_to_file` - or to `load_resource_pack`, which mounts
## it into `res://` instead and gets a sentence of its own.
##
## THE ONLY CHECK IN THIS SECTION THAT IS ABOUT SAFETY rather than about a path that will not work.
## The other three describe a game that breaks; this one describes a game that works exactly as
## written and runs somebody else's code while doing it. It is a WARNING and not an error, because a
## project may mean it: a game whose mods ARE code is a deliberate decision, and the decision is the
## reader's. What is not a decision is making it without knowing, which is what this says out loud.
##
## THERE IS NO ONE-CLICK FIX and there should not be. The three doors below are three different
## readings of the same file, and only the reader knows which one the file was ever meant to be.
static func loads_outside_findings(sources: Dictionary) -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	for script_path: String in _sorted_keys(sources):
		var lines: PackedStringArray = EventForgeOutsidePaths.loading_outside_lines(
			str(sources[script_path]))
		if lines.is_empty():
			continue
		var message: String = EventSheetL10n.translate("%s loads a file that came from outside the game - dropped on the window, chosen by the player, or found in a watched or unpacked folder. First: %s.") % [
			script_path.get_file(), lines[0]]
		message += _and_more(lines)
		message += " " + EventSheetL10n.translate("A scene or a resource file can name a script, and loading one runs that script with everything this game can reach - the player's files, their network, their machine. The file was written by whoever made it, and that is not this project.")
		if _mounts_a_pack(lines):
			message += " " + EventSheetL10n.translate("One of those lines MOUNTS a pack rather than loading a file: load_resource_pack puts everything inside it under res:// from then on, and unless its second argument says otherwise it REPLACES the game's own files with the ones it carries. Nothing runs at that moment and everything after it may be somebody else's - including the files the rest of this project treats as the game's own by construction.")
		message += " " + EventSheetL10n.translate("Read it as DATA instead, and the file cannot bring behaviour with it: Image From File for a picture, Read Text File (or a fallback) for text, Table From File for rows and columns. If this game means to run code its players wrote, say so where they can read it - that is a decision, not an accident.")
		message += " " + EventSheetL10n.translate("This follows names inside ONE file - a path stored on this object, walked out of a list, or written under a folder this file watches or unpacks into. It does not follow one across files or through a call, so a file it says nothing about is not a file it has cleared.")
		findings.append(_finding("warning", CHECK_LOADS_OUTSIDE, script_path, message, lines[0]))
	return findings


## True when one of the reported lines mounts a resource pack rather than loading a file. The extra
## sentence is only true about that call, so it is only said about a file that holds one.
static func _mounts_a_pack(lines: PackedStringArray) -> bool:
	for line: String in lines:
		if line.contains(EventForgeOutsidePaths.PACK_MOUNT_CALL):
			return true
	return false


# ── A scene built from a file this project cannot vouch for ──────────────────────────────────
#
# The fifth check, and the SECOND one in this section that is about trust rather than about a path
# that will not work. It sits beside the outside-content check above and deliberately answers a
# different half of the same story:
#
#   the check above  follows a path that came in through one of the game's own DOORS - a drop, a
#                    chooser, a watched folder, an unpacked archive - wherever it ends up. It cannot
#                    see a path written into the line, and it offers no fix, because which of three
#                    data-shaped readings the file was meant to have is the reader's call.
#   this one         reads the PLACE off the path in the line, and only ever speaks about a SCENE
#                    file - the one format whose resource table can name a script and which nothing
#                    but a scene loader would be handed. Because the file is named and the question
#                    is one row, this one HAS a fix: the data-only question, asked first.
#
# So a line neither can see is a line neither claims, and a line both can see earns two findings that
# say two different true things about it. Nothing here re-says the other's sentence.
#
# THE GUARD IS READ OFF THE CALL, not off a list of row ids: the data-only question compiles to one
# named function, so a sheet that picked the row and a person who typed the call are both guarded.
# And a guard only counts over the file it NAMES, which is the same rule the unguarded-read check
# states about its own question - a line asking about one scene and building another is the
# unguarded build it looks like.


## One finding per script that builds a scene from a path this project cannot vouch for without
## asking the data-only question over that same path first.
static func untrusted_scene_findings(sources: Dictionary) -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	for script_path: String in _sorted_keys(sources):
		var source: String = str(sources[script_path])
		var lines: PackedStringArray = untrusted_scene_lines(source)
		if lines.is_empty():
			continue
		findings.append(_finding("warning", CHECK_UNTRUSTED_SCENE, script_path,
			untrusted_scene_message(script_path.get_file(), lines[0], lines.size()),
			untrusted_scene_subject(source)))
	return findings


## The words, in one place, so the Doctor's line and the sentence the sheet's own help strip shows
## under the selected row are the same finding said once. `named` is how many lines in this file say
## it, which is what the "more like it" tail counts.
static func untrusted_scene_message(label: String, line: String, named: int) -> String:
	var message: String = EventSheetL10n.translate("%s builds a scene from a file the game did not ship with, and a scene file can name a SCRIPT - so building one runs its author's code with everything this game can reach: the player's files, their network, their machine. First: %s.") % [
		label, line]
	if named > NAMED_LIMIT:
		message += " " + EventSheetL10n.translate("%d more like it in this file.") % (named - NAMED_LIMIT)
	message += " " + EventSheetL10n.translate("Scene File Is Data-Only asks about that same file first: it reads the file's own resource table as text and builds nothing, so a scene carrying code answers false before anything runs.")
	message += " " + EventSheetL10n.translate("This is read off the path written in the line - one built out of pieces, or held in a variable, is a path this check has nothing to say about - and it is about THAT file, not about the scenes that file points at.")
	return message


## The lines of this source that build a scene from a path whose place is not `res://`, with no
## data-only question over that same path anywhere in the blocks around them. Trimmed, in the order
## they appear.
static func untrusted_scene_lines(source: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	if not EventForgeSceneTrust.says_enough(source):
		return found
	var lines: PackedStringArray = source.split("\n")
	for index: int in range(lines.size()):
		var line: String = lines[index].strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var untrusted: PackedStringArray = EventForgeSceneTrust.untrusted_scene_paths(line)
		if untrusted.is_empty():
			continue
		var asked: PackedStringArray = _scene_paths_asked_about(lines, index)
		for path_expression: String in untrusted:
			if not asked.has(path_expression):
				found.append(line)
				break
	return found


## The first path this source builds unasked, which is what the finding is filed under and what the
## one-click door names. "" for a source that has none.
static func untrusted_scene_subject(source: String) -> String:
	var lines: PackedStringArray = untrusted_scene_lines(source)
	if lines.is_empty():
		return ""
	var untrusted: PackedStringArray = EventForgeSceneTrust.untrusted_scene_paths(lines[0])
	return "" if untrusted.is_empty() else untrusted[0]


## The scene files every block AROUND this line asks the data-only question about, plus the ones the
## line asks itself. The walk goes outwards by indentation - the enclosing `if`, then whatever
## encloses that - because an event compiles to an `if` and a sub-event to an `if` inside it, so a
## question asked by an event stands over every row under it.
static func _scene_paths_asked_about(lines: PackedStringArray, index: int) -> PackedStringArray:
	var asked: PackedStringArray = EventForgeSceneTrust.guarded_paths(lines[index])
	var indent: int = _indent_of(lines[index])
	var above: int = index - 1
	while above >= 0 and indent > 0:
		var line: String = lines[above]
		above -= 1
		if line.strip_edges().is_empty():
			continue
		var outer: int = _indent_of(line)
		if outer >= indent:
			continue
		indent = outer
		for path_expression: String in EventForgeSceneTrust.guarded_paths(line):
			if not asked.has(path_expression):
				asked.append(path_expression)
	return asked


## How many tabs one line begins with. Tabs, because every line this plugin emits is indented with
## them and the style gate says the same of every line it accepts.
static func _indent_of(line: String) -> int:
	var tabs: int = 0
	while tabs < line.length() and line[tabs] == "\t":
		tabs += 1
	return tabs


# ── The receipts, and the rows a fix would change ────────────────────────────────────────────
#
# Each of the three below answers the same question about ONE sheet: which rows this fix would touch,
# what each of their lines reads as now, and what it would read as afterwards. The fix itself lives
# in the dock (it needs the undo funnel); what lives here is the reading, so the sentence a reader
# approves and the edit that lands are computed from one place.


## What rewriting res:// writes under user:// WOULD do, as before/after pairs of the row's own value.
static func res_write_receipt(sheet: EventSheetResource) -> Array[Dictionary]:
	return _receipt(sheet, Callable(EventSheetFilesDoctor, "_res_write_rewrite"))


## The same rows, rewritten. Returns how many values changed, so the caller reports only real work.
static func rewrite_res_writes(sheet: EventSheetResource) -> int:
	return _rewrite(sheet, Callable(EventSheetFilesDoctor, "_res_write_rewrite"))


## What rewriting an absolute path under user:// WOULD do.
static func absolute_path_receipt(sheet: EventSheetResource) -> Array[Dictionary]:
	return _receipt(sheet, Callable(EventSheetFilesDoctor, "_absolute_path_rewrite"))


## The same rows, rewritten.
static func rewrite_absolute_paths(sheet: EventSheetResource) -> int:
	return _rewrite(sheet, Callable(EventSheetFilesDoctor, "_absolute_path_rewrite"))


## The fallback a respelling writes when the reader has not named one. Empty text is what Godot
## already answers with for a missing file, so the respelling changes the LINE and not the game: the
## guard becomes visible and the answer stays the one the sheet was already getting. A reader who
## wanted a different answer types it in the field the respelling put there.
const RESPELL_FALLBACK := "\"\""


## What respelling every unguarded user:// read of a sheet WOULD do, as before/after pairs of the
## parameter's own value. The Doctor's door for the note above: not a correction, a saying-out-loud.
static func guarded_read_receipt(sheet: EventSheetResource) -> Array[Dictionary]:
	var receipt: Array[Dictionary] = []
	_walk_values(sheet, func(_action: ACEAction, _param_id: String, value: String) -> String:
		var respelt: String = respell(value)
		if not respelt.is_empty():
			receipt.append({"before": value, "after": respelt})
		return "")
	return receipt


## The same values, respelt. Returns how many really changed.
static func respell_guarded_reads(sheet: EventSheetResource) -> int:
	var changed: Array[int] = [0]
	_walk_values(sheet, func(_action: ACEAction, _param_id: String, value: String) -> String:
		var respelt: String = respell(value)
		if respelt.is_empty():
			return ""
		changed[0] += 1
		return respelt)
	return changed[0]


## One value, with a bare read of a literal user:// path replaced by the guarded shape - or "" when
## there is nothing here to respell. The whole value must BE the read: a read buried in a longer
## expression is somebody's own sentence, and wrapping a piece of it in a ternary would change what
## the surrounding operators bind to.
static func respell(value: String) -> String:
	var text: String = value.strip_edges()
	if not text.begins_with(EventForgeFilePlaces.READ_CALL) or not text.ends_with(")"):
		return ""
	if text.contains(EventForgeFilePlaces.EXISTS_CALL):
		return ""
	var path: String = _arguments_after(text, EventForgeFilePlaces.READ_CALL.length())
	if path.length() != text.length() - EventForgeFilePlaces.READ_CALL.length() - 1:
		return ""
	if EventForgeFilePlaces.place_of(path) != EventForgeFilePlaces.PLACE_USER:
		return ""
	return EventForgeFilePlaces.guarded_read(path, RESPELL_FALLBACK)


## Every parameter of every action of a sheet, in row order, handed to `visitor` as
## (action, param_id, value); a non-empty return replaces the value. Wider than the path walk above
## on purpose: a read is written into whatever field wanted the text, not into a path field.
static func _walk_values(sheet: EventSheetResource, visitor: Callable) -> void:
	if sheet == null:
		return
	_walk_value_rows(sheet.events, visitor)
	for entry: Variant in sheet.functions:
		if entry is EventFunction:
			var event_function: EventFunction = entry
			_walk_value_rows(event_function.events if not event_function.events.is_empty()
				else event_function.rows, visitor)


static func _walk_value_rows(rows: Array, visitor: Callable) -> void:
	for row: Variant in rows:
		if row is EventGroup:
			var group: EventGroup = row
			_walk_value_rows(group.events if not group.events.is_empty() else group.rows, visitor)
		elif row is EventRow:
			var event: EventRow = row
			for action: Variant in event.actions:
				if not (action is ACEAction):
					continue
				var typed: ACEAction = action
				var params: Dictionary = typed.params
				var keys: Array = params.keys()
				keys.sort()
				for param_id: Variant in keys:
					var replacement: String = str(visitor.call(typed, str(param_id),
						str(params[param_id])))
					if not replacement.is_empty():
						params[str(param_id)] = replacement
			_walk_value_rows(event.sub_events, visitor)


## The new value one path parameter would take under the res://-write rule, or "" for one this rule
## leaves alone. Write-shaped parameters only: reading res:// is correct and is never rewritten.
static func _res_write_rewrite(_provider_id: String, ace_id: String, param_id: String,
		value: String) -> String:
	if not EventForgeFilePlaces.write_params_of(ace_id).has(param_id):
		return ""
	var literal: String = EventForgeFilePlaces.literal_of(value)
	if literal.is_empty() or not literal.begins_with(EventForgeFilePlaces.RES_SCHEME):
		return ""
	var rewritten: String = EventForgeFilePlaces.under_user(literal)
	return "" if rewritten.is_empty() else EventForgeFilePlaces.requote(value, rewritten)


## The new value one path parameter would take under the absolute-path rule. EVERY path parameter,
## write-shaped or not: a drive letter in a read is as unshippable as one in a write.
static func _absolute_path_rewrite(provider_id: String, ace_id: String, param_id: String,
		value: String) -> String:
	if not EventForgeFilePlaces.path_params_of(ace_id, provider_id).has(param_id):
		return ""
	var literal: String = EventForgeFilePlaces.literal_of(value)
	if literal.is_empty() or not EventForgeFilePlaces.is_absolute_os_path(literal):
		return ""
	var rewritten: String = EventForgeFilePlaces.under_user(literal)
	return "" if rewritten.is_empty() else EventForgeFilePlaces.requote(value, rewritten)


## The before/after pairs one rule would leave over a whole sheet, in row order.
static func _receipt(sheet: EventSheetResource, rule: Callable) -> Array[Dictionary]:
	var receipt: Array[Dictionary] = []
	_walk(sheet, func(action: ACEAction, param_id: String, value: String) -> bool:
		var rewritten: String = str(rule.call(str(action.provider_id), action.ace_id, param_id, value))
		if rewritten.is_empty():
			return false
		receipt.append({"before": value, "after": rewritten})
		return false)
	return receipt


## The same walk, writing. Returns how many parameter values really changed.
static func _rewrite(sheet: EventSheetResource, rule: Callable) -> int:
	var changed: Array[int] = [0]
	_walk(sheet, func(action: ACEAction, param_id: String, value: String) -> bool:
		var rewritten: String = str(rule.call(str(action.provider_id), action.ace_id, param_id, value))
		if rewritten.is_empty():
			return false
		(action.params as Dictionary)[param_id] = rewritten
		changed[0] += 1
		return true)
	return changed[0]


## Every path parameter of every file row of a sheet, in row order, handed to `visitor` as
## (action, param_id, value). One walk, so the receipt and the rewrite can only ever see the same
## rows in the same order.
static func _walk(sheet: EventSheetResource, visitor: Callable) -> void:
	if sheet == null:
		return
	_walk_rows(sheet.events, visitor)
	for entry: Variant in sheet.functions:
		if entry is EventFunction:
			var event_function: EventFunction = entry
			_walk_rows(event_function.events if not event_function.events.is_empty()
				else event_function.rows, visitor)


static func _walk_rows(rows: Array, visitor: Callable) -> void:
	for row: Variant in rows:
		if row is EventGroup:
			var group: EventGroup = row
			_walk_rows(group.events if not group.events.is_empty() else group.rows, visitor)
		elif row is EventRow:
			var event: EventRow = row
			for action: Variant in event.actions:
				if not (action is ACEAction):
					continue
				var typed: ACEAction = action
				for param_id: String in EventForgeFilePlaces.path_params_of(typed.ace_id,
						str(typed.provider_id)):
					visitor.call(typed, param_id, str((typed.params as Dictionary).get(param_id, "")))
			_walk_rows(event.sub_events, visitor)


# ── Shared ───────────────────────────────────────────────────────────────────────────────────


## Every non-blank, non-comment statement of a source, trimmed - the unit all three checks read.
static func _statements_of(source: String) -> PackedStringArray:
	var statements: PackedStringArray = PackedStringArray()
	for raw_line: String in source.split("\n"):
		var line: String = raw_line.strip_edges()
		if not line.is_empty() and not line.begins_with("#"):
			statements.append(line)
	return statements


## The text between a call's opening bracket and its matching close, so a nested call inside the
## arguments does not end them early.
static func _arguments_after(line: String, from: int) -> String:
	var depth: int = 1
	var index: int = from
	while index < line.length():
		var character: String = line[index]
		if character == "(":
			depth += 1
		elif character == ")":
			depth -= 1
			if depth == 0:
				return line.substr(from, index - from)
		index += 1
	return line.substr(from)


## The double-quoted strings in one piece of text, in order, without their quotes. Single quotes are
## deliberately left out: every path this plugin emits is double-quoted, and a lone apostrophe inside
## an ordinary sentence would otherwise open a string that never closes.
##
## AN ESCAPED QUOTE DOES NOT CLOSE A STRING. `"a \" b"` is one literal and not two halves of two, so
## the scan counts the backslashes in front of a quote and honours an odd number of them - otherwise
## a string carrying one is split in the wrong place and every literal after it on the line is read
## inside out.
static func _quoted_literals(text: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var index: int = 0
	while index < text.length():
		if text[index] != "\"":
			index += 1
			continue
		var close_at: int = _closing_quote(text, index + 1)
		if close_at < 0:
			break
		found.append(text.substr(index + 1, close_at - index - 1))
		index = close_at + 1
	return found


## Where the double quote that CLOSES a literal opened before `from` is, or -1 when the text runs out
## first.
static func _closing_quote(text: String, from: int) -> int:
	var index: int = from
	while index < text.length():
		if text[index] == "\"" and not _is_escaped(text, index):
			return index
		index += 1
	return -1


## True when a piece of text is one plain method name and nothing else.
static func _is_identifier(text: String) -> bool:
	if text.is_empty():
		return false
	for index: int in range(text.length()):
		var glyph: String = text[index]
		if glyph == "_" or glyph.is_valid_int() or glyph.to_lower() != glyph.to_upper():
			continue
		return false
	return true


## True when the character at `index` is preceded by an odd number of backslashes, which is what an
## escaped one is.
static func _is_escaped(text: String, index: int) -> bool:
	var slashes: int = 0
	var back: int = index - 1
	while back >= 0 and text[back] == "\\":
		slashes += 1
		back -= 1
	return slashes % 2 == 1


## What these three checks CANNOT see, said in the finding rather than only in a comment. Every one of
## them reads the PATH LITERAL a call was handed, so a path built out of pieces (`"user://" + name`
## is caught; `base + name` is not) or held in a variable is one they have nothing to say about. A
## check that overstates its reach is worse than no check, because a quiet report then reads as a
## clean project.
static func _read_off_the_literal() -> String:
	return EventSheetL10n.translate("This is read off the path written in the line: one built out of pieces, or held in a variable, is a path this check has nothing to say about - a quiet report is not a proof.")


## The tail a finding grows when more than one line in the same file says the same thing.
static func _and_more(lines: PackedStringArray) -> String:
	if lines.size() <= NAMED_LIMIT:
		return ""
	return " " + EventSheetL10n.translate("%d more like it in this file.") % (lines.size() - NAMED_LIMIT)


static func _sorted_keys(source: Dictionary) -> PackedStringArray:
	var keys: PackedStringArray = PackedStringArray()
	for key: Variant in source.keys():
		keys.append(str(key))
	keys.sort()
	return keys


static func _is_someone_elses(script_path: String) -> bool:
	for prefix: String in NOT_MINE:
		if script_path.begins_with(prefix):
			return true
	return false
