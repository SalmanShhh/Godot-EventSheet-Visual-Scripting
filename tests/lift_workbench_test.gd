# Godot EventSheets - the Lift Workbench's reading, gated headless.
#
# The window is widgets over one call: EventSheetLiftReading.read(buffer). This pins that call, which
# is everything a developer standing at the bench is told - what claims each line, what the buffer
# opens as, and whether it saves back byte-identically - plus the draft door that turns an unclaimed
# line into a table entry.
#
# WHY THE LAYERS ARE PINNED APART. A named lift-table entry and the general reading are different
# claims and the panel shows them differently; a reading that quietly promoted one to the other would
# still round-trip, still count the same percentage, and lie to the only person who cares. So the
# claim on a known spelling is pinned as the family and the entry id, by value.
@tool
class_name LiftWorkbenchTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
## A buffer with one of each answer in it: a spelling a shipped table entry claims by name, lines
## that arrive as rows without one, and a lambda that stays honest code (Callables-as-data have no
## structured equivalent, and are meant not to).
const MIXED_BUFFER: String = """extends Node

var lives: int = 3


func _ready() -> void:
	rpc("player_joined", name)
	lives = 3
	var timer: Timer = Timer.new()
	timer.timeout.connect(func() -> void:
		lives -= 1
	)
	add_child(timer)
"""

## The by-example spelling the draft door hands to the example engine, and the entry it must derive.
const DRAFT_EXAMPLE: String = "shake_camera([[strength|argument: 3.0]])"


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _reading_pins() and all_passed
	all_passed = _claim_pins() and all_passed
	all_passed = _draft_pins() and all_passed
	all_passed = _one_reader() and all_passed
	return all_passed


## The buffer's three answers, by value.
static func _reading_pins() -> bool:
	var all_passed: bool = true
	var reading: Dictionary = EventSheetLiftReading.read(MIXED_BUFFER)
	all_passed = _check("the buffer saves back byte-identically",
		bool(reading.get("identical", false)), true) and all_passed
	all_passed = _check("an identical re-emission carries no difference",
		(reading.get("diff", {}) as Dictionary).is_empty(), true) and all_passed
	var counts: Dictionary = EventSheetLiftReading.layer_counts(reading)
	all_passed = _check("one line is claimed by a lift-table entry",
		int(counts[EventSheetLiftReading.LAYER_ENTRY]), 1) and all_passed
	all_passed = _check("the lambda's three lines stay code",
		int(counts[EventSheetLiftReading.LAYER_CODE]), 3) and all_passed
	all_passed = _check("blank lines belong to nobody",
		int(counts[EventSheetLiftReading.LAYER_QUIET]), 4) and all_passed
	return all_passed


## The claims themselves, per line: the entry names its family and its id, and the loop says the one
## plain sentence the whole feature rests on.
static func _claim_pins() -> bool:
	var all_passed: bool = true
	var reading: Dictionary = EventSheetLiftReading.read(MIXED_BUFFER)
	var by_text: Dictionary = {}
	for line: Variant in reading.get("lines", []) as Array:
		by_text[str((line as Dictionary).get("text", "")).strip_edges()] = line
	var send: Dictionary = by_text.get("rpc(\"player_joined\", name)", {})
	all_passed = _check("the send spelling is claimed by the multiplayer family",
		str(send.get("family", "")), "multiplayer_lift") and all_passed
	all_passed = _check("...and by the entry that spells it",
		str(send.get("entry_id", "")), "send_everyone_with_arguments") and all_passed
	all_passed = _check("...at the entry layer, which reads differently from a general reading",
		str(send.get("layer", "")), EventSheetLiftReading.LAYER_ENTRY) and all_passed
	var lambda: Dictionary = by_text.get("timer.timeout.connect(func() -> void:", {})
	all_passed = _check("the lambda is told the plain truth",
		str(lambda.get("claim", "")), EventSheetLiftReading.STAYS_CODE) and all_passed
	all_passed = _check("...at the code layer", str(lambda.get("layer", "")),
		EventSheetLiftReading.LAYER_CODE) and all_passed
	# A line INSIDE the block is never re-attributed by text: the block already docked the
	# percentage for it, and `lives -= 1` would otherwise read as Subtract From on its own.
	var inside: Dictionary = by_text.get("lives -= 1", {})
	all_passed = _check("a line inside the block stays code with it",
		str(inside.get("layer", "")), EventSheetLiftReading.LAYER_CODE) and all_passed
	return all_passed


## The draft door: a marked example derives an entry, that entry claims the line it was drafted from,
## and it says it is a draft while it does.
static func _draft_pins() -> bool:
	var all_passed: bool = true
	var derived: Dictionary = EventForgeLiftExample.entry("shake_the_camera", "ShakeCamera",
		DRAFT_EXAMPLE)
	all_passed = _check("the marked example derives an entry rather than a refusal",
		derived.has(EventForgeLiftTable.REFUSAL_KEY), false) and all_passed
	all_passed = _check("...whose shape is the line with a slot where the mark was",
		str(derived.get("shape", "")), "shake_camera({strength})") and all_passed
	var claimed: Dictionary = EventSheetLiftReading.table_claim("shake_camera(3.0)", [derived])
	all_passed = _check("a drafted entry claims the line it was drafted from",
		str(claimed.get("entry_id", "")), "shake_the_camera") and all_passed
	all_passed = _check("...and says it is a draft, not a shipped spelling",
		str(claimed.get("family", "")), "draft") and all_passed
	# A refused example is inert rather than dangerous: it matches nothing, so a broken draft cannot
	# claim a line by accident.
	var refused: Dictionary = EventForgeLiftExample.entry("bad", "Bad", "shake_camera([[3.0]])")
	all_passed = _check("an example the engine cannot answer comes back refused",
		refused.has(EventForgeLiftTable.REFUSAL_KEY), true) and all_passed
	all_passed = _check("...and claims nothing",
		EventSheetLiftReading.table_claim("shake_camera(3.0)", [refused]).is_empty(), true) and all_passed
	# AN EXAMPLE THAT IS ALL VALUE SPAN is the dangerous one, because it builds: `[[x: foo]]` derives
	# `^(?<x>.+)$`, which is not a spelling of anything - it is the whole language - and a draft that
	# wide claims every line in the window with nothing on screen to say why.
	all_passed = _check("an example with no text of its own is refused, and says why",
		EventForgeLiftExample.refusal("[[x: foo]]"),
		"the example is all value span and no text of its own, so it would match every line - write"		+ " the line the way a person writes it, with only the values marked") and all_passed
	all_passed = _check("...even when the span names a fragment",
		EventForgeLiftExample.refusal("[[x|word: foo]]").is_empty(), false) and all_passed
	# And the way OUT of a draft that claims too much: the panel lists what it holds and clears it.
	var bench: EventSheetLiftWorkbench = EventSheetLiftWorkbench.new()
	bench.clear_drafts()
	all_passed = _check("a cleared panel holds no drafts",
		bench.drafts_summary(), PackedStringArray()) and all_passed
	all_passed = _check("...and claims nothing on a buffer",
		bench.draft_entries(), []) and all_passed
	all_passed = _drafts_are_panel_scoped() and all_passed
	return all_passed


## DRAFTS LAST AS LONG AS THE PANEL DOES. They are working state, not a feature with a store behind
## it: one panel's drafts are held on that object, a panel opened afterwards starts empty, and no
## file is written for them - so a line can never read as somebody's draft from a session that is
## over, and there is nothing on disk for a person to go and find.
static func _drafts_are_panel_scoped() -> bool:
	var all_passed: bool = true
	# The path the first version of this panel wrote. Removed first, so what is asserted below is that
	# the panel does not write it, not that this machine happened to be clean.
	var abandoned_store: String = "user://eventsheets_lift_drafts.txt"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(abandoned_store))
	var open_panel: EventSheetLiftWorkbench = EventSheetLiftWorkbench.new()
	open_panel._drafts.append({"id": "shake_the_camera", "ace_id": "ShakeCamera",
		"example": DRAFT_EXAMPLE})
	all_passed = _check("the panel that made the draft is holding it",
		open_panel.drafts_summary(),
		PackedStringArray(["shake_the_camera - %s" % DRAFT_EXAMPLE])) and all_passed
	all_passed = _check("a panel opened afterwards holds nothing",
		EventSheetLiftWorkbench.new().drafts_summary(), PackedStringArray()) and all_passed
	all_passed = _check("...and nothing was written for them to come back from",
		FileAccess.file_exists(abandoned_store), false) and all_passed
	return all_passed


## The percentage the workbench shows, the percentage the corpus gate pins and the percentage the
## head bar's chip shows are ONE number from ONE walk. Asked here of the same buffer through both
## doors, because two implementations of it would drift the moment either learned a new row shape.
static func _one_reader() -> bool:
	var reading: Dictionary = EventSheetLiftReading.read(MIXED_BUFFER)
	var direct: Dictionary = EventSheetReadingCoverage.measure(
		reading.get("sheet", null) as EventSheetResource)
	return _check("the reading's percentage is the coverage walk's own",
		EventSheetLiftReading.percent(reading), int(direct.get("percent", -1)))


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("lift_workbench_test", label, actual, expected)
