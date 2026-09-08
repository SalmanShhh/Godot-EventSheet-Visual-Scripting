# EventSheet - A BEHAVIOR PACK OPENS ON ITS VERBS, proved against two shipped packs.
#
# A pack has a public face - the settings a designer turns and the verbs the picker offers - and an
# implementation nobody opens on purpose. Read in file order it opened on the implementation: eleven
# variables, a script block and the tick loop, with the verbs the reader clicked the pack for last,
# under a head that read them as triggers. This pins the reading that turns that round:
#
#   1. Four bands in order - Settings, Verbs, How it works, Internal state.
#   2. A verb reads as the verb the picker offers, not as a trigger: "Flash", never "On Flash",
#      with the kind word beside it and an authored sentence used whole where there is one.
#   3. The plumbing idioms read in sheet words: "Start ticking" / "Stop ticking", and the host guard
#      folded onto the tick's own line.
#   4. Inside a pack the sheet's own two labels read as the pack's short name; `host` stays `host`.
#   5. The file's prose is drawn once.
#
# Every one of those is a LENS: the load-bearing assertion is the last block, where both packs
# re-emit byte for byte from the same sheet the readings above were taken from. A reading that
# cannot put the file back is not a reading, it is an edit.
@tool
class_name PackOpensOnVerbsTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const FLASH_PATH := "res://eventsheet_addons/flash/flash_behavior.gd"
const SPRING_PATH := "res://eventsheet_addons/spring/spring_behavior.gd"


static func run() -> bool:
	var passed: bool = true
	passed = _flash_opens_in_four_bands() and passed
	passed = _verbs_read_as_verbs() and passed
	passed = _plumbing_reads_in_sheet_words() and passed
	passed = _pack_is_its_own_object() and passed
	passed = _spring_opens_the_same_way() and passed
	passed = _both_packs_re_emit_byte_for_byte() and passed
	return passed


## Opens a pack the way the dock opens one: a read-only preview, which is reading mode.
static func _open(path: String) -> EventSheetViewport:
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(path)
	sheet.read_only = true
	var view := EventSheetViewport.new()
	view.set_ace_registry(EventSheetACERegistry.new())
	view.set_sheet(sheet)
	view.set_reading_mode(true)
	return view


## Every row's text, one string per row, spans joined - the same reading the render harness prints,
## so a value pinned here is a value that can be seen in the image. Children are walked too.
static func _row_texts(view: EventSheetViewport) -> PackedStringArray:
	var texts: PackedStringArray = PackedStringArray()
	for entry: Dictionary in view.get_flat_rows():
		_collect_row_texts(view, entry.get("row"), texts)
	return texts


static func _collect_row_texts(view: EventSheetViewport, row_data: EventRowData, texts: PackedStringArray) -> void:
	if row_data == null:
		return
	view._row_builder._ensure_event_spans(row_data)
	var parts: PackedStringArray = PackedStringArray()
	for span: SemanticSpan in row_data.spans:
		parts.append(span.text)
	texts.append(" | ".join(parts))
	for child: EventRowData in row_data.children:
		_collect_row_texts(view, child, texts)


## The pack's own band bars, in the order the sheet draws them - the whole of what "opens on its
## verbs" means, as one comparable value.
static func _band_titles(view: EventSheetViewport) -> PackedStringArray:
	var titles: PackedStringArray = PackedStringArray()
	for entry: Dictionary in view.get_flat_rows():
		var row_data: EventRowData = entry.get("row")
		if row_data == null or row_data.spans.is_empty():
			continue
		if not _is_pack_band(row_data):
			continue
		titles.append(row_data.spans[0].text)
	return titles


static func _is_pack_band(row_data: EventRowData) -> bool:
	var meta: Variant = row_data.spans[0].metadata
	return meta is Dictionary and str((meta as Dictionary).get("kind", "")) == "pack_head_group"


## The bar with this title, or null - so a test can ask what is INSIDE a band rather than only
## which bands there are.
static func _band(view: EventSheetViewport, title: String) -> EventRowData:
	for entry: Dictionary in view.get_flat_rows():
		var row_data: EventRowData = entry.get("row")
		if row_data == null or row_data.spans.is_empty():
			continue
		if _is_pack_band(row_data) and row_data.spans[0].text == title:
			return row_data
	return null


## The first line of each of a band's own members - the list a reader sees when the band opens.
static func _band_leads(view: EventSheetViewport, title: String) -> PackedStringArray:
	var leads: PackedStringArray = PackedStringArray()
	var bar: EventRowData = _band(view, title)
	if bar == null:
		return leads
	for child: EventRowData in bar.children:
		view._row_builder._ensure_event_spans(child)
		var parts: PackedStringArray = PackedStringArray()
		for span: SemanticSpan in child.spans:
			var meta: Variant = span.metadata
			if meta is Dictionary and str((meta as Dictionary).get("lane", "")) == "action":
				continue
			parts.append(span.text)
		leads.append(" ".join(parts).strip_edges())
	return leads


## The ACTION lane of the trigger row whose name leads with these words - what the band says about
## when that trigger happens.
static func _trigger_answer(view: EventSheetViewport, name_words: String) -> String:
	var bar: EventRowData = _band(view, "Verbs")
	if bar == null:
		return ""
	for child: EventRowData in bar.children:
		view._row_builder._ensure_event_spans(child)
		var names: PackedStringArray = PackedStringArray()
		var answer: PackedStringArray = PackedStringArray()
		for span: SemanticSpan in child.spans:
			var meta: Variant = span.metadata
			if meta is Dictionary and str((meta as Dictionary).get("lane", "")) == "action":
				answer.append(span.text)
			else:
				names.append(span.text)
		if " ".join(names).contains(name_words):
			return " ".join(answer).strip_edges()
	return ""


static func _count_containing(texts: PackedStringArray, needle: String) -> int:
	var seen: int = 0
	for text: String in texts:
		if text.contains(needle):
			seen += 1
	return seen


## Flash opens as Settings, Verbs, How it works, Internal state - and the settings band holds the one
## knob the Inspector shows, while the ten the pack keeps to itself are folded away under the last.
static func _flash_opens_in_four_bands() -> bool:
	var view: EventSheetViewport = _open(FLASH_PATH)
	var passed: bool = SUPPORT.pins("pack_opens_on_verbs", [
		["Flash opens in four bands, in this order",
			", ".join(_band_titles(view)),
			"Settings, Verbs, How it works, Internal state"],
		["the settings band holds the one exported knob",
			", ".join(_band_leads(view, "Settings")),
			"x Instance number interval ⚙ = 0.1 Seconds between visibility toggles - smaller values blink faster. @export var interval: float = 0.1"],
		["Settings and Verbs open with the pack",
			[_band(view, "Settings").folded, _band(view, "Verbs").folded], [false, false]],
		["How it works and Internal state stay folded",
			[_band(view, "How it works").folded, _band(view, "Internal state").folded], [true, true]],
		["the private state is not in the settings band",
			_count_containing(_band_leads(view, "Settings"), "accumulator"), 0],
		["the private state is under Internal state",
			_count_containing(_band_leads(view, "Internal state"), "accumulator"), 1],
		["the file's own prose is drawn once",
			_count_containing(_row_texts(view),
				"The classic damage-flicker and invincibility-frames effect"), 1]
	])
	view.free()
	return passed


## The verbs read as the picker offers them: the name alone, the kind word beside it, and an
## authored display sentence used whole rather than repeated as chips.
static func _verbs_read_as_verbs() -> bool:
	var view: EventSheetViewport = _open(FLASH_PATH)
	var texts: PackedStringArray = _row_texts(view)
	var passed: bool = SUPPORT.pins("pack_opens_on_verbs", [
		["the verbs band lists the pack's vocabulary in file order",
			", ".join(_band_leads(view, "Verbs")),
			"ƒ Flash seconds action, ƒ Stop Flash action, ƒ Blink pattern for seconds s action, "
				+ "ƒ Stop Blink action, ƒ Is Blinking condition, ƒ Blink Phase expression, "
				+ "➜ On Flash Finished"],
		["a verb is no longer read as a trigger", _count_containing(texts, "ƒ | On Flash |"), 0],
		["an authored sentence is not repeated as chips",
			_count_containing(texts, "Blink pattern for seconds s | pattern"), 0]
	])
	view.free()
	return passed


## The two idioms every pack repeats, in the sheet's own words - and the host guard reading on the
## tick's own line instead of taking a cell of its own.
static func _plumbing_reads_in_sheet_words() -> bool:
	var view: EventSheetViewport = _open(FLASH_PATH)
	var texts: PackedStringArray = _row_texts(view)
	var passed: bool = SUPPORT.pins("pack_opens_on_verbs", [
		["switching the tick on reads as starting to tick",
			_count_containing(texts, "Start ticking") > 0, true],
		["switching it off reads as stopping",
			_count_containing(texts, "Stop ticking") > 0, true],
		["the callback words are gone from the pack's reading",
			_count_containing(texts, "Every tick (draw) deactivated"), 0],
		["the host guard reads on the tick's own line",
			_count_containing(texts, "⟳ | Every tick (draw) | host is valid"), 1]
	])
	view.free()
	return passed


## Inside a pack the two labels that mean "this file" read as the name the picker offers it by, and
## the node it rides keeps its own.
static func _pack_is_its_own_object() -> bool:
	var view: EventSheetViewport = _open(FLASH_PATH)
	var labels: Dictionary = {}
	for entry: Dictionary in view.get_flat_rows():
		_collect_object_labels(view, entry.get("row"), labels)
	var passed: bool = SUPPORT.pins("pack_opens_on_verbs", [
		["a member write reads under the pack, not under System",
			labels.has("Flash"), true],
		["the node the pack rides keeps its own name", labels.has("host"), true]
	])
	view.free()
	return passed


static func _collect_object_labels(view: EventSheetViewport, row_data: EventRowData, labels: Dictionary) -> void:
	if row_data == null:
		return
	view._row_builder._ensure_event_spans(row_data)
	for span: SemanticSpan in row_data.spans:
		var meta: Variant = span.metadata
		if not (meta is Dictionary):
			continue
		var label: String = str((meta as Dictionary).get("object_label", "")).strip_edges()
		if not label.is_empty():
			labels[label] = true
	for child: EventRowData in row_data.children:
		_collect_object_labels(view, child, labels)


## A second pack, so the reading is a rule rather than one file's shape: Spring declares its knobs
## with @export_range and fires two triggers, and opens in the same four bands.
static func _spring_opens_the_same_way() -> bool:
	var view: EventSheetViewport = _open(SPRING_PATH)
	var verbs: PackedStringArray = _band_leads(view, "Verbs")
	var passed: bool = SUPPORT.pins("pack_opens_on_verbs", [
		["Spring opens in the same four bands, in the same order",
			", ".join(_band_titles(view)),
			"Settings, Verbs, How it works, Internal state"],
		["its exported knobs are its settings",
			", ".join(_band_leads(view, "Settings")).contains("default_stiffness"), true],
		["its verbs lead the band",
			verbs[0] if not verbs.is_empty() else "", "ƒ Spring spring name to target action"],
		["and its triggers close it",
			verbs[verbs.size() - 1] if not verbs.is_empty() else "",
			"➜ On Spring Started text"],
		# A signal declaration says what a trigger is CALLED and nothing at all about when it
		# happens, so the band reads that off this file's own rows instead.
		["a trigger says which of the pack's verbs fire it",
			_trigger_answer(view, "On Spring Started"),
			"emits spring_started fired by Spring To · Spring Color"]
	])
	view.free()
	return passed


## THE CONTRACT the four readings above stand on: both packs, opened and saved untouched, are the
## same bytes. Nothing here is an edit.
static func _both_packs_re_emit_byte_for_byte() -> bool:
	var passed: bool = true
	for path: String in [FLASH_PATH, SPRING_PATH]:
		var source: String = FileAccess.get_file_as_string(path)
		var verify_path: String = "user://pack_opens_on_verbs_%s" % path.get_file()
		passed = SUPPORT.check("pack_opens_on_verbs",
			"%s saves every byte back" % path.get_file(),
			SUPPORT.reemit(source, verify_path) == source, true) and passed
	return passed
