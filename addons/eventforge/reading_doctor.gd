# Godot EventSheets - the Doctor's READING page: the project's stays-code lines, grouped by shape.
#
# Every other Doctor section is about something being wrong. This one is not. A line that stays code
# is a line working perfectly, and a project made entirely of them is a working project - general
# purpose includes the right to just be code. What this page is for is the OTHER half of that
# promise: curation is the polish, not the ceiling, and somebody has to be able to see where the next
# curated table would pay. So the page is a ledger, every line of it a note, and the only thing it
# asks of a reader is that they look.
#
# THE TWO NUMBERS ARE SAID APART, and this is the trap the page exists around. The head number is the
# project's reads-as percentage - the DRAWING question, how much of the file the canvas shows as rows
# rather than as a wall of code - and on real whole files it sits at or near 100%, because a function
# body is drawn as a body and not as a block. The stays-code count underneath it is the NAMING
# question, and it is far less flattering. Both are true, they measure different things, and a page
# that printed only the first would publish a figure that is true and misleading at once.
#
# THE HEAD NUMBER COMES THROUGH THE ONE SHARED READER (EventSheetLiftReading, which is
# EventSheetReadingCoverage underneath), so this page, the head bar's chip on an opened file and the
# corpus pins in the suite can never quote three different percentages for the same bytes.
#
# A SHAPE IS ONE BUCKET, NOT ONE TABLE. The shape keeps the verb and blanks the receiver, while a
# curated table is keyed on the class AND the verb - so `node.play(text)` gathers an
# AnimatedSprite2D's play beside an AudioStreamPlayer's, which are two tables rather than one. Every
# count on this page is therefore a count of LINES: where writing words would pay most, not how many
# entries one table would gain. The page never says otherwise, and a reader taking a count for an
# entry count would be taking the wrong number.
#
# THE PAGE OBEYS THE BAND SCALE LAW twice over. The commonest shapes are named and the rest are
# counted; each named shape opens a few of its own lines and counts the rest. And the tail is its own
# entry: the lines whose shape nothing else in the project repeats are COUNTED, never expanded - a
# one-off is nobody's table, and listing two hundred of them would bury the eleven that matter.
#
# THE WALK IS CAPPED, and says so. Reading a script means importing it, compiling it back and
# attributing every line, which is cheap per script and not free; a project of four hundred scripts
# would otherwise pay for all of them on every audit, which is how a section becomes one nobody runs.
# The first few in path order are read and the rest are counted.
#
# THE CAP IS A SAMPLE, NOT A QUEUE, and the sentence says that too. There is no cursor and nothing is
# remembered between runs, so the SAME scripts are read every time - re-opening the Doctor cannot
# reach the rest, and a sentence inviting a reader to try would be a promise this cannot keep. What it
# says instead is what is true: these are the first few in path order, and the ledger is about them.
@tool
class_name EventSheetReadingDoctor
extends RefCounted

## The id the section is registered under, and the ids its lines are filed as. Frozen alongside the
## wording, because the tests address a finding by its check id.
const CHECK_ID := "reading"
const CHECK_SHAPE := "reading-shape"
const CHECK_LINE := "reading-line"
const CHECK_TAIL := "reading-tail"

## How many scripts one audit reads for this section. A ceiling, not a target.
const SCRIPTS_READ_LIMIT: int = 12

## How many shapes the page names before it counts the rest - the band scale law.
const SHAPES_LISTED: int = 6

## How many of its own lines one shape opens before the rest are counted. The point of the lines is
## to show what the shape really is, and three of them do that.
const LINES_PER_SHAPE: int = 3


## Registers the section, replacing any previous registration - so a plugin reload, a second Doctor
## run and a test that registers it by hand all leave exactly one.
static func ensure_registered() -> void:
	EventSheets.register_doctor_check(CHECK_ID, Callable(EventSheetReadingDoctor, "check"))


## The section itself, with the contract every registered check has: append findings, never write
## inside res://. `sheet_paths` is deliberately unused - it finds only `.tres` sheets while `.gd` is
## the default sheet format, and this page is about hand-written GDScript above all.
static func check(_sheet_paths: PackedStringArray, findings: Array[Dictionary]) -> void:
	findings.append_array(report(EventSheets.project_scripts()))


## The whole page for a list of scripts, as findings. Pure over the paths, so a test can hand it a
## folder of fixtures and pin every number and every word.
static func report(script_paths: PackedStringArray) -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	_place = 0
	var sorted: PackedStringArray = script_paths.duplicate()
	sorted.sort()
	var lines: Array[Dictionary] = []
	var read_lines: int = 0
	var total_lines: int = 0
	var read: int = 0
	for script_path: String in sorted:
		if read >= SCRIPTS_READ_LIMIT:
			break
		var source: String = EventSheetProjectDoctor.source_of(script_path)
		if source.strip_edges().is_empty():
			continue
		read += 1
		var reading: Dictionary = EventSheetLiftReading.read(source, script_path)
		var coverage: Dictionary = reading.get("coverage", {}) as Dictionary
		read_lines += int(coverage.get("read_lines", 0))
		total_lines += int(coverage.get("total_lines", 0))
		lines.append_array(EventSheetReadingShapes.stays_code_lines(reading, script_path))
	if read == 0:
		return findings
	var census: Dictionary = EventSheetReadingShapes.census(lines)
	findings.append(_note("", _head_line(read_lines, total_lines, int(census.get("lines", 0))),
		CHECK_ID, "head"))
	if read < sorted.size():
		findings.append(_note("", EventSheetL10n.translate(
			"Read the first %d script(s) of %d, in path order. The ledger below is a sample of this project, not the whole of it - the same scripts are read every time.") % [
			read, sorted.size()], CHECK_ID, "capped"))
	findings.append_array(_shape_lines(census))
	findings.append_array(_tail_lines(census))
	return findings


## The head sentence: both numbers, labelled apart, in the order a reader needs them. The percentage
## first because it is the one every other surface already shows, then the count the page is about.
static func _head_line(read_lines: int, total_lines: int, stays_code: int) -> String:
	var percent: int = 100
	if total_lines > 0:
		percent = int(floor(100.0 * float(read_lines) / float(total_lines)))
	if stays_code <= 0:
		return EventSheetL10n.translate(
			"%d%% of what was read draws as rows, and every line of it has a name on it. Nothing here stays code.") % percent
	return EventSheetL10n.translate(
		"%d%% of what was read draws as rows - that is the drawing question. The naming question is below it: %d line(s) stay honest code, because no vocabulary claims them yet. Both are true, and they are not the same number.") % [
		percent, stays_code]


## One finding per named shape, each followed by a few of its own lines as doors. A door carries the
## file it is in, so the page opens where the line is rather than describing where it is.
static func _shape_lines(census: Dictionary) -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	var shapes: Array = census.get("shapes", []) as Array
	var listed_lines: int = 0
	var all_lines: int = 0
	for entry: Variant in shapes:
		all_lines += int((entry as Dictionary).get("count", 0))
	for index: int in range(shapes.size()):
		var entry: Dictionary = shapes[index] as Dictionary
		var held: Array = entry.get("lines", []) as Array
		if index >= SHAPES_LISTED:
			findings.append(_note("", EventSheetL10n.translate(
				"%d more shape(s) are said more than once here, over %d line(s). The ledger names the commonest and counts the rest.") % [
				shapes.size() - SHAPES_LISTED, all_lines - listed_lines], CHECK_TAIL, "more-shapes"))
			break
		listed_lines += held.size()
		var first: Dictionary = held[0] as Dictionary
		findings.append(_note(str(first.get("path", "")), EventSheetL10n.translate(
			"%d line(s) are the same shape: %s") % [held.size(), str(entry.get("shape", ""))],
			CHECK_SHAPE, str(entry.get("shape", ""))))
		for line_index: int in range(mini(LINES_PER_SHAPE, held.size())):
			var line: Dictionary = held[line_index] as Dictionary
			findings.append(_note(str(line.get("path", "")), EventSheetL10n.translate("line %d: %s") % [
				int(line.get("number", 0)), str(line.get("text", "")).strip_edges()],
				CHECK_LINE, "%s:%d" % [str(line.get("path", "")), int(line.get("number", 0))]))
		if held.size() > LINES_PER_SHAPE:
			findings.append(_note(str(first.get("path", "")), EventSheetL10n.translate(
				"... and %d more line(s) of the same shape.") % (held.size() - LINES_PER_SHAPE),
				CHECK_LINE, "%s+" % str(entry.get("shape", ""))))
	return findings


## The honest tail: what nothing repeats, and what holds no statement at all. Counted, never
## expanded - a one-off is nobody's table, and a note inside a run of code is not a shape.
static func _tail_lines(census: Dictionary) -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	var one_offs: int = (census.get("one_offs", []) as Array).size()
	if one_offs > 0:
		findings.append(_note("", EventSheetL10n.translate(
			"%d line(s) are shapes nothing else here repeats. Counted rather than listed: a line said once is nobody's table, and it is meant to stay code.") % one_offs,
			CHECK_TAIL, "one-offs"))
	var notes: int = int(census.get("notes", 0))
	if notes > 0:
		findings.append(_note("", EventSheetL10n.translate(
			"%d line(s) inside those runs hold no statement to shape - a note, or the inside of a text block.") % notes,
			CHECK_TAIL, "notes"))
	return findings


## One finding. Every line of this section is a note: nothing here is wrong, and a project that
## ignores all of it is a working project.
##
## The `order` field is what keeps the ledger a ledger. The front page sorts findings by check, file
## and message, which would put the head sentence at the bottom and scatter a shape's own doors
## across the page; a ledger read in that order is not a ledger. So every line of this section
## carries the place it belongs in, counted up as the page is written. The key begins with the check
## id the section is registered under, so the whole page still sorts as one block among the others.
static func _note(path: String, message: String, check_id: String, subject: String) -> Dictionary:
	_place += 1
	return {"severity": "info", "check": check_id, "path": path, "message": message,
		"subject": subject, "order": "%s|%04d" % [CHECK_ID, _place]}


## Where the next line of the page goes. Reset at the top of every report, so two reports of the same
## project are the same page rather than the second one being numbered off the end of the first.
static var _place: int = 0
