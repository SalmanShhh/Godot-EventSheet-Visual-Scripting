@tool
class_name ReadingDumpTest
extends RefCounted

# The reading dump is a GATE TEXT, so what it has to be is what this pins: the same bytes twice over
# an unchanged sheet, and a line that MOVES when the reading moves. A text that is stable but blind
# would pass the first half and be worthless.
#
# The two seeds are the two things a reading is made of. A row whose verb the installed vocabulary
# does not have reads through its own stored reading, `"Retired verb {amount}"` - a display WORD and
# a param SLOT in one row - so changing the word and changing the value the slot is filled with are
# two edits of exactly one line each. That is the sensitivity a deletion in the reading files has to
# be caught by: a word that quietly changed, and a value that quietly stopped reaching its slot.
#
# The population here is a hand-built sheet of three rows rather than the tool's own (every builtin
# descriptor and every shipped sheet), because that one takes minutes. The tool walks the same writer
# over a bigger population; the writer is what is pinned.

const SUPPORT := preload("res://tests/support.gd")
const LINES := preload("res://tools/reading_lines.gd")
const P: String = "reading_dump_test"

## The verb the stored-reading rows name. A provider nothing registers, so the row falls to the
## reading baked onto it, which is exactly the row a retired verb leaves behind.
const GONE_PROVIDER: String = "ReadingDumpGoneProvider"
const GONE_ACE: String = "ReadingDumpGoneVerb"


static func run() -> bool:
	var ok: bool = true
	ok = _line_shape() and ok
	ok = _stable_bytes() and ok
	ok = _seeded_word_moves_one_line() and ok
	ok = _seeded_param_moves_one_line() and ok
	ok = _paths_are_named() and ok
	ok = _style_marks_are_written() and ok
	ok = _verbatim_means_the_line_stayed_code() and ok
	return ok


## The written line, pinned without a viewport: five tab-separated fields in the order `FIELDS`
## names, escaped the way the registry dumps escape, and the path field carrying its branch.
static func _line_shape() -> bool:
	var reading: LINES.Reading = LINES.Reading.new()
	reading.origin = "builtin::action::Core::SetVar"
	reading.lane = "action"
	reading.object_label = "System"
	reading.segments = PackedStringArray(["action+chip+kind=action=Set score to 1"])
	reading.path = LINES.Path.GRAMMAR
	reading.branch = "SetVar"
	return SUPPORT.pins(P, [
		["the field order is the one FIELDS names", LINES.FIELDS,
			PackedStringArray(["origin", "lane", "object", "segments", "path"])],
		["a line is five tab-separated fields", LINES.line_for(reading).split("\t").size(), 5],
		["the line reads as written", LINES.line_for(reading),
			"builtin::action::Core::SetVar\taction\tSystem\taction+chip+kind=action=Set score to 1\tgrammar:SetVar"],
		["the header carries the format version", LINES.HEADER, "# eventsheets reading dump 2"],
		["a text of this format is recognised", LINES.is_current_format(LINES.text([reading])), true],
	])


## Two dumps of one unchanged sheet are the same bytes. The sheet is built again from nothing for the
## second dump, so anything that leaked from the first build would show here.
static func _stable_bytes() -> bool:
	var first: String = _dump(_sheet("Retired verb {amount}", "1"))
	var second: String = _dump(_sheet("Retired verb {amount}", "1"))
	return SUPPORT.pins(P, [
		["dumping an unchanged sheet twice writes the same bytes", first == second, true],
		["the dump is not empty", first.split("\n").size() > 3, true],
	])


## A display WORD that changed moves exactly one line, and moves it in place: the origin key is
## positional, so the line keeps its key and changes its segments.
static func _seeded_word_moves_one_line() -> bool:
	var before: String = _dump(_sheet("Retired verb {amount}", "1"))
	var after: String = _dump(_sheet("Withdrawn verb {amount}", "1"))
	var moved: PackedStringArray = _moved_lines(before, after)
	return SUPPORT.pins(P, [
		["a changed display word moves exactly one line", moved.size(), 1],
		["the changed line still carries the new word",
			moved[0].contains("Withdrawn verb 1") if moved.size() == 1 else "", true],
		["every other line stands", _lines(before).size() == _lines(after).size(), true],
	])


## A PARAM value that changed moves exactly one line - the row whose slot it fills, and no other.
static func _seeded_param_moves_one_line() -> bool:
	var before: String = _dump(_sheet("Retired verb {amount}", "1"))
	var after: String = _dump(_sheet("Retired verb {amount}", "7"))
	var moved: PackedStringArray = _moved_lines(before, after)
	return SUPPORT.pins(P, [
		["a changed param value moves exactly one line", moved.size(), 1],
		["the changed line carries the new value",
			moved[0].contains("Retired verb 7") if moved.size() == 1 else "", true],
	])


## Every path a cell can come down is spelled, and the stored-reading row is classified as the
## bespoke branch it really takes rather than as the generic assembly.
static func _paths_are_named() -> bool:
	var readings: Array = LINES.readings_of_sheet(_sheet("Retired verb {amount}", "1"), "res://probe.gd")
	var stored_path: String = ""
	for entry: Variant in readings:
		var reading: LINES.Reading = entry as LINES.Reading
		if reading.ace_key == "%s::%s" % [GONE_PROVIDER, GONE_ACE]:
			stored_path = reading.path_text()
	return SUPPORT.pins(P, [
		["every path has a name", LINES.PATH_NAMES.size(), 6],
		["a row whose verb is gone reads through its stored reading", stored_path,
			"bespoke:%s" % LINES.BRANCH_STORED],
	])


## THE MARKS A REFACTOR COULD DROP WITHOUT TOUCHING A WORD. Emphasis, a class picture and the muted
## word beside the object are all things a reader SEES and none of them is a word, so a text that
## wrote only the words would print `same` over a value that stopped being bold. Each is pinned on a
## span of its own, and the plain span beside them is pinned as carrying none of the three.
static func _style_marks_are_written() -> bool:
	var plain: SemanticSpan = SemanticSpan.new()
	plain.text = "Set score to 1"
	plain.type = SemanticSpan.SpanType.VALUE
	var rich: SemanticSpan = SemanticSpan.new()
	rich.text = "hp 5"
	rich.type = SemanticSpan.SpanType.VALUE
	var marked: Dictionary = {"bbcode_segments": [
		{"text": "hp ", "color": null, "bold": false, "italic": false},
		{"text": "5", "color": Color.RED, "bold": true, "italic": false},
	], "object_note": "Node2D", "text_color": Color.BLUE}
	return SUPPORT.pins(P, [
		["a plain span carries no style mark", LINES.segment_text_of(plain, {}), "value=Set score to 1"],
		["emphasis, the muted note and a tint are all marks",
			LINES.segment_text_of(rich, marked),
			"value+rich=-,b#ff0000ff+note=Node2D+tint=#0000ffff=hp 5"],
		["an object picture is named by the file it came from",
			LINES.segment_text_of(plain, {"object_icon": _icon()}), "value+icon=probe_icon.png=Set score to 1"],
	])


## A texture standing in for an editor icon, named the way a shipped one is.
static func _icon() -> Texture2D:
	var texture: ImageTexture = ImageTexture.create_from_image(
		Image.create(1, 1, false, Image.FORMAT_RGBA8))
	texture.resource_path = "res://probe/probe_icon.png"
	return texture


## VERBATIM IS A CLAIM, AND THE CLAIM IS CHECKED. A raw code row was classified verbatim on sight,
## which said "the line stays the code it is" about lines a reading layer had turned into words -
## `$Label.text = "hi"` is drawn as `Set text to "hi"` and is no more the code it came from than a
## picked verb is. Three rows, one of each kind: a line a reading claimed, a line nothing claimed, and
## a comment, whose words differ from its line only because the card drops the `#` in front of it.
static func _verbatim_means_the_line_stayed_code() -> bool:
	var paths: Dictionary = {}
	for entry: Variant in LINES.readings_of_sheet(_raw_sheet(), "res://probe.gd"):
		var reading: LINES.Reading = entry as LINES.Reading
		paths[" ".join(reading.plain)] = reading.path_text()
	return SUPPORT.pins(P, [
		["a line a reading turned into words is not verbatim",
			paths.get("Set text to \"hi\"", "(no such cell)"),
			"grammar:%s" % LINES.BRANCH_STATEMENT],
		["a line the card shows as itself is verbatim",
			paths.get("Script block cheat_helper(1, 2)", "(no such cell)"), "verbatim"],
		["a comment is code that stays code", paths.get("# just a note", "(no such cell)"), "verbatim"],
	])


## One event holding three raw rows: a property write a reading claims, a card the canvas shows the
## code of, and a comment.
static func _raw_sheet() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.custom_class_name = "ReadingDumpRawProbe"
	sheet.host_class = "Node2D"
	var row: EventRow = EventRow.new()
	row.trigger_id = "OnReady"
	for code: String in ["$Label.text = \"hi\"", "# just a note"]:
		var raw: RawCodeRow = RawCodeRow.new()
		raw.code = code
		row.actions.append(raw)
	sheet.events.append(row)
	var block_row: RawCodeRow = RawCodeRow.new()
	block_row.code = "cheat_helper(1, 2)"
	sheet.events.append(block_row)
	return sheet


## The three-row sheet the seeds are made in: the row with a stored reading, and two ordinary
## variable rows beside it so a moved line has neighbours that must not move.
static func _sheet(stored: String, amount: String) -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.custom_class_name = "ReadingDumpProbe"
	sheet.host_class = "Node"
	var row: EventRow = EventRow.new()
	row.trigger_id = "OnReady"
	var gone: ACEAction = ACEAction.new()
	gone.provider_id = GONE_PROVIDER
	gone.ace_id = GONE_ACE
	gone.params = {"amount": amount}
	gone.display_text = stored
	row.actions.append(gone)
	row.actions.append(_set_var("score", "1"))
	row.actions.append(_set_var("lives", "3"))
	sheet.events.append(row)
	return sheet


static func _set_var(variable_name: String, value: String) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "SetVar"
	action.params = {"var_name": variable_name, "value": value}
	return action


## One sheet's readings as the dump would write them.
static func _dump(sheet: EventSheetResource) -> String:
	return LINES.text(LINES.readings_of_sheet(sheet, "res://probe.gd"))


static func _lines(dump_text: String) -> PackedStringArray:
	return dump_text.split("\n", false)


## The lines of `after` that `before` does not hold - what a seeded change moved.
static func _moved_lines(before: String, after: String) -> PackedStringArray:
	var held: Dictionary = {}
	for line: String in _lines(before):
		held[line] = true
	var moved: PackedStringArray = PackedStringArray()
	for line: String in _lines(after):
		if not held.has(line):
			moved.append(line)
	return moved
