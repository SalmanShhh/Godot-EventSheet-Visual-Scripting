# Godot EventSheets - the VERBATIM LEDGER: the shape of a stays-code line, and the page built on it.
#
# Five things are pinned here, and each one is pinned as VALUES rather than as counts or tolerances:
#
#   1. THE SHAPE ITSELF, on a table of statements and the shapes they blank to. Same code, same
#      shape - including across spacing, because a project that writes `x = 1` and one that writes
#      `x=1` must land in one group rather than two.
#   2. THE NAME ATOM IS THE LIFTER'S OWN. The scanner spells "what is an identifier" as a character
#      test and EventForgeLiftGrammar.IDENTIFIER spells it as a regex; a sample table holds the two
#      against each other, so the day one widens the other cannot quietly stay behind.
#   3. THE CENSUS, over a hand-built list: what is ranked, how ties break, what falls into the
#      one-off tail, and what is counted as a note rather than shaped.
#   4. THE CORPUS'S TWO PINNED CODE LINES, by shape. tests/corpus_test.gd already pins that
#      door_state_machine.gd and pickup_juice.gd have exactly one stays-code line each; this says
#      what those lines LOOK like, which is the fact the ledger is built on.
#   5. THE INSIDE OF A TEXT BLOCK IS NOT A STATEMENT. A multi-line literal's continuation lines are
#      prose, and `shape_of` reads one line at a time and cannot know that - so the state is carried
#      across the walk, and a table of lines says which ones the walk considers open.
#   6. THE DOCTOR PAGE, over a staged pair of scripts: the head sentence carrying both numbers apart,
#      the grouped shape with its lines as doors, and the one-off tail counted rather than expanded -
#      and, on a folder bigger than the cap, the sentence that says the page is a sample.
#
# SERIAL-CI HYGIENE. Reading files warms the lift-table family cache for the whole process, and CI
# runs the suite serially in one process, so a later test would inherit it. This drops it on the way
# out, and the staged scripts live in user:// and are deleted - nothing is left in the repository.
@tool
class_name ReadingShapesTest
extends RefCounted

## Where the staged pair is written. user://, so a run leaves nothing under res://.
const STAGED_DIR: String = "user://reading_shapes_staged"
const STAGED_A: String = STAGED_DIR + "/coin.gd"
const STAGED_B: String = STAGED_DIR + "/spark.gd"

## Where the capped-walk probe writes its folder of thirteen. Its own directory, removed when the
## check is done, so the staged pair above is never one of the thirteen.
const CAPPED_DIR: String = "user://reading_shapes_capped"

## A multi-line literal, which is where the ledger used to read prose as code: the opening line IS a
## statement, and the three under it are the inside of a text block.
const TEXT_BLOCK: String = """extends Node


func brief() -> void:
	$Screen.text = \"\"\"CHEF PLANNER
task: %s
step: %s
\"\"\"
"""

## Two scripts that share one statement and disagree about everything else - the smallest project
## that has both a repeated shape and a one-off.
const SOURCE_A: String = """extends Area2D

var taken: bool = false


func collect() -> void:
	var pop: Tween = create_tween()
	pop.tween_property(self, "modulate:a", 0.0, 0.25)
	pop.chain().tween_callback(queue_free)


func fizzle() -> void:
	var out: Tween = create_tween()
	out.chain().tween_callback(queue_free)
"""

const SOURCE_B: String = """extends Node2D

enum Phase {IDLE, RISING, FALLING}

var phase: int = Phase.IDLE


func finish() -> void:
	var done: Tween = create_tween()
	done.chain().tween_callback(queue_free)
"""

## The corpus files whose single stays-code line this gate says the shape of. The corpus gate pins
## that there is exactly one; this pins what it is.
const CORPUS_SHAPES: Dictionary = {
	"res://tests/corpus/door_state_machine.gd": "enum name{name,name,name,name}",
	"res://tests/corpus/pickup_juice.gd": "name.chain().tween_callback(name)"
}


static func run() -> bool:
	var ok: bool = _test_the_shape()
	ok = _test_the_name_atom_is_the_lifters() and ok
	ok = _test_the_census() and ok
	ok = _test_the_corpus_code_lines() and ok
	ok = _test_a_text_block_is_not_a_statement() and ok
	ok = _test_the_doctor_page() and ok
	ok = _test_the_capped_walk() and ok
	_tidy_up()
	return ok


## The blanking itself, statement by statement. Every row here is a claim about what the ledger
## groups together, so a change to the scanner shows up as a diff in this table rather than as a
## quietly re-ordered Doctor page.
static func _test_the_shape() -> bool:
	var table: Dictionary = {
		# The corpus's own two, which are the reason this exists.
		"	pop.chain().tween_callback(queue_free)": "name.chain().tween_callback(name)",
		"enum State {CLOSED, OPENING, OPEN, LOCKED}": "enum name{name,name,name,name}",
		# THE VERB AND THE MEMBER STAY, because they are what a curated table is keyed on: two calls
		# with different verbs are two tables, not one bucket of "a call with one argument".
		"	queue_free()": "queue_free()",
		"	hide()": "hide()",
		"	add_child(bullet)": "add_child(name)",
		"	remove_child(bullet)": "remove_child(name)",
		"	health.x += MAX_ARMOUR": "name.x+=name",
		# The receiver in front of the dot is the half that varies, so it still goes: one table entry
		# covers `torch.energy` and `lamp.energy` alike.
		"	torch.energy = 1.2": "name.energy=number",
		"	lamp.energy = 0.4": "name.energy=number",
		# Keywords stay, names go: `if` and `while` are different kinds of line.
		"	if not is_on_floor():": "if not is_on_floor():",
		"	while lives > 0:": "while name>number:",
		# Spacing is not part of a shape - these two are the same statement.
		"	velocity.y += JUMP_VELOCITY": "name.y+=name",
		"velocity.y+=JUMP_VELOCITY": "name.y+=name",
		# Literals of every kind blank to what kind they are, never to their value.
		"	speed = 300.0": "name=number",
		"	speed = 3e-4": "name=number",
		"	mask = 0xFF": "name=number",
		"	label.text = \"score\"": "name.text=text",
		"	rpc(&\"hit\", 10)": "rpc(&text,number)",
		# A node path is one thing, however it is written, and `%` is only a node in unary position.
		"	$Hero/FlashBehavior.flash(0.4)": "node.flash(number)",
		"	%Player.hurt()": "node.hurt()",
		"	var i: int = index % count": "var name:name=name%name",
		"	$\"Big Door\".open()": "node.open()",
		# An annotation names which kind of line this is, exactly as a keyword does.
		"@export var value: int = 1": "@export var name:name=number",
		# A trailing comment is not part of the statement; a `#` inside a string is.
		"	queue_free()  # bye": "queue_free()",
		"	print(\"# not a comment\")": "print(text)",
		# A NAME THE ASCII ATOM CANNOT SPELL IS STILL BLANKED, never printed: a shape whose whole job
		# is to carry none of the author's words must not carry their bytes either. The run is blanked
		# on its own rather than merged into the name beside it, so the atom stays exactly the
		# lifter's and `über` is a name to neither of them.
		"	über = 2": "name name=number",
		"	日本語()": "name()",
		# TWO CLASSES, ONE VERB, ONE BUCKET. The receiver is blanked and the verb is kept, so these
		# two are the same shape - and a curated table is keyed on the class as well as the verb, so
		# that bucket is two tables rather than one. Pinned because it is what the ledger's counts
		# mean: lines worth writing words for, never entries one table would gain.
		"	sprite.play(\"run\")": "name.play(text)",
		"	music.play(\"theme\")": "name.play(text)",
		# Nothing to shape.
		"	# @group:juice": "",
		"		": ""
	}
	var ok: bool = true
	for statement: String in table:
		ok = _check("shape of %s" % statement.strip_edges(),
			EventSheetReadingShapes.shape_of(statement), str(table[statement])) and ok
	return ok


## The scanner and the lifter's grammar agree about what a name is, on words picked to sit either
## side of the line. Keywords are left out on purpose: they are names to the grammar and words to the
## scanner, which is the one deliberate difference between them.
##
## `über` is in the table for the OTHER half of the same rule: it is not a name to either of them,
## and the pin below proves the scanner does not quietly widen its atom to take it. What it must do
## instead - blank the run rather than print it - is pinned in the shape table above.
static func _test_the_name_atom_is_the_lifters() -> bool:
	var identifier: RegEx = RegEx.create_from_string("^%s$" % EventForgeLiftGrammar.IDENTIFIER)
	var samples: PackedStringArray = ["player", "_private", "x1", "Vector2", "__group_juice_active",
		"1x", "9", "", "has-dash", "a b", "über"]
	var ok: bool = true
	for sample: String in samples:
		var by_grammar: bool = identifier.search(sample) != null
		var by_scanner: bool = EventSheetReadingShapes.shape_of(sample) == EventSheetReadingShapes.BLANK_NAME
		ok = _check("\"%s\" is a name to both or to neither" % sample, by_scanner, by_grammar) and ok
	return ok


## The ranking, the tie-break, the tail and the notes, over a list built by hand so nothing here
## depends on a file, a walk or a compiler.
static func _test_the_census() -> bool:
	var lines: Array[Dictionary] = []
	# Three lines that share a shape (one verb, three receivers), two that share another, one said
	# once, and a note. The three receivers differ on purpose: the receiver is the half that varies,
	# so it is blanked, while the verb is what the shape is grouped BY.
	for entry: Array in [["a.gd", 1, "a.hide()"], ["a.gd", 2, "c.hide()"], ["b.gd", 3, "e.hide()"],
			["b.gd", 4, "x = 1"], ["b.gd", 5, "y = 2"], ["c.gd", 6, "solo(1, 2, 3)"],
			["c.gd", 7, "# a note"]]:
		lines.append({"path": str(entry[0]), "number": int(entry[1]), "text": str(entry[2]),
			"shape": EventSheetReadingShapes.shape_of(str(entry[2]))})
	var census: Dictionary = EventSheetReadingShapes.census(lines)
	var shapes: Array = census.get("shapes", []) as Array
	var ok: bool = _check("every line handed in is counted", int(census.get("lines", 0)), 7)
	ok = _check("the note holds no statement to shape", int(census.get("notes", 0)), 1) and ok
	ok = _check("two shapes are said more than once", shapes.size(), 2) and ok
	ok = _check("the commonest shape is first",
		str((shapes[0] as Dictionary).get("shape", "")), "name.hide()") and ok
	ok = _check("and it carries all three of its lines",
		int((shapes[0] as Dictionary).get("count", 0)), 3) and ok
	ok = _check("the second shape is the pair",
		str((shapes[1] as Dictionary).get("shape", "")), "name=number") and ok
	ok = _check("the line said once falls into the tail",
		(census.get("one_offs", []) as Array).size(), 1) and ok
	# The tie-break is the shape's own text, never the order the lines arrived in: the same lines
	# shuffled must rank the same way on every machine.
	var reversed_lines: Array[Dictionary] = []
	for index: int in range(lines.size() - 1, -1, -1):
		reversed_lines.append(lines[index])
	var reversed_census: Dictionary = EventSheetReadingShapes.census(reversed_lines)
	var reversed_shapes: PackedStringArray = PackedStringArray()
	for entry: Variant in reversed_census.get("shapes", []) as Array:
		reversed_shapes.append(str((entry as Dictionary).get("shape", "")))
	ok = _check("the ranking does not depend on the order the lines arrived in", reversed_shapes,
		PackedStringArray(["name.hide()", "name=number"])) and ok
	return ok


## The corpus's two pinned code lines, by shape. Read through the one shared reader, so this and the
## corpus gate can never disagree about which lines they are.
static func _test_the_corpus_code_lines() -> bool:
	var ok: bool = true
	for path: String in CORPUS_SHAPES:
		var reading: Dictionary = EventSheetLiftReading.read(FileAccess.get_file_as_string(path), path)
		var found: PackedStringArray = PackedStringArray()
		for line: Dictionary in EventSheetReadingShapes.stays_code_lines(reading, path):
			found.append(str(line.get("shape", "")))
		ok = _check("%s stays code in one shape" % path.get_file(), found,
			PackedStringArray([str(CORPUS_SHAPES[path])])) and ok
	return ok


## The page itself over a staged pair: the head that says both numbers apart, the grouped shape with
## its lines as doors, and the tail counted rather than expanded.
static func _test_the_doctor_page() -> bool:
	DirAccess.make_dir_recursive_absolute(STAGED_DIR)
	_write(STAGED_A, SOURCE_A)
	_write(STAGED_B, SOURCE_B)
	var findings: Array[Dictionary] = EventSheetReadingDoctor.report(
		PackedStringArray([STAGED_A, STAGED_B]))
	var checks: PackedStringArray = PackedStringArray()
	for finding: Dictionary in findings:
		checks.append(str(finding.get("check", "")))
	var ok: bool = _check("the page is a head, a shape, its three doors and the tail", checks,
		PackedStringArray([EventSheetReadingDoctor.CHECK_ID, EventSheetReadingDoctor.CHECK_SHAPE,
			EventSheetReadingDoctor.CHECK_LINE, EventSheetReadingDoctor.CHECK_LINE,
			EventSheetReadingDoctor.CHECK_LINE, EventSheetReadingDoctor.CHECK_TAIL]))
	# Nothing on this page is an accusation. A project made of code is a working project.
	var severities: Dictionary = {}
	for finding: Dictionary in findings:
		severities[str(finding.get("severity", ""))] = true
	ok = _check("every line of the page is a note", severities.keys(), ["info"]) and ok
	ok = _check("the head says the drawing number and the naming number apart",
		str(findings[0].get("message", "")),
		"100% of what was read draws as rows - that is the drawing question. The naming question is below it: 4 line(s) stay honest code, because no vocabulary claims them yet. Both are true, and they are not the same number.") and ok
	ok = _check("the shape is named with its count", str(findings[1].get("message", "")),
		"3 line(s) are the same shape: name.chain().tween_callback(name)") and ok
	ok = _check("a door opens the file the line is in", str(findings[3].get("path", "")),
		STAGED_A) and ok
	ok = _check("the door quotes the line the way the file spells it",
		str(findings[3].get("message", "")), "line 14: out.chain().tween_callback(queue_free)") and ok
	# The front page sorts by check, file and message, which would drop the head sentence to the
	# bottom and scatter the shape's doors. The ledger hands the page its own order instead, and this
	# is the pin that says it survived: triaged, the page still reads head, shape, doors, tail.
	var triaged_checks: PackedStringArray = PackedStringArray()
	for finding: Dictionary in EventSheetDoctorInbox.triage(findings, PackedStringArray()):
		triaged_checks.append(str(finding.get("check", "")))
	ok = _check("the page keeps its ledger order once the inbox has sorted it", triaged_checks,
		checks) and ok
	ok = _check("the tail counts the one-off rather than listing it",
		str(findings[5].get("message", "")),
		"1 line(s) are shapes nothing else here repeats. Counted rather than listed: a line said once is nobody's table, and it is meant to stay code.") and ok
	return ok


## The inside of a multi-line literal is prose, not a statement. Pinned as the STATE the walk carries
## line by line, because that is the whole mechanism: `shape_of` sees one line and cannot know that
## the line above it opened a text block that has not closed. Without it a template's `task: %s` came
## out as "a name, then a unique-name node path" - a printf placeholder read as a scene path - and on
## a real project those lines outnumbered the statements around them.
static func _test_a_text_block_is_not_a_statement() -> bool:
	var ok: bool = true
	# [line, what was open before it, what it leaves open].
	for row: Array in [
		["\t$Screen.text = \"\"\"CHEF PLANNER", "", "\"\"\""],
		["task: %s", "\"\"\"", "\"\"\""],
		["\"\"\"", "\"\"\"", ""],
		["\tqueue_free()", "", ""],
		# A block opened and closed on one line leaves nothing open.
		["\tvar note: String = \"\"\"one line\"\"\"", "", ""],
		# A `#` outside a literal starts a comment, so a quote in it opens nothing.
		["\tqueue_free()  # \"\"\" not a block", "", ""],
		# A PLAINLY quoted literal can carry a real newline in GDScript, and the generated showcases
		# use it: a three-line HUD readout is one statement. So the plain quote is carried too, and
		# the prose under it is prose - this is the corpus's own case, not a hypothetical one.
		["	$Screen.text = \"CHEF PLANNER (HTN)", "", "\""],
		["task: %s", "\"", "\""],
		["steps left: %d\" % [$Chef/Planner.current_task()]", "\"", ""],
		# An escaped quote inside a continued literal closes nothing.
		["still open \\\" here", "\"", "\""],
		# Which leaves an unbalanced file with the rest of itself unshaped, rather than with prose
		# ranked as statements: the safe way round for something whose whole job is a ranking.
		["	var broken: String = \"unclosed", "", "\""],
	]:
		ok = _check("after \"%s\" the walk has %s open" % [str(row[0]).strip_edges(),
			"nothing" if str(row[2]).is_empty() else str(row[2])],
			EventSheetReadingShapes.open_string_after(str(row[0]), str(row[1])), str(row[2])) and ok
	# And the shape that follows from it: the opening line is a statement and is shaped; the prose
	# under it has no shape at all, so the census counts it as a note rather than ranking it.
	var reading: Dictionary = EventSheetLiftReading.read(TEXT_BLOCK, "user://reading_shapes_block.gd")
	var shapes: PackedStringArray = PackedStringArray()
	for line: Dictionary in EventSheetReadingShapes.stays_code_lines(reading, "block.gd"):
		shapes.append(str(line.get("shape", "")))
	return _check("the block's opening line is shaped and its prose is not",
		shapes, PackedStringArray(["node.text=text", "", "", ""])) and ok


## The capped walk, on a folder bigger than the cap. The branch exists because reading a script is
## cheap and not free, and its sentence has to be true: there is no cursor and nothing is remembered,
## so the same scripts are read every run and the page is a SAMPLE. A sentence inviting a reader to
## open the Doctor again for the rest would be a promise this cannot keep.
static func _test_the_capped_walk() -> bool:
	DirAccess.make_dir_recursive_absolute(CAPPED_DIR)
	var paths: PackedStringArray = PackedStringArray()
	for index: int in range(EventSheetReadingDoctor.SCRIPTS_READ_LIMIT + 1):
		var path: String = "%s/probe_%02d.gd" % [CAPPED_DIR, index]
		_write(path, SOURCE_B)
		paths.append(path)
	var first: Array[Dictionary] = EventSheetReadingDoctor.report(paths)
	var capped: String = ""
	for finding: Dictionary in first:
		if str(finding.get("subject", "")) == "capped":
			capped = str(finding.get("message", ""))
	var ok: bool = _check("the capped walk says what it read, in path order", capped,
		"Read the first 12 script(s) of 13, in path order. The ledger below is a sample of this"\
		+ " project, not the whole of it - the same scripts are read every time.")
	# The claim inside that sentence, made good: a second run reads the same twelve and says the same
	# thing, which is why it must not promise the rest.
	var second: PackedStringArray = PackedStringArray()
	for finding: Dictionary in EventSheetReadingDoctor.report(paths):
		second.append(str(finding.get("message", "")))
	var again: PackedStringArray = PackedStringArray()
	for finding: Dictionary in first:
		again.append(str(finding.get("message", "")))
	ok = _check("and a second run is the same page, not the next twelve", second, again) and ok
	for path: String in paths:
		DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(CAPPED_DIR)
	return ok


## Drops what this test warmed, and takes the staged scripts with it. CI runs the suite serially in
## one process: a family cache left standing here is a cache the next test inherits.
static func _tidy_up() -> void:
	DirAccess.remove_absolute(STAGED_A)
	DirAccess.remove_absolute(STAGED_B)
	DirAccess.remove_absolute(STAGED_DIR)
	EventSheetLiftReading.clear_cache()


static func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(text)
	file.close()


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		return true
	print("[FAIL] reading_shapes_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
