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
#   5. THE DOCTOR PAGE, over a staged pair of scripts: the head sentence carrying both numbers apart,
#      the grouped shape with its lines as doors, and the one-off tail counted rather than expanded.
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
	"res://tests/corpus/pickup_juice.gd": "name.name().name(name)"
}


static func run() -> bool:
	var ok: bool = _test_the_shape()
	ok = _test_the_name_atom_is_the_lifters() and ok
	ok = _test_the_census() and ok
	ok = _test_the_corpus_code_lines() and ok
	ok = _test_the_doctor_page() and ok
	_tidy_up()
	return ok


## The blanking itself, statement by statement. Every row here is a claim about what the ledger
## groups together, so a change to the scanner shows up as a diff in this table rather than as a
## quietly re-ordered Doctor page.
static func _test_the_shape() -> bool:
	var table: Dictionary = {
		# The corpus's own two, which are the reason this exists.
		"	pop.chain().tween_callback(queue_free)": "name.name().name(name)",
		"enum State {CLOSED, OPENING, OPEN, LOCKED}": "enum name{name,name,name,name}",
		# Keywords stay, names go: `if` and `while` are different kinds of line.
		"	if not is_on_floor():": "if not name():",
		"	while lives > 0:": "while name>number:",
		# Spacing is not part of a shape - these two are the same statement.
		"	velocity.y += JUMP_VELOCITY": "name.name+=name",
		"velocity.y+=JUMP_VELOCITY": "name.name+=name",
		# Literals of every kind blank to what kind they are, never to their value.
		"	speed = 300.0": "name=number",
		"	speed = 3e-4": "name=number",
		"	mask = 0xFF": "name=number",
		"	label.text = \"score\"": "name.name=text",
		"	rpc(&\"hit\", 10)": "name(&text,number)",
		# A node path is one thing, however it is written, and `%` is only a node in unary position.
		"	$Hero/FlashBehavior.flash(0.4)": "node.name(number)",
		"	%Player.hurt()": "node.name()",
		"	var i: int = index % count": "var name:name=name%name",
		"	$\"Big Door\".open()": "node.name()",
		# An annotation names which kind of line this is, exactly as a keyword does.
		"@export var value: int = 1": "@export var name:name=number",
		# A trailing comment is not part of the statement; a `#` inside a string is.
		"	queue_free()  # bye": "name()",
		"	print(\"# not a comment\")": "name(text)",
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
	for entry: Array in [["a.gd", 1, "a.b()"], ["a.gd", 2, "c.d()"], ["b.gd", 3, "e.f()"],
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
		str((shapes[0] as Dictionary).get("shape", "")), "name.name()") and ok
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
		PackedStringArray(["name.name()", "name=number"])) and ok
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
		"3 line(s) are the same shape: name.name().name(name)") and ok
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
