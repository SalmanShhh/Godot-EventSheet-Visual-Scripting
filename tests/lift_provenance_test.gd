# Godot EventSheets - what claims this line, pinned as the ANSWERS rather than as a count.
#
# The provenance reader (EventSheetLiftProvenance) walks every reading layer in the order the
# importer asks them and reports each one that answers. A count of how many answered would pass on
# any two layers swapping places, so nothing here counts: every pin is the layer, the file it names
# and the sentence it says, on four lines of one buffer chosen because each lands on a different
# layer of the stack.
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


static func run() -> bool:
	var ok: bool = _test_the_three_known_lines()
	ok = _test_the_by_example_layer_is_told_apart() and ok
	ok = _test_the_printed_shape() and ok
	ok = _test_a_line_that_is_not_one() and ok
	return ok


## The three lines the tool exists to tell apart. Each is pinned as the whole answer list, so a layer
## that starts answering where it did not - or stops answering where it did - fails here.
static func _test_the_three_known_lines() -> bool:
	var ok: bool = _check("a curated table entry claims its own spelling",
		_claims(TABLE_LINE), [
			_answer(0, "table", "multiplayer_lift.gd",
				"send_everyone_with_arguments -> SendMessageToEveryone"),
			_answer(4, "call", "", "Node2D.rpc (receiver: self)")
		])
	# The derived layer answers BELOW the index, and says which receiver resolution got it there -
	# `node`, because the @onready declaration at the top of the buffer types $Beam as a Light2D.
	ok = _check("a line nothing curated names reads through the index and the derived call layer",
		_claims(DERIVED_LINE), [
			_answer(3, "index", "", "Core::NodeSetProcessing"),
			_answer(4, "call", "", "Light2D.set_process (receiver: node)")
		]) and ok
	ok = _check("and a line no layer claims says exactly that", _claims(VERBATIM_LINE),
		[_answer(6, "verbatim", "", EventSheetLiftProvenance.UNCLAIMED)]) and ok
	return ok


## The one thing the provenance reader can say that the per-line reading beside it cannot: WHICH
## authoring route the entry that claimed the line came down. Both are lift-table entries and both
## match through the same engine; the input-event family's are derived from marked examples, and the
## entry itself carries that (EventForgeLiftTable.origin_of) rather than it being inferred.
static func _test_the_by_example_layer_is_told_apart() -> bool:
	var ok: bool = _check("an entry derived from an example says so, and names its family",
		_claims(EXAMPLE_LINE),
		[_answer(1, "example", "input_event_lift.gd",
			"event_action_pressed -> EventIsActionPressed")])
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
## naming the file and the line, then one line per layer - and it is what somebody diffs two runs of,
## so it is pinned rather than described.
static func _test_the_printed_shape() -> bool:
	return _check("the whole answer, as it prints",
		EventSheetLiftProvenance.text(SOURCE, TABLE_LINE, "res://buffer.gd"),
		"res://buffer.gd:8  rpc(&\"take_damage\", 10)\n"
		+ "  1. table    multiplayer_lift.gd  send_everyone_with_arguments -> SendMessageToEveryone\n"
		+ "  5. call     Node2D.rpc (receiver: self)")


## The two lines that are not lines of code. Said in words, because a mistyped line number that came
## back as "nothing claims it" would read as a finding about the file.
static func _test_a_line_that_is_not_one() -> bool:
	var ok: bool = _check("a blank line is asked of nothing", _claims(2),
		[_answer(6, "verbatim", "", EventSheetLiftProvenance.BLANK)])
	ok = _check("and a line past the end of the buffer says so", _claims(9999),
		[_answer(6, "verbatim", "", EventSheetLiftProvenance.OUT_OF_RANGE)]) and ok
	return ok


## The answers for one line of the shared buffer, as a plain Array so a pin compares values.
static func _claims(number: int) -> Array:
	var found: Array = []
	for answer: Dictionary in EventSheetLiftProvenance.claims(SOURCE, number):
		found.append(answer)
	return found


## One expected answer, in the shape the reader hands back.
static func _answer(order: int, layer: String, where: String, detail: String) -> Dictionary:
	return {"order": order, "layer": layer, "where": where, "detail": detail}


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("lift_provenance_test", label, actual, expected)
