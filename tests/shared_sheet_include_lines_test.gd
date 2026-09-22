@tool
class_name SharedSheetIncludeLinesTest
extends RefCounted

# EventForge - an included shared sheet reads as one Include line, in either vocabulary.
#
# A script includes a shared sheet in one of Godot's two shapes: it extends it (the base), or it
# keeps one and forwards to it (a helper). A reader from another event-sheet editor looks for an
# "Include" line; a Godot reader looks for `extends` or a helper object. One line carries both. These
# pins hold:
#   1. which includes a script's own source declares, by value, and only real shared sheets;
#   2. the Include lines the head draws for them - "Include" for the one reader, and the Godot shape
#      (`extends X`, `var _x, called from _process`) at the end of the same line for the other;
#   3. the helper's forwarding call reads as the shared sheet's handler running here;
#   4. no pill on any of it - every span is a plain word.

const SUPPORT := preload("res://tests/support.gd")
const INCLUDER := "res://tests/fixtures/shared_sheets/fixture_includer.gd"


static func run() -> bool:
	var ok: bool = _the_source_says_what_it_includes()
	ok = _the_lines() and ok
	return ok


static func _the_source_says_what_it_includes() -> bool:
	var found: Array[Dictionary] = EventSheetSharedSheets.includes_of_source(FileAccess.get_file_as_string(INCLUDER))
	var read: Array = []
	for include: Dictionary in found:
		read.append("%s %s %s %s" % [include["wiring"], include["class"], include["member"], ",".join(include["from"])])
	return SUPPORT.pins("shared_sheet_include_lines_test", [
		["the base and the helper, in file order", read,
			["base_class FixtureDamageRules  ", "helper FixturePauseHandling _fixture_pause_handling _process"]],
		["an ordinary object the script makes is not an include",
			EventSheetSharedSheets.includes_of_source("extends Node\nvar _timer := Timer.new()\n").size(), 0],
	])


static func _the_lines() -> bool:
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(INCLUDER)
	var view := EventSheetViewport.new()
	view.set_ace_registry(EventSheetACERegistry.new())
	view.set_sheet(sheet)
	var texts: PackedStringArray = PackedStringArray()
	var pills: int = 0
	for entry: Dictionary in view.get_flat_rows():
		var row_data: EventRowData = entry.get("row")
		if row_data == null:
			continue
		view._row_builder._ensure_event_spans(row_data)
		var parts: PackedStringArray = PackedStringArray()
		for span: SemanticSpan in row_data.spans:
			parts.append(span.text)
			if row_data.row_uid.begins_with("include_line_") and span.metadata is Dictionary \
					and bool((span.metadata as Dictionary).get("badge", false)):
				pills += 1
		texts.append(" | ".join(parts))
	view.free()
	return SUPPORT.pins("shared_sheet_include_lines_test", [
		["the base reads as one line, with its Godot shape",
			texts.has("⇥ | Include | FixtureDamageRules | · shared sheet, as its base - extends FixtureDamageRules"), true],
		["the helper reads as one line, with its Godot shape",
			texts.has("⇥ | Include | FixturePauseHandling | · shared sheet, as a helper - var _fixture_pause_handling, called from _process"), true],
		["the forwarding call runs the helper's handler",
			_any_contains(texts, "Include | FixturePauseHandling | ▸ run its Every Frame"), true],
		["no pill on an Include line", pills, 0],
	])


static func _any_contains(texts: PackedStringArray, needle: String) -> bool:
	for text: String in texts:
		if text.contains(needle):
			return true
	return false
