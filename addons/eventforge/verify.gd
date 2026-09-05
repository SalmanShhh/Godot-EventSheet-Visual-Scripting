# Godot EventSheets - the standing contracts, asked of a project's own files from a command line.
#
# The promises this plugin makes are not documentation. They are properties of the files sitting in
# front of you, and every one of them can be checked without opening the editor. That is all this is:
# it reads your project without writing a byte of it, and it answers with an exit code plus one line
# per failure naming the file, the line, and the place in the editor that shows the same thing.
#
# FOUR CHECKS, EACH ONE SENTENCE OF THE CONTRACT SPELLED OUT:
#
#  1. Every file parses as valid GDScript. A sheet IS its `.gd`, so a file that does not parse is not
#     a sheet to fix later - it is a game that does not start. Merge markers are the usual way a file
#     arrives in that state, so they are named as themselves rather than as a syntax error.
#  2. Every file round-trips byte for byte. Opening a file as a sheet and saving it untouched has to
#     reproduce it exactly, and the only honest way to hold that law is to ask it of real files.
#  3. No scope declares one baked local twice. Two branches can mint the same token and a merge can
#     bring both in; the file Godot then refuses to parse is the one that reaches the next person.
#  4. The migration report holds no row waiting on a human. A row whose verb has moved still compiles
#     exactly as it did, so nothing here is urgent - but a branch that lands with rows nobody has
#     answered has postponed a decision onto whoever opens the file next.
#
# WHY IT IS A COMMAND AND NOT A HOOK. The plugin ships the question; git decides when it is asked.
# Nothing here installs a hook, writes a config file, or runs itself when a sheet is opened or saved.
# Handed a list of paths it checks exactly those, which is what makes it usable from a pre-commit
# hook on the staged files; handed nothing it checks the whole project, which is what a branch gate
# and a CI job want.
#
# READ-ONLY AND DETERMINISTIC. Nothing under `res://` is written or cached, paths are sorted before
# they are read, and no message carries a timestamp or a machine path - so two machines given the
# same tree print the same report. The one thing a run writes at all is the throwaway `user://` file
# the byte gate re-emits into, which is the plugin's own probe path and is never a file of yours.
@tool
class_name EventSheetVerify
extends RefCounted

## The four checks, by the ids the report files them under. Frozen alongside their wording, like
## every other check id in this plugin: a hook that greps for one addresses it by this.
const CHECK_PARSES := "parses"
const CHECK_ROUND_TRIP := "round-trip"
const CHECK_DUPLICATE_TOKEN := EventSheetLocalTokens.CHECK_DUPLICATE_TOKEN
const CHECK_MIGRATION_ASKS := "migration-asks"

## In the order they are run and printed, which is also the order they matter in: a file that does
## not parse has nothing useful to say about its rows.
const CHECKS: PackedStringArray = [
	CHECK_PARSES, CHECK_ROUND_TRIP, CHECK_DUPLICATE_TOKEN, CHECK_MIGRATION_ASKS,
]

## Godot's own script-template folder. The files in it are not scripts: they hold `_BASE_` and
## `_CLASS_` placeholders that the editor substitutes when it makes a new file from one, so they
## never parse and are never loaded. Skipped by name because that is an engine convention rather
## than a choice a project made.
const TEMPLATE_DIR := "res://script_templates/"

## The two things a run reads: GDScript, and a stored sheet. Anything else handed over by a hook is
## not a file this gate has a question about, and is dropped rather than complained at.
const READ_AS: PackedStringArray = ["gd", "tres"]

## How much of a differing line the round-trip failure quotes before it stops. Long enough to
## recognise the line, short enough that a report stays readable in a terminal.
const QUOTED_LINE_WIDTH: int = 72


## Every failure the given files hold: the three text checks first, file by file in path order, and
## then the migration rows in the order the report itself keeps them (by file, then by event). Two
## machines given the same tree print the same lines in the same order.
##
## `requested` is the files to check, and an empty one means the whole project. `skipped` is a list
## of path PREFIXES to leave out, which exists for one situation: a folder of deliberately broken
## GDScript kept as test fixtures is the one thing this gate cannot tell from a real file, so a
## project that keeps one names it rather than being told its own fixtures are broken.
##
## `running_script` is the file the engine is CURRENTLY EXECUTING, when the caller is a script that
## is itself inside the corpus - which the whole-project form always is, since the gate script lives
## in the project. Check 1 loads every file as a script to ask the engine's own verdict, and asking
## that of the running main loop hangs the process and then takes it down, so the one file the engine
## is demonstrably able to read is answered by that fact instead. The other three still ask it
## everything.
##
## `read_every_script` is THE RUN THAT HAS TO BE CERTAIN. Check 4's whole-project corpus is every
## stored `.tres` sheet and a capped sample of the `.gd` ones, because reading a script means LIFTING
## it and a thousand of them is minutes rather than seconds - which is the right trade for a hook and
## the wrong one for a release check. Asked for, the `.gd` half is read whole and the verdict says so.
## It changes nothing about a run that named its files: those are all read either way.
##
## Returns {"files": int, "migration_files": int, "migration_note": String,
## "failures": Array[Dictionary]}, each failure shaped {check, path, line, message, where} - `line`
## is 1-based and 0 when the failure belongs to the file rather than to a line of it, and `where`
## names the one place in the editor that shows the same thing. `migration_files` is how many files
## check 4 actually read, which is NOT always `files`: the whole-project report reads every stored
## sheet and only samples the `.gd` ones, and a verdict printing one of those numbers over the other
## is how a gate reports green over files nobody read. `migration_note` is the sentence a whole read
## names itself with, and "" for every other run.
static func run(requested: PackedStringArray = PackedStringArray(),
		skipped: PackedStringArray = PackedStringArray(),
		running_script: String = "", read_every_script: bool = false) -> Dictionary:
	var paths: PackedStringArray = corpus(requested, skipped)
	var failures: Array[Dictionary] = []
	for path: String in paths:
		failures.append_array(file_failures(path, running_script))
	var migration: Dictionary = _migration_rows(requested, paths, read_every_script)
	var rows: Array[Dictionary] = []
	rows.assign(migration.get("rows", []))
	failures.append_array(migration_failures(rows))
	return {"files": paths.size(), "migration_files": int(migration.get("files", 0)),
		"migration_note": str(migration.get("note", "")), "failures": failures}


## The files one run reads: the ones asked for, or the whole project when nothing was asked for.
## Sorted, de-duplicated, and filtered to files that exist - a hook hands over whatever git printed,
## including a path that was staged as a deletion.
##
## The project's own corpus is every `.gd` outside `addons/` plus every stored `.tres` sheet. The
## plugin's own code is not the project's game, and a `.gd` that is a sheet is deliberately
## indistinguishable from one a person typed, so there is nothing to filter on and no need for one:
## both kinds have to parse and both have to round-trip.
##
## A `.tres` is in the list for the migration check alone - it is a stored sheet rather than
## GDScript, so the three text checks have nothing to ask it, and its emitted `.gd` is in the list
## separately like any other file.
##
## A REQUESTED FOLDER IS THE FILES UNDER IT. A path that names a directory used to contribute
## nothing at all, so `-- eventsheet_addons demo` printed "0 file(s) read, nothing to answer" and
## exited 0 - a gate reporting a clean run over two trees it never opened. The obvious way to ask
## for a subtree is now the way that works, and a CI job no longer has to expand it with git first.
## A path that is not there contributes nothing and says nothing, deliberately: a hook hands over
## whatever git printed, and a staged deletion is a path that is gone.
static func corpus(requested: PackedStringArray = PackedStringArray(),
		skipped: PackedStringArray = PackedStringArray()) -> PackedStringArray:
	var listed: PackedStringArray = requested.duplicate()
	if listed.is_empty():
		listed = EventSheetProjectDoctor.all_project_scripts()
		listed.append_array(EventSheetTemplates.non_template_sheets(
			EventSheetProjectFind.list_project_sheets()))
	var kept: PackedStringArray = PackedStringArray()
	for listed_path: String in listed:
		for path: String in _named_files(in_project(listed_path)):
			if not READ_AS.has(path.get_extension().to_lower()) or not FileAccess.file_exists(path):
				continue
			if path.begins_with(TEMPLATE_DIR) or _is_skipped(path, skipped):
				continue
			if not kept.has(path):
				kept.append(path)
	kept.sort()
	return kept


## Every file under a folder, at any depth, sorted - the whole subtree, whatever its extension,
## because the caller decides which kinds it has a question about. Deterministic on any machine:
## a directory's entries come back in whatever order the filesystem holds them, so both lists are
## sorted before they are walked.
static func files_under(dir_path: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return found
	var file_names: PackedStringArray = dir.get_files()
	file_names.sort()
	for file_name: String in file_names:
		found.append(dir_path.path_join(file_name))
	var folder_names: PackedStringArray = dir.get_directories()
	folder_names.sort()
	for folder_name: String in folder_names:
		found.append_array(files_under(dir_path.path_join(folder_name)))
	return found


## A path as the engine addresses it. Git prints paths relative to the repository root and Godot
## reads them relative to nothing at all, so a hook that piped `git diff --name-only` straight in
## would hand over `player.gd` and be told, wrongly and silently, that there is no such file. The one
## place that difference is reconciled, so a hook can be the two lines it ought to be.
static func in_project(path: String) -> String:
	var written: String = path.strip_edges().replace("\\", "/").trim_prefix("./")
	if written.is_empty() or written.contains("://"):
		return written
	return "res://" + written.trim_prefix("/")


## The three checks one file answers on its own, and the ORDER IS THE POINT: the most specific
## reading of a broken file wins, because a reader can act on a named cause and cannot act on "it
## does not parse".
##
## Merge markers and a doubled baked local are both read off the TEXT, so both still answer for a
## file the engine has already refused - and both are the reason it refused. A file whose `_ready`
## declares one name twice is exactly a file Godot will not parse, so asking the engine first would
## bury the one sentence that says why and the one chip that fixes it. The engine's own verdict is
## asked last and only when nothing more specific applies.
##
## A file that does not parse is asked nothing about its rows: they are whatever the importer could
## make of text the engine rejects, and a second complaint about them would only bury the first.
##
## A stored `.tres` sheet answers none of these: it is not GDScript, so "does it parse" and "does it
## come back byte for byte" are questions about the `.gd` it emits, which is checked as itself.
## A FILE THAT CANNOT BE READ IS A FAILURE, not a pass. `FileAccess.get_file_as_string` answers ""
## for a file it could not open exactly as it does for an empty one, and the round-trip check reads
## "" as "nothing to say" - so an unreadable file used to walk through green.
static func file_failures(path: String, running_script: String = "") -> Array[Dictionary]:
	if path.get_extension().to_lower() != "gd":
		return []
	var handle: FileAccess = FileAccess.open(path, FileAccess.READ)
	if handle == null:
		return [_failure(CHECK_PARSES, path, 0,
			"This file could not be read, so none of the four contracts could be asked of it.",
			"Check that it is still on disk and that this account may read it - nothing in the editor can open it either.")]
	var source: String = handle.get_as_text()
	handle.close()
	var found: Array[Dictionary] = marker_failures(path, source)
	found.append_array(duplicate_token_failures(path, source))
	if not found.is_empty():
		return found
	found = parse_failures(path, running_script)
	if not found.is_empty():
		return found
	return round_trip_failures(path, source)


# ── 1. it parses ──────────────────────────────────────────────────────────────────


## Check 1, in the words the state deserves: the file still holds merge markers.
##
## It is a parse failure - a file with markers in it is not GDScript - but it is one a syntax error
## never explains, and the plugin already has exactly one reading of this state, the same textual
## guard that opens such a file read-only. The gate says what the editor says, off the same lines.
static func marker_failures(path: String, source: String) -> Array[Dictionary]:
	var markers: PackedInt32Array = EventSheetConflictGuard.marker_line_numbers(source)
	if markers.is_empty():
		return []
	return [_failure(CHECK_PARSES, path, markers[0],
		"Merge markers on %s. This is not GDScript, so nothing can read it: not the game, not the editor, not this gate." % EventSheetConflictGuard.lines_phrase(markers),
		"EventSheets opens a file in this state read-only, with a banner at the head naming those lines and Show the conflicts beside it.")]


## Check 1: the engine can read this file as GDScript.
##
## The engine's own verdict, never a checker of our own: the file is loaded as a script with the
## project's global classes available, exactly as the game loads it, and a load that comes back with
## no base type is a file the engine refused. It prints its own Parse Error line and the line number
## with it as it does so, which is where the reader gets the line - a second parser here could
## disagree with the one that actually refuses to run the game, and being quietly different from the
## engine is worse than being brief.
##
## The load is asked of the file on DISK rather than of anything already in memory, because the
## file on disk is what the hook is about to let through.
## EXCEPT OF THE FILE THE ENGINE IS RUNNING. Loading a script fresh, ignoring the cache, while that
## same script is the main loop hangs the process for as long as anybody waits and then takes it down
## with a segfault - and the whole-project form always has the gate script in its corpus, because the
## gate script lives in the project. That one file is answered by the fact that it is executing: a
## file the engine is running is a file the engine read. Its other three checks are asked as normal,
## so nothing about it goes unexamined.
static func parse_failures(path: String, running_script: String = "") -> Array[Dictionary]:
	if not running_script.is_empty() and path == in_project(running_script):
		return []
	var loaded: Variant = ResourceLoader.load(path, "GDScript", ResourceLoader.CACHE_MODE_IGNORE)
	if loaded is GDScript and not (loaded as GDScript).get_instance_base_type().is_empty():
		return []
	return [_failure(CHECK_PARSES, path, 0,
		"This file is not valid GDScript. A sheet is its .gd, so this is not a sheet to fix later - it is a file nothing loads.",
		"The engine printed its own Parse Error line above, naming the line; Godot's script editor names the same one.")]


# ── 2. it round-trips ─────────────────────────────────────────────────────────────


## Check 2: opening this file as a sheet and saving it untouched reproduces it byte for byte.
##
## Asked through the same byte gate every built-in lift is gated by, so this can never be a second
## opinion about what round-tripping means. What this adds is the line: a failing file is diffed
## against its own re-emission and the FIRST line that would change is the one reported, because
## "this file would come back different" is not something a person can act on and "line 41 would come
## back as this instead" is.
static func round_trip_failures(path: String, source: String) -> Array[Dictionary]:
	if source.is_empty() or EventSheets.round_trips(source):
		return []
	var sheet: EventSheetResource = EventSheets.open_gd_as_sheet(source)
	var written: String = ""
	if sheet != null:
		sheet.external_source_path = EventSheets.ROUND_TRIP_PROBE_PATH
		written = str(EventSheets.compile(sheet, sheet.external_source_path).get("output", ""))
	var differed: Dictionary = first_difference(source, written)
	return [_failure(CHECK_ROUND_TRIP, path, int(differed.get("line", 0)),
		"Opening this file as a sheet and saving it untouched would not reproduce it. %s" % str(differed.get("message", "")),
		"Open the file as a sheet: a line the importer cannot read back stays a verbatim Script block, and this is the first one that would come back changed.")]


## The first line at which two texts differ, as {line, message}. Both sides are quoted so the reader
## can see the change rather than being told there is one; a line longer than the report's width is
## cut, which is deterministic and keeps a minified line from taking the terminal with it.
##
## A DIFFERENCE YOU CANNOT SEE GETS SAID INSTEAD OF SHOWN. Two lines that read the same and differ in
## their trailing whitespace would print as the same words twice, which tells a reader nothing, so
## that case is named rather than quoted - and so is the file whose two versions agree line for line
## and differ only in whether the last one ends with a newline, which is the difference a diff tool
## draws as a whole changed line and a person cannot see at all.
##
## A file that differs only by being longer or shorter is a real answer too: the line reported is the
## first one that only one side has.
static func first_difference(before: String, after: String) -> Dictionary:
	var left: PackedStringArray = _lines_of(before)
	var right: PackedStringArray = _lines_of(after)
	var count: int = maxi(left.size(), right.size())
	for index: int in count:
		var mine: String = left[index] if index < left.size() else ""
		var theirs: String = right[index] if index < right.size() else ""
		if mine == theirs:
			continue
		if index >= right.size():
			return {"line": index + 1, "message": "Line %d would be dropped: %s" % [
				index + 1, _quoted(mine)]}
		if index >= left.size():
			return {"line": index + 1, "message": "%d line(s) would be added, the first of them %s" % [
				right.size() - left.size(), _quoted(theirs)]}
		if mine.strip_edges() == theirs.strip_edges():
			return {"line": index + 1, "message": "Line %d differs only in its trailing whitespace: %s" % [
				index + 1, _quoted(mine)]}
		return {"line": index + 1, "message": "Line %d would come back as %s instead of %s" % [
			index + 1, _quoted(theirs), _quoted(mine)]}
	return {"line": left.size(), "message": "The two agree line for line, so what differs is the newline at the end of the file: a file saved from the editor ends with one."}


## A text as its lines, with the empty piece a final newline leaves behind dropped - a file of three
## lines has three lines whether or not it ends with a newline. That difference is real and is
## reported, but it belongs to the FILE rather than to a line of it, so counting it as a fourth line
## would make every such file look like it had a line added.
static func _lines_of(text: String) -> PackedStringArray:
	var lines: PackedStringArray = text.split("\n")
	if lines.size() > 0 and lines[lines.size() - 1].is_empty():
		lines.remove_at(lines.size() - 1)
	return lines


# ── 3. no scope declares one baked local twice ────────────────────────────────────


## Check 3: no two rows of this file declare the same baked local in one scope.
##
## The reading and the wording are the Doctor's own - one sentence for this state, wherever it is
## said - and the line reported is the SECOND declaration, because the first one is the row that was
## already in the file and the second is the row a merge brought in.
static func duplicate_token_failures(path: String, source: String) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for entry: Dictionary in EventSheetLocalTokens.duplicates_in(source):
		var lines: PackedInt32Array = entry.get("lines", PackedInt32Array()) as PackedInt32Array
		found.append(_failure(CHECK_DUPLICATE_TOKEN, path, lines[1] if lines.size() > 1 else 0,
			EventSheetLocalTokens.duplicate_message(entry),
			"Project Doctor lists this line with one chip on it, Re-mint one of them, and the re-mint is an ordinary undoable sheet edit."))
	return found


# ── 4. nothing is waiting on a human ──────────────────────────────────────────────


## Check 4: the migration report holds no row a person still has to answer.
##
## A row that migrates cleanly is not a failure - it is work the editor can do on one click, and a
## branch is allowed to land with it. A row that ASKS is different: the vocabulary has nowhere to
## send it, or the newer verb keeps state of its own, or the rewrite could not prove itself. Nobody
## can answer that but a person, and a branch that lands with one has moved the decision onto
## whoever opens the file next.
##
## Pure over the report's own rows - the frozen public shape - so this says exactly what
## `EventSheets.migration_report()` says and cannot drift from it.
static func migration_failures(rows: Array[Dictionary]) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for row: Dictionary in rows:
		if not bool(row.get("asks", false)):
			continue
		var sheet: String = str(row.get("sheet", ""))
		var before: String = str(row.get("before", ""))
		found.append(_failure(CHECK_MIGRATION_ASKS, sheet, line_of(sheet, before),
			"Event %d writes %s on a verb the installed vocabulary has moved on from, and the rewrite is one nothing can make for you." % [
				int(row.get("row", 0)), _quoted(before)],
			"Open the sheet and press Migrate… on the head band's counting line: this row is one of the ones it leaves alone, with the reason beside it."))
	return found


## The 1-based line of `path` whose code is `text`, or 0 when the file has no such line. The address
## a person can act on for a `.gd` sheet, whose rows ARE lines of the file; a `.tres` sheet stores
## its rows instead, so there is no line to find and the event number is the whole address.
static func line_of(path: String, text: String) -> int:
	var wanted: String = text.strip_edges()
	if wanted.is_empty() or path.get_extension().to_lower() != "gd":
		return 0
	var line_number: int = 0
	for line: String in FileAccess.get_file_as_string(path).split("\n"):
		line_number += 1
		if line.strip_edges() == wanted:
			return line_number
	return 0


# ── the report ────────────────────────────────────────────────────────────────────


## One failure as the line a terminal prints, which is the line a hook shows and a CI annotation
## quotes: `res://player.gd:41 [round-trip] <what> <where>`. The file and line lead, in the shape
## every compiler and linter prints them in, so an editor that turns such a line into a link does.
static func failure_line(failure: Dictionary) -> String:
	var where: String = str(failure.get("path", ""))
	if int(failure.get("line", 0)) > 0:
		where += ":%d" % int(failure.get("line", 0))
	return "%s [%s] %s %s" % [where, str(failure.get("check", "")),
		str(failure.get("message", "")), str(failure.get("where", ""))]


## The verdict line, and it says the same thing in both directions: what was read, and what was
## found. A gate whose green run prints nothing leaves the reader guessing whether it ran.
## The migration check's own corpus is named whenever it is smaller than the run's, because those two
## numbers are the difference between "this gate read your project" and "this gate read a sample of
## it", and only one of them is worth trusting a branch to. A run asked to read the `.gd` half whole
## ends with the sentence that says so, in the migration section's own words - because a mode you
## could only tell apart by counting the findings is a mode nobody can trust the verdict of.
static func verdict(result: Dictionary) -> String:
	var failures: Array = result.get("failures", []) as Array
	var files: int = int(result.get("files", 0))
	var migration: int = int(result.get("migration_files", files))
	var sampled: String = "" if migration >= files else " (migration read %d of them)" % migration
	var whole: String = str(result.get("migration_note", ""))
	if failures.is_empty():
		return "verify: %d file(s) read%s, nothing to answer.%s" % [files, sampled, whole]
	return "verify: %d file(s) read%s, %d failure(s).%s" % [files, sampled, failures.size(), whole]


# ── the parts nobody outside calls ────────────────────────────────────────────────


## The migration report's rows for this run: the project's own when nothing was asked for, and the
## asked-for files alone when a hook named them.
##
## The whole-project run asks the same two calls `EventSheets.migration_report()` is, so this gate
## and anything else reading that report can never disagree about what the project holds - and asking
## them here rather than through the seam is what puts the CORPUS in reach, which is the number the
## verdict has to print beside the other one. The report reads every stored sheet but only SAMPLES
## the `.gd` ones, so it is routinely far smaller than the list the other three checks read, and
## "812 file(s) read, nothing to answer" printed over a migration check that opened two dozen of them
## is a gate somebody would trust for the wrong reason.
##
## A hook that named three staged files is answered about those three instead: the sampling is right
## for a project-wide audit and wrong for a hook, whose three files may not be in the sample.
##
## A WHOLE READ NAMES ITSELF, in the migration section's own words rather than in a second wording of
## the same fact - the two halves of the corpus are listed here so that sentence can be asked for
## without walking the project a third time to build it.
static func _migration_rows(requested: PackedStringArray, paths: PackedStringArray,
		read_every_script: bool = false) -> Dictionary:
	if not requested.is_empty():
		return {"rows": EventSheetMigrationDoctor.rows(paths), "files": paths.size(), "note": ""}
	var sheets: PackedStringArray = EventSheetTemplates.non_template_sheets(
		EventSheetProjectFind.list_project_sheets())
	var scripts: PackedStringArray = EventSheetProjectDoctor.all_project_scripts()
	var corpus_paths: PackedStringArray = EventSheetMigrationDoctor.corpus(sheets, scripts,
		read_every_script)
	return {"rows": EventSheetMigrationDoctor.rows(corpus_paths), "files": corpus_paths.size(),
		"note": EventSheetMigrationDoctor.sample_note(sheets, scripts, true) if read_every_script else ""}


## A prefix is written the way the path is, so `tests/fixtures/` and `res://tests/fixtures/` are the
## same instruction: somebody naming a folder on a command line should not have to know which of the
## two spellings the walk happens to use.
# What one requested path names: the files under it when it is a folder, and itself otherwise. A
# path that is neither is itself too, and drops out of the corpus a line later for not existing.
static func _named_files(path: String) -> PackedStringArray:
	if DirAccess.dir_exists_absolute(path):
		return files_under(path)
	return PackedStringArray([path])


static func _is_skipped(path: String, skipped: PackedStringArray) -> bool:
	for prefix: String in skipped:
		var written: String = in_project(prefix)
		if not written.is_empty() and path.begins_with(written):
			return true
	return false


static func _quoted(line: String) -> String:
	var text: String = line.strip_edges()
	if text.length() > QUOTED_LINE_WIDTH:
		text = text.substr(0, QUOTED_LINE_WIDTH) + "…"
	return "\"%s\"" % text


static func _failure(check_id: String, path: String, line: int, message: String,
		where: String) -> Dictionary:
	return {"check": check_id, "path": path, "line": line, "message": message, "where": where}
