# Godot EventSheets - U22 the generated GDScript-to-events dictionary, and U20 the page that
# introduces it.
#
# The dictionary exists to be PROOF, so the gate is the whole point: the page is regenerated here
# from the live idiom tables and the live vocabulary and compared with the bytes that shipped. A
# reading table edited without rebaking the bundle fails the suite instead of shipping a page that
# claims a reading nobody produces.
#
# The hand-written "Coming from GDScript" page is held to the same standard from the other side:
# every plain call it names has to be one the dictionary really lists.
@tool
class_name DocDictionaryTest
extends RefCounted

const GUIDE_PATH := "res://docs/GUIDE-COMING-FROM-GDSCRIPT.md"


static func run() -> bool:
	var passed: bool = true
	var registry: EventSheetACERegistry = EventSheetACERegistry.new()
	registry.refresh_from_sources([], true)
	var found: Array[Dictionary] = EventSheetDocDictionary.entries(registry)
	passed = _the_page_is_the_tables(found) and passed
	passed = _every_row_is_a_real_reading(found) and passed
	passed = _the_shipped_page_is_the_generated_one(found) and passed
	passed = _the_guide_names_real_calls(found) and passed
	return passed


static func _the_page_is_the_tables(found: Array[Dictionary]) -> bool:
	var passed: bool = true
	passed = _check("queue_free is the row that frees an object",
		_reads_as(found, "queue_free"), "Queue Free") and passed
	passed = _check("add_child is the row that adds one",
		_reads_as(found, "add_child"), "Add Child") and passed
	passed = _check("change_scene_to_file is the layout change",
		_reads_as(found, "change_scene_to_file"), "Go To Layout") and passed
	passed = _check("is_on_wall is what the reading calls it",
		_reads_as(found, "is_on_wall"), "Is By Wall") and passed
	passed = _check("push_back comes from the list table, in the reading's own words",
		[_reads_as(found, "push_back"), _from(found, "push_back")],
		["Push back to", EventSheetDocDictionary.FROM_LISTS]) and passed
	passed = _check("a call nothing recognises is not listed",
		_reads_as(found, "not_a_real_call"), "(not listed)") and passed
	passed = _check("the page is in alphabetical order", _is_sorted(found), true) and passed
	return passed


## Every row has to be actionable: a call a reader could type, a sentence the sheet really says,
## and - for a vocabulary row - the id of the page where Show GDScript and Add this row live.
static func _every_row_is_a_real_reading(found: Array[Dictionary]) -> bool:
	var passed: bool = true
	var blank_reading: PackedStringArray = PackedStringArray()
	var unsayable_call: PackedStringArray = PackedStringArray()
	var missing_page: PackedStringArray = PackedStringArray()
	for entry: Dictionary in found:
		var call: String = str(entry.get("call", ""))
		if str(entry.get("reads_as", "")).strip_edges().is_empty():
			blank_reading.append(call)
		if not EventSheetCodeSearch.is_code_query(call) and not call.contains("_"):
			continue
		if call != call.to_lower() or call.contains(" ") or call.contains("("):
			unsayable_call.append(call)
		if str(entry.get("from", "")) == EventSheetDocDictionary.FROM_VOCABULARY \
				and str(entry.get("doc_id", "")).is_empty():
			missing_page.append(call)
	passed = _check("no row reads as nothing", " ".join(blank_reading), "") and passed
	passed = _check("no row names something a reader cannot type",
		" ".join(unsayable_call), "") and passed
	passed = _check("every vocabulary row points at its own page",
		" ".join(missing_page), "") and passed
	passed = _check("the page is not empty", found.size() > 200, true) and passed
	return passed


## THE GATE: the bytes in the bundle are the bytes this build generates.
static func _the_shipped_page_is_the_generated_one(found: Array[Dictionary]) -> bool:
	var shipped: String = _read(EventSheetDocDictionary.BUNDLE_PATH)
	if shipped.is_empty():
		return _check("the dictionary shipped with this build",
			"missing %s" % EventSheetDocDictionary.BUNDLE_PATH, "the baked page")
	return _check("the shipped dictionary is the one this build's tables generate",
		shipped == EventSheetDocDictionary.bundle_text(found), true)


## The written page is the short version of the generated one, so every plain call it names must be
## a call the generated one really lists. A word invented for the page fails here.
static func _the_guide_names_real_calls(found: Array[Dictionary]) -> bool:
	var listed: Dictionary = {}
	for entry: Dictionary in found:
		listed[str(entry.get("call", ""))] = true
	var missing: PackedStringArray = PackedStringArray()
	# A lifecycle hook (`_ready`, `_process`) is a place the engine calls YOU, not a row anybody adds,
	# so the dictionary does not list one and the page is free to name it.
	var pattern: RegEx = RegEx.create_from_string("`([a-z][a-z0-9_]*)\\(\\)`")
	for hit: RegExMatch in pattern.search_all(_read(GUIDE_PATH)):
		var call: String = hit.get_string(1)
		if not listed.has(call) and not missing.has(call):
			missing.append(call)
	return _check("every call the written page names is one the dictionary lists",
		" ".join(missing), "")


# ── Reading the entries ───────────────────────────────────────────────────────────────────────


static func _reads_as(found: Array[Dictionary], call: String) -> String:
	for entry: Dictionary in found:
		if str(entry.get("call", "")) == call:
			return str(entry.get("reads_as", ""))
	return "(not listed)"


static func _from(found: Array[Dictionary], call: String) -> String:
	for entry: Dictionary in found:
		if str(entry.get("call", "")) == call:
			return str(entry.get("from", ""))
	return "(not listed)"


static func _is_sorted(found: Array[Dictionary]) -> bool:
	for index: int in range(1, found.size()):
		if str(found[index - 1].get("call", "")) > str(found[index].get("call", "")):
			return false
	return true


static func _read(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var handle: FileAccess = FileAccess.open(path, FileAccess.READ)
	if handle == null:
		return ""
	var text: String = handle.get_as_text()
	handle.close()
	return text


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] dictionary: %s" % label)
		return true
	print("[FAIL] dictionary: %s\n  expected: %s\n  actual:   %s" % [label, str(expected), str(actual)])
	return false
