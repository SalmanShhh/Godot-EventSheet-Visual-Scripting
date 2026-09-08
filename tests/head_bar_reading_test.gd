@tool
class_name HeadBarReadingTest
extends RefCounted

# Pins the ONE HEAD BAR an opened file rests under, and the Behaviors band beside it.
#
# A file used to open with six stacked bars before its first event - the class, what it extends, the
# receipts and how much of it read as events, the `##` prose, the controls it names and the
# variables it declares. They are one line now:
#
#     InputRebindDemo extends Control - reads as events - 4 input actions - 1 variable
#
# and every bar they were is still there, as the fold under it. Four things are pinned here, each
# by VALUE:
#
#   1. the bar's own words, for a showcase and for a shipped pack, plus the rows that hang under it;
#   2. the file's prose drawn ONCE - the `##` band that used to draw its value and its echo over
#      each other is gone, and the comment row is the only copy;
#   3. the quiet sheet at the head: a control the Input Map has not got leaves the Input bar's words
#      entirely and becomes the amber state on the bar, with the sentence in the help strip;
#   4. the Behaviors band, whose chips are doors into the packs they name, which says the KINDS
#      and their counts on one folded line and opens into
#      one line per kind with its settings and the nodes wearing it.
#
# Read off the shipped tree rather than a fixture, because the point of every one of these readings
# is what a reader sees when they open the real file.

const SUPPORT := preload("res://tests/support.gd")
const P := "head_bar_reading_test"

const SHOWCASE := "res://demo/showcase/input_rebind/input_rebind.gd"
const PACK := "res://eventsheet_addons/flash/flash_behavior.gd"
const CAROUSEL := "res://demo/showcase/carousel/showcase_carousel.gd"


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _one_bar_for_a_showcase() and all_passed
	all_passed = _one_bar_for_a_pack() and all_passed
	all_passed = _the_prose_is_drawn_once() and all_passed
	all_passed = _the_input_finding_is_quiet() and all_passed
	all_passed = _behaviors_count_by_kind() and all_passed
	return all_passed


## The showcase's head: one bar with its four facts, and the bars it folds hanging under it.
static func _one_bar_for_a_showcase() -> bool:
	var head: Array = _head_rows(SHOWCASE)
	return SUPPORT.pins(P, [
		["input_rebind head bar", _words_of(head[0]),
			"▣ InputRebindDemo extends Control · 4 input actions · 1 variable"],
		["input_rebind head bar folds the bars it stands for", _child_uids(head[0]),
			"sheet_head_name, sheet_head_extends, pack_include_bar, input_actions, pack_internal_state"],
		["input_rebind head bar is a fold, closed", str(head[0].folded), "true"],
	])


## A shipped pack's head: the same bar, with the pack's own Include bar, its `@icon` and its host
## binding among the lines it folds.
##
## A PACK is the one file whose variable folders leave that fold: they read on the sheet as the
## pack's Settings and its Internal state. The bar's variable count leaves with them, because every
## fact on that line is COUNTED FROM the bar it folds and a bar that folds them no longer would be
## claiming somebody else's rows.
static func _one_bar_for_a_pack() -> bool:
	var head: Array = _head_rows(PACK)
	return SUPPORT.pins(P, [
		["flash head bar", _words_of(head[0]),
			"▣ FlashBehavior extends Node"],
		["flash head bar folds the bars it stands for", _child_uids(head[0]),
			"sheet_head_name, sheet_head_extends, sheet_head_icon, sheet_head_host, pack_include_bar"],
	])


## The `##` block is a comment row and nothing else. The band that used to carry it drew its value
## and its echo of the same line over each other, and a pack that also ends on an about-comment drew
## the sentence twice; both files now hold exactly one row that says it.
static func _the_prose_is_drawn_once() -> bool:
	return SUPPORT.pins(P, [
		["input_rebind description bands", _uids_matching(SHOWCASE, "sheet_head_description"), ""],
		["input_rebind description rows", _rows_saying(SHOWCASE, "a working rebind screen"), 1],
		["flash description bands", _uids_matching(PACK, "sheet_head_description"), ""],
		["flash description rows", _rows_saying(PACK, "Blinks the host node's visibility"), 1],
		["flash reads its whole ## block", _words_of(_row_named(PACK, "head_description_row")),
			"Blinks the host node's visibility on and off for a duration, then snaps it back to fully visible and fires On Flash Finished. The classic damage-flicker and invincibility-frames effect, with a single interval knob you can change live."],
	])


## A control the project's Input Map has not got: nothing at all in the sheet, the amber state on
## the head bar, and the sentence the help strip reads out of it.
static func _the_input_finding_is_quiet() -> bool:
	var head: Array = _head_rows(SHOWCASE)
	var input_bar: EventRowData = _child_named(head[0], "input_actions")
	return SUPPORT.pins(P, [
		["the Input bar says nothing about it", _words_of(input_bar.children[0]), "demo_jump"],
		["the head bar wears the finding", head[0].attention_note.get_slice(" · ", 0),
			"\"demo_jump\" is not in the Input Map - the control never fires and nothing says so. Add it in Project ▸ Input Map, or fix the spelling."],
		["the finding carries its family", str(head[0].attention_findings[0].get("family", "")), "input"],
		["the finding carries the control it is about",
			str(head[0].attention_findings[0].get("subject", "")), "demo_jump"],
	])


## Thirty-four behaviors on one object: eight kinds with their counts on the folded line, and one
## line per kind under it - with the settings the scene wrote and the nodes wearing them.
static func _behaviors_count_by_kind() -> bool:
	var band: EventRowData = _row_named(CAROUSEL, "object_behaviors")
	var lines: PackedStringArray = PackedStringArray()
	for member: EventRowData in band.children:
		lines.append(_words_of(member))
	return SUPPORT.pins(P, [
		["carousel Behaviors band", _words_of(band),
			"Behaviors · 34 on this object - Spring 10, Tween 10, Flash 2, Juice, Scenes, Blend Modes, Screen FX, Sine 8"],
		["carousel Behaviors band is folded", str(band.folded), "true"],
		["carousel Behaviors kinds", "\n".join(lines), "\n".join(PackedStringArray([
			"Spring ×10 on Carousel … Tile7",
			"Tween ×10 on Carousel … Tile7",
			"Flash ×2 on Carousel · Hero",
			"Juice",
			"Scenes",
			"Blend Modes",
			"Screen FX layer = 100",
			"Sine ×8 movement = \"vertical\" · period = 1.6 · magnitude = 18.0 · on Tile0 … Tile7",
		]))],
		# A kind is a DOOR: the chip carries the pack's own script, so clicking the word opens
		# that behavior as a sheet - the same jump the Include bar makes, through the same field.
		["carousel Behaviors chips open their packs", _chip_doors(band),
			"Spring 10 -> spring_behavior.gd"],
	])


## The first chip of a band that names a file, as "<chip> -> <file>". One line rather than all of
## them, because the pin is that a chip IS a door and which file it opens - not the pack list,
## which the band words above already carry.
static func _chip_doors(band: EventRowData) -> String:
	for span: SemanticSpan in band.spans:
		if span == null or not (span.metadata is Dictionary):
			continue
		var opens: String = str((span.metadata as Dictionary).get("include_path", ""))
		if not opens.is_empty():
			return "%s -> %s" % [span.text.trim_suffix(","), opens.get_file()]
	return ""


# ── reading the shipped files ───────────────────────────────────────────────────────────────────


## One file opened exactly as opening it opens it: read-only, in reading mode, through the shipped
## row builder. Returns the ROOT rows; the caller frees nothing, because the viewport is freed here
## and the rows outlive it.
static func _head_rows(path: String) -> Array:
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(path)
	if sheet == null:
		return []
	sheet.read_only = true
	var style: EventSheetEditorStyle = EventSheetEditorStyle.new()
	style.ensure_defaults()
	sheet.editor_style = style
	var viewport: EventSheetViewport = EventSheetViewport.new()
	viewport.set_ace_registry(EventSheetACERegistry.new())
	viewport.set_sheet(sheet)
	viewport.set_reading_mode(true)
	var rows: Array = viewport._root_rows.duplicate()
	viewport.free()
	return rows


## One row's words, spans joined - what a reader of that line sees, without the colours.
static func _words_of(row_data: EventRowData) -> String:
	var words: PackedStringArray = PackedStringArray()
	for span: SemanticSpan in row_data.spans:
		var text: String = span.text.strip_edges()
		if not text.is_empty():
			words.append(text)
	return " ".join(words)


## A row's uid without the instance number every head row is keyed by, which changes per run.
static func _stable_uid(row_data: EventRowData) -> String:
	var uid: String = str(row_data.row_uid)
	var cut: int = uid.rfind("_-")
	if cut < 0:
		cut = uid.rfind("_")
	return uid.substr(0, cut) if cut > 0 else uid


static func _child_uids(row_data: EventRowData) -> String:
	var uids: PackedStringArray = PackedStringArray()
	for child: EventRowData in row_data.children:
		uids.append(_stable_uid(child))
	return ", ".join(uids)


static func _child_named(row_data: EventRowData, uid: String) -> EventRowData:
	for child: EventRowData in row_data.children:
		if _stable_uid(child) == uid:
			return child
	return EventRowData.new()


## The one row of a file with this uid, at any depth - the Behaviors band is a root row, but asking
## for it by name keeps the pin from counting the head's rows.
static func _row_named(path: String, uid: String) -> EventRowData:
	for row_data: EventRowData in _all_rows(path):
		if _stable_uid(row_data) == uid:
			return row_data
	return EventRowData.new()


## Every uid of a file that starts with this prefix, sorted - "" when the file grows none, which is
## what a band that no longer exists looks like.
static func _uids_matching(path: String, prefix: String) -> String:
	var found: PackedStringArray = PackedStringArray()
	for row_data: EventRowData in _all_rows(path):
		if _stable_uid(row_data).begins_with(prefix):
			found.append(_stable_uid(row_data))
	found.sort()
	return ", ".join(found)


## How many rows of a file say a phrase - the count that says a sentence is drawn once.
static func _rows_saying(path: String, phrase: String) -> int:
	var said: int = 0
	for row_data: EventRowData in _all_rows(path):
		if _words_of(row_data).contains(phrase):
			said += 1
	return said


static func _all_rows(path: String) -> Array:
	var found: Array = []
	_walk(_head_rows(path), found)
	return found


static func _walk(rows: Array, into: Array) -> void:
	for row_data: EventRowData in rows:
		into.append(row_data)
		_walk(row_data.children, into)
