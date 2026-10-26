@tool
class_name HeadBarReadingTest
extends RefCounted

# Pins the ONE HEAD BAR every opened file rests under, and the cards behind its words.
#
# A file used to open with a head card over the sheet, a folded group row under it, the file's prose
# hoisted to the top as a comment row and a Behaviors band among the rows. It opens on one bar now:
#
#     ◆ CarouselOfJuice  Custom node · extends Node2D            4 variables · 2 events · 34 behaviours
#
# and everything else lives one hover away, on the card behind the name or a count. Five things are
# pinned here, each by VALUE:
#
#   1. the bar's own words for a showcase and for a shipped pack (a behaviour says only that it is
#      one), and that the bar is a flat 30 px bar, not a fold;
#   2. the file's prose is no row of the head: a `##` line is the name card's, and the paragraph a
#      file ends on stays where the file has it;
#   3. the quiet sheet at the head: a control the Input Map has not got is the amber state on the bar;
#   4. the behaviours are a count with a card - each kind a door into its pack, then why they are not
#      rows, then Add behaviour… - and no band among the rows;
#   5. the variables count leaves the compiler's bookkeeping out, and its card says so.
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
	all_passed = _the_prose_stays_where_the_file_has_it() and all_passed
	all_passed = _the_input_finding_is_quiet() and all_passed
	all_passed = _behaviours_are_a_count_with_a_card() and all_passed
	all_passed = _variables_leave_the_bookkeeping_out() and all_passed
	return all_passed


## The showcase's head: one flat bar, the name as written, its kind, and the counts.
static func _one_bar_for_a_showcase() -> bool:
	var head: Array = _head_rows(SHOWCASE)
	return SUPPORT.pins(P, [
		["input_rebind head bar", _words_of(head[0]),
			"◆ InputRebindDemo Custom node · extends Control 1 variable · 8 events · 1 behaviour"],
		["the head bar is the sheet's", _stable_uid(head[0]), "sheet_head_bar"],
		["the head bar folds nothing", head[0].children.size(), 0],
		["the head bar is a bar, not a group", head[0].row_type, EventRowData.RowType.SECTION],
		["the head bar is 30 px in every look", head[0].fixed_height, 30.0],
		["the variable stays a row of its own, under the bar",
			(head[1] as EventRowData).source_resource is LocalVariable, true],
	])


## A shipped pack is a behaviour: its bar says the name and that it is a behaviour, and no more.
static func _one_bar_for_a_pack() -> bool:
	var head: Array = _head_rows(PACK)
	return SUPPORT.pins(P, [
		["flash opens on its head bar", _words_of(head[0]), "◆ FlashBehavior Behaviour"],
		["and the bar is the one head bar", _stable_uid(head[0]), "sheet_head_bar"],
		["no row of the head is the @icon line", _uids_matching(PACK, "sheet_head_icon"), ""],
	])


## The file's prose is no row of the head. A `##` line is said on the name's card; so is the `#`
## paragraph a showcase ends on, which the card claims as the description, and the canvas leaves its
## row out: it is said once, on the card.
static func _the_prose_stays_where_the_file_has_it() -> bool:
	var rows: Array = _head_rows(SHOWCASE)
	return SUPPORT.pins(P, [
		["input_rebind description bands", _uids_matching(SHOWCASE, "sheet_head_description"), ""],
		["input_rebind's closing paragraph is no row", _rows_saying(SHOWCASE, "a working rebind screen"), 0],
		["it is the name card's description, said once",
			str((_card_of(rows[0], "name").get("lines", []) as Array)).contains("a working rebind screen"), true],
		["flash's ## line is no row", _uids_matching(PACK, "sheet_head_description"), ""],
		["flash's ## line is the name card's", (_card_of(_head_rows(PACK)[0], "name").get("lines", []) as Array)
			.size(), 1],
	])


## A control the project's Input Map has not got: nothing at all in the sheet, the amber state on
## the head bar, and the sentence the help strip reads out of it.
static func _the_input_finding_is_quiet() -> bool:
	var head: Array = _head_rows(SHOWCASE)
	return SUPPORT.pins(P, [
		["the head bar wears the finding", head[0].attention_note.get_slice(" · ", 0),
			"\"demo_jump\" is not in the Input Map - the control never fires and nothing says so. Add it in Project ▸ Input Map, or fix the spelling."],
		["the finding carries its family", str(head[0].attention_findings[0].get("family", "")), "input"],
		["the finding carries the control it is about",
			str(head[0].attention_findings[0].get("subject", "")), "demo_jump"],
	])


## Thirty-four behaviours on one object: a count on the bar, and on its card the kinds with their
## counts (each one a door into its pack), why they are listed there, and Add behaviour….
static func _behaviours_are_a_count_with_a_card() -> bool:
	var head: Array = _head_rows(CAROUSEL)
	var card: Dictionary = _card_of(head[0], "behaviours")
	var kinds: PackedStringArray = PackedStringArray()
	for link: Variant in card.get("links", []):
		kinds.append(str((link as Array)[0]))
	var first: Array = (card.get("links", [[""]]) as Array)[0] as Array
	return SUPPORT.pins(P, [
		["carousel head bar", _words_of(head[0]),
			"◆ CarouselOfJuice Custom node · extends Node2D 4 variables · 2 events · 34 behaviours"],
		["carousel behaviour kinds on the card", " · ".join(kinds),
			"Spring 10 · Tween 10 · Flash 2 · Juice · Scenes · Blend Modes · Screen FX · Sine 8"],
		["a kind opens its pack", str(first[1]).get_file(), "spring_behavior.gd"],
		["the card says why they are not rows", str((card.get("lines", [""]) as Array)[0]),
			"They are child nodes in the scene, not lines of this file, so they are listed here rather than as rows."],
		["and offers Add behaviour…", str(card.get("doors", [])), "[[\"Add behaviour…\", \"add_behaviour\"]]"],
		["no Behaviors band among the rows", _uids_matching(CAROUSEL, "object_behaviors"), ""],
	])


## The compiler's own members are bookkeeping, not variables a reader declared: never counted, and
## named on the card as what they are.
static func _variables_leave_the_bookkeeping_out() -> bool:
	var card: Dictionary = _card_of(_head_rows(CAROUSEL)[0], "variables")
	return SUPPORT.pins(P, [
		["the variables card", str((card.get("lines", [""]) as Array)[0]),
			"beat, intensity, party_on and moments_played, all 4 shown in the Inspector. The 3 other variables in the file are bookkeeping the compiler writes (__group_juice_active, __every_beat_caro, …)."],
	])


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


## The card behind one word of a head bar, by its id - {} when the bar has no such word.
static func _card_of(row_data: EventRowData, card_id: String) -> Dictionary:
	for span: SemanticSpan in row_data.spans:
		var card: Variant = (span.metadata as Dictionary).get("head_card") if span.metadata is Dictionary else null
		if card is Dictionary and str((card as Dictionary).get("id", "")) == card_id:
			return card
	return {}


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
