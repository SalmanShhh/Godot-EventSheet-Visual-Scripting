# Godot EventSheets - what row a line became, and what claims it, pinned as the ANSWERS.
#
# The provenance reader (EventSheetLiftProvenance) answers two questions about one line, and this
# pins both of them.
#
# THE CLAIM is what row the editor actually turns the line into, asked of the row builder itself:
# reopen, re-emit, look the line up in the compiler's source map. It is the question the whole tool
# exists for, and it is the one a per-line walk cannot answer, because the importer reads a file
# STRUCTURALLY - a class-level member is a variable row and never a statement, however confidently a
# statement layer would have read it. The second buffer here is exactly that case.
#
# THE PREVIEW is which reading layer WOULD have claimed the line, walked in the importer's own order.
# A count of how many answered would pass on any two layers swapping places, so nothing here counts:
# every pin is the printed line, naming the layer, the file it names and the sentence it says. Four
# lines of one buffer, chosen because each lands on a different layer of the stack.
#
#   a curated table entry  `rpc(&"take_damage", 10)`   the multiplayer family's own spelling
#   an entry BY EXAMPLE    `event.is_action_pressed`   the input-event family, derived from a marked
#                                                      example rather than from a written pattern
#   a derived reading      `beam.set_process(false)`   nothing curated names it, and the receiver's
#                                                      class is known from the @onready declaration
#   verbatim               `match beam.energy:`        a match head is one line of a block that only
#                                                      lifts whole, so no single-line layer claims it
#
# THE FOURTH IS THE LOAD-BEARING ONE. A reader that answered something for every line would be
# useless: the whole point of the stack is that its bottom is honest code, and the sentence saying so
# is pinned here word for word.
@tool
class_name LiftProvenanceTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const READING := preload("res://tools/reading_lines.gd")

## One buffer, four lines, four layers. Written out rather than loaded from a fixture so the line
## numbers the pins name are visible beside the lines they name.
const SOURCE: String = """extends Node2D

@onready var beam: Light2D = $Beam


func _ready() -> void:
	beam.set_process(false)
	rpc(&"take_damage", 10)
	match beam.energy:
		1.0:
			pass


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"jump"):
		beam.set_process(true)
"""

const DERIVED_LINE: int = 7
const TABLE_LINE: int = 8
const VERBATIM_LINE: int = 9
const EXAMPLE_LINE: int = 15

## A second buffer for the STRUCTURAL question, because the first one has no structure worth asking
## about. Its one member declaration is the case that made the claim a separate question: asked as an
## isolated statement it reads as a typed local-variable assignment, and the file it is in turns it
## into a variable row that no statement layer ever sees.
const MEMBERS: String = """extends Node2D

var level_seconds: float = 0.0


func _process(delta: float) -> void:
	level_seconds += delta
"""

const MEMBER_LINE: int = 3

## A buffer whose three statements are ONE row: the layout-on-top run. It is here because a run is
## the one claim a per-line reader cannot make on its own, and because the entry that claims it is a
## table entry - so the layer it is reported under is the table, not the matcher that used to answer
## for it, and the answer says how much of the body it took.
const RUN: String = """extends Node


func open_pause_menu() -> void:
	var menu = load("res://pause_menu.tscn").instantiate()
	menu.name = "PauseMenu"
	get_tree().root.add_child(menu)
"""

const RUN_LINE: int = 5

## A third buffer that cannot round-trip, for the read-only proof: it ends without a last newline
## and the emitter always writes one, so re-emitting it can never reproduce it. The closing quotes
## sit against `pass` for that reason - a newline before them would make this file round-trip and
## the proof vacuous.
## A buffer whose first line is a file-level annotation: a row the canvas folds into the sheet's head
## rather than drawing a cell for. It is here because "no cell on the resting walk" used to be one
## sentence for three different situations, and the one it named was the one this line is NOT.
const HEADER_ANNOTATION: String = """## @ace_category("Probe")
extends Node


func _ready() -> void:
	pass
"""


const NO_LAST_NEWLINE: String = """extends Node


func _ready() -> void:
	pass"""


static func run() -> bool:
	var ok: bool = _test_the_row_the_line_became()
	ok = _test_the_claim_never_writes_to_the_file_it_asks_about() and ok
	ok = _test_the_three_known_lines() and ok
	ok = _test_a_run_of_statements() and ok
	ok = _test_the_by_example_layer_is_told_apart() and ok
	ok = _test_the_printed_shape() and ok
	ok = _test_which_builder_path_shaped_it() and ok
	ok = _test_a_line_that_is_not_one() and ok
	return ok


## The claim: the row the editor makes of the line, from the row builder rather than from a parallel
## walk. The member declaration is the pin that matters - the statement layers below it read it as a
## typed local-variable assignment, and the file makes it a variable row.
static func _test_the_row_the_line_became() -> bool:
	var member: EventSheetLiftProvenance.RowClaim = EventSheetLiftProvenance.row_claim(MEMBERS,
		MEMBER_LINE, "res://members.gd")
	var ok: bool = _check("a class-level member is a variable row, not a statement",
		member.detail, "LocalVariable  level_seconds")
	ok = _check("...and it is a NAMED claim rather than a guess", member.kind,
		EventSheetLiftProvenance.Row.NAMED) and ok
	# And the preview says what it WOULD have read as, which is exactly the wrong answer the claim
	# exists to replace: a statement layer sees a typed assignment on that line.
	ok = _check("...while the statement layers, asked the line alone, say something else entirely",
		_claims_of(MEMBERS, MEMBER_LINE, "res://members.gd").is_empty(), false) and ok
	return ok


## A READ-ONLY TOOL HAS TO BE READ-ONLY, and this is the one place it could stop being one.
## `SheetCompiler.compile` writes its output to the path it is given whenever that differs from what
## is already there, so a claim that re-emitted a file back over its own path would rewrite the file
## somebody asked it about - and would do it in exactly the case where the answer is "this does not
## reproduce itself". The claim compiles to the shared round-trip probe path under `user://`
## instead, which also makes "lossless" here mean what the public seam and the repository gate mean.
##
## The buffer below ends without a newline, which the emitter always writes, so it cannot round-trip:
## the destructive case and the refusing case are the same case.
static func _test_the_claim_never_writes_to_the_file_it_asks_about() -> bool:
	var path: String = "user://lift_provenance_read_only_probe.gd"
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return _check("the probe file could be written", false, true)
	file.store_string(NO_LAST_NEWLINE)
	file.close()
	var claim: EventSheetLiftProvenance.RowClaim = EventSheetLiftProvenance.row_claim(NO_LAST_NEWLINE,
		1, path)
	var ok: bool = _check("a file that does not reproduce itself is told so, not answered anyway",
		claim.kind, EventSheetLiftProvenance.Row.NOT_REPRODUCIBLE)
	ok = _check("...and the file it was asked about is exactly as it was",
		FileAccess.get_file_as_string(path), NO_LAST_NEWLINE) and ok
	ok = _check("...because the round trip is compiled to the shared probe path, never to res://",
		EventSheetLiftProvenance.PROBE_PATH, EventSheets.ROUND_TRIP_PROBE_PATH) and ok
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return ok


## The three lines the tool exists to tell apart. Each is pinned as the whole answer list, so a layer
## that starts answering where it did not - or stops answering where it did - fails here.
static func _test_the_three_known_lines() -> bool:
	var ok: bool = _check("a curated table entry claims its own spelling",
		_claims(TABLE_LINE), [
			"  1. table    multiplayer_lift.gd  send_everyone_with_arguments -> SendMessageToEveryone",
			"  5. call     Node2D.rpc (receiver: self)"
		])
	# The derived layer answers BELOW the index, and says which receiver resolution got it there -
	# `node`, because the @onready declaration at the top of the buffer types $Beam as a Light2D.
	ok = _check("a line nothing curated names reads through the index and the derived call layer",
		_claims(DERIVED_LINE), [
			"  4. index    Core::NodeSetProcessing",
			"  5. call     Light2D.set_process (receiver: node)"
		]) and ok
	ok = _check("and a line no layer claims says exactly that", _claims(VERBATIM_LINE),
		["  7. verbatim %s" % EventSheetLiftProvenance.UNCLAIMED]) and ok
	return ok


## A run of statements, which is the claim no per-line reading can make: the answer names the ENTRY
## that claimed it, the row it means and how many statements it took - at the TABLE layer, because a
## run written as a table entry is a table claim. It was reported as a matcher while the layout family
## matched by hand, and a family that goes back to matching by hand would say `match_run` here again.
##
## The two lines UNDER the opening one are pinned with it, because they are the honest half of this
## answer: the tool asks each line as an isolated statement, so the second and third statements of a
## claimed run still report what they would have read as on their own.
static func _test_a_run_of_statements() -> bool:
	var ok: bool = _check("a run claimed by a table entry is a table claim, over its statements",
		_claims_of(RUN, RUN_LINE, ""),
		["  1. table    layout_on_top_lift.gd  layout_on_top_written -> AddLayoutOnTop over 3 lines"])
	ok = _check("and a line inside the run is still asked on its own",
		_claims_of(RUN, RUN_LINE + 1, ""), ["  4. index    Core::SetNodeName"]) and ok
	return ok


## The one thing the provenance reader can say that the per-line reading beside it cannot: WHICH
## authoring route the entry that claimed the line came down. Both are lift-table entries and both
## match through the same engine; the input-event family's are derived from marked examples, and the
## entry itself carries that (EventForgeLiftTable.origin_of) rather than it being inferred.
static func _test_the_by_example_layer_is_told_apart() -> bool:
	var ok: bool = _check("an entry derived from an example says so, and names its family",
		_claims(EXAMPLE_LINE),
		["  2. example  input_event_lift.gd  event_action_pressed -> EventIsActionPressed"])
	# And the stamp itself, at the seam, so a family that stops carrying it fails here rather than by
	# quietly reading as a hand-written table.
	var derived: Dictionary = EventForgeLiftExample.entry("probe", "Probe",
		"shake_camera([[strength|argument: 3.0]])")
	ok = _check("...because the by-example builder stamps every entry it derives",
		EventForgeLiftTable.origin_of(derived), EventForgeLiftTable.ORIGIN_EXAMPLE) and ok
	ok = _check("...and an entry nobody stamped is one somebody wrote",
		EventForgeLiftTable.origin_of({"id": "written"}), EventForgeLiftTable.ORIGIN_HAND) and ok
	return ok


## The text the command line prints, byte for byte. It is a deliberately plain format - a header
## naming the file and the line, then the row the line became, then one line per layer that would
## have claimed it - and it is what somebody diffs two runs of, so it is pinned rather than described.
##
## The claim here is the EVENT, not the verb inside it: the compiler's source map is keyed on the row
## that OWNS an emission, and an event owns the lines of every condition and action under it. That is
## the grain the editor itself works at (it is what click-to-select selects), and the preview beneath
## says which verb of that event claimed this particular line.
static func _test_the_printed_shape() -> bool:
	return _check("the whole answer, as it prints",
		EventSheetLiftProvenance.text(SOURCE, TABLE_LINE, "res://buffer.gd"),
		"res://buffer.gd:8  rpc(&\"take_damage\", 10)\n"
		+ "  row      EventRow  OnReady\n"
		+ "  shaped   bespoke:_trigger_sentence, grammar:NodeSetProcessing, bespoke:_reading_sentence\n"
		+ "  read by:\n"
		+ "  1. table    multiplayer_lift.gd  send_everyone_with_arguments -> SendMessageToEveryone\n"
		+ "  5. call     Node2D.rpc (receiver: self)")


## THE THIRD QUESTION: which builder path shaped the reading the row draws. Same grain as the claim
## above - the source map is keyed on the row that owns an emission, so a line inside an event is
## answered by that event - and the same words the reading census counts in, so the door and the
## figure can never say different things about one row.
##
## The chrome of an event row (its badge column) is deliberately NOT in the answer while the row has a
## verb in it: it is the same on every event and would bury the part that differs. A row that is only
## chrome falls back to it, which is the variable declaration pinned last here.
static func _test_which_builder_path_shaped_it() -> bool:
	var ok: bool = _check("an event's cells name their paths in the order the canvas draws them",
		EventSheetLiftProvenance.shaped_by(SOURCE, TABLE_LINE, "res://buffer.gd"),
		"bespoke:_trigger_sentence, grammar:NodeSetProcessing, bespoke:_reading_sentence")
	ok = _check("a line of the same event gets the same answer - the grain is the row",
		EventSheetLiftProvenance.shaped_by(SOURCE, DERIVED_LINE, "res://buffer.gd"),
		"bespoke:_trigger_sentence, grammar:NodeSetProcessing, bespoke:_reading_sentence") and ok
	ok = _check("a row that is only chrome says so rather than naming nothing",
		EventSheetLiftProvenance.shaped_by(SOURCE, 3, "res://buffer.gd"), "structure") and ok
	ok = _check("a row the canvas draws no cell for says WHICH of the reasons it is",
		EventSheetLiftProvenance.shaped_by(HEADER_ANNOTATION, 1, "res://buffer.gd"),
		"%s - %s" % [EventSheetLiftProvenance.NO_READING, READING.NO_CELL_NOT_AN_EVENT]) and ok
	return ok


## The two lines that are not lines of code. Said in words, because a mistyped line number that came
## back as "nothing claims it" would read as a finding about the file.
static func _test_a_line_that_is_not_one() -> bool:
	var ok: bool = _check("a blank line is asked of nothing", _claims(2),
		["  7. verbatim %s" % EventSheetLiftProvenance.BLANK])
	ok = _check("and a line past the end of the buffer says so", _claims(9999),
		["  7. verbatim %s" % EventSheetLiftProvenance.OUT_OF_RANGE]) and ok
	return ok


## The answers for one line of the shared buffer, as the lines they print, so a pin compares the
## words a reader sees rather than a shape only this file knows.
static func _claims(number: int) -> Array:
	return _claims_of(SOURCE, number, "")


## The same, for any buffer.
static func _claims_of(source: String, number: int, script_path: String) -> Array:
	var found: Array = []
	for answer: EventSheetLiftProvenance.Answer in EventSheetLiftProvenance.claims(source, number,
			script_path):
		found.append(answer.line())
	return found


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("lift_provenance_test", label, actual, expected)
