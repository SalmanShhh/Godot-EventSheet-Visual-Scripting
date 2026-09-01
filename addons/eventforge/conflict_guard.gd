# Godot EventSheets - the guard in front of a file a merge has not finished with.
#
# THE ONE SANCTIONED BANNER. Everything else this pass reports is a FINDING: it goes into the quiet
# amber row state, the selected row's help strip and the Doctor's inbox, and the sheet itself stays
# silent. A file holding merge markers is not a finding. It is a FILE-LEVEL BLOCKING STATE - the file
# is not GDScript, it has no single reading, and every operation the editor could offer over it is
# wrong. That is a state, and a state may say so at the head of the sheet.
#
# THE GUARD IS TEXTUAL AND TOTAL, and both words are load-bearing.
#
#   TEXTUAL, because a merge in trouble does not always leave a tidy region. Half of one is resolved
#   by hand and the closing `>>>>>>>` is left behind; a rebase writes `|||||||` and is interrupted;
#   an editor writes the markers with trailing whitespace. Reading only well-formed regions - two
#   sides between three markers - answers "no conflicts" for every one of those files, and the sheet
#   then lifts marker lines as code and offers to save over them. Any marker line anywhere is enough.
#
#   TOTAL, because a partial guard is not a guard. No lift, no save, no unlock, and no "open anyway".
#   The reader gets the file on screen read-only, with its marker lines named, and is pointed at the
#   place this is actually resolved.
#
# THE BYTES ARE THE POINT. A conflicted file opened and closed is a conflicted file, byte for byte -
# nothing here writes, and the read-only state is what keeps every path that could write off it.
#
# PURE + STATIC: no editor, no dialog, no display server, so every word below is pinned headless.
@tool
class_name EventSheetConflictGuard
extends RefCounted

## The four marker prefixes, borrowed from the reading layer rather than spelled twice - they are
## git's, not ours, and one list of them is the only way the guard and the resolution view can agree
## about what a marker is.
const MARKS: PackedStringArray = [
	EventSheetConflictRegions.OURS_MARK,
	EventSheetConflictRegions.BASE_MARK,
	EventSheetConflictRegions.SPLIT_MARK,
	EventSheetConflictRegions.THEIRS_MARK,
]

## How many marker lines the banner names before it stops counting them out. A file with forty of
## them is a file to take to the merge tool, not a list to read.
const NAMED_LINES: int = 6


## Every marker line in this text, in file order: {line, mark, text} with `line` 1-based and `text`
## the line itself with its trailing whitespace taken off.
##
## A marker is a line that STARTS with one of the four prefixes, which is the same rule git writes
## by. Leading whitespace disqualifies it on purpose: an indented `=======` is a row of equals signs
## inside a comment or a string, and blocking a file over one would be a guard nobody could get past.
static func marker_lines(source: String) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var line_number: int = 0
	for line: String in source.split("\n"):
		line_number += 1
		for mark: String in MARKS:
			if not line.begins_with(mark):
				continue
			found.append({"line": line_number, "mark": mark, "text": line.rstrip("\r \t")})
			break
	return found


## True when this text holds a marker line at all - the whole question the open path asks.
static func blocks(source: String) -> bool:
	for line: String in source.split("\n"):
		for mark: String in MARKS:
			if line.begins_with(mark):
				return true
	return false


## The same question of a file on disk. A file that cannot be read answers false: an unreadable file
## fails for its own reasons further along, and inventing a conflict for it would be a worse lie than
## the one it is already telling.
static func blocks_file(path: String) -> bool:
	return blocks(FileAccess.get_file_as_string(path))


## The marker lines as line numbers, which is what the banner and the tests both want out of a read.
static func marker_line_numbers(source: String) -> PackedInt32Array:
	var numbers: PackedInt32Array = PackedInt32Array()
	for entry: Dictionary in marker_lines(source):
		numbers.append(int(entry["line"]))
	return numbers


## "line 12" / "lines 12 and 18" / "lines 12, 18 and 24" / "lines 12, 18, 24 and 31 (and 9 more)".
## English rather than a bracketed list, because this is the sentence a person reads at the top of
## their screen when something has gone wrong and they want to know where.
static func lines_phrase(numbers: PackedInt32Array) -> String:
	if numbers.is_empty():
		return ""
	var shown: PackedStringArray = PackedStringArray()
	for index: int in mini(numbers.size(), NAMED_LINES):
		shown.append(str(numbers[index]))
	var tail: String = ""
	if numbers.size() > NAMED_LINES:
		tail = " (and %d more)" % (numbers.size() - NAMED_LINES)
	if shown.size() == 1:
		return "line %s%s" % [shown[0], tail]
	var last: String = shown[shown.size() - 1]
	shown.remove_at(shown.size() - 1)
	return "lines %s and %s%s" % [", ".join(shown), last, tail]


## The banner's sentence: what this file is, where the markers are, and where it gets resolved.
##
## IT NAMES THE MERGE TOOL rather than offering to be one. Picking a side is a decision about two
## people's work, made with the whole history in view, and the tool that already has that view is the
## one the reader ran the merge in. This editor's job here is to refuse to make things worse and to
## say clearly why it is refusing.
static func banner_text(file_name: String, numbers: PackedInt32Array) -> String:
	if numbers.is_empty():
		return ""
	return "%s still has merge conflict markers on %s. It is not GDScript until they are gone, so it is open read-only here: nothing is lifted into rows, and Save is off. Finish the merge in the tool you started it in, then open it again." % [
		file_name, lines_phrase(numbers)]


## Puts a freshly-read sheet into the blocked state, and is the ONLY place that state is entered:
## read-only, with the marker lines it is blocked over recorded on it. The open path calls this and
## so does the test, so "what a blocked sheet is" is one answer rather than two that drift.
##
## Returns the sheet, so the call reads as the transformation it is.
static func block(sheet: EventSheetResource, numbers: PackedInt32Array) -> EventSheetResource:
	if sheet == null or numbers.is_empty():
		return sheet
	sheet.read_only = true
	sheet.conflict_marker_lines = numbers
	return sheet


## The status line the save path answers with. Shorter than the banner and about the gesture rather
## than the file, because the reader has already read the banner and has just pressed Ctrl+S.
static func save_refusal(file_name: String) -> String:
	return "%s still has merge conflict markers in it - saving would write the sheet's reading of them back over the file. Resolve the merge first." % file_name


## What the Doctor says about such a file. The audit reads whole projects, so it leads with the count
## rather than with the lines: the reader is scanning a list, not looking at the file.
static func doctor_message(file_name: String, numbers: PackedInt32Array) -> String:
	if numbers.is_empty():
		return ""
	return "%s still holds %d merge conflict marker line(s) (%s). It will not parse, and it opens read-only until the merge is finished." % [
		file_name, numbers.size(), lines_phrase(numbers)]
